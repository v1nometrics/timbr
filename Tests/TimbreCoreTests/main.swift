// SPDX-License-Identifier: MPL-2.0
import Foundation
import TimbreCore

func expect(_ condition: @autoclosure () -> Bool, _ msg: String) {
    if !condition() {
        fputs("FAIL: \(msg)\n", stderr)
        exit(1)
    }
}

@main
struct TimbreCoreTestRunner {
    static func main() async {
        print("[TimbreCoreTests] Running core unit & security tests...")

        // 1. EqualizerAPO parser + negative/fuzz bounds
        let validAPO = """
        Preamp: -4.2 dB
        Filter 1: ON PK Fc 100 Hz Gain -3.5 dB Q 1.41
        Filter 2: ON LSC Fc 105 Hz Gain +2.0 dB Q 0.70
        Filter 3: OFF PK Fc 5000 Hz Gain +4.0 dB Q 2.0
        """
        let parsed = try! EqualizerAPOParser.parse(validAPO, layer: .correction)
        expect(abs(parsed.preampDB - (-4.2)) < 1e-6, "Preamp parsed")
        expect(parsed.bands.count == 3, "3 bands parsed")
        expect(parsed.bands[0].type == .peak && parsed.bands[1].type == .lowShelf && !parsed.bands[2].enabled, "Filter types & OFF parsed")
        let exported = EqualizerAPOParser.export(preampDB: parsed.preampDB, bands: parsed.bands)
        let roundTrip = try! EqualizerAPOParser.parse(exported, layer: .correction)
        expect(roundTrip.bands.count == 3, "APO export->parse roundtrip")

        let huge = String(repeating: "A", count: EqualizerAPOParser.maxBytes + 10)
        do {
            _ = try EqualizerAPOParser.parse(huge)
            expect(false, "Huge APO payload must fail")
        } catch EqualizerAPOParserError.inputTooLarge {
            // expected
        } catch {
            expect(false, "Unexpected APO error: \(error)")
        }
        print("  [PASS] EqualizerAPO parser, export roundtrip & size cap")

        // 2. ExtensionIPCServer Origin & Bearer auth checks
        let srv = ExtensionIPCServer { _ in }
        let unauth = srv.processHTTPRequest("POST /v1/tab-audio HTTP/1.1\r\nOrigin: chrome-extension://abc\r\n\r\n{}")
        expect(unauth.contains("401"), "Missing bearer returns 401")
        let badOrigin = srv.processHTTPRequest("POST /v1/tab-audio HTTP/1.1\r\nAuthorization: Bearer \(srv.sessionToken)\r\nOrigin: https://evil.example\r\n\r\n{}")
        expect(badOrigin.contains("403"), "Web Origin rejected with 403")
        let body = "{\"browser\":\"chrome\",\"tabID\":\"7\",\"title\":\"YouTube\",\"origin\":\"https://youtube.com\",\"volume\":1.25,\"isMuted\":false}"
        let ok = srv.processHTTPRequest("POST /v1/tab-audio HTTP/1.1\r\nAuthorization: Bearer \(srv.sessionToken)\r\nOrigin: chrome-extension://abc\r\nContent-Length: \(body.utf8.count)\r\n\r\n\(body)")
        expect(ok.contains("200"), "Valid extension request accepted")
        srv.enqueueTabCommand(browser: "chrome", tabID: "7", volume: 0.45, isMuted: true)
        let cmdResp = srv.processHTTPRequestWithResponse("GET /v1/tab-commands HTTP/1.1\r\nAuthorization: Bearer \(srv.sessionToken)\r\nOrigin: chrome-extension://abc\r\n\r\n")
        expect(cmdResp.status.contains("200") && cmdResp.body.contains("\"tabID\":\"7\"") && cmdResp.body.contains("\"isMuted\":true"), "Bidirectional tab command delivered via authenticated GET")
        print("  [PASS] ExtensionIPCServer Bearer + Origin isolation & bidirectional commands")

        // 3. AI Safety Bounds & Deterministic Fallback
        let proposals = await AIAssistantRouter.proposeVariants(prompt: "menos sibilância e mais grave", language: .ptBR)
        expect(!proposals.isEmpty && proposals.count <= 3, "AI returns 1..3 proposals")
        for p in proposals {
            for op in p.operations {
                if let g = op.gainDB { expect(abs(g) <= EQDeltaValidator.maxAbsGainDB, "Gain clamped") }
                if let q = op.q { expect(q >= EQDeltaValidator.minQ && q <= EQDeltaValidator.maxQ, "Q clamped") }
            }
        }
        do {
            let excessive = EQDeltaProposal(
                label: "x", rationale: "x", runtimeUsed: .offlineHeuristic,
                operations: [
                    EQDeltaOperation(op: .addFilter, filterType: .peak, freqHz: 100, gainDB: 2, q: 1),
                    EQDeltaOperation(op: .addFilter, filterType: .peak, freqHz: 200, gainDB: 2, q: 1),
                    EQDeltaOperation(op: .addFilter, filterType: .peak, freqHz: 300, gainDB: 2, q: 1),
                    EQDeltaOperation(op: .addFilter, filterType: .peak, freqHz: 400, gainDB: 2, q: 1)
                ]
            )
            _ = try EQDeltaValidator.validateAndClamp(excessive, strict: true)
            expect(false, "Strict mode must reject >3 new bands")
        } catch EQDeltaValidationError.tooManyNewFilters {
            // expected
        } catch {
            expect(false, "Unexpected AI validation error: \(error)")
        }
        do {
            let sneak = EQDeltaProposal(
                label: "sneak", rationale: "adjust_band append bypass", runtimeUsed: .offlineHeuristic,
                operations: (0..<4).map { i in
                    EQDeltaOperation(op: .adjustBand, filterType: .peak, freqHz: Double(100 + i * 200), gainDB: 3, q: 1)
                }
            )
            _ = try EQDeltaValidator.apply(proposal: sneak, toTasteBands: [])
            expect(false, "adjust_band must not bypass maxNewFiltersPerRequest")
        } catch EQDeltaValidationError.tooManyNewFilters {
            // expected
        } catch {
            expect(false, "Unexpected adjust_band validation error: \(error)")
        }
        let airPodsMatch = AutoEqService.matchDeviceName("AirPods")
        expect(airPodsMatch.first?.id == "apple-airpods-3-crinacle", "Bare AirPods prefers 3rd gen, not Pro/Max")
        let air4Match = AutoEqService.matchDeviceName("AirPods 4")
        expect(air4Match.first?.id == "apple-airpods-4-rtings-5128", "AirPods 4 prefers non-ANC starter")
        expect(AutoEqService.isAllowlistedRelativePath("../etc/passwd") == false, "AutoEq path traversal rejected")
        print("  [PASS] AI Safety bounds & validator")

        // 4. PairwiseGPTrainer preference convergence
        let trainer = PairwiseGPTrainer()
        let target = TasteVector([0.75, 0.0, 0.1, 0.0])
        var history: [PairwiseComparison] = []
        for round in 0..<8 {
            let (a, b) = trainer.proposeNextPair(history: history, seed: UInt64(100 + round))
            let distA = zip(a.values, target.values).map { ($0 - $1) * ($0 - $1) }.reduce(0, +)
            let distB = zip(b.values, target.values).map { ($0 - $1) * ($0 - $1) }.reduce(0, +)
            history.append(PairwiseComparison(candidateA: a, candidateB: b, winnerIsA: distA <= distB))
        }
        let best = trainer.estimateBest(history: history)
        expect(best.values[0] > 0.0, "PairwiseGP learned positive bass preference")
        print("  [PASS] PairwiseGP Trainer convergence: \(best.values)")

        // 5. Localization parity PT-BR / ES / EN + Compact <=40pt ear token length
        for key in TimbreStrings.allKeys {
            for lang in TimbreLanguage.allCases {
                let val = TimbreStrings.row(key)?[lang] ?? ""
                expect(!val.isEmpty, "Missing localization \(key) for \(lang.rawValue)")
            }
        }
        for key in TimbreStrings.allKeys where key.hasPrefix("notch.compact.") {
            for lang in TimbreLanguage.allCases {
                let val = TimbreStrings.get(key, lang: lang)
                expect(val.count <= 6, "Compact ear key \(key) too long: \(val)")
            }
        }
        print("  [PASS] Trilingual PT/ES/EN parity (\(TimbreStrings.allKeys.count) keys)")

        // 6. Guardian Rules G-01..G-07 + Silent Studio + Muted pairs
        let btHfp = AudioDeviceDescriptor(uid: "bt1", name: "MOMENTUM 4", transport: .bluetoothHFP, sampleRate: 16000, isHWVolumeMasterSettable: true)
        let drv = HardwareDriverTelemetry(driverName: "M4", internalEQNonFlat: true, connectionStatus: "ok")
        let ctx = GuardianContext(
            activeOutput: btHfp,
            activeInput: btHfp,
            sources: [],
            knownSourceSampleRate: 48000,
            limiterClipCountRecent: 25,
            correctionActive: true,
            driverTelemetry: drv,
            softwareVolumeAppliedOnOutput: true,
            expectedOutputUID: "other-uid",
            competingCaptureApps: ["SoundSource"]
        )
        let alerts = GuardianAnalyzer.evaluate(ctx)
        let ruleIDs = Set(alerts.map { $0.ruleID })
        expect(ruleIDs == Set(GuardianRuleID.allCases), "All G-01..G-07 rules triggered: \(ruleIDs)")
        let muted = GuardianAnalyzer.evaluate(ctx, mutedPairs: ["G-01|*|bt1"])
        expect(!muted.contains(where: { $0.ruleID == .g01HFP }), "Muted pair suppresses G-01")
        expect(GuardianAnalyzer.evaluate(ctx, silentStudioMode: true).isEmpty, "Silent Studio suppresses non-critical")
        expect(GuardianAnalyzer.isVoIPOrDAWProtected(bundleID: "us.zoom.xos"), "Zoom VoIP protected")
        print("  [PASS] Guardian G-01..G-07, Silent Studio & VoIP protection")

        // 7. SQLiteStore, AutoEq offline & DiagnosticsExporter
        let tmpDB = FileManager.default.temporaryDirectory.appendingPathComponent("timbr_test_\(UUID().uuidString).sqlite").path
        defer { try? FileManager.default.removeItem(atPath: tmpDB) }
        let db = try! SQLiteStore(path: tmpDB)
        let p = TimbrePreset(name: "M4 Test", simpleTaste: SimpleTasteControls(bassDB: 1.5))
        try! db.savePreset(p)
        expect(db.loadPresets().first?.name == "M4 Test", "SQLite preset roundtrip")
        try! db.saveEvent(ObservatoryEvent(category: "test", message: "ok"))
        expect(db.loadRecentEvents().count == 1, "SQLite event roundtrip")
        try! db.clearAllHistory()
        expect(db.loadRecentEvents().isEmpty, "SQLite clearAllHistory")

        let m4Matches = AutoEqService.matchDeviceName("Sennheiser MOMENTUM 4")
        expect(!m4Matches.isEmpty, "AutoEq matched Momentum 4")
        let m4Eq = try! await AutoEqService.loadParametricEQ(entry: m4Matches[0], allowNetwork: false)
        expect(!m4Eq.parsed.bands.isEmpty && m4Eq.fromCacheOrOffline, "AutoEq bundled offline APO loaded")

        let diag = SanitizedDiagnosticReport(osVersion: "26.6", devices: [btHfp], activeAlerts: alerts, recentEvents: [])
        let diagJSON = try! diag.toJSONPretty()
        expect(diag.audioBuffersIncluded == false && diagJSON.contains("\"audioBuffersIncluded\" : false"), "Diagnostics zero audio buffers")
        print("  [PASS] SQLiteStore, AutoEq offline & DiagnosticsExporter")

        // Source ordering: several apps playing keep a stable order (newest run leads), then muted, then recent.
        let t0 = Date(timeIntervalSince1970: 1_000)
        var spotify = AudioSourceDescriptor(bundleID: "com.spotify.client", name: "Spotify", isPlaying: true, lastActiveAt: t0)
        var chrome = AudioSourceDescriptor(bundleID: "com.google.Chrome", name: "Chrome", isPlaying: true, lastActiveAt: t0.addingTimeInterval(30))
        let mutedSrc = AudioSourceDescriptor(bundleID: "a.muted", name: "Muted", isMuted: true, lastActiveAt: t0)
        let recent = AudioSourceDescriptor(bundleID: "b.recent", name: "Recent", lastActiveAt: t0.addingTimeInterval(60))
        // Both refresh lastActiveAt every pass; only playingSince decides between them.
        spotify.lastActiveAt = t0.addingTimeInterval(90); chrome.lastActiveAt = t0.addingTimeInterval(90)
        let ordered = [recent, spotify, mutedSrc, chrome].sorted(by: AudioSourceDescriptor.displayOrder).map(\.bundleID)
        expect(ordered == ["com.google.Chrome", "com.spotify.client", "a.muted", "b.recent"], "Source display order stable with simultaneous playback: \(ordered)")
        print("  [PASS] Simultaneous sources ordering")

        // macOS daemons get friendly groups; apps are never captured by the catalog.
        expect(SystemAudioClient.classify(reportedBundleID: "systemsoundserverd", executablePath: "/usr/sbin/systemsoundserverd") == .systemSounds, "systemsoundserverd → System sounds")
        expect(SystemAudioClient.classify(reportedBundleID: "com.apple.PowerChime", executablePath: nil) == .systemSounds, "PowerChime → System sounds")
        expect(SystemAudioClient.classify(reportedBundleID: "com.apple.assistantd", executablePath: nil) == .siri, "assistantd → Siri")
        expect(SystemAudioClient.classify(reportedBundleID: "com.apple.avconferenced", executablePath: nil) == .calls, "avconferenced → Calls")
        expect(GuardianAnalyzer.isVoIPOrDAWProtected(bundleID: SystemAudioClient.calls.rawValue), "System calls are VoIP-protected")
        expect(SystemAudioClient.classify(reportedBundleID: "com.spotify.client", executablePath: "/Applications/Spotify.app/Contents/MacOS/Spotify") == nil, "Apps are not system clients")
        expect(SystemAudioClient.isSystemExecutable("/usr/libexec/historicalaudiod") && !SystemAudioClient.isSystemExecutable("/Applications/X.app/Contents/MacOS/X"), "System executable detection")
        expect(SystemAudioClient.allCases.allSatisfy { TimbreStrings.allKeys.contains($0.nameKey) }, "Every system client name is localized")
        expect(SilentOutputApps.contains("com.superduper.superwhisper") && !SilentOutputApps.contains("com.spotify.client"), "Dictation apps with silent output engines are not 'playing'")
        print("  [PASS] System audio clients catalog")

        // NotchPeekTarget resolution: 0 playing → output, 1 playing → single, 2+ playing → Master + playing apps.
        let pausedSafari = AudioSourceDescriptor(bundleID: "com.apple.Safari", name: "Safari", isPlaying: false, lastActiveAt: t0.addingTimeInterval(120))
        expect(NotchPeekTarget.resolve(from: []) == .output, "Empty sources resolve to .output")
        expect(NotchPeekTarget.resolve(from: [pausedSafari, mutedSrc]) == .output, "Paused/muted-only sources resolve to .output")
        expect(NotchPeekTarget.resolve(from: [pausedSafari, spotify]) == .single(spotify), "Single playing source wins over paused sources")
        if case .masterWithSources(let multiList) = NotchPeekTarget.resolve(from: [pausedSafari, spotify, chrome]) {
            expect(multiList.map(\.bundleID) == ["com.google.Chrome", "com.spotify.client"], "2+ playing resolves to Master + playing apps in displayOrder: \(multiList.map(\.bundleID))")
        } else {
            expect(false, "Expected .masterWithSources for 2 playing apps")
        }
        let fivePlaying = (1...5).map { i in
            var s = AudioSourceDescriptor(bundleID: "app.\(i)", name: "App \(i)", isPlaying: true, lastActiveAt: t0.addingTimeInterval(Double(i)))
            s.playingSince = t0.addingTimeInterval(Double(i))
            return s
        }
        if case .masterWithSources(let capped) = NotchPeekTarget.resolve(from: fivePlaying, limit: 4) {
            expect(capped.count == 4 && capped.first?.bundleID == "app.5", "Multi-source peek caps at 4 playing sources keeping newest first")
        } else {
            expect(false, "Expected capped .masterWithSources")
        }
        print("  [PASS] NotchPeekTarget resolution (0 / 1 / 2+ playing)")

        // TimbreHarmonicMath: 5-bar timbr. mark + subtle restrained motion + Reduce Motion
        let idleBars = TimbreHarmonicMath.samples(active: false, level: 0.9, time: 1.2, reduceMotion: false)
        expect(idleBars.count == 5 && idleBars.allSatisfy { $0.height == TimbreHarmonicMath.idleDotHeight && $0.opacity == TimbreHarmonicMath.idleOpacity }, "Idle bars collapse to quiet dots")

        let rmA = TimbreHarmonicMath.samples(active: true, level: nil, time: 0.0, reduceMotion: true)
        let rmB = TimbreHarmonicMath.samples(active: true, level: 0.8, time: 1.3, reduceMotion: true)
        expect(rmA.map(\.height) == TimbreHarmonicMath.baseHeights && rmA == rmB, "Reduce Motion keeps static timbr. silhouette")

        let nativeT0 = TimbreHarmonicMath.samples(active: true, level: nil, time: 0.0, reduceMotion: false)
        let nativeT1 = TimbreHarmonicMath.samples(active: true, level: nil, time: 0.7, reduceMotion: false)
        expect(nativeT0 != nativeT1, "Native active pass-through breathes subtly over time")
        for i in 0..<5 {
            expect(abs(nativeT0[i].height - TimbreHarmonicMath.baseHeights[i]) <= 1.15, "Native harmonic excursion stays subtle (<=1.15pt)")
            expect(nativeT0[i].opacity >= 0.69 && nativeT0[i].opacity <= 0.87, "Native harmonic luminance stays restrained")
        }

        let liveQuiet = TimbreHarmonicMath.samples(active: true, level: 0.05, time: 0.4, reduceMotion: false)
        let liveLoud = TimbreHarmonicMath.samples(active: true, level: 0.95, time: 0.4, reduceMotion: false)
        let avgQuiet = liveQuiet.map(\.height).reduce(0, +) / 5.0
        let avgLoud = liveLoud.map(\.height).reduce(0, +) / 5.0
        expect(avgLoud > avgQuiet && liveLoud.allSatisfy { $0.height <= 13.0 && $0.opacity <= 0.91 }, "Live signal lifts harmonic envelope smoothly within calm bounds")
        print("  [PASS] TimbreHarmonicMath (5-bar silhouette, subtle breath, Reduce Motion)")

        // FullscreenEvaluator: Chrome/Safari/video fullscreen vs desktop maximized & multi-display
        let notchScreen = FullscreenScreenSpec(minX: 0, minY: 0, width: 1470, height: 956, topInset: 32, hasPhysicalNotch: true)
        let dockBackdrop = FullscreenWindowSnapshot(ownerPID: 10, ownerName: "Dock", layer: 20, minX: 0, minY: 0, width: 1470, height: 956)
        let ownWindow = FullscreenWindowSnapshot(ownerPID: 999, ownerName: "Timbr", layer: 0, minX: 0, minY: 0, width: 1470, height: 956)
        let desktopMaxWithDock = FullscreenWindowSnapshot(ownerPID: 200, ownerName: "T3 Code", layer: 0, minX: 0, minY: 33, width: 1470, height: 868)
        let desktopMaxAutoHideDock = FullscreenWindowSnapshot(ownerPID: 200, ownerName: "Safari", layer: 0, minX: 0, minY: 32, width: 1470, height: 924)
        let html5Fullscreen = FullscreenWindowSnapshot(ownerPID: 201, ownerName: "Google Chrome", layer: 0, minX: 0, minY: 0, width: 1470, height: 956)
        let nativeFullscreen = FullscreenWindowSnapshot(ownerPID: 202, ownerName: "Safari", layer: 0, minX: 0, minY: 32, width: 1470, height: 924)
        let externalFullscreen = FullscreenWindowSnapshot(ownerPID: 203, ownerName: "VLC", layer: 0, minX: 1470, minY: 0, width: 1920, height: 1080)
        let splitLeft = FullscreenWindowSnapshot(ownerPID: 202, ownerName: "Safari", layer: 0, minX: 0, minY: 32, width: 730, height: 924)
        let splitRight = FullscreenWindowSnapshot(ownerPID: 204, ownerName: "Notes", layer: 0, minX: 740, minY: 32, width: 730, height: 924)

        expect(!FullscreenEvaluator.isFullscreen(screen: notchScreen, windows: [dockBackdrop, ownWindow, desktopMaxWithDock], menuBarVisible: true, autoHideMenuBarAlways: false, frontmostAXFullScreen: false, ownPID: 999), "Desktop maximized window is not fullscreen")
        expect(!FullscreenEvaluator.isFullscreen(screen: notchScreen, windows: [dockBackdrop, desktopMaxAutoHideDock], menuBarVisible: true, autoHideMenuBarAlways: false, frontmostAXFullScreen: false, ownPID: 999), "Desktop maximized with auto-hidden Dock (menu bar visible) is not fullscreen")
        expect(FullscreenEvaluator.isFullscreen(screen: notchScreen, windows: [dockBackdrop, html5Fullscreen], menuBarVisible: false, autoHideMenuBarAlways: false, frontmostAXFullScreen: false, ownPID: 999), "Chrome HTML5 fullscreen covering notch edge hides compact")
        expect(FullscreenEvaluator.isFullscreen(screen: notchScreen, windows: [dockBackdrop, nativeFullscreen], menuBarVisible: false, autoHideMenuBarAlways: false, frontmostAXFullScreen: false, ownPID: 999), "Native macOS fullscreen Space hides compact")
        expect(FullscreenEvaluator.isFullscreen(screen: notchScreen, windows: [dockBackdrop, splitLeft, splitRight], menuBarVisible: false, autoHideMenuBarAlways: false, frontmostAXFullScreen: false, ownPID: 999), "Fullscreen Split View hides compact")
        expect(!FullscreenEvaluator.isFullscreen(screen: notchScreen, windows: [dockBackdrop, externalFullscreen], menuBarVisible: false, autoHideMenuBarAlways: false, frontmostAXFullScreen: false, ownPID: 999), "Fullscreen on external display does not hide MacBook notch")
        expect(FullscreenEvaluator.isFullscreen(screen: notchScreen, windows: [dockBackdrop, nativeFullscreen], menuBarVisible: true, autoHideMenuBarAlways: false, frontmostAXFullScreen: true, ownPID: 999), "AXFullScreen keeps fullscreen active during brief top-edge menu bar peek")
        print("  [PASS] FullscreenEvaluator (HTML5, native Space, Split View, auto-hide Dock, multi-monitor)")

        // MenuBarSpaceEvaluator: Chrome wrapped right menus (Janela/Ajuda), dual-app chin fallback, Accessibility gating
        let freeBoth = MenuBarSpaceEvaluator.freeEars(
            hasPhysicalNotch: true,
            screenWidth: 1470,
            notchLeft: 645.5,
            notchRight: 824.5,
            axTrusted: true,
            appMenuSpans: [MenuBarItemSpan(minX: 20, maxX: 450)],
            statusItemSpans: [MenuBarItemSpan(minX: 940, maxX: 1460)]
        )
        expect(freeBoth.left == 44 && freeBoth.right == 44, "Ample free space yields 44pt ears on both sides: \(freeBoth)")
        expect(!MenuBarSpaceEvaluator.shouldUseChin(ears: freeBoth, hasMultipleSources: false), "1 app uses both ears")
        expect(!MenuBarSpaceEvaluator.shouldUseChin(ears: freeBoth, hasMultipleSources: true), "2+ apps fit cleanly when both ears are free")

        // Exact Chrome scenario: left menu ends at 633, wrapped Janela/Ajuda sit at 832..959 right of notch!
        let chromeWrapped = MenuBarSpaceEvaluator.freeEars(
            hasPhysicalNotch: true,
            screenWidth: 1470,
            notchLeft: 645.5,
            notchRight: 824.5,
            axTrusted: true,
            appMenuSpans: [
                MenuBarItemSpan(minX: 520, maxX: 633),
                MenuBarItemSpan(minX: 832, maxX: 898),
                MenuBarItemSpan(minX: 898, maxX: 959)
            ],
            statusItemSpans: [MenuBarItemSpan(minX: 928, maxX: 1460)]
        )
        expect(chromeWrapped.left == 0 && chromeWrapped.right == 0, "Wrapped right app menus (Janela/Ajuda) zero out right ear: \(chromeWrapped)")
        expect(MenuBarSpaceEvaluator.shouldUseChin(ears: chromeWrapped, hasMultipleSources: false), "Wrapped menus force safe chin for 1 app")
        expect(MenuBarSpaceEvaluator.shouldUseChin(ears: chromeWrapped, hasMultipleSources: true), "Wrapped menus force safe chin for 2+ apps")

        // Bilateral consistency: if EITHER ear is blocked (left=0 OR right=0), always drop to chin
        // so the app icon never jumps across the camera to the right or cramps next to the harmonic mark.
        let rightOnly = MenuBarSpaceEvaluator.freeEars(
            hasPhysicalNotch: true,
            screenWidth: 1470,
            notchLeft: 645.5,
            notchRight: 824.5,
            axTrusted: true,
            appMenuSpans: [MenuBarItemSpan(minX: 520, maxX: 633)],
            statusItemSpans: [MenuBarItemSpan(minX: 928, maxX: 1460)]
        )
        expect(rightOnly.left == 0 && rightOnly.right == 44, "Left busy + right free yields (0, 44): \(rightOnly)")
        expect(MenuBarSpaceEvaluator.shouldUseChin(ears: rightOnly, hasMultipleSources: false), "Left busy drops 1 app to chin instead of jumping icon to right ear")
        expect(MenuBarSpaceEvaluator.shouldUseChin(ears: rightOnly, hasMultipleSources: true), "Left busy drops 2+ apps to chin")
        expect(MenuBarSpaceEvaluator.shouldUseChin(ears: (44, 0), hasMultipleSources: false), "Right busy drops 1 app to chin instead of cramping icon + mark")

        expect(MenuBarSpaceEvaluator.shouldUseChin(ears: (30, 44), hasMultipleSources: true), "30pt left ear drops 2+ apps to chin (< 36pt)")
        expect(!MenuBarSpaceEvaluator.shouldUseChin(ears: (30, 44), hasMultipleSources: false), "30pt left + 44pt right fits 1 app cleanly across both ears")

        // Without AX permission, never guess over wrapped or left menus
        let untrusted = MenuBarSpaceEvaluator.freeEars(
            hasPhysicalNotch: true,
            screenWidth: 1470,
            notchLeft: 645.5,
            notchRight: 824.5,
            axTrusted: false,
            appMenuSpans: [],
            statusItemSpans: [MenuBarItemSpan(minX: 940, maxX: 1460)]
        )
        expect(untrusted.left == 0 && untrusted.right == 0, "Without Accessibility trust, falls back to safe chin")
        print("  [PASS] MenuBarSpaceEvaluator (wrapped menus, dual-app chin fallback, AX gating)")

        // OutputVolumeBehavior: CoreAudio -63.5 dB floor must engage hardware mute at "0%" (< 0.005)
        let dragZero = OutputVolumeBehavior.evaluateSetVolume(requested: 0.0, isHWMuteSettable: true)
        expect(dragZero.scalar == 0.0 && dragZero.muted && dragZero.displayVolume == 0.0 && dragZero.hudMuted,
               "Dragging output slider to 0 engages hardware mute")
        let dragSubDisplayZero = OutputVolumeBehavior.evaluateSetVolume(requested: 0.004, isHWMuteSettable: true)
        expect(dragSubDisplayZero.scalar == 0.0 && dragSubDisplayZero.muted && dragSubDisplayZero.displayVolume == 0.0,
               "Sub-0.5% values that format as 0% snap scalar to 0 and engage hardware mute")
        let dragAudible = OutputVolumeBehavior.evaluateSetVolume(requested: 0.006, isHWMuteSettable: true)
        expect(!dragAudible.muted && abs(Double(dragAudible.scalar) - 0.006) < 0.0001 && !dragAudible.hudMuted,
               "Dragging above 0.5% unmutes hardware output")
        let dragNoHWMute = OutputVolumeBehavior.evaluateSetVolume(requested: 0.0, isHWMuteSettable: false)
        expect(dragNoHWMute.scalar == 0.0 && !dragNoHWMute.muted && dragNoHWMute.hudMuted,
               "Devices without HW mute keep muted=false while still marking HUD muted at 0")

        let keyDownZero = OutputVolumeBehavior.evaluateMediaKey(
            currentVolume: 0.05, currentMuted: false, isHWMuteSettable: true, action: .volumeDown(step: 0.0625)
        )
        expect(keyDownZero.scalar == 0.0 && keyDownZero.muted && keyDownZero.displayVolume == 0.0 && keyDownZero.hudMuted,
               "Volume Down key reaching 0 engages hardware mute")
        let keyMuteAtZero = OutputVolumeBehavior.evaluateMediaKey(
            currentVolume: 0.0, currentMuted: true, isHWMuteSettable: true, action: .muteToggle
        )
        expect(keyMuteAtZero.muted && keyMuteAtZero.displayVolume == 0.0,
               "Mute toggle at 0% never unmutes into CoreAudio -63.5 dB floor")
        let keyUnmuteHalf = OutputVolumeBehavior.evaluateMediaKey(
            currentVolume: 0.5, currentMuted: true, isHWMuteSettable: true, action: .muteToggle
        )
        expect(!keyUnmuteHalf.muted && keyUnmuteHalf.scalar == nil && abs(keyUnmuteHalf.displayVolume - 0.5) < 0.0001,
               "Mute toggle from muted 50% restores audible output cleanly")
        let keyUpFromZero = OutputVolumeBehavior.evaluateMediaKey(
            currentVolume: 0.0, currentMuted: true, isHWMuteSettable: true, action: .volumeUp(step: 0.0625)
        )
        expect(!keyUpFromZero.muted && abs(Double(keyUpFromZero.scalar ?? 0) - 0.0625) < 0.0001,
               "Volume Up key from muted 0% raises volume and unmutes")
        expect(OutputVolumeBehavior.shouldRestoreAudibleOnUnmute(activeVolume: 0.0), "0% needs audible restore")
        expect(!OutputVolumeBehavior.shouldRestoreAudibleOnUnmute(activeVolume: 0.25), "25% does not bump volume")
        expect(OutputVolumeBehavior.normalizeSourceVolume(0.003) == 0.0, "Source gain below 0.5% snaps to digital silence 0.0")
        print("  [PASS] OutputVolumeBehavior (zero-volume hardware mute, media keys, no -63.5 dB bleed)")

        // Unified Peek + Expanded spotlight rule across 0 / 1 / 2+ playing apps
        let now = Date()
        var spot2 = AudioSourceDescriptor(bundleID: "com.spotify.client", name: "Spotify", isPlaying: true, lastActiveAt: now)
        spot2.playingSince = now
        var chr2 = AudioSourceDescriptor(bundleID: "com.google.Chrome", name: "Google Chrome", isPlaying: true, lastActiveAt: now.addingTimeInterval(-30))
        chr2.playingSince = now.addingTimeInterval(-30)
        let pausedSpotify = AudioSourceDescriptor(bundleID: "com.spotify.client", name: "Spotify", isPlaying: false, lastActiveAt: now.addingTimeInterval(-60))

        expect(NotchPeekTarget.resolve(from: []) == .output, "0 playing -> Peek output")
        expect(NotchExpandedTarget.resolve(from: []) == .empty, "0 sources -> Expanded empty")

        expect(NotchPeekTarget.resolve(from: [pausedSpotify]) == .output, "Paused only -> Peek output")
        let pausedExpanded = NotchExpandedTarget.resolve(from: [pausedSpotify])
        expect(pausedExpanded.layoutKind == NotchExpandedTarget.LayoutKind.masterLed && pausedExpanded.singleSource == nil && pausedExpanded.listRowCount == 1,
               "Paused only -> Expanded masterLed with paused app row underneath")

        let singleExpanded = NotchExpandedTarget.resolve(from: [chr2, pausedSpotify])
        expect(singleExpanded.layoutKind == NotchExpandedTarget.LayoutKind.single && singleExpanded.singleSource?.bundleID == chr2.bundleID && singleExpanded.listRowCount == 1,
               "1 playing -> single app spotlight in Expanded")

        let multiPeek = NotchPeekTarget.resolve(from: [spot2, chr2])
        let multiExpanded = NotchExpandedTarget.resolve(from: [spot2, chr2])
        expect({
            if case .masterWithSources(let pList) = multiPeek { return pList.count == 2 }
            return false
        }(), "2+ playing -> Peek led neutrally by Geral/Master")
        expect(multiExpanded.layoutKind == NotchExpandedTarget.LayoutKind.masterLed && multiExpanded.singleSource == nil && multiExpanded.listRowCount == 2,
               "2+ playing -> Expanded also led neutrally by Geral/Master with equal app rows underneath")
        print("  [PASS] NotchPeekTarget & NotchExpandedTarget unified spotlight (0 / 1 / 2+ playing)")

        // AudioUIMath: Decibel taper, ballistics + peak hold + clip latch, LCD whole-segment quantization, rotary knob arc
        expect(abs(AudioDecibelMath.dbToGain(-6.0) - 0.501187) < 0.001, "dbToGain(-6 dB) ~ 0.501")
        expect(AudioDecibelMath.dbToGain(-70.0) == 0.0, "Below floorDB snaps to 0.0 gain")
        expect(!AudioDecibelMath.gainToDB(0.0).isFinite, "0.0 gain maps to -infinity dB")
        let midLinear = AudioDecibelMath.dbToNormalized(-30.0, minDB: -60.0, maxDB: 0.0, audioTaper: false)
        let midAudio = AudioDecibelMath.dbToNormalized(-30.0, minDB: -60.0, maxDB: 0.0, audioTaper: true)
        expect(abs(midLinear - 0.5) < 0.0001 && midAudio < midLinear && midAudio > 0.25,
               "Audio taper expands upper dB resolution near 0 dB (midAudio=\(midAudio))")
        let roundTripDB = AudioDecibelMath.normalizedToDB(midAudio, minDB: -60.0, maxDB: 0.0, audioTaper: true)
        expect(abs(roundTripDB - (-30.0)) < 0.001, "Audio taper round-trips normalized <-> dB")
        expect(AudioDecibelMath.zone(forDB: -80.0) == .silent, "-80 dBFS is silent")
        expect(AudioDecibelMath.zone(forDB: -18.0) == .normal, "-18 dBFS is normal")
        expect(AudioDecibelMath.zone(forDB: -6.0) == .warning, "-6 dBFS is warning")
        expect(AudioDecibelMath.zone(forDB: -0.5) == .clip, "-0.5 dBFS is clip")

        var bal = AudioMeterBallistics(floorDB: -60.0, clipThresholdDB: -1.0, holdDurationSeconds: 1.5, releaseDBPerSecond: 20.0)
        bal.step(sampleDB: -6.0, dtSeconds: 0.016)
        expect(abs(bal.smoothedDB - (-6.0)) < 0.001 && abs(bal.heldPeakDB - (-6.0)) < 0.001 && !bal.isClipLatched,
               "Fast attack captures -6 dB immediately without false clip")
        bal.step(sampleDB: -30.0, dtSeconds: 0.5)
        expect(abs(bal.smoothedDB - (-16.0)) < 0.001 && abs(bal.heldPeakDB - (-6.0)) < 0.001,
               "Smoothed level falls at 20 dB/s while heldPeakDB holds for 1.5 s")
        bal.step(sampleDB: -30.0, dtSeconds: 1.5)
        expect(bal.heldPeakDB < -6.0, "Held peak decays after hold duration expires")
        bal.step(sampleDB: -0.3, dtSeconds: 0.016)
        expect(bal.isClipLatched && bal.clipEventCount == 1, "Signal >= -1 dBFS latches clip indicator and increments count")
        bal.step(sampleDB: -0.1, dtSeconds: 0.016)
        expect(bal.clipEventCount == 1, "Continuous clip burst counts as 1 event until signal drops below threshold")
        bal.step(sampleDB: -12.0, dtSeconds: 0.016)
        bal.step(sampleDB: -0.2, dtSeconds: 0.016)
        expect(bal.clipEventCount == 2, "Second clip transient increments clipEventCount to 2")
        bal.resetClip()
        expect(!bal.isClipLatched && bal.clipEventCount == 0, "resetClip clears latch and counter")

        let lcdSilent = LCDSegmentLayout.quantize(dbfs: -90.0, heldPeakDB: -90.0, segmentCount: 24)
        expect(lcdSilent.litCount == 0 && lcdSilent.heldPeakIndex == nil, "Silence lights 0 LCD segments")
        let lcdHot = LCDSegmentLayout.quantize(dbfs: -3.0, heldPeakDB: -0.5, segmentCount: 24)
        expect(lcdHot.litCount > lcdHot.warningStartIndex && lcdHot.heldPeakIndex == 23,
               "Hot signal quantizes whole segments into warning zone with held peak at top segment")

        let bipolarKnob = KnobArcGeometry.compute(value: 3.0, range: -6.0...6.0, origin: 0.0)
        expect(abs(bipolarKnob.originDeg - 0.0) < 0.001 && abs(bipolarKnob.valueDeg - 67.5) < 0.001,
               "Bipolar knob places origin 0 dB at 12 o'clock (0 deg) and +3 dB at +67.5 deg")
        expect(!bipolarKnob.isTickLit(tickIndex: 2, tickCount: 11) && bipolarKnob.isTickLit(tickIndex: 6, tickCount: 11),
               "Peripheral scale ticks light only between origin (12 o'clock) and value")
        print("  [PASS] AudioUIMath (decibel taper, ballistics, clip latch, LCD quantization, bipolar knob arc)")

        print("[TimbreCoreTests] ALL PASSED")
    }
}
