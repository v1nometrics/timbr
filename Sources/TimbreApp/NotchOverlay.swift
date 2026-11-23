// SPDX-License-Identifier: MPL-2.0
// The notch surface (docs/05-design-system/03-superficies-e-anatomia.md §1).
//
// Model studied from the reference open-source notch apps (DynamicNotchKit and NotchDrop, MIT;
// boring.notch, GPL — parameters only, no code copied):
//   1. Fill is exactly sRGB 0,0,0 with no stroke; a soft black shadow only while open.
//   2. One shape, flush with the screen edge, grows SIDEWAYS AND DOWN from the hardware notch;
//      content flanks the camera in "wings" at menu-bar height.
//   3. The persistent state (compact) only uses menu-bar space measured as free; open states are
//      transient and release the menu bar as soon as the pointer heads for it.
//   4. The window never resizes; one animatable shape morphs inside a fixed canvas.
//   5. Hover pops the notch immediately, opens after a short dwell (no accidental opens when
//      sweeping the menu bar), and closing follows the pointer continuously.
import SwiftUI
import AppKit
import Darwin
import Combine
import ApplicationServices
import TimbreCore
import TimbreEngine
import TimbreDesignSystem

// MARK: - Screen geometry

public struct NotchScreenGeometry: Equatable, Sendable {
    public let screenFrame: CGRect
    public let hasPhysicalNotch: Bool
    public let notchWidth: CGFloat
    public let notchHeight: CGFloat

    public static func measure() -> NotchScreenGeometry {
        let target = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main ?? NSScreen.screens.first
        guard let target else {
            return NotchScreenGeometry(screenFrame: CGRect(x: 0, y: 0, width: 1470, height: 956), hasPhysicalNotch: false, notchWidth: 190, notchHeight: 30)
        }
        let topInset = target.safeAreaInsets.top
        if topInset > 0, let left = target.auxiliaryTopLeftArea, let right = target.auxiliaryTopRightArea {
            return NotchScreenGeometry(screenFrame: target.frame, hasPhysicalNotch: true, notchWidth: max(120, right.minX - left.maxX), notchHeight: topInset)
        }
        let menuBar = max(24, target.frame.maxY - target.visibleFrame.maxY)
        return NotchScreenGeometry(screenFrame: target.frame, hasPhysicalNotch: false, notchWidth: 190, notchHeight: min(menuBar, 30))
    }
}

// MARK: - Fullscreen probe (live CG/AX/AppKit snapshot fed to pure FullscreenEvaluator)

@MainActor
private enum FullscreenProbe {
    static func isActive(on g: NotchScreenGeometry, playingBundleIDs: Set<String>, playingOwnerNames: Set<String>) -> Bool {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? g.screenFrame.height
        let screenSpec = FullscreenScreenSpec(
            minX: g.screenFrame.minX,
            minY: primaryHeight - g.screenFrame.maxY,
            width: g.screenFrame.width,
            height: g.screenFrame.height,
            topInset: g.notchHeight,
            hasPhysicalNotch: g.hasPhysicalNotch
        )
        let ownPID = ProcessInfo.processInfo.processIdentifier
        var snapshots: [FullscreenWindowSnapshot] = []
        if let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] {
            snapshots.reserveCapacity(list.count)
            for w in list {
                guard let layer = w[kCGWindowLayer as String] as? Int, layer == 0,
                      let pid = w[kCGWindowOwnerPID as String] as? Int32,
                      let bd = w[kCGWindowBounds as String] as? NSDictionary,
                      let r = CGRect(dictionaryRepresentation: bd as CFDictionary) else { continue }
                let owner = w[kCGWindowOwnerName as String] as? String ?? ""
                snapshots.append(FullscreenWindowSnapshot(
                    ownerPID: pid, ownerName: owner, layer: layer,
                    minX: r.minX, minY: r.minY, width: r.width, height: r.height
                ))
            }
        }
        let gd = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)
        let autoHideMenu = (gd?["_HIHideMenuBar"] as? Bool) ?? ((gd?["_HIHideMenuBar"] as? Int) == 1)
        let front = NSWorkspace.shared.frontmostApplication
        let frontBundleID = front?.bundleIdentifier
        let frontOwnerName = front?.localizedName
        let axFullscreen = isFrontmostWindowAXFullscreen(on: screenSpec)
        return FullscreenEvaluator.isFullscreen(
            screen: screenSpec,
            windows: snapshots,
            menuBarVisible: NSMenu.menuBarVisible(),
            autoHideMenuBarAlways: autoHideMenu,
            frontmostAXFullScreen: axFullscreen,
            ownPID: ownPID,
            frontmostBundleID: frontBundleID,
            frontmostOwnerName: frontOwnerName,
            playingBundleIDs: playingBundleIDs,
            playingOwnerNames: playingOwnerNames
        )
    }

    private static func isFrontmostWindowAXFullscreen(on screen: FullscreenScreenSpec) -> Bool {
        guard AXIsProcessTrusted(),
              let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return false }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var winRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &winRef) == .success,
              let winRef else { return false }
        // swiftlint:disable:next force_cast
        let win = winRef as! AXUIElement
        var fsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(win, "AXFullScreen" as CFString, &fsRef) == .success,
              let fs = fsRef as? Bool, fs else { return false }

        // Only suppress the notch if the fullscreen window is actually on the notch display.
        var posRef: CFTypeRef?, sizeRef: CFTypeRef?
        var pos = CGPoint.zero, size = CGSize.zero
        if AXUIElementCopyAttributeValue(win, kAXPositionAttribute as CFString, &posRef) == .success, let posRef,
           AXUIElementCopyAttributeValue(win, kAXSizeAttribute as CFString, &sizeRef) == .success, let sizeRef {
            // swiftlint:disable:next force_cast
            AXValueGetValue(posRef as! AXValue, .cgPoint, &pos)
            // swiftlint:disable:next force_cast
            AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
            let midX = pos.x + size.width / 2
            let midY = pos.y + size.height / 2
            return midX >= screen.minX && midX <= screen.maxX && midY >= screen.minY && midY <= screen.maxY
        }
        return true
    }
}

// MARK: - Menu bar space (what the ears may occupy)

/// Measures how much of the menu bar beside the notch is free.
/// Right side: status-item windows (CGWindowList, layer 25, no permission needed).
/// Left side: the frontmost app's menus via Accessibility (only when already granted);
/// without it the left side is treated as occupied — we never guess over someone's menus.
@MainActor
enum MenuBarSpace {
    static func freeEars(_ g: NotchScreenGeometry) -> (left: CGFloat, right: CGFloat) {
        guard g.hasPhysicalNotch else { return (0, 0) }
        let axTrusted = AXIsProcessTrusted()
        guard axTrusted else { return (0, 0) }

        let primaryHeight = NSScreen.screens.first?.frame.height ?? g.screenFrame.height
        let cgTop = primaryHeight - g.screenFrame.maxY
        let screenX = g.screenFrame.minX
        let screenW = g.screenFrame.width
        let notchLeft = g.screenFrame.midX - g.notchWidth / 2 - screenX
        let notchRight = g.screenFrame.midX + g.notchWidth / 2 - screenX
        let ownPID = ProcessInfo.processInfo.processIdentifier

        var statusSpans: [MenuBarItemSpan] = []
        // macOS 26 Tahoe hosts active menu bar status items (layer 25) with kCGWindowIsOnscreen == false,
        // so query `.optionAll` and filter strictly to visible-alpha windows inside the menu-bar strip.
        if let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] {
            for w in list {
                guard let layer = w[kCGWindowLayer as String] as? Int, layer == 25,
                      let pid = w[kCGWindowOwnerPID as String] as? Int32, pid != ownPID,
                      (w[kCGWindowAlpha as String] as? Double ?? 1.0) > 0,
                      let bd = w[kCGWindowBounds as String] as? NSDictionary,
                      let r = CGRect(dictionaryRepresentation: bd as CFDictionary),
                      r.width > 0, r.width < screenW * 0.4,
                      r.height > 0, r.height <= g.notchHeight + 8,
                      r.minY >= cgTop - 4, r.minY < cgTop + g.notchHeight,
                      r.maxX > screenX, r.minX < screenX + screenW else { continue }
                statusSpans.append(MenuBarItemSpan(minX: Double(r.minX - screenX), maxX: Double(r.maxX - screenX)))
            }
        }

        var appMenuSpans: [MenuBarItemSpan] = []
        if let app = NSWorkspace.shared.frontmostApplication {
            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            var menuBar: CFTypeRef?
            if AXUIElementCopyAttributeValue(axApp, kAXMenuBarAttribute as CFString, &menuBar) == .success, let menuBar {
                var children: CFTypeRef?
                // swiftlint:disable:next force_cast
                if AXUIElementCopyAttributeValue(menuBar as! AXUIElement, kAXChildrenAttribute as CFString, &children) == .success,
                   let items = children as? [AXUIElement] {
                    for item in items {
                        var posRef: CFTypeRef?, sizeRef: CFTypeRef?
                        var pos = CGPoint.zero, size = CGSize.zero
                        if AXUIElementCopyAttributeValue(item, kAXPositionAttribute as CFString, &posRef) == .success, let posRef {
                            // swiftlint:disable:next force_cast
                            AXValueGetValue(posRef as! AXValue, .cgPoint, &pos)
                        }
                        if AXUIElementCopyAttributeValue(item, kAXSizeAttribute as CFString, &sizeRef) == .success, let sizeRef {
                            // swiftlint:disable:next force_cast
                            AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
                        }
                        guard size.width > 0,
                              pos.y >= cgTop - 4, pos.y < cgTop + g.notchHeight,
                              pos.x + size.width > screenX, pos.x < screenX + screenW else { continue }
                        let minX = Double(pos.x - screenX)
                        appMenuSpans.append(MenuBarItemSpan(minX: minX, maxX: minX + Double(size.width)))
                    }
                }
            }
        }

