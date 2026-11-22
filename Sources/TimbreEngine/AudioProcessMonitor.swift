// SPDX-License-Identifier: MPL-2.0
// Event-driven source detection: Core Audio notifies when the process list changes or when any
// process starts or stops producing output. The 2 s timer in AppState stays only as a fallback.
import Foundation
import CoreAudio

public final class AudioProcessMonitor: @unchecked Sendable {
    // All mutable state is touched only on `queue` (listener blocks are delivered there too).
    private let queue = DispatchQueue(label: "dev.timbr.process-monitor")
    private var watched: [AudioObjectID: AudioObjectPropertyListenerBlock] = [:]
    /// Process objects seen starting output since the last drain. Short sounds (a 0.3 s alert) are
    /// often over before the coalesced refresh reads them; this keeps them from being missed.
    private var startedSinceDrain: Set<AudioObjectID> = []
    private var onChange: (@Sendable () -> Void)?
    private var listBlock: AudioObjectPropertyListenerBlock?
    private var pending = false
    private var running = false

    private static let listAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyProcessObjectList, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    private static let outputAddress = AudioObjectPropertyAddress(
        mSelector: kAudioProcessPropertyIsRunningOutput, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    /// Measured on macOS 26: for a newly started process the HAL notifies IsRunning but NOT
    /// IsRunningOutput, so we listen to both and re-read the output state ourselves.
    private static let runningAddress = AudioObjectPropertyAddress(
        mSelector: kAudioProcessPropertyIsRunning, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)

    public init() {}

    public func start(onChange: @escaping @Sendable () -> Void) {
        queue.async { [self] in
            guard !running else { return }
            running = true
            self.onChange = onChange
            let list: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                self?.rewatch()
                self?.fire()
            }
            listBlock = list
            var addr = Self.listAddress
            AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &addr, queue, list)
            rewatch()
        }
    }

    public func stop() {
        queue.async { [self] in
            guard running else { return }
            running = false
            if let listBlock {
                var addr = Self.listAddress
                AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &addr, queue, listBlock)
            }
            for (id, block) in watched { Self.unlisten(id, block, queue) }
            watched.removeAll()
            startedSinceDrain.removeAll()
            onChange = nil
        }
    }

    private func rewatch() {
        guard running else { return }
        var addr = Self.listAddress
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size) == noErr else { return }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &ids) == noErr else { return }
        let current = Set(ids)
        for id in current where watched[id] == nil {
            // One block per object: the callback does not say which object changed.
            let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                guard let self else { return }
                self.noteIfPlaying(id)
                // Output often starts a few ms after "running": look again shortly after.
                self.queue.asyncAfter(deadline: .now() + 0.06) { [weak self] in self?.noteIfPlaying(id) }
                self.fire()
            }
            var a = Self.outputAddress
            var r = Self.runningAddress
            let okOut = AudioObjectAddPropertyListenerBlock(id, &a, queue, block) == noErr
            let okRun = AudioObjectAddPropertyListenerBlock(id, &r, queue, block) == noErr
            if okOut || okRun { watched[id] = block }
            // A brand-new process object may already be playing before we could listen to it.
            if Self.isRunningOutput(id) { startedSinceDrain.insert(id) }
        }
        for (id, block) in watched where !current.contains(id) {
            Self.unlisten(id, block, queue)   // object may already be gone; errors are harmless
            watched[id] = nil
        }
    }

    /// Process objects that started output since the previous call (and clears the set).
    public func drainRecentlyStarted() -> Set<AudioObjectID> {
        queue.sync {
            let s = startedSinceDrain
            startedSinceDrain.removeAll()
            return s
        }
    }

    private func noteIfPlaying(_ id: AudioObjectID) {
        if Self.isRunningOutput(id), !startedSinceDrain.contains(id) {
            startedSinceDrain.insert(id)
            fire()
        }
    }

    private static func unlisten(_ id: AudioObjectID, _ block: @escaping AudioObjectPropertyListenerBlock, _ queue: DispatchQueue) {
        var a = outputAddress
        var r = runningAddress
        _ = AudioObjectRemovePropertyListenerBlock(id, &a, queue, block)
        _ = AudioObjectRemovePropertyListenerBlock(id, &r, queue, block)
    }

    private static func isRunningOutput(_ id: AudioObjectID) -> Bool {
        var a = outputAddress
        var v: UInt32 = 0
        var s = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(id, &a, 0, nil, &s, &v) == noErr && v != 0
    }

    /// Coalesces bursts (a browser starting several streams) into one refresh.
    private func fire() {
        guard running, !pending else { return }
        pending = true
        queue.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self else { return }
            self.pending = false
            self.onChange?()
        }
    }
}
