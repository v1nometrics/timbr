// SPDX-License-Identifier: MPL-2.0
import Foundation
import CoreAudio
import AudioToolbox
import TimbreCore

public struct SystemAudioSnapshot: Codable, Sendable {
    public let defaultOutputUID: String?
    public let defaultInputUID: String?
    public let outputVolumeScalar: Float32?
    public let outputMuted: Bool?
    public let capturedAt: Date
}

private struct PersistedHALSnapshot: Codable, Sendable {
    let snapshot: SystemAudioSnapshot
    let modifiedOutputUID: Bool
    let modifiedInputUID: Bool
    let modifiedOutputVolume: Bool
}

public final class HALManager: @unchecked Sendable {
    private let lock = NSLock()
    private var initialSnapshot: SystemAudioSnapshot?
    private var modifiedOutputUID = false
    private var modifiedInputUID = false
    private var modifiedOutputVolume = false
    private let snapshotFileURL: URL
    private let watchdogQueue = DispatchQueue(label: "dev.v1torres.timbr.hal-watchdog")
    private var watchdogInstalled = false
    private var devicesListenerBlock: AudioObjectPropertyListenerBlock?
    private var defaultOutListenerBlock: AudioObjectPropertyListenerBlock?

    public init(snapshotFileURL: URL? = nil) {
        if let snapshotFileURL {
            self.snapshotFileURL = snapshotFileURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.snapshotFileURL = appSupport.appendingPathComponent("dev.v1torres.timbr/hal-snapshot.json")
        }
    }

    deinit {
        stopSystemWatchdog()
    }