        let res = MenuBarSpaceEvaluator.freeEars(
            hasPhysicalNotch: g.hasPhysicalNotch,
            screenWidth: Double(screenW),
            notchLeft: Double(notchLeft),
            notchRight: Double(notchRight),
            axTrusted: axTrusted,
            appMenuSpans: appMenuSpans,
            statusItemSpans: statusSpans
        )
        return (CGFloat(res.left), CGFloat(res.right))
    }
}

// MARK: - Layout spec

/// The whole shape is described by five animatable numbers, measured from the notch centre:
/// left/right half-widths, total height from the screen edge, bottom corner radius and the
/// concave top "shoulder" radius that blends the shape into the screen edge.
struct NotchSpec: Equatable {
    var l: CGFloat, r: CGFloat, h: CGFloat, bottom: CGFloat, shoulder: CGFloat

    func lerp(to o: NotchSpec, _ t: CGFloat) -> NotchSpec {
        func m(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * t }
        return NotchSpec(l: m(l, o.l), r: m(r, o.r), h: m(h, o.h), bottom: m(bottom, o.bottom), shoulder: m(shoulder, o.shoulder))
    }

    /// Hover "pop": the notch breathes a few points before it commits to opening.
    var popped: NotchSpec { NotchSpec(l: l + 5, r: r + 5, h: h + 3, bottom: bottom + 2, shoulder: shoulder) }
}

/// Model shared by every reference notch app (DynamicNotchKit, boring.notch, NotchDrop):
/// the open notch grows sideways AND down from the hardware, flush with the screen edge,
/// content flanking the camera in the "wings" at menu-bar height. The persistent state
/// (compact) only ever uses menu-bar space measured as free; open states are transient,
/// user-initiated, and release the menu bar as soon as the pointer heads for it.
struct NotchLayout {
    let g: NotchScreenGeometry
    let ears: (left: CGFloat, right: CGFloat)
    let hasMultipleSources: Bool
    var half: CGFloat { g.notchWidth / 2 }
    var H: CGFloat { g.notchHeight }
    var useChin: Bool {
        MenuBarSpaceEvaluator.shouldUseChin(
            ears: (Double(ears.left), Double(ears.right)),
            hasMultipleSources: hasMultipleSources
        )
    }

    static let chinHeight: CGFloat = 20
    static let peekWing: CGFloat = 128
    static let expandedWing: CGFloat = 140
    static let hudWing: CGFloat = 58
    static let peekDepth: CGFloat = 44
    static let hudDepth: CGFloat = 18
    static let shadowPad: CGFloat = 28

    /// Peek: output (0 playing), single app + fader (1 playing), or Master/Geral + playing apps (2+ playing).
    static func peekDepth(rows: Int) -> CGFloat {
        peekDepth + (rows > 0 ? 4 + CGFloat(rows) * 34 : 0)
    }

    static func expandedDepth(rows: Int, hasAlert: Bool, layoutKind: NotchExpandedTarget.LayoutKind) -> CGFloat {
        // empty output block (46), single app focus + master strip (66 + 36), or master-led hero + hairline rows (66 + 4).
        let heroHeight: CGFloat = {
            switch layoutKind {
            case .empty: return 46
            case .single: return 66 + 36
            case .masterLed: return 66 + (rows > 0 ? 4 : 0)
            }
        }()
        return 8 + heroHeight + CGFloat(rows) * 34 + (hasAlert ? 44 : 0) + 46 + 2
    }

    var peekHalf: CGFloat { half + Self.peekWing }
    var expandedHalf: CGFloat { max(half + Self.expandedWing, 232) }
    var hudHalf: CGFloat { half + Self.hudWing }
    var restRadius: CGFloat { min(10, H / 3) }

    func spec(_ state: NotchState, rows: Int = 0, hasAlert: Bool = false, expandedLayout: NotchExpandedTarget.LayoutKind = .single) -> NotchSpec {
        let closedS = TimbreRadius.notchShoulder, openS = TimbreRadius.notchShoulderOpen
        switch state {
        case .resting:
            return NotchSpec(l: half, r: half, h: H, bottom: restRadius, shoulder: closedS)
        case .compact:
            if useChin { return NotchSpec(l: half, r: half, h: H + Self.chinHeight, bottom: 12, shoulder: closedS) }
            return NotchSpec(l: half + ears.left, r: half + ears.right, h: H, bottom: restRadius, shoulder: closedS)
        case .hud:
            return NotchSpec(l: hudHalf, r: hudHalf, h: H + Self.hudDepth, bottom: 14, shoulder: 11)
        case .peek:
            return NotchSpec(l: peekHalf, r: peekHalf, h: H + Self.peekDepth(rows: rows), bottom: 20, shoulder: openS)
        case .expanded:
            return NotchSpec(l: expandedHalf, r: expandedHalf,
                             h: H + Self.expandedDepth(rows: rows, hasAlert: hasAlert, layoutKind: expandedLayout),
                             bottom: TimbreRadius.notchExpanded, shoulder: openS)
        }
    }

    /// Fixed canvas: fits the largest state plus its shadow, so the window never resizes.
    var canvas: CGSize {
        let maxExpanded = max(
            Self.expandedDepth(rows: 3, hasAlert: true, layoutKind: .single),
            Self.expandedDepth(rows: 4, hasAlert: true, layoutKind: .masterLed)
        )
        return CGSize(width: (expandedHalf + TimbreRadius.notchShoulderOpen + Self.shadowPad) * 2,
                      height: H + maxExpanded + Self.shadowPad)
    }
}

// MARK: - Shape

/// Concave shoulders at the screen edge → straight sides → continuous bottom corners.
/// Without a hardware notch it becomes a floating continuous pill.
struct NotchShape: Shape {
    var spec: NotchSpec
    var hardware: Bool

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>>> {
        get { AnimatablePair(AnimatablePair(spec.l, spec.r), AnimatablePair(spec.h, AnimatablePair(spec.bottom, spec.shoulder))) }
        set {
            spec.l = newValue.first.first; spec.r = newValue.first.second
            spec.h = newValue.second.first
            spec.bottom = newValue.second.second.first; spec.shoulder = newValue.second.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let cx = rect.midX, top = rect.minY
        let l = max(0, spec.l), r = max(0, spec.r), h = max(1, spec.h)
        guard hardware else {
            return Path(roundedRect: CGRect(x: cx - l, y: top, width: l + r, height: h),
                        cornerRadius: min(spec.bottom, h / 2), style: .continuous)
        }
        let s = max(0, min(spec.shoulder, h / 2))
        let b = max(0, min(spec.bottom, h - s, (l + r) / 2))
        let bottom = top + h
        var p = Path()
        p.move(to: CGPoint(x: cx - l - s, y: top))
        p.addQuadCurve(to: CGPoint(x: cx - l, y: top + s), control: CGPoint(x: cx - l, y: top))
        p.addLine(to: CGPoint(x: cx - l, y: bottom - b))
        p.addCurve(to: CGPoint(x: cx - l + b, y: bottom),
                   control1: CGPoint(x: cx - l, y: bottom - b * 0.42), control2: CGPoint(x: cx - l + b * 0.42, y: bottom))
        p.addLine(to: CGPoint(x: cx + r - b, y: bottom))
        p.addCurve(to: CGPoint(x: cx + r, y: bottom - b),
                   control1: CGPoint(x: cx + r - b * 0.42, y: bottom), control2: CGPoint(x: cx + r, y: bottom - b * 0.42))
        p.addLine(to: CGPoint(x: cx + r, y: top + s))
        p.addQuadCurve(to: CGPoint(x: cx + r + s, y: top), control: CGPoint(x: cx + r, y: top))
        p.closeSubpath()
        return p
    }
}

// MARK: - Interaction model

/// Shared between the controller (pointer math) and the view (rendering).
@MainActor
final class NotchInteraction: ObservableObject {
    /// 0 = fully open, 1 = fully collapsed; driven continuously by pointer distance.
    @Published var dismissProgress: CGFloat = 0
    /// Pointer is over the closed notch and the dwell timer is running.
    @Published var hovering = false
    @Published var ears: (left: CGFloat, right: CGFloat) = (0, 0)
    @Published var geometry: NotchScreenGeometry = .measure()
}

// MARK: - Persistent overlay Space (pin across Spaces & 3-finger swipes, public fallback if unavailable)

@MainActor
private final class NotchSpaceOverlay {
    private typealias MainConnectionFn = @convention(c) () -> Int32
    private typealias SpaceCreateFn = @convention(c) (Int32, Int32, CFDictionary?) -> UInt64
    private typealias SpaceSetAbsoluteLevelFn = @convention(c) (Int32, UInt64, Int32) -> Int32
    private typealias ShowSpacesFn = @convention(c) (Int32, CFArray) -> Int32
    private typealias AddAndRemoveFn = @convention(c) (Int32, UInt64, CFArray) -> Int32
    private typealias SpaceDestroyFn = @convention(c) (Int32, UInt64) -> Int32

