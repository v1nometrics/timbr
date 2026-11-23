// SPDX-License-Identifier: MPL-2.0
// Fail-closed mute (ADR-0017): the contract between timbr and `timbr-mute-keeper`.
//
// Measured on macOS 26.6 (2026-11-23, listening test): a process tap only mutes while some running
// process reads it — an unread `.muted` tap leaves the app audible, and every tap dies with the
// process that reads it. So a mute that must outlive timbr needs another live process: the keeper,
// a tiny separate executable (no UI, no DSP) that holds only mutes. timbr writes the desired set to
// `request.json`; the keeper applies it and reports in `status.json`. The request file is also the
// record a relaunched timbr reads back.
//
// This file is compiled into both executables, so it depends on Foundation only.
import Foundation

public enum MuteKeeperProtocol {
    public static let version = 1
    public static let executableName = "timbr-mute-keeper"
    /// Aggregate UIDs of the keeper. Distinct from `ProcessTapEngine.aggregateUIDPrefix`, so timbr's
    /// orphan cleanup can never take a keeper aggregate for a leak.
    public static let aggregateUIDPrefix = "dev.v1torres.timbr.mutekeeper."

    public struct Target: Codable, Equatable, Hashable, Sendable {
        public let bundleID: String      // the row the user muted (owner app)
        public let pids: [Int32]          // processes playing right now
        public let bundleIDs: [String]    // followed across relaunches (macOS 26 processRestoreEnabled)

        public init(bundleID: String, pids: [Int32], bundleIDs: [String]) {
            self.bundleID = bundleID
            self.pids = Array(Set(pids)).sorted()
            self.bundleIDs = Array(Set(bundleIDs)).sorted()
        }
    }

    public struct Request: Codable, Equatable, Sendable {
        public var version: Int
        public var generation: UInt64
        public var targets: [Target]

        public init(generation: UInt64, targets: [Target]) {
            self.version = MuteKeeperProtocol.version
            self.generation = generation
            self.targets = targets.sorted { $0.bundleID < $1.bundleID }
        }
    }

    public struct Status: Codable, Equatable, Sendable {
        public var version: Int
        public var generation: UInt64     // request generation this status answers
        public var pid: Int32
        public var held: [String]          // bundle IDs with a running mute
        public var failures: [String: String]

        public init(generation: UInt64, pid: Int32, held: [String], failures: [String: String]) {
            self.version = MuteKeeperProtocol.version
            self.generation = generation
            self.pid = pid
            self.held = held.sorted()
            self.failures = failures
        }
    }

    public static func defaultDirectory() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return support.appendingPathComponent("dev.v1torres.timbr/mute-keeper", isDirectory: true)
    }

    public static func requestURL(_ dir: URL) -> URL { dir.appendingPathComponent("request.json") }
    public static func statusURL(_ dir: URL) -> URL { dir.appendingPathComponent("status.json") }
    public static func lockURL(_ dir: URL) -> URL { dir.appendingPathComponent("keeper.lock") }

    public static func write<T: Encodable>(_ value: T, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        try enc.encode(value).write(to: url, options: .atomic)
    }

    public static func read<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    /// True while a keeper holds the lock in `dir` (the keeper takes an exclusive `flock` for life).
    public static func isKeeperRunning(in dir: URL) -> Bool {
        let fd = open(lockURL(dir).path, O_RDONLY)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        if flock(fd, LOCK_EX | LOCK_NB) == 0 {
            flock(fd, LOCK_UN)
            return false
        }
        return true
    }

    /// Bundle IDs timbr may drop its own in-process mute for: the keeper answered the current
    /// request and reports them held. Anything else keeps the in-process mute as well.
    public static func confirmedHeld(status: Status?, requestGeneration: UInt64, keeperRunning: Bool) -> Set<String> {
        guard keeperRunning, let status, status.version == version, status.generation == requestGeneration else { return [] }
        return Set(status.held)
    }
}