    public func startSystemWatchdog(onChange: @escaping @Sendable () -> Void) {
        lock.lock()
        guard !watchdogInstalled else { lock.unlock(); return }
        watchdogInstalled = true
        let devBlock: AudioObjectPropertyListenerBlock = { _, _ in onChange() }
        let outBlock: AudioObjectPropertyListenerBlock = { _, _ in onChange() }
        devicesListenerBlock = devBlock
        defaultOutListenerBlock = outBlock
        lock.unlock()

        var devAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var outAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &devAddr, watchdogQueue, devBlock)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &outAddr, watchdogQueue, outBlock)
    }

    public func stopSystemWatchdog() {
        lock.lock()
        guard watchdogInstalled else { lock.unlock(); return }
        watchdogInstalled = false
        let devBlock = devicesListenerBlock
        let outBlock = defaultOutListenerBlock
        devicesListenerBlock = nil
        defaultOutListenerBlock = nil
        lock.unlock()

        var devAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var outAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        if let devBlock {
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &devAddr, watchdogQueue, devBlock)
        }
        if let outBlock {
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &outAddr, watchdogQueue, outBlock)
        }
    }

    public func enumerateDevices() -> [AudioDeviceDescriptor] {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size) == noErr,
              size > 0 else { return [] }
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &ids) == noErr else {
            return []
        }

        let defOut = getUInt32Prop(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultOutputDevice)
        let defIn = getUInt32Prop(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultInputDevice)

        return ids.compactMap { id -> AudioDeviceDescriptor? in
            guard let uid = getStringProp(id, kAudioDevicePropertyDeviceUID) else { return nil }
            // Our own private aggregates are plumbing, not devices: never list them (they would show up
            // as outputs, could be picked as mirrors and churn the device list on every tap change).
            if uid.hasPrefix(ProcessTapEngine.aggregateUIDPrefix) { return nil }
            let name = getStringProp(id, kAudioObjectPropertyName) ?? uid
            let mfr = getStringProp(id, kAudioObjectPropertyManufacturer) ?? ""
            let isHidden = (getUInt32Prop(id, kAudioDevicePropertyIsHidden) ?? 0) != 0
            if isHidden { return nil }

            let rawTransport = getUInt32Prop(id, kAudioDevicePropertyTransportType)
            let inCh = channelCount(id, kAudioObjectPropertyScopeInput)
            let outCh = channelCount(id, kAudioObjectPropertyScopeOutput)
            let sr = getFloat64Prop(id, kAudioDevicePropertyNominalSampleRate) ?? 48000
            let rates = nominalRates(id)
            let srSet = isSettable(id, kAudioDevicePropertyNominalSampleRate, kAudioObjectPropertyScopeGlobal)
            let volMain = isSettable(id, kAudioDevicePropertyVolumeScalar, kAudioObjectPropertyScopeOutput, 0)
            let volCh1 = isSettable(id, kAudioDevicePropertyVolumeScalar, kAudioObjectPropertyScopeOutput, 1)
            let muteOut = isSettable(id, kAudioDevicePropertyMute, kAudioObjectPropertyScopeOutput, 0)
            let hogSet = isSettable(id, kAudioDevicePropertyHogMode, kAudioObjectPropertyScopeGlobal)
            let latOut = getUInt32Prop(id, kAudioDevicePropertyLatency, kAudioObjectPropertyScopeOutput) ?? 0
            let safeOut = getUInt32Prop(id, kAudioDevicePropertySafetyOffset, kAudioObjectPropertyScopeOutput) ?? 0

            let transport = mapTransport(rawTransport, sampleRate: sr, inCh: inCh, outCh: outCh, name: name)
            return AudioDeviceDescriptor(
                uid: uid,
                audioObjectID: id,
                name: name,
                manufacturer: mfr,
                transport: transport,
                inputChannels: inCh,
                outputChannels: outCh,
                sampleRate: sr,
                availableRates: rates.isEmpty ? [sr] : rates,
                isSampleRateSettable: srSet,
                isHWVolumeMasterSettable: volMain,
                isHWVolumeChannelSettable: volCh1,
                isHWMuteSettable: muteOut,
                isHogModeSettable: hogSet,
                outputLatencyFrames: latOut,
                safetyOffsetFrames: safeOut,
                isDefaultOutput: id == defOut,
                isDefaultInput: id == defIn,
                analogImpedanceMode: (transport == .wiredAnalog && name.lowercased().contains("momentum")) ? .active470Ohm : nil
            )
        }
    }

    public func captureInitialSnapshotIfNeeded() {
        lock.lock()
        defer { lock.unlock() }
        guard initialSnapshot == nil else { return }
        let devices = enumerateDevices()
        let outDev = devices.first(where: { $0.isDefaultOutput })
        let inDev = devices.first(where: { $0.isDefaultInput })
        let vol = outDev.flatMap { readOutputVolumeScalar(deviceID: $0.audioObjectID) }
        let muted = outDev.flatMap { readOutputMute(deviceID: $0.audioObjectID) }
        initialSnapshot = SystemAudioSnapshot(
            defaultOutputUID: outDev?.uid,
            defaultInputUID: inDev?.uid,
            outputVolumeScalar: vol,
            outputMuted: muted,
            capturedAt: Date()
        )
    }

    private func persistSnapshotUnlocked() {
        guard let snap = initialSnapshot else { return }
        guard modifiedOutputUID || modifiedInputUID || modifiedOutputVolume else { return }
        let payload = PersistedHALSnapshot(
            snapshot: snap,
            modifiedOutputUID: modifiedOutputUID,
            modifiedInputUID: modifiedInputUID,
            modifiedOutputVolume: modifiedOutputVolume
        )
        try? FileManager.default.createDirectory(at: snapshotFileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(payload) {
            try? data.write(to: snapshotFileURL, options: .atomic)
        }
    }

    private func removePersistedSnapshot() {
        try? FileManager.default.removeItem(at: snapshotFileURL)
    }

    @discardableResult
    public func recoverLeftoverSnapshotIfPresent() -> Bool {
        guard let data = try? Data(contentsOf: snapshotFileURL),
              let persisted = try? JSONDecoder().decode(PersistedHALSnapshot.self, from: data) else {
            return false
        }
        applyRestore(
            snapshot: persisted.snapshot,
            restoreOut: persisted.modifiedOutputUID,
            restoreIn: persisted.modifiedInputUID,
            restoreVol: persisted.modifiedOutputVolume
        )
        removePersistedSnapshot()
        return true
    }

    public func restoreSnapshotIfModified() {
        lock.lock()
        let snap = initialSnapshot
        let restoreOut = modifiedOutputUID
        let restoreIn = modifiedInputUID
        let restoreVol = modifiedOutputVolume
        modifiedOutputUID = false
        modifiedInputUID = false
        modifiedOutputVolume = false
        lock.unlock()

        if let snap {
            applyRestore(snapshot: snap, restoreOut: restoreOut, restoreIn: restoreIn, restoreVol: restoreVol)
        }
        removePersistedSnapshot()
    }

    private func applyRestore(snapshot snap: SystemAudioSnapshot, restoreOut: Bool, restoreIn: Bool, restoreVol: Bool) {
        let devices = enumerateDevices()
        if restoreOut, let uid = snap.defaultOutputUID, let dev = devices.first(where: { $0.uid == uid }) {
            _ = setDefaultDevice(dev.audioObjectID, selector: kAudioHardwarePropertyDefaultOutputDevice)
        }
        if restoreIn, let uid = snap.defaultInputUID, let dev = devices.first(where: { $0.uid == uid }) {
            _ = setDefaultDevice(dev.audioObjectID, selector: kAudioHardwarePropertyDefaultInputDevice)
        }
        if restoreVol, let uid = snap.defaultOutputUID, let dev = devices.first(where: { $0.uid == uid }) {
            if let v = snap.outputVolumeScalar { _ = setOutputVolumeScalarRaw(deviceID: dev.audioObjectID, value: v) }
            if let m = snap.outputMuted { _ = setOutputMute(deviceID: dev.audioObjectID, muted: m) }
        }
    }

    @discardableResult
    public func setDefaultOutput(uid: String) -> Bool {
        captureInitialSnapshotIfNeeded()
        guard let dev = enumerateDevices().first(where: { $0.uid == uid }) else { return false }
        let ok = setDefaultDevice(dev.audioObjectID, selector: kAudioHardwarePropertyDefaultOutputDevice)
        if ok {
            lock.lock(); modifiedOutputUID = true; persistSnapshotUnlocked(); lock.unlock()
        }
        return ok
    }

    @discardableResult
    public func setDefaultInput(uid: String) -> Bool {
        captureInitialSnapshotIfNeeded()
        guard let dev = enumerateDevices().first(where: { $0.uid == uid }) else { return false }
        let ok = setDefaultDevice(dev.audioObjectID, selector: kAudioHardwarePropertyDefaultInputDevice)
        if ok {
            lock.lock(); modifiedInputUID = true; persistSnapshotUnlocked(); lock.unlock()
        }
        return ok
    }

    @discardableResult
    public func setOutputVolumeScalar(deviceID: AudioObjectID, value: Float32) -> Bool {
        captureInitialSnapshotIfNeeded()
        var clamped = min(max(value, 0.0), 1.0)
        for elem: AudioObjectPropertyElement in [0, 1, 2] {
            if isSettable(deviceID, kAudioDevicePropertyVolumeScalar, kAudioObjectPropertyScopeOutput, elem) {
                var addr = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyVolumeScalar,
                    mScope: kAudioObjectPropertyScopeOutput,
                    mElement: elem
                )
                let size = UInt32(MemoryLayout<Float32>.size)
                if AudioObjectSetPropertyData(deviceID, &addr, 0, nil, size, &clamped) == noErr {
                    if elem == 0 {
                        lock.lock(); modifiedOutputVolume = true; persistSnapshotUnlocked(); lock.unlock()
                        return true
                    }
                }
            }
        }
        return false
    }

    @discardableResult
    private func setOutputVolumeScalarRaw(deviceID: AudioObjectID, value: Float32) -> Bool {
        var clamped = min(max(value, 0.0), 1.0)
        for elem: AudioObjectPropertyElement in [0, 1, 2] {
            if isSettable(deviceID, kAudioDevicePropertyVolumeScalar, kAudioObjectPropertyScopeOutput, elem) {
                var addr = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyVolumeScalar,
                    mScope: kAudioObjectPropertyScopeOutput,
                    mElement: elem
                )
                let size = UInt32(MemoryLayout<Float32>.size)
                if AudioObjectSetPropertyData(deviceID, &addr, 0, nil, size, &clamped) == noErr, elem == 0 {
                    return true
                }
            }
        }
        return false
    }

    public func readOutputVolumeScalar(deviceID: AudioObjectID) -> Float32? {
        for elem: AudioObjectPropertyElement in [0, 1] {
            var addr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: elem
            )
            if AudioObjectHasProperty(deviceID, &addr) {
                var val: Float32 = 0
                var size = UInt32(MemoryLayout<Float32>.size)
                if AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &val) == noErr {
                    return val
                }
            }
        }
        return nil
    }

    public func readOutputMute(deviceID: AudioObjectID) -> Bool? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: 0
        )
        guard AudioObjectHasProperty(deviceID, &addr) else { return nil }
        var val: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &val) == noErr else { return nil }
        return val != 0
    }

    @discardableResult
    public func setOutputMute(deviceID: AudioObjectID, muted: Bool) -> Bool {
        guard isSettable(deviceID, kAudioDevicePropertyMute, kAudioObjectPropertyScopeOutput, 0) else { return false }
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: 0
        )
        var val: UInt32 = muted ? 1 : 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectSetPropertyData(deviceID, &addr, 0, nil, size, &val) == noErr
    }

    @discardableResult
    public func setSampleRate(deviceID: AudioObjectID, sampleRate: Double) -> Bool {
        guard isSettable(deviceID, kAudioDevicePropertyNominalSampleRate, kAudioObjectPropertyScopeGlobal, 0) else { return false }
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: 0
        )
        var sr = Float64(sampleRate)
        let size = UInt32(MemoryLayout<Float64>.size)
        return AudioObjectSetPropertyData(deviceID, &addr, 0, nil, size, &sr) == noErr
    }

    public func detectCompetingCaptureApps(devices: [AudioDeviceDescriptor]) -> [String] {
        var hits: [String] = []
        let keywords = ["Loopback", "SoundSource", "BlackHole", "BackgroundMusic", "eqMac"]
        for d in devices {
            for kw in keywords where d.name.localizedCaseInsensitiveContains(kw) {
                hits.append(d.name)
            }
        }
        return Array(Set(hits)).sorted()
    }

    private func setDefaultDevice(_ id: AudioObjectID, selector: AudioObjectPropertySelector) -> Bool {
        var addr = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: 0)
        var devID = id
        return AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, UInt32(MemoryLayout<AudioObjectID>.size), &devID) == noErr
    }

    private func mapTransport(_ t: UInt32?, sampleRate: Double, inCh: Int, outCh: Int, name: String) -> DeviceTransport {
        guard let t else { return .unknown }
        switch t {
        case kAudioDeviceTransportTypeBuiltIn:
            if name.localizedCaseInsensitiveContains("Headphones") || name.localizedCaseInsensitiveContains("External") {
                return .wiredAnalog
            }
            return .builtIn
        case kAudioDeviceTransportTypeUSB: return .usb
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
            return (inCh > 0 && outCh > 0 && sampleRate <= 16000) ? .bluetoothHFP : .bluetoothA2DP
        case kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort: return .hdmi
        case kAudioDeviceTransportTypeAggregate: return .aggregate
        case kAudioDeviceTransportTypeVirtual: return .virtual
        case kAudioDeviceTransportTypeContinuityCaptureWired, kAudioDeviceTransportTypeContinuityCaptureWireless: return .continuity
        default: return .unknown
        }
    }

    private func getStringProp(_ id: AudioObjectID, _ sel: AudioObjectPropertySelector) -> String? {
        var addr = AudioObjectPropertyAddress(mSelector: sel, mScope: kAudioObjectPropertyScopeGlobal, mElement: 0)
        guard AudioObjectHasProperty(id, &addr) else { return nil }
        var cfStr: CFString?
        var size = UInt32(MemoryLayout<CFString?>.size)
        let err = withUnsafeMutablePointer(to: &cfStr) { ptr in
            AudioObjectGetPropertyData(id, &addr, 0, nil, &size, ptr)
        }
        guard err == noErr, let s = cfStr else { return nil }
        return s as String
    }

    private func getUInt32Prop(_ id: AudioObjectID, _ sel: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> UInt32? {
        var addr = AudioObjectPropertyAddress(mSelector: sel, mScope: scope, mElement: 0)
        guard AudioObjectHasProperty(id, &addr) else { return nil }
        var val: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &val) == noErr else { return nil }
        return val
    }

    private func getFloat64Prop(_ id: AudioObjectID, _ sel: AudioObjectPropertySelector) -> Double? {
        var addr = AudioObjectPropertyAddress(mSelector: sel, mScope: kAudioObjectPropertyScopeGlobal, mElement: 0)
        guard AudioObjectHasProperty(id, &addr) else { return nil }
        var val: Float64 = 0
        var size = UInt32(MemoryLayout<Float64>.size)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &val) == noErr else { return nil }
        return val
    }

    private func isSettable(_ id: AudioObjectID, _ sel: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope, _ elem: AudioObjectPropertyElement = kAudioObjectPropertyElementMain) -> Bool {
        var addr = AudioObjectPropertyAddress(mSelector: sel, mScope: scope, mElement: elem)
        guard AudioObjectHasProperty(id, &addr) else { return false }
        var settable: DarwinBoolean = false
        return AudioObjectIsPropertySettable(id, &addr, &settable) == noErr && settable.boolValue
    }

    private func channelCount(_ id: AudioObjectID, _ scope: AudioObjectPropertyScope) -> Int {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreamConfiguration, mScope: scope, mElement: 0)
        guard AudioObjectHasProperty(id, &addr) else { return 0 }
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr, size > 0 else { return 0 }
        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, raw) == noErr else { return 0 }
        let abl = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
        return abl.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    private func nominalRates(_ id: AudioObjectID) -> [Double] {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyAvailableNominalSampleRates, mScope: kAudioObjectPropertyScopeGlobal, mElement: 0)
        guard AudioObjectHasProperty(id, &addr) else { return [] }
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr, size > 0 else { return [] }
        let count = Int(size) / MemoryLayout<AudioValueRange>.size
        var ranges = [AudioValueRange](repeating: AudioValueRange(), count: count)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &ranges) == noErr else { return [] }
        return Array(Set(ranges.map { $0.mMinimum })).sorted()
    }
}
