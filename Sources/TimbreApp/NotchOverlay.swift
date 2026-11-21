// SPDX-License-Identifier: MPL-2.0
// The notch surface (docs/05-design-system/03-superficies-e-anatomia.md §1).
//
// Rules that make it read as hardware and never fight the menu bar:
//   1. Fill is exactly sRGB 0,0,0 — no stroke, no shadow, no blur, no alpha.
//   2. NECK + BODY: at menu-bar height the shape is never wider than the physical notch
//      (plus ears only where the menu bar is measured free). Everything else hangs BELOW the
//      menu bar in a body joined to the notch by concave fillets — menus are never covered.
//   3. The window never resizes; one animatable shape morphs inside a fixed canvas.
//   4. One persistent app icon travels between states (no duplicate cross-fading copies).
//   5. Hover is event-driven; closing follows the pointer continuously (rubber-band),
//      reverses if it comes back and commits past a threshold, carrying the motion.
import SwiftUI
import AppKit
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

// MARK: - Menu bar space (what the ears may occupy)

/// Measures how much of the menu bar beside the notch is free.
/// Right side: status-item windows (CGWindowList, layer 25, no permission needed).
/// Left side: the frontmost app's menus via Accessibility (only when already granted);
/// without it the left side is treated as occupied — we never guess over someone's menus.
@MainActor
enum MenuBarSpace {
    nonisolated static let earMax: CGFloat = 44
    nonisolated static let earMin: CGFloat = 26
    nonisolated static let gap: CGFloat = 8

    static func freeEars(_ g: NotchScreenGeometry) -> (left: CGFloat, right: CGFloat) {
        guard g.hasPhysicalNotch else { return (0, 0) }
        // Screen-local top-left coordinates (CG/AX global space for the notch display).
        let screenX = g.screenFrame.minX
        let notchLeft = g.screenFrame.midX - g.notchWidth / 2 - screenX
        let notchRight = g.screenFrame.midX + g.notchWidth / 2 - screenX
        let ownPID = ProcessInfo.processInfo.processIdentifier

        var rightOccupied = CGFloat.greatestFiniteMagnitude
        if let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] {
            for w in list {
                guard let layer = w[kCGWindowLayer as String] as? Int, layer == 25,
                      let pid = w[kCGWindowOwnerPID as String] as? Int32, pid != ownPID,
                      let bd = w[kCGWindowBounds as String] as? NSDictionary,
                      let r = CGRect(dictionaryRepresentation: bd as CFDictionary) else { continue }
                let x = r.minX - screenX
                if r.minY < g.notchHeight, x >= notchRight - 1 { rightOccupied = min(rightOccupied, x) }
            }
        }
        let rightFree = rightOccupied == .greatestFiniteMagnitude ? earMax : rightOccupied - notchRight - gap

        var leftFree: CGFloat = 0
        if AXIsProcessTrusted(), let app = NSWorkspace.shared.frontmostApplication {
            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            var menuBar: CFTypeRef?
            if AXUIElementCopyAttributeValue(axApp, kAXMenuBarAttribute as CFString, &menuBar) == .success, let menuBar {
                var children: CFTypeRef?
                // swiftlint:disable:next force_cast
                if AXUIElementCopyAttributeValue(menuBar as! AXUIElement, kAXChildrenAttribute as CFString, &children) == .success,
                   let items = children as? [AXUIElement] {
                    var maxX: CGFloat = 0
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
                        let x = pos.x - screenX
                        if size.width > 0, x < notchLeft { maxX = max(maxX, x + size.width) }
                    }
                    leftFree = notchLeft - maxX - gap
                }
            }
        }
        func clampEar(_ v: CGFloat) -> CGFloat { v >= earMin ? min(v, earMax) : 0 }
        return (clampEar(leftFree), clampEar(rightFree))
    }
}

// MARK: - Layout spec

