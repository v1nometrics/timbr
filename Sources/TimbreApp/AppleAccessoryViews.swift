// SPDX-License-Identifier: MPL-2.0
import SwiftUI
import TimbreCore
import TimbreEngine
import TimbreDesignSystem

/// Shared Apple accessory strip — Observatório, Mixer destinations, Notch expanded.
/// Design bible: SourceOriginBadge colors, no fake ANC toggles, Reduce Motion safe springs.
public struct AppleAccessoryBatteryStrip: View {
    let telemetry: HardwareDriverTelemetry
    let t: (String) -> String
    let colors: TimbreColors
    var compact: Bool = false

    public init(
        telemetry: HardwareDriverTelemetry,
        t: @escaping (String) -> String,
        colors: TimbreColors,
        compact: Bool = false
    ) {
        self.telemetry = telemetry
        self.t = t
        self.colors = colors
        self.compact = compact
    }

    public var body: some View {
        HStack(spacing: compact ? 4 : TimbreSpacing.s2) {
            if let left = telemetry.batteryLeftPercent {
                cell(t("dev.apple.battery_l"), left, charging: telemetry.leftCharging == true)
            }
            if let right = telemetry.batteryRightPercent {
                cell(t("dev.apple.battery_r"), right, charging: telemetry.rightCharging == true)
            }
            if let cse = telemetry.batteryCasePercent {
                cell(t("dev.apple.battery_case"), cse, charging: telemetry.caseCharging == true)
            }
            if telemetry.batteryLeftPercent == nil,
               telemetry.batteryRightPercent == nil,
               let bat = telemetry.batteryPercent {
                cell(t("dev.m4.battery"), bat, charging: telemetry.isCharging == true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func cell(_ label: String, _ pct: Int, charging: Bool) -> some View {
        HStack(spacing: 3) {
            Text(compact ? "\(label)\(pct)" : "\(label) \(pct)%")
                .font(compact ? TimbreTypography.micro.font : TimbreTypography.monoValue.font)
                .foregroundStyle(pct < 20 ? colors.semantic_warning : colors.ink_primary)
            if charging {
                Image(systemName: "bolt.fill")
                    .font(.system(size: compact ? 7 : 9, weight: .semibold))
                    .foregroundStyle(colors.semantic_positive)
                    .accessibilityLabel("charging")
            }
        }
        .padding(.horizontal, compact ? 5 : 7)
        .padding(.vertical, compact ? 2 : 3)
        .background((pct < 20 ? colors.semantic_warning : colors.semantic_positive).opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: TimbreRadius.badge, style: .continuous))
    }
}

public struct AppleAccessoryCard: View {
    @ObservedObject var appState: AppState
    let telemetry: HardwareDriverTelemetry
    let colors: TimbreColors
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(appState: AppState, telemetry: HardwareDriverTelemetry, colors: TimbreColors) {
        self.appState = appState
        self.telemetry = telemetry
        self.colors = colors
    }

    private var kind: AppleAudioAccessoryKind {
        AppleAudioAccessoryKind(rawValue: telemetry.accessoryFamily ?? "") ?? .unknown
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: TimbreSpacing.s3) {
            HStack(alignment: .center, spacing: TimbreSpacing.s3) {
                Image(systemName: kind.sfSymbolName)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(colors.ink_primary)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 36, height: 36)
                    .background(colors.bg_track)
                    .clipShape(RoundedRectangle(cornerRadius: TimbreRadius.control, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(telemetry.modelIdentifier ?? kind.displayName)
                        .type(TimbreTypography.cardTitle)
                        .foregroundStyle(colors.ink_primary)
                    Text(appState.t("dev.apple.family"))
                        .type(TimbreTypography.eyebrow)
                        .foregroundStyle(colors.ink_muted)
                        .tracking(1.1)
                }
                Spacer()
                trustBadge
                originBadge(appState.t("dev.m4.read_only"), tone: .muted)
            }

            AppleAccessoryBatteryStrip(telemetry: telemetry, t: appState.t, colors: colors)

            if let codec = telemetry.reportedCodec {
                originBadge(codec, tone: .info)
            }

            Text(appState.t("dev.apple.aacp_closed"))
                .type(TimbreTypography.caption)
                .foregroundStyle(colors.ink_muted)
                .fixedSize(horizontal: false, vertical: true)

            Text(appState.t("dev.apple.continuity_hint"))
                .type(TimbreTypography.caption)
                .foregroundStyle(colors.ink_muted)
                .fixedSize(horizontal: false, vertical: true)

            if telemetry.spatialAudioMayAlterFR == true {
                Text(appState.t("dev.apple.spatial_warn"))
                    .type(TimbreTypography.caption)
                    .foregroundStyle(colors.semantic_warning)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let keys = telemetry.systemManagedFeatureKeys, !keys.isEmpty {
                VStack(alignment: .leading, spacing: TimbreSpacing.s2) {
                    Text(appState.t("dev.apple.features_title"))
                        .type(TimbreTypography.small)
                        .foregroundStyle(colors.ink_secondary)
                    Text(appState.t("dev.apple.features_system"))
                        .type(TimbreTypography.caption)
                        .foregroundStyle(colors.ink_muted)
                    FlowFeatureChips(keys: keys, t: appState.t, colors: colors)
                }
                .padding(.top, TimbreSpacing.s1)
            }

            HStack {
                Spacer()
                Button(appState.t("dev.apple.refresh_scan")) {
                    ContinuityBLEScanner.shared.requestScanBurst()
                    appState.refreshSystemState()
                }
                .buttonStyle(.t(.secondary))
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
        .animation(reduceMotion ? nil : TimbreMotion.enter, value: telemetry.modelIdentifier)
    }

    private var trustBadge: some View {
        let key: String
        let tone: BadgeTone
        switch telemetry.trustBadge {
        case .measured:
            key = "obs.badge.measured"; tone = .positive
        case .reported:
            key = "obs.badge.reported"; tone = .info
        case .bitPerfect:
            key = "obs.badge.bitperfect"; tone = .positive
        default:
            key = "obs.badge.inferred"; tone = .muted
        }
        return originBadge(appState.t(key), tone: tone)
    }

    private enum BadgeTone { case positive, info, warning, muted }

    private func originBadge(_ text: String, tone: BadgeTone) -> some View {
        let color: Color = switch tone {
        case .positive: colors.semantic_positive
        case .info: colors.semantic_info
        case .warning: colors.semantic_warning
        case .muted: colors.ink_muted
        }
        return Text(text)
            .type(TimbreTypography.micro)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(tone == .muted ? colors.bg_track : color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: TimbreRadius.badge, style: .continuous))
    }
}

private struct FlowFeatureChips: View {
    let keys: [String]
    let t: (String) -> String
    let colors: TimbreColors

    var body: some View {
        // Simple wrap via LazyVGrid — no interactive toggles (systemManaged)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(keys, id: \.self) { key in
                Text(t("dev.apple.feature.\(key)"))
                    .type(TimbreTypography.micro)
                    .foregroundStyle(colors.ink_secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(colors.bg_track)
                    .clipShape(RoundedRectangle(cornerRadius: TimbreRadius.badge, style: .continuous))
                    .accessibilityLabel(t("dev.apple.feature.\(key)"))
                    .accessibilityHint(t("dev.apple.features_system"))
            }
        }
    }
}
