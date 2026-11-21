// SPDX-License-Identifier: MPL-2.0
import SwiftUI
import AppKit
import Combine
import TimbreCore
import TimbreEngine
import TimbreDesignSystem

public struct NotchScreenGeometry: Equatable, Sendable {
    public let screenFrame: CGRect
    public let hasPhysicalNotch: Bool
    public let notchWidth: CGFloat
    public let notchHeight: CGFloat

    public static func measure(screen: NSScreen? = NSScreen.main ?? NSScreen.screens.first) -> NotchScreenGeometry {
        guard let screen else {
            return NotchScreenGeometry(
                screenFrame: CGRect(x: 0, y: 0, width: 1470, height: 956),
                hasPhysicalNotch: false,
                notchWidth: 180,
                notchHeight: 32
            )
        }
        let topInset = screen.safeAreaInsets.top
        if topInset > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            let gap = max(140, right.minX - left.maxX)
            return NotchScreenGeometry(
                screenFrame: screen.frame,
                hasPhysicalNotch: true,
                notchWidth: gap,
                notchHeight: topInset
            )
        }
        return NotchScreenGeometry(
            screenFrame: screen.frame,
            hasPhysicalNotch: false,
            notchWidth: 176,
            notchHeight: 30
        )
    }
}

private final class NonActivatingNotchPanel: NSPanel {
    var allowKeyFocus = false
    override var canBecomeKey: Bool { allowKeyFocus }
    override var canBecomeMain: Bool { false }
}

@MainActor
public final class NotchPanelController {
    private var panel: NonActivatingNotchPanel?
    private weak var appState: AppState?
    private var cancellables: Set<AnyCancellable> = []
    private var hoverTimer: Timer?
    private var hoverEnterStart: Date?
    private var hoverExitStart: Date?
    private var globalMouseMonitor: Any?
    private var localKeyMonitor: Any?
    private var geometry = NotchScreenGeometry.measure()

    public init(appState: AppState) {
        self.appState = appState
        setupPanel()
        bindState()
        startHoverAndDismissMonitors()
    }

    private func setupPanel() {
        let p = NonActivatingNotchPanel(
            contentRect: CGRect(x: 0, y: 0, width: 420, height: 280),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isFloatingPanel = true
        p.level = .statusBar + 1
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = false
        p.hidesOnDeactivate = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        if let appState {
            let root = NotchOverlayView(appState: appState, geometry: geometry)
            p.contentView = NSHostingView(rootView: root)
        }
        self.panel = p
        updatePanelFrameAndBehavior()
    }

    private func bindState() {
        guard let appState else { return }
        Publishers.CombineLatest4(
            appState.$notchState,
            appState.$notchEnabled,
            appState.$menuBarOnlyMode,
            appState.$sources
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _, _, _, _ in
            self?.updatePanelFrameAndBehavior()
        }
        .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updatePanelFrameAndBehavior() }
            .store(in: &cancellables)
    }

    public func updatePanelFrameAndBehavior() {
        guard let appState, let panel else { return }
        geometry = NotchScreenGeometry.measure()

        if !appState.notchEnabled || appState.menuBarOnlyMode || appState.notchState == .resting {
            panel.allowKeyFocus = false
            panel.ignoresMouseEvents = true
            panel.orderOut(nil)
            return
        }

        let size: CGSize
        switch appState.notchState {
        case .resting:
            size = CGSize(width: geometry.notchWidth, height: geometry.notchHeight)
        case .compact:
            size = CGSize(width: geometry.notchWidth + 84, height: geometry.notchHeight + 4)
        case .hud:
            size = CGSize(width: max(geometry.notchWidth + 110, 290), height: 54)
        case .peek:
            size = CGSize(width: 340, height: 108)
        case .expanded:
            size = CGSize(width: 440, height: 340)
        }

        let topMargin: CGFloat = geometry.hasPhysicalNotch ? 0 : 8
        let originX = geometry.screenFrame.midX - size.width / 2.0
        let originY = geometry.screenFrame.maxY - size.height - topMargin
        panel.setFrame(CGRect(origin: CGPoint(x: originX, y: originY), size: size), display: true, animate: false)

        if appState.notchState == .hud || appState.notchState == .expanded {
            panel.level = .screenSaver
        } else {
            panel.level = .statusBar + 1
        }

        panel.allowKeyFocus = (appState.notchState == .expanded)
        panel.ignoresMouseEvents = (appState.notchState == .hud)
        panel.orderFrontRegardless()
    }