    private let handle: UnsafeMutableRawPointer
    private let cid: Int32
    private let spaceID: UInt64
    private let addAndRemoveFn: AddAndRemoveFn
    private let spaceDestroyFn: SpaceDestroyFn?

    init?() {
        guard let h = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY) else { return nil }
        guard let pMain = dlsym(h, "SLSMainConnectionID"),
              let pCreate = dlsym(h, "SLSSpaceCreate"),
              let pSetLevel = dlsym(h, "SLSSpaceSetAbsoluteLevel"),
              let pShow = dlsym(h, "SLSShowSpaces"),
              let pAddRemove = dlsym(h, "SLSSpaceAddWindowsAndRemoveFromSpaces") else {
            dlclose(h)
            return nil
        }
        let mainConn = unsafeBitCast(pMain, to: MainConnectionFn.self)
        let spaceCreate = unsafeBitCast(pCreate, to: SpaceCreateFn.self)
        let setLevel = unsafeBitCast(pSetLevel, to: SpaceSetAbsoluteLevelFn.self)
        let showSpaces = unsafeBitCast(pShow, to: ShowSpacesFn.self)
        let addRemove = unsafeBitCast(pAddRemove, to: AddAndRemoveFn.self)
        let destroy = dlsym(h, "SLSSpaceDestroy").map { unsafeBitCast($0, to: SpaceDestroyFn.self) }

        let cid = mainConn()
        let sid = spaceCreate(cid, 1, nil)
        guard sid != 0 else {
            dlclose(h)
            return nil
        }
        // Level 1 sits strictly above all managed Spaces & 3-finger Space-swipe animations (0),
        // while staying below SetupAssistant (100), SecurityAgent/TouchID (200), and LockScreen (300).
        guard setLevel(cid, sid, 1) == 0,
              showSpaces(cid, [NSNumber(value: sid)] as CFArray) == 0 else {
            _ = destroy?(cid, sid)
            dlclose(h)
            return nil
        }
        self.handle = h
        self.cid = cid
        self.spaceID = sid
        self.addAndRemoveFn = addRemove
        self.spaceDestroyFn = destroy
    }

    func attach(_ window: NSWindow) {
        let wid = window.windowNumber
        guard wid > 0 else { return }
        _ = addAndRemoveFn(cid, spaceID, [NSNumber(value: wid)] as CFArray)
    }

    func destroy() {
        _ = spaceDestroyFn?(cid, spaceID)
        dlclose(handle)
    }
}

// MARK: - Panels

private final class NonActivatingNotchPanel: NSPanel {
    var allowKeyFocus = false
    override var canBecomeKey: Bool { allowKeyFocus }
    override var canBecomeMain: Bool { false }
}

/// The panel never becomes key on hover, so the very first click must reach SwiftUI controls
/// (expand-on-tap, faders, mute) instead of being swallowed as a "focus" click.
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    var contextMenu: (() -> NSMenu)?
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func rightMouseDown(with event: NSEvent) {
        guard let menu = contextMenu?() else { return super.rightMouseDown(with: event) }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
}

