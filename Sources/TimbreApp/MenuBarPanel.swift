// SPDX-License-Identifier: MPL-2.0
// Menu bar surface (RF-1303): the same essentials as the expanded notch, for keyboard users,
// Macs without a notch and anyone who hides the notch. Designed panel, not a stock NSMenu.
import SwiftUI
import AppKit
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
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("timbr").font(.system(size: 15, weight: .semibold)).tracking(-0.4)
                        Text(".").font(.system(size: 15, weight: .semibold)).foregroundStyle(c.accent_signal)
                    }
                    .foregroundStyle(c.ink_primary)
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
                            TFader(value: Binding(get: { src.isMuted ? 0 : src.volume }, set: { appState.setSourceVolume(bundleID: src.bundleID, volume: $0) }),
                                   range: 0...2, unity: 1, tint: c.ink_primary, height: 20, trackHeight: 2.5, label: src.name, valueText: Fmt.percent(src.volume), unityPosition: 0.75)
                            Text(src.isMuted ? "—" : Fmt.percent(src.volume)).type(TimbreTypography.monoSmall).foregroundStyle(c.ink_secondary).frame(width: 26, alignment: .trailing)
                            IconButton(symbol: src.isMuted ? "speaker.slash.fill" : "speaker.fill", size: 22, active: src.isMuted, activeColor: c.semantic_warning, help: appState.t("ui.mute")) {
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
                Eyebrow(text: appState.t("ui.mixer.outputs")).padding(.top, 12).padding(.bottom, 4)
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
                        .background(RoundedRectangle(cornerRadius: TimbreRadius.control, style: .continuous).fill(dev.isDefaultOutput ? c.bg_selected : .clear))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8).padding(.bottom, 10)

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