/// Neck = the part at menu-bar height (extents from the notch centre).
/// Body = the part below the menu bar. `h` = total height from the screen edge.
struct NotchSpec: Equatable {
    var nL: CGFloat, nR: CGFloat, bL: CGFloat, bR: CGFloat, h: CGFloat, r: CGFloat

    func lerp(to o: NotchSpec, _ t: CGFloat) -> NotchSpec {
        func m(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * t }
        return NotchSpec(nL: m(nL, o.nL), nR: m(nR, o.nR), bL: m(bL, o.bL), bR: m(bR, o.bR), h: m(h, o.h), r: m(r, o.r))
    }
}

struct NotchLayout {
    let g: NotchScreenGeometry
    let ears: (left: CGFloat, right: CGFloat)
    var half: CGFloat { g.notchWidth / 2 }
    var H: CGFloat { g.notchHeight }
    var useChin: Bool { ears.left == 0 && ears.right == 0 }

    static let chinHeight: CGFloat = 20
    static let peekHalf: CGFloat = 180
    static let expandedHalf: CGFloat = 222
    static let hudHalf: CGFloat = 124

    static func expandedBodyHeight(rows: Int, hasAlert: Bool, hasFocus: Bool) -> CGFloat {
        10 + 30 + 6 + (hasFocus ? 74 : 48) + CGFloat(rows) * 34 + (hasAlert ? 44 : 0) + 46 + 4
    }

    func spec(_ state: NotchState, rows: Int = 0, hasAlert: Bool = false, hasFocus: Bool = true) -> NotchSpec {
        let rest = NotchSpec(nL: half, nR: half, bL: half, bR: half, h: H, r: min(10, H / 2))
        switch state {
        case .resting:
            return rest
        case .compact:
            if useChin { return NotchSpec(nL: half, nR: half, bL: half, bR: half, h: H + Self.chinHeight, r: 12) }
            let l = half + ears.left, r = half + ears.right
            return NotchSpec(nL: l, nR: r, bL: l, bR: r, h: H, r: min(10, H / 2 - 1))
        case .hud:
            let b = max(Self.hudHalf, half + 36)
            return NotchSpec(nL: half, nR: half, bL: b, bR: b, h: H + 34, r: 17)
        case .peek:
            let b = max(Self.peekHalf, half + 40)
            return NotchSpec(nL: half, nR: half, bL: b, bR: b, h: H + 66, r: 22)
        case .expanded:
            let b = max(Self.expandedHalf, half + 40)
            return NotchSpec(nL: half, nR: half, bL: b, bR: b, h: H + Self.expandedBodyHeight(rows: rows, hasAlert: hasAlert, hasFocus: hasFocus), r: 26)
        }
    }

    /// Fixed canvas: large enough for every state, so the window never resizes.
    var canvas: CGSize {
        CGSize(width: max(Self.expandedHalf, half + 40, half + MenuBarSpace.earMax) * 2 + 40,
               height: H + Self.expandedBodyHeight(rows: 3, hasAlert: true, hasFocus: true) + 12)
    }
}

// MARK: - Shape

/// Shoulders (concave) at the screen edge → neck → concave fillets → body → continuous corners.
struct NotchShape: Shape {
    var spec: NotchSpec
    var neckHeight: CGFloat
    var shoulder: CGFloat
    var fillet: CGFloat = 14
    var bodyTopRadius: CGFloat = 14

