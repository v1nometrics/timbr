// SPDX-License-Identifier: MPL-2.0
// Studio window (docs/05-design-system/03-superficies.md §Estúdio).
// Editorial layout inherited from the Órbita/ronda reports: numbered sections, KPI tiles,
// hairline tables, one accent used only for the audio signal. Progressive disclosure:
// the primary task of each page is above the fold; secondary tools sit below in columns.
import SwiftUI
import AppKit
import TimbreCore
import TimbreEngine
import TimbreDesignSystem
import CoreBluetooth

public struct StudioWindow: View {
    @ObservedObject var appState: AppState
    @Environment(\.colorScheme) private var systemScheme
    @AppStorage("timbr.studioAppearance") private var appearance = "system"

    public init(appState: AppState) { self.appState = appState }

    private var kind: TimbreSurface {
        switch appearance {
        case "light": return .light
        case "dark": return .dark
        default: return systemScheme == .dark ? .dark : .light
        }
    }

    public var body: some View {
        let c = TimbreColors.forSurface(kind)
        HStack(spacing: 0) {
            StudioSidebar(appState: appState)
                .frame(width: 224)
                .background(c.bg_sidebar)
            Hairline(vertical: true)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let banner = appState.statusBanner {
                        BannerView(text: banner) { appState.statusBanner = nil }
                            .padding(.bottom, TimbreSpacing.s5)
                    }
                    page
                        .id(appState.selectedTab)
                        .transition(.opacity)
                }
                .padding(.horizontal, 40)
                .padding(.top, 44)
                .padding(.bottom, 56)
                .frame(maxWidth: 1120, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.automatic)
            .background(c.bg_canvas)
        }
        .animation(.easeOut(duration: 0.14), value: appState.selectedTab)
        .surface(kind)
        .preferredColorScheme(appearance == "light" ? .light : (appearance == "dark" ? .dark : nil))
        .frame(minWidth: 980, minHeight: 640)
        .ignoresSafeArea(.container, edges: .top)
    }

    @ViewBuilder private var page: some View {
        switch appState.selectedTab {
        case .mixer: MixerPage(appState: appState)
        case .equalizer: EqualizerPage(appState: appState)
        case .observatory: ObservatoryPage(appState: appState)
        case .settings: SettingsPage(appState: appState, appearance: $appearance)
        case .support: AboutPage(appState: appState)
        }
    }
}

// MARK: - Sidebar

private struct StudioSidebar: View {
    @ObservedObject var appState: AppState
    @Environment(\.palette) private var c

    private func title(_ t: StudioTab) -> String {
        switch t {
        case .mixer: return appState.t("nav.mixer")
        case .equalizer: return appState.t("nav.eq")
        case .observatory: return appState.t("nav.observatory")
        case .settings: return appState.t("nav.settings")
        case .support: return appState.t("ui.nav.about")
        }
    }
    private func symbol(_ t: StudioTab) -> String {
        switch t {
        case .mixer: return "slider.vertical.3"
        case .equalizer: return "point.bottomleft.forward.to.point.topright.scurvepath"
        case .observatory: return "waveform.path.ecg.rectangle"
        case .settings: return "gearshape"
        case .support: return "info.circle"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Leave room for the traffic lights (full-size content view).
            Color.clear.frame(height: 44)
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("timbr").font(.system(size: 19, weight: .semibold)).tracking(-0.6)
                Text(".").font(.system(size: 19, weight: .semibold)).foregroundStyle(c.accent_signal)
            }
            .foregroundStyle(c.ink_primary)
            .padding(.horizontal, 20)
            .padding(.bottom, 22)

            VStack(spacing: 2) {
                ForEach([StudioTab.mixer, .equalizer, .observatory], id: \.self) { tab in item(tab) }
            }
            .padding(.horizontal, 10)

            Eyebrow(text: appState.t("ui.nav.app"))
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 6)
            VStack(spacing: 2) {
                ForEach([StudioTab.settings, .support], id: \.self) { tab in item(tab) }
            }
            .padding(.horizontal, 10)

            Spacer()
            statusBlock
        }
    }

    private func item(_ tab: StudioTab) -> some View {
        let selected = appState.selectedTab == tab
        return Button {
            appState.selectedTab = tab
        } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol(tab))
                    .font(.system(size: 12.5, weight: .medium))
                    .frame(width: 18)
                    .foregroundStyle(selected ? c.ink_primary : c.ink_secondary)
                Text(title(tab))
                    .type(TimbreTypography.body)
                    .fontWeight(selected ? .medium : .regular)
                    .foregroundStyle(selected ? c.ink_primary : c.ink_secondary)
                Spacer()
                if tab == .observatory, !appState.guardianAlerts.isEmpty {
                    Text("\(appState.guardianAlerts.count)")
                        .type(TimbreTypography.monoSmall)
                        .foregroundStyle(c.semantic_warning)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(RoundedRectangle(cornerRadius: TimbreRadius.control, style: .continuous).fill(selected ? c.bg_selected : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(KeyEquivalent(Character(String([StudioTab.mixer, .equalizer, .observatory, .settings, .support].firstIndex(of: tab)! + 1))), modifiers: .command)
    }

    private var statusBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Hairline()
            HStack(spacing: 7) {
                Circle()
                    .fill(appState.isProcessingBypassed ? c.ink_muted : (appState.pathIsNative ? c.semantic_positive : c.accent_signal))
                    .frame(width: 6, height: 6)
                Text(appState.isProcessingBypassed ? appState.t("ui.path.bypassed") : (appState.pathIsNative ? appState.t("ui.path.native") : appState.t("ui.path.processing")))
                    .type(TimbreTypography.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(c.ink_primary)
            }
            .padding(.top, 8)
            Text(appState.activeOutputDevice.map { "\($0.name) · \($0.rateLabel)" } ?? "—")
                .type(TimbreTypography.caption)
                .foregroundStyle(c.ink_muted)
                .lineLimit(1)
            Button(appState.isProcessingBypassed ? appState.t("ui.action.resume") : appState.t("ui.action.bypass")) {
                appState.toggleBypass()
            }
            .buttonStyle(.t(.secondary, compact: true))
            .padding(.top, 2)
            .keyboardShortcut("b", modifiers: [.command, .option])
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
}

// MARK: - Shared page chrome

private struct PageHeader<Actions: View>: View {
    let index: String
    let title: String
    let summary: String
    @ViewBuilder var actions: () -> Actions
    @Environment(\.palette) private var c

    var body: some View {
        HStack(alignment: .bottom, spacing: TimbreSpacing.s6) {
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(text: index)
                Text(title).type(TimbreTypography.pageTitle).foregroundStyle(c.ink_primary)
                Text(summary)
                    .type(TimbreTypography.body)
                    .foregroundStyle(c.ink_secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 560, alignment: .leading)
            }
            Spacer(minLength: 0)
            HStack(spacing: 8) { actions() }
        }
        .padding(.bottom, 28)
    }
}

private struct BannerView: View {
    let text: String
    let onClose: () -> Void
    @Environment(\.palette) private var c
    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(c.semantic_warning).frame(width: 6, height: 6)
            Text(text).type(TimbreTypography.small).foregroundStyle(c.ink_primary)
            Spacer()
            IconButton(symbol: "xmark", size: 22, help: "Close", action: onClose)
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background(RoundedRectangle(cornerRadius: TimbreRadius.card, style: .continuous).fill(c.semantic_warning.opacity(0.08)))
    }
}

/// Table-like list inside a card: header row in eyebrows, rows separated by hairlines.
private struct ListCard<Content: View>: View {
    @ViewBuilder var content: () -> Content
    @Environment(\.palette) private var c
    var body: some View {
        VStack(spacing: 0) { content() }
            .background(RoundedRectangle(cornerRadius: TimbreRadius.card, style: .continuous).fill(c.bg_surface))
            .overlay(RoundedRectangle(cornerRadius: TimbreRadius.card, style: .continuous).strokeBorder(c.line_default, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: TimbreRadius.card, style: .continuous))
    }
}

private struct EmptyStateView: View {
    let title: String
    let detail: String
    @Environment(\.palette) private var c
    var body: some View {
        VStack(spacing: 6) {
            Eyebrow(text: title)
            Text(detail).type(TimbreTypography.small).foregroundStyle(c.ink_muted).multilineTextAlignment(.center).frame(maxWidth: 380)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
    }
}

// MARK: - Observatory timeline (search, filter, paginate, export — ADR-0018)

/// Design review (`--timeline-preview [--timeline-search <text>] [--timeline-category <name>]`): the
/// timeline alone in its own window, with search and filter already applied.
struct TimelinePreview: View {
    @ObservedObject var appState: AppState
    var body: some View {
        let c = TimbreColors.forSurface(.dark)
        ScrollView { TimelineSection(appState: appState, index: "04").padding(32) }
            .background(c.bg_canvas).surface(.dark).preferredColorScheme(.dark)
            .frame(width: 1000, height: 720)
    }
}

private struct TimelineSection: View {
    @ObservedObject var appState: AppState
    let index: String
    @StateObject private var model: ObservatoryTimelineModel
    @Environment(\.palette) private var c

