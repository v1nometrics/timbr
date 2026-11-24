// SPDX-License-Identifier: MPL-2.0
// Studio window (docs/05-design-system/03-superficies.md §Estúdio).
// Editorial studio layout: numbered sections, KPI tiles,
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
                    if appState.updater.shouldShowStudioBanner {
                        UpdateBannerView(appState: appState)
                            .padding(.bottom, TimbreSpacing.s5)
                            .transition(.opacity.combined(with: .offset(y: -8)))
                    }
                    if let banner = appState.statusBanner {
                        BannerView(text: banner) { appState.statusBanner = nil }
                            .padding(.bottom, TimbreSpacing.s5)
                            .transition(.opacity.combined(with: .offset(y: -8)))
                    }
                    page
                        .id(appState.selectedTab)
                        .transition(.opacity)
                }
                .animation(TimbreMotion.standard, value: appState.statusBanner != nil || appState.updater.shouldShowStudioBanner)   // the page slides down with it
                .padding(.horizontal, 40)
                .padding(.top, 44)
                .padding(.bottom, 56)
                .frame(maxWidth: 1120, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.automatic)
            .background(c.bg_canvas)
        }
        .animation(TimbreMotion.tab, value: appState.selectedTab)
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
                } else if tab == .settings, appState.updater.hasActionableUpdate {
                    Circle()
                        .fill(c.semantic_info)
                        .frame(width: 6, height: 6)
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
        HStack(alignment: .bottom, spacing: TimbreSpacing.s4) {
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(text: index)
                Text(title).type(TimbreTypography.pageTitle).foregroundStyle(c.ink_primary).fixedSize(horizontal: false, vertical: true)
                Text(summary)
                    .type(TimbreTypography.body)
                    .foregroundStyle(c.ink_secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 460, alignment: .leading)
            }
            Spacer(minLength: 12)
            HStack(spacing: 8) { actions() }
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.bottom, 22)
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

// MARK: - Observatory: listening time (ADR-0023)

private struct ListeningSection: View {
    @ObservedObject var appState: AppState
    let index: String
    @Environment(\.palette) private var c

    private var week: [ListeningDay] {
        // The last seven calendar days, oldest first, with empty days filled in.
        let cal = Calendar.current
        let byDay = Dictionary(appState.listeningWeek.map { ($0.day, $0) }, uniquingKeysWith: { a, _ in a })
        return (0..<7).reversed().map { back in
            let key = ListeningPolicy.dayKey(cal.date(byAdding: .day, value: -back, to: Date()) ?? Date())
            if key == appState.listeningToday.day { return appState.listeningToday }
            return byDay[key] ?? ListeningDay(day: key)
        }
    }

    var body: some View {
        let today = appState.listeningToday
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(index: index, title: appState.t("ui.obs.listening_title"), subtitle: appState.t("ui.obs.listening_sub"))
            ListCard {
                HStack(spacing: 0) {
                    stat(appState.t("ui.obs.listening_today"), ListeningPolicy.duration(today.personalSeconds))
                    stat(appState.t("ui.obs.listening_high"), ListeningPolicy.duration(today.highSeconds), warn: appState.listeningAdvice)
                    stat(appState.t("ui.obs.listening_streak"), ListeningPolicy.duration(appState.listeningStreakSeconds), warn: appState.listeningAdvice)
                }
                .frame(height: 70)
                Hairline()
                HStack(spacing: 12) {
                    Image(systemName: appState.listeningAdvice ? "exclamationmark.triangle" : "checkmark.circle")
                        .foregroundStyle(appState.listeningAdvice ? c.semantic_warning : c.semantic_positive)
                    Text(appState.listeningAdvice
                         ? String(format: appState.t("ui.obs.listening_advice"), ListeningPolicy.duration(appState.listeningStreakSeconds))
                         : appState.t("ui.obs.listening_ok"))
                        .type(TimbreTypography.small).foregroundStyle(c.ink_primary)
                    Spacer()
                }
                .padding(.horizontal, 20).frame(height: 46)
                Hairline()
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(text: appState.t("ui.obs.listening_week"))
                    HStack(alignment: .bottom, spacing: 10) {
                        ForEach(week) { d in dayBar(d) }
                    }
                    .frame(height: 64)
                    Text(appState.t("ui.obs.listening_note")).type(TimbreTypography.caption).foregroundStyle(c.ink_muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
            }
        }
    }