private final class NotchSensorView: NSView {
    var onEnter: (() -> Void)?
    var onExit: (() -> Void)?
    var onClick: (() -> Void)?
    var contextMenu: (() -> NSMenu)?
    private var area: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area { removeTrackingArea(area) }
        let a = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(a)
        area = a
    }
    override func mouseEntered(with event: NSEvent) { onEnter?() }
    override func mouseExited(with event: NSEvent) { onExit?() }
    override func mouseDown(with event: NSEvent) { onClick?() }
    override func rightMouseDown(with event: NSEvent) {
        guard let menu = contextMenu?() else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@MainActor
public final class NotchPanelController {
    /// Dwell before a hover opens the notch. Long enough that sweeping the pointer across the
    /// menu bar never opens it by accident; the hover "pop" gives feedback before that.
    private static let dwell: TimeInterval = 0.15

    private static let baseNotchLevel = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
    private static let sensorNotchLevel = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 4)

    private var panel: NonActivatingNotchPanel?
    private var sensor: NSPanel?
    private var notchSpace: NotchSpaceOverlay?
    private weak var appState: AppState?
    private let interaction = NotchInteraction()
    private var cancellables: Set<AnyCancellable> = []
    private var clickMonitor: Any?
    private var keyMonitor: Any?
    private var moveMonitors: [Any] = []
    private var hoverWork: DispatchWorkItem?
    private var panelOrderOutWork: DispatchWorkItem?
    private var earTimer: Timer?
    private var fullscreenTimer: Timer?
    /// Open states only start following the pointer once it has been inside the shape.
    private var armed = false
    private var lastState: NotchState = .resting

    private var g: NotchScreenGeometry { interaction.geometry }
    private var layoutModel: NotchLayout { NotchLayout(g: g, ears: interaction.ears, hasMultipleSources: appState?.compactPair?.second != nil) }

    public init(appState: AppState) {
        self.appState = appState
        setupPanels()
        bind()
        installStaticMonitors()
        refreshFullscreen()
        refreshEars()
        apply(state: appState.notchState)
    }

    private func setupPanels() {
        notchSpace = NotchSpaceOverlay()
        let behavior: NSWindow.CollectionBehavior = notchSpace != nil
            ? [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            : [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

        let p = NonActivatingNotchPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isFloatingPanel = true
        p.level = Self.baseNotchLevel
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = false
        p.hidesOnDeactivate = false
        p.isMovable = false
        p.collectionBehavior = behavior
        p.ignoresMouseEvents = true
        if let appState {
            let host = FirstMouseHostingView(rootView: NotchOverlayView(appState: appState, interaction: interaction))
            host.wantsLayer = true
            host.layer?.backgroundColor = .clear
            host.contextMenu = { [weak self] in self?.makeContextMenu() ?? NSMenu() }
            p.contentView = host
        }
        panel = p

        let s = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        s.isFloatingPanel = true
        s.level = Self.sensorNotchLevel
        s.backgroundColor = .clear
        s.isOpaque = false
        s.hasShadow = false
        s.hidesOnDeactivate = false
        s.collectionBehavior = behavior
        let v = NotchSensorView()
        v.onEnter = { [weak self] in self?.sensorEntered() }
        v.onExit = { [weak self] in self?.sensorExited() }
        v.onClick = { [weak self] in self?.open(.expanded) }
        v.contextMenu = { [weak self] in self?.makeContextMenu() ?? NSMenu() }
        s.contentView = v
        sensor = s
        placePanel()
    }

    private func placePanel() {
        guard let panel else { return }
        let c = layoutModel.canvas
        let topPad: CGFloat = g.hasPhysicalNotch ? 0 : 6
        panel.setFrame(CGRect(x: g.screenFrame.midX - c.width / 2, y: g.screenFrame.maxY - c.height - topPad, width: c.width, height: c.height), display: true)
    }

    private func bind() {
        guard let appState else { return }
        Publishers.CombineLatest4(appState.$notchState, appState.$notchEnabled, appState.$menuBarOnlyMode, appState.$hideNotchInFullscreen)
            .combineLatest(appState.$isFullscreenActive)
            .receive(on: RunLoop.main)
            .sink { [weak self] left, _ in self?.apply(state: left.0) }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.interaction.geometry = .measure()
                self.refreshFullscreen()
                self.refreshEars()
                self.placePanel()
                self.apply(state: self.appState?.notchState ?? .resting)
            }
            .store(in: &cancellables)
        appState.$sources
            .map { _ in appState.compactPair?.second != nil }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, self.appState?.notchState == .compact else { return }
                self.positionSensor(for: .compact)
            }
            .store(in: &cancellables)
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshFullscreen()
                self?.refreshEars()
                // Menus change with the frontmost app; re-measure once macOS lays out the new menu bar.
                for delay in [0.08, 0.25] {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        self?.refreshFullscreen()
                        self?.refreshEars()
                    }
                }
            }
            .store(in: &cancellables)
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.activeSpaceDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshFullscreen()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    self?.refreshFullscreen()
                    self?.refreshEars()
                }
            }
            .store(in: &cancellables)
        // Catch in-space HTML5 / borderless fullscreen toggles (e.g. Chrome YouTube fullscreen) promptly.
        fullscreenTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshFullscreen() }
        }
    }

    private func refreshFullscreen() {
        let playing = appState?.playingSources ?? []
        let bundleIDs = Set(playing.map(\.bundleID))
        let ownerNames = Set(playing.map(\.name))
        appState?.setFullscreenActive(FullscreenProbe.isActive(on: g, playingBundleIDs: bundleIDs, playingOwnerNames: ownerNames))
    }

    private func refreshEars() {
        let e: (left: CGFloat, right: CGFloat) = ProcessInfo.processInfo.arguments.contains("--review-chin")
            ? (0, 0)
            : MenuBarSpace.freeEars(g)
        if e.left != interaction.ears.left || e.right != interaction.ears.right {
            withAnimation(TimbreMotion.smooth) { interaction.ears = e }
            if appState?.notchState == .compact { positionSensor(for: .compact) }
        }
    }

    // MARK: State application

    private func apply(state: NotchState) {
        guard let appState, let panel, let sensor else { return }
        if !appState.notchEnabled || appState.menuBarOnlyMode {
            panelOrderOutWork?.cancel()
            panel.orderOut(nil); sensor.orderOut(nil); stopFollowing(); return
        }
        if state == .resting && appState.shouldSuppressNotchChrome {
            // Drop hover sensor immediately so Chrome/Safari top-center exit-fullscreen buttons are never blocked.
            sensor.orderOut(nil)
            stopFollowing()
            panel.ignoresMouseEvents = true
            panelOrderOutWork?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self, let s = self.appState,
                      s.notchState == .resting, s.shouldSuppressNotchChrome else { return }
                self.panel?.orderOut(nil)
            }
            panelOrderOutWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.38, execute: work)
            lastState = state
            return
        }
        panelOrderOutWork?.cancel()
        if !panel.isVisible {
            panel.orderFrontRegardless()
            notchSpace?.attach(panel)
        }
        let interactive = state == .peek || state == .expanded
        panel.level = (state == .hud || state == .expanded) ? .popUpMenu : Self.baseNotchLevel
        panel.allowKeyFocus = state == .expanded
        if interactive {
            sensor.orderOut(nil)
            if interaction.hovering { interaction.hovering = false }
            startFollowing()
            if state == .expanded, lastState != .expanded {
                armed = pointerInsideShape(state: .expanded, margin: 2)
                panel.makeKey()
            }
            if state == .peek, lastState != .peek { armed = pointerInsideShape(state: .peek, margin: 24) }
            updateMouseThrough()
        } else {
            stopFollowing()
            panel.ignoresMouseEvents = true
            if interaction.dismissProgress != 0 { interaction.dismissProgress = 0 }
            positionSensor(for: state)
            if !sensor.isVisible {
                sensor.orderFrontRegardless()
                notchSpace?.attach(sensor)
            }
        }
        if state == .compact {
            refreshEars()
            earTimer?.invalidate()
            earTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.refreshEars() }
            }
        } else {
            earTimer?.invalidate(); earTimer = nil
        }
        lastState = state
    }

    private func positionSensor(for state: NotchState) {
        guard let sensor else { return }
        let e = interaction.ears
        let left = state == .compact && !layoutModel.useChin ? e.left : 0
        let right = state == .compact && !layoutModel.useChin ? e.right : 0
        let x = g.screenFrame.midX - g.notchWidth / 2 - left
        let hgt = g.notchHeight + (state == .compact && layoutModel.useChin ? NotchLayout.chinHeight : 0)
        sensor.setFrame(CGRect(x: x, y: g.screenFrame.maxY - hgt, width: g.notchWidth + left + right, height: hgt), display: false)
    }

    // MARK: Context menu (the notch's own menu: no menu bar icon needed)

    private func makeContextMenu() -> NSMenu {
        let menu = NSMenu()
        guard let appState else { return menu }
        menu.addItem(ClosureMenuItem(appState.t("ui.ctx.open_studio")) { appState.openStudioHandler?() })
        menu.addItem(ClosureMenuItem(appState.t("ui.ctx.settings")) {
            appState.selectedTab = .settings
            appState.openStudioHandler?()
        })
        menu.addItem(.separator())
        let icon = ClosureMenuItem(appState.t("ui.ctx.show_menubar")) { appState.setShowMenuBarIcon(!appState.showMenuBarIcon) }
        icon.state = appState.showMenuBarIcon ? .on : .off
        menu.addItem(icon)
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem(appState.t("ui.quit") + " timbr.") { NSApp.terminate(nil) })
        return menu
    }

    // MARK: Hover → pop → open

    private func sensorEntered() {
        hoverWork?.cancel()
        guard let s = appState?.notchState, s == .resting || s == .compact else { return }
        withAnimation(TimbreMotion.notchPop) { interaction.hovering = true }
        let work = DispatchWorkItem { [weak self] in self?.open(.peek, haptic: true) }
        hoverWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.dwell, execute: work)
    }

    private func sensorExited() {
        hoverWork?.cancel()
        if interaction.hovering { withAnimation(TimbreMotion.notchClose) { interaction.hovering = false } }
    }

    private func open(_ state: NotchState, haptic: Bool = false) {
        hoverWork?.cancel()
        guard let appState, appState.notchEnabled, !appState.menuBarOnlyMode else { return }
        if state == .peek && appState.shouldSuppressNotchChrome { return }
        if state == .peek, !(appState.notchState == .resting || appState.notchState == .compact) { return }
        if haptic { NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now) }
        withAnimation(TimbreMotion.notchOpen) {
            interaction.hovering = false
            interaction.dismissProgress = 0
            appState.notchState = state
        }
    }

    private func close() {
        guard let appState else { return }
        let target: NotchState = appState.shouldShowCompact ? .compact : .resting
        withAnimation(TimbreMotion.notchClose) {
            interaction.dismissProgress = 0
            appState.notchState = target
        }
    }

    // MARK: Pointer following (only while open — zero cost at rest)

    private func startFollowing() {
        guard moveMonitors.isEmpty else { return }
        let handler: (NSEvent) -> Void = { [weak self] _ in
            MainActor.assumeIsolated { self?.pointerMoved() }
        }
        if let gm = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: handler) { moveMonitors.append(gm) }
        if let lm = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: { [weak self] e in
            MainActor.assumeIsolated { self?.pointerMoved() }
            return e
        }) { moveMonitors.append(lm) }
        panel?.acceptsMouseMovedEvents = true
    }

    private func stopFollowing() {
        moveMonitors.forEach { NSEvent.removeMonitor($0) }
        moveMonitors.removeAll()
    }

    private func screenRect(for state: NotchState) -> CGRect {
        guard let appState else { return .zero }
        let s = layoutModel.spec(state, rows: NotchOverlayView.rows(for: state, appState), hasAlert: !appState.guardianAlerts.isEmpty, expandedLayout: appState.expandedTarget.layoutKind)
        let topY = g.screenFrame.maxY - (g.hasPhysicalNotch ? 0 : 6)
        return CGRect(x: g.screenFrame.midX - s.l, y: topY - s.h, width: s.l + s.r, height: s.h)
    }

    private func distanceToShape(_ p: CGPoint, state: NotchState) -> CGFloat {
        let r = screenRect(for: state)
        let dx = max(r.minX - p.x, 0, p.x - r.maxX)
        let dy = max(r.minY - p.y, 0, p.y - r.maxY)
        return (dx * dx + dy * dy).squareRoot()
    }

    private func pointerInsideShape(state: NotchState, margin: CGFloat) -> Bool {
        distanceToShape(NSEvent.mouseLocation, state: state) <= margin
    }

    private func updateMouseThrough() {
        guard let appState, let panel else { return }
        panel.ignoresMouseEvents = !pointerInsideShape(state: appState.notchState, margin: 1)
    }

    private func pointerMoved() {
        guard let appState else { return }
        let state = appState.notchState
        guard state == .peek || state == .expanded else { return }
        updateMouseThrough()
        let pt = NSEvent.mouseLocation
        let d = distanceToShape(pt, state: state)
        if d <= 0.5 { armed = true }
        guard armed else { return }
        // Heading sideways along the menu bar means "I want a menu": release it much sooner.
        // The blend is continuous in y so the progress never jumps.
        let bandBottom = g.screenFrame.maxY - g.notchHeight
        let inBand = min(1, max(0, (pt.y - (bandBottom - 16)) / 16))
        let normal: CGFloat = state == .peek ? 64 : 104
        let range = normal + (30 - normal) * inBand
        let raw = max(0, d - 4) / range
        if raw >= 1 {
            armed = false
            close()
            return
        }
        // Rubber-band: early pixels move a lot, then it resists — like pulling something elastic.
        let eased = 1 - pow(1 - raw, 1.8)
        withAnimation(.interactiveSpring(response: 0.16, dampingFraction: 0.86)) {
            interaction.dismissProgress = eased
        }
    }

    // MARK: Click outside / Esc

    private func installStaticMonitors() {
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let s = self.appState?.notchState, s == .expanded || s == .peek else { return }
                self.close()
            }
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53, let s = self?.appState?.notchState, s == .expanded || s == .peek {
                self?.close()
                return nil
            }
            return event
        }
    }

    /// Design-review choreography (`--demo`): pop, open, pointer-driven collapse, expand, close, HUD.
    public func runDemo() {
        guard let appState else { return }
        func at(_ t: Double, _ f: @escaping @MainActor () -> Void) {
            DispatchQueue.main.asyncAfter(deadline: .now() + t) { MainActor.assumeIsolated { f() } }
        }
        at(0.6) { appState.notchState = .compact }
        at(1.4) { withAnimation(TimbreMotion.notchPop) { self.interaction.hovering = true } }
        at(1.6) { self.open(.peek) }
        // Simulated pointer walking away over ~0.7 s, then commit.
        for i in 0...14 {
            at(2.8 + Double(i) * 0.05) {
                let raw = CGFloat(i) / 15
                withAnimation(.interactiveSpring(response: 0.16, dampingFraction: 0.86)) {
                    self.interaction.dismissProgress = 1 - pow(1 - raw, 1.8)
                }
            }
        }
        at(3.55) { self.close() }
        at(4.6) { self.open(.expanded) }
        at(6.0) { self.close() }
        at(7.0) { appState.triggerHUD(title: "Output", value: 0.64, muted: false) }
    }

    public func teardown() {
        hoverWork?.cancel()
        panelOrderOutWork?.cancel()
        earTimer?.invalidate()
        fullscreenTimer?.invalidate()
        stopFollowing()
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        panel?.orderOut(nil)
        sensor?.orderOut(nil)
        notchSpace?.destroy()
        notchSpace = nil
    }
}

