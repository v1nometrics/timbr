// SPDX-License-Identifier: MPL-2.0
// Official update checker and verified in-app updater via GitHub Releases (ADR-0026).
// Privacy contract (P7): read-only HTTPS GET of static release manifest; zero cookies, zero IDs, zero telemetry.
import Foundation
import AppKit
import CryptoKit
import Security
import TimbreCore

public enum UpdateStatus: Equatable, Sendable {
    case idle
    case checking
    case upToDate(checkedAt: Date)
    case available(UpdateManifest)
    case downloading(UpdateManifest, progress: Double)
    case verifying(UpdateManifest)
    case installing(UpdateManifest)
    case downloadedToFolder(UpdateManifest, fileURL: URL)
    case unsupportedOS(required: String)
    case failed(String)
}

private enum UpdaterError: LocalizedError {
    case httpStatus(Int)
    case untrustedURL
    case downloadTooLarge
    case cancelled
    case checksumMismatch
    case mountFailed
    case missingAppBundle
    case invalidBundleIdentifier
    case codeSignatureInvalid
    case stagingFailed

    var errorDescription: String? {
        switch self {
        case .httpStatus(let code): return "HTTP \(code)"
        case .untrustedURL: return "Untrusted release URL"
        case .downloadTooLarge: return "Download exceeds safety size limit"
        case .cancelled: return "Cancelled"
        case .checksumMismatch: return "SHA-256 verification failed"
        case .mountFailed: return "Could not mount verified disk image"
        case .missingAppBundle: return "Timbr.app not found inside disk image"
        case .invalidBundleIdentifier: return "Bundle identifier mismatch"
        case .codeSignatureInvalid: return "Bundle code signature verification failed"
        case .stagingFailed: return "Could not prepare update for installation"
        }
    }
}

private struct VerifiedPreparationResult: Sendable {
    let installedInPlace: Bool
    let swapScriptPath: String?
    let swapArgs: [String]
    let downloadedDMGURL: URL?
}

/// Streams a DMG directly to disk with bounded memory and smooth progress callbacks.
private final class DownloadTransferDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private let destinationURL: URL
    private let maxBytes: Int64
    private let onProgress: @Sendable (Double) -> Void
    private var continuation: CheckedContinuation<URL, Error>?
    private var lastReportedFraction: Double = -1
    private var finished = false

    init(
        destinationURL: URL,
        maxBytes: Int64,
        onProgress: @escaping @Sendable (Double) -> Void
    ) {
        self.destinationURL = destinationURL
        self.maxBytes = maxBytes
        self.onProgress = onProgress
        super.init()
    }

    func attach(continuation: CheckedContinuation<URL, Error>) {
        lock.lock()
        self.continuation = continuation
        lock.unlock()
    }

    private func complete(_ result: Result<URL, Error>) {
        lock.lock()
        guard !finished else {
            lock.unlock()
            return
        }
        finished = true
        let cont = continuation
        continuation = nil
        lock.unlock()
        cont?.resume(with: result)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        if totalBytesWritten > maxBytes || (totalBytesExpectedToWrite > 0 && totalBytesExpectedToWrite > maxBytes) {
            downloadTask.cancel()
            complete(.failure(UpdaterError.downloadTooLarge))
            return
        }
        guard totalBytesExpectedToWrite > 0 else { return }
        let fraction = min(1.0, max(0.0, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)))
        lock.lock()
        let delta = abs(fraction - lastReportedFraction)
        let shouldReport = delta >= 0.015 || fraction >= 1.0
        if shouldReport { lastReportedFraction = fraction }
        lock.unlock()
        if shouldReport {
            onProgress(fraction)
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        if let http = downloadTask.response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            complete(.failure(UpdaterError.httpStatus(http.statusCode)))
            return
        }
        do {
            let fm = FileManager.default
            if fm.fileExists(atPath: destinationURL.path) {
                try fm.removeItem(at: destinationURL)
            }
            try fm.moveItem(at: location, to: destinationURL)
            complete(.success(destinationURL))
        } catch {
            complete(.failure(error))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        if (error as NSError).code == NSURLErrorCancelled {
            complete(.failure(UpdaterError.cancelled))
        } else {
            complete(.failure(error))
        }
    }
}