    private func stat(_ title: String, _ value: String, warn: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Eyebrow(text: title)
            Text(value).type(TimbreTypography.mediumValue).foregroundStyle(warn ? c.semantic_warning : c.ink_primary)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One day: the bar is the time with headphones (scaled to 8 h = full height); the darker part is the high-volume share.
    private func dayBar(_ d: ListeningDay) -> some View {
        let full: CGFloat = 8 * 3600
        let h = min(1, CGFloat(d.personalSeconds) / full)
        let hi = d.personalSeconds > 0 ? min(1, CGFloat(d.highSeconds / d.personalSeconds)) : 0
        let label = String(d.day.suffix(2))
        return VStack(spacing: 4) {
            ZStack(alignment: .bottom) {
                Capsule().fill(c.bg_track).frame(width: 18, height: 46)
                Capsule().fill(c.ink_muted.opacity(0.55)).frame(width: 18, height: max(d.personalSeconds > 0 ? 4 : 0, 46 * h))
                Capsule().fill(c.ink_primary).frame(width: 18, height: max(d.highSeconds > 0 ? 3 : 0, 46 * h * hi))
            }
            .frame(height: 46, alignment: .bottom)
            Text(label).type(TimbreTypography.monoSmall).foregroundStyle(c.ink_faint)
        }
        .frame(maxWidth: .infinity)
        .help("\(d.day): \(ListeningPolicy.duration(d.personalSeconds)) · \(ListeningPolicy.duration(d.highSeconds))")
    }
}

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
        VStack(alignment: .leading, spacing: 32) {
            PageHeader(index: appState.t("nav.mixer"), title: appState.t("ui.mixer.title"), summary: appState.signalSummary) {
                Button(appState.t("ui.mixer.reset")) { appState.resetAllSourceVolumesToFlat() }
                    .buttonStyle(.t(.secondary))
                    .disabled(!appState.hasNonFlatSourceVolumes)
                    .help(appState.t("mixer.reset_flat_help"))
            }
            .padding(.bottom, -24)

            masterConsoleStrip

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

    private var masterConsoleStrip: some View {
        let dev = appState.activeOutputDevice
        let t = appState.telemetry
        let live = appState.hasLiveSignal
        let peakDB = live ? max(appState.meterBallisticsL.smoothedDB, appState.meterBallisticsR.smoothedDB) : -60.0
        let holdDB = live ? max(appState.meterBallisticsL.heldPeakDB, appState.meterBallisticsR.heldPeakDB) : nil
        let isMuted = appState.outputSilenced
        let rawVol = appState.activeOutputVolume ?? Double(dev.flatMap { appState.halManager.readOutputVolumeScalar(deviceID: $0.audioObjectID) } ?? 0.5)
        let vol = isMuted ? 0 : rawVol
        let activeBands = appState.activePreset.allEffectiveBands.filter { $0.enabled && abs($0.gainDB) > 0.01 }.count

        return ListCard {
            HStack(spacing: 14) {
                if let dev {
                    DeviceGlyph(device: dev, size: 32, active: true)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(dev?.name ?? "—")
                            .type(TimbreTypography.bodyStrong)
                            .foregroundStyle(c.ink_primary)
                            .lineLimit(1)
                        if appState.outputDevices.count > 1 {
                            MenuChip(title: appState.t("ui.mixer.change_input")) {
                                ForEach(appState.outputDevices) { d in
                                    Button {
                                        appState.selectDefaultOutput(d)
                                    } label: {
                                        if d.isDefaultOutput {
                                            Label(d.name, systemImage: "checkmark")
                                        } else {
                                            Text(d.name)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    HStack(spacing: 6) {
                        OriginMark(origin: .reported)
                        Text(dev.map { "\($0.rateLabel) · \($0.transportLabel(appState.t))" } ?? "—")
                            .type(TimbreTypography.monoSmall)
                            .foregroundStyle(c.ink_muted)
                    }
                }
                .frame(minWidth: 210, alignment: .leading)

                Spacer(minLength: 8)

                if let dev, dev.isHWVolumeMasterSettable || dev.isHWVolumeChannelSettable {
                    let liveNorm: Double? = (!isMuted && appState.playingCount > 0)
                        ? (live ? AudioDecibelMath.dbToNormalized(peakDB, minDB: -60, maxDB: 0) : min(1.0, rawVol * 0.52))
                        : nil
                    TFader(
                        value: Binding(get: { vol }, set: { appState.setOutputVolume(dev, value: $0, showHUD: false) }),
                        range: 0...1,
                        tint: c.ink_primary,
                        label: dev.name,
                        valueText: isMuted ? appState.t("ui.notch.muted") : Fmt.percent(rawVol),
                        liveMeterNorm: liveNorm,
                        scaleMarks: [0.25, 0.5, 0.75]
                    )
                    .frame(maxWidth: 320)

                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text(isMuted ? "—" : Fmt.percent(rawVol)).type(TimbreTypography.monoValue)
                        if !isMuted { Text("%").type(TimbreTypography.monoSmall).foregroundStyle(c.ink_muted) }
                    }
                    .foregroundStyle(isMuted ? c.semantic_warning : c.ink_primary)
                    .frame(width: 52, alignment: .trailing)

                    if dev.isHWMuteSettable {
                        TChannelButton(
                            text: "M",
                            symbol: isMuted ? "speaker.slash.fill" : nil,
                            pressed: isMuted,
                            tone: .mute,
                            size: 24,
                            help: appState.t("ui.mute")
                        ) {
                            appState.toggleOutputMute()
                        }
                    }
                } else {
                    Badge(text: appState.t("dev.sw_volume"), tone: .warning)
                        .help(appState.t("ui.output.sw_help"))
                }
            }
            .padding(.horizontal, 20)
            .frame(height: 62)

            Hairline()

            // Integrated Signal Chain Telemetry Bar (replaces the 4 separate KPI cards)
            HStack(spacing: 14) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(appState.isProcessingBypassed ? c.ink_muted : (appState.pathIsNative ? c.semantic_positive : c.accent_signal))
                        .frame(width: 6, height: 6)
                    Text(appState.isProcessingBypassed ? appState.t("ui.path.bypassed") : (appState.pathIsNative ? appState.t("ui.path.native_short") : appState.t("ui.path.processing_short")))
                        .type(TimbreTypography.monoSmall)
                        .foregroundStyle(c.ink_primary)
                    Text("· " + String(format: appState.t("ui.kpi.taps_n"), appState.activeTapsCount))
                        .type(TimbreTypography.monoSmall)
                        .foregroundStyle(c.ink_muted)
                }
                .fixedSize()

                Hairline(vertical: true).frame(height: 14)

                HStack(spacing: 5) {
                    Eyebrow(text: appState.t("ui.kpi.playing"))
                    Text("\(appState.playingCount)")
                        .type(TimbreTypography.monoValue)
                        .foregroundStyle(appState.playingCount > 0 ? c.ink_primary : c.ink_muted)
                    Text("/ \(appState.mixerSources.count)")
                        .type(TimbreTypography.monoSmall)
                        .foregroundStyle(c.ink_faint)
                }
                .fixedSize()

                Hairline(vertical: true).frame(height: 14)

                HStack(spacing: 5) {
                    Eyebrow(text: appState.t("eq.preamp"))
                    Text(Fmt.db(t.preampDB) + " dB")
                        .type(TimbreTypography.monoValue)
                        .foregroundStyle(c.ink_primary)
                }
                .fixedSize()

                Hairline(vertical: true).frame(height: 14)

                HStack(spacing: 7) {
                    Eyebrow(text: appState.t("ui.eq.true_peak"))
                    TLevelMeter(peakDB: peakDB, rmsDB: live ? t.lufsMomentary : nil, heldPeakDB: holdDB, height: 5)
                        .frame(width: 72)
                    Text((live && max(t.truePeakL, t.truePeakR) > -70) ? Fmt.signed(max(t.truePeakL, t.truePeakR)) + " dBTP" : "—")
                        .type(TimbreTypography.monoSmall)
                        .foregroundStyle(c.ink_secondary)
                }
                .fixedSize()

                Spacer(minLength: 8)

                Button {
                    appState.selectedTab = .equalizer
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "point.bottomleft.forward.to.point.topright.scurvepath")
                            .font(.system(size: 10, weight: .medium))
                        Text(appState.activePreset.name + (activeBands > 0 ? " (\(activeBands))" : ""))
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.t(.ghost, compact: true))
                .fixedSize()
            }
            .padding(.horizontal, 20)
            .frame(height: 38)
            .background(c.bg_inset)
        }
    }

    @ViewBuilder private var sources: some View {
        ListCard {
            columnHeader([appState.t("ui.col.app"), appState.t("ui.col.volume"), ""])
            if appState.mixerSources.isEmpty {
                EmptyStateView(title: appState.t("notch.empty_playing"), detail: appState.t("ui.mixer.empty_detail"))
            }
            ForEach(Array(appState.mixerSources.enumerated()), id: \.element.id) { i, src in
                VStack(spacing: 0) {
                    if i > 0 { Hairline().padding(.leading, 64) }
                    SourceRow(appState: appState, src: src)
                    ForEach(tabs(for: src), id: \.tabID) { tab in
                        Hairline().padding(.leading, 64)
                        TabRow(appState: appState, tab: tab)
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(TimbreMotion.smooth, value: appState.mixerSources.map(\.bundleID))
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
        VStack(alignment: .leading, spacing: 14) {
            PageHeader(index: appState.t("nav.eq"), title: appState.t("ui.eq.title"), summary: eqSummary) {
                TSegmented(options: [
                    (AppState.EQMode.four, "4"), (.five, "5"), (.ten, "10"),
                    (.free, appState.t("eq.mode.advanced")),
                ], selection: Binding(get: { appState.eqMode }, set: { appState.setEQMode($0) }))

                Button(appState.t("ui.eq.save")) { appState.saveCurrentPreset() }
                    .buttonStyle(.t(.primary, compact: true))
            }
            .padding(.bottom, -14)

            // Unified EQ Instrument Console: Correction & Preset Bar + Curve + Metrology + Fader Bank / Band Table
            VStack(spacing: 0) {
                correctionAndLegendBar
                Hairline()
                EQCurveCanvas(appState: appState, height: 192)
                    .padding(.horizontal, 18)
                    .padding(.top, 6)
                    .padding(.bottom, 8)
                Hairline()
                metrology
                Hairline()
                if appState.activePreset.useAdvancedPEQ {
                    advancedBandsConsole
                } else {
                    graphicFaderBankConsole
                }
            }
            .background(RoundedRectangle(cornerRadius: TimbreRadius.card, style: .continuous).fill(c.bg_surface))
            .overlay(RoundedRectangle(cornerRadius: TimbreRadius.card, style: .continuous).strokeBorder(c.line_default, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: TimbreRadius.card, style: .continuous))

            // Compact 2-Column Audition & Tone Assistant Utility Strip
            HStack(alignment: .top, spacing: 14) {
                comparePanel
                assistantPanel
            }
        }
    }

    private var presetMenu: some View {
        MenuChip(title: appState.activePreset.name, symbol: "slider.horizontal.3") {
            Button {
                appState.resetToDefaultNeutralPreset()
            } label: {
                if appState.activePreset.name == "Neutral Studio" && appState.activePreset.allEffectiveBands.allSatisfy({ abs($0.gainDB) < 0.01 }) {
                    Label(appState.t("ui.eq.preset_default"), systemImage: "checkmark")
                } else {
                    Text(appState.t("ui.eq.preset_default"))
                }
            }
            if !appState.savedPresets.isEmpty {
                ForEach(appState.savedPresets) { preset in
                    Button {
                        appState.selectPreset(preset)
                    } label: {
                        if preset.id == appState.activePreset.id {
                            Label(preset.name, systemImage: "checkmark")
                        } else {
                            Text(preset.name)
                        }
                    }
                }
            }
            Button(appState.t("eq.import_apo")) { appState.importEqualizerAPOFromPanel() }
            Button(appState.t("eq.export_apo")) { appState.exportEqualizerAPOToPanel() }
        }
    }

    private static var cachedMatchKey: String = ""
    private static var cachedMatches: [AutoEqEntry] = []

    private var correctionAndLegendBar: some View {
        let devName = appState.activeOutputDevice?.name ?? ""
        let matches: [AutoEqEntry] = {
            if Self.cachedMatchKey == devName { return Self.cachedMatches }
            let m = AutoEqService.matchDeviceName(devName)
            Self.cachedMatchKey = devName
            Self.cachedMatches = m
            return m
        }()

        return HStack(spacing: 10) {
            HStack(spacing: 12) {
                legend(appState.t("eq.layer.correction"), dashed: true, color: c.ink_secondary)
                legend(appState.t("eq.layer.taste"), dashed: false, color: c.ink_muted)
                legend(appState.t("eq.layer.result"), dashed: false, color: c.accent_signal, thick: true)
            }
            .fixedSize()

            Spacer(minLength: 8)

            // Inline AutoEq Headphone Correction + Preset & A/B Strip
            HStack(spacing: 8) {
                presetMenu

                TSegmented(options: [
                    (ABCompareMode.full, "EQ"),
                    (.bypassEqualLatency, "Flat")
                ], selection: Binding(
                    get: { appState.abMode },
                    set: { mode in
                        if mode != appState.abMode { appState.toggleABNeutral() }
                    }
                ))

                Hairline(vertical: true).frame(height: 16)

                Image(systemName: "headphones")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(appState.activePreset.correctionMetadata != nil ? c.ink_primary : c.ink_muted)
                Text("AutoEq")
                    .type(TimbreTypography.eyebrow)
                    .foregroundStyle(c.ink_muted)

                if let meta = appState.activePreset.correctionMetadata {
                    Badge(text: "\(meta.headphoneModel) · \(meta.sourceCredit)", tone: .accent, dot: true)
                    Button(appState.t("ui.eq.remove")) { appState.clearCorrection() }
                        .buttonStyle(.t(.ghost, compact: true))
                } else if let topMatch = matches.first {
                    Button("\(topMatch.headphoneName) · \(appState.t("ui.apply"))") {
                        appState.applyAutoEqEntry(topMatch)
                    }
                    .buttonStyle(.t(.secondary, compact: true))
                }

                MenuChip(title: appState.t("ui.eq.browse_autoeq")) {
                    if !matches.isEmpty {
                        ForEach(matches) { entry in
                            Button("\(entry.headphoneName) (\(entry.source))") {
                                appState.applyAutoEqEntry(entry)
                            }
                        }
                    }
                    ForEach(AutoEqService.starterCatalog) { entry in
                        Button("\(entry.headphoneName) · \(entry.source)") {
                            appState.applyAutoEqEntry(entry)
                        }
                    }
                }
            }
            .fixedSize()
        }
        .padding(.horizontal, 20)
        .frame(height: 40)
        .background(c.bg_inset.opacity(0.5))
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
        .frame(height: 52)
        .background(c.bg_inset.opacity(0.35))
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Eyebrow(text: label)
            Text(value).type(TimbreTypography.monoValue).foregroundStyle(c.ink_primary)
        }
        .frame(width: 138, alignment: .leading)
    }

    /// 31.5 Hz must not read "32 Hz" (Fmt.hz rounds).
    private func freqLabel(_ f: Double) -> String { f < 100 && f != f.rounded() ? String(format: "%.1f", f) : Fmt.hz(f) }

    // MARK: - Unified Vertical Graphic Fader Bank (4 / 5 / 10 bands)

    private var graphicFaderBankConsole: some View {
        let layout = appState.activePreset.layout
        let gains = appState.activePreset.gains(for: layout)
        let range = layout.gainRangeDB
        let sub: String = {
            switch layout {
            case .four: return appState.t("ui.eq.taste_sub")
            case .five: return appState.t("ui.eq.taste_sub_5")
            case .ten: return appState.t("ui.eq.taste_sub_10")
            }
        }()

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Eyebrow(text: appState.t("ui.eq.taste_title"))
                Text("·").foregroundStyle(c.ink_faint)
                Text(sub).type(TimbreTypography.caption).foregroundStyle(c.ink_secondary).lineLimit(1)
                Spacer()
                Button(appState.t("ui.eq.flatten")) { appState.flattenCurrentLayout() }
                    .buttonStyle(.t(.ghost, compact: true))
                    .disabled(appState.activePreset.isLayoutFlat(layout))
            }
            .padding(.horizontal, 20)
            .frame(height: 38)

            Hairline()

            HStack(alignment: .center, spacing: 0) {
                // Left dB reference scale column
                VStack(alignment: .trailing, spacing: 0) {
                    Spacer().frame(height: 26)
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("+\(Int(range)) dB").type(TimbreTypography.monoSmall).foregroundStyle(c.ink_faint)
                        Spacer()
                        Text("+\(Int(range / 2))").type(TimbreTypography.monoSmall).foregroundStyle(c.ink_faint)
                        Spacer()
                        Text("0 dB").type(TimbreTypography.monoSmall).foregroundStyle(c.ink_secondary)
                        Spacer()
                        Text("−\(Int(range / 2))").type(TimbreTypography.monoSmall).foregroundStyle(c.ink_faint)
                        Spacer()
                        Text("−\(Int(range)) dB").type(TimbreTypography.monoSmall).foregroundStyle(c.ink_faint)
                    }
                    .frame(height: 90)
                    Spacer().frame(height: 36)
                }
                .frame(width: 48, alignment: .trailing)
                .padding(.trailing, 8)

                ForEach(Array(layout.slots.enumerated()), id: \.offset) { idx, slot in
                    if idx > 0 {
                        Hairline(vertical: true).frame(height: 152)
                    }
                    faderChannelStrip(
                        index: idx,
                        slot: slot,
                        gain: gains[idx],
                        range: range,
                        compact: layout == .ten,
                        name: appState.t(slot.nameKey),
                        hint: appState.t(slot.nameKey + ".hint")
                    )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }

    private func faderChannelStrip(index: Int, slot: EQLayoutSlot, gain: Double, range: Double, compact: Bool, name: String, hint: String) -> some View {
        let binding = Binding(get: { gain }, set: { appState.setLayoutGain($0, at: index) })
        let modified = abs(gain) > 0.01
        let selected = appState.selectedFixedSlotIndex == index
        let hzText = compact ? freqLabel(slot.freqHz) : (freqLabel(slot.freqHz) + " Hz")

        return VStack(spacing: 4) {
            // Top frequency + band index + info popover
            HStack(spacing: 3) {
                if !compact {
                    Text("\(index + 1)")
                        .type(TimbreTypography.monoSmall)
                        .foregroundStyle(modified || selected ? c.accent_signal : c.ink_faint)
                }
                Text(hzText)
                    .type(TimbreTypography.monoSmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(modified || selected ? c.ink_primary : c.ink_secondary)
                    .lineLimit(1)
                    .fixedSize()
                InfoHintButton(text: hint, label: name, startsOpen: index == 0)
            }
            .frame(height: 18)

            // Vertical tactile fader
            TVerticalFader(
                value: binding,
                range: -range...range,
                bipolar: true,
                resetValue: 0,
                step: 0.5,
                tint: c.accent_signal,
                height: 98,
                width: 34,
                scaleMarks: [-range, -range / 2, 0, range / 2, range],
                label: "\(name) (\(freqLabel(slot.freqHz)) Hz)",
                valueText: Fmt.db(gain) + " dB"
            )

            // Live tabular dB readout (click to zero) + semantic band title
            Button {
                appState.setLayoutGain(0, at: index)
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(Fmt.db(gain))
                        .type(TimbreTypography.monoValue)
                        .foregroundStyle(modified ? c.ink_primary : c.ink_muted)
                        .contentTransition(.numericText(value: gain))
                    Text("dB")
                        .type(TimbreTypography.monoSmall)
                        .foregroundStyle(c.ink_faint)
                }
            }
            .buttonStyle(.plain)
            .help(appState.t("ui.eq.flatten"))

            Text(name)
                .type(TimbreTypography.micro)
                .foregroundStyle(selected ? c.ink_primary : c.ink_secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: TimbreRadius.control, style: .continuous)
                .fill(selected ? c.bg_selected.opacity(0.55) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { isHov in
            if isHov {
                appState.selectedFixedSlotIndex = index
            } else if appState.selectedFixedSlotIndex == index {
                appState.selectedFixedSlotIndex = nil
            }
        }
    }

    // MARK: - Free Parametric EQ Band Console (Integrated inside main EQ instrument)

    private var advancedBandsConsole: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Eyebrow(text: appState.t("ui.eq.bands_title"))
                Text("·").foregroundStyle(c.ink_faint)
                Text(appState.t("ui.eq.bands_sub")).type(TimbreTypography.caption).foregroundStyle(c.ink_secondary).lineLimit(1)
                Spacer()
                HStack(spacing: 8) {
                    if appState.freeBandsBeforeReset != nil {
                        Button(appState.t("ui.undo")) { appState.undoResetFreeBands() }
                            .buttonStyle(.t(.ghost, compact: true))
                    }
                    Button(appState.t("ui.eq.reset_filters")) { appState.resetFreeBands() }
                        .buttonStyle(.t(.ghost, compact: true))
                        .disabled(!appState.canResetFreeBands)
                    Button {
                        appState.addTasteBand()
                    } label: {
                        Label(appState.t("ui.eq.add_band"), systemImage: "plus")
                    }
                    .buttonStyle(.t(.secondary, compact: true))
                    .disabled(!appState.canAddFreeBand)
                    .help(appState.canAddFreeBand ? "" : String(format: appState.t("ui.eq.max_bands"), appState.maxFreeBands))
                }
            }
            .padding(.horizontal, 20)
            .frame(height: 40)

            Hairline()

            HStack(spacing: 0) {
                Eyebrow(text: "#").frame(width: 34, alignment: .leading)
                Eyebrow(text: appState.t("ui.eq.col.on")).frame(width: 52, alignment: .leading)
                Eyebrow(text: appState.t("ui.eq.col.type")).frame(width: 136, alignment: .leading)
                Eyebrow(text: appState.t("ui.eq.col.freq")).frame(width: 112, alignment: .trailing)
                Eyebrow(text: appState.t("ui.eq.col.gain")).frame(width: 112, alignment: .trailing)
                Eyebrow(text: "Q").frame(width: 96, alignment: .trailing)
                Spacer()
            }
            .padding(.horizontal, 20)
            .frame(height: 32)
            .background(c.bg_inset.opacity(0.3))
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

    private func bandRow(_ i: Int, _ band: EQBand) -> some View {
        func upd(_ f: (inout EQBand) -> Void) {
            var b = band
            f(&b)
            appState.selectedEQBandID = band.id
            appState.updateTasteBand(b)
        }
        let selected = appState.selectedEQBandID == band.id
        let types: [(EQFilterType, String)] = [
            (.peak, appState.t("ui.filter.peak")),
            (.lowShelf, appState.t("ui.filter.lowshelf")),
            (.highShelf, appState.t("ui.filter.highshelf")),
            (.lowPass, appState.t("ui.filter.lowpass")),
            (.highPass, appState.t("ui.filter.highpass")),
            (.notch, appState.t("ui.filter.notch"))
        ]
        return HStack(spacing: 0) {
            Text("\(i + 1)")
                .type(TimbreTypography.monoValue)
                .foregroundStyle(band.enabled ? c.accent_signal : c.ink_muted)
                .frame(width: 34, alignment: .leading)
            TSwitch(isOn: Binding(get: { band.enabled }, set: { v in upd { $0.enabled = v } }), label: "Band \(i + 1)")
                .frame(width: 52, alignment: .leading)
            MenuChip(title: types.first(where: { $0.0 == band.type })?.1 ?? band.type.rawValue) {
                ForEach(types, id: \.0) { t in Button(t.1) { upd { $0.type = t.0 } } }
            }
            .frame(width: 136, alignment: .leading)
            ScrubValue(value: Binding(get: { band.freqHz }, set: { v in upd { $0.freqHz = v } }), range: 20...20000, step: 1, logarithmic: true,
                       format: { "\(Fmt.hz($0)) Hz" }, width: 88)
                .frame(width: 112, alignment: .trailing)
            ScrubValue(value: Binding(get: { band.gainDB }, set: { v in upd { $0.gainDB = v } }), range: -15...15, step: 0.1,
                       format: { "\(Fmt.db($0)) dB" }, width: 88)
                .frame(width: 112, alignment: .trailing)
            ScrubValue(value: Binding(get: { band.q }, set: { v in upd { $0.q = v } }), range: 0.1...10, step: 0.01,
                       format: { String(format: "%.2f", $0) }, width: 68)
                .frame(width: 96, alignment: .trailing)
            Spacer()
            IconButton(symbol: "minus.circle", size: 24, help: appState.t("ui.eq.remove_band")) {
                appState.removeTasteBand(id: band.id)
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 44)
        .background(selected ? c.bg_selected.opacity(0.55) : Color.clear)
        .opacity(band.enabled ? 1 : 0.55)
        .contentShape(Rectangle())
        .onTapGesture {
            appState.selectedEQBandID = band.id
        }
    }

    // MARK: - Lower Utility Panels (Compact 2-Column Audition & Tone Assistant)

    private func panel<Content: View>(_ title: String, _ sub: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).type(TimbreTypography.cardTitle).foregroundStyle(c.ink_primary)
                Text(sub).type(TimbreTypography.caption).foregroundStyle(c.ink_muted).fixedSize(horizontal: false, vertical: true)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: TimbreRadius.card, style: .continuous).fill(c.bg_surface))
        .overlay(RoundedRectangle(cornerRadius: TimbreRadius.card, style: .continuous).strokeBorder(c.line_default, lineWidth: 1))
    }

    private var comparePanel: some View {
        panel(appState.t("ui.eq.compare_title"), appState.t("ui.eq.compare_sub")) {
            HStack(spacing: 8) {
                if !appState.blindABActive {
                    Button(appState.t("ui.eq.start_blind")) { appState.startBlindAB() }
                        .buttonStyle(.t(.secondary, compact: true))
                } else {
                    sampleButton("X", selected: appState.blindCurrentIsX) { appState.selectBlindSample(isX: true) }
                    sampleButton("Y", selected: !appState.blindCurrentIsX) { appState.selectBlindSample(isX: false) }
                    if !appState.blindRevealed {
                        Button(appState.t("ui.eq.reveal")) { appState.revealBlindAB() }.buttonStyle(.t(.secondary, compact: true))
                    }
                    IconButton(symbol: "xmark", size: 24, help: appState.t("ui.eq.stop")) { appState.stopBlindAB() }
                }
                Spacer()
                if appState.blindRevealed {
                    Text(String(format: appState.t("ui.eq.reveal_result"), appState.blindXIsFull ? appState.t("ui.eq.with_eq") : appState.t("ui.eq.without_eq")))
                        .type(TimbreTypography.caption).foregroundStyle(c.ink_secondary)
                }
            }
            Hairline()
            HStack(spacing: 8) {
                Text(appState.t("eq.trainer_title")).type(TimbreTypography.small).fontWeight(.medium).foregroundStyle(c.ink_primary)
                Spacer()
                Text(String(format: appState.t("ui.eq.rounds"), appState.trainerHistory.count))
                    .type(TimbreTypography.monoSmall).foregroundStyle(c.ink_muted)
            }
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
        }
    }

    private func sampleButton(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(.system(size: 13, weight: .semibold, design: .monospaced))
                .frame(width: 34, height: 26)
                .foregroundStyle(selected ? c.ink_inverse : c.ink_primary)
                .background(RoundedRectangle(cornerRadius: TimbreRadius.control, style: .continuous).fill(selected ? c.ink_primary : c.bg_selected))
        }
        .buttonStyle(PressScaleStyle())
    }

    private var assistantPanel: some View {
        panel(appState.t("ui.eq.assistant_title"), appState.t("ui.eq.assistant_sub")) {
            HStack(spacing: 8) {
                TField(placeholder: appState.t("eq.ai_placeholder"), text: $appState.aiPromptText) { appState.submitAIPrompt() }
                Button(appState.t("eq.ai_apply")) { appState.submitAIPrompt() }
                    .buttonStyle(.t(.primary, compact: true))
                    .disabled(appState.aiPromptText.trimmingCharacters(in: .whitespaces).isEmpty)
                if !appState.undoTasteStack.isEmpty {
                    Button(appState.t("ui.undo")) { appState.undoLastAITweak() }.buttonStyle(.t(.ghost, compact: true))
                }
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
            PageHeader(index: appState.t("nav.observatory"), title: appState.t("ui.obs.title"), summary: obsSummary) {
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
            let hasPeak = live && max(t.truePeakL, t.truePeakR) > -70

            TLCDDisplay(
                title: "TRUE PEAK & LUFS RECORDER MONITOR",
                statusText: live ? "LIVE · 4× OVERSAMPLED" : (appState.pathIsNative ? "BIT-PERFECT · 0 TAPS" : "IDLE"),
                isLive: live
            ) {
                VStack(spacing: 10) {
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

                    Hairline()

                    HStack(spacing: 24) {
                        lcdMetric("LUFS · M", live && t.lufsMomentary > -70 ? Fmt.signed(t.lufsMomentary) + " LUFS" : "—")
                        lcdMetric(appState.t("ui.eq.true_peak"), hasPeak ? Fmt.signed(max(t.truePeakL, t.truePeakR)) + " dBTP" : "—")
                        lcdMetric(appState.t("ui.eq.limiter"), live ? (t.limiterActive ? Fmt.db(-abs(t.limiterGR)) + " dB" : "0.0 dB") : "—")
                        lcdMetric(appState.t("ui.obs.clips"), "\(t.clipPreventedCount)")
                        lcdMetric("DSP", live ? String(format: "%.0f µs", t.cpuMicroseconds) : "—")
                        Spacer()
                    }
                    .padding(.top, 2)
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

            ListeningSection(appState: appState, index: appState.driverTelemetry == nil ? "04" : "05")
            TimelineSection(appState: appState, index: appState.driverTelemetry == nil ? "05" : "06")
        }
    }

    private func lcdMetric(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            OriginMark(origin: .measured)
            Eyebrow(text: label)
            Text(value)
                .type(TimbreTypography.monoValue)
                .foregroundStyle(c.ink_primary)
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
                row(appState.t("ui.settings.instant_pause"), appState.t("ui.settings.instant_pause_sub")) {
                    TSwitch(isOn: Binding(get: { appState.instantPauseDetection }, set: { appState.toggleInstantPauseDetection($0) }))
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
                tcc(appState.t("tcc.audio.title"), appState.t("tcc.audio.why"), granted: nil, pane: .systemAudio)
                Hairline().padding(.leading, 20)
                tcc(appState.t("tcc.ax.title"), appState.t("tcc.ax.why"), granted: appState.accessibilityGranted, pane: .accessibility)
                Hairline().padding(.leading, 20)
                tcc(appState.t("tcc.bt.title"), appState.t("tcc.bt.why"), granted: CBCentralManager.authorization == .allowedAlways, pane: .bluetooth)
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
            group("05", appState.t("ui.settings.updates")) {
                row(appState.t("ui.updates.auto"), appState.t("ui.updates.auto_sub")) {
                    TSwitch(isOn: Binding(
                        get: { appState.updater.automaticChecksEnabled },
                        set: { appState.toggleAutoUpdateChecks($0) }
                    ))
                }
                Hairline().padding(.leading, 20)
                UpdateStatusRow(appState: appState)
            }
            group("06", appState.t("ui.settings.data")) {
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

    private func tcc(_ title: String, _ why: String, granted: Bool?, pane: SystemPermission) -> some View {
        row(title, why) {
            HStack(spacing: 10) {
                Badge(text: appState.t(granted == nil ? "tcc.status.check_in_settings" : granted == true ? "tcc.status.ok" : "tcc.status.pending"),
                      tone: granted == nil ? .neutral : granted == true ? .positive : .warning)
                Button(appState.t("tcc.open_settings")) {
                    appState.openSystemSettingsTCC(pane)
                }
                .buttonStyle(.t(.ghost, compact: true))
            }
        }
    }
}

// MARK: - Feedback by e-mail (ADR-0024)

private struct FeedbackSection: View {
    @ObservedObject var appState: AppState
    @Environment(\.palette) private var c

    private func catTitle(_ k: FeedbackCategory) -> String { appState.t("ui.feedback.cat.\(k.rawValue)") }

    var body: some View {
        let count = FeedbackComposer.normalize(appState.feedbackText).count
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(appState.t("ui.feedback.title")).type(TimbreTypography.sectionTitle).foregroundStyle(c.ink_primary)
                Text(appState.t("ui.feedback.sub")).type(TimbreTypography.small).foregroundStyle(c.ink_secondary)
                    .frame(maxWidth: 620, alignment: .leading).fixedSize(horizontal: false, vertical: true)
            }
            TSegmented(options: FeedbackCategory.allCases.map { ($0, catTitle($0)) }, selection: $appState.feedbackCategory)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $appState.feedbackText)
                    .scrollContentBackground(.hidden)
                    .font(.system(size: 13))
                    .foregroundStyle(c.ink_primary)
                    .padding(8)
                if appState.feedbackText.isEmpty {
                    Text(appState.t("ui.feedback.hint.\(appState.feedbackCategory.rawValue)"))
                        .type(TimbreTypography.body).foregroundStyle(c.ink_faint)
                        .padding(.horizontal, 13).padding(.vertical, 8).allowsHitTesting(false)
                }
            }
            .frame(maxWidth: 620).frame(height: 120)
            .background(RoundedRectangle(cornerRadius: TimbreRadius.field, style: .continuous).fill(c.bg_inset))
            .overlay(RoundedRectangle(cornerRadius: TimbreRadius.field, style: .continuous).strokeBorder(c.line_default, lineWidth: 0.5))

            HStack {
                Text(count > 0 && count < FeedbackComposer.minMessageLength ? appState.t("ui.feedback.too_short")
                     : String(format: appState.t("ui.feedback.counter"), count, FeedbackComposer.maxMessageLength))
                    .type(TimbreTypography.monoSmall).foregroundStyle(c.ink_muted)
            }
            .frame(maxWidth: 620, alignment: .trailing)

            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(text: appState.t("ui.feedback.context"))
                ctx("ui.feedback.ctx.app", $appState.feedbackOptions.app)
                ctx("ui.feedback.ctx.system", $appState.feedbackOptions.system)
                ctx("ui.feedback.ctx.output", $appState.feedbackOptions.output)
                ctx("ui.feedback.ctx.equalizer", $appState.feedbackOptions.equalizer)
                ctx("ui.feedback.ctx.language", $appState.feedbackOptions.language)
                Text(appState.t("ui.feedback.never")).type(TimbreTypography.caption).foregroundStyle(c.ink_muted)
            }

            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(text: appState.t("ui.feedback.preview"))
                Text("Para: \(FeedbackComposer.recipient)\nAssunto: \(FeedbackComposer.subject(appState.feedbackCategory))\n\n\(appState.feedbackPreview.isEmpty ? "…" : appState.feedbackPreview)")
                    .type(TimbreTypography.monoSmall).foregroundStyle(c.ink_secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: TimbreRadius.field, style: .continuous).fill(c.bg_surface))
                    .overlay(RoundedRectangle(cornerRadius: TimbreRadius.field, style: .continuous).strokeBorder(c.line_default, lineWidth: 0.5))
            }
            .frame(maxWidth: 620, alignment: .leading)

            HStack(spacing: 10) {
                Button(appState.t("ui.feedback.send")) { appState.sendFeedbackEmail() }
                    .buttonStyle(.t(.primary)).disabled(!appState.feedbackSendable)
                Button(appState.t("ui.feedback.copy")) { appState.copyFeedback() }
                    .buttonStyle(.t(.secondary)).disabled(!appState.feedbackSendable)
                Button(appState.t("ui.feedback.clear")) { appState.clearFeedback() }
                    .buttonStyle(.t(.ghost)).disabled(appState.feedbackText.isEmpty)
                Spacer()
                if let url = URL(string: "https://github.com/v1nometrics/timbr/issues/new") {
                    Button(appState.t("ui.feedback.github")) { NSWorkspace.shared.open(url) }.buttonStyle(.t(.ghost, compact: true))
                }
            }
            .frame(maxWidth: 620)
        }
    }

    private func ctx(_ key: String, _ on: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            TSwitch(isOn: on, label: appState.t(key))
            Text(appState.t(key)).type(TimbreTypography.small).foregroundStyle(c.ink_primary)
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
                TimbrBrandIcon(size: 72)
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("timbr").font(.system(size: 56, weight: .semibold)).tracking(-2.6)
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
                if let remote = appState.updater.availableManifest {
                    Button(appState.updater.canInstallInPlace ? appState.t("ui.updates.prepare") : appState.t("ui.updates.download_dmg")) {
                        appState.updater.downloadAndInstall(remote)
                    }
                    .buttonStyle(.t(.secondary))
                    .disabled(appState.updater.isBusy)
                } else {
                    Button(appState.updater.isBusy ? appState.t("ui.updates.checking") : appState.t("ui.updates.check_now")) {
                        appState.openUpdatesSettings()
                        appState.updater.checkForUpdates(manual: true)
                    }
                    .buttonStyle(.t(.ghost))
                    .disabled(appState.updater.isBusy)
                }
            }
            Hairline()
            FeedbackSection(appState: appState)
            Hairline()
            HStack(spacing: 40) {
                fact(appState.t("ui.about.version"), appState.updater.currentVersion.displayLabel)
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


// MARK: - Updates (ADR-0026)

private struct UpdateProgressBar: View {
    let progress: Double?
    @Environment(\.palette) private var c

    var body: some View {
        GeometryReader { geo in
            let w: CGFloat = geo.size.width
            let fraction: CGFloat = progress.map { CGFloat(min(1.0, max(0.0, $0))) } ?? 0.35
            let fillW: CGFloat = max(6, w * fraction)
            ZStack(alignment: .leading) {
                Capsule().fill(c.bg_inset)
                Capsule()
                    .fill(c.ink_primary)
                    .frame(width: fillW)
            }
        }
        .frame(height: 4)
        .frame(maxWidth: 260)
    }
}

private struct UpdateBannerView: View {
    @ObservedObject var appState: AppState
    @Environment(\.palette) private var c

    var body: some View {
        if let manifest = appState.updater.availableManifest {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Badge(text: appState.t("ui.updates.available_badge"), tone: .info)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(headline(for: manifest))
                            .type(TimbreTypography.body)
                            .fontWeight(.medium)
                            .foregroundStyle(c.ink_primary)
                        if let sub = subtitle(for: manifest) {
                            Text(sub)
                                .type(TimbreTypography.caption)
                                .foregroundStyle(c.ink_muted)
                                .lineLimit(2)
                        }
                    }
                    Spacer(minLength: 12)
                    actions(for: manifest)
                }
                if case .downloading(_, let progress) = appState.updater.status {
                    UpdateProgressBar(progress: progress)
                } else if case .verifying = appState.updater.status {
                    UpdateProgressBar(progress: nil)
                } else if case .installing = appState.updater.status {
                    UpdateProgressBar(progress: 1.0)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: TimbreRadius.card, style: .continuous).fill(c.bg_surface))
            .overlay(RoundedRectangle(cornerRadius: TimbreRadius.card, style: .continuous).strokeBorder(c.line_default, lineWidth: 0.5))
        }
    }

    private func headline(for manifest: UpdateManifest) -> String {
        switch appState.updater.status {
        case .downloading(_, let progress):
            return String(format: appState.t("ui.updates.downloading"), manifest.displayVersion, Int((progress * 100).rounded()))
        case .verifying:
            return appState.t("ui.updates.verifying")
        case .installing:
            return appState.t("ui.updates.installing")
        default:
            return String(format: appState.t("ui.updates.available_title"), manifest.displayVersion)
        }
    }

    private func subtitle(for manifest: UpdateManifest) -> String? {
        if case .available = appState.updater.status {
            if let summary = manifest.summary, !summary.isEmpty { return summary }
            return appState.t("ui.updates.available_sub")
        }
        return nil
    }

    @ViewBuilder
    private func actions(for manifest: UpdateManifest) -> some View {
        switch appState.updater.status {
        case .downloading:
            Button(appState.t("ui.updates.cancel")) { appState.updater.cancelDownload() }
                .buttonStyle(.t(.ghost, compact: true))
        case .verifying, .installing:
            EmptyView()
        default:
            HStack(spacing: 8) {
                Button(appState.updater.canInstallInPlace ? appState.t("ui.updates.prepare") : appState.t("ui.updates.download_dmg")) {
                    appState.updater.downloadAndInstall(manifest)
                }
                .buttonStyle(.t(.primary, compact: true))
                Button(appState.t("ui.updates.view_notes")) {
                    appState.updater.openReleaseNotes(manifest)
                }
                .buttonStyle(.t(.ghost, compact: true))
                Button {
                    appState.updater.dismissBanner()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(c.ink_muted)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct UpdateStatusRow: View {
    @ObservedObject var appState: AppState
    @Environment(\.palette) private var c

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(appState.t("ui.updates.current"))
                            .type(TimbreTypography.body)
                            .foregroundStyle(c.ink_primary)
                        Text(appState.updater.currentVersion.displayLabel)
                            .type(TimbreTypography.monoSmall)
                            .foregroundStyle(c.ink_secondary)
                        statusBadge
                    }
                    Text(statusDetail)
                        .type(TimbreTypography.caption)
                        .foregroundStyle(c.ink_muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 16)
                trailingActions
            }

            if case .downloading(_, let progress) = appState.updater.status {
                UpdateProgressBar(progress: progress)
            } else if case .verifying = appState.updater.status {
                UpdateProgressBar(progress: nil)
            } else if case .installing = appState.updater.status {
                UpdateProgressBar(progress: 1.0)
            }

            if appState.updater.hasActionableUpdate {
                Text(appState.t("ui.updates.tcc_note"))
                    .type(TimbreTypography.caption)
                    .foregroundStyle(c.ink_muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(minHeight: 54)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch appState.updater.status {
        case .available, .downloading, .verifying, .installing:
            Badge(text: appState.t("ui.updates.available_badge"), tone: .info)
        case .upToDate:
            Badge(text: appState.t("tcc.status.ok"), tone: .positive)
        case .unsupportedOS, .failed:
            Badge(text: "!", tone: .warning, dot: false)
        default:
            EmptyView()
        }
    }

    private var statusDetail: String {
        switch appState.updater.status {
        case .idle:
            return appState.t("ui.updates.up_to_date")
        case .checking:
            return appState.t("ui.updates.checking")
        case .upToDate:
            return appState.t("ui.updates.up_to_date")
        case .available(let m):
            let title = String(format: appState.t("ui.updates.available_title"), m.displayVersion)
            if let summary = m.summary, !summary.isEmpty {
                return "\(title) — \(summary)"
            }
            return title
        case .downloading(let m, let progress):
            return String(format: appState.t("ui.updates.downloading"), m.displayVersion, Int((progress * 100).rounded()))
        case .verifying:
            return appState.t("ui.updates.verifying")
        case .installing:
            return appState.t("ui.updates.installing")
        case .downloadedToFolder(_, let fileURL):
            return String(format: appState.t("ui.updates.downloaded_folder"), fileURL.lastPathComponent)
        case .unsupportedOS(let required):
            return String(format: appState.t("ui.updates.unsupported_os"), required)
        case .failed(let message):
            return String(format: appState.t("ui.updates.failed"), message)
        }
    }

    @ViewBuilder
    private var trailingActions: some View {
        switch appState.updater.status {
        case .available(let m):
            HStack(spacing: 8) {
                Button(appState.updater.canInstallInPlace ? appState.t("ui.updates.prepare") : appState.t("ui.updates.download_dmg")) {
                    appState.updater.downloadAndInstall(m)
                }
                .buttonStyle(.t(.primary, compact: true))
                Button(appState.t("ui.updates.view_notes")) {
                    appState.updater.openReleaseNotes(m)
                }
                .buttonStyle(.t(.ghost, compact: true))
                Button(appState.t("ui.updates.skip")) {
                    appState.updater.skipUpdate(m)
                }
                .buttonStyle(.t(.ghost, compact: true))
            }
        case .downloading:
            Button(appState.t("ui.updates.cancel")) {
                appState.updater.cancelDownload()
            }
            .buttonStyle(.t(.ghost, compact: true))
        case .verifying, .installing:
            EmptyView()
        case .downloadedToFolder(_, let fileURL):
            Button(appState.t("ui.updates.open_dmg")) { NSWorkspace.shared.open(fileURL) }
                .buttonStyle(.t(.secondary, compact: true))
        default:
            Button(appState.updater.isBusy ? appState.t("ui.updates.checking") : appState.t("ui.updates.check_now")) {
                appState.updater.checkForUpdates(manual: true)
            }
            .buttonStyle(.t(.secondary, compact: true))
            .disabled(appState.updater.isBusy)
        }
    }
}
