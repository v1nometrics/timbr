// SPDX-License-Identifier: MPL-2.0
// timbr-mute-keeper (ADR-0017): holds the mutes the user set in timbr, and keeps holding them if
// timbr crashes, is force-quit, SIGKILLed or updated. Nothing else: no UI, no DSP, no network.
//
// Each mute is a `.mutedWhenTapped` process tap read by an IOProc that writes silence — the same
// mechanism timbr has always used in-process, which is the only kind of tap that actually mutes
// (an unread tap does not; measured 2026-11-23). It runs while `request.json` lists something and
// exits on its own when the list is empty.
//
// Usage (spawned by timbr): timbr-mute-keeper [--dir <state dir>]
import Foundation
import CoreAudio
import AudioToolbox

setvbuf(stdout, nil, _IOLBF, 0)
let args = CommandLine.arguments
let dir: URL = {
    if let i = args.firstIndex(of: "--dir"), i + 1 < args.count { return URL(fileURLWithPath: args[i + 1], isDirectory: true) }
    return MuteKeeperProtocol.defaultDirectory()
}()
try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

// Single instance per state directory, for the life of the process.
let lockFD = open(MuteKeeperProtocol.lockURL(dir).path, O_CREAT | O_RDWR, 0o644)
guard lockFD >= 0, flock(lockFD, LOCK_EX | LOCK_NB) == 0 else { exit(0) }
ftruncate(lockFD, 0)
_ = "\(getpid())\n".withCString { write(lockFD, $0, strlen($0)) }

final class Keeper: @unchecked Sendable {
    private struct Slot {
        let target: MuteKeeperProtocol.Target
        let deviceUID: String
        let tapID: AudioObjectID
        let aggregateID: AudioObjectID
        let procID: AudioDeviceIOProcID
    }

    private var slots: [String: Slot] = [:]
    private var failures: [String: String] = [:]
    private var applied = MuteKeeperProtocol.Request(generation: 0, targets: [])
    private var lastRequestStamp: Date?
    let dir: URL

    init(dir: URL) { self.dir = dir }

    /// Re-read `request.json` if it changed; returns false when the keeper should exit.
    func poll(force: Bool = false) -> Bool {
        let url = MuteKeeperProtocol.requestURL(dir)
        let stamp = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
        if !force, stamp == lastRequestStamp { return !slots.isEmpty || !applied.targets.isEmpty }
        lastRequestStamp = stamp
        guard let req = MuteKeeperProtocol.read(MuteKeeperProtocol.Request.self, from: url),
              req.version == MuteKeeperProtocol.version else {
            return !slots.isEmpty   // unreadable mid-write: keep what we hold, retry next tick
        }
        apply(req, rebuildAll: false)
        return !req.targets.isEmpty
    }

    func apply(_ req: MuteKeeperProtocol.Request, rebuildAll: Bool) {
        let device = Self.defaultOutputUID()
        let wanted = Dictionary(req.targets.map { ($0.bundleID, $0) }, uniquingKeysWith: { a, _ in a })
        // Create or replace first (new tap running before the old one goes: no gap)…
        for (bid, target) in wanted {
            if let cur = slots[bid], cur.target == target, !rebuildAll, cur.deviceUID == device { continue }
            guard let device, let slot = makeSlot(target, deviceUID: device) else {
                if device == nil { failures[bid] = "no output device" }
                continue   // keep the old slot if there is one: an older mute beats none
            }
            let old = slots[bid]
            slots[bid] = slot
            failures[bid] = nil
            if let old { destroy(old) }
        }
        // …then release what is no longer muted.
        for (bid, slot) in slots where wanted[bid] == nil {
            destroy(slot)
            slots[bid] = nil
            failures[bid] = nil
        }
        applied = req
        writeStatus()
    }

    func rebuildForDeviceChange() { apply(applied, rebuildAll: true) }
    /// A mute that could not be created yet (process not started, device busy) is retried.
    func retryFailures() { if !failures.isEmpty { apply(applied, rebuildAll: false) } }

    func releaseAll() {
        for (_, s) in slots { destroy(s) }
        slots.removeAll()
        writeStatus()
    }

    private func writeStatus() {
        let st = MuteKeeperProtocol.Status(generation: applied.generation, pid: getpid(), held: Array(slots.keys), failures: failures)
        try? MuteKeeperProtocol.write(st, to: MuteKeeperProtocol.statusURL(dir))
    }

