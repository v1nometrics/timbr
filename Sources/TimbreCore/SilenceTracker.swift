// SPDX-License-Identifier: MPL-2.0
// Tells "the app paused" from "the app is between two notes" using the level our own DSP already
// measures (no new tap, no new capture): a slot counts as silent once its peak has stayed below the
// floor for `holdSeconds`, and stops counting the instant a loud block arrives.
import Foundation

public struct SilenceTracker: Sendable {
    public let floorDB: Double
    public let holdSeconds: TimeInterval
    private var quietSince: [String: Date] = [:]

    /// `holdSeconds` is the trade-off: long enough that the gap between two songs does not flicker the
    /// notch, short enough to feel immediate next to the 2–7 s macOS needs to report a pause.
    public init(floorDB: Double = -75, holdSeconds: TimeInterval = 1.0) {
        self.floorDB = floorDB
        self.holdSeconds = holdSeconds
    }

    /// Feed the latest peak (dBFS/dBTP) of every live tap slot; get back the keys silent long enough.
    public mutating func update(peaks: [String: Double], now: Date) -> Set<String> {
        var silent: Set<String> = []
        for (key, db) in peaks {
            if db < floorDB {
                let since = quietSince[key] ?? now
                quietSince[key] = since
                if now.timeIntervalSince(since) >= holdSeconds { silent.insert(key) }
            } else {
                quietSince[key] = nil
            }
        }
        for key in quietSince.keys where peaks[key] == nil { quietSince[key] = nil }   // slot went away
        return silent
    }

    public mutating func reset() { quietSince.removeAll() }
}