    private func startHoverAndDismissMonitors() {
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.evaluateHoverHysteresis() }
        }
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                guard let self, let appState = self.appState, appState.notchState == .expanded else { return }
                let loc = NSEvent.mouseLocation
                if let frame = self.panel?.frame, !frame.contains(loc) {
                    appState.notchState = appState.shouldShowCompact ? .compact : .resting
                }
            }
        }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53, let appState = self?.appState, appState.notchState == .expanded {
                appState.notchState = appState.shouldShowCompact ? .compact : .resting
                return nil
            }
            return event
        }
    }

    private func evaluateHoverHysteresis() {
        guard let appState, appState.notchEnabled, !appState.menuBarOnlyMode else { return }
        let mouse = NSEvent.mouseLocation
        let hitZone = CGRect(
            x: geometry.screenFrame.midX - (geometry.notchWidth / 2.0 + 42),
            y: geometry.screenFrame.maxY - max(geometry.notchHeight + 8, 40),
            width: geometry.notchWidth + 84,
            height: max(geometry.notchHeight + 12, 42)
        )
        let expandedZone = panel?.frame.insetBy(dx: -8, dy: -8) ?? hitZone

        let insideHover = (appState.notchState == .peek) ? expandedZone.contains(mouse) : hitZone.contains(mouse)

        if insideHover {
            hoverExitStart = nil
            if appState.notchState == .resting || appState.notchState == .compact {
                if hoverEnterStart == nil { hoverEnterStart = Date() }
                if let start = hoverEnterStart, Date().timeIntervalSince(start) >= 0.12 {
                    appState.setNotchHover(true)
                    hoverEnterStart = nil
                }
            }
        } else {
            hoverEnterStart = nil
            if appState.notchState == .peek {
                if hoverExitStart == nil { hoverExitStart = Date() }
                if let exitStart = hoverExitStart, Date().timeIntervalSince(exitStart) >= 0.30 {
                    appState.setNotchHover(false)
                    hoverExitStart = nil
                }
            }
        }
    }

    public func teardown() {
        hoverTimer?.invalidate()
        hoverTimer = nil
        if let globalMouseMonitor { NSEvent.removeMonitor(globalMouseMonitor) }
        if let localKeyMonitor { NSEvent.removeMonitor(localKeyMonitor) }
        panel?.orderOut(nil)
    }
}

public struct NotchOverlayView: View {
    @ObservedObject var appState: AppState
    let geometry: NotchScreenGeometry
    private let colors = TimbreColors.notch
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public var body: some View {
        Group {
            switch appState.notchState {
            case .resting:
                Color.clear
            case .compact:
                compactView
            case .hud:
                hudView
            case .peek:
                peekView
            case .expanded:
                expandedView
            }
        }
        .animation(reduceMotion ? nil : TimbreMotion.morph, value: appState.notchState)
        .onTapGesture {
            if appState.notchState == .compact || appState.notchState == .peek {
                appState.notchState = .expanded
            }
        }
    }

