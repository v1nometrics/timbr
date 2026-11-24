// SPDX-License-Identifier: MPL-2.0
// Pure update manifest schema, version comparison, and fail-closed validation (ADR-0026).
// Zero networking here: TimbreCore stays 100% pure and unit-testable offline.
import Foundation

public struct SemVer: Equatable, Comparable, Hashable, Sendable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int, patch: Int = 0) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public init?(parsing raw: String) {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("v") || trimmed.hasPrefix("V") {
            trimmed.removeFirst()
        }
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2 && parts.count <= 3 else { return nil }
        var nums: [Int] = []
        for p in parts {
            guard !p.isEmpty, p.allSatisfy(\.isASCII), p.allSatisfy(\.isNumber), let n = Int(p), n >= 0 else {
                return nil
            }
            nums.append(n)
        }
        self.major = nums[0]
        self.minor = nums[1]
        self.patch = nums.count == 3 ? nums[2] : 0
    }

    public var description: String {
        "\(major).\(minor).\(patch)"
    }

    public static func < (lhs: SemVer, rhs: SemVer) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }
}

public struct AppVersion: Equatable, Hashable, Sendable, CustomStringConvertible {
    public let version: String
    public let build: Int
    public let commit: String?

    public init(version: String, build: Int, commit: String? = nil) {
        self.version = version
        self.build = build
        self.commit = commit
    }

    public var semVer: SemVer? {
        SemVer(parsing: version)
    }

    public var displayLabel: String {
        if build > 0 {
            return "\(version) (build \(build))"
        }
        return version
    }

    public var description: String { displayLabel }