@MainActor
public final class AppUpdater: ObservableObject {
    @Published public private(set) var status: UpdateStatus = .idle
    @Published public var automaticChecksEnabled: Bool = true
    @Published public private(set) var bannerDismissedTag: String? = nil
    @Published public private(set) var lastCheckedAt: Date? = nil
    @Published public private(set) var currentVersion: AppVersion = AppVersion.current()

    public var onLog: ((String) -> Void)?
    public var onPersistAutoCheck: ((Bool) -> Void)?
    public var onPersistSkippedTag: ((String?) -> Void)?
    public var skippedTagProvider: (() -> String?)?

    private var initialCheckTask: Task<Void, Never>?
    private var periodicTimer: Timer?
    private var activeTask: Task<Void, Never>?
    private var activeDownloadTask: URLSessionDownloadTask?
    private var activeManifestForCancel: UpdateManifest?

    public init() {}

    public var availableManifest: UpdateManifest? {
        switch status {
        case .available(let m), .downloading(let m, _), .verifying(let m), .installing(let m):
            return m
        default:
            return nil
        }
    }

    public var hasActionableUpdate: Bool {
        availableManifest != nil
    }

    public var shouldShowStudioBanner: Bool {
        switch status {
        case .available(let m):
            return bannerDismissedTag != m.tag
        case .downloading, .verifying, .installing:
            return true
        default:
            return false
        }
    }

    public var isBusy: Bool {
        switch status {
        case .checking, .downloading, .verifying, .installing:
            return true
        default:
            return false
        }
    }

    public var canInstallInPlace: Bool {
        let bundleURL = Bundle.main.bundleURL
        guard UpdatePolicy.isStandardApplicationsPath(bundleURL.path, homeDirectory: NSHomeDirectory()) else {
            return false
        }
        let fm = FileManager.default
        let parentPath = bundleURL.deletingLastPathComponent().path
        return fm.isWritableFile(atPath: bundleURL.path) && fm.isWritableFile(atPath: parentPath)
    }

    public func configure(automaticChecks: Bool) {
        self.automaticChecksEnabled = automaticChecks
    }

    public func setAutomaticChecksEnabled(_ enabled: Bool, isAuxiliaryInstance: Bool) {
        automaticChecksEnabled = enabled
        onPersistAutoCheck?(enabled)
        if enabled {
            startAutomaticChecks(isAuxiliaryInstance: isAuxiliaryInstance)
        } else {
            initialCheckTask?.cancel()
            initialCheckTask = nil
            periodicTimer?.invalidate()
            periodicTimer = nil
        }
    }

