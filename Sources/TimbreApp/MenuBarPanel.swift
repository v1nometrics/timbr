// SPDX-License-Identifier: MPL-2.0
// Menu bar surface (RF-1303): the same essentials as the expanded notch, for keyboard users,
// Macs without a notch and anyone who hides the notch. Designed panel, not a stock NSMenu.
import SwiftUI
import AppKit
import Combine
import TimbreCore
import TimbreEngine
import TimbreDesignSystem

struct MenuBarPanel: View {
    let delegate: AppDelegate
    @ObservedObject var appState: AppState
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let kind: TimbreSurface = scheme == .dark ? .dark : .light
        let c = TimbreColors.forSurface(kind)
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .center, spacing: 8) {
                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                            Text("timbr").font(.system(size: 15, weight: .semibold)).tracking(-0.4)
                        }
                        .foregroundStyle(c.ink_primary)
                        LiveMiniMeter(liveMeters: appState.liveMeters,
                                      hasLiveSignal: appState.hasLiveSignal,
                                      active: !appState.playingSources.isEmpty && !appState.isProcessingBypassed,
                                      color: appState.isProcessingBypassed ? c.ink_muted : c.accent_base)
                    }
                    Text((appState.isProcessingBypassed ? appState.t("ui.path.bypassed") : (appState.pathIsNative ? appState.t("ui.path.native") : appState.t("ui.path.processing"))) + " · " + (appState.activeOutputDevice?.name ?? "—")).type(TimbreTypography.caption).foregroundStyle(c.ink_muted).lineLimit(1)
                }
                Spacer()
                TSwitch(isOn: Binding(get: { !appState.isProcessingBypassed }, set: { _ in appState.toggleBypass() }), label: appState.t("ui.action.processing"))
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 12)

            Hairline()

            // Sources
            VStack(alignment: .leading, spacing: 0) {
                Eyebrow(text: appState.t("mixer.title")).padding(.top, 12).padding(.bottom, 4)
                if appState.mixerSources.isEmpty {
                    Text(appState.t("notch.empty_playing")).type(TimbreTypography.small).foregroundStyle(c.ink_muted).frame(height: 36)
                }
                ForEach(appState.mixerSources.prefix(5)) { src in
                    HStack(spacing: 10) {
                        AppIcon(bundleID: src.bundleID, name: src.name, size: 18)
                        Text(src.name).type(TimbreTypography.small).foregroundStyle(c.ink_primary).lineLimit(1).frame(width: 92, alignment: .leading)
                        if src.isVoIPExcluded {
                            Text(appState.t("mixer.voip_ignored")).type(TimbreTypography.micro).foregroundStyle(c.ink_muted)
                            Spacer()
                        } else {
                            LiveMenuBarSourceFader(
                                liveMeters: appState.liveMeters,
                                hasLiveSignal: appState.hasLiveSignal,
                                src: src,
                                tint: c.ink_primary,
                                onVolumeChange: { appState.setSourceVolume(bundleID: src.bundleID, volume: $0) }
                            )
                            Text(src.isMuted ? "—" : Fmt.percent(src.volume)).type(TimbreTypography.monoSmall).foregroundStyle(c.ink_secondary).frame(width: 26, alignment: .trailing)
                            TChannelButton(text: "M", pressed: src.isMuted, tone: .mute, help: appState.t("ui.mute")) {
                                appState.toggleSourceMute(bundleID: src.bundleID)
                            }
                        }
                    }
                    .frame(height: 34)
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 8)

            Hairline()

            // Outputs
            VStack(alignment: .leading, spacing: 2) {
                // The rows bleed 8 pt for their selection plate; the eyebrow keeps the panel's 16 pt edge.
                Eyebrow(text: appState.t("ui.mixer.outputs")).padding(.top, 12).padding(.bottom, 4).padding(.leading, 8)
                ForEach(appState.outputDevices) { dev in
                    Button {
                        appState.selectDefaultOutput(dev)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: dev.glyph).font(.system(size: 12)).symbolRenderingMode(.hierarchical).frame(width: 18)
                                .foregroundStyle(dev.isDefaultOutput ? c.ink_primary : c.ink_secondary)
                            Text(dev.name).type(TimbreTypography.small).foregroundStyle(c.ink_primary).lineLimit(1)
                            Spacer()
                            Text(dev.rateLabel).type(TimbreTypography.monoSmall).foregroundStyle(c.ink_muted)
                            Image(systemName: "checkmark").font(.system(size: 10, weight: .semibold)).foregroundStyle(c.ink_primary).opacity(dev.isDefaultOutput ? 1 : 0)
                        }
                        .padding(.horizontal, 8)
                        .frame(height: 28)
                        .background(RoundedRectangle(cornerRadius: TimbreRadius.field, style: .continuous).fill(dev.isDefaultOutput ? c.bg_selected : .clear))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8).padding(.bottom, 10)

            if let remote = appState.updater.availableManifest {
                Hairline()
                Button {
                    appState.openUpdatesSettings()
                } label: {
                    HStack(spacing: 8) {
                        Circle().fill(c.semantic_info).frame(width: 6, height: 6)
                        Text(String(format: appState.t("ui.updates.available_title"), remote.displayVersion))
                            .type(TimbreTypography.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(c.ink_primary)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(c.ink_secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Hairline()

            HStack(spacing: 6) {
                Button(appState.t("notch.open_studio")) { delegate.openStudio() }
                    .buttonStyle(.t(.primary, compact: true))
                    .keyboardShortcut(",", modifiers: [.command, .option])
                Button(appState.t("notch.ab_neutral")) { appState.toggleABNeutral() }
                    .buttonStyle(.t(.secondary, compact: true))
                Spacer()
                Button(appState.t("ui.quit")) { NSApp.terminate(nil) }
                    .buttonStyle(.t(.ghost, compact: true))
                    .keyboardShortcut("q")
            }
            .padding(12)
        }
        .frame(width: 348)
        .background(c.bg_canvas)
        .surface(kind)
    }
}

/// The menu bar icon (NSStatusItem) and its panel (NSPopover). Present only while the notch is not
/// the way in — no notch screen, notch off, menu-bar-only mode — or when the person asks for it.
@MainActor
final class MenuBarIconController: NSObject {
    private var item: NSStatusItem?
    private let popover = NSPopover()
    private weak var appState: AppState?
    private var watch: AnyCancellable?
    private var bypassWatch: AnyCancellable?

    init(delegate: AppDelegate, appState: AppState) {
        self.appState = appState
        super.init()
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: MenuBarPanel(delegate: delegate, appState: appState))
        watch = Publishers.CombineLatest4(appState.$showMenuBarIcon, appState.$menuBarOnlyMode, appState.$notchEnabled, appState.$notchScreenAvailable)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _, _, _ in self?.sync() }
        bypassWatch = appState.$isProcessingBypassed
            .receive(on: RunLoop.main)
            .sink { [weak self] bypassed in self?.setSymbol(bypassed: bypassed) }
    }

    private func sync() {
        guard let appState else { return }
        if appState.menuBarIconVisible {
            guard item == nil else { return }
            let it = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            // Our own visibility rule decides; don't inherit a stale "hidden" state macOS persisted for
            // the old SwiftUI MenuBarExtra item.
            it.autosaveName = "timbr.status"
            it.isVisible = true
            it.button?.target = self
            it.button?.action = #selector(toggle(_:))
            it.button?.setAccessibilityLabel("timbr")
            item = it
            setSymbol(bypassed: appState.isProcessingBypassed)
        } else if let it = item {
            popover.performClose(nil)
            NSStatusBar.system.removeStatusItem(it)
            item = nil
        }
    }

    private func setSymbol(bypassed: Bool) {
        if let url = Bundle.main.url(forResource: "TimbrMenuTemplate", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.size = NSSize(width: 24, height: 10)
            image.isTemplate = true
            item?.button?.image = image
            item?.button?.appearsDisabled = bypassed
            item?.button?.setAccessibilityLabel("timbr")
        }
    }

    @objc private func toggle(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}

private struct LiveMenuBarSourceFader: View {
    @ObservedObject var liveMeters: LiveMeterModel
    let hasLiveSignal: Bool
    let src: AudioSourceDescriptor
    let tint: Color
    let onVolumeChange: @MainActor @Sendable (Double) -> Void

    var body: some View {
        let norm: Double? = (!src.isPlaying || src.isMuted || !hasLiveSignal)
            ? nil
            : min(1, max(0, (liveMeters.telemetry.lufsMomentary + 60) / 60) * min(1.0, src.volume))
        TFader(
            value: Binding(get: { src.isMuted ? 0 : src.volume }, set: { onVolumeChange($0) }),
            range: 0...2,
            unity: 1,
            tint: tint,
            height: 20,
            trackHeight: 2.5,
            label: src.name,
            valueText: Fmt.percent(src.volume),
            unityPosition: 0.75,
            liveMeterNorm: norm,
            scaleMarks: [0.25, 0.5, 0.75, 1.5]
        )
    }
}
