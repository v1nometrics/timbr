// SPDX-License-Identifier: MPL-2.0
// timbr's side of the fail-closed mute (ADR-0017). See MuteKeeperProtocol for the why.
//
// Flow: publish the silenced apps → make sure the keeper runs → keep muting in-process until the
// keeper confirms it holds each app (`confirmedHeld`) → only then drop the in-process mute. Whatever
// happens to timbr after that, the keeper keeps the app silent. If the keeper cannot run, the
// in-process mute simply stays (the old behaviour), so a mute never depends on the keeper to work.
import Foundation
import CoreAudio
import TimbreCore

public final class MuteKeeperClient: @unchecked Sendable {
    public let directory: URL
    private let lock = NSLock()
    private var generation: UInt64
    private var published: [MuteKeeperProtocol.Target]?
    private var lastSpawnAttempt: Date = .distantPast
    /// What a previous timbr had the keeper hold. Merged into fresh targets for the same app, so the
    /// first publish after a relaunch (before every helper process is rediscovered) never narrows it.
    private var adopted: [String: MuteKeeperProtocol.Target] = [:]
    public private(set) var lastFailure: String?

    public init(directory: URL = MuteKeeperProtocol.defaultDirectory()) {
        self.directory = directory
        let previous = MuteKeeperProtocol.read(MuteKeeperProtocol.Request.self, from: MuteKeeperProtocol.requestURL(directory))
        self.generation = previous?.generation ?? 0
    }

    public var keeperRunning: Bool { MuteKeeperProtocol.isKeeperRunning(in: directory) }

    // MARK: Targets

    public static func target(for src: AudioSourceDescriptor) -> MuteKeeperProtocol.Target? {
        guard PersistentMutePolicy.isSilenced(src) else { return nil }
        let objs = ProcessTapEngine.translatePIDsToProcessObjects(src.pids)
        let reported = objs.compactMap(reportedBundleID(of:))
        return .init(bundleID: src.bundleID, pids: src.pids,
                     bundleIDs: PersistentMutePolicy.restorableBundleIDs(owner: src.bundleID, reported: reported))
    }

    static func reportedBundleID(of obj: AudioObjectID) -> String? {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioProcessPropertyBundleID, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var cf: CFString?
        var size = UInt32(MemoryLayout<CFString?>.size)
        let err = withUnsafeMutablePointer(to: &cf) { AudioObjectGetPropertyData(obj, &addr, 0, nil, &size, $0) }
        guard err == noErr, let s = cf as String?, !s.isEmpty else { return nil }
        return s
    }

    // MARK: Publish / confirm

    /// Writes the desired mute set (only when it changed) and starts the keeper if something is muted.
    public func publish(_ targets: [MuteKeeperProtocol.Target]) {
        lock.lock()
        let wanted = Set(targets.map(\.bundleID))
        adopted = adopted.filter { wanted.contains($0.key) }
        let merged = targets.map { t -> MuteKeeperProtocol.Target in
            guard let old = adopted[t.bundleID] else { return t }
            return .init(bundleID: t.bundleID, pids: t.pids + old.pids.filter { kill($0, 0) == 0 }, bundleIDs: t.bundleIDs + old.bundleIDs)
        }
        let sorted = merged.sorted { $0.bundleID < $1.bundleID }
        let changed = published != sorted
        if changed { generation &+= 1; published = sorted }
        let gen = generation
        lock.unlock()
        if changed {
            do { try MuteKeeperProtocol.write(MuteKeeperProtocol.Request(generation: gen, targets: sorted), to: MuteKeeperProtocol.requestURL(directory)) }
            catch { lastFailure = "mute keeper: could not write the request (\(error.localizedDescription))" }
        }
        if !sorted.isEmpty { ensureKeeperRunning() }
    }

    /// Apps the keeper confirmed it holds for the latest request. Empty while it is starting, down,
    /// or still answering an older request — timbr keeps its own mute for those.
    public func confirmedHeld() -> Set<String> {
        lock.lock(); let gen = generation; lock.unlock()
        let status = MuteKeeperProtocol.read(MuteKeeperProtocol.Status.self, from: MuteKeeperProtocol.statusURL(directory))
        return MuteKeeperProtocol.confirmedHeld(status: status, requestGeneration: gen, keeperRunning: keeperRunning)
    }

    // MARK: Relaunch

    /// Apps still muted by a keeper that outlived the previous timbr (crash, kill, update). Empty if
    /// no keeper runs: then nothing is holding them and there is nothing to adopt.
    public func survivingMutes() -> [MuteKeeperProtocol.Target] {
        guard keeperRunning,
              let req = MuteKeeperProtocol.read(MuteKeeperProtocol.Request.self, from: MuteKeeperProtocol.requestURL(directory)) else { return [] }
        lock.lock()
        generation = max(generation, req.generation)
        published = req.targets
        for t in req.targets { adopted[t.bundleID] = t }
        lock.unlock()
        return req.targets
    }

    /// Unmutes everything the keeper holds and lets it exit ("restore sound and quit", emergency CLI).
    public func releaseAll() {
        lock.lock(); published = nil; lock.unlock()   // force the empty request onto disk
        publish([])
        if let pid = Self.keeperPID(in: directory), keeperRunning { kill(pid, SIGTERM) }
    }

    // MARK: Keeper process

    private func ensureKeeperRunning() {
        guard !keeperRunning else { return }
        guard Date().timeIntervalSince(lastSpawnAttempt) > 1.0 else { return }
        lastSpawnAttempt = Date()
        guard let exe = Self.keeperExecutable() else {
            lastFailure = "mute keeper: \(MuteKeeperProtocol.executableName) is missing from the app bundle"
            return
        }
        var attr: posix_spawnattr_t?
        posix_spawnattr_init(&attr)
        defer { posix_spawnattr_destroy(&attr) }
        // Own session: not in timbr's process group, so nothing aimed at timbr reaches it.
        posix_spawnattr_setflags(&attr, Int16(POSIX_SPAWN_SETSID))
        var actions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&actions)
        defer { posix_spawn_file_actions_destroy(&actions) }
        for fd in [STDIN_FILENO, STDOUT_FILENO, STDERR_FILENO] {
            posix_spawn_file_actions_addopen(&actions, fd, "/dev/null", fd == STDIN_FILENO ? O_RDONLY : O_WRONLY, 0)
        }
        let argv = [exe.path, "--dir", directory.path]
        var cArgs = argv.map { strdup($0) } + [nil]
        defer { for p in cArgs { free(p) } }
        var pid: pid_t = 0
        let rc = posix_spawn(&pid, exe.path, &actions, &attr, &cArgs, environ)
        lastFailure = rc == 0 ? nil : "mute keeper: posix_spawn = \(rc)"
    }

    static func keeperExecutable() -> URL? {
        let candidates = [
            Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/\(MuteKeeperProtocol.executableName)"),
            Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent(MuteKeeperProtocol.executableName),
        ].compactMap { $0 }
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    static func keeperPID(in dir: URL) -> pid_t? {
        guard let s = try? String(contentsOf: MuteKeeperProtocol.lockURL(dir), encoding: .utf8) else { return nil }
        return pid_t(s.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
