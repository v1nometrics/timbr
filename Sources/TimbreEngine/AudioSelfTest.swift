// SPDX-License-Identifier: MPL-2.0
// End-to-end measurement of the per-app volume path, run inside the signed app (which holds the
// System Audio Recording grant): `Timbr --selftest-audio <report.json>`.
//
// It plays a known tone with afplay (a child process, so timbr. is its responsible app), drives the
// real ProcessTapEngine exactly like the UI does, and measures with two independent unmuted taps:
//   • SOURCE  — a tap on afplay itself: the signal before timbr. touches it;
//   • OUTPUT  — a tap on timbr.'s own process: what timbr. actually sends to the output device.
// gain = 20·log10(rms(OUTPUT) / rms(SOURCE)). Nothing here is simulated (AGENTS.md: no invented results).
import Foundation
import CoreAudio
import AudioToolbox
import TimbreCore

public enum AudioSelfTest {
    public struct Case: Codable, Sendable {
        public let name: String
        public let requestedVolume: Double
        public let muted: Bool
        public let toneDBFS: Double
        public let expectedGainDB: Double?
        public let sourceRMSdBFS: Double
        public let outputRMSdBFS: Double
        public let outputPeakdBFS: Double
        public let measuredGainDB: Double
        public let pass: Bool
        public let note: String
    }

    public struct Report: Codable, Sendable {
        public let date: Date
        public let outputDevice: String
        public let sampleRate: Double
        public let cases: [Case]
        public let engineFailure: String?
        public let allPassed: Bool
    }

    // MARK: Meter (written by one IOProc, read by the main thread after a settle period)

    struct MeterState {
        var sumSq: Double = 0
        var count: Double = 0
        var peak: Double = 0
    }

    final class MeterTap {
        let tapID: AudioObjectID
        let aggID: AudioObjectID
        let procID: AudioDeviceIOProcID
        let state: UnsafeMutablePointer<MeterState>

        /// `exclusive`: tap every process except `processes` (a global meter).
        init?(processes: [AudioObjectID], deviceUID: String, exclusive: Bool = false) {
            let desc = exclusive ? CATapDescription(stereoGlobalTapButExcludeProcesses: processes)
                                 : CATapDescription(stereoMixdownOfProcesses: processes)
            desc.name = "timbr.selftest.meter"
            desc.isPrivate = true
            desc.muteBehavior = .unmuted
            var tap = AudioObjectID(kAudioObjectUnknown)
            guard AudioHardwareCreateProcessTap(desc, &tap) == noErr, tap != kAudioObjectUnknown else { return nil }
            let agg: [String: Any] = [
                kAudioAggregateDeviceNameKey as String: "timbr.selftest",
                kAudioAggregateDeviceUIDKey as String: "\(ProcessTapEngine.aggregateUIDPrefix)selftest.\(UUID().uuidString)",
                kAudioAggregateDeviceMainSubDeviceKey as String: deviceUID,
                kAudioAggregateDeviceSubDeviceListKey as String: [[kAudioSubDeviceUIDKey as String: deviceUID]],
                kAudioAggregateDeviceTapListKey as String: [[kAudioSubTapUIDKey as String: desc.uuid.uuidString, kAudioSubTapDriftCompensationKey as String: false]],
                kAudioAggregateDeviceIsPrivateKey as String: true,
                kAudioAggregateDeviceIsStackedKey as String: false,
            ]
            var aggID = AudioObjectID(kAudioObjectUnknown)
            guard AudioHardwareCreateAggregateDevice(agg as CFDictionary, &aggID) == noErr else {
                AudioHardwareDestroyProcessTap(tap); return nil
            }
            let st = UnsafeMutablePointer<MeterState>.allocate(capacity: 1)
            st.initialize(to: MeterState())
            var pid: AudioDeviceIOProcID?
            let err = AudioDeviceCreateIOProcIDWithBlock(&pid, aggID, nil) { _, input, _, output, _ in
                let outABL = UnsafeMutableAudioBufferListPointer(output)
                for b in outABL { if let d = b.mData { memset(d, 0, Int(b.mDataByteSize)) } }   // meter is silent
                let inABL = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
                guard let last = inABL.last, let d = last.mData?.assumingMemoryBound(to: Float.self) else { return }
                let n = Int(last.mDataByteSize) / MemoryLayout<Float>.size
                var s = 0.0, p = 0.0
                for i in 0..<n { let v = Double(d[i]); s += v * v; p = max(p, abs(v)) }
                st.pointee.sumSq += s
                st.pointee.count += Double(n)
                st.pointee.peak = max(st.pointee.peak, p)
            }
            guard err == noErr, let pid, AudioDeviceStart(aggID, pid) == noErr else {
                AudioHardwareDestroyAggregateDevice(aggID); AudioHardwareDestroyProcessTap(tap)
                st.deallocate(); return nil
            }
            tapID = tap; self.aggID = aggID; procID = pid; state = st
        }

