// SPDX-License-Identifier: MPL-2.0
import SwiftUI
import AppKit
import TimbreCore
import TimbreEngine
import TimbreDesignSystem

public struct StudioWindow: View {
    @ObservedObject var appState: AppState
    @Environment(\.colorScheme) private var systemScheme

    public init(appState: AppState) {
        self.appState = appState
    }

    private var colors: TimbreColors {
        if appState.useLightSurface { return .light }
        return systemScheme == .light ? .light : .dark
    }

    public var body: some View {
        NavigationSplitView {
            List(StudioTab.allCases, selection: $appState.selectedTab) { tab in
                Label(tabTitle(tab), systemImage: tabIcon(tab))
                    .font(TimbreTypography.body.font)
                    .tag(tab)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 185, ideal: 205, max: 230)
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: TimbreSpacing.s1) {
                    Text(appState.language.tagline)
                        .font(TimbreTypography.caption.font)
                        .foregroundStyle(colors.ink_secondary)
                    HStack(spacing: TimbreSpacing.s1) {
                        Circle()
                            .fill(appState.isProcessingBypassed ? colors.ink_muted : colors.semantic_positive)
                            .frame(width: 7, height: 7)
                        Text(appState.activeTapsCount == 0 ? appState.t("mixer.no_taps") : "Tap ativo (\(appState.activeTapsCount))")
                            .font(TimbreTypography.micro.font)
                            .foregroundStyle(colors.ink_muted)
                    }
                }
                .padding(TimbreSpacing.s3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(colors.bg_track)
            }
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: TimbreSpacing.s5) {
                    if let banner = appState.statusBanner {
                        HStack {
                            Text(banner)
                                .font(TimbreTypography.small.font)
                                .foregroundStyle(colors.semantic_warning)
                            Spacer()
                            Button("×") { appState.statusBanner = nil }
                                .buttonStyle(.plain)
                        }
                        .padding(TimbreSpacing.s3)
                        .background(colors.bg_raised)
                        .clipShape(RoundedRectangle(cornerRadius: TimbreRadius.control))
                    }

                    switch appState.selectedTab {
                    case .mixer:
                        mixerSection
                    case .equalizer:
                        equalizerSection
                    case .observatory:
                        observatorySection
                    case .settings:
                        settingsSection
                    case .support:
                        supportSection
                    }
                }
                .padding(TimbreSpacing.s6)
            }
            .background(colors.bg_canvas)
        }
        .frame(minWidth: 920, minHeight: 620)
        .tint(colors.accent_base)
    }

    private func tabTitle(_ tab: StudioTab) -> String {
        switch tab {
        case .mixer: return appState.t("nav.mixer")
        case .equalizer: return appState.t("nav.eq")
        case .observatory: return appState.t("nav.observatory")
        case .settings: return appState.t("nav.settings")
        case .support: return appState.t("nav.support")
        }
    }

    private func tabIcon(_ tab: StudioTab) -> String {
        switch tab {
        case .mixer: return "slider.horizontal.3"
        case .equalizer: return "waveform.path.ecg"
        case .observatory: return "shield.lefthalf.filled"
        case .settings: return "gearshape"
        case .support: return "heart"
        }
    }

    // MARK: - 1. Mixer
    private var mixerSection: some View {
        VStack(alignment: .leading, spacing: TimbreSpacing.s5) {
            HStack {
                Text(appState.t("nav.mixer"))
                    .font(TimbreTypography.heroTitle.font)
                    .foregroundStyle(colors.ink_primary)
                Spacer()
                Button(appState.isProcessingBypassed ? appState.t("notch.bypass") : "DSP ON") {
                    appState.toggleBypass()
                }
                .buttonStyle(.borderedProminent)
                .tint(appState.isProcessingBypassed ? colors.ink_muted : colors.accent_base)
            }

            // Sources Card
            card(title: appState.t("mixer.title")) {
                if appState.sources.isEmpty {
                    Text(appState.t("mixer.no_taps"))
                        .font(TimbreTypography.body.font)
                        .foregroundStyle(colors.ink_muted)
                } else {
                    ForEach(appState.sources) { src in
                        HStack(spacing: TimbreSpacing.s3) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(src.name)
                                    .font(TimbreTypography.body.font)
                                    .foregroundStyle(colors.ink_primary)
                                Text(src.bundleID)
                                    .font(TimbreTypography.micro.font)
                                    .foregroundStyle(colors.ink_muted)
                            }
                            .frame(width: 210, alignment: .leading)

                            if src.isVoIPExcluded {
                                badge(appState.t("mixer.voip_ignored"), color: colors.semantic_info)
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
                                    .foregroundStyle(src.volume > 1.0 ? colors.semantic_warning : colors.ink_secondary)
                                    .frame(width: 52, alignment: .trailing)

                                if src.volume > 1.0 {
                                    badge(appState.t("mixer.boost_warning"), color: colors.semantic_warning)
                                }

                                Button(src.isMuted ? "Unmute" : "Mute") {
                                    appState.toggleSourceMute(bundleID: src.bundleID)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        Divider().background(colors.line_subtle)
                    }
                }

                // Browser Tab Audio Updates via Extension IPC (Bidirectional)
                if !appState.tabUpdates.isEmpty {
                    Text("Browser Tabs (Extension IPC)")
                        .font(TimbreTypography.small.font)
                        .foregroundStyle(colors.ink_secondary)
                        .padding(.top, TimbreSpacing.s2)
                    ForEach(appState.tabUpdates, id: \.tabID) { tab in
                        HStack(spacing: TimbreSpacing.s3) {
                            Text("[\(tab.browser)] \(tab.title)")
                                .font(TimbreTypography.small.font)
                                .foregroundStyle(colors.ink_primary)
                                .lineLimit(1)
                                .frame(width: 210, alignment: .leading)
                            Slider(
                                value: Binding(
                                    get: { tab.volume },
                                    set: { appState.setTabVolume(browser: tab.browser, tabID: tab.tabID, volume: $0) }
                                ),
                                in: 0...2.0
                            )
                            Text(tab.isMuted ? "MUTE" : "\(Int((tab.volume * 100).rounded()))%")
                                .font(TimbreTypography.monoValue.font)
                                .foregroundStyle(colors.ink_secondary)
                                .frame(width: 52, alignment: .trailing)
                            Button(tab.isMuted ? "Unmute" : "Mute") {
                                appState.toggleTabMute(browser: tab.browser, tabID: tab.tabID)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                } else {
                    Text(appState.t("mixer.tabs_note"))
                        .font(TimbreTypography.caption.font)
                        .foregroundStyle(colors.ink_muted)
                }
            }

            // Outputs Card
            card(title: appState.t("mixer.destinations")) {
                ForEach(appState.outputDevices) { dev in
                    HStack(spacing: TimbreSpacing.s3) {
                        Button {
                            appState.selectDefaultOutput(dev)
                        } label: {
                            Image(systemName: dev.isDefaultOutput ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(dev.isDefaultOutput ? colors.accent_base : colors.ink_muted)
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(dev.name)
                                .font(TimbreTypography.body.font)
                                .foregroundStyle(colors.ink_primary)
                            HStack(spacing: TimbreSpacing.s2) {
                                Text("\(Int(dev.sampleRate)) Hz")
                                    .font(TimbreTypography.monoValue.font)
                                    .foregroundStyle(colors.ink_secondary)
                                badge(
                                    dev.supportsAnyHWVolume ? appState.t("dev.hw_volume") : appState.t("dev.sw_volume"),
                                    color: dev.supportsAnyHWVolume ? colors.semantic_positive : colors.semantic_warning
                                )
                                if dev.name.localizedCaseInsensitiveContains("MOMENTUM 4") {
                                    let imp = dev.analogImpedanceMode ?? .active470Ohm
                                    Button(imp == .active470Ohm ? appState.t("dev.m4.p2_active") : appState.t("dev.m4.p2_passive")) {
                                        appState.toggleMomentum4Impedance()
                                    }
                                    .buttonStyle(.bordered)
                                    .font(TimbreTypography.micro.font)
                                }
                            }
                        }
                        Spacer()
                        if dev.isHWVolumeMasterSettable || dev.isHWVolumeChannelSettable {
                            let vol = Double(appState.halManager.readOutputVolumeScalar(deviceID: dev.audioObjectID) ?? 0.5)
                            Slider(
                                value: Binding(
                                    get: { vol },
                                    set: { appState.setOutputVolume(dev, value: $0) }
                                ),
                                in: 0...1.0
                            )
                            .frame(width: 150)
                            Text("\(Int((vol * 100).rounded()))%")
                                .font(TimbreTypography.monoValue.font)
                                .foregroundStyle(colors.ink_secondary)
                                .frame(width: 44, alignment: .trailing)
                        }
                        if !dev.isDefaultOutput {
                            let isMirrored = appState.mirrorOutputUIDs.contains(dev.uid)
                            Toggle("Mirror", isOn: Binding(
                                get: { isMirrored },
                                set: { _ in appState.toggleMirrorOutput(dev) }
                            ))
                            .toggleStyle(.checkbox)
                            if isMirrored {
                                let dMs = appState.outputDelaysMs[dev.uid] ?? 0.0
                                Slider(
                                    value: Binding(
                                        get: { dMs },
                                        set: { appState.setOutputDelay(dev, delayMs: $0) }
                                    ),
                                    in: 0...250,
                                    step: 1
                                )
                                .frame(width: 90)
                                Text("\(Int(dMs.rounded())) ms")
                                    .font(TimbreTypography.monoValue.font)
                                    .foregroundStyle(colors.ink_muted)
                                    .frame(width: 46, alignment: .trailing)
                            }
                        }
                    }
                    Divider().background(colors.line_subtle)
                }
            }
        }
    }

    // MARK: - 2. Equalizer
    private var equalizerSection: some View {
        VStack(alignment: .leading, spacing: TimbreSpacing.s5) {
            HStack {
                Text(appState.t("nav.eq"))
                    .font(TimbreTypography.heroTitle.font)
                    .foregroundStyle(colors.ink_primary)
                Spacer()
                Picker("", selection: Binding(
                    get: { appState.activePreset.useAdvancedPEQ },
                    set: { appState.toggleAdvancedPEQ($0) }
                )) {
                    Text(appState.t("eq.mode.simple")).tag(false)
                    Text(appState.t("eq.mode.advanced")).tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 220)

                Button(appState.t("eq.import_apo")) { appState.importEqualizerAPOFromPanel() }
                Button(appState.t("eq.export_apo")) { appState.exportEqualizerAPOToPanel() }
                Button("Save Preset") { appState.saveCurrentPreset() }
                    .buttonStyle(.borderedProminent)
                    .tint(colors.accent_base)
            }

            // Curve Plot
            EQCurveCanvas(appState: appState, colors: colors)

            // Legend + Metrology strip
            HStack(spacing: TimbreSpacing.s4) {
                legendDot(appState.t("eq.layer.correction"), color: colors.semantic_info)
                legendDot(appState.t("eq.layer.taste"), color: colors.accent_strong)
                legendDot(appState.t("eq.layer.result"), color: colors.accent_base)
                Spacer()
                Text("\(appState.t("eq.preamp")): \(String(format: "%.1f dB", appState.telemetry.preampDB))")
                    .font(TimbreTypography.monoValue.font)
                    .foregroundStyle(colors.ink_secondary)
                Toggle(appState.t("eq.crossfeed"), isOn: Binding(
                    get: { appState.activePreset.crossfeedEnabled },
                    set: { appState.activePreset.crossfeedEnabled = $0; appState.syncDSPAndTap() }
                ))
                .toggleStyle(.switch)
            }

            // Simple OR Free PEQ Editor
            if !appState.activePreset.useAdvancedPEQ {
                card(title: appState.t("eq.mode.simple")) {
                    simpleSlider(appState.t("eq.taste.bass"), value: Binding(
                        get: { appState.activePreset.simpleTaste.bassDB },
                        set: { var st = appState.activePreset.simpleTaste; st.bassDB = SimpleTasteControls.clampStep($0); appState.updateSimpleTaste(st) }
                    ))
                    simpleSlider(appState.t("eq.taste.warmth"), value: Binding(
                        get: { appState.activePreset.simpleTaste.warmthDB },
                        set: { var st = appState.activePreset.simpleTaste; st.warmthDB = SimpleTasteControls.clampStep($0); appState.updateSimpleTaste(st) }
                    ))
                    simpleSlider(appState.t("eq.taste.presence"), value: Binding(
                        get: { appState.activePreset.simpleTaste.presenceDB },
                        set: { var st = appState.activePreset.simpleTaste; st.presenceDB = SimpleTasteControls.clampStep($0); appState.updateSimpleTaste(st) }
                    ))
                    simpleSlider(appState.t("eq.taste.air"), value: Binding(
                        get: { appState.activePreset.simpleTaste.airDB },
                        set: { var st = appState.activePreset.simpleTaste; st.airDB = SimpleTasteControls.clampStep($0); appState.updateSimpleTaste(st) }
                    ))
                }
            } else {
                card(title: appState.t("eq.mode.advanced")) {
                    HStack {
                        Button("+ Band") { appState.addTasteBand() }
                        Spacer()
                        Text("Vicanek / RBJ Float64")
                            .font(TimbreTypography.micro.font)
                            .foregroundStyle(colors.ink_muted)
                    }
                    ForEach(appState.activePreset.tasteBands) { band in
                        HStack(spacing: TimbreSpacing.s2) {
                            Toggle("", isOn: Binding(
                                get: { band.enabled },
                                set: { var b = band; b.enabled = $0; appState.updateTasteBand(b) }
                            ))
                            .labelsHidden()

                            Picker("", selection: Binding(
                                get: { band.type },
                                set: { var b = band; b.type = $0; appState.updateTasteBand(b) }
                            )) {
                                ForEach([EQFilterType.peak, .lowShelf, .highShelf, .lowPass, .highPass], id: \.self) { ft in
                                    Text(ft.rawValue).tag(ft)
                                }
                            }
                            .frame(width: 96)

                            Text("\(Int(band.freqHz)) Hz")
                                .font(TimbreTypography.monoValue.font)
                                .frame(width: 72, alignment: .trailing)
                            Slider(value: Binding(
                                get: { log10(band.freqHz) },
                                set: { var b = band; b.freqHz = pow(10.0, $0); appState.updateTasteBand(b) }
                            ), in: log10(20.0)...log10(20000.0))

                            Text(String(format: "%+.1f dB", band.gainDB))
                                .font(TimbreTypography.monoValue.font)
                                .frame(width: 68, alignment: .trailing)
                            Slider(value: Binding(
                                get: { band.gainDB },
                                set: { var b = band; b.gainDB = ($0 * 2).rounded() / 2; appState.updateTasteBand(b) }
                            ), in: -15...15)

                            Text(String(format: "Q %.2f", band.q))
                                .font(TimbreTypography.monoValue.font)
                                .frame(width: 56, alignment: .trailing)
                            Slider(value: Binding(
                                get: { band.q },
                                set: { var b = band; b.q = ($0 * 10).rounded() / 10; appState.updateTasteBand(b) }
                            ), in: 0.3...10.0)
                            .frame(width: 80)

                            Button("×") { appState.removeTasteBand(id: band.id) }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }

            // AutoEq Catalog + AI Assistant + Blind A/B + Bayesian Taste Trainer
            HStack(alignment: .top, spacing: TimbreSpacing.s4) {
                card(title: "AutoEq") {
                    if let meta = appState.activePreset.correctionMetadata {
                        HStack {
                            Text("\(meta.headphoneModel) (\(meta.sourceCredit))")
                                .font(TimbreTypography.small.font)
                                .foregroundStyle(colors.semantic_info)
                            Spacer()
                            Button("Clear") { appState.clearCorrection() }
                        }
                    }
                    let matches = AutoEqService.matchDeviceName(appState.activeOutputDevice?.name ?? "Sennheiser MOMENTUM 4")
                    ForEach(matches.prefix(4)) { entry in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(entry.headphoneName).font(TimbreTypography.small.font)
                                Text("\(entry.source) · \(entry.rig) · \(entry.target)")
                                    .font(TimbreTypography.micro.font)
                                    .foregroundStyle(colors.ink_muted)
                            }
                            Spacer()
                            Button("Apply") { appState.applyAutoEqEntry(entry) }
                        }
                    }
                }

                card(title: appState.t("eq.blind_ab")) {
                    if !appState.blindABActive {
                        Button(appState.t("eq.blind_ab")) { appState.startBlindAB() }
                            .buttonStyle(.borderedProminent)
                            .tint(colors.accent_base)
                    } else {
                        HStack {
                            Button("Sample X") { appState.selectBlindSample(isX: true) }
                                .buttonStyle(.borderedProminent)
                                .tint(appState.blindCurrentIsX ? colors.accent_base : colors.ink_muted)
                            Button("Sample Y") { appState.selectBlindSample(isX: false) }
                                .buttonStyle(.borderedProminent)
                                .tint(!appState.blindCurrentIsX ? colors.accent_base : colors.ink_muted)
                            Button("Reveal") { appState.revealBlindAB() }
                            Button("Stop") { appState.stopBlindAB() }
                        }
                        if appState.blindRevealed {
                            Text("X = \(appState.blindXIsFull ? "EQ Full" : "Bypass"), Y = \(appState.blindXIsFull ? "Bypass" : "EQ Full")")
                                .font(TimbreTypography.monoValue.font)
                                .foregroundStyle(colors.semantic_positive)
                        }
                    }

                    Divider().background(colors.line_subtle)

                    Text(appState.t("eq.trainer_title"))
                        .font(TimbreTypography.small.font)
                        .foregroundStyle(colors.ink_primary)
                    HStack {
                        Button("Listen A") { appState.auditionTrainerCandidate(isB: false) }
                        Button("Listen B") { appState.auditionTrainerCandidate(isB: true) }
                        Button("Prefer A") { appState.voteTrainerWinner(isA: true) }
                            .buttonStyle(.borderedProminent)
                            .tint(colors.accent_base)
                        Button("Prefer B") { appState.voteTrainerWinner(isA: false) }
                            .buttonStyle(.borderedProminent)
                            .tint(colors.accent_base)
                    }
                    Text("Rounds: \(appState.trainerHistory.count)")
                        .font(TimbreTypography.micro.font)
                        .foregroundStyle(colors.ink_muted)
                }
            }

            // AI Assistant Bar ("AI proposes, DSP decides")
            card(title: "AI EQ Assistant (Local Safety Bounds)") {
                HStack {
                    TextField(appState.t("eq.ai_placeholder"), text: $appState.aiPromptText)
                        .textFieldStyle(.roundedBorder)
                    Button(appState.t("eq.ai_apply")) { appState.submitAIPrompt() }
                        .buttonStyle(.borderedProminent)
                        .tint(colors.accent_base)
                    if !appState.undoTasteStack.isEmpty {
                        Button("Undo") { appState.undoLastAITweak() }
                    }
                }
                if !appState.aiStatusMessage.isEmpty {
                    Text(appState.aiStatusMessage)
                        .font(TimbreTypography.micro.font)
                        .foregroundStyle(colors.ink_muted)
                }
                HStack(spacing: TimbreSpacing.s3) {
                    ForEach(appState.aiProposals) { prop in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(prop.label).font(TimbreTypography.small.font)
                            Text(prop.rationale).font(TimbreTypography.micro.font).foregroundStyle(colors.ink_muted)
                            Button("Apply (\(prop.operations.count) ops)") { appState.applyAIProposal(prop) }
                                .buttonStyle(.bordered)
                        }
                        .padding(TimbreSpacing.s2)
                        .background(colors.bg_track)
                        .clipShape(RoundedRectangle(cornerRadius: TimbreRadius.control))
                    }
                }
            }
        }
    }

    // MARK: - 3. Observatory & Guardian
    private var observatorySection: some View {
        VStack(alignment: .leading, spacing: TimbreSpacing.s5) {
            HStack {
                Text(appState.t("nav.observatory"))
                    .font(TimbreTypography.heroTitle.font)
                    .foregroundStyle(colors.ink_primary)
                Spacer()
                Toggle(appState.t("guard.silent_studio"), isOn: Binding(
                    get: { appState.silentStudioMode },
                    set: { appState.toggleSilentStudio($0) }
                ))
                .toggleStyle(.switch)
            }

            // Signal Chain horizontal
            card(title: "Signal Chain") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: TimbreSpacing.s2) {
                        stagePill(appState.t("obs.stage.sources"), sub: "\(appState.sources.count) apps", badgeText: appState.t("obs.badge.measured"), color: colors.semantic_positive)
                        Text("→").foregroundStyle(colors.ink_muted)
                        stagePill(appState.t("obs.stage.mixer"), sub: appState.activeTapsCount == 0 ? "0 taps" : "ProcessTap", badgeText: appState.activeTapsCount == 0 ? appState.t("obs.badge.bitperfect") : appState.t("obs.badge.measured"), color: colors.semantic_info)
                        Text("→").foregroundStyle(colors.ink_muted)
                        stagePill(appState.t("obs.stage.correction"), sub: "\(appState.activePreset.correctionBands.count) b", badgeText: appState.t("obs.badge.measured"), color: colors.semantic_positive)
                        Text("→").foregroundStyle(colors.ink_muted)
                        stagePill(appState.t("obs.stage.taste"), sub: "\(appState.activePreset.effectiveTasteBands.count) b", badgeText: appState.t("obs.badge.measured"), color: colors.semantic_positive)
                        Text("→").foregroundStyle(colors.ink_muted)
                        stagePill(appState.t("obs.stage.protection"), sub: String(format: "%.1f dBTP", appState.activePreset.limiterCeilingDBTP), badgeText: appState.t("obs.badge.measured"), color: colors.semantic_positive)
                        Text("→").foregroundStyle(colors.ink_muted)
                        stagePill(appState.t("obs.stage.device"), sub: appState.activeOutputDevice?.name ?? "—", badgeText: appState.t("obs.badge.reported"), color: colors.accent_base)
                        Text("→").foregroundStyle(colors.ink_muted)
                        stagePill(appState.t("obs.stage.headphone"), sub: appState.driverTelemetry?.reportedCodec ?? "Generic", badgeText: appState.t("obs.badge.inferred"), color: colors.semantic_warning)
                    }
                }
            }

            // Telemetry Metrology Grid
            HStack(spacing: TimbreSpacing.s3) {
                metricBox("LUFS (M)", value: String(format: "%.1f", appState.telemetry.lufsMomentary))
                metricBox("True-Peak L/R", value: String(format: "%.1f / %.1f", appState.telemetry.truePeakL, appState.telemetry.truePeakR))
                metricBox("Limiter GR", value: String(format: "%.1f dB", appState.telemetry.limiterGR))
                metricBox("Clips Prevented", value: "\(appState.telemetry.clipPreventedCount)")
                metricBox("DSP CPU", value: String(format: "%.1f µs", appState.telemetry.cpuMicroseconds))
            }

            // Driver Telemetry Card
            if let drv = appState.driverTelemetry {
                card(title: drv.driverName) {
                    HStack(spacing: TimbreSpacing.s3) {
                        Text("Status: \(drv.connectionStatus)").font(TimbreTypography.small.font)
                        if let codec = drv.reportedCodec {
                            badge(codec, color: colors.semantic_info)
                        }
                        if let bat = drv.batteryPercent {
                            badge("\(appState.t("dev.m4.battery")): \(bat)%", color: bat < 20 ? colors.semantic_warning : colors.semantic_positive)
                        }
                        if let anc = drv.ancEnabled {
                            badge(anc ? appState.t("dev.m4.anc_on") : appState.t("dev.m4.anc_off"), color: colors.ink_secondary)
                        }
                        if let tr = drv.transparencyPercent {
                            badge("\(appState.t("dev.m4.transparency")): \(tr)%", color: colors.ink_secondary)
                        }
                        if drv.internalEQNonFlat == true {
                            badge(appState.t("dev.m4.eq_non_flat"), color: colors.semantic_warning)
                        }
                        badge(appState.t("dev.m4.read_only"), color: colors.ink_muted)
                        Spacer()
                        if drv.driverName.contains("Momentum 4") {
                            Button(appState.t("dev.m4.refresh")) {
                                appState.refreshHardwareTelemetryNow()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }

            // Guardian Alerts
            card(title: "Guardian") {
                if appState.guardianAlerts.isEmpty {
                    Text(appState.t("obs.clean_chain"))
                        .font(TimbreTypography.body.font)
                        .foregroundStyle(colors.semantic_positive)
                } else {
                    ForEach(appState.guardianAlerts) { alert in
                        HStack {
                            Circle()
                                .fill(alert.severity == .warning ? colors.semantic_warning : colors.semantic_info)
                                .frame(width: 8, height: 8)
                            VStack(alignment: .leading) {
                                Text(appState.t(alert.titleKey)).font(TimbreTypography.body.font)
                                Text(alert.detail).font(TimbreTypography.caption.font).foregroundStyle(colors.ink_muted)
                            }
                            Spacer()
                            if let act = alert.suggestedActionKey {
                                Button(appState.t(act)) { appState.runGuardianAction(alert) }
                                    .buttonStyle(.borderedProminent)
                                    .tint(colors.accent_base)
                            }
                            Button(appState.t("guard.action.ignore_pair")) { appState.silenceGuardianPair(alert) }
                                .buttonStyle(.bordered)
                        }
                        Divider().background(colors.line_subtle)
                    }
                }
            }

            // Timeline
            card(title: "Observatory Timeline") {
                ForEach(appState.recentEvents.prefix(15)) { ev in
                    HStack {
                        Text(ev.timestamp.formatted(date: .omitted, time: .standard))
                            .font(TimbreTypography.monoValue.font)
                            .foregroundStyle(colors.ink_muted)
                        Text("[\(ev.category)]")
                            .font(TimbreTypography.monoValue.font)
                            .foregroundStyle(colors.accent_base)
                        Text(ev.message)
                            .font(TimbreTypography.small.font)
                            .foregroundStyle(colors.ink_primary)
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - 4. Settings
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: TimbreSpacing.s5) {
            Text(appState.t("nav.settings"))
                .font(TimbreTypography.heroTitle.font)
                .foregroundStyle(colors.ink_primary)

            card(title: "Language & Surface") {
                Picker("Language", selection: $appState.language) {
                    ForEach(TimbreLanguage.allCases, id: \.self) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Light Studio Surface", isOn: $appState.useLightSurface)
                Toggle("Notch Overlay Enabled", isOn: $appState.notchEnabled)
                Toggle("Compact Activity Ears", isOn: Binding(
                    get: { appState.showCompactActivity },
                    set: { appState.toggleShowCompact($0) }
                ))
                Toggle(appState.t("notch.menu_only_badge"), isOn: $appState.menuBarOnlyMode)
                Toggle(appState.t("mixer.auto_duck"), isOn: Binding(
                    get: { appState.autoDuckOnCall },
                    set: { appState.toggleAutoDuck($0) }
                ))

                if !appState.competingNotchApps.isEmpty {
                    HStack {
                        badge("Competing notch: \(appState.competingNotchApps.joined(separator: ", "))", color: colors.semantic_warning)
                        Button("Use Menu Bar Only") { appState.menuBarOnlyMode = true }
                    }
                }
            }

            card(title: "Permissions (Pre-TCC Privacy)") {
                tccRow(title: "Audio Capture", detail: appState.t("tcc.audio.why"), granted: !appState.tapEngine.tccAudioCaptureDeniedOrZeroed, pane: "audio")
                tccRow(title: "Accessibility (Media Keys)", detail: appState.t("tcc.ax.why"), granted: appState.accessibilityGranted, pane: "accessibility")
                tccRow(title: "Bluetooth (Momentum 4)", detail: appState.t("tcc.bt.why"), granted: true, pane: "bluetooth")
            }

            card(title: "Browser Extension IPC & Diagnostics") {
                HStack {
                    Text("Localhost 127.0.0.1:48192 (\(appState.ipcPortActive ? "Active" : "Inactive"))")
                        .font(TimbreTypography.monoValue.font)
                    Spacer()
                    Button("Copy Pairing Token") {
                        if let tok = appState.ipcServer?.sessionToken {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(tok, forType: .string)
                        }
                    }
                }
                HStack {
                    Button("Export Sanitized Diagnostics (JSON)") { appState.exportSanitizedDiagnostics() }
                    Button("Clear Local History", role: .destructive) { appState.clearAllLocalHistory() }
                }
            }
        }
    }

    // MARK: - 5. Support & Donations
    private var supportSection: some View {
        VStack(alignment: .leading, spacing: TimbreSpacing.s5) {
            Text(appState.t("support.title"))
                .font(TimbreTypography.heroTitle.font)
                .foregroundStyle(colors.ink_primary)

            card(title: appState.t("support.license")) {
                Text(appState.t("support.body"))
                    .font(TimbreTypography.prose.font)
                    .foregroundStyle(colors.ink_secondary)

                HStack(spacing: TimbreSpacing.s3) {
                    if let ghURL = URL(string: "https://github.com/v1nometrics/timbr") {
                        Link("GitHub Repository (MPL-2.0)", destination: ghURL)
                            .buttonStyle(.borderedProminent)
                            .tint(colors.accent_base)
                    }
                    if let sponsorURL = URL(string: "https://github.com/sponsors/v1nometrics") {
                        Link("GitHub Sponsors", destination: sponsorURL)
                            .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    // MARK: - Helpers
    private func card<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: TimbreSpacing.s3) {
            Text(title)
                .font(TimbreTypography.cardTitle.font)
                .foregroundStyle(colors.ink_primary)
            content()
        }
        .padding(TimbreSpacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colors.bg_surface)
        .clipShape(RoundedRectangle(cornerRadius: TimbreRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TimbreRadius.card, style: .continuous)
                .stroke(colors.line_default, lineWidth: 1)
        )
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(TimbreTypography.micro.font)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.16))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: TimbreRadius.badge))
    }

    private func legendDot(_ label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(TimbreTypography.caption.font).foregroundStyle(colors.ink_secondary)
        }
    }

    private func simpleSlider(_ label: String, value: Binding<Double>) -> some View {
        HStack {
            Text(label).font(TimbreTypography.body.font).frame(width: 110, alignment: .leading)
            Slider(value: value, in: -6.0...6.0, step: 0.5)
            Text(String(format: "%+.1f dB", value.wrappedValue))
                .font(TimbreTypography.monoValue.font)
                .frame(width: 72, alignment: .trailing)
        }
    }

    private func stagePill(_ title: String, sub: String, badgeText: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(TimbreTypography.small.font).foregroundStyle(colors.ink_primary)
            Text(sub).font(TimbreTypography.micro.font).foregroundStyle(colors.ink_muted).lineLimit(1)
            badge(badgeText, color: color)
        }
        .padding(TimbreSpacing.s2)
        .frame(minWidth: 108, alignment: .leading)
        .background(colors.bg_track)
        .clipShape(RoundedRectangle(cornerRadius: TimbreRadius.control))
    }

    private func metricBox(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(TimbreTypography.caption.font).foregroundStyle(colors.ink_muted)
            Text(value).font(TimbreTypography.mediumValue.font).foregroundStyle(colors.ink_primary)
        }
        .padding(TimbreSpacing.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colors.bg_surface)
        .clipShape(RoundedRectangle(cornerRadius: TimbreRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: TimbreRadius.card)
                .stroke(colors.line_default, lineWidth: 1)
        )
    }

    private func tccRow(title: String, detail: String, granted: Bool, pane: String) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title).font(TimbreTypography.body.font)
                    badge(granted ? "OK" : "Pending", color: granted ? colors.semantic_positive : colors.semantic_warning)
                }
                Text(detail).font(TimbreTypography.caption.font).foregroundStyle(colors.ink_muted)
            }
            Spacer()
            Button("System Settings") { appState.openSystemSettingsTCC(pane) }
        }
    }
}