    public func startAutomaticChecks(isAuxiliaryInstance: Bool) {
        guard !isAuxiliaryInstance else { return }
        initialCheckTask?.cancel()
        periodicTimer?.invalidate()
        guard automaticChecksEnabled else { return }

        initialCheckTask = Task { [weak self] in
            let delayNs = UInt64(UpdatePolicy.initialCheckDelaySeconds * 1_000_000_000)
            try? await Task.sleep(nanoseconds: delayNs)
            guard !Task.isCancelled else { return }
            self?.checkForUpdates(manual: false)
        }

        periodicTimer = Timer.scheduledTimer(
            withTimeInterval: UpdatePolicy.automaticCheckIntervalSeconds,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.automaticChecksEnabled, !self.isBusy else { return }
                self.checkForUpdates(manual: false)
            }
        }
    }

    public func stop() {
        initialCheckTask?.cancel()
        initialCheckTask = nil
        periodicTimer?.invalidate()
        periodicTimer = nil
        activeDownloadTask?.cancel()
        activeDownloadTask = nil
        activeTask?.cancel()
        activeTask = nil
    }

    public func checkForUpdates(manual: Bool) {
        if isBusy { return }
        if manual {
            bannerDismissedTag = nil
            status = .checking
        }
        let current = currentVersion
        let skipped = skippedTagProvider?()

        activeTask?.cancel()
        activeTask = Task { [weak self] in
            guard let self else { return }
            do {
                let manifest = try await Self.fetchManifest(url: UpdatePolicy.defaultManifestURL)
                guard !Task.isCancelled else { return }
                let now = Date()
                self.lastCheckedAt = now
                let evaluation = UpdatePolicy.evaluate(
                    manifest: manifest,
                    current: current,
                    skippedTag: skipped,
                    ignoreSkipped: manual
                )
                switch evaluation {
                case .available(let remote):
                    self.status = .available(remote)
                    self.onLog?("Update available: \(remote.displayVersion) [\(remote.tag)]")
                case .skipped(let remote):
                    if manual {
                        self.status = .available(remote)
                    } else {
                        self.status = .upToDate(checkedAt: now)
                    }
                case .upToDate:
                    self.status = .upToDate(checkedAt: now)
                    if manual {
                        self.onLog?("Update check: already on latest (\(current.displayLabel))")
                    }
                case .unsupportedOS(let required, _):
                    if manual {
                        self.status = .unsupportedOS(required: required)
                    } else {
                        self.status = .upToDate(checkedAt: now)
                    }
                case .invalid(let reason):
                    self.onLog?("Update manifest rejected: \(reason)")
                    if manual {
                        self.status = .failed(reason)
                    }
                }
            } catch UpdaterError.httpStatus(404) {
                if manual {
                    self.status = .upToDate(checkedAt: Date())
                } else if case .checking = self.status {
                    self.status = .idle
                }
            } catch is CancellationError {
                if case .checking = self.status {
                    self.status = .idle
                }
            } catch {
                self.onLog?("Update check failed: \(error.localizedDescription)")
                if manual {
                    self.status = .failed(error.localizedDescription)
                } else if case .checking = self.status {
                    self.status = .idle
                }
            }
        }
    }

    public func downloadAndInstall(_ manifest: UpdateManifest) {
        guard !isBusy else { return }
        guard UpdatePolicy.isTrustedReleaseURL(manifest.downloadURL),
              let url = URL(string: manifest.downloadURL),
              UpdatePolicy.isValidSHA256(manifest.sha256) else {
            status = .failed(UpdaterError.untrustedURL.localizedDescription)
            return
        }

        activeManifestForCancel = manifest
        status = .downloading(manifest, progress: 0)
        onLog?("Downloading update \(manifest.tag)")

        let bundleURL = Bundle.main.bundleURL
        let allowInPlace = canInstallInPlace
        let currentPID = ProcessInfo.processInfo.processIdentifier

        activeTask?.cancel()
        activeTask = Task { [weak self] in
            guard let self else { return }
            let tempDMG = FileManager.default.temporaryDirectory
                .appendingPathComponent("timbr-update-\(UUID().uuidString).dmg")
            defer {
                self.activeDownloadTask = nil
                self.activeManifestForCancel = nil
            }
            do {
                try await self.downloadFile(from: url, to: tempDMG, manifest: manifest)
                guard !Task.isCancelled else {
                    try? FileManager.default.removeItem(at: tempDMG)
                    self.status = .available(manifest)
                    return
                }

                self.status = .verifying(manifest)
                let expectedHash = manifest.sha256.lowercased()
                let tag = manifest.tag

                let prep = try await Task.detached(priority: .userInitiated) {
                    try Self.verifyAndPrepare(
                        dmgURL: tempDMG,
                        expectedSHA256: expectedHash,
                        tag: tag,
                        bundleURL: bundleURL,
                        allowInPlace: allowInPlace,
                        currentPID: currentPID
                    )
                }.value

                guard !Task.isCancelled else { return }

                if prep.installedInPlace, let scriptPath = prep.swapScriptPath {
                    self.status = .installing(manifest)
                    self.onLog?("Update \(manifest.tag) verified (SHA-256 + codesign); swapping bundle and restarting")
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/bin/sh")
                    process.arguments = [scriptPath] + prep.swapArgs
                    process.standardInput = FileHandle.nullDevice
                    process.standardOutput = FileHandle.nullDevice
                    process.standardError = FileHandle.nullDevice
                    try process.run()
                    NSApp.terminate(nil)
                } else if let dmgURL = prep.downloadedDMGURL {
                    self.status = .downloadedToFolder(manifest, fileURL: dmgURL)
                    self.onLog?("Verified DMG saved to \(dmgURL.path)")
                    NSWorkspace.shared.activateFileViewerSelecting([dmgURL])
                    NSWorkspace.shared.open(dmgURL)
                }
            } catch UpdaterError.cancelled {
                try? FileManager.default.removeItem(at: tempDMG)
                self.status = .available(manifest)
            } catch is CancellationError {
                try? FileManager.default.removeItem(at: tempDMG)
                self.status = .available(manifest)
            } catch {
                try? FileManager.default.removeItem(at: tempDMG)
                self.onLog?("Update install failed: \(error.localizedDescription)")
                self.status = .failed(error.localizedDescription)
            }
        }
    }

    public func cancelDownload() {
        let fallback = activeManifestForCancel
        activeDownloadTask?.cancel()
        activeDownloadTask = nil
        activeTask?.cancel()
        activeTask = nil
        if let fallback {
            status = .available(fallback)
        } else {
            status = .idle
        }
    }

    public func skipUpdate(_ manifest: UpdateManifest) {
        onPersistSkippedTag?(manifest.tag)
        bannerDismissedTag = manifest.tag
        status = .idle
        onLog?("Skipped update \(manifest.tag)")
    }

    public func dismissBanner() {
        if let m = availableManifest {
            bannerDismissedTag = m.tag
        }
    }

    public func openReleaseNotes(_ manifest: UpdateManifest) {
        guard UpdatePolicy.isTrustedReleaseURL(manifest.releaseNotesURL),
              let url = URL(string: manifest.releaseNotesURL) else {
            NSWorkspace.shared.open(UpdatePolicy.releasesPageURL)
            return
        }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Networking & Verification (zero cookies, zero disk cache)

    private nonisolated static func makePrivacySessionConfiguration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 300
        return config
    }

    private nonisolated static func fetchManifest(url: URL) async throws -> UpdateManifest {
        let session = URLSession(configuration: makePrivacySessionConfiguration())
        defer { session.finishTasksAndInvalidate() }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpShouldHandleCookies = false
        request.setValue("timbr-updater", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw UpdaterError.httpStatus(0)
        }
        guard (200...299).contains(http.statusCode) else {
            throw UpdaterError.httpStatus(http.statusCode)
        }
        return try JSONDecoder().decode(UpdateManifest.self, from: data)
    }

    private func downloadFile(from url: URL, to destination: URL, manifest: UpdateManifest) async throws {
        let delegate = DownloadTransferDelegate(
            destinationURL: destination,
            maxBytes: UpdatePolicy.maxDownloadBytes
        ) { [weak self] fraction in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if case .downloading = self.status {
                    self.status = .downloading(manifest, progress: fraction)
                }
            }
        }
        let session = URLSession(
            configuration: Self.makePrivacySessionConfiguration(),
            delegate: delegate,
            delegateQueue: nil
        )
        defer { session.finishTasksAndInvalidate() }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpShouldHandleCookies = false
        request.setValue("timbr-updater", forHTTPHeaderField: "User-Agent")

        let task = session.downloadTask(with: request)
        self.activeDownloadTask = task
        _ = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                delegate.attach(continuation: continuation)
                task.resume()
            }
        } onCancel: {
            task.cancel()
        }
    }

    private nonisolated static func sha256Hex(fileURL: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let chunk = try handle.read(upToCount: 65_536) ?? Data()
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private nonisolated static func runProcess(_ executable: String, arguments: [String]) throws -> (Int32, Data) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: executable)
        proc.arguments = arguments
        let outPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = Pipe()
        try proc.run()
        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        return (proc.terminationStatus, data)
    }

    /// The updater can preserve TCC grants only when the candidate satisfies the installed
    /// app's designated requirement. A structurally valid ad hoc signature is insufficient.
    private nonisolated static func preservesSigningIdentity(from installed: URL, to candidate: URL) -> Bool {
        let flags = SecCSFlags(rawValue: 0)
        var current: SecStaticCode?
        var next: SecStaticCode?
        var requirement: SecRequirement?
        guard SecStaticCodeCreateWithPath(installed as CFURL, flags, &current) == errSecSuccess,
              let current,
              SecCodeCopyDesignatedRequirement(current, flags, &requirement) == errSecSuccess,
              let requirement,
              SecStaticCodeCreateWithPath(candidate as CFURL, flags, &next) == errSecSuccess,
              let next else { return false }
        return SecStaticCodeCheckValidity(next, flags, requirement) == errSecSuccess
    }

    private nonisolated static func verifyAndPrepare(
        dmgURL: URL,
        expectedSHA256: String,
        tag: String,
        bundleURL: URL,
        allowInPlace: Bool,
        currentPID: Int32
    ) throws -> VerifiedPreparationResult {
        // 1. Fail-closed SHA-256 verification before mounting or touching the DMG.
        let actualSHA = try sha256Hex(fileURL: dmgURL)
        guard actualSHA == expectedSHA256 else {
            throw UpdaterError.checksumMismatch
        }

        // 2. Mount DMG read-only without Finder noise and inspect the signed app bundle.
        let (attachStatus, attachData) = try runProcess(
            "/usr/bin/hdiutil",
            arguments: ["attach", "-nobrowse", "-readonly", "-plist", dmgURL.path]
        )
        guard attachStatus == 0,
              let plist = try? PropertyListSerialization.propertyList(from: attachData, format: nil) as? [String: Any],
              let entities = plist["system-entities"] as? [[String: Any]],
              let mountPoint = entities.compactMap({ $0["mount-point"] as? String }).first else {
            throw UpdaterError.mountFailed
        }
        var stillMounted = true
        let detachMount = {
            if stillMounted {
                stillMounted = false
                _ = try? runProcess("/usr/bin/hdiutil", arguments: ["detach", mountPoint, "-force"])
            }
        }
        defer { detachMount() }

        let mountedApp = URL(fileURLWithPath: mountPoint).appendingPathComponent("Timbr.app")
        guard FileManager.default.fileExists(atPath: mountedApp.path) else {
            throw UpdaterError.missingAppBundle
        }

        let infoPlistURL = mountedApp.appendingPathComponent("Contents/Info.plist")
        guard let infoData = try? Data(contentsOf: infoPlistURL),
              let info = try? PropertyListSerialization.propertyList(from: infoData, format: nil) as? [String: Any],
              (info["CFBundleIdentifier"] as? String) == UpdatePolicy.expectedBundleIdentifier,
              (info["CFBundleExecutable"] as? String) == UpdatePolicy.expectedExecutableName else {
            throw UpdaterError.invalidBundleIdentifier
        }

        let (verifyStatus, _) = try runProcess(
            "/usr/bin/codesign",
            arguments: ["--verify", "--deep", "--strict", mountedApp.path]
        )
        guard verifyStatus == 0 else {
            throw UpdaterError.codeSignatureInvalid
        }

        // 3. Atomic in-place swap when installed in /Applications or ~/Applications; otherwise deliver verified DMG.
        if allowInPlace, preservesSigningIdentity(from: bundleURL, to: mountedApp) {
            let parentDir = bundleURL.deletingLastPathComponent()
            let stagedApp = parentDir.appendingPathComponent(".Timbr-update-\(UUID().uuidString).app")
            let (copyStatus, _) = try runProcess("/usr/bin/ditto", arguments: [mountedApp.path, stagedApp.path])
            guard copyStatus == 0 else {
                try? FileManager.default.removeItem(at: stagedApp)
                throw UpdaterError.stagingFailed
            }

            detachMount()
            try? FileManager.default.removeItem(at: dmgURL)

            let scriptURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("timbr-swap-\(UUID().uuidString).sh")
            let scriptBody = """
            #!/bin/sh
            set -eu
            PID="$1"
            TARGET="$2"
            STAGED="$3"
            BACKUP="${TARGET}.timbr-prev"
            i=0
            while kill -0 "$PID" 2>/dev/null && [ "$i" -lt 100 ]; do
              sleep 0.1
              i=$((i + 1))
            done
            rm -rf "$BACKUP"
            if [ -d "$TARGET" ]; then
              mv "$TARGET" "$BACKUP"
            fi
            if mv "$STAGED" "$TARGET"; then
              rm -rf "$BACKUP"
              xattr -dr com.apple.quarantine "$TARGET" 2>/dev/null || true
              open -n "$TARGET"
            else
              if [ -d "$BACKUP" ]; then
                mv "$BACKUP" "$TARGET" || true
              fi
              exit 1
            fi
            rm -f "$0"
            """
            try scriptBody.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)

            return VerifiedPreparationResult(
                installedInPlace: true,
                swapScriptPath: scriptURL.path,
                swapArgs: [String(currentPID), bundleURL.path, stagedApp.path],
                downloadedDMGURL: nil
            )
        } else {
            detachMount()
            let safeTag = tag.filter { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "." || $0 == "-" || $0 == "_") }
            let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let dest = downloads.appendingPathComponent("Timbr-\(safeTag.isEmpty ? "update" : safeTag).dmg")
            if FileManager.default.fileExists(atPath: dest.path) {
                try? FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.moveItem(at: dmgURL, to: dest)
            return VerifiedPreparationResult(
                installedInPlace: false,
                swapScriptPath: nil,
                swapArgs: [],
                downloadedDMGURL: dest
            )
        }
    }
}
