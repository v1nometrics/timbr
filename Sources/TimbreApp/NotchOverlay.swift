// SPDX-License-Identifier: MPL-2.0
// The notch surface (docs/05-design-system/03-notch.md).
// Rules that make it read as hardware, not as a floating card:
//   1. Fill is exactly sRGB 0,0,0 — no stroke, no shadow, no blur, no alpha.
//   2. Top edge is flat and flush with the screen edge; the top corners are CONCAVE shoulders.
//   3. The window never animates its frame; the shape morphs inside a stable canvas.
//   4. Hover is event-driven (NSTrackingArea) — zero polling at rest (P9).
import SwiftUI
import AppKit
import Combine
import TimbreCore
import TimbreEngine
import TimbreDesignSystem

// MARK: - Geometry

public struct NotchScreenGeometry: Equatable, Sendable {
    public let screenFrame: CGRect
    public let hasPhysicalNotch: Bool
    public let notchWidth: CGFloat
    public let notchHeight: CGFloat

    public static func measure(screen: NSScreen? = nil) -> NotchScreenGeometry {
        let target = screen
            ?? NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let target else {
            return NotchScreenGeometry(screenFrame: CGRect(x: 0, y: 0, width: 1470, height: 956), hasPhysicalNotch: false, notchWidth: 180, notchHeight: 32)
        }
        let topInset = target.safeAreaInsets.top
        if topInset > 0, let left = target.auxiliaryTopLeftArea, let right = target.auxiliaryTopRightArea {
            let gap = max(120, right.minX - left.maxX)
            return NotchScreenGeometry(screenFrame: target.frame, hasPhysicalNotch: true, notchWidth: gap, notchHeight: topInset)
        }
        // No notch: a floating pill below the menu bar.
        let menuBar = max(24, target.frame.maxY - target.visibleFrame.maxY)
        return NotchScreenGeometry(screenFrame: target.frame, hasPhysicalNotch: false, notchWidth: 190, notchHeight: min(menuBar, 30))
    }
}

/// Size, bottom radius and shoulder radius for every notch state. Single source for panel + shape.
struct NotchMetrics {
    let g: NotchScreenGeometry
    static let ear: CGFloat = 42
    var shoulder: CGFloat { g.hasPhysicalNotch ? TimbreRadius.notchShoulder : 0 }

    func body(for state: NotchState, rows: Int, hasAlert: Bool, hasFocus: Bool = true) -> (size: CGSize, radius: CGFloat) {
        let w = g.notchWidth, h = g.notchHeight
        switch state {
        case .resting:
            return (CGSize(width: w, height: h), min(10, h / 2))
        case .compact:
            return (CGSize(width: w + Self.ear * 2, height: h), min(11, h / 2))
        case .hud:
            return (CGSize(width: max(w + 120, 300), height: h + 20), 16)
        case .peek:
            return (CGSize(width: max(w + 300, 480), height: h + 50), 20)
        case .expanded:
            let focus: CGFloat = rows == 0 && !hasFocus ? 58 : 76
            let list = CGFloat(rows) * 34
            let alert: CGFloat = hasAlert ? 44 : 0
            let footer: CGFloat = 46
            return (CGSize(width: max(w + 300, 516), height: h + 10 + focus + list + alert + footer + 8), TimbreRadius.notchExpanded)
        }
    }

    /// Panel canvas = body + shoulders (+ breathing room for the floating pill).
    func canvas(for state: NotchState, rows: Int, hasAlert: Bool, hasFocus: Bool = true) -> CGSize {
        let b = body(for: state, rows: rows, hasAlert: hasAlert, hasFocus: hasFocus).size
        return CGSize(width: b.width + shoulder * 2, height: b.height + (g.hasPhysicalNotch ? 0 : 8))
    }
}

// MARK: - Shape