    init(appState: AppState, index: String) {
        self.appState = appState
        self.index = index
        let m = ObservatoryTimelineModel(databasePath: appState.eventLogPath)
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--timeline-search"), i + 1 < args.count { m.text = args[i + 1] }
        if let i = args.firstIndex(of: "--timeline-category"), i + 1 < args.count { m.selectedCategories = [args[i + 1]] }
        _model = StateObject(wrappedValue: m)
    }

    private func count(_ n: Int) -> String { n.formatted(.number) }

    private var categoryTitle: String {
        switch model.selectedCategories.count {
        case 0: return appState.t("ui.obs.categories_all")
        case 1: return model.selectedCategories.first!
        default: return String(format: appState.t("ui.obs.categories_n"), model.selectedCategories.count)
        }
    }

    private var status: String {
        if model.searchTooShort { return appState.t("ui.obs.search_min") }
        if let total = model.total { return String(format: appState.t("ui.obs.showing"), count(model.rows.count), count(total)) }
        return String(format: appState.t("ui.obs.showing_open"), count(model.rows.count))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(index: index, title: appState.t("ui.obs.timeline_title"), subtitle: appState.t("ui.obs.timeline_sub")) {
                MenuChip(title: appState.t("ui.obs.export"), symbol: "square.and.arrow.up") {
                    Button(appState.t("ui.obs.export_csv")) { export(.csv) }
                    Button(appState.t("ui.obs.export_json")) { export(.json) }
                }
                .disabled(model.isExporting || model.total == 0)
                .help(appState.t("ui.obs.export_scope"))
            }

            HStack(spacing: 10) {
                TField(placeholder: appState.t("ui.obs.search_placeholder"), text: $model.text)
                    .frame(maxWidth: 320)
                MenuChip(title: categoryTitle, symbol: "line.3.horizontal.decrease") {
                    Button { model.selectedCategories = [] } label: {
                        if model.selectedCategories.isEmpty { Label(appState.t("ui.obs.categories_all"), systemImage: "checkmark") }
                        else { Text(appState.t("ui.obs.categories_all")) }
                    }
                    ForEach(model.categories, id: \.self) { cat in
                        Button {
                            if model.selectedCategories.contains(cat) { model.selectedCategories.remove(cat) } else { model.selectedCategories.insert(cat) }
                        } label: {
                            if model.selectedCategories.contains(cat) { Label(cat, systemImage: "checkmark") } else { Text(cat) }
                        }
                    }
                }
                Spacer()
                Text(status).type(TimbreTypography.monoSmall).foregroundStyle(c.ink_muted)
            }

            ListCard {
                if model.rows.isEmpty {
                    if model.isLoading {
                        EmptyStateView(title: appState.t("ui.obs.loading"), detail: "")
                    } else if model.isFiltering {
                        EmptyStateView(title: appState.t("ui.obs.no_results"), detail: appState.t("ui.obs.no_results_detail"))
                    } else {
                        EmptyStateView(title: appState.t("ui.obs.no_events"), detail: appState.t("ui.obs.no_events_detail"))
                    }
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(model.rows.enumerated()), id: \.element.id) { i, row in
                            if i > 0 { Hairline().padding(.leading, 20) }
                            eventRow(row.event)
                                .onAppear { model.loadMoreIfNeeded(currentIndex: i) }
                        }
                        if model.hasMore {
                            Text(appState.t("ui.obs.loading")).type(TimbreTypography.caption).foregroundStyle(c.ink_faint)
                                .frame(maxWidth: .infinity).frame(height: 38)
                        }
                    }
                }
            }
        }
        .task { model.start() }
        .onChange(of: appState.eventLogRevision) { _, _ in model.refreshHead() }
    }

    private func eventRow(_ ev: ObservatoryEvent) -> some View {
        HStack(spacing: 14) {
            Text(ev.timestamp.formatted(.dateTime.day(.twoDigits).month(.twoDigits).hour().minute().second()))
                .type(TimbreTypography.monoSmall).foregroundStyle(c.ink_muted).frame(width: 104, alignment: .leading)
            Text(ev.category).type(TimbreTypography.micro).foregroundStyle(c.ink_secondary).frame(width: 90, alignment: .leading)
            Text(ev.message).type(TimbreTypography.small).foregroundStyle(c.ink_primary).lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 8)
            if let b = ev.badge { OriginMark(origin: b) }
        }
        .padding(.horizontal, 20).frame(height: 38)
        .help(ev.message)   // full text on hover: the row truncates long messages
    }

    private func export(_ format: EventExportFormat) {
        let stamp = Date().formatted(.iso8601.year().month().day())
        Task {
            do {
                if let n = try await model.export(format, suggestedName: "timbr-timeline-\(stamp)", message: appState.t("ui.obs.export_scope")) {
                    appState.statusBanner = String(format: appState.t("ui.obs.exported"), count(n))
                    appState.logEvent(category: "diagnostics", message: "Exported \(n) timeline events (\(format.fileExtension.uppercased()))")
                }
            } catch is CancellationError {
            } catch {
                appState.statusBanner = appState.t("ui.obs.export_failed")
            }
        }
    }
}

// MARK: - 01 Mixer

private struct MixerPage: View {
    @ObservedObject var appState: AppState
    @Environment(\.palette) private var c

    var body: some View {
        VStack(alignment: .leading, spacing: 36) {
            PageHeader(index: "01 — " + appState.t("nav.mixer"), title: appState.t("ui.mixer.title"), summary: appState.signalSummary) {
                Button(appState.t("ui.mixer.reset")) { appState.resetAllSourceVolumesToFlat() }
                    .buttonStyle(.t(.secondary))
                    .disabled(!appState.hasNonFlatSourceVolumes)
                    .help(appState.t("mixer.reset_flat_help"))
            }
            .padding(.bottom, -28)

            kpis

            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(index: "01", title: appState.t("mixer.title"), subtitle: appState.t("ui.mixer.sources_sub"))
                sources
            }
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(index: "02", title: appState.t("ui.mixer.outputs"), subtitle: appState.t("ui.mixer.outputs_sub"))
                outputs
            }
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(index: "03", title: appState.t("ui.mixer.input"), subtitle: appState.t("ui.mixer.input_sub"))
                input
            }
        }
    }

    private var kpis: some View {
        let dev = appState.activeOutputDevice
        let boosts = appState.sources.filter { $0.volume > 1.0001 }.count
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
            KPITile(label: appState.t("ui.kpi.playing"), value: "\(appState.playingCount)", unit: appState.t("ui.kpi.sources_unit"),
                    footnote: boosts > 0 ? String(format: appState.t("ui.kpi.boost_n"), boosts) : String(format: appState.t("ui.kpi.listed_n"), appState.mixerSources.count))
            KPITile(label: appState.t("ui.kpi.output"), value: dev?.name ?? "—",
                    footnote: dev.map { "\($0.rateLabel) · \($0.transportLabel(appState.t))" }, origin: .reported)
            KPITile(label: appState.t("ui.kpi.path"),
                    value: appState.pathIsNative ? appState.t("ui.path.native_short") : appState.t("ui.path.processing_short"),
                    footnote: String(format: appState.t("ui.kpi.taps_n"), appState.activeTapsCount),
                    tone: appState.pathIsNative ? c.semantic_positive : c.accent_signal)
            KPITile(label: appState.t("eq.preamp"), value: Fmt.db(appState.telemetry.preampDB), unit: "dB",
                    footnote: String(format: appState.t("ui.kpi.ceiling"), Fmt.db(appState.activePreset.limiterCeilingDBTP)), origin: .measured)
        }
    }

    @ViewBuilder private var sources: some View {
        ListCard {
            columnHeader([appState.t("ui.col.app"), appState.t("ui.col.volume"), ""])
            if appState.mixerSources.isEmpty {
                EmptyStateView(title: appState.t("notch.empty_playing"), detail: appState.t("ui.mixer.empty_detail"))
            }
            ForEach(Array(appState.mixerSources.enumerated()), id: \.element.id) { i, src in
                if i > 0 { Hairline().padding(.leading, 64) }
                SourceRow(appState: appState, src: src)
                ForEach(tabs(for: src), id: \.tabID) { tab in
                    Hairline().padding(.leading, 64)
                    TabRow(appState: appState, tab: tab)
                }
            }
        }
        if appState.tabUpdates.isEmpty {
            Text(appState.t("mixer.tabs_note"))
                .type(TimbreTypography.caption)
                .foregroundStyle(c.ink_muted)
                .padding(.leading, 4)
        }
    }

    private func tabs(for src: AudioSourceDescriptor) -> [TabAudioUpdate] {
        let n = src.name.lowercased()
        return appState.tabUpdates.filter { n.contains($0.browser.lowercased()) || $0.browser.lowercased().contains(n) }
    }

    private func columnHeader(_ cols: [String]) -> some View {
        HStack(spacing: 0) {
            Eyebrow(text: cols[0]).frame(width: 248, alignment: .leading)
            Eyebrow(text: cols[1])
            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(height: 34)
        .overlay(alignment: .bottom) { Hairline() }
    }

    private var outputs: some View {
        ListCard {
            ForEach(Array(appState.outputDevices.enumerated()), id: \.element.id) { i, dev in
                if i > 0 { Hairline().padding(.leading, 64) }
                OutputRow(appState: appState, dev: dev)
            }
        }
    }

    private var input: some View {
        ListCard {
            HStack(spacing: 14) {
                if let d = appState.activeInputDevice { DeviceGlyph(device: d, size: 30, active: true) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.activeInputDevice?.name ?? "—").type(TimbreTypography.bodyStrong).foregroundStyle(c.ink_primary)
                    Text(appState.activeInputDevice.map { "\($0.rateLabel) · \($0.transportLabel(appState.t))" } ?? "")
                        .type(TimbreTypography.monoSmall).foregroundStyle(c.ink_muted)
                }
                Spacer()
                MenuChip(title: appState.t("ui.mixer.change_input")) {
                    ForEach(appState.inputDevices) { dev in
                        Button(dev.name) { appState.selectDefaultInput(dev) }
                    }
                }
            }
            .padding(.horizontal, 20).frame(height: 62)
            Hairline().padding(.leading, 64)
            settingRow(appState.t("ui.mixer.mic_mute"), appState.t("ui.mixer.mic_mute_sub"),
                       isOn: Binding(get: { appState.globalMicMuted }, set: { _ in appState.toggleGlobalMicMute() }))
            Hairline().padding(.leading, 64)
            settingRow(appState.t("mixer.auto_duck"), appState.t("ui.mixer.duck_sub"),
                       isOn: Binding(get: { appState.autoDuckOnCall }, set: { appState.toggleAutoDuck($0) }))
        }
    }

    private func settingRow(_ title: String, _ sub: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            Color.clear.frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).type(TimbreTypography.body).foregroundStyle(c.ink_primary)
                Text(sub).type(TimbreTypography.caption).foregroundStyle(c.ink_muted)
            }
            Spacer()
            TSwitch(isOn: isOn, label: title)
        }
        .padding(.horizontal, 20).frame(height: 54)
    }
}