// MARK: - Content reveal (blur + scale from the top, as the shape grows)

private struct Reveal: ViewModifier {
    let p: CGFloat
    func body(content: Content) -> some View {
        content
            .opacity(1 - Double(p))
            .blur(radius: 8 * p)
            .scaleEffect(x: 1 - 0.04 * p, y: 1 - 0.2 * p, anchor: .top)
    }
}

// MARK: - Overlay view

public struct NotchOverlayView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var interaction: NotchInteraction
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let c = TimbreColors.notch

    static func listRows(_ s: AppState) -> Int { s.expandedTarget.listRowCount }
    static func peekRows(_ s: AppState) -> Int {
        switch s.peekTarget {
        case .output: return 0
        case .single(let sole): return (!sole.isVoIPExcluded && s.outputSilenced) ? 1 : 0
        case .masterWithSources(let list): return list.count
        }
    }
    static func rows(for state: NotchState, _ s: AppState) -> Int {
        state == .peek ? peekRows(s) : listRows(s)
    }

    private var g: NotchScreenGeometry { interaction.geometry }
    private var layout: NotchLayout { NotchLayout(g: g, ears: interaction.ears, hasMultipleSources: appState.compactPair?.second != nil) }
    private var travellingFocus: AudioSourceDescriptor? {
        appState.compactPair?.lead ?? appState.expandedTarget.singleSource
    }
    private var closedState: NotchState { appState.shouldShowCompact ? .compact : .resting }
    private var level: Double? { appState.hasLiveSignal ? min(1, max(0, (appState.telemetry.lufsMomentary + 48) / 40)) : nil }
    private var H: CGFloat { g.notchHeight }

    private func spec(_ s: NotchState) -> NotchSpec {
        layout.spec(s, rows: Self.rows(for: s, appState), hasAlert: !appState.guardianAlerts.isEmpty, expandedLayout: appState.expandedTarget.layoutKind)
    }

    private static func isOpen(_ s: NotchState) -> Bool { s == .peek || s == .expanded || s == .hud }

    public var body: some View {
        let state = appState.notchState
        let p = (state == .peek || state == .expanded) ? interaction.dismissProgress : 0
        let closedPose = interaction.hovering ? spec(state).popped : spec(state)
        let rendered = Self.isOpen(state) ? spec(state).lerp(to: spec(closedState), p) : closedPose
        let canvas = layout.canvas
        let shape = NotchShape(spec: rendered, hardware: g.hasPhysicalNotch)
        let openAmount = Self.isOpen(state) ? Double(1 - p) : 0
        let hidden = state == .resting && (g.hasPhysicalNotch || appState.shouldSuppressNotchChrome) && !interaction.hovering

        ZStack(alignment: .topLeading) {
            shape
                .fill(Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 1))
                .shadow(color: .black.opacity(0.5 * openAmount), radius: 14, x: 0, y: 6)
                .opacity(hidden ? 0 : 1)

            ZStack(alignment: .topLeading) {
                content(state, spec: spec(state), canvas: canvas)
                    .modifier(Reveal(p: min(1, p * 1.6)))
                focusIcon(state, progress: p, canvas: canvas)
            }
            .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
            .clipShape(shape)
        }
        .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
        .animation(reduceMotion ? .easeOut(duration: 0.12) : animation(for: state), value: state)
        .animation(TimbreMotion.smooth, value: Self.listRows(appState))
        .animation(TimbreMotion.smooth, value: appState.playingSources.map(\.bundleID))
        .animation(TimbreMotion.smooth, value: appState.outputSilenced)
        .animation(TimbreMotion.smooth, value: appState.guardianAlerts.count)
        .surface(.notch)
        .preferredColorScheme(.dark)
    }

    private func animation(for s: NotchState) -> Animation {
        Self.isOpen(s) ? TimbreMotion.notchOpen : TimbreMotion.notchClose
    }

    // MARK: Persistent focus icon — one view that travels, never duplicated

    private struct CompactIconFrames {
        let leadCenter: CGPoint
        let leadSize: CGFloat
        let secondCenter: CGPoint?
        let secondSize: CGFloat
        let visible: Bool
    }

    /// Computes balanced, non-clipping positions for 1 or 2 playing app icons across every
    /// measured menu-bar layout (chin, both ears, left-only ear, right-only ear).
    private func compactIconFrames(hasSecond: Bool, canvas: CGSize) -> CompactIconFrames {
        let cx = canvas.width / 2
        if layout.useChin {
            let y = H + NotchLayout.chinHeight / 2 - 1
            if hasSecond {
                return CompactIconFrames(
                    leadCenter: CGPoint(x: cx - layout.half + 31, y: y), leadSize: 14,
                    secondCenter: CGPoint(x: cx - layout.half + 19, y: y), secondSize: 13,
                    visible: true
                )
            }
            return CompactIconFrames(leadCenter: CGPoint(x: cx - layout.half + 22, y: y), leadSize: 14, secondCenter: nil, secondSize: 0, visible: true)
        }
        let e = interaction.ears
        if e.left > 0 && e.right > 0 {
            let earMid = cx - layout.half - e.left / 2
            if hasSecond {
                let step: CGFloat = e.left >= 40 ? 6.0 : 4.5
                return CompactIconFrames(
                    leadCenter: CGPoint(x: earMid + step, y: H / 2), leadSize: e.left >= 40 ? 14 : 13,
                    secondCenter: CGPoint(x: earMid - step, y: H / 2), secondSize: e.left >= 40 ? 13 : 12,
                    visible: true
                )
            }
            return CompactIconFrames(leadCenter: CGPoint(x: earMid, y: H / 2), leadSize: e.left >= 34 ? 16 : 15, secondCenter: nil, secondSize: 0, visible: true)
        }
        return CompactIconFrames(leadCenter: CGPoint(x: cx - layout.half + 12, y: H / 2), leadSize: 12, secondCenter: nil, secondSize: 0, visible: false)
    }

    private func iconFrame(_ s: NotchState, canvas: CGSize) -> (center: CGPoint, size: CGFloat, visible: Bool) {
        let cx = canvas.width / 2
        switch s {
        case .resting, .hud:
            return (CGPoint(x: cx - layout.half + 12, y: H / 2), 12, false)
        case .compact:
            let f = compactIconFrames(hasSecond: appState.compactPair?.second != nil, canvas: canvas)
            return (f.leadCenter, f.leadSize, f.visible)
        case .peek:
            let showsSingleApp: Bool = {
                if case .single = appState.peekTarget { return true }
                return false
            }()
            return (CGPoint(x: cx - spec(.peek).l + 16 + 9, y: H / 2), 18, showsSingleApp)
        case .expanded:
            let showsSingleApp = appState.expandedTarget.singleSource != nil
            return (CGPoint(x: cx - spec(.expanded).l + 16 + 10, y: H / 2), 20, showsSingleApp)
        }
    }

    @ViewBuilder
    private func focusIcon(_ s: NotchState, progress: CGFloat, canvas: CGSize) -> some View {
        if let f = travellingFocus {
            let pair = appState.compactPair
            let hasSecond = pair?.second != nil
            let open = iconFrame(s, canvas: canvas)
            let closed = iconFrame(closedState, canvas: canvas)
            let t = (s == .peek || s == .expanded) ? progress : 0
            let retractsToClosed = (s == .peek || s == .expanded) && !open.visible
            let center = retractsToClosed
                ? closed.center
                : CGPoint(x: open.center.x + (closed.center.x - open.center.x) * t, y: open.center.y + (closed.center.y - open.center.y) * t)
            let size = retractsToClosed ? closed.size : open.size + (closed.size - open.size) * t
            let opacity: Double = {
                if retractsToClosed {
                    return closed.visible ? Double(max(0, (t - 0.35) / 0.65)) : 0
                }
                return (open.visible && (closed.visible || t < 0.85)) ? 1 : 0
            }()
            let cutoutOpacity: Double = {
                guard hasSecond else { return 0 }
                if s == .compact { return 1 }
                if retractsToClosed { return closed.visible ? Double(max(0, (t - 0.35) / 0.65)) : 0 }
                return t > 0.6 ? Double((t - 0.6) / 0.4) : 0
            }()
            AppIcon(bundleID: f.bundleID, name: f.name, size: size)
                .background(
                    RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                        .fill(Color.black)
                        .padding(-1.5)
                        .opacity(cutoutOpacity)
                )
                .position(center)
                .opacity(opacity)
                .allowsHitTesting(false)
        }
    }

    // MARK: State content (positioned in canvas coordinates)

    @ViewBuilder
    private func content(_ s: NotchState, spec sp: NotchSpec, canvas: CGSize) -> some View {
        let cx = canvas.width / 2
        switch s {
        case .resting:
            EmptyView()
        case .compact:
            compact(canvas: canvas)
                .transition(.opacity.animation(.easeOut(duration: 0.12)))
        case .hud:
            hud(wing: sp.l - layout.half).frame(width: sp.l + sp.r, height: sp.h, alignment: .top)
                .offset(x: cx - sp.l)
                .transition(bodyTransition)
        case .peek:
            peek(wing: sp.l - layout.half).frame(width: sp.l + sp.r, height: sp.h, alignment: .top)
                .offset(x: cx - sp.l)
                .transition(bodyTransition)
        case .expanded:
            expanded(wing: sp.l - layout.half).frame(width: sp.l + sp.r, height: sp.h, alignment: .top)
                .offset(x: cx - sp.l)
                .transition(bodyTransition)
        }
    }

    /// Content rides the shape's own spring in (blur → sharp, scaled from the top edge)
    /// and leaves almost instantly, so the shape is never seen dragging stale content.
    private var bodyTransition: AnyTransition {
        .asymmetric(
            insertion: .modifier(active: Reveal(p: 1), identity: Reveal(p: 0)).animation(.spring(duration: 0.36, bounce: 0)),
            removal: .opacity.animation(.easeOut(duration: 0.09))
        )
    }

    /// One row at menu-bar height split by the camera: left wing, notch gap, right wing.
    private func wingRow<L: View, R: View>(wing: CGFloat, @ViewBuilder left: () -> L, @ViewBuilder right: () -> R) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) { left() }
                .padding(.leading, 16).padding(.trailing, 10)
                .frame(width: wing, alignment: .leading)
            Color.clear.frame(width: layout.half * 2)
            HStack(spacing: 8) { right() }
                .padding(.leading, 10).padding(.trailing, 14)
                .frame(width: wing, alignment: .trailing)
        }
        .frame(height: H)
    }

    // Compact — ears in measured free menu-bar space, or a chin under the notch when there is none.
    private func compact(canvas: CGSize) -> some View {
        let cx = canvas.width / 2
        let indicator = Group {
            if let alert = appState.guardianAlerts.first {
                Circle().fill(alert.severity == .info ? c.semantic_info : c.semantic_warning).frame(width: 6, height: 6)
            } else {
                MiniMeter(level: level, active: !appState.playingSources.isEmpty && !appState.isProcessingBypassed,
                          color: appState.isProcessingBypassed ? c.ink_muted : c.accent_base)
            }
        }
        let pair = appState.compactPair
        let second = pair?.second
        let frames = compactIconFrames(hasSecond: second != nil, canvas: canvas)
        let compactLabel: String = {
            if let lead = pair?.lead, let second { return "\(lead.name) + \(second.name)" }
            return (pair?.lead ?? travellingFocus)?.name ?? appState.t("notch.empty_playing")
        }()
        return ZStack(alignment: .topLeading) {
            // Both logos stay legible when two apps play simultaneously (lead icon travels above).
            if let second, frames.visible, let secondCenter = frames.secondCenter {
                AppIcon(bundleID: second.bundleID, name: second.name, size: frames.secondSize)
                    .position(secondCenter)
                    .opacity(0.94)
                    .transition(.opacity)
            }
            if layout.useChin {
                indicator.position(x: cx + layout.half - 22, y: H + NotchLayout.chinHeight / 2 - 1)
            } else if interaction.ears.left > 0, interaction.ears.right > 0 {
                indicator.position(x: cx + layout.half + interaction.ears.right / 2, y: H / 2)
            }
        }
        .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(compactLabel)
    }

    // HUD — icon and value flank the camera; the level runs in a thin chin below.
    private func hud(wing: CGFloat) -> some View {
        let v = min(max(appState.hudValue, 0), 1)
        let tint = appState.hudMuted ? c.semantic_warning : c.ink_primary
        return VStack(spacing: 0) {
            wingRow(wing: wing) {
                Image(systemName: appState.hudKind == .brightness
                      ? (v < 0.5 ? "sun.min.fill" : "sun.max.fill")
                      : (appState.hudMuted ? "speaker.slash.fill" : (v < 0.01 ? "speaker.fill" : (v < 0.34 ? "speaker.wave.1.fill" : (v < 0.67 ? "speaker.wave.2.fill" : "speaker.wave.3.fill")))))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
                    .contentTransition(.symbolEffect(.replace))
                Spacer(minLength: 0)
            } right: {
                Text(appState.hudMuted ? appState.t("ui.notch.muted") : Fmt.percent(v))
                    .type(TimbreTypography.monoValue).fontWeight(.medium)
                    .foregroundStyle(tint)
                    .contentTransition(.numericText(value: v))
                    .lineLimit(1)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(c.bg_track)
                    Capsule().fill(appState.hudMuted ? c.ink_muted : c.ink_primary).frame(width: geo.size.width * v)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 18)
            .padding(.top, 3)
            .animation(.linear(duration: 0.06), value: v)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(appState.hudTitle) \(Fmt.percent(v))%")
    }

    // Peek — adapts cleanly to 0, 1, or 2+ simultaneously playing sources.
    private func peek(wing: CGFloat) -> some View {
        Group {
            switch appState.peekTarget {
            case .output:
                outputPeek(wing: wing)
            case .single(let sole):
                sourcePeek(wing: wing, source: sole)
            case .masterWithSources(let list):
                multiSourcePeek(wing: wing, sources: list)
            }
        }
        // Click anywhere that is not a control → grow into the full mixer (Dynamic Island tap).
        .contentShape(Rectangle())
        .onTapGesture { expandFromPeek() }
        .accessibilityAction(named: appState.t("ui.notch.expand")) { expandFromPeek() }
    }

    /// Nothing playing: the notch is your output — device, its volume, one fader.
    private func outputPeek(wing: CGFloat) -> some View {
        let dev = appState.activeOutputDevice
        let muted = appState.outputSilenced
        return VStack(spacing: 0) {
            wingRow(wing: wing) {
                Image(systemName: muted ? "speaker.slash.fill" : (dev?.glyph ?? "speaker.wave.2"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(muted ? c.semantic_warning : c.ink_secondary)
                    .frame(width: 18)
                Text(appState.t("ui.notch.output")).type(TimbreTypography.notchTitle).foregroundStyle(c.ink_primary).lineLimit(1)
                Spacer(minLength: 0)
            } right: {
                outputPeekValue(muted: muted)
            }
            outputControlRow
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func outputPeekValue(muted: Bool) -> some View {
        if muted {
            Spacer(minLength: 0)
            Text(appState.t("ui.notch.muted"))
                .type(TimbreTypography.caption).fontWeight(.medium)
                .foregroundStyle(c.semantic_warning)
                .lineLimit(1)
        } else if let v = appState.activeOutputVolume {
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(Fmt.percent(v)).type(TimbreTypography.monoValue).fontWeight(.medium)
                    .foregroundStyle(v < OutputVolumeBehavior.zeroThreshold ? c.semantic_warning : c.ink_primary)
                    .contentTransition(.numericText(value: v))
                Text("%").type(TimbreTypography.monoSmall).foregroundStyle(c.ink_muted)
            }
        }
    }

    /// Device name + hardware output fader: priority keeps the device name readable while capping very long names.
    private var outputControlRow: some View {
        HStack(spacing: 12) {
            Text(appState.activeOutputDevice?.name ?? "—")
                .type(TimbreTypography.caption)
                .foregroundStyle(c.ink_secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 150, alignment: .leading)
                .layoutPriority(1)
            outputControl
        }
        .padding(.horizontal, 18)
        .frame(height: 30)
    }

    /// Hardware volume of the active output, or a plain sentence when the device owns its volume.
    @ViewBuilder
    private var outputControl: some View {
        if let dev = appState.activeOutputDevice, let v = appState.activeOutputVolume {
            HStack(spacing: 10) {
                TFader(value: Binding(get: { appState.outputSilenced ? 0 : v }, set: { appState.setOutputVolume(dev, value: $0, showHUD: false) }),
                       range: 0...1, tint: c.ink_primary, height: 20, label: dev.name, valueText: Fmt.percent(v))
                masterMuteButton(dev)
            }
        } else {
            Text(appState.t("ui.notch.device_volume_fixed")).type(TimbreTypography.caption).foregroundStyle(c.ink_muted)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Master (the output device)

    @ViewBuilder
    private func masterMuteButton(_ dev: AudioDeviceDescriptor) -> some View {
        if dev.isHWMuteSettable {
            IconButton(symbol: appState.outputSilenced ? "speaker.slash.fill" : "speaker.wave.2.fill", size: 22,
                       active: appState.outputSilenced, activeColor: c.semantic_warning, help: appState.t("ui.mute")) {
                appState.toggleOutputMute()
            }
        }
    }

    /// The master strip: every per-app fader above feeds this one. Separated by a hairline, like a console.
    private var masterRow: some View {
        let dev = appState.activeOutputDevice
        let muted = appState.outputSilenced
        return HStack(spacing: 10) {
            Image(systemName: muted ? "speaker.slash.fill" : (dev?.glyph ?? "speaker.wave.2"))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(muted ? c.semantic_warning : c.ink_secondary)
                .frame(width: 16)
            Text(appState.t("ui.notch.master")).type(TimbreTypography.caption).fontWeight(.medium)
                .foregroundStyle(c.ink_primary).frame(width: 96, alignment: .leading)
                .help(dev?.name ?? "")
            if let dev, let v = appState.activeOutputVolume {
                TFader(value: Binding(get: { muted ? 0 : v }, set: { appState.setOutputVolume(dev, value: $0, showHUD: false) }),
                       range: 0...1, tint: c.ink_primary, height: 18, trackHeight: 2, label: dev.name, valueText: Fmt.percent(v))
                Text(muted ? "—" : Fmt.percent(v)).type(TimbreTypography.monoSmall).foregroundStyle(c.ink_muted).frame(width: 26, alignment: .trailing)
            } else {
                Text(appState.t("ui.notch.device_volume_fixed")).type(TimbreTypography.micro).foregroundStyle(c.ink_muted).lineLimit(1)
                Spacer(minLength: 0)
            }
            if let dev, dev.isHWMuteSettable {
                IconButton(symbol: muted ? "speaker.slash.fill" : "speaker.fill", size: 20, active: muted, activeColor: c.semantic_warning, help: appState.t("ui.mute")) {
                    appState.toggleOutputMute()
                }
            }
        }
        .frame(height: 34)
        .padding(.top, 2)
        .overlay(alignment: .top) { Hairline() }
    }

    /// Shown in the peek when nothing can be heard: says why, and fixes it in one click.
    private var silencedRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "speaker.slash.fill").font(.system(size: 11, weight: .semibold)).foregroundStyle(c.semantic_warning)
            Text(appState.t(appState.outputSilenced ? "ui.notch.output_muted" : "ui.notch.output_zero"))
                .type(TimbreTypography.caption).foregroundStyle(c.ink_primary).lineLimit(1)
            Spacer(minLength: 0)
            Button(appState.t("ui.notch.unmute_output")) { appState.restoreOutputAudible() }
                .buttonStyle(.t(.secondary, compact: true))
        }
        .frame(height: 30)
    }

    /// Single app playing: unambiguous — the hover controls that app directly.
    private func sourcePeek(wing: CGFloat, source f: AudioSourceDescriptor) -> some View {
        VStack(spacing: 0) {
            wingRow(wing: wing) {
                Color.clear.frame(width: 18, height: 18)   // slot for the travelling icon
                Text(f.name)
                    .type(TimbreTypography.notchTitle)
                    .foregroundStyle(c.ink_primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            } right: {
                Spacer(minLength: 0)
                if f.isVoIPExcluded {
                    Text(appState.t("ui.status.call"))
                        .type(TimbreTypography.caption)
                        .foregroundStyle(c.ink_muted)
                        .lineLimit(1)
                } else {
                    valueLabel(f, big: false)
                    IconButton(symbol: f.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill", size: 22, active: f.isMuted, activeColor: c.semantic_warning, help: appState.t("ui.mute")) {
                        appState.toggleSourceMute(bundleID: f.bundleID)
                    }
                }
            }
            if !f.isVoIPExcluded {
                TFader(value: volumeBinding(f), range: 0...2, unity: 1, tint: c.ink_primary, height: 20, label: f.name, valueText: Fmt.percent(f.volume), unityPosition: 0.75)
                    .padding(.horizontal, 18)
                    .frame(height: 30)
                if appState.outputSilenced {
                    silencedRow.padding(.horizontal, 18).padding(.top, 4)
                }
            } else {
                outputControlRow
            }
            Spacer(minLength: 0)
        }
    }

    /// 2+ apps playing simultaneously: Master/Geral leads at top (the common output),
    /// followed by every playing app on equal footing right below.
    private func multiSourcePeek(wing: CGFloat, sources playing: [AudioSourceDescriptor]) -> some View {
        let dev = appState.activeOutputDevice
        let muted = appState.outputSilenced
        return VStack(spacing: 0) {
            wingRow(wing: wing) {
                Image(systemName: muted ? "speaker.slash.fill" : (dev?.glyph ?? "speaker.wave.2"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(muted ? c.semantic_warning : c.ink_secondary)
                    .frame(width: 18)
                Text(appState.t("ui.notch.master"))
                    .type(TimbreTypography.notchTitle)
                    .foregroundStyle(c.ink_primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            } right: {
                outputPeekValue(muted: muted)
            }
            outputControlRow
            VStack(spacing: 0) {
                ForEach(playing) { src in sourceRow(src) }
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)
            .overlay(alignment: .top) { Hairline().padding(.horizontal, 18).padding(.top, 2) }
            .transition(.opacity)
            Spacer(minLength: 0)
        }
    }

    private func expandFromPeek() {
        withAnimation(reduceMotion ? .easeOut(duration: 0.12) : TimbreMotion.notchOpen) {
            appState.notchState = .expanded
        }
    }

    /// Bring the app that owns this audio to the front (launch it if it has quit), then fold away.
    private func bringToFront(_ src: AudioSourceDescriptor) {
        if let client = SystemAudioClient(bundleID: src.bundleID) {
            // macOS sounds have no app: open the settings pane that controls them (calls → FaceTime).
            if let url = client.settingsURL {
                NSWorkspace.shared.open(url)
            } else if client == .calls, let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: client.iconBundleID) {
                NSWorkspace.shared.openApplication(at: app, configuration: NSWorkspace.OpenConfiguration())
            } else {
                return
            }
            withAnimation(TimbreMotion.notchClose) { appState.notchState = appState.shouldShowCompact ? .compact : .resting }
            return
        }
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: src.bundleID)
        if let app = running.first(where: { $0.activationPolicy == .regular }) ?? running.first {
            app.activate()
        } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: src.bundleID) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
        withAnimation(TimbreMotion.notchClose) {
            appState.notchState = appState.shouldShowCompact ? .compact : .resting
        }
    }

    // Expanded — unified spotlight rule with Peek:
    // 1 playing → that single app leads; 2+ playing or 0 playing with recent sources → neutral Geral leads.
    private func expanded(wing: CGFloat) -> some View {
        let target = appState.expandedTarget
        let dev = appState.activeOutputDevice
        let muted = appState.outputSilenced
        return VStack(alignment: .leading, spacing: 0) {
            wingRow(wing: wing) {
                switch target {
                case .single(let f, _):
                    HoverLink(help: String(format: appState.t("ui.notch.open_app"), f.name)) { bringToFront(f) } label: {
                        HStack(spacing: 8) {
                            Color.clear.frame(width: 20, height: 20)   // slot for the travelling icon
                            Text(f.name).type(TimbreTypography.notchTitle).foregroundStyle(c.ink_primary).lineLimit(1)
                        }
                    }
                case .masterWithSources:
                    HStack(spacing: 8) {
                        Image(systemName: muted ? "speaker.slash.fill" : (dev?.glyph ?? "speaker.wave.2"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(muted ? c.semantic_warning : c.ink_secondary)
                            .frame(width: 20, height: 20)
                        Text(appState.t("ui.notch.master"))
                            .type(TimbreTypography.notchTitle)
                            .foregroundStyle(c.ink_primary)
                            .lineLimit(1)
                    }
                case .empty:
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("timbr").font(.system(size: 13, weight: .semibold)).tracking(-0.3)
                        Text(".").font(.system(size: 13, weight: .semibold)).foregroundStyle(c.accent_base)
                    }
                    .foregroundStyle(c.ink_primary)
                }
                Spacer(minLength: 0)
            } right: {
                Spacer(minLength: 0)
                MenuChip(title: dev?.name ?? "—", symbol: dev?.glyph ?? "speaker.wave.2", iconOnly: true) {
                    ForEach(appState.outputDevices) { outDev in
                        Button { appState.selectDefaultOutput(outDev) } label: {
                            if outDev.isDefaultOutput { Label(outDev.name, systemImage: "checkmark") } else { Text(outDev.name) }
                        }
                    }
                }
            }

            Color.clear.frame(height: 8)

            switch target {
            case .empty:
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(appState.t("notch.empty_playing")).type(TimbreTypography.caption).foregroundStyle(c.ink_muted)
                        Text("·").type(TimbreTypography.caption).foregroundStyle(c.ink_faint)
                        Text(dev?.name ?? "—").type(TimbreTypography.caption).foregroundStyle(c.ink_secondary).lineLimit(1)
                    }
                    outputControl
                }
                .frame(height: 46, alignment: .center)
                .padding(.horizontal, 18)

            case .single(let f, let others):
                focusBlock(f).padding(.horizontal, 18)
                ForEach(others) { src in
                    sourceRow(src).padding(.horizontal, 18)
                }
                masterRow.padding(.horizontal, 18)

            case .masterWithSources(let list):
                masterFocusBlock.padding(.horizontal, 18)
                if !list.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(list) { src in
                            sourceRow(src)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 4)
                    .overlay(alignment: .top) { Hairline().padding(.horizontal, 18).padding(.top, 2) }
                }
            }

            if let alert = appState.guardianAlerts.first {
                alertRow(alert).padding(.horizontal, 12).padding(.top, 4)
            }

            Spacer(minLength: 0)
            footer
        }
    }

    private var masterFocusBlock: some View {
        let dev = appState.activeOutputDevice
        let muted = appState.outputSilenced
        let hasPlaying = !appState.playingSources.isEmpty
        let subtitle = hasPlaying
            ? String(format: appState.t("ui.notch.playing_on"), dev?.name ?? "—")
            : "\(appState.t("notch.empty_playing")) · \(dev?.name ?? "—")"
        return VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Text(subtitle)
                    .type(TimbreTypography.caption)
                    .foregroundStyle(c.ink_muted)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if muted {
                    Text(appState.t("ui.notch.muted"))
                        .type(TimbreTypography.caption).fontWeight(.medium)
                        .foregroundStyle(c.semantic_warning)
                        .lineLimit(1)
                } else if let v = appState.activeOutputVolume {
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text(Fmt.percent(v))
                            .type(TimbreTypography.notchValue)
                            .fontWeight(.medium)
                            .foregroundStyle(v < OutputVolumeBehavior.zeroThreshold ? c.semantic_warning : c.ink_primary)
                            .contentTransition(.numericText(value: v))
                        Text("%").type(TimbreTypography.monoSmall).foregroundStyle(c.ink_muted)
                    }
                }
                if let dev, dev.isHWMuteSettable {
                    IconButton(
                        symbol: muted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                        size: 26,
                        active: muted,
                        activeColor: c.semantic_warning,
                        help: appState.t("ui.mute")
                    ) {
                        appState.toggleOutputMute()
                    }
                }
            }
            .frame(height: 30)
            if let dev, let v = appState.activeOutputVolume {
                TFader(
                    value: Binding(get: { muted ? 0 : v }, set: { appState.setOutputVolume(dev, value: $0, showHUD: false) }),
                    range: 0...1,
                    tint: c.ink_primary,
                    label: dev.name,
                    valueText: muted ? appState.t("ui.notch.muted") : Fmt.percent(v)
                )
            } else {
                Text(appState.t("ui.notch.device_volume_fixed"))
                    .type(TimbreTypography.caption)
                    .foregroundStyle(c.ink_muted)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: 66, alignment: .top)
    }

    private func valueLabel(_ f: AudioSourceDescriptor, big: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text(f.isMuted ? "—" : Fmt.percent(f.volume))
                .type(big ? TimbreTypography.notchValue : TimbreTypography.monoValue)
                .fontWeight(.medium)
                .foregroundStyle(f.volume > 1 && !f.isMuted ? c.semantic_warning : c.ink_primary)
                .contentTransition(.numericText(value: f.volume))
            Text("%").type(TimbreTypography.monoSmall).foregroundStyle(c.ink_muted)
        }
    }

    private func focusBlock(_ f: AudioSourceDescriptor) -> some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Text(f.isVoIPExcluded ? appState.t("mixer.voip_ignored")
                     : String(format: appState.t(f.isPlaying ? "ui.notch.playing_on" : "ui.notch.paused_on"), appState.activeOutputDevice?.name ?? "—"))
                    .type(TimbreTypography.caption).foregroundStyle(c.ink_muted).lineLimit(1)
                Spacer(minLength: 0)
                if !f.isVoIPExcluded { valueLabel(f, big: true) }
                IconButton(symbol: f.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill", size: 26, active: f.isMuted, activeColor: c.semantic_warning, help: appState.t("ui.mute")) {
                    appState.toggleSourceMute(bundleID: f.bundleID)
                }
                .disabled(f.isVoIPExcluded)
            }
            .frame(height: 30)
            if !f.isVoIPExcluded {
                TFader(value: volumeBinding(f), range: 0...2, unity: 1, tint: c.ink_primary, label: f.name, valueText: Fmt.percent(f.volume), unityPosition: 0.75)
            }
        }
        .frame(height: 66, alignment: .top)
    }

    private func sourceRow(_ src: AudioSourceDescriptor) -> some View {
        HStack(spacing: 10) {
            HoverLink(help: String(format: appState.t("ui.notch.open_app"), src.name)) { bringToFront(src) } label: {
                HStack(spacing: 10) {
                    AppIcon(bundleID: src.bundleID, name: src.name, size: 16)
                    Text(src.name).type(TimbreTypography.caption).foregroundStyle(src.isPlaying ? c.ink_primary : c.ink_secondary).lineLimit(1).frame(width: 96, alignment: .leading)
                }
            }
            if src.isVoIPExcluded {
                Text(appState.t("mixer.voip_ignored")).type(TimbreTypography.micro).foregroundStyle(c.ink_muted)
                Spacer(minLength: 0)
            } else {
                TFader(value: volumeBinding(src), range: 0...2, unity: 1, tint: c.ink_secondary, height: 18, trackHeight: 2, label: src.name, valueText: Fmt.percent(src.volume), unityPosition: 0.75)
                Text(src.isMuted ? "—" : Fmt.percent(src.volume)).type(TimbreTypography.monoSmall).foregroundStyle(c.ink_muted).frame(width: 26, alignment: .trailing)
                IconButton(symbol: src.isMuted ? "speaker.slash.fill" : "speaker.fill", size: 20, active: src.isMuted, activeColor: c.semantic_warning, help: appState.t("ui.mute")) {
                    appState.toggleSourceMute(bundleID: src.bundleID)
                }
            }
        }
        .frame(height: 34)
    }

    private func alertRow(_ alert: GuardianAlert) -> some View {
        HStack(spacing: 8) {
            Circle().fill(c.semantic_warning).frame(width: 6, height: 6)
            Text(appState.t(alert.titleKey)).type(TimbreTypography.caption).foregroundStyle(c.ink_primary).lineLimit(1)
            Spacer(minLength: 0)
            if let act = alert.suggestedActionKey {
                Button(appState.t(act)) { appState.runGuardianAction(alert) }.buttonStyle(.t(.secondary, compact: true))
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(c.semantic_warning.opacity(0.1)))
    }

    private var footer: some View {
        HStack(spacing: 6) {
            footerChip(title: appState.isProcessingBypassed ? appState.t("ui.notch.eq_off") : appState.t("ui.notch.eq_on"), symbol: "power", on: !appState.isProcessingBypassed) {
                appState.toggleBypass()
            }
            footerChip(title: appState.t("notch.ab_neutral"), symbol: "square.split.2x1", on: appState.abMode != .full) { appState.toggleABNeutral() }
            Spacer(minLength: 0)
            Button {
                appState.notchState = appState.shouldShowCompact ? .compact : .resting
                appState.openStudioHandler?()
            } label: {
                HStack(spacing: 4) {
                    Text(appState.t("ui.studio"))
                    Image(systemName: "arrow.up.right").font(.system(size: 9, weight: .semibold))
                }
            }
            .buttonStyle(.t(.ghost, compact: true))
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .overlay(alignment: .top) { Hairline().padding(.horizontal, 14) }
    }

    private func footerChip(title: String, symbol: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 9, weight: .semibold)).foregroundStyle(on ? c.accent_base : c.ink_muted)
                Text(title).type(TimbreTypography.caption).fontWeight(.medium)
            }
            .foregroundStyle(on ? c.ink_primary : c.ink_secondary)
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(Capsule().fill(on ? c.bg_selected : c.bg_inset))
        }
        .buttonStyle(PressScaleStyle())
    }

    private func volumeBinding(_ src: AudioSourceDescriptor) -> Binding<Double> {
        Binding(get: { src.isMuted ? 0 : src.volume }, set: { appState.setSourceVolume(bundleID: src.bundleID, volume: $0) })
    }
}

/// A quiet link: no chrome at rest, a soft plate on hover that bleeds outside the label so the
/// layout (and the travelling icon's slot) never shifts.
private struct HoverLink<Label: View>: View {
    let help: String
    let action: () -> Void
    @ViewBuilder let label: () -> Label
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            label()
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(TimbreColors.notch.bg_hover.opacity(hover ? 1 : 0))
                        .padding(.horizontal, -6).padding(.vertical, -4)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(DimOnPress())
        .onHover { h in withAnimation(TimbreMotion.snappy) { hover = h } }
        .help(help)
        .accessibilityLabel(help)
    }
}

/// Press feedback that does not scale (the travelling icon lives in another layer and must stay aligned).
private struct DimOnPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(TimbreMotion.pressOut, value: configuration.isPressed)
    }
}

/// NSMenuItem that runs a closure (target/action without a dedicated responder).
final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void
    init(_ title: String, _ handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }
    required init(coder: NSCoder) { fatalError("init(coder:) is not used") }
    @objc private func run() { handler() }
}
