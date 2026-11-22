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
        "com.atoll.Atoll",
        "dev.notchy.Notchy",
        "com.notchy.app",
        "com.omnimac.OmniMac",
        "com.ilovenotch.ILoveNotch",
        "com.opennotch.OpenNotch"
    ]

    public static let knownNotchNameKeywords: [String] = [
        "boring.notch", "mediamate", "alcove", "dynamiclake", "atoll", "notchy", "omnimac", "ilovenotch", "opennotch"
    ]

    public static func matchesCompetitor(bundleID: String?, localizedName: String?) -> Bool {
        if let id = bundleID, knownNotchBundleIDs.contains(id) {
            return true
        }
        let haystack = "\(bundleID ?? "") \(localizedName ?? "")".lowercased()
        return knownNotchNameKeywords.contains { haystack.contains($0) }
    }

    public static func detectRunningCompetitors() -> [String] {
        let selfPID = ProcessInfo.processInfo.processIdentifier
        return NSWorkspace.shared.runningApplications
            .compactMap { app -> String? in
                guard app.processIdentifier != selfPID else { return nil }
                guard matchesCompetitor(bundleID: app.bundleIdentifier, localizedName: app.localizedName) else { return nil }
                return app.localizedName ?? app.bundleIdentifier
            }
    }
}

public enum MediaKeyAction: Sendable, Equatable {
    case volumeUp(fine: Bool)
    case volumeDown(fine: Bool)
    case muteToggle
    case brightnessUp(fine: Bool)
    case brightnessDown(fine: Bool)
}

public final class MediaKeyTap: @unchecked Sendable {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var handler: ((MediaKeyAction) -> Void)?
    /// Whether brightness keys are ours to handle (only if we can actually change brightness).
    private var ownsBrightness = false

    public init() {}

    public var isRunning: Bool { eventTap != nil }

    public static var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    public func start(onAction: @escaping (MediaKeyAction) -> Void) -> Bool {
        guard Self.isAccessibilityGranted else { return false }
        stop()
        self.handler = onAction
        self.ownsBrightness = DisplayBrightness.get() != nil
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
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput, let tap = me.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                    return Unmanaged.passRetained(event)
                }
                if let nsEvent = NSEvent(cgEvent: event), nsEvent.subtype.rawValue == 8 {
                    let data1 = nsEvent.data1
                    let keyCode = (data1 & 0xFFFF0000) >> 16
                    let keyFlags = data1 & 0x0000FFFF
                    let state = (keyFlags & 0xFF00) >> 8
                    let keyDown = state == 0xA
                    let keyUp = state == 0xB
                    // ⌥⇧ + key = quarter step, like macOS.
                    let fine = nsEvent.modifierFlags.contains(.option) && nsEvent.modifierFlags.contains(.shift)
                    // NX_KEYTYPE_SOUND_UP 0, SOUND_DOWN 1, BRIGHTNESS_UP 2, BRIGHTNESS_DOWN 3, MUTE 7.
                    // Key-up of a key we own is swallowed too, or macOS shows its own HUD on release.
                    switch keyCode {
                    case 0: if keyDown { me.handler?(.volumeUp(fine: fine)) }; if keyDown || keyUp { return nil }
                    case 1: if keyDown { me.handler?(.volumeDown(fine: fine)) }; if keyDown || keyUp { return nil }
                    case 7: if keyDown { me.handler?(.muteToggle) }; if keyDown || keyUp { return nil }
                    case 2 where me.ownsBrightness: if keyDown { me.handler?(.brightnessUp(fine: fine)) }; if keyDown || keyUp { return nil }
                    case 3 where me.ownsBrightness: if keyDown { me.handler?(.brightnessDown(fine: fine)) }; if keyDown || keyUp { return nil }
                    default: break
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
