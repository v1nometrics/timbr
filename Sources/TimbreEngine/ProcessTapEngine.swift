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
/// `.mutedWhenTapped` tap cannot leave applications silently muted. Deliberate mutes are not
/// aggregates of this process: they live in `timbr-mute-keeper` (ADR-0017), under their own UID prefix.
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
    /// Mutes that must outlive this process (ADR-0017): held by `timbr-mute-keeper`, a separate
    /// process. Not touched by `stopAndDestroyTap()`. nil in tests and self-tests.
    public let muteKeeper: MuteKeeperClient?
    private var dspEngine: OpaquePointer? // Fallback/shared curve evaluator & primary metrics
    private var activeSlots: [String: TapSlot] = [:]
    /// Last parameter signature published to each DSP engine (main thread). Publishing only on
    /// change keeps the 2 s refresh and fader drags from re-sending identical EQ parameters.
    private var publishedSignature: [OpaquePointer: Int] = [:]
    /// Human-readable reason of the last tap/aggregate failure, for the event log (nil = healthy).
    public private(set) var lastFailure: String?
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

    public init(sampleRate: Double = 48000, muteKeeper: MuteKeeperClient? = nil) {
        self.muteKeeper = muteKeeper
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

    /// True while any of these Core Audio process objects still has output running. One property read
    /// each (no PID translation, which is a round trip to coreaudiod per process). An object that has
    /// disappeared fails the read and counts as stopped, which is right: its process is gone.
    public static func isAnyObjectOutputting(_ objects: [AudioObjectID]) -> Bool {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioProcessPropertyIsRunningOutput, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        for obj in objects {
            var v: UInt32 = 0
            var size = UInt32(MemoryLayout<UInt32>.size)
            if AudioObjectGetPropertyData(obj, &addr, 0, nil, &size, &v) == noErr, v != 0 { return true }
        }
        return false
    }

    /// True while any of these processes still has Core Audio output running. A handful of property
    /// reads: cheap enough to ask four times a second, unlike re-enumerating every audio process.
    public static func isAnyProcessOutputting(pids: [pid_t]) -> Bool {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioProcessPropertyIsRunningOutput, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        for obj in translatePIDsToProcessObjects(pids) {
            var v: UInt32 = 0
            var size = UInt32(MemoryLayout<UInt32>.size)
            if AudioObjectGetPropertyData(obj, &addr, 0, nil, &size, &v) == noErr, v != 0 { return true }
        }
        return false
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

    public func enumerateRunningAudioSources(existing: [AudioSourceDescriptor] = [], recentlyStarted: Set<AudioObjectID> = []) -> [AudioSourceDescriptor] {
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
        let runningApps = Dictionary(NSWorkspace.shared.runningApplications.map { ($0.processIdentifier, $0) },
                                     uniquingKeysWith: { first, _ in first })

        // Keep user state (volume, mute, routing, recency) but recompute what is live on every pass:
        // a source is "playing" only if one of its processes is outputting audio right now.
        var grouped: [String: AudioSourceDescriptor] = [:]
        for var prev in existing {
            prev.isPlaying = false
            prev.pids = []
            grouped[prev.bundleID] = prev
        }

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

            // Attribute helper processes (Chromium/Electron helpers, WebKit GPU processes, XPC
            // audio services) to the app the user actually sees.
            let owner = AudioProcessAttribution.owner(of: pid, reportedBundleID: cfBundle as String?, runningApps: runningApps)
            guard owner.pid != selfPID else { continue }
            let bundleID = owner.bundleID
            // Dictation tools keep a silent output engine running: never "playing" (SilentOutputApps).
            let silentUtility = SilentOutputApps.contains(bundleID)
            let isPlaying = runningOut != 0 && !silentUtility
            // Started and already finished since the last pass (e.g. a short alert): recent, not playing.
            let justPlayed = !isPlaying && !silentUtility && recentlyStarted.contains(objID)
            let voipProtected = GuardianAnalyzer.isVoIPOrDAWProtected(bundleID: bundleID)

            if var cur = grouped[bundleID] {
                if !cur.pids.contains(pid) { cur.pids.append(pid) }
                if isPlaying {
                    cur.isPlaying = true
                    cur.lastActiveAt = Date()
                } else if justPlayed {
                    cur.lastActiveAt = Date()
                }
                cur.name = owner.name
                cur.isVoIPExcluded = voipProtected
                grouped[bundleID] = cur
            } else if isPlaying || justPlayed {
                grouped[bundleID] = AudioSourceDescriptor(
                    bundleID: bundleID,
                    name: owner.name,
                    pids: [pid],
                    volume: 1.0,
                    isMuted: false,
                    isPlaying: isPlaying,
                    isVoIPExcluded: voipProtected
                )
            }
        }

        let now = Date()
        for key in grouped.keys {
            if grouped[key]!.isPlaying {
                if grouped[key]!.playingSince == nil { grouped[key]!.playingSince = now }
            } else {
                grouped[key]!.playingSince = nil
            }
        }
        // Order: playing now (newest run first) -> muted -> recent (last 10 min)
        let cutoff = now.addingTimeInterval(-600)
        return grouped.values
            .filter { $0.isPlaying || $0.isMuted || $0.lastActiveAt > cutoff }
            .sorted(by: AudioSourceDescriptor.displayOrder)
    }

    public func updateDSP(preset: TimbrePreset, outputDevice: AudioDeviceDescriptor?, abMode: ABCompareMode, gain: Double = 1.0, delayMs: Double = 0.0) {
        lock.lock()
        let fallbackEng = dspEngine
        // Only the global slot carries the global gain; per-app slots get their own gain in reconcile.
        let primarySlot = activeSlots["global"]
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

        let effective = preset.allEffectiveBands
        var h = Hasher()
        h.combine(sampleRate); h.combine(cfg.limiter_ceiling_dbtp); h.combine(cfg.crossfeed_enabled); h.combine(delayMs)
        h.combine(effective)
        let signature = h.finalize()
        if publishedSignature[enginePtr] != signature {
            publishedSignature[enginePtr] = signature
            let bands = effective.map { $0.cBand }
            bands.withUnsafeBufferPointer { buf in
                timbre_dsp_update(enginePtr, cfg, buf.baseAddress, UInt32(buf.count))   // one publish, wait-free for the audio thread
            }
        }
        // Gain and A/B are single atomics: always safe to set.
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

    public func hasSlot(forKey key: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return activeSlots[key] != nil
    }

    /// Latest peak (max of L/R true peak, dB) of every live slot, keyed by slot key
    /// (`global`, `app:<bundleID>`, `mirror:<uid>`). The DSP updates it every block, so silence shows up
    /// within ~20 ms, long before Core Audio reports that an app stopped playing.
    public func slotPeaks() -> [String: Double] {
        lock.lock()
        let slots = activeSlots.map { ($0.key, $0.value.enginePtr) }
        lock.unlock()
        var out: [String: Double] = [:]
        for (key, eng) in slots {
            let m = timbre_dsp_get_metrics(eng)
            out[key] = max(m.true_peak_l_dbtp, m.true_peak_r_dbtp)
        }
        return out
    }

    /// Limiter gain reduction (dB, ≤ 0) of every per-app slot, keyed by bundle ID. A boosted app
    /// whose limiter is working hard is already as loud as it can get without distortion.
    public func limiterReductionByApp() -> [String: Double] {
        lock.lock()
        let slots = activeSlots.filter { $0.key.hasPrefix("app:") }.map { (String($0.key.dropFirst(4)), $0.value.enginePtr) }
        var out: [String: Double] = [:]
        for (bid, eng) in slots { out[bid] = timbre_dsp_get_metrics(eng).limiter_gr_db }
        lock.unlock()
        return out
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
            mirrorOutputs: [],
            manageMutes: false
        )
    }

    /// Full multi-tap orchestrator:
    /// - Invariant P1: 0 taps when processingEnabled == false or completely neutral.
    /// - Fail-closed mutes handed to `timbr-mute-keeper` (ADR-0017); in-process gain-0 slots until it confirms.
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
        mirrorOutputs: [MirrorOutputTarget] = [],
        audioActive: Bool = true,
        forceGlobalTap: Bool = false,
        manageMutes: Bool = true
    ) -> Bool {
        // Fail-closed mutes (ADR-0017): hand the silenced apps to the keeper. Until it confirms an app,
        // timbr keeps muting that app itself (below), so there is no instant where nobody holds it.
        let keeper = manageMutes ? muteKeeper : nil
        let muteTargets = keeper == nil ? [] : sources.compactMap(MuteKeeperClient.target(for:))
        keeper?.publish(muteTargets)
        let keeperHolds = keeper?.confirmedHeld() ?? []

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

        // Silenced apps (muted or at 0 %) stay out of the global and mirror taps, by process and by
        // bundle ID, or those taps would capture and replay them.
        let silenced = sources.filter { PersistentMutePolicy.isSilenced($0) }
        let silencedObjs = Self.translatePIDsToProcessObjects(silenced.flatMap { $0.pids })
        let silencedBundleIDs = muteTargets.flatMap(\.bundleIDs) + silenced.map(\.bundleID)
        let tapExcludedBundleIDs = Array(Set(excludedBundleIDs + silencedBundleIDs)).sorted()

        // Per-app isolated taps: custom audible volume, or silenced and not (yet) held by the keeper.
        let customSources = sources.filter { src in
            guard !src.isVoIPExcluded, !src.pids.isEmpty else { return false }
            if PersistentMutePolicy.isSilenced(src) { return !keeperHolds.contains(src.bundleID) }
            return abs(src.volume - 1.0) > 0.01
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
            let targetGain = PersistentMutePolicy.isSilenced(src) ? 0.0 : src.volume * duckFactor
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
        // The global tap only exists while something is actually playing (plus a grace period decided
        // by the caller). Idle, it would keep the purple "recording" indicator lit and make apps that
        // watch for audio input (e.g. superwhisper's meeting detection) think a meeting started.
        let needsGlobal = (eqActive || preset.crossfeedEnabled || duckFactor < 0.999 || forceGlobalTap) && audioActive
        if needsGlobal {
            let globalExcludes = Array(Set(baseExcludedObjs + perAppObjs + silencedObjs))
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
                excludedBundleIDs: tapExcludedBundleIDs
            )
            if !ok { allSuccess = false }
        }

        // 3. Simultaneous multi-output mirror taps (E-04 / B-201) — unmuted; failure must NOT
        // tear down the primary muted path (mirrors are best-effort). Apps the user muted are
        // excluded so they stay silent on the mirror too. (Known limit: other per-app volumes
        // are not replicated on mirrors.)
        let mirrorExcludes = Array(Set(baseExcludedObjs + silencedObjs))
        var mirrorFailed = false
        for target in mirrorOutputs where target.device.uid != outputDevice.uid {
            let key = "mirror:\(target.device.uid)"
            desiredKeys.insert(key)
            let ok = ensureTapSlot(
                key: key,
                outputDevice: target.device,
                mode: .excludeProcesses(mirrorExcludes),
                muteBehavior: .unmuted,
                preset: preset,
                abMode: abMode,
                gain: duckFactor,
                delayMs: target.delayMs,
                excludedBundleIDs: tapExcludedBundleIDs
            )
            if !ok {
                mirrorFailed = true
                desiredKeys.remove(key)
            }
        }

        // If any mutedWhenTapped slot failed, roll back muted taps so apps are never
        // left silent without a working global path (P1 / orphaned-mute invariant).
        // Mirror-only failures do not trigger this rollback.
        if !allSuccess {
            lock.lock()
            let rollbackKeys = activeSlots.keys.filter {
                desiredKeys.contains($0) && ($0.hasPrefix("app:") || $0 == "global")
            }
            var rollback: [TapSlot] = []
            for k in rollbackKeys {
                if let slot = activeSlots.removeValue(forKey: k) {
                    rollback.append(slot)
                    desiredKeys.remove(k)
                }
            }
            lock.unlock()
            for slot in rollback { destroySlot(slot) }
        }
        if mirrorFailed { allSuccess = false }
        if allSuccess { lastFailure = nil }

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
            // Do NOT touch isExclusive here. The initialisers already set it correctly:
            // stereoMixdownOfProcesses → false (tap ONLY these), stereoGlobalTapButExcludeProcesses →
            // true (tap everything EXCEPT these). Forcing it to true turned every per-app tap into
            // "every other app", so moving one app's fader changed all the others instead.
            tapDesc.muteBehavior = muteBehavior
            if case .excludeProcesses = mode, tapDesc.responds(to: NSSelectorFromString("setBundleIDs:")) {
                var excludes = excludedBundleIDs
                if let selfID = Bundle.main.bundleIdentifier { excludes.append(selfID) }
                tapDesc.setValue(excludes, forKey: "bundleIDs")
            }

            var tapID = AudioObjectID(kAudioObjectUnknown)
            let tapErr = AudioHardwareCreateProcessTap(tapDesc, &tapID)
            guard tapErr == noErr, tapID != AudioObjectID(kAudioObjectUnknown) else {
                lastFailure = "AudioHardwareCreateProcessTap(\(key)) = \(Self.describe(tapErr))"
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
                lastFailure = "AudioHardwareCreateAggregateDevice(\(key)) = \(Self.describe(aggErr))"
                AudioHardwareDestroyProcessTap(tapID)
                return false
            }

            let cfg = timbre_dsp_default_config(outputDevice.sampleRate, 1024)
            guard let enginePtr = timbre_dsp_create(cfg) else {
                lastFailure = "timbre_dsp_create(\(key)) failed"
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
                TapRenderer.render(enginePtr, inInputData, outOutputData)
            }

            guard ioErr == noErr, let procID else {
                lastFailure = "AudioDeviceCreateIOProcIDWithBlock(\(key)) = \(Self.describe(ioErr))"
                timbre_dsp_destroy(enginePtr)
                AudioHardwareDestroyAggregateDevice(aggID)
                AudioHardwareDestroyProcessTap(tapID)
                return false
            }

            let startErr = AudioDeviceStart(aggID, procID)
            guard startErr == noErr else {
                lastFailure = "AudioDeviceStart(\(key)) = \(Self.describe(startErr))"
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
        lastFailure = "Process taps need macOS 14.2 or later"
        return false
    }

    static func describe(_ status: OSStatus) -> String {
        let n = UInt32(bitPattern: status)
        let bytes = [UInt8((n >> 24) & 0xFF), UInt8((n >> 16) & 0xFF), UInt8((n >> 8) & 0xFF), UInt8(n & 0xFF)]
        if bytes.allSatisfy({ $0 >= 32 && $0 < 127 }), let s = String(bytes: bytes, encoding: .ascii) { return "'\(s)' (\(status))" }
        return "\(status)"
    }

    private func destroySlot(_ slot: TapSlot) {
        publishedSignature[slot.enginePtr] = nil
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

/// Real-time render for one tap slot. No allocation, no locks, no Swift reference counting.
/// Handles whatever stream layout the aggregate presents instead of assuming "first buffer, stereo".
enum TapRenderer {
    static func render(_ engine: OpaquePointer,
                       _ input: UnsafePointer<AudioBufferList>,
                       _ output: UnsafeMutablePointer<AudioBufferList>) {
        let inABL = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
        let outABL = UnsafeMutableAudioBufferListPointer(output)
        // Anything we do not write must be silence, never stale memory.
        for b in outABL {
            if let d = b.mData { memset(d, 0, Int(b.mDataByteSize)) }
        }
        guard inABL.count > 0, outABL.count > 0 else { return }

        // Input: the tap's streams come after any input streams of the sub-device, so read from the end.
        // Stereo mixdown arrives as one interleaved 2-channel buffer, or as two mono buffers.
        let fsz = UInt32(MemoryLayout<Float>.size)
        let last = inABL[inABL.count - 1]
        guard let lastData = last.mData?.assumingMemoryBound(to: Float.self), last.mNumberChannels > 0 else { return }
        let inL: UnsafePointer<Float>
        let inR: UnsafePointer<Float>
        let inStride: UInt32
        let inFrames: UInt32
        if last.mNumberChannels >= 2 {
            inL = UnsafePointer(lastData)
            inR = UnsafePointer(lastData + 1)
            inStride = last.mNumberChannels
            inFrames = last.mDataByteSize / fsz / last.mNumberChannels
        } else if inABL.count >= 2, inABL[inABL.count - 2].mNumberChannels == 1,
                  let l = inABL[inABL.count - 2].mData?.assumingMemoryBound(to: Float.self) {
            inL = UnsafePointer(l)
            inR = UnsafePointer(lastData)
            inStride = 1
            inFrames = min(last.mDataByteSize, inABL[inABL.count - 2].mDataByteSize) / fsz
        } else {
            inL = UnsafePointer(lastData)
            inR = UnsafePointer(lastData)
            inStride = 1
            inFrames = last.mDataByteSize / fsz
        }
        guard inFrames > 0 else { return }

        // Output: L/R on channels 0/1 of the first stream (interleaved N channels), or on the first
        // two mono streams (planar), or a mono mix on a single mono stream.
        let o0 = outABL[0]
        guard let d0 = o0.mData?.assumingMemoryBound(to: Float.self), o0.mNumberChannels > 0 else { return }
        if o0.mNumberChannels >= 2 {
            let frames = min(inFrames, o0.mDataByteSize / fsz / o0.mNumberChannels)
            timbre_dsp_process_strided_f32(engine, inL, inR, inStride, d0, d0 + 1, o0.mNumberChannels, frames)
        } else if outABL.count >= 2, outABL[1].mNumberChannels == 1, let d1 = outABL[1].mData?.assumingMemoryBound(to: Float.self) {
            let frames = min(inFrames, o0.mDataByteSize / fsz, outABL[1].mDataByteSize / fsz)
            timbre_dsp_process_strided_f32(engine, inL, inR, inStride, d0, d1, 1, frames)
        } else {
            let frames = min(inFrames, o0.mDataByteSize / fsz)
            timbre_dsp_process_strided_f32(engine, inL, inR, inStride, d0, nil, 1, frames)
        }
    }
}
