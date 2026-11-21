// SPDX-License-Identifier: MPL-2.0
import Foundation
import CoreAudio
import AudioToolbox
import AppKit
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

public struct MirrorOutputTarget: Equatable, Sendable {
    public let device: AudioDeviceDescriptor
    public let delayMs: Double

    public init(device: AudioDeviceDescriptor, delayMs: Double) {
        self.device = device
        self.delayMs = min(max(delayMs, 0.0), 250.0)
    }
}

public final class ProcessTapEngine: @unchecked Sendable {
    public static let aggregateUIDPrefix = "dev.v1torres.timbr.agg."

    private final class TapSlot {
        let key: String
        let tapID: AudioObjectID
        let aggregateID: AudioObjectID
        let aggregateUID: String
        let ioProcID: AudioDeviceIOProcID
        let enginePtr: OpaquePointer
        let sampleRate: Double
        let deviceUID: String
        let processObjects: Set<AudioObjectID>

        init(
            key: String,
            tapID: AudioObjectID,
            aggregateID: AudioObjectID,
            aggregateUID: String,
            ioProcID: AudioDeviceIOProcID,
            enginePtr: OpaquePointer,
            sampleRate: Double,
            deviceUID: String,
            processObjects: Set<AudioObjectID>
        ) {
            self.key = key
            self.tapID = tapID
            self.aggregateID = aggregateID
            self.aggregateUID = aggregateUID
            self.ioProcID = ioProcID
            self.enginePtr = enginePtr
            self.sampleRate = sampleRate
            self.deviceUID = deviceUID
            self.processObjects = processObjects
        }
    }

    private let lock = NSLock()
    private var dspEngine: OpaquePointer? // Fallback/shared curve evaluator & primary metrics
    private var activeSlots: [String: TapSlot] = [:]
    private var lastZeroBufferRecoveryAt: Date = .distantPast
    private var consecutiveZeroBuffers: UInt64 = 0

    public private(set) var lastSampleRate: Double = 48000
    public private(set) var tccAudioCaptureDeniedOrZeroed: Bool = false

    public var activeTapCount: Int {
        lock.lock()
        let count = activeSlots.count
        lock.unlock()
        return count
    }

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