    var animatableData: AnimatablePair<AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>>, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(AnimatablePair(AnimatablePair(spec.nL, spec.nR), AnimatablePair(spec.bL, spec.bR)), AnimatablePair(spec.h, spec.r)) }
        set {
            spec.nL = newValue.first.first.first; spec.nR = newValue.first.first.second
            spec.bL = newValue.first.second.first; spec.bR = newValue.first.second.second
            spec.h = newValue.second.first; spec.r = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let cx = rect.midX, top = rect.minY
        let H = neckHeight
        let h = max(spec.h, H)
        let nL = spec.nL, nR = spec.nR
        let bL = max(spec.bL, nL), bR = max(spec.bR, nR)
        let s = shoulder
        let bottom = top + h
        let bodyDepth = max(0, h - H)
        let r = min(spec.r, (bL + bR) / 2, max(2, h - s) * 0.5)

        // No hardware notch: a floating continuous pill.
        guard s > 0 else {
            return Path(roundedRect: CGRect(x: cx - bL, y: top, width: bL + bR, height: h), cornerRadius: min(r, h / 2), style: .continuous)
        }

        let flareL = bL - nL, flareR = bR - nR
        let fL = min(fillet, flareL / 2, bodyDepth / 2), fR = min(fillet, flareR / 2, bodyDepth / 2)
        let tL = min(bodyTopRadius, flareL / 2, bodyDepth / 2), tR = min(bodyTopRadius, flareR / 2, bodyDepth / 2)
        let rr = min(r, bodyDepth > 1 ? bodyDepth - max(tL, tR) : r)

        var p = Path()
        // Left shoulder.
        p.move(to: CGPoint(x: cx - nL - s, y: top))
        p.addQuadCurve(to: CGPoint(x: cx - nL, y: top + s), control: CGPoint(x: cx - nL, y: top))
        if flareL > 0.5 {
            p.addLine(to: CGPoint(x: cx - nL, y: top + H - fL))
            p.addQuadCurve(to: CGPoint(x: cx - nL - fL, y: top + H), control: CGPoint(x: cx - nL, y: top + H))
            p.addLine(to: CGPoint(x: cx - bL + tL, y: top + H))
            p.addQuadCurve(to: CGPoint(x: cx - bL, y: top + H + tL), control: CGPoint(x: cx - bL, y: top + H))
        }
        p.addLine(to: CGPoint(x: cx - bL, y: bottom - rr))
        p.addCurve(to: CGPoint(x: cx - bL + rr, y: bottom), control1: CGPoint(x: cx - bL, y: bottom - rr * 0.38), control2: CGPoint(x: cx - bL + rr * 0.38, y: bottom))
        p.addLine(to: CGPoint(x: cx + bR - rr, y: bottom))
        p.addCurve(to: CGPoint(x: cx + bR, y: bottom - rr), control1: CGPoint(x: cx + bR - rr * 0.38, y: bottom), control2: CGPoint(x: cx + bR, y: bottom - rr * 0.38))
        if flareR > 0.5 {
            p.addLine(to: CGPoint(x: cx + bR, y: top + H + tR))
            p.addQuadCurve(to: CGPoint(x: cx + bR - tR, y: top + H), control: CGPoint(x: cx + bR, y: top + H))
            p.addLine(to: CGPoint(x: cx + nR + fR, y: top + H))
            p.addQuadCurve(to: CGPoint(x: cx + nR, y: top + H - fR), control: CGPoint(x: cx + nR, y: top + H))
        }
        p.addLine(to: CGPoint(x: cx + nR, y: top + s))
        p.addQuadCurve(to: CGPoint(x: cx + nR + s, y: top), control: CGPoint(x: cx + nR, y: top))
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
    @Published var ears: (left: CGFloat, right: CGFloat) = (0, 0)
    @Published var geometry: NotchScreenGeometry = .measure()
}

// MARK: - Panels

private final class NonActivatingNotchPanel: NSPanel {
    var allowKeyFocus = false
    override var canBecomeKey: Bool { allowKeyFocus }
    override var canBecomeMain: Bool { false }
}

private final class NotchSensorView: NSView {
    var onEnter: (() -> Void)?
    var onExit: (() -> Void)?
    var onClick: (() -> Void)?
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
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@MainActor
public final class NotchPanelController {
    private var panel: NonActivatingNotchPanel?
    private var sensor: NSPanel?
    private weak var appState: AppState?
    private let interaction = NotchInteraction()
    private var cancellables: Set<AnyCancellable> = []
    private var clickMonitor: Any?
    private var keyMonitor: Any?
    private var moveMonitors: [Any] = []
    private var hoverWork: DispatchWorkItem?
    private var earTimer: Timer?
    /// Expanded opened by click/shortcut only starts following the pointer after it has been inside once.
    private var armed = false
    private var lastState: NotchState = .resting