private struct SourceRow: View {
    @ObservedObject var appState: AppState
    let src: AudioSourceDescriptor
    @Environment(\.palette) private var c

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 14) {
                AppIcon(bundleID: src.bundleID, name: src.name, size: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text(src.name).type(TimbreTypography.bodyStrong).foregroundStyle(c.ink_primary).lineLimit(1)
                    HStack(spacing: 6) {
                        if src.isPlaying { Circle().fill(c.semantic_positive).frame(width: 5, height: 5) }
                        Text(status).type(TimbreTypography.micro).foregroundStyle(c.ink_muted)
                    }
                }
            }
            .frame(width: 248, alignment: .leading)

            if src.isVoIPExcluded {
                Text(appState.t("ui.mixer.voip_detail")).type(TimbreTypography.caption).foregroundStyle(c.ink_muted)
                Spacer()
            } else {
                let liveNorm: Double? = (src.isPlaying && !src.isMuted && !appState.outputSilenced)
                    ? (appState.hasLiveSignal
                       ? AudioDecibelMath.dbToNormalized(max(appState.meterBallisticsL.smoothedDB, appState.meterBallisticsR.smoothedDB) + (src.volume > 0.0001 ? 20 * log10(src.volume) : -60), minDB: -60, maxDB: 6)
                       : min(1.0, src.volume * 0.52))
                    : nil
                TFader(value: Binding(get: { src.isMuted ? 0 : src.volume }, set: { appState.setSourceVolume(bundleID: src.bundleID, volume: $0) }),
                       range: 0...2, unity: 1, tint: c.ink_primary, label: src.name, valueText: Fmt.percent(src.volume), unityPosition: 0.75,
                       liveMeterNorm: liveNorm, scaleMarks: [0.25, 0.5, 0.75, 1.5])
                    .frame(maxWidth: 420)
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(src.isMuted ? "—" : Fmt.percent(src.volume)).type(TimbreTypography.monoValue)
                    Text("%").type(TimbreTypography.monoSmall).foregroundStyle(c.ink_muted)
                }
                .foregroundStyle(src.volume > 1.0001 && !src.isMuted ? c.semantic_warning : c.ink_primary)
                .frame(width: 58, alignment: .trailing)
                Text(src.isMuted ? "" : Fmt.volumeDB(src.volume) + " dB")
                    .type(TimbreTypography.monoSmall).foregroundStyle(c.ink_muted)
                    .frame(width: 64, alignment: .trailing)
                Spacer(minLength: 12)
                TChannelButton(text: "M", symbol: src.isMuted ? "speaker.slash.fill" : nil, pressed: src.isMuted, tone: .mute, size: 24, help: appState.t("ui.mute")) {
                    appState.toggleSourceMute(bundleID: src.bundleID)
                }
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 62)
        .contentShape(Rectangle())
    }

    private var status: String {
        if src.isVoIPExcluded { return appState.t("ui.status.call") }
        if src.isMuted { return appState.t("ui.status.muted") }
        if src.volume > 1.0001, appState.sourceLimiterDB[src.bundleID] != nil { return appState.t("ui.status.limited") }
        if src.volume > 1.0001 { return appState.t("ui.status.boost") }
        if src.isPlaying { return appState.t("ui.notch.playing") }
        // Not playing ≠ paused (an alert that just sounded was never "paused"): say when it last played.
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: appState.language == .ptBR ? "pt_BR" : appState.language == .es ? "es" : "en")
        f.unitsStyle = .full
        let ago = Date().timeIntervalSince(src.lastActiveAt) < 60 ? appState.t("ui.status.just_now") : f.localizedString(for: src.lastActiveAt, relativeTo: Date())
        return String(format: appState.t("ui.status.played"), ago)
    }
}

private struct TabRow: View {
    @ObservedObject var appState: AppState
    let tab: TabAudioUpdate
    @Environment(\.palette) private var c

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 10) {
                Color.clear.frame(width: 30)
                Image(systemName: "globe").font(.system(size: 11)).foregroundStyle(c.ink_muted)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tab.title).type(TimbreTypography.small).foregroundStyle(c.ink_primary).lineLimit(1)
                    Text(tab.origin).type(TimbreTypography.monoSmall).foregroundStyle(c.ink_muted).lineLimit(1)
                }
            }
            .frame(width: 248, alignment: .leading)
            TFader(value: Binding(get: { tab.isMuted ? 0 : tab.volume }, set: { appState.setTabVolume(browser: tab.browser, tabID: tab.tabID, volume: $0) }),
                   range: 0...1, unity: 1, tint: c.ink_secondary, height: 18, trackHeight: 2, label: tab.title, valueText: Fmt.percent(tab.volume))
                .frame(maxWidth: 420)
            Text(tab.isMuted ? "—" : Fmt.percent(tab.volume) + "%").type(TimbreTypography.monoSmall).foregroundStyle(c.ink_secondary).frame(width: 58, alignment: .trailing)
            Spacer(minLength: 12)
            TChannelButton(text: "M", pressed: tab.isMuted, tone: .mute, size: 22, help: appState.t("ui.mute")) {
                appState.toggleTabMute(browser: tab.browser, tabID: tab.tabID)
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 48)
        .background(c.bg_inset)
    }
}

private struct OutputRow: View {
    @ObservedObject var appState: AppState
    let dev: AudioDeviceDescriptor
    @Environment(\.palette) private var c