    public static func current(bundle: Bundle = .main) -> AppVersion {
        let short = (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let buildRaw = (bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let commit = (bundle.object(forInfoDictionaryKey: "TimbrCommitSHA") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let version = (short?.isEmpty == false) ? short! : "0.1.0"
        let build = buildRaw.flatMap(Int.init) ?? 0
        return AppVersion(version: version, build: build, commit: (commit?.isEmpty == false) ? commit : nil)
    }
}

public struct UpdateManifest: Codable, Equatable, Sendable {
    public static let supportedSchemaVersion = 1

    public let schemaVersion: Int
    public let version: String
    public let build: Int
    public let tag: String
    public let commit: String
    public let publishedAt: String
    public let minimumMacOS: String
    public let downloadURL: String
    public let releaseNotesURL: String
    public let sha256: String
    public let summary: String?

    public init(
        schemaVersion: Int = UpdateManifest.supportedSchemaVersion,
        version: String,
        build: Int,
        tag: String,
        commit: String,
        publishedAt: String,
        minimumMacOS: String,
        downloadURL: String,
        releaseNotesURL: String,
        sha256: String,
        summary: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.version = version
        self.build = build
        self.tag = tag
        self.commit = commit
        self.publishedAt = publishedAt
        self.minimumMacOS = minimumMacOS
        self.downloadURL = downloadURL
        self.releaseNotesURL = releaseNotesURL
        self.sha256 = sha256
        self.summary = summary
    }

    public var displayVersion: String {
        build > 0 ? "\(version) (build \(build))" : version
    }
}

public enum UpdateEvaluation: Equatable, Sendable {
    case upToDate
    case available(UpdateManifest)
    case skipped(UpdateManifest)
    case unsupportedOS(required: String, current: String)
    case invalid(String)
}

public enum UpdatePolicy {
    public static let repositorySlug = "v1nometrics/timbr"
    public static let expectedBundleIdentifier = AudioSourceIdentity.timbrBundleID
    public static let expectedExecutableName = "Timbr"
    public static let defaultManifestURL = URL(string: "https://github.com/v1nometrics/timbr/releases/latest/download/update-manifest.json")!
    public static let releasesPageURL = URL(string: "https://github.com/v1nometrics/timbr/releases")!
    public static let automaticCheckIntervalSeconds: TimeInterval = 4 * 60 * 60
    public static let initialCheckDelaySeconds: TimeInterval = 12
    public static let maxDownloadBytes: Int64 = 150 * 1024 * 1024

    /// Only allow official HTTPS GitHub release URLs belonging to `v1nometrics/timbr`.
    public static func isTrustedReleaseURL(_ raw: String) -> Bool {
        guard let comps = URLComponents(string: raw),
              let scheme = comps.scheme?.lowercased(), scheme == "https",
              let host = comps.host?.lowercased(), host == "github.com",
              comps.port == nil, comps.user == nil, comps.password == nil else {
            return false
        }
        let path = comps.path
        guard path.hasPrefix("/\(repositorySlug)/releases/") else { return false }
        let segments = path.split(separator: "/")
        if segments.contains("..") || segments.contains(".") { return false }
        return segments.count >= 4
    }

    /// Valid SHA-256 hex string: exactly 64 ASCII hexadecimal digits.
    public static func isValidSHA256(_ raw: String) -> Bool {
        guard raw.count == 64 else { return false }
        for u in raw.utf8 {
            let isDigit = (u >= 48 && u <= 57)
            let isUpper = (u >= 65 && u <= 70)
            let isLower = (u >= 97 && u <= 102)
            if !(isDigit || isUpper || isLower) { return false }
        }
        return true
    }

    /// True strictly when `manifest` is newer than `current` (never downgrades).
    public static func isNewer(manifest: UpdateManifest, than current: AppVersion) -> Bool {
        guard let remoteSemVer = SemVer(parsing: manifest.version),
              let localSemVer = current.semVer else {
            return false
        }
        if remoteSemVer != localSemVer {
            return remoteSemVer > localSemVer
        }
        return manifest.build > current.build
    }

    public static func currentMacOSVersion() -> SemVer {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return SemVer(major: v.majorVersion, minor: v.minorVersion, patch: v.patchVersion)
    }

    public static func evaluate(
        manifest: UpdateManifest,
        current: AppVersion,
        currentMacOS: SemVer = currentMacOSVersion(),
        skippedTag: String? = nil,
        ignoreSkipped: Bool = false
    ) -> UpdateEvaluation {
        guard manifest.schemaVersion == UpdateManifest.supportedSchemaVersion else {
            return .invalid("unsupported schema version \(manifest.schemaVersion)")
        }
        guard SemVer(parsing: manifest.version) != nil else {
            return .invalid("invalid manifest version")
        }
        guard manifest.build > 0 else {
            return .invalid("invalid build number")
        }
        guard !manifest.tag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .invalid("empty release tag")
        }
        guard isTrustedReleaseURL(manifest.downloadURL) else {
            return .invalid("untrusted download URL")
        }
        guard isTrustedReleaseURL(manifest.releaseNotesURL) else {
            return .invalid("untrusted release notes URL")
        }
        guard isValidSHA256(manifest.sha256) else {
            return .invalid("invalid SHA-256 checksum")
        }
        guard let minOS = SemVer(parsing: manifest.minimumMacOS) else {
            return .invalid("invalid minimumMacOS")
        }
        guard currentMacOS >= minOS else {
            return .unsupportedOS(required: minOS.description, current: currentMacOS.description)
        }
        guard isNewer(manifest: manifest, than: current) else {
            return .upToDate
        }
        if !ignoreSkipped, let skippedTag, skippedTag == manifest.tag {
            return .skipped(manifest)
        }
        return .available(manifest)
    }

    /// True only when running from a standard Applications folder (`/Applications` or `~/Applications`),
    /// preventing self-updates from overwriting a local dev checkout (`dist/Timbr.app`) or read-only DMG volume.
    public static func isStandardApplicationsPath(_ bundlePath: String, homeDirectory: String) -> Bool {
        let std = URL(fileURLWithPath: bundlePath).standardizedFileURL.path
        guard std.hasSuffix(".app") else { return false }
        let parent = URL(fileURLWithPath: std).deletingLastPathComponent().standardizedFileURL.path
        let userApps = URL(fileURLWithPath: homeDirectory).appendingPathComponent("Applications").standardizedFileURL.path
        return parent == "/Applications" || parent == userApps
    }
}