    private var compactView: some View {
        HStack(spacing: 0) {
            // Left ear (<= 40 pt)
            HStack(spacing: TimbreSpacing.s1) {
                Circle()
                    .fill(colors.accent_base)
                    .frame(width: 6, height: 6)
                Text(shortAppLabel)
                    .font(TimbreTypography.micro.font)
                    .foregroundStyle(colors.ink_primary)
                    .lineLimit(1)
            }
            .frame(width: 40, alignment: .leading)
            .padding(.leading, TimbreSpacing.s2)

            Spacer(minLength: geometry.hasPhysicalNotch ? geometry.notchWidth : 12)

            // Right ear (<= 40 pt) — battery micro-glyph when Apple Continuity is live
            HStack(spacing: TimbreSpacing.s1) {
                if let bat = appleCompactBatteryGlyph {
                    Text(bat)
                        .font(TimbreTypography.micro.font)
                        .foregroundStyle(colors.ink_secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                } else if !appState.guardianAlerts.isEmpty {
                    Circle()
                        .fill(colors.semantic_warning)
                        .frame(width: 6, height: 6)
                }
                Image(systemName: appState.isProcessingBypassed ? "waveform.slash" : "waveform")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(appState.isProcessingBypassed ? colors.ink_muted : colors.accent_strong)
            }
            .frame(width: 40, alignment: .trailing)
            .padding(.trailing, TimbreSpacing.s2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.bg_surface)
        .clipShape(RoundedRectangle(cornerRadius: geometry.hasPhysicalNotch ? TimbreRadius.card : TimbreRadius.pill, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: geometry.hasPhysicalNotch ? TimbreRadius.card : TimbreRadius.pill, style: .continuous)
                .stroke(colors.line_default, lineWidth: 1)
        )
    }

    private var hudView: some View {
        HStack(spacing: TimbreSpacing.s3) {
            Image(systemName: appState.hudMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .foregroundStyle(appState.hudMuted ? colors.semantic_warning : colors.accent_base)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(appState.hudTitle)
                        .font(TimbreTypography.small.font)
                        .foregroundStyle(colors.ink_primary)
                        .lineLimit(1)
                    Spacer()
                    Text(appState.hudMuted ? "MUTE" : "\(Int((appState.hudValue * 100).rounded()))%")
                        .font(TimbreTypography.monoValue.font)
                        .foregroundStyle(colors.ink_secondary)
                }
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(colors.bg_track)
                        Capsule()
                            .fill(appState.hudMuted ? colors.ink_muted : colors.accent_base)
                            .frame(width: g.size.width * CGFloat(min(max(appState.hudValue, 0), 1)))
                    }
                }
                .frame(height: 5)
            }
        }
        .padding(.horizontal, TimbreSpacing.s4)
        .padding(.vertical, TimbreSpacing.s2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.bg_surface)
        .clipShape(RoundedRectangle(cornerRadius: TimbreRadius.notchExpanded, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TimbreRadius.notchExpanded, style: .continuous)
                .stroke(colors.line_default, lineWidth: 1)
        )
    }

    private var peekView: some View {
        VStack(alignment: .leading, spacing: TimbreSpacing.s2) {
            HStack {
                Text(appState.sources.first(where: { $0.isPlaying })?.name ?? "timbr.")
                    .font(TimbreTypography.small.font)
                    .foregroundStyle(colors.ink_primary)
                    .lineLimit(1)
                Spacer()
                Button {
                    appState.toggleBypass()
                } label: {
                    Text(appState.isProcessingBypassed ? "Bypass" : "EQ On")
                        .font(TimbreTypography.micro.font)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(appState.isProcessingBypassed ? colors.bg_track : colors.accent_subtle)
                        .foregroundStyle(appState.isProcessingBypassed ? colors.ink_muted : colors.accent_strong)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            if let src = appState.sources.first(where: { $0.isPlaying && !$0.isVoIPExcluded }) {
                HStack(spacing: TimbreSpacing.s2) {
                    Image(systemName: "speaker.wave.2")
                        .font(.system(size: 11))
                        .foregroundStyle(colors.ink_secondary)
                    Slider(
                        value: Binding(
                            get: { src.volume },
                            set: { appState.setSourceVolume(bundleID: src.bundleID, volume: $0) }
                        ),
                        in: 0...4.0
                    )
                    .tint(src.volume > 1.0 ? colors.semantic_warning : colors.accent_base)
                    Text("\(Int((src.volume * 100).rounded()))%")
                        .font(TimbreTypography.monoValue.font)
                        .foregroundStyle(src.volume > 1.0 ? colors.semantic_warning : colors.ink_secondary)
                        .frame(width: 42, alignment: .trailing)
                }
            } else {
                Text(appState.activeOutputDevice?.name ?? "—")
                    .font(TimbreTypography.caption.font)
                    .foregroundStyle(colors.ink_secondary)
            }

            HStack {
                Text(appState.activeOutputDevice?.name ?? "—")
                    .font(TimbreTypography.caption.font)
                    .foregroundStyle(colors.ink_muted)
                    .lineLimit(1)
                Spacer()
                Button(appState.t("notch.open_studio")) {
                    appState.notchState = appState.shouldShowCompact ? .compact : .resting
                    appState.openStudioHandler?()
                }
                .font(TimbreTypography.micro.font)
                .foregroundStyle(colors.accent_strong)
                .buttonStyle(.plain)
            }
        }
        .padding(TimbreSpacing.s3)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.bg_surface)
        .clipShape(RoundedRectangle(cornerRadius: TimbreRadius.notchExpanded, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TimbreRadius.notchExpanded, style: .continuous)
                .stroke(colors.line_default, lineWidth: 1)
        )
    }

    private var expandedView: some View {
        VStack(alignment: .leading, spacing: TimbreSpacing.s3) {
            HStack {
                Text("timbr.")
                    .font(TimbreTypography.cardTitle.font)
                    .foregroundStyle(colors.ink_primary)
                if !appState.competingNotchApps.isEmpty {
                    Text(appState.t("notch.menu_only_badge"))
                        .font(TimbreTypography.micro.font)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(colors.semantic_warning.opacity(0.2))
                        .foregroundStyle(colors.semantic_warning)
                        .clipShape(Capsule())
                }
                Spacer()
                Button(appState.isProcessingBypassed ? "Bypass" : "EQ On") {
                    appState.toggleBypass()
                }
                .font(TimbreTypography.caption.font)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(appState.isProcessingBypassed ? colors.bg_track : colors.accent_subtle)
                .foregroundStyle(appState.isProcessingBypassed ? colors.ink_secondary : colors.accent_strong)
                .clipShape(RoundedRectangle(cornerRadius: TimbreRadius.control))
                .buttonStyle(.plain)

                Button(appState.t("notch.open_studio")) {
                    appState.notchState = appState.shouldShowCompact ? .compact : .resting
                    appState.openStudioHandler?()
                }
                .font(TimbreTypography.caption.font)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(colors.accent_base)
                .foregroundStyle(colors.ink_primary)
                .clipShape(RoundedRectangle(cornerRadius: TimbreRadius.control))
                .buttonStyle(.plain)
            }

            Divider().background(colors.line_default)

            if let telem = appState.driverTelemetry, telem.accessoryFamily != nil {
                HStack(alignment: .center, spacing: TimbreSpacing.s2) {
                    Image(systemName: (AppleAudioAccessoryKind(rawValue: telem.accessoryFamily ?? "") ?? .unknown).sfSymbolName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(colors.ink_primary)
                        .symbolRenderingMode(.hierarchical)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(telem.modelIdentifier ?? appState.t("dev.apple.family"))
                            .font(TimbreTypography.small.font)
                            .foregroundStyle(colors.ink_primary)
                            .lineLimit(1)
                        AppleAccessoryBatteryStrip(
                            telemetry: telem,
                            t: appState.t,
                            colors: colors,
                            compact: true
                        )
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 2)
                .accessibilityElement(children: .combine)
            }

            // Active Sources
            Text(appState.t("mixer.title"))
                .font(TimbreTypography.micro.font)
                .foregroundStyle(colors.ink_muted)

            ScrollView {
                VStack(spacing: TimbreSpacing.s2) {
                    if appState.sources.isEmpty {
                        Text(appState.t("mixer.no_taps"))
                            .font(TimbreTypography.caption.font)
                            .foregroundStyle(colors.ink_muted)
                    }
                    ForEach(appState.sources.prefix(5)) { src in
                        HStack(spacing: TimbreSpacing.s2) {
                            Text(src.name)
                                .font(TimbreTypography.small.font)
                                .foregroundStyle(colors.ink_primary)
                                .frame(width: 96, alignment: .leading)
                                .lineLimit(1)
                            if src.isVoIPExcluded {
                                Text(appState.t("mixer.voip_ignored"))
                                    .font(TimbreTypography.micro.font)
                                    .foregroundStyle(colors.semantic_info)
                                Spacer()
                            } else {
                                Slider(
                                    value: Binding(
                                        get: { src.volume },
                                        set: { appState.setSourceVolume(bundleID: src.bundleID, volume: $0) }
                                    ),
                                    in: 0...4.0
                                )
                                .tint(src.volume > 1.0 ? colors.semantic_warning : colors.accent_base)
                                Text("\(Int((src.volume * 100).rounded()))%")
                                    .font(TimbreTypography.monoValue.font)
                                    .foregroundStyle(colors.ink_secondary)
                                    .frame(width: 40, alignment: .trailing)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 110)

            Divider().background(colors.line_default)

            // Output quick selector
            HStack {
                Text(appState.t("mixer.destinations"))
                    .font(TimbreTypography.micro.font)
                    .foregroundStyle(colors.ink_muted)
                Spacer()
                Menu(appState.activeOutputDevice?.name ?? "—") {
                    ForEach(appState.outputDevices) { dev in
                        Button(dev.name) { appState.selectDefaultOutput(dev) }
                    }
                }
                .font(TimbreTypography.small.font)
            }

            if let topAlert = appState.guardianAlerts.first {
                HStack(spacing: TimbreSpacing.s2) {
                    Circle().fill(colors.semantic_warning).frame(width: 7, height: 7)
                    Text(appState.t(topAlert.titleKey))
                        .font(TimbreTypography.caption.font)
                        .foregroundStyle(colors.ink_primary)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(TimbreSpacing.s2)
                .background(colors.bg_raised)
                .clipShape(RoundedRectangle(cornerRadius: TimbreRadius.control))
            }
        }
        .padding(TimbreSpacing.s4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.bg_surface)
        .clipShape(RoundedRectangle(cornerRadius: TimbreRadius.notchExpanded, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TimbreRadius.notchExpanded, style: .continuous)
                .stroke(colors.line_default, lineWidth: 1)
        )
    }

    private var shortAppLabel: String {
        let name = appState.sources.first(where: { $0.isPlaying })?.name ?? "♪"
        return String(name.prefix(4))
    }

    /// Compact right-ear glyph: min(L,R) when Continuity is live (bible: no clutter).
    private var appleCompactBatteryGlyph: String? {
        guard let telem = appState.driverTelemetry, telem.accessoryFamily != nil else { return nil }
        let pods = [telem.batteryLeftPercent, telem.batteryRightPercent].compactMap { $0 }
        if let minPod = pods.min() { return "\(minPod)" }
        if let bat = telem.batteryPercent { return "\(bat)" }
        return nil
    }
}