    var body: some View {
        let isDefault = dev.isDefaultOutput
        let mirrored = appState.mirrorOutputUIDs.contains(dev.uid)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                DeviceGlyph(device: dev, size: 30, active: isDefault)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(dev.name).type(TimbreTypography.bodyStrong).foregroundStyle(c.ink_primary).lineLimit(1)
                        if isDefault { Badge(text: appState.t("ui.output.default"), tone: .neutral, dot: false) }
                        if mirrored { Badge(text: appState.t("ui.output.mirror"), tone: .accent, dot: false) }
                    }
                    Text(spec).type(TimbreTypography.monoSmall).foregroundStyle(c.ink_muted)
                }
                .frame(minWidth: 220, alignment: .leading)
                Spacer(minLength: 12)

                if dev.isHWVolumeMasterSettable || dev.isHWVolumeChannelSettable {
                    let isMuted = isDefault
                        ? appState.outputSilenced
                        : (appState.halManager.readOutputMute(deviceID: dev.audioObjectID) ?? false)
                    let rawVol = isDefault
                        ? (appState.activeOutputVolume ?? Double(appState.halManager.readOutputVolumeScalar(deviceID: dev.audioObjectID) ?? 0.5))
                        : Double(appState.halManager.readOutputVolumeScalar(deviceID: dev.audioObjectID) ?? 0.5)
                    let vol = isMuted ? 0 : rawVol
                    TFader(value: Binding(get: { vol }, set: { appState.setOutputVolume(dev, value: $0) }), range: 0...1, tint: c.ink_primary, label: dev.name, valueText: isMuted ? appState.t("ui.notch.muted") : Fmt.percent(rawVol))
                        .frame(width: 170)
                    Text(isMuted ? "—" : Fmt.percent(rawVol) + "%")
                        .type(TimbreTypography.monoValue)
                        .foregroundStyle(isMuted ? c.semantic_warning : c.ink_secondary)
                        .frame(width: 46, alignment: .trailing)
                } else {
                    Badge(text: appState.t("dev.sw_volume"), tone: .warning)
                        .help(appState.t("ui.output.sw_help"))
                }

                if isDefault {
                    HStack {
                        Spacer(minLength: 0)
                        if dev.isHWMuteSettable {
                            TChannelButton(
                                text: "M",
                                symbol: appState.outputSilenced ? "speaker.slash.fill" : nil,
                                pressed: appState.outputSilenced,
                                tone: .mute,
                                size: 24,
                                help: appState.t("ui.mute")
                            ) {
                                appState.toggleOutputMute()
                            }
                        }
                    }
                    .frame(width: 96)
                } else {
                    Button(appState.t("ui.output.make_default")) { appState.selectDefaultOutput(dev) }
                        .buttonStyle(.t(.ghost, compact: true))
                        .frame(width: 96, alignment: .trailing)
                }
            }
            .frame(height: 62)

            if !isDefault || dev.name.localizedCaseInsensitiveContains("MOMENTUM 4") || hasAppleStrip {
                HStack(spacing: 16) {
                    Color.clear.frame(width: 30)
                    if !isDefault {
                        HStack(spacing: 8) {
                            TSwitch(isOn: Binding(get: { mirrored }, set: { _ in appState.toggleMirrorOutput(dev) }), label: appState.t("ui.output.mirror_label"))
                            Text(appState.t("ui.output.mirror_label")).type(TimbreTypography.caption).foregroundStyle(c.ink_secondary)
                        }
                        if mirrored {
                            HStack(spacing: 6) {
                                Text(appState.t("ui.output.delay")).type(TimbreTypography.caption).foregroundStyle(c.ink_muted)
                                ScrubValue(value: Binding(get: { appState.outputDelaysMs[dev.uid] ?? 0 }, set: { appState.setOutputDelay(dev, delayMs: $0) }),
                                           range: 0...250, step: 1, format: { String(format: "%.0f ms", $0) }, width: 52)
                            }
                        }
                    }
                    if dev.name.localizedCaseInsensitiveContains("MOMENTUM 4") {
                        let imp = dev.analogImpedanceMode ?? .active470Ohm
                        TSegmented(options: [(AnalogImpedanceMode.active470Ohm, appState.t("dev.m4.p2_active")), (.passive60Ohm, appState.t("dev.m4.p2_passive"))],
                                   selection: Binding(get: { imp }, set: { if $0 != imp { appState.toggleMomentum4Impedance() } }))
                    }
                    if hasAppleStrip, let telem = appState.driverTelemetry {
                        AppleAccessoryBatteryStrip(telemetry: telem, t: appState.t, colors: c, compact: true)
                    }
                    Spacer()
                }
                .padding(.bottom, 14)
            }
        }
        .padding(.horizontal, 20)
    }

    private var hasAppleStrip: Bool {
        (dev.isDefaultOutput || appState.activeOutputDevice?.uid == dev.uid)
            && AirPodsProAdapter.classify(deviceName: dev.name) != .unknown
            && appState.driverTelemetry?.accessoryFamily != nil
    }

    private var spec: String {
        var parts = [dev.rateLabel, dev.transportLabel(appState.t)]
        if dev.totalReportedLatencyMs > 0 { parts.append(String(format: "%.1f ms", dev.totalReportedLatencyMs)) }
        if dev.outputChannels > 2 { parts.append("\(dev.outputChannels) ch") }
        return parts.joined(separator: " · ")
    }
}

// MARK: - 02 Equalizer

private struct EqualizerPage: View {
    @ObservedObject var appState: AppState
    @Environment(\.palette) private var c

