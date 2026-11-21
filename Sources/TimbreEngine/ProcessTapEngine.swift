// SPDX-License-Identifier: MPL-2.0
import Foundation
import AppKit
import CoreAudio
import AudioToolbox
import CTimbreDSP
import TimbreCore

public struct DSPTelemetrySnapshot: Sendable {
    public let preampDB: Double
    public let truePeakL: Double
    public let truePeakR: Double
    public let lufsMomentary: Double
    public let limiterGR: Double
    public let limiterActive: Bool
    public let clipPreventedCount: UInt64
    public let cpuMicroseconds: Double
    public let spectrumBinsDB: [Float]

    public static let idle = DSPTelemetrySnapshot(
        preampDB: 0, truePeakL: -120, truePeakR: -120, lufsMomentary: -120,
        limiterGR: 0, limiterActive: false, clipPreventedCount: 0, cpuMicroseconds: 0,
        spectrumBinsDB: [Float](repeating: -120, count: Int(TIMBRE_SPECTRUM_BINS))
    )
}

/// Destroys orphaned private Core Audio aggregate devices left behind by a crash
/// or SIGKILL (adapted from AbhisekGanguly/AudioRouter, MIT), so a leaked
/// `.mutedWhenTapped` tap cannot leave applications silently muted.
public enum OrphanedTapCleanup {
    public static func isOrphanedAggregateUID(_ uid: String, activeUIDs: Set<String> = []) -> Bool {
        uid.hasPrefix(ProcessTapEngine.aggregateUIDPrefix) && !activeUIDs.contains(uid)
    }

    @discardableResult
    public static func cleanupOrphanedAggregates(excludingUIDs: Set<String> = []) -> Int {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: 0
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size) == noErr,
              size > 0 else { return 0 }

        let count = Int(size) / MemoryLayout<AudioObjectID>.size
        var deviceIDs = [AudioObjectID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &deviceIDs) == noErr else {
            return 0
        }

        var destroyed = 0
        for devID in deviceIDs {
            var transport: UInt32 = 0
            var tSize = UInt32(MemoryLayout<UInt32>.size)
            var tAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyTransportType,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: 0
            )
            guard AudioObjectHasProperty(devID, &tAddr),
                  AudioObjectGetPropertyData(devID, &tAddr, 0, nil, &tSize, &transport) == noErr,
                  transport == kAudioDeviceTransportTypeAggregate else {
                continue
            }

            var uidCF: CFString?
            var uSize = UInt32(MemoryLayout<CFString?>.size)
            var uAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: 0
            )
            let uidErr = withUnsafeMutablePointer(to: &uidCF) { ptr in
                AudioObjectGetPropertyData(devID, &uAddr, 0, nil, &uSize, ptr)
            }
            guard uidErr == noErr, let uid = uidCF as String? else { continue }
            guard isOrphanedAggregateUID(uid, activeUIDs: excludingUIDs) else { continue }

            if AudioHardwareDestroyAggregateDevice(devID) == noErr {
                destroyed += 1
            }
        }
        return destroyed
    }
}

public final class ProcessTapEngine: @unchecked Sendable {
    public static let aggregateUIDPrefix = "dev.v1torres.timbr.agg."

    private let lock = NSLock()
    private var dspEngine: OpaquePointer? // timbre_dsp_engine_t*
    private var activeTapID: AudioObjectID = AudioObjectID(kAudioObjectUnknown)
    private var activeAggregateID: AudioObjectID = AudioObjectID(kAudioObjectUnknown)
    private var activeAggregateUID: String?
    private var ioProcID: AudioDeviceIOProcID?
    private var isTapRunning = false
    private var lastZeroBufferRecoveryAt: Date = .distantPast
    private var consecutiveZeroBuffers: UInt64 = 0

    public private(set) var lastSampleRate: Double = 48000
    public private(set) var tccAudioCaptureDeniedOrZeroed: Bool = false

    public init(sampleRate: Double = 48000) {
        self.lastSampleRate = sampleRate
        let cfg = timbre_dsp_default_config(sampleRate, 1024)
        self.dspEngine = timbre_dsp_create(cfg)
        _ = OrphanedTapCleanup.cleanupOrphanedAggregates()
    }

    deinit {
        stopAndDestroyTap()
        lock.lock()
        if let dsp = dspEngine {
            timbre_dsp_destroy(dsp)
            dspEngine = nil
        }
        lock.unlock()
    }

    public func enumerateRunningAudioSources(existing: [AudioSourceDescriptor] = []) -> [AudioSourceDescriptor] {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: 0
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size) == noErr,
              size > 0 else { return existing }