        func reset() { state.pointee = MeterState() }
        var rmsDB: Double { state.pointee.count > 0 ? 20 * log10(max(1e-9, (state.pointee.sumSq / state.pointee.count).squareRoot())) : -180 }
        var peakDB: Double { 20 * log10(max(1e-9, state.pointee.peak)) }

        func stop() {
            AudioDeviceStop(aggID, procID)
            AudioDeviceDestroyIOProcID(aggID, procID)
            AudioHardwareDestroyAggregateDevice(aggID)
            AudioHardwareDestroyProcessTap(tapID)
            state.deallocate()
        }
    }

    // MARK: Run

    @MainActor
    public static func run(reportURL: URL) async -> Report {
        let hal = HALManager()
        let devices = hal.enumerateDevices()
        guard let out = devices.first(where: { $0.isDefaultOutput && $0.outputChannels > 0 }) else {
            return finish(Report(date: Date(), outputDevice: "—", sampleRate: 0, cases: [], engineFailure: "No default output device", allPassed: false), reportURL)
        }

        // (name, volume, muted, tone dBFS, expected gain dB; nil = must be silent)
        let plan: [(String, Double, Bool, Double, Double?)] = [
            ("volume 50 %", 0.5, false, -20, -6.02),
            ("volume 25 %", 0.25, false, -20, -12.04),
            ("boost 200 % (headroom available)", 2.0, false, -20, 6.02),
            ("boost 150 %", 1.5, false, -20, 3.52),
            ("mute", 1.0, true, -20, nil),
            ("boost 200 % on a near-full-scale tone (limiter must hold the ceiling)", 2.0, false, -1, nil),
        ]

        let engine = ProcessTapEngine(sampleRate: out.sampleRate)
        var cases: [Case] = []
        for (name, vol, muted, tone, expected) in plan {
            let wav = FileManager.default.temporaryDirectory.appendingPathComponent("timbr-selftest-\(Int(-tone)).wav")
            writeTone(to: wav, dBFS: tone, seconds: 4, sampleRate: 48000)
            let player = Process()
            player.executableURL = URL(fileURLWithPath: "/usr/bin/afplay")
            player.arguments = [wav.path]
            do { try player.run() } catch {
                cases.append(Case(name: name, requestedVolume: vol, muted: muted, toneDBFS: tone, expectedGainDB: expected, sourceRMSdBFS: -180, outputRMSdBFS: -180, outputPeakdBFS: -180, measuredGainDB: 0, pass: false, note: "afplay failed: \(error)"))
                continue
            }
            defer { player.terminate() }
            // Wait for afplay's process object to start output.
            var objs: [AudioObjectID] = []
            for _ in 0..<40 {
                objs = ProcessTapEngine.translatePIDsToProcessObjects([player.processIdentifier])
                if let o = objs.first, isRunningOutput(o) { break }
                try? await Task.sleep(for: .milliseconds(50))
            }
            let selfObjs = ProcessTapEngine.translatePIDsToProcessObjects([ProcessInfo.processInfo.processIdentifier])
            guard !objs.isEmpty, !selfObjs.isEmpty,
                  let srcMeter = MeterTap(processes: objs, deviceUID: out.uid) else {
                cases.append(Case(name: name, requestedVolume: vol, muted: muted, toneDBFS: tone, expectedGainDB: expected, sourceRMSdBFS: -180, outputRMSdBFS: -180, outputPeakdBFS: -180, measuredGainDB: 0, pass: false, note: "could not create the source meter (System Audio Recording permission?)"))
                continue
            }
            // Baseline first: a second tap on a process that timbr. is already tapping (muted) stops
            // receiving audio, so the source level is measured before the engine takes the process.
            try? await Task.sleep(for: .milliseconds(300))
            srcMeter.reset()
            try? await Task.sleep(for: .milliseconds(800))
            let src = srcMeter.rmsDB
            srcMeter.stop()
            let source = AudioSourceDescriptor(bundleID: "selftest.afplay", name: "afplay", pids: [player.processIdentifier], volume: vol, isMuted: muted, isPlaying: true)
            let ok = engine.reconcileMultiTap(processingEnabled: true, preset: TimbrePreset(name: "Self-test flat"), abMode: .full,
                                              outputDevice: out, sources: [source], excludedBundleIDs: [], duckFactor: 1.0, mirrorOutputs: [])
            guard let outMeter = MeterTap(processes: selfObjs, deviceUID: out.uid) else {
                engine.stopAndDestroyTap()
                cases.append(Case(name: name, requestedVolume: vol, muted: muted, toneDBFS: tone, expectedGainDB: expected, sourceRMSdBFS: -180, outputRMSdBFS: -180, outputPeakdBFS: -180, measuredGainDB: 0, pass: false, note: "could not create the output meter"))
                continue
            }
            try? await Task.sleep(for: .milliseconds(500))   // taps settle, de-zipper and limiter release
            outMeter.reset()
            try? await Task.sleep(for: .milliseconds(1200))
            let outRMS = outMeter.rmsDB, outPeak = outMeter.peakDB
            outMeter.stop()
            engine.stopAndDestroyTap()

            let gain = outRMS - src
            var pass: Bool
            var note: String
            if !ok {
                pass = false; note = "engine: \(engine.lastFailure ?? "reconcile failed")"
            } else if src < -60 {
                pass = false; note = "source meter read silence — no permission or afplay not playing"
            } else if muted {
                pass = outRMS < -80; note = pass ? "silent as expected" : "audio leaked through mute"
            } else if let e = expected {
                pass = abs(gain - e) <= 0.5; note = pass ? "within ±0.5 dB" : "off by \(String(format: "%.2f", gain - e)) dB"
            } else {
                // Limiter case: output must rise but never exceed the ceiling (+0.1 dB for the 4× true-peak estimate).
                let ceiling = out.recommendedLimiterCeilingDBTP
                pass = outPeak <= ceiling + 0.1 && gain > 0
                note = "peak \(String(format: "%.2f", outPeak)) dBFS vs ceiling \(String(format: "%.1f", ceiling)) dBTP — loud material cannot get much louder without clipping"
            }
            cases.append(Case(name: name, requestedVolume: vol, muted: muted, toneDBFS: tone, expectedGainDB: expected,
                              sourceRMSdBFS: src, outputRMSdBFS: outRMS, outputPeakdBFS: outPeak, measuredGainDB: gain, pass: pass, note: note))
            try? await Task.sleep(for: .milliseconds(200))
        }
        return finish(Report(date: Date(), outputDevice: out.name, sampleRate: out.sampleRate, cases: cases,
                             engineFailure: engine.lastFailure, allPassed: !cases.isEmpty && cases.allSatisfy(\.pass)), reportURL)
    }