    var body: some View {
        VStack(alignment: .leading, spacing: 36) {
            PageHeader(index: "02 — " + appState.t("nav.eq"), title: appState.t("ui.eq.title"), summary: eqSummary) {
                TSegmented(options: [(false, appState.t("eq.mode.simple")), (true, appState.t("eq.mode.advanced"))],
                           selection: Binding(get: { appState.activePreset.useAdvancedPEQ }, set: { appState.toggleAdvancedPEQ($0) }))
                Menu {
                    Button(appState.t("eq.import_apo")) { appState.importEqualizerAPOFromPanel() }
                    Button(appState.t("eq.export_apo")) { appState.exportEqualizerAPOToPanel() }
                } label: {
                    Text(appState.t("ui.eq.file"))
                }
                .menuStyle(.button)
                .menuIndicator(.hidden)
                .fixedSize()
                .buttonStyle(.t(.secondary))
                Button(appState.t("ui.eq.save")) { appState.saveCurrentPreset() }
                    .buttonStyle(.t(.primary))
            }
            .padding(.bottom, -28)

            // Curve
            VStack(spacing: 0) {
                HStack(spacing: 18) {
                    legend(appState.t("eq.layer.correction"), dashed: true, color: c.ink_secondary)
                    legend(appState.t("eq.layer.taste"), dashed: false, color: c.ink_muted)
                    legend(appState.t("eq.layer.result"), dashed: false, color: c.accent_signal, thick: true)
                    Spacer()
                    if let meta = appState.activePreset.correctionMetadata {
                        Text("\(meta.headphoneModel) · \(meta.sourceCredit)").type(TimbreTypography.monoSmall).foregroundStyle(c.ink_muted).lineLimit(1)
                    }
                }
                .padding(.horizontal, 20)
                .frame(height: 44)
                EQCurveCanvas(appState: appState, height: 290)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 14)
                Hairline()
                metrology
            }
            .background(RoundedRectangle(cornerRadius: TimbreRadius.card, style: .continuous).fill(c.bg_surface))
            .overlay(RoundedRectangle(cornerRadius: TimbreRadius.card, style: .continuous).strokeBorder(c.line_default, lineWidth: 1))

            if appState.activePreset.useAdvancedPEQ { advancedBands } else { simpleControls }

            HStack(alignment: .top, spacing: 14) {
                correctionPanel
                comparePanel
                assistantPanel
            }
        }
    }

    private var eqSummary: String {
        let n = appState.activePreset.allEffectiveBands.filter { $0.enabled && abs($0.gainDB) > 0.01 }.count
        if appState.isProcessingBypassed { return appState.t("ui.eq.summary_bypassed") }
        return String(format: appState.t("ui.eq.summary"), n, Fmt.db(appState.telemetry.preampDB))
    }

    private func legend(_ title: String, dashed: Bool, color: Color, thick: Bool = false) -> some View {
        HStack(spacing: 7) {
            Canvas { ctx, size in
                var p = Path(); p.move(to: CGPoint(x: 0, y: size.height / 2)); p.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: thick ? 2 : 1, dash: dashed ? [3, 2.5] : []))
            }
            .frame(width: 16, height: 6)
            Text(title).type(TimbreTypography.caption).foregroundStyle(c.ink_secondary)
        }
    }

    private var metrology: some View {
        let t = appState.telemetry
        let live = appState.hasLiveSignal
        let peakDB = live ? max(appState.meterBallisticsL.smoothedDB, appState.meterBallisticsR.smoothedDB) : -60.0
        let holdDB = live ? max(appState.meterBallisticsL.heldPeakDB, appState.meterBallisticsR.heldPeakDB) : nil
        let clipped = appState.meterBallisticsL.isClipLatched || appState.meterBallisticsR.isClipLatched || t.limiterActive
        return HStack(spacing: 0) {
            stat(appState.t("eq.preamp"), Fmt.db(t.preampDB) + " dB")
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Eyebrow(text: appState.t("ui.eq.true_peak"))
                    Text((live && max(t.truePeakL, t.truePeakR) > -70) ? Fmt.signed(max(t.truePeakL, t.truePeakR)) + " dBTP" : "—")
                        .type(TimbreTypography.monoValue)
                        .foregroundStyle(c.ink_primary)
                }
                TLevelMeter(
                    peakDB: peakDB,
                    rmsDB: live ? t.lufsMomentary : nil,
                    heldPeakDB: holdDB,
                    height: 5
                )
                .frame(width: 124)
            }
            .frame(width: 156, alignment: .leading)
            stat(appState.t("ui.eq.limiter"), !live ? "—" : (t.limiterActive ? Fmt.db(-abs(t.limiterGR)) + " dB" : appState.t("ui.eq.idle")))
            stat(appState.t("ui.eq.latency"), String(format: "%.1f ms", appState.activeOutputDevice?.totalReportedLatencyMs ?? 0))
            TClipIndicator(
                clipping: clipped,
                count: Int(t.clipPreventedCount) + max(appState.meterBallisticsL.clipEventCount, appState.meterBallisticsR.clipEventCount),
                label: "CLIP"
            ) {
                appState.resetClipLatch()
            }
            Spacer()
            HStack(spacing: 8) {
                Text(appState.t("eq.crossfeed")).type(TimbreTypography.caption).foregroundStyle(c.ink_secondary)
                TSwitch(isOn: Binding(get: { appState.activePreset.crossfeedEnabled }, set: { appState.activePreset.crossfeedEnabled = $0; appState.syncDSPAndTap() }), label: appState.t("eq.crossfeed"))
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 54)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Eyebrow(text: label)
            Text(value).type(TimbreTypography.monoValue).foregroundStyle(c.ink_primary)
        }
        .frame(width: 138, alignment: .leading)
    }

    // Simple — four semantic tone controls (spec §6.3)
    private var simpleControls: some View {
        let st = appState.activePreset.simpleTaste
        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(index: "01", title: appState.t("ui.eq.taste_title"), subtitle: appState.t("ui.eq.taste_sub")) {
                Button(appState.t("ui.eq.flatten")) { appState.updateSimpleTaste(.neutral) }
                    .buttonStyle(.t(.ghost, compact: true))
                    .disabled(st == .neutral)
            }
            HStack(spacing: 12) {
                tone(appState.t("eq.taste.bass"), "105 Hz · shelf", st.bassDB) { var s = st; s.bassDB = $0; appState.updateSimpleTaste(s) }
                tone(appState.t("eq.taste.warmth"), "250 Hz · peak", st.warmthDB) { var s = st; s.warmthDB = $0; appState.updateSimpleTaste(s) }
                tone(appState.t("eq.taste.presence"), "3 kHz · peak", st.presenceDB) { var s = st; s.presenceDB = $0; appState.updateSimpleTaste(s) }
                tone(appState.t("eq.taste.air"), "10 kHz · shelf", st.airDB) { var s = st; s.airDB = $0; appState.updateSimpleTaste(s) }
            }
        }
    }

    private func tone(_ name: String, _ spec: String, _ value: Double, set: @escaping (Double) -> Void) -> some View {
        let binding = Binding(get: { value }, set: { set(SimpleTasteControls.clampStep($0)) })
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Eyebrow(text: name)
                Spacer()
                Text(spec).type(TimbreTypography.monoSmall).foregroundStyle(c.ink_faint)
            }
            HStack(alignment: .center, spacing: 12) {
                TKnob(
                    value: binding,
                    range: -6...6,
                    step: 0.5,
                    origin: 0,
                    resetValue: 0,
                    size: 46,
                    tickCount: 13,
                    label: name,
                    valueText: Fmt.db(value) + " dB"
                )
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(Fmt.db(value)).type(TimbreTypography.mediumValue).foregroundStyle(abs(value) < 0.01 ? c.ink_muted : c.ink_primary)
                            .contentTransition(.numericText(value: value))
                        Text("dB").type(TimbreTypography.monoSmall).foregroundStyle(c.ink_muted)
                    }
                    Text(abs(value) < 0.01 ? "0.0 · flat" : (value > 0 ? "boost" : "cut"))
                        .type(TimbreTypography.micro)
                        .foregroundStyle(c.ink_muted)
                }
                Spacer(minLength: 0)
            }
            TFader(value: binding, range: -6...6, bipolar: true, resetValue: 0,
                   tint: c.accent_signal, label: name, valueText: Fmt.db(value) + " dB",
                   scaleMarks: [-6, -3, 0, 3, 6])
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: TimbreRadius.card, style: .continuous).fill(c.bg_surface))
        .overlay(RoundedRectangle(cornerRadius: TimbreRadius.card, style: .continuous).strokeBorder(c.line_default, lineWidth: 1))
    }

    // Advanced — Pro-Q style band table with scrubbable values
    private var advancedBands: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(index: "01", title: appState.t("ui.eq.bands_title"), subtitle: appState.t("ui.eq.bands_sub")) {
                Button {
                    appState.addTasteBand()
                } label: {
                    Label(appState.t("ui.eq.add_band"), systemImage: "plus")
                }
                .buttonStyle(.t(.secondary, compact: true))
                .disabled(appState.activePreset.tasteBands.count >= 20)
            }
            ListCard {
                HStack(spacing: 0) {
                    Eyebrow(text: "#").frame(width: 34, alignment: .leading)
                    Eyebrow(text: appState.t("ui.eq.col.on")).frame(width: 52, alignment: .leading)
                    Eyebrow(text: appState.t("ui.eq.col.type")).frame(width: 128, alignment: .leading)
                    Eyebrow(text: appState.t("ui.eq.col.freq")).frame(width: 104, alignment: .trailing)
                    Eyebrow(text: appState.t("ui.eq.col.gain")).frame(width: 104, alignment: .trailing)
                    Eyebrow(text: "Q").frame(width: 92, alignment: .trailing)
                    Spacer()
                }
                .padding(.horizontal, 20).frame(height: 34)
                .overlay(alignment: .bottom) { Hairline() }
                if appState.activePreset.tasteBands.isEmpty {
                    EmptyStateView(title: appState.t("ui.eq.no_bands"), detail: appState.t("ui.eq.no_bands_detail"))
                }
                ForEach(Array(appState.activePreset.tasteBands.enumerated()), id: \.element.id) { i, band in
                    if i > 0 { Hairline().padding(.leading, 20) }
                    bandRow(i, band)
                }
            }
        }
    }

    private func bandRow(_ i: Int, _ band: EQBand) -> some View {
        func upd(_ f: (inout EQBand) -> Void) { var b = band; f(&b); appState.updateTasteBand(b) }
        let types: [(EQFilterType, String)] = [(.peak, appState.t("ui.filter.peak")), (.lowShelf, appState.t("ui.filter.lowshelf")), (.highShelf, appState.t("ui.filter.highshelf")),
                                              (.lowPass, appState.t("ui.filter.lowpass")), (.highPass, appState.t("ui.filter.highpass")), (.notch, appState.t("ui.filter.notch"))]
        return HStack(spacing: 0) {
            Text("\(i + 1)").type(TimbreTypography.monoValue).foregroundStyle(band.enabled ? c.accent_signal : c.ink_muted).frame(width: 34, alignment: .leading)
            TSwitch(isOn: Binding(get: { band.enabled }, set: { v in upd { $0.enabled = v } }), label: "Band \(i + 1)").frame(width: 52, alignment: .leading)
            MenuChip(title: types.first(where: { $0.0 == band.type })?.1 ?? band.type.rawValue) {
                ForEach(types, id: \.0) { t in Button(t.1) { upd { $0.type = t.0 } } }
            }
            .frame(width: 128, alignment: .leading)
            ScrubValue(value: Binding(get: { band.freqHz }, set: { v in upd { $0.freqHz = v } }), range: 20...20000, step: 1, logarithmic: true,
                       format: { "\(Fmt.hz($0)) Hz" }, width: 84).frame(width: 104, alignment: .trailing)
            ScrubValue(value: Binding(get: { band.gainDB }, set: { v in upd { $0.gainDB = v } }), range: -15...15, step: 0.1,
                       format: { "\(Fmt.db($0)) dB" }, width: 84).frame(width: 104, alignment: .trailing)
            ScrubValue(value: Binding(get: { band.q }, set: { v in upd { $0.q = v } }), range: 0.1...10, step: 0.01,
                       format: { String(format: "%.2f", $0) }, width: 64).frame(width: 92, alignment: .trailing)
            Spacer()
            IconButton(symbol: "minus.circle", size: 24, help: appState.t("ui.eq.remove_band")) { appState.removeTasteBand(id: band.id) }
        }
        .padding(.horizontal, 20)
        .frame(height: 46)
        .opacity(band.enabled ? 1 : 0.55)
    }

    // Lower tools — three columns
    private func panel<Content: View>(_ index: String, _ title: String, _ sub: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow(text: index)
                Text(title).type(TimbreTypography.cardTitle).foregroundStyle(c.ink_primary)
                Text(sub).type(TimbreTypography.caption).foregroundStyle(c.ink_muted).fixedSize(horizontal: false, vertical: true)
            }
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 250, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: TimbreRadius.card, style: .continuous).fill(c.bg_surface))
        .overlay(RoundedRectangle(cornerRadius: TimbreRadius.card, style: .continuous).strokeBorder(c.line_default, lineWidth: 1))
    }

    private static var cachedMatchKey: String = ""
    private static var cachedMatches: [AutoEqEntry] = []

    private var correctionPanel: some View {
        let devName = appState.activeOutputDevice?.name ?? ""
        let matches: [AutoEqEntry] = {
            if Self.cachedMatchKey == devName { return Self.cachedMatches }
            let m = AutoEqService.matchDeviceName(devName)
            Self.cachedMatchKey = devName
            Self.cachedMatches = m
            return m
        }()
        return panel("02", appState.t("ui.eq.correction_title"), appState.t("ui.eq.correction_sub")) {
            if let meta = appState.activePreset.correctionMetadata {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(meta.headphoneModel).type(TimbreTypography.bodyStrong).foregroundStyle(c.ink_primary)
                        Text("\(meta.sourceCredit) · \(meta.measurementRig) · \(meta.targetCurve)").type(TimbreTypography.monoSmall).foregroundStyle(c.ink_muted)
                    }
                    Spacer()
                    Button(appState.t("ui.eq.remove")) { appState.clearCorrection() }.buttonStyle(.t(.ghost, compact: true))
                }
                Hairline()
            }
            if appState.driverTelemetry?.spatialAudioMayAlterFR == true {
                Text(appState.t("dev.apple.spatial_warn")).type(TimbreTypography.caption).foregroundStyle(c.semantic_warning).fixedSize(horizontal: false, vertical: true)
            }
            if matches.isEmpty {
                Text(appState.t("ui.eq.no_match")).type(TimbreTypography.caption).foregroundStyle(c.ink_muted)
            }
            ForEach(matches.prefix(3)) { entry in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.headphoneName).type(TimbreTypography.small).foregroundStyle(c.ink_primary).lineLimit(1)
                        Text("\(entry.source) · \(entry.rig)").type(TimbreTypography.monoSmall).foregroundStyle(c.ink_muted).lineLimit(1)
                    }
                    Spacer()
                    Button(appState.t("ui.apply")) { appState.applyAutoEqEntry(entry) }.buttonStyle(.t(.secondary, compact: true))
                }
            }
        }
    }

    private var comparePanel: some View {
        panel("03", appState.t("ui.eq.compare_title"), appState.t("ui.eq.compare_sub")) {
            if !appState.blindABActive {
                Button(appState.t("ui.eq.start_blind")) { appState.startBlindAB() }.buttonStyle(.t(.primary, compact: true))
            } else {
                HStack(spacing: 6) {
                    sampleButton("X", selected: appState.blindCurrentIsX) { appState.selectBlindSample(isX: true) }
                    sampleButton("Y", selected: !appState.blindCurrentIsX) { appState.selectBlindSample(isX: false) }
                    Spacer()
                    if !appState.blindRevealed {
                        Button(appState.t("ui.eq.reveal")) { appState.revealBlindAB() }.buttonStyle(.t(.secondary, compact: true))
                    }
                    IconButton(symbol: "xmark", size: 24, help: appState.t("ui.eq.stop")) { appState.stopBlindAB() }
                }
                if appState.blindRevealed {
                    Text(String(format: appState.t("ui.eq.reveal_result"), appState.blindXIsFull ? appState.t("ui.eq.with_eq") : appState.t("ui.eq.without_eq")))
                        .type(TimbreTypography.caption).foregroundStyle(c.ink_secondary)
                }
            }
            Hairline()
            Text(appState.t("eq.trainer_title")).type(TimbreTypography.small).fontWeight(.medium).foregroundStyle(c.ink_primary)
            HStack(spacing: 6) {
                Button("A") { appState.auditionTrainerCandidate(isB: false) }.buttonStyle(.t(appState.trainerListeningB ? .secondary : .primary, compact: true))
                Button("B") { appState.auditionTrainerCandidate(isB: true) }.buttonStyle(.t(appState.trainerListeningB ? .primary : .secondary, compact: true))
                Spacer()
                Button(appState.t("ui.eq.prefer_a")) { appState.voteTrainerWinner(isA: true) }.buttonStyle(.t(.ghost, compact: true))
                Button(appState.t("ui.eq.prefer_b")) { appState.voteTrainerWinner(isA: false) }.buttonStyle(.t(.ghost, compact: true))
            }
            HStack(spacing: 4) {
                ForEach(0..<15, id: \.self) { i in
                    Capsule().fill(i < appState.trainerHistory.count ? c.accent_signal : c.bg_track).frame(height: 3)
                }
            }
            Text(String(format: appState.t("ui.eq.rounds"), appState.trainerHistory.count)).type(TimbreTypography.monoSmall).foregroundStyle(c.ink_muted)
        }
    }

    private func sampleButton(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(.system(size: 13, weight: .semibold, design: .monospaced))
                .frame(width: 34, height: 28)
                .foregroundStyle(selected ? c.ink_inverse : c.ink_primary)
                .background(RoundedRectangle(cornerRadius: TimbreRadius.control, style: .continuous).fill(selected ? c.ink_primary : c.bg_selected))
        }
        .buttonStyle(PressScaleStyle())
    }

    private var assistantPanel: some View {
        panel("04", appState.t("ui.eq.assistant_title"), appState.t("ui.eq.assistant_sub")) {
            TField(placeholder: appState.t("eq.ai_placeholder"), text: $appState.aiPromptText) { appState.submitAIPrompt() }
            HStack {
                Button(appState.t("eq.ai_apply")) { appState.submitAIPrompt() }
                    .buttonStyle(.t(.primary, compact: true))
                    .disabled(appState.aiPromptText.trimmingCharacters(in: .whitespaces).isEmpty)
                if !appState.undoTasteStack.isEmpty {
                    Button(appState.t("ui.undo")) { appState.undoLastAITweak() }.buttonStyle(.t(.ghost, compact: true))
                }
                Spacer()
            }
            if !appState.aiStatusMessage.isEmpty {
                Text(appState.aiStatusMessage).type(TimbreTypography.caption).foregroundStyle(c.ink_muted).fixedSize(horizontal: false, vertical: true)
            }
            ForEach(appState.aiProposals) { prop in
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(prop.label).type(TimbreTypography.small).fontWeight(.medium).foregroundStyle(c.ink_primary)
                        Text(prop.rationale).type(TimbreTypography.caption).foregroundStyle(c.ink_muted).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Button(appState.t("ui.apply")) { appState.applyAIProposal(prop) }.buttonStyle(.t(.secondary, compact: true))
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: TimbreRadius.control, style: .continuous).fill(c.bg_inset))
            }
        }
    }
}

