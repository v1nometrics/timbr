// SPDX-License-Identifier: MPL-2.0
// Built-in display brightness, so the notch can own the brightness keys like it owns volume.
// macOS has no public API for this. Two paths, tried in order:
//   1. DisplayServices (private framework used by Control Center) — works on Apple Silicon laptops;
//   2. IOKit's IODisplay brightness parameter — older/Intel and some panels.
// Both are looked up at runtime; if neither works, the key event is passed through to macOS
// untouched (the system HUD appears instead of silently doing nothing).
import Foundation
import CoreGraphics
import IOKit
import IOKit.graphics

public enum DisplayBrightness {
    private typealias GetFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetFn = @convention(c) (CGDirectDisplayID, Float) -> Int32

    nonisolated(unsafe) private static let handle: UnsafeMutableRawPointer? =
        dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY)
    private static let getFn: GetFn? = handle.flatMap { dlsym($0, "DisplayServicesGetBrightness") }.map { unsafeBitCast($0, to: GetFn.self) }
    private static let setFn: SetFn? = handle.flatMap { dlsym($0, "DisplayServicesSetBrightness") }.map { unsafeBitCast($0, to: SetFn.self) }

    /// The built-in panel if there is one, else the main display.
    public static var targetDisplay: CGDirectDisplayID {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var n: UInt32 = 0
        if CGGetOnlineDisplayList(16, &ids, &n) == .success {
            if let builtin = ids.prefix(Int(n)).first(where: { CGDisplayIsBuiltin($0) != 0 }) { return builtin }
        }
        return CGMainDisplayID()
    }

    /// Current brightness 0…1, or nil when it cannot be read (then we never consume the key).
    public static func get(_ display: CGDirectDisplayID = targetDisplay) -> Double? {
        if let getFn {
            var v: Float = 0
            if getFn(display, &v) == 0 { return Double(v) }
        }
        if let io = service(for: display) {
            defer { IOObjectRelease(io) }
            var v: Float = 0
            if IODisplayGetFloatParameter(io, 0, kIODisplayBrightnessKey as CFString, &v) == kIOReturnSuccess { return Double(v) }
        }
        return nil
    }

    @discardableResult
    public static func set(_ value: Double, display: CGDirectDisplayID = targetDisplay) -> Bool {
        let v = Float(min(max(value, 0), 1))
        if let setFn, setFn(display, v) == 0 { return true }
        if let io = service(for: display) {
            defer { IOObjectRelease(io) }
            return IODisplaySetFloatParameter(io, 0, kIODisplayBrightnessKey as CFString, v) == kIOReturnSuccess
        }
        return false
    }

    private static func service(for display: CGDirectDisplayID) -> io_service_t? {
        var it: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IODisplayConnect"), &it) == kIOReturnSuccess else { return nil }
        defer { IOObjectRelease(it) }
        while case let s = IOIteratorNext(it), s != 0 {
            let info = IODisplayCreateInfoDictionary(s, IOOptionBits(kIODisplayOnlyPreferredName)).takeRetainedValue() as NSDictionary
            if let vendor = info[kDisplayVendorID] as? UInt32, let product = info[kDisplayProductID] as? UInt32,
               vendor == CGDisplayVendorNumber(display), product == CGDisplayModelNumber(display) {
                return s
            }
            IOObjectRelease(s)
        }
        return nil
    }
}