/// Flat top, concave shoulders, continuous bottom corners. Animatable in width/height/radius.
struct NotchShape: Shape {
    var width: CGFloat
    var height: CGFloat
    var bottomRadius: CGFloat
    var shoulder: CGFloat

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat> {
        get { AnimatablePair(AnimatablePair(width, height), bottomRadius) }
        set { width = newValue.first.first; height = newValue.first.second; bottomRadius = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let s = shoulder
        let r = min(bottomRadius, height / 2, width / 2)
        let left = rect.midX - width / 2
        let right = rect.midX + width / 2
        let top = rect.minY
        let bottom = top + height
        // No hardware notch: a free-floating continuous pill.
        guard s > 0 else {
            return Path(roundedRect: CGRect(x: left, y: top, width: width, height: height), cornerRadius: r, style: .continuous)
        }
        var p = Path()
        // Concave shoulder: flares from the screen edge into the body, like the hardware cutout.
        p.move(to: CGPoint(x: left - s, y: top))
        p.addQuadCurve(to: CGPoint(x: left, y: top + s), control: CGPoint(x: left, y: top))
        p.addLine(to: CGPoint(x: left, y: bottom - r))
        // Continuous-looking bottom corners (cubic approximation of Apple's squircle).
        p.addCurve(to: CGPoint(x: left + r, y: bottom),
                   control1: CGPoint(x: left, y: bottom - r * 0.38),
                   control2: CGPoint(x: left + r * 0.38, y: bottom))
        p.addLine(to: CGPoint(x: right - r, y: bottom))
        p.addCurve(to: CGPoint(x: right, y: bottom - r),
                   control1: CGPoint(x: right - r * 0.38, y: bottom),
                   control2: CGPoint(x: right, y: bottom - r * 0.38))
        p.addLine(to: CGPoint(x: right, y: top + s))
        p.addQuadCurve(to: CGPoint(x: right + s, y: top), control: CGPoint(x: right, y: top))
        p.closeSubpath()
        return p
    }
}

// MARK: - Panels

private final class NonActivatingNotchPanel: NSPanel {
    var allowKeyFocus = false
    override var canBecomeKey: Bool { allowKeyFocus }
    override var canBecomeMain: Bool { false }
}

/// Invisible view over the hardware notch that turns hover/click into state changes.
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
    private var sensorView: NotchSensorView?
    private weak var appState: AppState?
    private var cancellables: Set<AnyCancellable> = []
    private var globalMouseMonitor: Any?
    private var localKeyMonitor: Any?
    private var hoverWork: DispatchWorkItem?
    private var shrinkWork: DispatchWorkItem?
    private var geometry = NotchScreenGeometry.measure()
    private var currentCanvas: CGSize = .zero

    public init(appState: AppState) {
        self.appState = appState
        setupPanels()
        bindState()
        startMonitors()
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
            let host = NSHostingView(rootView: NotchOverlayView(appState: appState, geometryProvider: { [weak self] in self?.geometry ?? .measure() }))
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
        v.onExit = { [weak self] in self?.sensorExited() }
        v.onClick = { [weak self] in self?.sensorClicked() }
        s.contentView = v
        sensor = s
        sensorView = v
        layout(animatedShrink: false)
    }

    private func bindState() {
        guard let appState else { return }
        Publishers.CombineLatest4(appState.$notchState, appState.$notchEnabled, appState.$menuBarOnlyMode, appState.$sources)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _, _, _ in self?.layout(animatedShrink: true) }
            .store(in: &cancellables)
        appState.$guardianAlerts
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.layout(animatedShrink: true) }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.geometry = .measure()
                self?.layout(animatedShrink: false)
            }
            .store(in: &cancellables)
    }

    private func frame(for size: CGSize) -> CGRect {
        CGRect(x: geometry.screenFrame.midX - size.width / 2, y: geometry.screenFrame.maxY - size.height, width: size.width, height: size.height)
    }

    /// Grow immediately, shrink after the spring settles — the shape morphs inside a stable canvas.
    func layout(animatedShrink: Bool) {
        guard let appState, let panel, let sensor else { return }
        let hidden = !appState.notchEnabled || appState.menuBarOnlyMode
        if hidden {
            panel.orderOut(nil)
            sensor.orderOut(nil)
            return
        }
        let m = NotchMetrics(g: geometry)
        let state = appState.notchState
        let target = m.canvas(for: state, rows: NotchOverlayView.listRows(appState), hasAlert: !appState.guardianAlerts.isEmpty, hasFocus: appState.focusSource != nil)
        let grow = CGSize(width: max(target.width, currentCanvas.width), height: max(target.height, currentCanvas.height))

        shrinkWork?.cancel()
        if grow != currentCanvas {
            currentCanvas = grow
            panel.setFrame(frame(for: grow), display: true)
        }
        if target != grow {
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.currentCanvas = target
                self.panel?.setFrame(self.frame(for: target), display: true)
            }
            shrinkWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + (animatedShrink ? 0.5 : 0), execute: work)
        }

        let interactive = state == .peek || state == .expanded
        panel.ignoresMouseEvents = !interactive
        panel.allowKeyFocus = state == .expanded
        panel.level = (state == .hud || state == .expanded) ? .popUpMenu : .statusBar + 1
        panel.orderFrontRegardless()
        if state == .expanded { panel.makeKey() }

        // Sensor covers the hardware notch (plus ears when compact); hidden while the panel is interactive.
        if interactive || !geometry.hasPhysicalNotch && state == .resting && !appState.shouldShowCompact {
            sensor.orderOut(nil)
        } else {
            let sensorW = state == .compact ? geometry.notchWidth + NotchMetrics.ear * 2 : geometry.notchWidth
            sensor.setFrame(frame(for: CGSize(width: sensorW, height: geometry.notchHeight)), display: false)
            sensor.orderFrontRegardless()
        }
    }

    private func sensorEntered() {
        hoverWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let appState = self?.appState else { return }
            if appState.notchState == .resting || appState.notchState == .compact { appState.setNotchHover(true) }
        }
        hoverWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }

    private func sensorExited() { hoverWork?.cancel() }

    private func sensorClicked() {
        hoverWork?.cancel()
        appState?.notchState = .expanded
    }

    /// Called by the overlay when the pointer leaves the peek shape.
    func pointerLeftPeek() {
        hoverWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let appState = self?.appState, appState.notchState == .peek else { return }
            appState.setNotchHover(false)
        }
        hoverWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    func pointerEnteredPeek() { hoverWork?.cancel() }

    private func startMonitors() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                guard let self, let appState = self.appState, appState.notchState == .expanded || appState.notchState == .peek else { return }
                appState.notchState = appState.shouldShowCompact ? .compact : .resting
            }
        }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53, let appState = self?.appState, appState.notchState == .expanded {
                appState.notchState = appState.shouldShowCompact ? .compact : .resting
                return nil
            }
            return event
        }
        NotchHoverBridge.shared.controller = self
    }

    public func teardown() {
        hoverWork?.cancel()
        shrinkWork?.cancel()
        if let globalMouseMonitor { NSEvent.removeMonitor(globalMouseMonitor) }
        if let localKeyMonitor { NSEvent.removeMonitor(localKeyMonitor) }
        panel?.orderOut(nil)
        sensor?.orderOut(nil)
    }
}