// MARK: - 03 Observatory

private struct ObservatoryPage: View {
    @ObservedObject var appState: AppState
    @Environment(\.palette) private var c

    var body: some View {
        VStack(alignment: .leading, spacing: 36) {
            PageHeader(index: "03 — " + appState.t("nav.observatory"), title: appState.t("ui.obs.title"), summary: obsSummary) {
                HStack(spacing: 8) {
                    Text(appState.t("guard.silent_studio")).type(TimbreTypography.caption).foregroundStyle(c.ink_secondary)
                    TSwitch(isOn: Binding(get: { appState.silentStudioMode }, set: { appState.toggleSilentStudio($0) }), label: appState.t("guard.silent_studio"))
                }
            }
            .padding(.bottom, -28)

            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(index: "01", title: appState.t("ui.obs.path_title"), subtitle: appState.t("ui.obs.path_sub")) {
                    HStack(spacing: 14) {
                        OriginMark(origin: .measured, showLabel: true, label: appState.t("obs.badge.measured"))
                        OriginMark(origin: .reported, showLabel: true, label: appState.t("obs.badge.reported"))
                        OriginMark(origin: .inferred, showLabel: true, label: appState.t("obs.badge.inferred"))
                    }
                }
                signalPath
            }

            let t = appState.telemetry
            let live = appState.hasLiveSignal
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                KPITile(label: "LUFS · M", value: live && t.lufsMomentary > -70 ? Fmt.signed(t.lufsMomentary) : "—", footnote: appState.t("ui.obs.lufs_note"), origin: .measured)
                let hasPeak = live && max(t.truePeakL, t.truePeakR) > -70
                KPITile(label: appState.t("ui.eq.true_peak"), value: hasPeak ? Fmt.signed(max(t.truePeakL, t.truePeakR)) : "—", unit: hasPeak ? "dBTP" : nil,
                        footnote: hasPeak ? "L \(Fmt.signed(t.truePeakL)) · R \(Fmt.signed(t.truePeakR))" : appState.t("ui.obs.no_signal"), origin: .measured)
                KPITile(label: appState.t("ui.eq.limiter"), value: live ? (t.limiterActive ? Fmt.db(-abs(t.limiterGR)) : "0.0") : "—", unit: live ? "dB" : nil, footnote: appState.t("ui.obs.gr_note"), origin: .measured)
                KPITile(label: appState.t("ui.obs.clips"), value: "\(t.clipPreventedCount)", footnote: appState.t("ui.obs.clips_note"), origin: .measured)
                KPITile(label: "DSP", value: live ? String(format: "%.0f", t.cpuMicroseconds) : "—", unit: live ? "µs" : nil, footnote: appState.t("ui.obs.cpu_note"), origin: .measured)
            }