    public static func translatePIDsToProcessObjects(_ pids: [pid_t]) -> [AudioObjectID] {
        var result: [AudioObjectID] = []
        var seen = Set<AudioObjectID>()
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslatePIDToProcessObject,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: 0
        )
        for pid in pids where pid > 0 {
            var qPid = pid
            var procObj = AudioObjectID(kAudioObjectUnknown)
            var size = UInt32(MemoryLayout<AudioObjectID>.size)
            let err = AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &addr,
                UInt32(MemoryLayout<pid_t>.size),
                &qPid,
                &size,
                &procObj
            )
            if err == noErr, procObj != AudioObjectID(kAudioObjectUnknown), !seen.contains(procObj) {
                seen.insert(procObj)
                result.append(procObj)
            }
        }
        return result
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

    public func updateDSP(preset: TimbrePreset, outputDevice: AudioDeviceDescriptor?, abMode: ABCompareMode, gain: Double = 1.0, delayMs: Double = 0.0) {
        lock.lock()
        let fallbackEng = dspEngine
        let primarySlot = activeSlots["global"] ?? activeSlots.values.first
        let sr = outputDevice?.sampleRate ?? lastSampleRate
        lock.unlock()

        if let fallbackEng {
            applyPreset(to: fallbackEng, preset: preset, outputDevice: outputDevice, sampleRate: sr, abMode: abMode, gain: gain, delayMs: delayMs)
        }
        if let primarySlot {
            applyPreset(to: primarySlot.enginePtr, preset: preset, outputDevice: outputDevice, sampleRate: primarySlot.sampleRate, abMode: abMode, gain: gain, delayMs: delayMs)
        }
    }

    private func applyPreset(
        to enginePtr: OpaquePointer,
        preset: TimbrePreset,
        outputDevice: AudioDeviceDescriptor?,
        sampleRate: Double,
        abMode: ABCompareMode,
        gain: Double,
        delayMs: Double
    ) {
        var cfg = timbre_dsp_default_config(sampleRate, 1024)
        cfg.limiter_ceiling_dbtp = outputDevice?.recommendedLimiterCeilingDBTP ?? preset.limiterCeilingDBTP
        cfg.limiter_enabled = true
        cfg.crossfeed_enabled = preset.crossfeedEnabled
        cfg.delay_ms = delayMs
        timbre_dsp_update_config(enginePtr, cfg)

        let bands = preset.allEffectiveBands.map { $0.cBand }
        bands.withUnsafeBufferPointer { buf in
            timbre_dsp_set_bands(enginePtr, buf.baseAddress, UInt32(buf.count))
        }
        timbre_dsp_set_ab_mode(enginePtr, abMode.cType)
        timbre_dsp_set_output_gain(enginePtr, gain)
    }

    public func readTelemetry() -> DSPTelemetrySnapshot {
        lock.lock()
        let eng = activeSlots["global"]?.enginePtr ?? activeSlots.values.first?.enginePtr ?? dspEngine
        lock.unlock()
        guard let eng else { return .idle }

        let m = timbre_dsp_get_metrics(eng)
        if m.zero_buffer_streak > 250 && Date().timeIntervalSince(lastZeroBufferRecoveryAt) > 30.0 {
            lastZeroBufferRecoveryAt = Date()
            tccAudioCaptureDeniedOrZeroed = activeTapCount > 0
        } else if m.zero_buffer_streak == 0 {
            tccAudioCaptureDeniedOrZeroed = false
        }

        var bins = [Float](repeating: -120, count: Int(TIMBRE_SPECTRUM_BINS))
        bins.withUnsafeMutableBufferPointer { buf in
            timbre_dsp_copy_spectrum(eng, buf.baseAddress, UInt32(buf.count))
        }
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

    // Legacy single-tap compatibility entry point
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
        let dummyPreset = TimbrePreset(name: "Active")
        return reconcileMultiTap(
            processingEnabled: true,
            preset: dummyPreset,
            abMode: .full,
            outputDevice: outputDevice,
            sources: [],
            excludedBundleIDs: excludedBundleIDs,
            duckFactor: 1.0,
            mirrorOutputs: []
        )
    }

    /// Full multi-tap orchestrator:
    /// - Invariant P1: 0 taps when processingEnabled == false or completely neutral.
    /// - Per-app isolated Process Taps (`stereoMixdownOfProcesses`) for apps with custom gain or mute.
    /// - Global exclusion tap (`stereoGlobalTapButExcludeProcesses`) excluding VoIP/DAW + per-app tapped processes.
    /// - Simultaneous multi-output mirror taps (`muteBehavior = .unmuted`) with ms delay alignment and BT drift guard.
    @discardableResult
    public func reconcileMultiTap(
        processingEnabled: Bool,
        preset: TimbrePreset,
        abMode: ABCompareMode,
        outputDevice: AudioDeviceDescriptor?,
        sources: [AudioSourceDescriptor],
        excludedBundleIDs: [String],
        duckFactor: Double = 1.0,
        mirrorOutputs: [MirrorOutputTarget] = []
    ) -> Bool {
        guard processingEnabled, let outputDevice else {
            stopAndDestroyTap()
            return true
        }

        if let sr = outputDevice.sampleRate as Double?, sr > 1000 {
            lastSampleRate = sr
        }

        // Translate protected VoIP/DAW PIDs + self PID so global taps never capture them
        let voipPIDs = sources.filter { $0.isVoIPExcluded || excludedBundleIDs.contains($0.bundleID) }.flatMap { $0.pids }
        let selfPID = ProcessInfo.processInfo.processIdentifier
        let baseExcludedPIDs = voipPIDs + [selfPID]
        let baseExcludedObjs = Self.translatePIDsToProcessObjects(baseExcludedPIDs)

        // Determine per-app isolated taps for non-VoIP active sources with custom volume or mute
        let customSources = sources.filter { src in
            !src.isVoIPExcluded && !src.pids.isEmpty && (src.isMuted || abs(src.volume - 1.0) > 0.01)
        }

        var desiredKeys = Set<String>()
        var allSuccess = true

        // 1. Per-app isolated taps
        var perAppObjs: [AudioObjectID] = []
        for src in customSources {
            let objs = Self.translatePIDsToProcessObjects(src.pids)
            guard !objs.isEmpty else { continue }
            perAppObjs.append(contentsOf: objs)
            let key = "app:\(src.bundleID)"
            desiredKeys.insert(key)
            let targetGain = src.isMuted ? 0.0 : (src.volume * duckFactor)
            let ok = ensureTapSlot(
                key: key,
                outputDevice: outputDevice,
                mode: .includeProcesses(objs),
                muteBehavior: .mutedWhenTapped,
                preset: preset,
                abMode: abMode,
                gain: targetGain,
                delayMs: 0.0,
                excludedBundleIDs: excludedBundleIDs
            )
            if !ok { allSuccess = false }
        }

        // 2. Primary global destination tap (when EQ, crossfeed, or ducking is active for remaining apps)
        let eqActive = preset.allEffectiveBands.contains { $0.enabled && abs($0.gainDB) > 0.01 }
        let needsGlobal = eqActive || preset.crossfeedEnabled || duckFactor < 0.999
        if needsGlobal {
            let globalExcludes = Array(Set(baseExcludedObjs + perAppObjs))
            desiredKeys.insert("global")
            let ok = ensureTapSlot(
                key: "global",
                outputDevice: outputDevice,
                mode: .excludeProcesses(globalExcludes),
                muteBehavior: .mutedWhenTapped,
                preset: preset,
                abMode: abMode,
                gain: duckFactor,
                delayMs: 0.0,
                excludedBundleIDs: excludedBundleIDs
            )
            if !ok { allSuccess = false }
        }

        // 3. Simultaneous multi-output mirror taps (E-04 / B-201)
        for target in mirrorOutputs where target.device.uid != outputDevice.uid {
            let key = "mirror:\(target.device.uid)"
            desiredKeys.insert(key)
            let ok = ensureTapSlot(
                key: key,
                outputDevice: target.device,
                mode: .excludeProcesses(baseExcludedObjs),
                muteBehavior: .unmuted,
                preset: preset,
                abMode: abMode,
                gain: duckFactor,
                delayMs: target.delayMs,
                excludedBundleIDs: excludedBundleIDs
            )
            if !ok { allSuccess = false }
        }

        // Tear down any stale slots no longer in desiredKeys
        lock.lock()
        let staleKeys = activeSlots.keys.filter { !desiredKeys.contains($0) }
        var toDestroy: [TapSlot] = []
        for k in staleKeys {
            if let slot = activeSlots.removeValue(forKey: k) {
                toDestroy.append(slot)
            }
        }
        lock.unlock()
        for slot in toDestroy {
            destroySlot(slot)
        }

        return allSuccess
    }

    private enum TapProcessMode {
        case includeProcesses([AudioObjectID])
        case excludeProcesses([AudioObjectID])
    }

    private func ensureTapSlot(
        key: String,
        outputDevice: AudioDeviceDescriptor,
        mode: TapProcessMode,
        muteBehavior: CATapMuteBehavior,
        preset: TimbrePreset,
        abMode: ABCompareMode,
        gain: Double,
        delayMs: Double,
        excludedBundleIDs: [String]
    ) -> Bool {
        let objSet: Set<AudioObjectID> = {
            switch mode {
            case .includeProcesses(let arr): return Set(arr)
            case .excludeProcesses(let arr): return Set(arr)
            }
        }()

        lock.lock()
        let existing = activeSlots[key]
        lock.unlock()

        if let existing,
           existing.deviceUID == outputDevice.uid,
           abs(existing.sampleRate - outputDevice.sampleRate) <= 1.0,
           existing.processObjects == objSet {
            applyPreset(
                to: existing.enginePtr,
                preset: preset,
                outputDevice: outputDevice,
                sampleRate: existing.sampleRate,
                abMode: abMode,
                gain: gain,
                delayMs: delayMs
            )
            return true
        }

        if let existing {
            lock.lock()
            activeSlots.removeValue(forKey: key)
            lock.unlock()
            destroySlot(existing)
        }

        if #available(macOS 14.2, *) {
            lock.lock()
            let activeUIDs = Set(activeSlots.values.map { $0.aggregateUID })
            lock.unlock()
            _ = OrphanedTapCleanup.cleanupOrphanedAggregates(excludingUIDs: activeUIDs)

            let tapDesc: CATapDescription
            switch mode {
            case .includeProcesses(let objs):
                tapDesc = CATapDescription(stereoMixdownOfProcesses: objs)
            case .excludeProcesses(let objs):
                tapDesc = CATapDescription(stereoGlobalTapButExcludeProcesses: objs)
            }
            tapDesc.name = "timbr.tap.\(key).\(outputDevice.uid)"
            tapDesc.isPrivate = true
            tapDesc.isExclusive = true
            tapDesc.muteBehavior = muteBehavior
            if case .excludeProcesses = mode, tapDesc.responds(to: NSSelectorFromString("setBundleIDs:")) {
                var excludes = excludedBundleIDs
                if let selfID = Bundle.main.bundleIdentifier { excludes.append(selfID) }
                tapDesc.setValue(excludes, forKey: "bundleIDs")
            }

            var tapID = AudioObjectID(kAudioObjectUnknown)
            let tapErr = AudioHardwareCreateProcessTap(tapDesc, &tapID)
            guard tapErr == noErr, tapID != AudioObjectID(kAudioObjectUnknown) else {
                return false
            }

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

            let cfg = timbre_dsp_default_config(outputDevice.sampleRate, 1024)
            guard let enginePtr = timbre_dsp_create(cfg) else {
                AudioHardwareDestroyAggregateDevice(aggID)
                AudioHardwareDestroyProcessTap(tapID)
                return false
            }
            applyPreset(
                to: enginePtr,
                preset: preset,
                outputDevice: outputDevice,
                sampleRate: outputDevice.sampleRate,
                abMode: abMode,
                gain: gain,
                delayMs: delayMs
            )

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
                timbre_dsp_destroy(enginePtr)
                AudioHardwareDestroyAggregateDevice(aggID)
                AudioHardwareDestroyProcessTap(tapID)
                return false
            }

            let startErr = AudioDeviceStart(aggID, procID)
            guard startErr == noErr else {
                AudioDeviceDestroyIOProcID(aggID, procID)
                timbre_dsp_destroy(enginePtr)
                AudioHardwareDestroyAggregateDevice(aggID)
                AudioHardwareDestroyProcessTap(tapID)
                return false
            }

            let slot = TapSlot(
                key: key,
                tapID: tapID,
                aggregateID: aggID,
                aggregateUID: aggregateUID,
                ioProcID: procID,
                enginePtr: enginePtr,
                sampleRate: outputDevice.sampleRate,
                deviceUID: outputDevice.uid,
                processObjects: objSet
            )
            lock.lock()
            activeSlots[key] = slot
            lock.unlock()
            return true
        }
        return false
    }

    private func destroySlot(_ slot: TapSlot) {
        AudioDeviceStop(slot.aggregateID, slot.ioProcID)
        AudioDeviceDestroyIOProcID(slot.aggregateID, slot.ioProcID)
        AudioHardwareDestroyAggregateDevice(slot.aggregateID)
        if #available(macOS 14.2, *) {
            AudioHardwareDestroyProcessTap(slot.tapID)
        }
        timbre_dsp_destroy(slot.enginePtr)
    }

    public func stopAndDestroyTap() {
        lock.lock()
        let slots = Array(activeSlots.values)
        activeSlots.removeAll()
        lock.unlock()

        for slot in slots {
            destroySlot(slot)
        }
    }
}