/// Lets the SwiftUI overlay report pointer exits without owning the controller.
@MainActor
final class NotchHoverBridge {
    static let shared = NotchHoverBridge()
    weak var controller: NotchPanelController?
}

// MARK: - Overlay view

private struct BlurFade: ViewModifier {
    let radius: CGFloat
    let opacity: Double
    func body(content: Content) -> some View { content.blur(radius: radius).opacity(opacity) }
}

private extension AnyTransition {
    static var notchContent: AnyTransition {
        .asymmetric(
            insertion: .modifier(active: BlurFade(radius: 6, opacity: 0), identity: BlurFade(radius: 0, opacity: 1))
                .animation(TimbreMotion.enter.delay(0.06)),
            removal: .modifier(active: BlurFade(radius: 4, opacity: 0), identity: BlurFade(radius: 0, opacity: 1))
                .animation(.easeOut(duration: 0.1))
        )
    }
}

public struct NotchOverlayView: View {
    @ObservedObject var appState: AppState
    let geometryProvider: @MainActor () -> NotchScreenGeometry
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let c = TimbreColors.notch

    static func listRows(_ s: AppState) -> Int {
        max(0, min(s.mixerSources.count - 1, 3))
    }

    private var g: NotchScreenGeometry { geometryProvider() }
    private var metrics: NotchMetrics { NotchMetrics(g: g) }