        let count = Int(size) / MemoryLayout<AudioObjectID>.size
        var procIDs = [AudioObjectID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &procIDs) == noErr else {
            return existing
        }

        let selfPID = ProcessInfo.processInfo.processIdentifier
        let runningApps = Dictionary(uniqueKeysWithValues: NSWorkspace.shared.runningApplications.compactMap { app -> (Int32, NSRunningApplication)? in
            (app.processIdentifier, app)
        })

        var grouped: [String: AudioSourceDescriptor] = Dictionary(uniqueKeysWithValues: existing.map { ($0.bundleID, $0) })

        for objID in procIDs {
            var pid: pid_t = 0
            var pidSize = UInt32(MemoryLayout<pid_t>.size)
            var pidAddr = AudioObjectPropertyAddress(mSelector: kAudioProcessPropertyPID, mScope: kAudioObjectPropertyScopeGlobal, mElement: 0)
            guard AudioObjectGetPropertyData(objID, &pidAddr, 0, nil, &pidSize, &pid) == noErr,
                  pid != selfPID else { continue }

            var runningOut: UInt32 = 0
            var runSize = UInt32(MemoryLayout<UInt32>.size)
            var runAddr = AudioObjectPropertyAddress(mSelector: kAudioProcessPropertyIsRunningOutput, mScope: kAudioObjectPropertyScopeGlobal, mElement: 0)
            _ = AudioObjectGetPropertyData(objID, &runAddr, 0, nil, &runSize, &runningOut)

            var cfBundle: CFString?
            var bSize = UInt32(MemoryLayout<CFString?>.size)
            var bAddr = AudioObjectPropertyAddress(mSelector: kAudioProcessPropertyBundleID, mScope: kAudioObjectPropertyScopeGlobal, mElement: 0)
            _ = withUnsafeMutablePointer(to: &cfBundle) { ptr in
                AudioObjectGetPropertyData(objID, &bAddr, 0, nil, &bSize, ptr)
            }
            let rawBundle = (cfBundle as String?) ?? runningApps[pid]?.bundleIdentifier ?? "pid.\(pid)"
            // Group WebKit / Chromium helper subprocesses cleanly under parent identifier when possible
            let bundleID = normalizeHelperBundleID(rawBundle)
            let appName = runningApps[pid]?.localizedName ?? bundleID.components(separatedBy: ".").last ?? bundleID
            let isPlaying = runningOut != 0
            let voipProtected = GuardianAnalyzer.isVoIPOrDAWProtected(bundleID: bundleID)

            if var cur = grouped[bundleID] {
                if !cur.pids.contains(pid) { cur.pids.append(pid) }
                cur.isPlaying = cur.isPlaying || isPlaying
                if isPlaying { cur.lastActiveAt = Date() }
                cur.isVoIPExcluded = voipProtected
                grouped[bundleID] = cur
            } else if isPlaying {
                grouped[bundleID] = AudioSourceDescriptor(
                    bundleID: bundleID,
                    name: appName,
                    pids: [pid],
                    volume: 1.0,
                    isMuted: false,
                    isPlaying: true,
                    isVoIPExcluded: voipProtected
                )
            }
        }

