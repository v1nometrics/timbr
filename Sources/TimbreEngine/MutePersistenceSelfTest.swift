// SPDX-License-Identifier: MPL-2.0
// End-to-end check of the fail-closed mute mechanics (ADR-0017), run inside the signed app:
//   `Timbr --selftest-mute-persistence <report.json>`
//
// A player process (timbr. in `--selftest-tone` mode) plays a quiet tone. A *second timbr. process*
// (`--selftest-mute-holder`) mutes it through the production MuteKeeperClient — which starts the
// real `timbr-mute-keeper` — waits for the keeper to confirm, and is then killed with SIGKILL, the
// harshest way timbr. can die. The keeper must still be running and holding the mute; a fresh
// client (= timbr. relaunched) must adopt it; releasing must make the keeper exit. Everything runs in
// a private state directory, never touching the real app's mutes.
//
// What this cannot measure: the speaker. Process taps read audio *before* the mute is applied and
// timbr. has no microphone grant. Audibility is checked by ear: scripts/listen_mute_crash.sh.
import Foundation
import CoreAudio
import TimbreCore

public enum MutePersistenceSelfTest {
    public struct Check: Codable, Sendable {
        public let name: String
        public let pass: Bool
        public let detail: String
    }

    public struct Report: Codable, Sendable {
        public let date: Date
        public let macOS: String
        public let checks: [Check]
        public let notes: [String]
        public let allPassed: Bool
    }

    static let testBundleID = "selftest.player"

    // MARK: Holder (the timbr. process that gets SIGKILLed)

    /// `--selftest-mute-holder <pid> <state dir>`: mute `pid` through the keeper, wait until it confirms,
    /// write `ready`, then idle until killed. Never releases: dying with the mute held is the point.
    @MainActor
    public static func runHolder(pid: pid_t, directory: URL) async -> MuteKeeperClient? {
        let objs = ProcessTapEngine.translatePIDsToProcessObjects([pid])
        guard !objs.isEmpty else { return nil }
        let reported = objs.compactMap(MuteKeeperClient.reportedBundleID(of:))
        let client = MuteKeeperClient(directory: directory)
        client.publish([.init(bundleID: testBundleID, pids: [pid], bundleIDs: reported)])
        for _ in 0..<100 {
            if client.confirmedHeld().contains(testBundleID) {
                try? "ready".write(to: directory.appendingPathComponent("ready"), atomically: true, encoding: .utf8)
                return client
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return nil
    }

    // MARK: Parent

    @MainActor
    public static func run(reportURL: URL) async -> Report {
        var checks: [Check] = []
        var notes: [String] = []
        func check(_ name: String, _ pass: Bool, _ detail: String) { checks.append(Check(name: name, pass: pass, detail: detail)) }

        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("timbr-mutetest-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        guard MuteKeeperClient.keeperExecutable() != nil else {
            return finish([Check(name: "keeper executable in the bundle", pass: false, detail: "missing")], [], reportURL)
        }

        let wav = FileManager.default.temporaryDirectory.appendingPathComponent("timbr-mutetest.wav")
        AudioSelfTest.writeTone(to: wav, dBFS: -30, seconds: 20, sampleRate: 48000)
        let player = Process()
        player.executableURL = Bundle.main.executableURL
        player.arguments = ["--selftest-tone", wav.path]
        player.standardOutput = FileHandle.nullDevice
        player.standardError = FileHandle.nullDevice
        guard (try? player.run()) != nil else { return finish([], ["the player did not start"], reportURL) }
        defer { player.terminate() }
        var playing = false
        for _ in 0..<100 {
            if let o = ProcessTapEngine.translatePIDsToProcessObjects([player.processIdentifier]).first, AudioSelfTest.isRunningOutput(o) { playing = true; break }
            try? await Task.sleep(for: .milliseconds(50))
        }
        check("player is producing audio", playing, "pid \(player.processIdentifier)")

        // 1. A second timbr. process mutes the player through the keeper, then dies by SIGKILL.
        let holder = Process()
        holder.executableURL = Bundle.main.executableURL
        holder.arguments = ["--selftest-mute-holder", String(player.processIdentifier), dir.path]
        holder.standardOutput = FileHandle.nullDevice
        holder.standardError = FileHandle.nullDevice
        guard (try? holder.run()) != nil else { return finish(checks, ["could not launch the holder process"], reportURL) }
        var ready = false
        for _ in 0..<160 {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("ready").path) { ready = true; break }
            try? await Task.sleep(for: .milliseconds(50))
        }
        let keeperPID = MuteKeeperClient.keeperPID(in: dir)
        check("keeper started and confirmed the mute", ready && MuteKeeperProtocol.isKeeperRunning(in: dir),
              "holder pid \(holder.processIdentifier), keeper pid \(keeperPID.map(String.init) ?? "—")")

        kill(holder.processIdentifier, SIGKILL)
        holder.waitUntilExit()
        try? await Task.sleep(for: .milliseconds(800))
        let status = MuteKeeperProtocol.read(MuteKeeperProtocol.Status.self, from: MuteKeeperProtocol.statusURL(dir))
        check("keeper outlives timbr. killed with SIGKILL and still holds the mute",
              MuteKeeperProtocol.isKeeperRunning(in: dir) && (status?.held.contains(testBundleID) ?? false),
              "holder exit: \(holder.terminationReason == .uncaughtSignal ? "signal" : "status") \(holder.terminationStatus); keeper running \(MuteKeeperProtocol.isKeeperRunning(in: dir)); held \(status?.held ?? [])")

        // 2. timbr. relaunched: adopt, then the user unmutes.
        let relaunched = MuteKeeperClient(directory: dir)
        let adopted = relaunched.survivingMutes().map(\.bundleID)
        check("a relaunched timbr. adopts the surviving mute", adopted.contains(testBundleID), "adopted \(adopted)")
        relaunched.releaseAll()
        var exited = false
        for _ in 0..<40 {
            if !MuteKeeperProtocol.isKeeperRunning(in: dir) { exited = true; break }
            try? await Task.sleep(for: .milliseconds(50))
        }
        check("unmuting everything releases the mute and the keeper exits", exited, exited ? "keeper gone" : "keeper still running")
        if !exited, let keeperPID { kill(keeperPID, SIGKILL) }

        notes.append("speaker silence is checked by ear (scripts/listen_mute_crash.sh): taps read pre-mute audio")
        return finish(checks, notes, reportURL)
    }

    private static func finish(_ checks: [Check], _ notes: [String], _ url: URL) -> Report {
        let r = Report(date: Date(), macOS: ProcessInfo.processInfo.operatingSystemVersionString, checks: checks,
                       notes: notes, allPassed: !checks.isEmpty && checks.allSatisfy(\.pass))
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        try? enc.encode(r).write(to: url)
        return r
    }
}