    public var body: some View {
        let state = appState.notchState
        let spec = metrics.body(for: state, rows: Self.listRows(appState), hasAlert: !appState.guardianAlerts.isEmpty, hasFocus: appState.focusSource != nil)
        let shape = NotchShape(width: spec.size.width, height: spec.size.height, bottomRadius: spec.radius, shoulder: metrics.shoulder)

        ZStack(alignment: .top) {
            shape
                .fill(Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 1))
                .opacity(state == .resting && g.hasPhysicalNotch ? 0 : 1)

            content(for: state)
                .frame(width: spec.size.width, height: spec.size.height, alignment: .top)
                .clipShape(shape)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, g.hasPhysicalNotch ? 0 : 6)
        .animation(reduceMotion ? .easeOut(duration: 0.12) : (isOpening(state) ? TimbreMotion.notchOpen : TimbreMotion.notchClose), value: state)
        .animation(TimbreMotion.smooth, value: appState.mixerSources.count)
        .onHover { inside in
            guard appState.notchState == .peek else { return }
            if inside { NotchHoverBridge.shared.controller?.pointerEnteredPeek() } else { NotchHoverBridge.shared.controller?.pointerLeftPeek() }
        }
        .surface(.notch)
        .preferredColorScheme(.dark)
    }

    private func isOpening(_ s: NotchState) -> Bool { s == .peek || s == .expanded || s == .hud }

    @ViewBuilder
    private func content(for state: NotchState) -> some View {
        switch state {
        case .resting: Color.clear
        case .compact: compact.transition(.notchContent)
        case .hud: hud.transition(.notchContent)
        case .peek: peek.transition(.notchContent)
        case .expanded: expanded.transition(.notchContent)
        }
    }

    private var bandHeight: CGFloat { g.notchHeight }
    private var focus: AudioSourceDescriptor? { appState.focusSource }
    private var level: Double? { appState.hasLiveSignal ? min(1, max(0, (appState.telemetry.lufsMomentary + 48) / 40)) : nil }

    // MARK: Compact — two ears, nothing under the camera

    private var compact: some View {
        HStack(spacing: 0) {
            Group {
                if let f = focus {
                    AppIcon(bundleID: f.bundleID, name: f.name, size: 17)
                } else {
                    Image(systemName: "waveform").font(.system(size: 11, weight: .semibold)).foregroundStyle(c.ink_secondary)
                }
            }
            .frame(width: NotchMetrics.ear, height: bandHeight)
            Spacer(minLength: 0)
            Group {
                if let alert = appState.guardianAlerts.first {
                    Circle().fill(alert.severity == .info ? c.semantic_info : c.semantic_warning).frame(width: 6, height: 6)
                } else {
                    MiniMeter(level: level, active: focus?.isPlaying == true && !appState.isProcessingBypassed, color: appState.isProcessingBypassed ? c.ink_muted : c.accent_base)
                }
            }
            .frame(width: NotchMetrics.ear, height: bandHeight)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(focus?.name ?? appState.t("notch.empty_playing"))
    }

    // MARK: HUD — ears + hairline progress under the camera

    private var hud: some View {
        let v = min(max(appState.hudValue, 0), 1)
        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                Image(systemName: appState.hudMuted ? "speaker.slash.fill" : (v < 0.01 ? "speaker.fill" : (v < 0.34 ? "speaker.wave.1.fill" : (v < 0.67 ? "speaker.wave.2.fill" : "speaker.wave.3.fill"))))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(appState.hudMuted ? c.semantic_warning : c.ink_primary)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 56, height: bandHeight)
                Spacer(minLength: 0)
                Text(appState.hudMuted ? appState.t("ui.notch.muted") : Fmt.percent(v))
                    .type(TimbreTypography.monoValue)
                    .fontWeight(.medium)
                    .foregroundStyle(appState.hudMuted ? c.semantic_warning : c.ink_primary)
                    .contentTransition(.numericText(value: v))
                    .frame(width: 56, height: bandHeight)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(c.bg_track)
                    Capsule().fill(appState.hudMuted ? c.ink_muted : c.ink_primary).frame(width: geo.size.width * v)
                }
            }
            .frame(height: 3)
            .padding(.horizontal, 22)
            .padding(.top, 6)
            .animation(.linear(duration: 0.06), value: v)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(appState.hudTitle) \(Fmt.percent(v))%")
    }

    // MARK: Peek — the one control you came for

    private var peek: some View {
        VStack(spacing: 0) {
            topBand(
                leading: AnyView(focusLabel(compact: true)),
                trailing: AnyView(
                    Group {
                        if let f = focus, !f.isVoIPExcluded {
                            HStack(alignment: .firstTextBaseline, spacing: 1) {
                                Text(f.isMuted ? "—" : Fmt.percent(f.volume)).type(TimbreTypography.monoValue).fontWeight(.medium)
                                    .foregroundStyle(f.volume > 1 && !f.isMuted ? c.semantic_warning : c.ink_primary)
                                    .contentTransition(.numericText(value: f.volume))
                                Text("%").type(TimbreTypography.monoSmall).foregroundStyle(c.ink_muted)
                            }
                        }
                    }
                )
            )
            if let f = focus, !f.isVoIPExcluded {
                TFader(value: volumeBinding(f), range: 0...2, unity: 1, tint: c.ink_primary, label: f.name, valueText: Fmt.percent(f.volume), unityPosition: 0.75)
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
            } else {
                Text(appState.t("notch.empty_playing"))
                    .type(TimbreTypography.small)
                    .foregroundStyle(c.ink_muted)
                    .padding(.top, 14)
            }
        }
    }

    // MARK: Expanded — mixer in a breath

    private var expanded: some View {
        VStack(spacing: 0) {
            topBand(
                leading: AnyView(
                    HStack(spacing: 6) {
                        Text("timbr.").font(.system(size: 13, weight: .semibold)).tracking(-0.3).foregroundStyle(c.ink_primary)
                        Circle().fill(appState.isProcessingBypassed ? c.ink_muted : (appState.activeTapsCount > 0 ? c.accent_base : c.semantic_positive)).frame(width: 5, height: 5)
                    }
                ),
                trailing: AnyView(outputLabel)
            )

            if let f = focus {
                focusBlock(f).padding(.horizontal, 20).padding(.top, 10)
            } else {
                VStack(spacing: 4) {
                    Text(appState.t("notch.empty_playing")).type(TimbreTypography.small).foregroundStyle(c.ink_secondary)
                    Text(appState.t("ui.notch.empty_hint")).type(TimbreTypography.caption).foregroundStyle(c.ink_muted)
                }
                .frame(height: 58)
            }

            VStack(spacing: 0) {
                ForEach(appState.mixerSources.filter { $0.bundleID != focus?.bundleID }.prefix(3)) { src in
                    sourceRow(src)
                }
            }
            .padding(.horizontal, 20)

            if let alert = appState.guardianAlerts.first {
                alertRow(alert).padding(.horizontal, 14).padding(.top, 6)
            }

            Spacer(minLength: 0)
            footer
        }
    }

    private func topBand(leading: AnyView, trailing: AnyView) -> some View {
        HStack(spacing: 0) {
            leading.frame(maxWidth: .infinity, alignment: .leading)
            Color.clear.frame(width: g.hasPhysicalNotch ? g.notchWidth : 16)
            trailing.frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .frame(height: bandHeight)
    }

    private func focusLabel(compact: Bool) -> some View {
        HStack(spacing: 7) {
            if let f = focus {
                AppIcon(bundleID: f.bundleID, name: f.name, size: 15)
                Text(f.name).type(TimbreTypography.caption).fontWeight(.medium).foregroundStyle(c.ink_primary).lineLimit(1)
            } else {
                Text("timbr.").font(.system(size: 12, weight: .semibold)).foregroundStyle(c.ink_secondary)
            }
        }
    }

    private var outputLabel: some View {
        HStack(spacing: 6) {
            if let d = appState.activeOutputDevice {
                Image(systemName: d.glyph).font(.system(size: 10.5, weight: .medium)).symbolRenderingMode(.hierarchical)
                Text(d.name).type(TimbreTypography.caption).lineLimit(1)
            }
        }
        .foregroundStyle(c.ink_secondary)
    }

    private func focusBlock(_ f: AudioSourceDescriptor) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                AppIcon(bundleID: f.bundleID, name: f.name, size: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(f.name).type(TimbreTypography.notchTitle).foregroundStyle(c.ink_primary).lineLimit(1)
                    Text(f.isVoIPExcluded ? appState.t("mixer.voip_ignored") : (f.isPlaying ? appState.t("ui.notch.playing") : appState.t("ui.notch.paused")) + " · " + Fmt.volumeDB(f.isMuted ? 0 : f.volume) + " dB")
                        .type(TimbreTypography.caption)
                        .foregroundStyle(c.ink_muted)
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
            if !f.isVoIPExcluded {
                TFader(value: volumeBinding(f), range: 0...2, unity: 1, tint: c.ink_primary, label: f.name, valueText: Fmt.percent(f.volume), unityPosition: 0.75)
            }
        }
        .frame(height: 76, alignment: .top)
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
                Button(appState.t(act)) { appState.runGuardianAction(alert) }
                    .buttonStyle(.t(.secondary, compact: true))
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(c.semantic_warning.opacity(0.1)))
    }

    private var footer: some View {
        HStack(spacing: 6) {
            footerChip(
                title: appState.isProcessingBypassed ? appState.t("ui.notch.eq_off") : appState.t("ui.notch.eq_on"),
                symbol: "power",
                on: !appState.isProcessingBypassed
            ) { appState.toggleBypass() }
            footerChip(title: appState.t("notch.ab_neutral"), symbol: "square.split.2x1", on: appState.abMode != .full) { appState.toggleABNeutral() }
            MenuChip(title: appState.activeOutputDevice?.name ?? "—", symbol: appState.activeOutputDevice?.glyph) {
                ForEach(appState.outputDevices) { dev in
                    Button {
                        appState.selectDefaultOutput(dev)
                    } label: {
                        if dev.isDefaultOutput { Label(dev.name, systemImage: "checkmark") } else { Text(dev.name) }
                    }
                }
            }
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
