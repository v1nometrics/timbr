// SPDX-License-Identifier: MPL-2.0
// Event-driven source detection: Core Audio notifies when the process list changes or when any
// process starts or stops producing output. The 2 s timer in AppState stays only as a fallback.
import Foundation
import CoreAudio

public final class AudioProcessMonitor: @unchecked Sendable {
    // All mutable state is touched only on `queue` (listener blocks are delivered there too).
    private let queue = DispatchQueue(label: "dev.timbr.process-monitor")
    private var watched: Set<AudioObjectID> = []
    private var onChange: (@Sendable () -> Void)?
    private var listBlock: AudioObjectPropertyListenerBlock?
    private var procBlock: AudioObjectPropertyListenerBlock?
    private var pending = false
    private var running = false

    private static let listAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyProcessObjectList, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    private static let outputAddress = AudioObjectPropertyAddress(
        mSelector: kAudioProcessPropertyIsRunningOutput, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)

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
            let proc: AudioObjectPropertyListenerBlock = { [weak self] _, _ in self?.fire() }
            listBlock = list
            procBlock = proc
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
            if let procBlock {
                for id in watched {
                    var addr = Self.outputAddress
                    AudioObjectRemovePropertyListenerBlock(id, &addr, queue, procBlock)
                }
            }
            watched.removeAll()
            onChange = nil
        }
    }

    private func rewatch() {
        guard running, let procBlock else { return }
        var addr = Self.listAddress
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size) == noErr else { return }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &ids) == noErr else { return }
        let current = Set(ids)
        for id in current.subtracting(watched) {
            var a = Self.outputAddress
            if AudioObjectAddPropertyListenerBlock(id, &a, queue, procBlock) == noErr { watched.insert(id) }
        }
        for id in watched.subtracting(current) {
            var a = Self.outputAddress
            _ = AudioObjectRemovePropertyListenerBlock(id, &a, queue, procBlock)   // object may already be gone
            watched.remove(id)
        }
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
