import Foundation
import CoreAudio
import AudioToolbox

func getStringProp(_ id: AudioObjectID, _ sel: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> String? {
    var addr = AudioObjectPropertyAddress(mSelector: sel, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    guard AudioObjectHasProperty(id, &addr) else { return nil }
    var cfStr: CFString?
    var size = UInt32(MemoryLayout<CFString?>.size)
    let err = withUnsafeMutablePointer(to: &cfStr) { ptr in
        AudioObjectGetPropertyData(id, &addr, 0, nil, &size, ptr)
    }
    guard err == noErr, let s = cfStr else { return nil }
    return s as String
}

func getUInt32Prop(_ id: AudioObjectID, _ sel: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> UInt32? {
    var addr = AudioObjectPropertyAddress(mSelector: sel, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    guard AudioObjectHasProperty(id, &addr) else { return nil }
    var val: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &val) == noErr else { return nil }
    return val
}

func getFloat64Prop(_ id: AudioObjectID, _ sel: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> Double? {
    var addr = AudioObjectPropertyAddress(mSelector: sel, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    guard AudioObjectHasProperty(id, &addr) else { return nil }
    var val: Float64 = 0
    var size = UInt32(MemoryLayout<Float64>.size)
    guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &val) == noErr else { return nil }
    return val
}

func isSettable(_ id: AudioObjectID, _ sel: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope, _ elem: AudioObjectPropertyElement = kAudioObjectPropertyElementMain) -> (has: Bool, settable: Bool) {
    var addr = AudioObjectPropertyAddress(mSelector: sel, mScope: scope, mElement: elem)
    guard AudioObjectHasProperty(id, &addr) else { return (false, false) }
    var s: DarwinBoolean = false
    let err = AudioObjectIsPropertySettable(id, &addr, &s)
    return (true, err == noErr && s.boolValue)
}

func channelCount(_ id: AudioObjectID, _ scope: AudioObjectPropertyScope) -> Int {
    var addr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreamConfiguration, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    guard AudioObjectHasProperty(id, &addr) else { return 0 }
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr, size > 0 else { return 0 }
    let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
    defer { raw.deallocate() }
    guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, raw) == noErr else { return 0 }
    let abl = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
    return abl.reduce(0) { $0 + Int($1.mNumberChannels) }
}

func nominalRates(_ id: AudioObjectID) -> [Double] {
    var addr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyAvailableNominalSampleRates, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    guard AudioObjectHasProperty(id, &addr) else { return [] }
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr, size > 0 else { return [] }
    let count = Int(size) / MemoryLayout<AudioValueRange>.size
    var ranges = [AudioValueRange](repeating: AudioValueRange(), count: count)
    guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &ranges) == noErr else { return [] }
    return ranges.map { $0.mMinimum }
}

func transportName(_ t: UInt32?) -> String {
    guard let t else { return "Unknown" }
    switch t {
    case kAudioDeviceTransportTypeBuiltIn: return "Built-in"
    case kAudioDeviceTransportTypeUSB: return "USB"
    case kAudioDeviceTransportTypeBluetooth: return "Bluetooth"
    case kAudioDeviceTransportTypeBluetoothLE: return "BluetoothLE"
    case kAudioDeviceTransportTypeVirtual: return "Virtual"
    case kAudioDeviceTransportTypeAggregate: return "Aggregate"
    case kAudioDeviceTransportTypeContinuityCaptureWired, kAudioDeviceTransportTypeContinuityCaptureWireless: return "Continuity"
    default: return String(format: "0x%08X", t)
    }
}

var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
var size: UInt32 = 0
AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size)
let count = Int(size) / MemoryLayout<AudioDeviceID>.size
var ids = [AudioDeviceID](repeating: 0, count: count)
AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &ids)

let defOut = getUInt32Prop(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultOutputDevice)
let defIn = getUInt32Prop(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultInputDevice)

var outList: [[String: Any]] = []
for id in ids {
    let name = getStringProp(id, kAudioObjectPropertyName) ?? "?"
    let uid = getStringProp(id, kAudioDevicePropertyDeviceUID) ?? "?"
    let mfr = getStringProp(id, kAudioObjectPropertyManufacturer) ?? "?"
    let transport = transportName(getUInt32Prop(id, kAudioDevicePropertyTransportType))
    let inCh = channelCount(id, kAudioObjectPropertyScopeInput)
    let outCh = channelCount(id, kAudioObjectPropertyScopeOutput)
    let sr = getFloat64Prop(id, kAudioDevicePropertyNominalSampleRate) ?? 0
    let srSet = isSettable(id, kAudioDevicePropertyNominalSampleRate, kAudioObjectPropertyScopeGlobal)
    let volOut = isSettable(id, kAudioDevicePropertyVolumeScalar, kAudioObjectPropertyScopeOutput, 0)
    let volOutCh1 = isSettable(id, kAudioDevicePropertyVolumeScalar, kAudioObjectPropertyScopeOutput, 1)
    let muteOut = isSettable(id, kAudioDevicePropertyMute, kAudioObjectPropertyScopeOutput, 0)
    let latOut = getUInt32Prop(id, kAudioDevicePropertyLatency, kAudioObjectPropertyScopeOutput) ?? 0
    let safeOut = getUInt32Prop(id, kAudioDevicePropertySafetyOffset, kAudioObjectPropertyScopeOutput) ?? 0
    let hogSet = isSettable(id, kAudioDevicePropertyHogMode, kAudioObjectPropertyScopeGlobal)

    outList.append([
        "id": id,
        "name": name,
        "uid": uid,
        "manufacturer": mfr,
        "transport": transport,
        "defaultOutput": id == defOut,
        "defaultInput": id == defIn,
        "inChannels": inCh,
        "outChannels": outCh,
        "sampleRate": sr,
        "availableRates": nominalRates(id),
        "sampleRateSettable": srSet.settable,
        "hwVolumeOutputMainSettable": volOut.settable,
        "hwVolumeOutputCh1Settable": volOutCh1.settable,
        "hwMuteOutputSettable": muteOut.settable,
        "outputLatencyFrames": latOut,
        "outputSafetyOffsetFrames": safeOut,
        "hogModeSettable": hogSet.settable
    ])
}

let data = try JSONSerialization.data(withJSONObject: outList, options: [.prettyPrinted, .sortedKeys])
print(String(data: data, encoding: .utf8)!)