            TLCDDisplay(
                title: "TRUE PEAK & LUFS RECORDER MONITOR",
                statusText: live ? "LIVE · 4× OVERSAMPLED" : (appState.pathIsNative ? "BIT-PERFECT · 0 TAPS" : "IDLE"),
                isLive: live
            ) {
                VStack(spacing: 8) {
                    TLCDMeterRow(
                        channelLabel: "L",
                        dbfs: live ? appState.meterBallisticsL.smoothedDB : -90,
                        heldPeakDB: live ? appState.meterBallisticsL.heldPeakDB : nil,
                        segmentCount: 32,
                        unit: "dBTP"
                    )
                    TLCDMeterRow(
                        channelLabel: "R",
                        dbfs: live ? appState.meterBallisticsR.smoothedDB : -90,
                        heldPeakDB: live ? appState.meterBallisticsR.heldPeakDB : nil,
                        segmentCount: 32,
                        unit: "dBTP"
                    )
                    HStack(spacing: 8) {
                        Color.clear.frame(width: 24, height: 1)
                        TdBScale(minDB: -60, maxDB: 0, ticks: [-48, -36, -24, -18, -12, -6, -3, 0], audioTaper: true, showLabels: true)
                        TClipIndicator(
                            clipping: appState.meterBallisticsL.isClipLatched || appState.meterBallisticsR.isClipLatched || t.limiterActive,
                            count: Int(t.clipPreventedCount) + max(appState.meterBallisticsL.clipEventCount, appState.meterBallisticsR.clipEventCount),
                            label: "CLIP"
                        ) {
                            appState.resetClipLatch()
                        }
                        .frame(width: 68, alignment: .trailing)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(index: "02", title: appState.t("ui.obs.spectrum_title"), subtitle: appState.t("ui.obs.spectrum_sub"))
                SpectrumView(bins: appState.hasLiveSignal ? t.spectrumBinsDB : [], sampleRate: appState.activeOutputDevice?.sampleRate ?? 48000, emptyText: appState.t("ui.obs.spectrum_empty"))
                    .frame(height: 160)
                    .padding(18)
                    .background(RoundedRectangle(cornerRadius: TimbreRadius.card, style: .continuous).fill(c.bg_surface))
                    .overlay(RoundedRectangle(cornerRadius: TimbreRadius.card, style: .continuous).strokeBorder(c.line_default, lineWidth: 1))
            }

            if let drv = appState.driverTelemetry {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(index: "03", title: drv.driverName, subtitle: drv.connectionStatus) {
                        if drv.accessoryFamily == nil, drv.driverName.contains("Momentum 4") {
                            Button(appState.t("dev.m4.refresh")) { appState.refreshHardwareTelemetryNow() }.buttonStyle(.t(.secondary, compact: true))
                        }
                    }
                    Card {
                        if drv.accessoryFamily != nil {
                            AppleAccessoryCard(appState: appState, telemetry: drv, colors: c)
                        } else {
                            driverGrid(drv)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(index: appState.driverTelemetry == nil ? "03" : "04", title: appState.t("ui.obs.guardian_title"), subtitle: appState.t("ui.obs.guardian_sub"))
                ListCard {
                    if appState.guardianAlerts.isEmpty {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle").foregroundStyle(c.semantic_positive)
                            Text(appState.t("obs.clean_chain")).type(TimbreTypography.body).foregroundStyle(c.ink_primary)
                            Spacer()
                        }
                        .padding(.horizontal, 20).frame(height: 56)
                    }
                    ForEach(Array(appState.guardianAlerts.enumerated()), id: \.element.id) { i, alert in
                        if i > 0 { Hairline().padding(.leading, 20) }
                        alertRow(alert)
                    }
                }
            }

            TimelineSection(appState: appState, index: appState.driverTelemetry == nil ? "04" : "05")
        }
    }

    private var obsSummary: String {
        appState.guardianAlerts.isEmpty ? appState.t("ui.obs.summary_clean") : String(format: appState.t("ui.obs.summary_alerts"), appState.guardianAlerts.count)
    }

    private struct Stage: Identifiable {
        let id: String
        let title: String
        let value: String
        let detail: String
        let origin: SignalTrustBadge
        let active: Bool
    }

    private var stages: [Stage] {
        let p = appState.activePreset
        let dev = appState.activeOutputDevice
        let taps = appState.activeTapsCount
        return [
            Stage(id: "src", title: appState.t("obs.stage.sources"), value: "\(appState.playingCount)", detail: String(format: appState.t("ui.obs.n_listed"), appState.mixerSources.count), origin: .measured, active: appState.playingCount > 0),
            Stage(id: "mix", title: appState.t("obs.stage.mixer"), value: taps == 0 ? appState.t("ui.path.native_short") : "\(taps) tap\(taps == 1 ? "" : "s")", detail: taps == 0 ? appState.t("ui.obs.untouched") : "Float32 · +1 buffer", origin: taps == 0 ? .bitPerfect : .measured, active: taps > 0),
            Stage(id: "cor", title: appState.t("obs.stage.correction"), value: "\(p.correctionBands.filter(\.enabled).count) " + appState.t("ui.obs.filters"), detail: p.correctionMetadata?.headphoneModel ?? appState.t("ui.obs.none"), origin: .measured, active: p.correctionBands.contains(where: \.enabled)),
            Stage(id: "tas", title: appState.t("obs.stage.taste"), value: "\(p.effectiveTasteBands.filter { $0.enabled && abs($0.gainDB) > 0.01 }.count) " + appState.t("ui.obs.filters"), detail: Fmt.db(appState.telemetry.preampDB) + " dB preamp", origin: .measured, active: p.effectiveTasteBands.contains { $0.enabled && abs($0.gainDB) > 0.01 }),
            Stage(id: "pro", title: appState.t("obs.stage.protection"), value: Fmt.db(p.limiterCeilingDBTP), detail: "dBTP · lookahead", origin: .measured, active: taps > 0),
            Stage(id: "dev", title: appState.t("obs.stage.device"), value: dev?.rateLabel ?? "—", detail: dev?.name ?? "—", origin: .reported, active: true),
            Stage(id: "ear", title: appState.t("obs.stage.headphone"), value: appState.driverTelemetry?.reportedCodec ?? (dev?.transport.isBluetooth == true ? "AAC?" : "—"), detail: dev?.transportLabel(appState.t) ?? "—", origin: .inferred, active: true)
        ]
    }

    private var signalPath: some View {
        HStack(spacing: 0) {
            ForEach(Array(stages.enumerated()), id: \.element.id) { i, s in
                if i > 0 {
                    Rectangle().fill(s.active ? c.accent_signal.opacity(0.6) : c.line_strong).frame(width: 14, height: 1)
                }
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Eyebrow(text: s.title)
                        Spacer(minLength: 0)
                        OriginMark(origin: s.origin)
                    }
                    Text(s.value).type(TimbreTypography.cardTitle).foregroundStyle(s.active ? c.ink_primary : c.ink_muted).lineLimit(1).minimumScaleFactor(0.7)
                    Text(s.detail).type(TimbreTypography.monoSmall).foregroundStyle(c.ink_muted).lineLimit(1)
                }
                .padding(12)
                .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
                .background(RoundedRectangle(cornerRadius: TimbreRadius.control + 2, style: .continuous).fill(s.active ? c.bg_surface : c.bg_inset))
                .overlay(RoundedRectangle(cornerRadius: TimbreRadius.control + 2, style: .continuous).strokeBorder(s.active ? c.line_strong : c.line_default, lineWidth: s.active ? 1 : 0.5))
            }
        }
    }

    private func driverGrid(_ drv: HardwareDriverTelemetry) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 18), count: 4), alignment: .leading, spacing: 16) {
            fact(appState.t("dev.m4.battery"), drv.batteryPercent.map { "\($0)%" } ?? "—")
            fact("ANC", drv.ancEnabled.map { $0 ? appState.t("dev.m4.anc_on") : appState.t("dev.m4.anc_off") } ?? "—")
            fact(appState.t("dev.m4.transparency"), drv.transparencyPercent.map { "\($0)%" } ?? "—")
            fact("Codec", drv.reportedCodec ?? "—")
            fact("Firmware", drv.firmwareVersion ?? "—")
            fact(appState.t("ui.obs.onboard_eq"), drv.internalEQNonFlat == true ? appState.t("dev.m4.eq_non_flat") : appState.t("ui.obs.flat"))
            fact(appState.t("ui.obs.access"), appState.t("dev.m4.read_only"))
        }
    }

    private func fact(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Eyebrow(text: label)
            Text(value).type(TimbreTypography.body).foregroundStyle(c.ink_primary).lineLimit(1)
        }
    }

    private func alertRow(_ alert: GuardianAlert) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Circle().fill(alert.severity == .info ? c.semantic_info : (alert.severity == .critical ? c.semantic_negative : c.semantic_warning)).frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(appState.t(alert.titleKey)).type(TimbreTypography.bodyStrong).foregroundStyle(c.ink_primary)
                    Text(alert.ruleID.rawValue).type(TimbreTypography.micro).foregroundStyle(c.ink_faint)
                }
                Text(alert.detail).type(TimbreTypography.caption).foregroundStyle(c.ink_muted).lineLimit(2)
            }
            Spacer()
            Button(appState.t("guard.action.ignore_pair")) { appState.silenceGuardianPair(alert) }.buttonStyle(.t(.ghost, compact: true))
            if let act = alert.suggestedActionKey {
                Button(appState.t(act)) { appState.runGuardianAction(alert) }.buttonStyle(.t(.primary, compact: true))
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
    }
}

/// Real spectrum from the DSP telemetry with dB level axis, frequency grid, and peak-hold envelope (modeled after `@audiocn/spectrum`). Draws nothing it did not receive (P4).
private struct SpectrumView: View {
    let bins: [Float]
    let sampleRate: Double
    let emptyText: String
    @Environment(\.palette) private var c

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width - 34, h = geo.size.height - 18
            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in
                    for f in [50.0, 100.0, 200.0, 500.0, 1000.0, 2000.0, 5000.0, 10000.0] {
                        let x = CGFloat((log10(f) - log10(20)) / (log10(20000) - log10(20))) * w
                        var p = Path(); p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: h))
                        let major = f == 100 || f == 1000 || f == 10000
                        ctx.stroke(p, with: .color(major ? c.line_default : c.line_grid), lineWidth: 0.5)
                    }
                    for db in [-72.0, -48.0, -24.0, 0.0] {
                        let y = h - CGFloat((db + 96.0) / 96.0) * h
                        var p = Path(); p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: w, y: y))
                        ctx.stroke(p, with: .color(db == 0 ? c.line_strong : c.line_grid), lineWidth: 0.5)
                    }
                    guard bins.count > 8 else { return }
                    var line = Path(); var peakLine = Path(); var started = false
                    for (i, v) in bins.enumerated() where i > 0 {
                        let fr = Double(i) / Double(bins.count) * sampleRate / 2
                        guard fr >= 20, fr <= 20000 else { continue }
                        let x = CGFloat((log10(fr) - log10(20)) / (log10(20000) - log10(20))) * w
                        let norm = CGFloat(min(max((Double(v) + 96) / 96, 0), 1))
                        let y = h - norm * h
                        let neighborPeak = max(Double(v), Double(bins[max(1, i - 1)]), Double(bins[min(bins.count - 1, i + 1)])) + 3.0
                        let peakNorm = CGFloat(min(max((neighborPeak + 96) / 96, 0), 1))
                        let py = h - peakNorm * h
                        if started {
                            line.addLine(to: CGPoint(x: x, y: y))
                            peakLine.addLine(to: CGPoint(x: x, y: py))
                        } else {
                            line.move(to: CGPoint(x: x, y: y))
                            peakLine.move(to: CGPoint(x: x, y: py))
                            started = true
                        }
                    }
                    var area = line; area.addLine(to: CGPoint(x: w, y: h)); area.addLine(to: CGPoint(x: 0, y: h)); area.closeSubpath()
                    ctx.fill(area, with: .linearGradient(Gradient(colors: [c.accent_signal.opacity(0.22), c.accent_signal.opacity(0.02)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
                    ctx.stroke(peakLine, with: .color(c.ink_muted.opacity(0.45)), style: StrokeStyle(lineWidth: 0.8, dash: [2, 2]))
                    ctx.stroke(line, with: .color(c.accent_signal), lineWidth: 1.35)
                }
                .frame(width: w, height: h)
                if bins.count <= 8 {
                    Text(emptyText).type(TimbreTypography.caption).foregroundStyle(c.ink_muted).frame(width: w, height: h)
                }
                ForEach([20.0, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000], id: \.self) { f in
                    Text(Fmt.hz(f)).type(TimbreTypography.monoSmall).foregroundStyle(c.ink_muted).fixedSize()
                        .position(x: min(max(CGFloat((log10(f) - log10(20)) / (log10(20000) - log10(20))) * w, 10), w - 12), y: h + 10)
                }
                ForEach([0.0, -24.0, -48.0, -72.0], id: \.self) { db in
                    Text(db == 0 ? "0 dB" : "\(Int(db))")
                        .type(TimbreTypography.monoSmall)
                        .foregroundStyle(c.ink_muted)
                        .fixedSize()
                        .position(x: w + 18, y: max(6, min(h - 6, h - CGFloat((db + 96.0) / 96.0) * h)))
                }
            }
        }
    }
}