    static func finish(_ r: Report, _ url: URL) -> Report {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        try? enc.encode(r).write(to: url)
        return r
    }

    static func isRunningOutput(_ obj: AudioObjectID) -> Bool {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioProcessPropertyIsRunningOutput, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var v: UInt32 = 0
        var s = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(obj, &addr, 0, nil, &s, &v) == noErr && v != 0
    }

    /// 1 kHz stereo sine, 16-bit PCM WAV, identical L/R.
    static func writeTone(to url: URL, dBFS: Double, seconds: Double, sampleRate: Int) {
        let frames = Int(Double(sampleRate) * seconds)
        let amp = pow(10, dBFS / 20) * 32767
        var data = Data()
        func le<T: FixedWidthInteger>(_ v: T) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
        data.append(contentsOf: Array("RIFF".utf8)); le(UInt32(36 + frames * 4))
        data.append(contentsOf: Array("WAVE".utf8)); data.append(contentsOf: Array("fmt ".utf8))
        le(UInt32(16)); le(UInt16(1)); le(UInt16(2)); le(UInt32(sampleRate)); le(UInt32(sampleRate * 4)); le(UInt16(4)); le(UInt16(16))
        data.append(contentsOf: Array("data".utf8)); le(UInt32(frames * 4))
        for i in 0..<frames {
            let v = Int16(clamping: Int((amp * sin(2 * Double.pi * 1000 * Double(i) / Double(sampleRate))).rounded()))
            le(v); le(v)
        }
        try? data.write(to: url)
    }
}