    private var g: NotchScreenGeometry { interaction.geometry }
    private var layoutModel: NotchLayout { NotchLayout(g: g, ears: interaction.ears) }

    public init(appState: AppState) {
        self.appState = appState
        setupPanels()
        bind()
        installStaticMonitors()
        refreshEars()
        apply(state: appState.notchState)
    }

    private func setupPanels() {
        let p = NonActivatingNotchPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isFloatingPanel = true
        p.level = .statusBar + 1
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = false
        p.hidesOnDeactivate = false
        p.isMovable = false
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        p.ignoresMouseEvents = true
        if let appState {
            let host = NSHostingView(rootView: NotchOverlayView(appState: appState, interaction: interaction))
            host.wantsLayer = true
            host.layer?.backgroundColor = .clear
            p.contentView = host
        }
        panel = p

        let s = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        s.isFloatingPanel = true
        s.level = .statusBar + 2
        s.backgroundColor = .clear
        s.isOpaque = false
        s.hasShadow = false
        s.hidesOnDeactivate = false
        s.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        let v = NotchSensorView()
        v.onEnter = { [weak self] in self?.sensorEntered() }
        v.onExit = { [weak self] in self?.hoverWork?.cancel() }
        v.onClick = { [weak self] in self?.open(.expanded) }
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
        Publishers.CombineLatest3(appState.$notchState, appState.$notchEnabled, appState.$menuBarOnlyMode)
            .receive(on: RunLoop.main)
            .sink { [weak self] state, _, _ in self?.apply(state: state) }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.interaction.geometry = .measure()
                self.refreshEars()
                self.placePanel()
                self.apply(state: self.appState?.notchState ?? .resting)
            }
            .store(in: &cancellables)
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                // Menus change with the frontmost app; re-measure once they have been laid out.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { self?.refreshEars() }
            }
            .store(in: &cancellables)
    }

    private func refreshEars() {
        let e = MenuBarSpace.freeEars(g)
        if e.left != interaction.ears.left || e.right != interaction.ears.right {
            withAnimation(TimbreMotion.smooth) { interaction.ears = e }
            if appState?.notchState == .compact { positionSensor(for: .compact) }
        }
    }

    // MARK: State application

    private func apply(state: NotchState) {
        guard let appState, let panel, let sensor else { return }
        if !appState.notchEnabled || appState.menuBarOnlyMode {
            panel.orderOut(nil); sensor.orderOut(nil); stopFollowing(); return
        }
        panel.orderFrontRegardless()
        let interactive = state == .peek || state == .expanded
        panel.level = (state == .hud || state == .expanded) ? .popUpMenu : .statusBar + 1
        panel.allowKeyFocus = state == .expanded
        if interactive {
            sensor.orderOut(nil)
            startFollowing()
            if state == .expanded, lastState != .expanded {
                armed = pointerInsideShape(state: .expanded, margin: 2)
                panel.makeKey()
            }
            if state == .peek { armed = true }
            updateMouseThrough()
        } else {
            stopFollowing()
            panel.ignoresMouseEvents = true
            if interaction.dismissProgress != 0 { interaction.dismissProgress = 0 }
            positionSensor(for: state)
            sensor.orderFrontRegardless()
        }
        if state == .compact {
            refreshEars()
            earTimer?.invalidate()
            earTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
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

    private func sensorEntered() {
        hoverWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.open(.peek) }
        hoverWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.07, execute: work)
    }

    private func open(_ state: NotchState) {
        hoverWork?.cancel()
        guard let appState, appState.notchEnabled, !appState.menuBarOnlyMode else { return }
        if state == .peek, !(appState.notchState == .resting || appState.notchState == .compact) { return }
        withAnimation(TimbreMotion.notchOpen) { appState.notchState = state }
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

    private func screenRects(for state: NotchState) -> [CGRect] {
        guard let appState else { return [] }
        let s = layoutModel.spec(state, rows: NotchOverlayView.listRows(appState), hasAlert: !appState.guardianAlerts.isEmpty, hasFocus: appState.focusSource != nil)
        let topY = g.screenFrame.maxY - (g.hasPhysicalNotch ? 0 : 6)
        let mid = g.screenFrame.midX
        let neck = CGRect(x: mid - s.nL, y: topY - g.notchHeight, width: s.nL + s.nR, height: g.notchHeight)
        let body = CGRect(x: mid - s.bL, y: topY - s.h, width: s.bL + s.bR, height: s.h)
        return [neck, body]
    }

    private func distanceToShape(_ p: CGPoint, state: NotchState) -> CGFloat {
        screenRects(for: state).map { r -> CGFloat in
            let dx = max(r.minX - p.x, 0, p.x - r.maxX)
            let dy = max(r.minY - p.y, 0, p.y - r.maxY)
            return (dx * dx + dy * dy).squareRoot()
        }.min() ?? .greatestFiniteMagnitude
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
        let d = distanceToShape(NSEvent.mouseLocation, state: state)
        if d <= 0.5 { armed = true }
        guard armed else { return }
        let range: CGFloat = state == .peek ? 70 : 110
        let raw = max(0, d - 6) / range
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

    /// Design-review choreography (`--demo`): open, pointer-driven collapse, expand, close, HUD.
    public func runDemo() {
        guard let appState else { return }
        func at(_ t: Double, _ f: @escaping @MainActor () -> Void) {
            DispatchQueue.main.asyncAfter(deadline: .now() + t) { MainActor.assumeIsolated { f() } }
        }
        at(0.6) { appState.notchState = .compact }
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
        earTimer?.invalidate()
        stopFollowing()
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        panel?.orderOut(nil)
        sensor?.orderOut(nil)
    }
}

// MARK: - Overlay view

public struct NotchOverlayView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var interaction: NotchInteraction
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let c = TimbreColors.notch

    static func listRows(_ s: AppState) -> Int { max(0, min(s.mixerSources.count - 1, 3)) }

    private var g: NotchScreenGeometry { interaction.geometry }
    private var layout: NotchLayout { NotchLayout(g: g, ears: interaction.ears) }
    private var focus: AudioSourceDescriptor? { appState.focusSource }
    private var closedState: NotchState { appState.shouldShowCompact ? .compact : .resting }
    private var level: Double? { appState.hasLiveSignal ? min(1, max(0, (appState.telemetry.lufsMomentary + 48) / 40)) : nil }

    private func spec(_ s: NotchState) -> NotchSpec {
        layout.spec(s, rows: Self.listRows(appState), hasAlert: !appState.guardianAlerts.isEmpty, hasFocus: focus != nil)
    }

    public var body: some View {
        let state = appState.notchState
        let p = (state == .peek || state == .expanded) ? interaction.dismissProgress : 0
        let rendered = spec(state).lerp(to: spec(closedState), p)
        let canvas = layout.canvas
        let shape = NotchShape(spec: rendered, neckHeight: g.notchHeight, shoulder: g.hasPhysicalNotch ? TimbreRadius.notchShoulder : 0)
        let contentOpacity = max(0, 1 - Double(p) * 1.7)

        ZStack(alignment: .topLeading) {
            shape
                .fill(Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 1))
                .opacity(state == .resting && g.hasPhysicalNotch ? 0 : 1)

            ZStack(alignment: .topLeading) {
                content(state, spec: spec(state), canvas: canvas)
                    .opacity(contentOpacity)
                    .blur(radius: p * 6)
                focusIcon(state, progress: p, canvas: canvas)
            }
            .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
            .clipShape(shape)
        }
        .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
        .animation(reduceMotion ? .easeOut(duration: 0.12) : animation(for: state), value: state)
        .animation(TimbreMotion.smooth, value: Self.listRows(appState))
        .animation(TimbreMotion.smooth, value: appState.guardianAlerts.count)
        .surface(.notch)
        .preferredColorScheme(.dark)
    }

    private func animation(for s: NotchState) -> Animation {
        (s == .peek || s == .expanded || s == .hud) ? TimbreMotion.notchOpen : TimbreMotion.notchClose
    }

    // MARK: Persistent focus icon — one view that travels, never duplicated

    private func iconFrame(_ s: NotchState, canvas: CGSize) -> (center: CGPoint, size: CGFloat, visible: Bool) {
        let cx = canvas.width / 2
        let H = g.notchHeight
        switch s {
        case .resting, .hud:
            return (CGPoint(x: cx - layout.half + 12, y: H / 2), 12, false)
        case .compact:
            if layout.useChin { return (CGPoint(x: cx - layout.half + 22, y: H + NotchLayout.chinHeight / 2 - 1), 13, true) }
            let e = interaction.ears
            if e.left > 0 {
                let x = (e.right == 0 && e.left >= 40) ? cx - layout.half - e.left + 13 : cx - layout.half - e.left / 2
                return (CGPoint(x: x, y: H / 2), 17, true)
            }
            // Only the right side is free: icon and meter share that ear.
            if e.right > 0 { return (CGPoint(x: cx + layout.half + (e.right >= 40 ? 13 : e.right / 2), y: H / 2), 16, true) }
            return (CGPoint(x: cx - layout.half + 12, y: H / 2), 12, false)
        case .peek:
            let x0 = cx - spec(.peek).bL
            return (CGPoint(x: x0 + 16 + 10, y: H + 12 + 11), 20, true)
        case .expanded:
            let x0 = cx - spec(.expanded).bL
            return (CGPoint(x: x0 + 18 + 15, y: H + 10 + 30 + 6 + 15), 30, true)
        }
    }

    @ViewBuilder
    private func focusIcon(_ s: NotchState, progress: CGFloat, canvas: CGSize) -> some View {
        if let f = focus {
            let open = iconFrame(s, canvas: canvas)
            let closed = iconFrame(closedState, canvas: canvas)
            let t = (s == .peek || s == .expanded) ? progress : 0
            let center = CGPoint(x: open.center.x + (closed.center.x - open.center.x) * t, y: open.center.y + (closed.center.y - open.center.y) * t)
            let size = open.size + (closed.size - open.size) * t
            let visible = open.visible && (closed.visible || t < 0.85)
            AppIcon(bundleID: f.bundleID, name: f.name, size: size)
                .position(center)
                .opacity(visible ? 1 : 0)
                .allowsHitTesting(false)
        }
    }

    // MARK: State content (positioned in canvas coordinates)

    @ViewBuilder
    private func content(_ s: NotchState, spec sp: NotchSpec, canvas: CGSize) -> some View {
        let cx = canvas.width / 2
        let H = g.notchHeight
        switch s {
        case .resting:
            EmptyView()
        case .compact:
            compact(canvas: canvas)
                .transition(.opacity.animation(.easeOut(duration: 0.12)))
        case .hud:
            hud.frame(width: sp.bL + sp.bR, height: sp.h - H)
                .offset(x: cx - sp.bL, y: H)
                .transition(bodyTransition)
        case .peek:
            peek.frame(width: sp.bL + sp.bR, height: sp.h - H, alignment: .top)
                .offset(x: cx - sp.bL, y: H)
                .transition(bodyTransition)
        case .expanded:
            expanded.frame(width: sp.bL + sp.bR, height: sp.h - H, alignment: .top)
                .offset(x: cx - sp.bL, y: H)
                .transition(bodyTransition)
        }
    }

    /// Body content: appears as the shape lands (no artificial delay), leaves instantly.
    private var bodyTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .offset(y: -6)).animation(.easeOut(duration: 0.2)),
            removal: .opacity.animation(.easeOut(duration: 0.08))
        )
    }

    // Compact — ears in measured free menu-bar space, or a chin under the notch when there is none.
    private func compact(canvas: CGSize) -> some View {
        let cx = canvas.width / 2
        let H = g.notchHeight
        let indicator = Group {
            if let alert = appState.guardianAlerts.first {
                Circle().fill(alert.severity == .info ? c.semantic_info : c.semantic_warning).frame(width: 6, height: 6)
            } else {
                MiniMeter(level: level, active: focus?.isPlaying == true && !appState.isProcessingBypassed,
                          color: appState.isProcessingBypassed ? c.ink_muted : c.accent_base)
            }
        }
        return ZStack(alignment: .topLeading) {
            if layout.useChin {
                indicator.position(x: cx + layout.half - 22, y: H + NotchLayout.chinHeight / 2 - 1)
            } else if interaction.ears.left > 0, interaction.ears.right > 0 {
                indicator.position(x: cx + layout.half + interaction.ears.right / 2, y: H / 2)
            } else if interaction.ears.right >= 40 {
                indicator.position(x: cx + layout.half + interaction.ears.right - 11, y: H / 2)
            } else if interaction.ears.left >= 40 {
                indicator.position(x: cx - layout.half - 11, y: H / 2)
            }
        }
        .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(focus?.name ?? appState.t("notch.empty_playing"))
    }

    // HUD — hangs under the notch; never widens the menu-bar part.
    private var hud: some View {
        let v = min(max(appState.hudValue, 0), 1)
        return HStack(spacing: 12) {
            Image(systemName: appState.hudMuted ? "speaker.slash.fill" : (v < 0.01 ? "speaker.fill" : (v < 0.34 ? "speaker.wave.1.fill" : (v < 0.67 ? "speaker.wave.2.fill" : "speaker.wave.3.fill"))))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(appState.hudMuted ? c.semantic_warning : c.ink_primary)
                .frame(width: 18)
                .contentTransition(.symbolEffect(.replace))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(c.bg_track)
                    Capsule().fill(appState.hudMuted ? c.ink_muted : c.ink_primary).frame(width: geo.size.width * v)
                }
            }
            .frame(height: 4)
            .animation(.linear(duration: 0.06), value: v)
            Text(appState.hudMuted ? appState.t("ui.notch.muted") : Fmt.percent(v))
                .type(TimbreTypography.monoValue).fontWeight(.medium)
                .foregroundStyle(appState.hudMuted ? c.semantic_warning : c.ink_primary)
                .contentTransition(.numericText(value: v))
                .frame(width: 34, alignment: .trailing)
        }
        .padding(.horizontal, 18)
        .frame(maxHeight: .infinity)
        .padding(.bottom, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(appState.hudTitle) \(Fmt.percent(v))%")
    }

    // Peek — the one control you came for.
    private var peek: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Color.clear.frame(width: 20, height: 22)   // slot for the travelling icon
                if let f = focus {
                    Text(f.name).type(TimbreTypography.notchTitle).foregroundStyle(c.ink_primary).lineLimit(1)
                    Spacer(minLength: 8)
                    if !f.isVoIPExcluded {
                        HStack(alignment: .firstTextBaseline, spacing: 1) {
                            Text(f.isMuted ? "—" : Fmt.percent(f.volume)).type(TimbreTypography.monoValue).fontWeight(.medium)
                                .foregroundStyle(f.volume > 1 && !f.isMuted ? c.semantic_warning : c.ink_primary)
                                .contentTransition(.numericText(value: f.volume))
                            Text("%").type(TimbreTypography.monoSmall).foregroundStyle(c.ink_muted)
                        }
                    }
                } else {
                    Text(appState.t("notch.empty_playing")).type(TimbreTypography.small).foregroundStyle(c.ink_muted)
                    Spacer()
                }
            }
            .frame(height: 22)
            if let f = focus, !f.isVoIPExcluded {
                TFader(value: volumeBinding(f), range: 0...2, unity: 1, tint: c.ink_primary, height: 20, label: f.name, valueText: Fmt.percent(f.volume), unityPosition: 0.75)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // Expanded — mixer in a breath.
    private var expanded: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("timbr").font(.system(size: 13, weight: .semibold)).tracking(-0.3)
                    Text(".").font(.system(size: 13, weight: .semibold)).foregroundStyle(c.accent_base)
                }
                .foregroundStyle(c.ink_primary)
                Circle().fill(appState.isProcessingBypassed ? c.ink_muted : (appState.pathIsNative ? c.semantic_positive : c.accent_base)).frame(width: 5, height: 5)
                Spacer()
                MenuChip(title: appState.activeOutputDevice?.name ?? "—", symbol: appState.activeOutputDevice?.glyph) {
                    ForEach(appState.outputDevices) { dev in
                        Button { appState.selectDefaultOutput(dev) } label: {
                            if dev.isDefaultOutput { Label(dev.name, systemImage: "checkmark") } else { Text(dev.name) }
                        }
                    }
                }
            }
            .frame(height: 30)
            .padding(.horizontal, 18)
            .padding(.top, 10)

            Color.clear.frame(height: 6)

            if let f = focus {
                focusBlock(f).padding(.horizontal, 18)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    Text(appState.t("notch.empty_playing")).type(TimbreTypography.small).foregroundStyle(c.ink_secondary)
                    Text(appState.t("ui.notch.empty_hint")).type(TimbreTypography.caption).foregroundStyle(c.ink_muted)
                }
                .frame(height: 48, alignment: .center)
                .padding(.horizontal, 18)
            }

            ForEach(appState.mixerSources.filter { $0.bundleID != focus?.bundleID }.prefix(3)) { src in
                sourceRow(src).padding(.horizontal, 18)
            }

            if let alert = appState.guardianAlerts.first {
                alertRow(alert).padding(.horizontal, 12).padding(.top, 4)
            }

            Spacer(minLength: 0)
            footer
        }
    }

    private func focusBlock(_ f: AudioSourceDescriptor) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Color.clear.frame(width: 30, height: 30)   // slot for the travelling icon
                VStack(alignment: .leading, spacing: 2) {
                    Text(f.name).type(TimbreTypography.notchTitle).foregroundStyle(c.ink_primary).lineLimit(1)
                    Text(f.isVoIPExcluded ? appState.t("mixer.voip_ignored") : (f.isPlaying ? appState.t("ui.notch.playing") : appState.t("ui.notch.paused")) + " · " + Fmt.volumeDB(f.isMuted ? 0 : f.volume) + " dB")
                        .type(TimbreTypography.caption).foregroundStyle(c.ink_muted)
                }
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(f.isMuted ? "—" : Fmt.percent(f.volume))
                        .type(TimbreTypography.notchValue)
                        .foregroundStyle(f.volume > 1 && !f.isMuted ? c.semantic_warning : c.ink_primary)
                        .contentTransition(.numericText(value: f.volume))
                    Text("%").type(TimbreTypography.monoSmall).foregroundStyle(c.ink_muted)
                }
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
        .frame(height: 74, alignment: .top)
    }

    private func sourceRow(_ src: AudioSourceDescriptor) -> some View {
        HStack(spacing: 10) {
            AppIcon(bundleID: src.bundleID, name: src.name, size: 16)
            Text(src.name).type(TimbreTypography.caption).foregroundStyle(src.isPlaying ? c.ink_primary : c.ink_secondary).lineLimit(1).frame(width: 96, alignment: .leading)
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