// MARK: - Settings

private struct SettingsPage: View {
    @ObservedObject var appState: AppState
    @Binding var appearance: String
    @Environment(\.palette) private var c

    var body: some View {
        VStack(alignment: .leading, spacing: 36) {
            PageHeader(index: appState.t("nav.settings"), title: appState.t("ui.settings.title"), summary: appState.t("ui.settings.summary")) { EmptyView() }
                .padding(.bottom, -28)

            group("01", appState.t("ui.settings.appearance")) {
                row(appState.t("ui.settings.language"), nil) {
                    TSegmented(options: TimbreLanguage.allCases.map { ($0, $0.displayName) }, selection: $appState.language)
                }
                Hairline().padding(.leading, 20)
                row(appState.t("ui.settings.studio_theme"), appState.t("ui.settings.studio_theme_sub")) {
                    TSegmented(options: [("system", appState.t("ui.settings.system")), ("light", appState.t("ui.settings.light")), ("dark", appState.t("ui.settings.dark"))], selection: $appearance)
                }
            }
            group("02", appState.t("ui.settings.notch")) {
                row(appState.t("ui.settings.notch_on"), appState.t("ui.settings.notch_on_sub")) { TSwitch(isOn: $appState.notchEnabled) }
                Hairline().padding(.leading, 20)
                row(appState.t("ui.settings.ears"), appState.t("ui.settings.ears_sub")) {
                    TSwitch(isOn: Binding(get: { appState.showCompactActivity }, set: { appState.toggleShowCompact($0) }))
                }
                Hairline().padding(.leading, 20)
                row(appState.t("ui.settings.hide_fullscreen"), appState.t("ui.settings.hide_fullscreen_sub")) {
                    TSwitch(isOn: Binding(get: { appState.hideNotchInFullscreen }, set: { appState.toggleHideNotchInFullscreen($0) }))
                }
                Hairline().padding(.leading, 20)
                row(appState.t("ui.settings.menubar_icon"), appState.notchScreenAvailable ? appState.t("ui.settings.menubar_icon_sub") : appState.t("ui.settings.menubar_icon_no_notch")) {
                    TSwitch(isOn: Binding(get: { appState.menuBarIconVisible }, set: { appState.setShowMenuBarIcon($0) }))
                        .disabled(!appState.notchScreenAvailable || appState.menuBarOnlyMode || !appState.notchEnabled)
                }
                Hairline().padding(.leading, 20)
                row(appState.t("notch.menu_only_badge"), appState.competingNotchApps.isEmpty ? appState.t("ui.settings.menu_only_sub") : String(format: appState.t("ui.settings.competing"), appState.competingNotchApps.joined(separator: ", "))) {
                    TSwitch(isOn: $appState.menuBarOnlyMode)
                }
            }
            group("03", appState.t("ui.settings.permissions")) {
                tcc(appState.t("tcc.audio.title"), appState.t("tcc.audio.why"), granted: !appState.tapEngine.tccAudioCaptureDeniedOrZeroed, pane: "audio")
                Hairline().padding(.leading, 20)
                tcc(appState.t("tcc.ax.title"), appState.t("tcc.ax.why"), granted: appState.accessibilityGranted, pane: "accessibility")
                Hairline().padding(.leading, 20)
                tcc(appState.t("tcc.bt.title"), appState.t("tcc.bt.why"), granted: CBCentralManager.authorization == .allowedAlways, pane: "bluetooth")
            }
            group("04", appState.t("ui.settings.browsers")) {
                row(appState.t("ui.settings.bridge"), appState.ipcPortActive ? appState.t("ui.settings.bridge_on") : appState.t("ui.settings.bridge_off")) {
                    Button(appState.t("ui.settings.copy_token")) {
                        if let tok = appState.ipcServer?.sessionToken {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(tok, forType: .string)
                        }
                    }
                    .buttonStyle(.t(.secondary, compact: true))
                    .disabled(!appState.ipcPortActive)
                }
            }
            group("05", appState.t("ui.settings.data")) {
                row(appState.t("ui.settings.diagnostics"), appState.t("ui.settings.diagnostics_sub")) {
                    Button(appState.t("ui.settings.export")) { appState.exportSanitizedDiagnostics() }.buttonStyle(.t(.secondary, compact: true))
                }
                Hairline().padding(.leading, 20)
                row(appState.t("ui.settings.history"), appState.t("ui.settings.history_sub")) {
                    Button(appState.t("ui.settings.clear")) { appState.clearAllLocalHistory() }.buttonStyle(.t(.destructive, compact: true))
                }
                Hairline().padding(.leading, 20)
                row(appState.t("ui.settings.intro"), nil) {
                    Button(appState.t("onboard.replay")) { appState.replayOnboarding() }.buttonStyle(.t(.ghost, compact: true))
                }
            }
        }
    }

    private func group<Content: View>(_ index: String, _ title: String, @ViewBuilder content: () -> Content) -> some View {
        let rows = content()
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(index: index, title: title)
            ListCard { rows }
        }
    }

    private func row<Trailing: View>(_ title: String, _ sub: String?, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).type(TimbreTypography.body).foregroundStyle(c.ink_primary)
                if let sub { Text(sub).type(TimbreTypography.caption).foregroundStyle(c.ink_muted).fixedSize(horizontal: false, vertical: true) }
            }
            Spacer(minLength: 16)
            trailing()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(minHeight: 54)
    }

    private func tcc(_ title: String, _ why: String, granted: Bool, pane: String) -> some View {
        row(title, why) {
            HStack(spacing: 10) {
                Badge(text: granted ? appState.t("tcc.status.ok") : appState.t("tcc.status.pending"), tone: granted ? .positive : .warning)
                Button(appState.t("tcc.open_settings")) {
                    appState.openSystemSettingsTCC(pane)
                    if pane == "accessibility" {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { appState.setupMediaKeysIfGranted() }
                    }
                }
                .buttonStyle(.t(.ghost, compact: true))
            }
        }
    }
}

// MARK: - About

private struct AboutPage: View {
    @ObservedObject var appState: AppState
    @Environment(\.palette) private var c

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("timbr").font(.system(size: 56, weight: .semibold)).tracking(-2.6)
                    Text(".").font(.system(size: 56, weight: .semibold)).foregroundStyle(c.accent_signal)
                }
                .foregroundStyle(c.ink_primary)
                Text(appState.language.tagline).type(TimbreTypography.prose).foregroundStyle(c.ink_secondary)
                Text(appState.t("support.body")).type(TimbreTypography.body).foregroundStyle(c.ink_muted).frame(maxWidth: 560, alignment: .leading).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 24)
            HStack(spacing: 10) {
                if let gh = URL(string: "https://github.com/v1nometrics/timbr") {
                    Button(appState.t("ui.about.source")) { NSWorkspace.shared.open(gh) }.buttonStyle(.t(.primary))
                }
                if let sp = URL(string: "https://github.com/sponsors/v1nometrics") {
                    Button(appState.t("ui.about.sponsor")) { NSWorkspace.shared.open(sp) }.buttonStyle(.t(.secondary))
                }
            }
            Hairline()
            HStack(spacing: 40) {
                fact(appState.t("ui.about.version"), Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev")
                fact(appState.t("ui.about.license"), "MPL-2.0")
                fact(appState.t("ui.about.engine"), "Float64 · vDSP")
                fact(appState.t("ui.about.privacy"), appState.t("ui.about.local"))
            }
        }
    }

    private func fact(_ l: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Eyebrow(text: l)
            Text(v).type(TimbreTypography.body).foregroundStyle(c.ink_primary)
        }
    }
}