    private func makeSlot(_ t: MuteKeeperProtocol.Target, deviceUID: String) -> Slot? {
        let objs = Self.processObjects(t.pids)
        let desc = CATapDescription(stereoMixdownOfProcesses: objs)
        let canRestore = desc.responds(to: NSSelectorFromString("setBundleIDs:"))
        guard !objs.isEmpty || (canRestore && !t.bundleIDs.isEmpty) else {
            failures[t.bundleID] = "no running process and no bundle-ID taps on this macOS"
            return nil
        }
        desc.name = "timbr.mutekeeper.\(t.bundleID)"
        desc.isPrivate = true
        desc.muteBehavior = .mutedWhenTapped
        if canRestore {
            desc.setValue(t.bundleIDs, forKey: "bundleIDs")
            if desc.responds(to: NSSelectorFromString("setProcessRestoreEnabled:")) { desc.setValue(true, forKey: "processRestoreEnabled") }
        }
        var tap = AudioObjectID(kAudioObjectUnknown)
        var err = AudioHardwareCreateProcessTap(desc, &tap)
        guard err == noErr, tap != AudioObjectID(kAudioObjectUnknown) else { failures[t.bundleID] = "tap \(err)"; return nil }

        let agg: [String: Any] = [
            kAudioAggregateDeviceNameKey as String: "timbr.mutekeeper",
            kAudioAggregateDeviceUIDKey as String: MuteKeeperProtocol.aggregateUIDPrefix + UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey as String: deviceUID,
            kAudioAggregateDeviceSubDeviceListKey as String: [[kAudioSubDeviceUIDKey as String: deviceUID]],
            kAudioAggregateDeviceTapListKey as String: [[kAudioSubTapUIDKey as String: desc.uuid.uuidString, kAudioSubTapDriftCompensationKey as String: false]],
            kAudioAggregateDeviceIsPrivateKey as String: true,
            kAudioAggregateDeviceIsStackedKey as String: false,
        ]
        var aggID = AudioObjectID(kAudioObjectUnknown)
        err = AudioHardwareCreateAggregateDevice(agg as CFDictionary, &aggID)
        guard err == noErr, aggID != AudioObjectID(kAudioObjectUnknown) else {
            AudioHardwareDestroyProcessTap(tap); failures[t.bundleID] = "aggregate \(err)"; return nil
        }
        var procID: AudioDeviceIOProcID?
        // Reading the tap is what mutes the app; we output silence.
        err = AudioDeviceCreateIOProcIDWithBlock(&procID, aggID, nil) { _, _, _, out, _ in
            for b in UnsafeMutableAudioBufferListPointer(out) { if let d = b.mData { memset(d, 0, Int(b.mDataByteSize)) } }
        }
        guard err == noErr, let procID, AudioDeviceStart(aggID, procID) == noErr else {
            if let procID { AudioDeviceDestroyIOProcID(aggID, procID) }
            AudioHardwareDestroyAggregateDevice(aggID); AudioHardwareDestroyProcessTap(tap)
            failures[t.bundleID] = "io \(err)"; return nil
        }
        return Slot(target: t, deviceUID: deviceUID, tapID: tap, aggregateID: aggID, procID: procID)
    }

    private func destroy(_ s: Slot) {
        AudioDeviceStop(s.aggregateID, s.procID)
        AudioDeviceDestroyIOProcID(s.aggregateID, s.procID)
        AudioHardwareDestroyAggregateDevice(s.aggregateID)
        AudioHardwareDestroyProcessTap(s.tapID)
    }

    static func processObjects(_ pids: [Int32]) -> [AudioObjectID] {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyTranslatePIDToProcessObject, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var out: [AudioObjectID] = []
        for pid in pids where pid > 0 {
            var q = pid
            var obj = AudioObjectID(kAudioObjectUnknown)
            var size = UInt32(MemoryLayout<AudioObjectID>.size)
            if AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, UInt32(MemoryLayout<pid_t>.size), &q, &size, &obj) == noErr,
               obj != AudioObjectID(kAudioObjectUnknown), !out.contains(obj) { out.append(obj) }
        }
        return out
    }

    static func defaultOutputUID() -> String? {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var dev = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &dev) == noErr, dev != kAudioObjectUnknown else { return nil }
        var uAddr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceUID, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var uid: CFString?
        var uSize = UInt32(MemoryLayout<CFString?>.size)
        let err = withUnsafeMutablePointer(to: &uid) { AudioObjectGetPropertyData(dev, &uAddr, 0, nil, &uSize, $0) }
        return err == noErr ? (uid as String?) : nil
    }
}

let keeper = Keeper(dir: dir)
let queue = DispatchQueue.main

// The output device changed (headphones in/out): rebuild on the new one, new before old.
var devAddr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &devAddr, queue) { _, _ in
    keeper.rebuildForDeviceChange()
}

// SIGTERM / SIGINT: release and leave (used by `Timbr --release-all-mutes`). SIGKILL cannot be caught;
// Core Audio then drops our taps and the apps play again — nothing else can hold them.
signal(SIGTERM, SIG_IGN); signal(SIGINT, SIG_IGN)
var signalSources: [DispatchSourceSignal] = []
for sig in [SIGTERM, SIGINT] {
    let src = DispatchSource.makeSignalSource(signal: sig, queue: queue)
    src.setEventHandler { keeper.releaseAll(); exit(0) }
    src.resume()
    signalSources.append(src)
}

guard keeper.poll(force: true) else { keeper.releaseAll(); exit(0) }
let timer = DispatchSource.makeTimerSource(queue: queue)
timer.schedule(deadline: .now() + .milliseconds(100), repeating: .milliseconds(100))
var ticks = 0
timer.setEventHandler {
    if !keeper.poll() { keeper.releaseAll(); exit(0) }
    ticks += 1
    if ticks % 20 == 0 { keeper.retryFailures() }
}
timer.resume()
dispatchMain()
