// SPDX-License-Identifier: MPL-2.0
import Foundation
import AppKit
import CoreGraphics
import TimbreCore

public enum CompetingNotchDetector {
    public static let knownNotchBundleIDs: Set<String> = [
        "com.theboringteam.boringnotch",
        "com.mediamate.MediaMate",
        "com.alcove.Alcove",
        "com.dynamiclake.DynamicLake",
        "com.atoll.Atoll"
    ]

    public static func detectRunningCompetitors() -> [String] {
        NSWorkspace.shared.runningApplications
            .compactMap { app -> String? in
                guard let id = app.bundleIdentifier, knownNotchBundleIDs.contains(id) else { return nil }
                return app.localizedName ?? id
            }
    }
}

public enum MediaKeyAction: Sendable {
    case volumeUp
    case volumeDown
    case muteToggle
}

public final class MediaKeyTap: @unchecked Sendable {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var handler: ((MediaKeyAction) -> Void)?

    public init() {}

    public static var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    public func start(onAction: @escaping (MediaKeyAction) -> Void) -> Bool {
        guard Self.isAccessibilityGranted else { return false }
        stop()
        self.handler = onAction
        let mask = CGEventMask(1 << 14) // NX_SYSDEFINED
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard type == .tapDisabledByTimeout || type == .tapDisabledByUserInput || type.rawValue == 14,
                      let userInfo else { return Unmanaged.passRetained(event) }
                let me = Unmanaged<MediaKeyTap>.fromOpaque(userInfo).takeUnretainedValue()
                if type == .tapDisabledByTimeout, let tap = me.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                    return Unmanaged.passRetained(event)
                }
                if let nsEvent = NSEvent(cgEvent: event), nsEvent.subtype.rawValue == 8 {
                    let data1 = nsEvent.data1
                    let keyCode = (data1 & 0xFFFF0000) >> 16
                    let keyFlags = data1 & 0x0000FFFF
                    let keyPressed = ((keyFlags & 0xFF00) >> 8) == 0xA
                    if keyPressed {
                        switch keyCode {
                        case 0: me.handler?(.volumeUp); return nil
                        case 1: me.handler?(.volumeDown); return nil
                        case 7: me.handler?(.muteToggle); return nil
                        default: break
                        }
                    }
                }
                return Unmanaged.passRetained(event)
            },
            userInfo: selfPtr
        ) else {
            return false
        }
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.eventTap = tap
        self.runLoopSource = src
        return true
    }

    public func stop() {
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
            runLoopSource = nil
        }
        if let tap = eventTap {
            CFMachPortInvalidate(tap)
            eventTap = nil
        }
        handler = nil
    }
}