        // Order: playing now -> muted -> recent (last 10 min)
        let cutoff = Date().addingTimeInterval(-600)
        return grouped.values
            .filter { $0.isPlaying || $0.isMuted || $0.lastActiveAt > cutoff }
            .sorted {
                if $0.isPlaying != $1.isPlaying { return $0.isPlaying && !$1.isPlaying }
                if $0.isMuted != $1.isMuted { return $0.isMuted && !$1.isMuted }
                return $0.lastActiveAt > $1.lastActiveAt
            }
    }

    private func normalizeHelperBundleID(_ id: String) -> String {
        if id.contains("com.apple.WebKit") { return "com.apple.Safari" }
        if id.contains("com.google.Chrome.helper") { return "com.google.Chrome" }
        if id.contains("company.thebrowser.Browser.helper") { return "company.thebrowser.Browser" }
        return id
    }

    public func updateDSP(preset: TimbrePreset, outputDevice: AudioDeviceDescriptor?, abMode: ABCompareMode, gain: Double = 1.0) {
        lock.lock()
        guard let eng = dspEngine else { lock.unlock(); return }
        var cfg = timbre_dsp_default_config(outputDevice?.sampleRate ?? lastSampleRate, 1024)
        cfg.limiter_ceiling_dbtp = outputDevice?.recommendedLimiterCeilingDBTP ?? preset.limiterCeilingDBTP
        cfg.limiter_enabled = true
        cfg.crossfeed_enabled = preset.crossfeedEnabled
        timbre_dsp_update_config(eng, cfg)

        let bands = preset.allEffectiveBands.map { $0.cBand }
        bands.withUnsafeBufferPointer { buf in
            timbre_dsp_set_bands(eng, buf.baseAddress, UInt32(buf.count))
        }
        timbre_dsp_set_ab_mode(eng, abMode.cType)
        timbre_dsp_set_output_gain(eng, gain)
        lock.unlock()
    }

    public func readTelemetry() -> DSPTelemetrySnapshot {
        lock.lock()
        guard let eng = dspEngine else { lock.unlock(); return .idle }
        let m = timbre_dsp_get_metrics(eng)
        var bins = [Float](repeating: -120, count: Int(TIMBRE_SPECTRUM_BINS))
        bins.withUnsafeMutableBufferPointer { buf in
            timbre_dsp_copy_spectrum(eng, buf.baseAddress, UInt32(buf.count))
        }
        lock.unlock()
        return DSPTelemetrySnapshot(
            preampDB: m.preamp_db,
            truePeakL: m.true_peak_l_dbtp,
            truePeakR: m.true_peak_r_dbtp,
            lufsMomentary: m.lufs_momentary,
            limiterGR: m.limiter_gr_db,
            limiterActive: m.limiter_active,
            clipPreventedCount: m.clip_prevented_count,
            cpuMicroseconds: Double(m.process_ns_last) / 1000.0,
            spectrumBinsDB: bins
        )
    }

    public func evaluateCurve(bands: [EQBand], freqsHz: [Double], layer: EQLayer? = nil) -> (magDB: [Double], recommendedPreampDB: Double) {
        let cBands = bands.map { $0.cBand }
        var mags = [Double](repeating: 0, count: freqsHz.count)
        var preamp = 0.0
        let mask = layer?.cType ?? TIMBRE_LAYER_ALL
        cBands.withUnsafeBufferPointer { bPtr in
            freqsHz.withUnsafeBufferPointer { fPtr in
                mags.withUnsafeMutableBufferPointer { mPtr in
                    timbre_dsp_eval_response(
                        bPtr.baseAddress, UInt32(bPtr.count),
                        lastSampleRate,
                        fPtr.baseAddress, UInt32(fPtr.count),
                        mPtr.baseAddress, nil,
                        mask, &preamp, 0.5
                    )
                }
            }
        }
        return (mags, preamp)
    }

    // Reconciles tap lifecycle: P1 invariant — 0 taps if bypass or no processing needed
    @discardableResult
    public func reconcileTap(
        processingEnabled: Bool,
        outputDevice: AudioDeviceDescriptor?,
        needsDestinationTap: Bool,
        excludedBundleIDs: [String]
    ) -> Bool {
        guard processingEnabled, needsDestinationTap, let outputDevice else {
            stopAndDestroyTap()
            return true
        }

        lock.lock()
        let alreadyRunning = isTapRunning
        let srChanged = abs(lastSampleRate - outputDevice.sampleRate) > 1.0
        lock.unlock()

        if alreadyRunning && !srChanged {
            return true
        }
        stopAndDestroyTap()
        return startDestinationTap(outputDevice: outputDevice, excludedBundleIDs: excludedBundleIDs)
    }

    private func startDestinationTap(outputDevice: AudioDeviceDescriptor, excludedBundleIDs: [String]) -> Bool {
        if #available(macOS 14.2, *) {
            lock.lock()
            let excluded = activeAggregateUID.map { Set([$0]) } ?? []
            lock.unlock()
            _ = OrphanedTapCleanup.cleanupOrphanedAggregates(excludingUIDs: excluded)
            // Global tap excluding self + VoIP/DAW safe ignore list (C-02)
            let tapDesc = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
            tapDesc.name = "timbr.tap.\(outputDevice.uid)"
            tapDesc.isPrivate = true
            tapDesc.isExclusive = true
            tapDesc.muteBehavior = .mutedWhenTapped
            if #available(macOS 26.0, *) {
                var excludes = excludedBundleIDs
                if let selfID = Bundle.main.bundleIdentifier { excludes.append(selfID) }
                tapDesc.bundleIDs = excludes
            }

            var tapID = AudioObjectID(kAudioObjectUnknown)
            let tapErr = AudioHardwareCreateProcessTap(tapDesc, &tapID)
            guard tapErr == noErr, tapID != AudioObjectID(kAudioObjectUnknown) else {
                return false
            }

            // Build private aggregate device pairing outputDevice + tap
            // Drift correction explicitly disabled for Bluetooth (E-04 / RNF)
            let subDevDict: [String: Any] = [
                kAudioSubDeviceUIDKey as String: outputDevice.uid,
                kAudioSubDeviceDriftCompensationKey as String: !outputDevice.transport.isBluetooth
            ]
            let tapEntry: [String: Any] = [
                kAudioSubTapUIDKey as String: tapDesc.uuid.uuidString,
                kAudioSubTapDriftCompensationKey as String: false
            ]
            let aggregateUID = "\(Self.aggregateUIDPrefix)\(UUID().uuidString)"
            let aggDesc: [String: Any] = [
                kAudioAggregateDeviceNameKey as String: "timbr.agg.\(outputDevice.name)",
                kAudioAggregateDeviceUIDKey as String: aggregateUID,
                kAudioAggregateDeviceMainSubDeviceKey as String: outputDevice.uid,
                kAudioAggregateDeviceSubDeviceListKey as String: [subDevDict],
                kAudioAggregateDeviceTapListKey as String: [tapEntry],
                kAudioAggregateDeviceIsPrivateKey as String: true,
                kAudioAggregateDeviceIsStackedKey as String: false
            ]

            var aggID = AudioObjectID(kAudioObjectUnknown)
            let aggErr = AudioHardwareCreateAggregateDevice(aggDesc as CFDictionary, &aggID)
            guard aggErr == noErr, aggID != AudioObjectID(kAudioObjectUnknown) else {
                AudioHardwareDestroyProcessTap(tapID)
                return false
            }

            lock.lock()
            lastSampleRate = outputDevice.sampleRate
            guard let enginePtr = dspEngine else {
                lock.unlock()
                AudioHardwareDestroyAggregateDevice(aggID)
                AudioHardwareDestroyProcessTap(tapID)
                return false
            }
            lock.unlock()

            var procID: AudioDeviceIOProcID?
            // RT Audio Thread: captures ONLY OpaquePointer (enginePtr) — zero Swift ARC retain/release, zero locks, zero heap allocs
            let ioErr = AudioDeviceCreateIOProcIDWithBlock(&procID, aggID, nil) { _, inInputData, _, outOutputData, _ in
                let inABL = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inInputData))
                let outABL = UnsafeMutableAudioBufferListPointer(outOutputData)
                guard let inBuf = inABL.first, let outBuf = outABL.first,
                      let inPtr = inBuf.mData?.assumingMemoryBound(to: Float.self),
                      let outPtr = outBuf.mData?.assumingMemoryBound(to: Float.self) else { return }

                let frames = outBuf.mDataByteSize / UInt32(MemoryLayout<Float>.size * 2)
                timbre_dsp_process_interleaved_f32(enginePtr, inPtr, outPtr, frames)
            }

            guard ioErr == noErr, let procID else {
                AudioHardwareDestroyAggregateDevice(aggID)
                AudioHardwareDestroyProcessTap(tapID)
                return false
            }

            let startErr = AudioDeviceStart(aggID, procID)
            guard startErr == noErr else {
                AudioDeviceDestroyIOProcID(aggID, procID)
                AudioHardwareDestroyAggregateDevice(aggID)
                AudioHardwareDestroyProcessTap(tapID)
                return false
            }

            lock.lock()
            activeTapID = tapID
            activeAggregateID = aggID
            activeAggregateUID = aggregateUID
            ioProcID = procID
            isTapRunning = true
            lock.unlock()
            return true
        }
        return false
    }

    public func stopAndDestroyTap() {
        lock.lock()
        let agg = activeAggregateID
        let tap = activeTapID
        let proc = ioProcID
        activeAggregateID = AudioObjectID(kAudioObjectUnknown)
        activeAggregateUID = nil
        activeTapID = AudioObjectID(kAudioObjectUnknown)
        ioProcID = nil
        isTapRunning = false
        lock.unlock()

        if agg != AudioObjectID(kAudioObjectUnknown) {
            if let proc {
                AudioDeviceStop(agg, proc)
                AudioDeviceDestroyIOProcID(agg, proc)
            }
            AudioHardwareDestroyAggregateDevice(agg)
        }
        if tap != AudioObjectID(kAudioObjectUnknown) {
            if #available(macOS 14.2, *) {
                AudioHardwareDestroyProcessTap(tap)
            }
        }
    }

    private func recordPotentialZeroBuffer() {
        consecutiveZeroBuffers += 1
        if consecutiveZeroBuffers > 250 && Date().timeIntervalSince(lastZeroBufferRecoveryAt) > 30.0 {
            lastZeroBufferRecoveryAt = Date()
            tccAudioCaptureDeniedOrZeroed = true
        }
    }

    private func resetZeroBufferCounter() {
        consecutiveZeroBuffers = 0
        tccAudioCaptureDeniedOrZeroed = false
    }
}
