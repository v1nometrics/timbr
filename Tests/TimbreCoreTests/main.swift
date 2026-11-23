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

        // FullscreenEvaluator: keep notch active in normal browser/work fullscreen Spaces; hide on video/cinema/top-edge fullscreen
        let notchScreen = FullscreenScreenSpec(minX: 0, minY: 0, width: 1470, height: 956, topInset: 32, hasPhysicalNotch: true)
        let nonNotchScreen = FullscreenScreenSpec(minX: 0, minY: 0, width: 1920, height: 1080, topInset: 0, hasPhysicalNotch: false)
        let dockBackdrop = FullscreenWindowSnapshot(ownerPID: 10, ownerName: "Dock", layer: 20, minX: 0, minY: 0, width: 1470, height: 956)
        let ownWindow = FullscreenWindowSnapshot(ownerPID: 999, ownerName: "Timbr", layer: 0, minX: 0, minY: 0, width: 1470, height: 956)
        let desktopMaxWithDock = FullscreenWindowSnapshot(ownerPID: 200, ownerName: "T3 Code", layer: 0, minX: 0, minY: 33, width: 1470, height: 868)
        let desktopMaxAutoHideDock = FullscreenWindowSnapshot(ownerPID: 200, ownerName: "Safari", layer: 0, minX: 0, minY: 32, width: 1470, height: 924)

        // Chrome normal native fullscreen: toolbar (Y=33..74), tab strip (Y=74..155), content (Y=155..956)
        let chromeToolbar = FullscreenWindowSnapshot(ownerPID: 201, ownerName: "Google Chrome", layer: 0, minX: 0, minY: 33, width: 1470, height: 41)
        let chromeTabStrip = FullscreenWindowSnapshot(ownerPID: 201, ownerName: "Google Chrome", layer: 0, minX: 0, minY: 74, width: 1470, height: 81)
        let chromeBrowsingContent = FullscreenWindowSnapshot(ownerPID: 201, ownerName: "Google Chrome", layer: 0, minX: 0, minY: 155, width: 1470, height: 801)
        // Chrome HTML5 video fullscreen: toolbar hides and video spans below-notch to bottom (or top edge 0..956)
        let chromeVideoBelowNotch = FullscreenWindowSnapshot(ownerPID: 201, ownerName: "Google Chrome", layer: 0, minX: 0, minY: 33, width: 1470, height: 923)
        let html5TopEdgeFullscreen = FullscreenWindowSnapshot(ownerPID: 201, ownerName: "Google Chrome", layer: 0, minX: 0, minY: 0, width: 1470, height: 956)

        // Safari normal native fullscreen vs Safari WKFullScreenWindow / active video
        let safariSingle = FullscreenWindowSnapshot(ownerPID: 202, ownerName: "Safari", layer: 0, minX: 0, minY: 32, width: 1470, height: 924)
        let safariWKOverlay = FullscreenWindowSnapshot(ownerPID: 202, ownerName: "Safari", layer: 0, minX: 0, minY: 32, width: 1470, height: 924)

        // Productivity & cinema apps
        let cursorFullscreen = FullscreenWindowSnapshot(ownerPID: 205, ownerName: "Cursor", layer: 0, minX: 0, minY: 32, width: 1470, height: 924)
        let vlcFullscreen = FullscreenWindowSnapshot(ownerPID: 206, ownerName: "VLC", layer: 0, minX: 0, minY: 32, width: 1470, height: 924)
        let externalFullscreen = FullscreenWindowSnapshot(ownerPID: 203, ownerName: "VLC", layer: 0, minX: 1470, minY: 0, width: 1920, height: 1080)
        let splitLeft = FullscreenWindowSnapshot(ownerPID: 202, ownerName: "Safari", layer: 0, minX: 0, minY: 32, width: 730, height: 924)
        let splitRight = FullscreenWindowSnapshot(ownerPID: 204, ownerName: "Notes", layer: 0, minX: 740, minY: 32, width: 730, height: 924)
        let nonNotchNativeFullscreen = FullscreenWindowSnapshot(ownerPID: 201, ownerName: "Google Chrome", layer: 0, minX: 0, minY: 0, width: 1920, height: 1080)

        expect(!FullscreenEvaluator.isFullscreen(screen: notchScreen, windows: [dockBackdrop, ownWindow, desktopMaxWithDock], menuBarVisible: true, autoHideMenuBarAlways: false, frontmostAXFullScreen: false, ownPID: 999), "Desktop maximized window is not fullscreen")
        expect(!FullscreenEvaluator.isFullscreen(screen: notchScreen, windows: [dockBackdrop, desktopMaxAutoHideDock], menuBarVisible: true, autoHideMenuBarAlways: false, frontmostAXFullScreen: false, ownPID: 999), "Desktop maximized with auto-hidden Dock (menu bar visible) is not fullscreen")
        expect(!FullscreenEvaluator.isFullscreen(screen: notchScreen, windows: [dockBackdrop, chromeToolbar, chromeTabStrip, chromeBrowsingContent], menuBarVisible: false, autoHideMenuBarAlways: false, frontmostAXFullScreen: true, ownPID: 999, frontmostBundleID: "com.google.Chrome", frontmostOwnerName: "Google Chrome", playingBundleIDs: ["com.spotify.client"], playingOwnerNames: ["Spotify"]), "Chrome normal fullscreen browsing keeps notch active in black bezel")
        expect(!FullscreenEvaluator.isFullscreen(screen: notchScreen, windows: [dockBackdrop, safariSingle], menuBarVisible: false, autoHideMenuBarAlways: false, frontmostAXFullScreen: true, ownPID: 999, frontmostBundleID: "com.apple.Safari", frontmostOwnerName: "Safari", playingBundleIDs: ["com.spotify.client"], playingOwnerNames: ["Spotify"]), "Safari normal fullscreen browsing keeps notch active even with background Spotify")
        expect(!FullscreenEvaluator.isFullscreen(screen: notchScreen, windows: [dockBackdrop, cursorFullscreen], menuBarVisible: false, autoHideMenuBarAlways: false, frontmostAXFullScreen: true, ownPID: 999, frontmostBundleID: "com.todesktop.230313mzl4w4u92", frontmostOwnerName: "Cursor"), "Productivity app (Cursor) in native fullscreen keeps notch active")
        expect(!FullscreenEvaluator.isFullscreen(screen: notchScreen, windows: [dockBackdrop, splitLeft, splitRight], menuBarVisible: false, autoHideMenuBarAlways: false, frontmostAXFullScreen: true, ownPID: 999, frontmostBundleID: "com.apple.Safari", frontmostOwnerName: "Safari"), "Fullscreen Split View keeps notch active in black bezel")
        expect(FullscreenEvaluator.isFullscreen(screen: notchScreen, windows: [dockBackdrop, chromeVideoBelowNotch], menuBarVisible: false, autoHideMenuBarAlways: false, frontmostAXFullScreen: true, ownPID: 999, frontmostBundleID: "com.google.Chrome", frontmostOwnerName: "Google Chrome"), "Chrome HTML5 video fullscreen (toolbars hidden) hides notch")
        expect(FullscreenEvaluator.isFullscreen(screen: notchScreen, windows: [dockBackdrop, html5TopEdgeFullscreen], menuBarVisible: false, autoHideMenuBarAlways: false, frontmostAXFullScreen: false, ownPID: 999), "Top-edge borderless fullscreen hides notch")
        expect(FullscreenEvaluator.isFullscreen(screen: notchScreen, windows: [dockBackdrop, safariSingle, safariWKOverlay], menuBarVisible: false, autoHideMenuBarAlways: false, frontmostAXFullScreen: true, ownPID: 999, frontmostBundleID: "com.apple.Safari", frontmostOwnerName: "Safari"), "Safari WKFullScreenWindow HTML5 video hides notch")
        expect(FullscreenEvaluator.isFullscreen(screen: notchScreen, windows: [dockBackdrop, safariSingle], menuBarVisible: false, autoHideMenuBarAlways: false, frontmostAXFullScreen: true, ownPID: 999, frontmostBundleID: "com.apple.Safari", frontmostOwnerName: "Safari", playingBundleIDs: ["com.apple.Safari"], playingOwnerNames: ["Safari"]), "Safari fullscreen playing video hides notch")
        expect(FullscreenEvaluator.isFullscreen(screen: notchScreen, windows: [dockBackdrop, vlcFullscreen], menuBarVisible: true, autoHideMenuBarAlways: false, frontmostAXFullScreen: true, ownPID: 999, frontmostBundleID: "org.videolan.vlc", frontmostOwnerName: "VLC"), "Cinema/media player (VLC) hides notch even during brief top-edge menu bar peek")
        expect(!FullscreenEvaluator.isFullscreen(screen: notchScreen, windows: [dockBackdrop, externalFullscreen], menuBarVisible: false, autoHideMenuBarAlways: false, frontmostAXFullScreen: false, ownPID: 999), "Fullscreen on external display does not hide MacBook notch")
        expect(FullscreenEvaluator.isFullscreen(screen: nonNotchScreen, windows: [nonNotchNativeFullscreen], menuBarVisible: false, autoHideMenuBarAlways: false, frontmostAXFullScreen: true, ownPID: 999, frontmostBundleID: "com.google.Chrome", frontmostOwnerName: "Google Chrome"), "Non-notched display fullscreen covers top edge and hides pill")
        print("  [PASS] FullscreenEvaluator (browser normal vs HTML5 video, cinema apps, productivity apps, multi-monitor)")

        // MenuBarSpaceEvaluator: Chrome wrapped right menus (Janela/Ajuda), hiddenInNotch vs pill chin, hidden menu bar, AX gating
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
        expect(MenuBarSpaceEvaluator.compactPlacement(hasPhysicalNotch: true, ears: freeBoth, hasMultipleSources: false) == .ears, "1 app uses both ears")
        expect(MenuBarSpaceEvaluator.compactPlacement(hasPhysicalNotch: true, ears: freeBoth, hasMultipleSources: true) == .ears, "2+ apps fit cleanly when both ears are free")

        // Exact Chrome desktop scenario (including immediately upon exiting fullscreen):
        // left menu ends at 633, wrapped Janela/Ajuda sit at 832..959 right of notch.
        // On a notched Mac, Compact must NEVER drop a persistent chin onto Chrome's tab bar — tuck inside notch instead.
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
        expect(MenuBarSpaceEvaluator.compactPlacement(hasPhysicalNotch: true, ears: chromeWrapped, hasMultipleSources: false) == .hiddenInNotch, "Chrome menus tuck 1 app into notch instead of covering tabs")
        expect(MenuBarSpaceEvaluator.compactPlacement(hasPhysicalNotch: true, ears: chromeWrapped, hasMultipleSources: true) == .hiddenInNotch, "Chrome menus tuck 2+ apps into notch instead of covering tabs")
        expect(!MenuBarSpaceEvaluator.shouldUseChin(hasPhysicalNotch: true, ears: chromeWrapped, hasMultipleSources: false), "Notched screen never uses persistent chin")

        // Hidden menu bar (e.g. native fullscreen with compact chrome enabled): both ears beside physical notch are free
        let hiddenMenuBar = MenuBarSpaceEvaluator.freeEars(
            hasPhysicalNotch: true,
            screenWidth: 1470,
            notchLeft: 645.5,
            notchRight: 824.5,
            axTrusted: false,
            menuBarVisible: false,
            appMenuSpans: [MenuBarItemSpan(minX: 520, maxX: 633), MenuBarItemSpan(minX: 832, maxX: 959)],
            statusItemSpans: [MenuBarItemSpan(minX: 928, maxX: 1460)]
        )
        expect(hiddenMenuBar.left == 44 && hiddenMenuBar.right == 44, "Hidden menu bar keeps 44pt ears clear beside physical notch: \(hiddenMenuBar)")
        expect(MenuBarSpaceEvaluator.compactPlacement(hasPhysicalNotch: true, ears: hiddenMenuBar, hasMultipleSources: false) == .ears, "Hidden menu bar uses ears without chin")

        // Bilateral consistency: if EITHER ear is blocked (left=0 OR right=0), tuck inside physical notch
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
        expect(MenuBarSpaceEvaluator.compactPlacement(hasPhysicalNotch: true, ears: rightOnly, hasMultipleSources: false) == .hiddenInNotch, "Left busy tucks 1 app inside notch instead of jumping icon to right ear")
        expect(MenuBarSpaceEvaluator.compactPlacement(hasPhysicalNotch: true, ears: rightOnly, hasMultipleSources: true) == .hiddenInNotch, "Left busy tucks 2+ apps inside notch")
        expect(MenuBarSpaceEvaluator.compactPlacement(hasPhysicalNotch: true, ears: (44, 0), hasMultipleSources: false) == .hiddenInNotch, "Right busy tucks 1 app inside notch instead of cramping icon + mark")

        expect(MenuBarSpaceEvaluator.compactPlacement(hasPhysicalNotch: true, ears: (30, 44), hasMultipleSources: true) == .hiddenInNotch, "30pt left ear tucks 2+ apps inside notch (< 36pt)")
        expect(MenuBarSpaceEvaluator.compactPlacement(hasPhysicalNotch: true, ears: (30, 44), hasMultipleSources: false) == .ears, "30pt left + 44pt right fits 1 app cleanly across both ears")

        // Non-notched displays & explicit --review-chin still use the floating chin pill
        expect(MenuBarSpaceEvaluator.compactPlacement(hasPhysicalNotch: false, ears: (0, 0), hasMultipleSources: false) == .chin, "Non-notched display uses floating pill chin")
        expect(MenuBarSpaceEvaluator.compactPlacement(hasPhysicalNotch: true, ears: (0, 0), hasMultipleSources: false, forceChin: true) == .chin, "Explicit --review-chin forces chin")

        // Without AX permission while menu bar is visible, never guess over wrapped or left menus
        let untrusted = MenuBarSpaceEvaluator.freeEars(
            hasPhysicalNotch: true,
            screenWidth: 1470,
            notchLeft: 645.5,
            notchRight: 824.5,
            axTrusted: false,
            appMenuSpans: [],
            statusItemSpans: [MenuBarItemSpan(minX: 940, maxX: 1460)]
        )
        expect(untrusted.left == 0 && untrusted.right == 0, "Without Accessibility trust, tucks cleanly inside notch")
        print("  [PASS] MenuBarSpaceEvaluator (no persistent chin over Chrome tabs, hidden menu bar, AX gating)")

        // CompactIconLayoutEvaluator: dual icons must NEVER overlap or clip in either ears or chin
        for leftEar in [36.0, 38.0, 40.0, 42.0, 44.0] {
            let cx = 300.0, half = 90.0
            let layout = CompactIconLayoutEvaluator.layout(
                canvasCenterX: cx, notchHalfWidth: half, notchHeight: 33.0, chinHeight: 20.0,
                leftEar: leftEar, rightEar: 44.0, useChin: false, hasSecond: true
            )
            expect(layout.visible, "Dual ear layout visible at leftEar=\(leftEar)")
            let secondX = layout.secondCenterX!
            let secondMinX = secondX - layout.secondSize / 2.0
            let secondMaxX = secondX + layout.secondSize / 2.0
            let leadMinX = layout.leadCenterX - layout.leadSize / 2.0
            let leadMaxX = layout.leadCenterX + layout.leadSize / 2.0
            let earOuterX = cx - half - leftEar
            let earInnerX = cx - half
            expect(secondMaxX + 3.0 <= leadMinX, "No icon overlap at leftEar=\(leftEar): gap=\(leadMinX - secondMaxX)")
            expect(secondMinX >= earOuterX + 4.0, "Second icon stays inside outer ear margin at leftEar=\(leftEar)")
            expect(leadMaxX <= earInnerX - 4.0, "Lead icon stays inside notch bezel margin at leftEar=\(leftEar)")
        }
        let narrowDual = CompactIconLayoutEvaluator.layout(
            canvasCenterX: 300.0, notchHalfWidth: 90.0, notchHeight: 33.0, chinHeight: 20.0,
            leftEar: 30.0, rightEar: 44.0, useChin: false, hasSecond: true
        )
        expect(!narrowDual.visible, "Dual ear icons stay hidden when left ear < 36pt and not using chin")
        let chinDual = CompactIconLayoutEvaluator.layout(
            canvasCenterX: 300.0, notchHalfWidth: 90.0, notchHeight: 33.0, chinHeight: 20.0,
            leftEar: 0.0, rightEar: 0.0, useChin: true, hasSecond: true
        )
        let chinGap = (chinDual.leadCenterX - chinDual.leadSize / 2.0) - (chinDual.secondCenterX! + chinDual.secondSize / 2.0)
        expect(chinDual.visible && chinGap >= 4.0, "Chin dual icons stay cleanly separated (gap=\(chinGap))")
        print("  [PASS] CompactIconLayoutEvaluator (zero dual-icon overlap across all ear widths & chin)")

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
        expect(OutputVolumeBehavior.isEffectivelySilenced(volume: 0.0, muted: false), "0% volume is effectively silenced even if CoreAudio mute flag has not synced")
        expect(OutputVolumeBehavior.isEffectivelySilenced(volume: 0.004, muted: false), "Sub-0.5% volume is effectively silenced")
        expect(!OutputVolumeBehavior.isEffectivelySilenced(volume: 0.1, muted: false), "10% unmuted is audible")
        expect(OutputVolumeBehavior.needsZeroVolumeMuteHeal(volume: 0.0, muted: false, isHWMuteSettable: true), "0% with mute=0 needs HW mute self-heal")
        expect(!OutputVolumeBehavior.needsZeroVolumeMuteHeal(volume: 0.0, muted: true, isHWMuteSettable: true), "0% with mute=1 already healed")
        expect(!OutputVolumeBehavior.needsZeroVolumeMuteHeal(volume: 0.25, muted: false, isHWMuteSettable: true), "25% with mute=0 does not need heal")
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

        // Fail-closed mute policy (ADR-0017)
        let req = MuteKeeperProtocol.Request(generation: 7, targets: [
            .init(bundleID: "com.spotify.client", pids: [42, 42, 7], bundleIDs: ["com.spotify.client.helper", "com.spotify.client"]),
            .init(bundleID: "com.apple.Music", pids: [], bundleIDs: ["com.apple.Music"])])
        expect(req.targets.map(\.bundleID) == ["com.apple.Music", "com.spotify.client"], "Keeper request is sorted (stable file, no spurious rewrites)")
        expect(req.targets[1].pids == [7, 42] && req.targets[1].bundleIDs == ["com.spotify.client", "com.spotify.client.helper"], "Targets are deduplicated and sorted")
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("timbr-keeper-test-\(UUID().uuidString)")
        try! MuteKeeperProtocol.write(req, to: MuteKeeperProtocol.requestURL(tmpDir))
        expect(MuteKeeperProtocol.read(MuteKeeperProtocol.Request.self, from: MuteKeeperProtocol.requestURL(tmpDir)) == req, "Keeper request round-trips through disk")
        expect(!MuteKeeperProtocol.isKeeperRunning(in: tmpDir), "No lock holder means no keeper")
        try? FileManager.default.removeItem(at: tmpDir)
        let st = MuteKeeperProtocol.Status(generation: 7, pid: 1, held: ["com.spotify.client"], failures: [:])
        expect(MuteKeeperProtocol.confirmedHeld(status: st, requestGeneration: 7, keeperRunning: true) == ["com.spotify.client"], "Keeper confirmation for the current request lets timbr. hand over")
        expect(MuteKeeperProtocol.confirmedHeld(status: st, requestGeneration: 8, keeperRunning: true).isEmpty, "A stale status (older request) never hands over")
        expect(MuteKeeperProtocol.confirmedHeld(status: st, requestGeneration: 7, keeperRunning: false).isEmpty, "A dead keeper never hands over")
        expect(MuteKeeperProtocol.confirmedHeld(status: nil, requestGeneration: 7, keeperRunning: true).isEmpty, "No status never hands over")
        let pmMuted = AudioSourceDescriptor(bundleID: "com.spotify.client", name: "Spotify", volume: 1.0, isMuted: true)
        let pmZero = AudioSourceDescriptor(bundleID: "com.spotify.client", name: "Spotify", volume: 0.0, isMuted: false)
        let pmQuiet = AudioSourceDescriptor(bundleID: "com.spotify.client", name: "Spotify", volume: 0.25, isMuted: false)
        let pmVoip = AudioSourceDescriptor(bundleID: "us.zoom.xos", name: "Zoom", volume: 1.0, isMuted: true, isVoIPExcluded: true)
        expect(PersistentMutePolicy.isSilenced(pmMuted), "Muted app is held fail-closed")
        expect(PersistentMutePolicy.isSilenced(pmZero), "Fader at 0 % is held fail-closed like a mute")
        expect(!PersistentMutePolicy.isSilenced(pmQuiet), "An audible volume is not a mute")
        expect(!PersistentMutePolicy.isSilenced(pmVoip), "VoIP/DAW protected apps are never muted by timbr.")
        expect(PersistentMutePolicy.restorableBundleIDs(owner: "com.google.Chrome", reported: ["com.google.Chrome.helper", "com.google.Chrome.helper", "com.apple.WebKit.GPU", "com.google.ChromeX"])
               == ["com.google.Chrome", "com.google.Chrome.helper"],
               "Restore follows the app and its helpers, never shared system processes or look-alike IDs")
        let pmMerged = PersistentMutePolicy.mergeSurvivingMutes(["com.spotify.client", "com.apple.Music"],
                                                              into: [pmQuiet], displayName: { $0 == "com.apple.Music" ? "Music" : nil })
        expect(pmMerged.count == 2 && pmMerged[0].isMuted && pmMerged[0].volume == 0.25, "A surviving mute marks the existing row muted and keeps its volume")
        expect(pmMerged[1].bundleID == "com.apple.Music" && pmMerged[1].name == "Music" && pmMerged[1].isMuted && pmMerged[1].pids.isEmpty,
               "A surviving mute for an app not seen yet gets its own muted row")
        print("  [PASS] PersistentMutePolicy & MuteKeeperProtocol (silenced rule, restore scope, adoption merge, hand-over only on confirmation)")

        // EQ layouts (4 / 5 / 10 bands), free-PEQ editing rules, old presets (ADR-0019)
        do {
            expect(EQBandLayout.allCases.map(\.bandCount) == [4, 5, 10], "Layouts have 4, 5 and 10 bands")
            expect(EQBandLayout.ten.slots.map(\.freqHz) == [31.5, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000], "10 bands are ISO octave centres")
            expect(EQBandLayout.four.slots.map(\.freqHz) == [105, 250, 3000, 10000] && SimpleTasteControls.neutral.toPEQBands().map(\.freqHz) == [105, 250, 3000, 10000],
                   "The 4-band layout is exactly the original Bass/Warmth/Presence/Air bands")
            for l in EQBandLayout.allCases {
                let f = l.slots.map(\.freqHz)
                expect(f == f.sorted() && Set(f).count == f.count, "\(l.rawValue): band centres strictly ascending")
            }
            var p = TimbrePreset(name: "layouts")
            p.layout = .ten
            p.setGain(3.2, at: 4, in: .ten)
            expect(p.gains(for: .ten)[4] == 3.0 || p.gains(for: .ten)[4] == 3.5, "Gain snaps to 0.5 dB steps")
            p.setGain(99, at: 0, in: .ten)
            expect(p.gains(for: .ten)[0] == 12, "Gain clamps to the layout's travel (±12 dB for 10 bands)")
            p.setGain(99, at: 0, in: .five)
            expect(p.gains(for: .five)[0] == 9, "…±9 dB for 5 bands")
            p.setGain(-4, at: 1, in: .four)
            expect(p.simpleTaste.warmthDB == -4 && p.gains(for: .four) == [0, -4, 0, 0], "The 4-band layout still lives in simpleTaste")
            expect(p.gains(for: .ten)[4] != 0 && p.gains(for: .five) == [9, 0, 0, 0, 0], "Each layout keeps its own gains when you switch")
            p.setGain(1, at: 99, in: .ten)
            expect(p.gains(for: .ten).count == 10, "An out-of-range slot is ignored")
            expect(p.layoutBands.count == 10 && p.effectiveTasteBands.count == 10 && p.layoutBands.filter(\.enabled).count == 2, "Fixed layout feeds the DSP: only non-zero bands are on")
            p.flattenLayout(.ten)
            expect(p.isLayoutFlat(.ten) && !p.isLayoutFlat(.four) && p.layoutBands.allSatisfy { !$0.enabled }, "Flatten zeroes only the current layout")

            // Presets saved before layouts existed still load, as the 4-band EQ
            let legacy = TimbrePreset(name: "legacy", simpleTaste: SimpleTasteControls(bassDB: 2))
            let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
            var obj = try! JSONSerialization.jsonObject(with: enc.encode(legacy)) as! [String: Any]
            obj.removeValue(forKey: "layout"); obj.removeValue(forKey: "layoutGains")
            let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
            let old = try! dec.decode(TimbrePreset.self, from: JSONSerialization.data(withJSONObject: obj))
            expect(old.layout == .four && old.layoutGains.isEmpty && old.simpleTaste.bassDB == 2, "A preset from before the layouts loads as the 4-band EQ with its gains")
            var modern = TimbrePreset(name: "modern"); modern.layout = .five; modern.setGain(-3, at: 2, in: .five)
            let back = try! dec.decode(TimbrePreset.self, from: enc.encode(modern))
            expect(back.layout == .five && back.gains(for: .five)[2] == -3, "Layout and gains round-trip")

            // The reported bug, as a rule
            let off = EQBand(type: .peak, freqHz: 1000, gainDB: 0, q: 1, enabled: false)
            var moved = off; moved.freqHz = 1500
            expect(EQBandEditing.afterUserAdjust(old: off, new: moved).enabled, "Moving a disabled band turns it on")
            var gained = off; gained.gainDB = -3
            expect(EQBandEditing.afterUserAdjust(old: off, new: gained).enabled, "…so does changing its gain")
            var toggled = off; toggled.enabled = true
            expect(EQBandEditing.afterUserAdjust(old: off, new: toggled).enabled, "Toggling on still turns it on")
            var onNow = off; onNow.enabled = true
            var switchedOff = onNow; switchedOff.enabled = false
            expect(!EQBandEditing.afterUserAdjust(old: onNow, new: switchedOff).enabled, "Switching a band off is respected, not undone")
            var retyped = off; retyped.type = .highShelf
            expect(!EQBandEditing.afterUserAdjust(old: off, new: retyped).enabled, "Changing only the type does not switch a band on")

            // Free-PEQ defaults, reset, placement and limits
            let seeded = EQBandEditing.bands(for: .four, gains: [2, 0, -1, 0], enabled: true)
            expect(seeded.allSatisfy(\.enabled), "A free PEQ seeded from a layout starts with every filter on")
            expect(EQBandEditing.isDefaultFree(EQBandEditing.defaultFreeBands()) && !EQBandEditing.isDefaultFree(seeded) && !EQBandEditing.isDefaultFree([]), "Reset is only offered when something differs from the defaults")
            var shifted = EQBandEditing.defaultFreeBands(); shifted[0].freqHz = 120
            expect(!EQBandEditing.isDefaultFree(shifted), "A moved but flat filter still counts as changed")
            let spot = EQBandEditing.nextFreeFrequency(existing: EQBandEditing.defaultFreeBands())
            expect(spot > 20 && spot < 20000 && !EQBandEditing.defaultFreeBands().contains { abs(log10($0.freqHz) - log10(spot)) < 0.12 },
                   "A new filter lands in a gap, not on top of an existing one (\(spot) Hz)")
            expect(EQBandEditing.nextFreeFrequency(existing: []) > 100 && EQBandEditing.nextFreeFrequency(existing: []) < 1000, "With no filters the first one lands mid-spectrum")
            expect(EQBandEditing.maxFreeBands(correctionCount: 0) == 24 && EQBandEditing.maxFreeBands(correctionCount: 10) == 22 && EQBandEditing.maxFreeBands(correctionCount: 40) == 0,
                   "Free filters never exceed what the DSP can run next to the correction bands")
            for l in EQBandLayout.allCases {
                for slot in l.slots {
                    for lang in TimbreLanguage.allCases {
                        expect(TimbreStrings.get(slot.nameKey, lang: lang) != slot.nameKey && TimbreStrings.get(slot.nameKey + ".hint", lang: lang) != slot.nameKey + ".hint",
                               "\(l.rawValue)/\(slot.freqHz) Hz: band name and hint exist in \(lang.rawValue)")
                    }
                }
            }
            expect(TimbreStrings.get("eq.band.bass", lang: .ptBR) == "Graves (Bass)" && TimbreStrings.get("eq.band.bass", lang: .en) == "Bass",
                   "Portuguese first with the audiophile term in parentheses; English shows the term alone")
            print("  [PASS] EQ layouts (4/5/10), per-layout gains, old-preset compatibility, free-PEQ handle/reset/placement rules")
        }

        // Observatory timeline: keyset pagination, trigram search, filters, streamed export (ADR-0018)
        do {
            let dbPath = FileManager.default.temporaryDirectory.appendingPathComponent("timbr-events-\(UUID().uuidString).sqlite").path
            let store = try! SQLiteStore(path: dbPath)
            let t0 = Date(timeIntervalSince1970: 1_800_000_000)
            let cats = ["device", "dsp", "mixer", "system"]
            for i in 0..<1500 {   // several events share a timestamp on purpose: the cursor must still not skip or repeat
                let msg = i % 50 == 0 ? "Switched output to MacBook Air Speakers #\(i)" : (i % 7 == 0 ? "=cmd|' /C calc'!A0, \"quoted\" line #\(i)" : "Event number \(i)")
                try! store.saveEvent(ObservatoryEvent(timestamp: t0.addingTimeInterval(Double(i / 3)), category: cats[i % 4], message: msg,
                                                      badge: i % 5 == 0 ? .measured : nil, deviceUID: i % 2 == 0 ? "uid-\(i)" : nil))
            }
            let reader = try! EventLogReader(path: dbPath)
            expect(reader.count(filter: EventFilter()) == 1500, "Reader counts every stored event")

            var seen = Set<UUID>(); var cursor: EventCursor?; var pages = 0; var last = Double.infinity
            while true {
                let pg = reader.page(filter: EventFilter(), after: cursor, limit: 100)
                for r in pg.rows {
                    expect(seen.insert(r.id).inserted, "Keyset pagination never repeats an event")
                    expect(r.event.timestamp.timeIntervalSince1970 <= last, "Timeline is newest first")
                    last = r.event.timestamp.timeIntervalSince1970
                }
                pages += 1
                guard pg.hasMore, let c = pg.rows.last?.cursor else { break }
                cursor = c
            }
            expect(seen.count == 1500 && pages == 15, "Paging 100 at a time walks all 1500 events in 15 pages, none skipped")

            let speakers = reader.page(filter: EventFilter(text: "air SPEA"), limit: 500)
            expect(speakers.rows.count == 30 && !speakers.hasMore, "Search matches a case-insensitive fragment through the index (30 of 1500)")
            expect(reader.count(filter: EventFilter(text: "air SPEA")) == 30, "Search count agrees with search results")
            expect(reader.page(filter: EventFilter(text: "ai"), limit: 5).rows.count == 5 && EventFilter(text: "ai").searchTooShort && EventFilter(text: "ai").isEmpty,
                   "Under 3 characters the search is not applied (and says it is too short)")
            expect(reader.count(filter: EventFilter(text: "\"quoted\"")) > 0 && reader.count(filter: EventFilter(text: "x\" OR 1=1 --")) == 0,
                   "Quotes and SQL fragments in the search box are data, not syntax")
            expect(reader.count(filter: EventFilter(categories: ["dsp"])) == 375, "Category filter counts that category only")
            expect(reader.count(filter: EventFilter(text: "Speakers", categories: ["device"])) == reader.page(filter: EventFilter(text: "Speakers", categories: ["device"]), limit: 500).rows.count,
                   "Search and category combine")
            expect(reader.categories() == cats, "Categories come from the data, sorted")

            // Live head: an event logged after the page was loaded appears via newer(than:)
            let head = reader.page(filter: EventFilter(), limit: 1).rows[0].cursor
            try! store.saveEvent(ObservatoryEvent(timestamp: t0.addingTimeInterval(1_000_000), category: "mixer", message: "Fresh event"))
            let fresh = reader.newer(filter: EventFilter(), than: head)
            expect(fresh.count == 1 && fresh[0].event.message == "Fresh event", "newer(than:) returns only what was logged after the loaded head")

            // Export: streamed, filtered, complete, safe for spreadsheets
            let csvURL = FileManager.default.temporaryDirectory.appendingPathComponent("timbr-export-\(UUID().uuidString).csv")
            let n = try! EventLogReader.export(databasePath: dbPath, filter: EventFilter(categories: ["mixer"]), format: .csv, to: csvURL)
            let csv = try! String(contentsOf: csvURL, encoding: .utf8)
            expect(n == 376 && csv.components(separatedBy: "\r\n").count == 376 + 2, "CSV export has the header plus every matching event")
            expect(csv.hasPrefix("timestamp,category,message,badge,device_uid\r\n"), "CSV has a header row")
            expect(!csv.contains(",=cmd") && csv.contains("'=cmd"), "CSV neutralises cells that a spreadsheet would run as formulas")
            let jsonURL = FileManager.default.temporaryDirectory.appendingPathComponent("timbr-export-\(UUID().uuidString).json")
            let nj = try! EventLogReader.export(databasePath: dbPath, filter: EventFilter(text: "Speakers"), format: .json, to: jsonURL)
            let parsed = try! JSONSerialization.jsonObject(with: Data(contentsOf: jsonURL)) as! [[String: Any]]
            expect(nj == 30 && parsed.count == 30 && parsed[0]["message"] != nil, "JSON export is a valid array with one object per match")
            let emptyURL = FileManager.default.temporaryDirectory.appendingPathComponent("timbr-export-\(UUID().uuidString).json")
            _ = try! EventLogReader.export(databasePath: dbPath, filter: EventFilter(text: "no such text anywhere"), format: .json, to: emptyURL)
            expect((try! JSONSerialization.jsonObject(with: Data(contentsOf: emptyURL)) as! [Any]).isEmpty, "An export with no matches is still a valid empty JSON array")
            let partials = (try? FileManager.default.contentsOfDirectory(atPath: FileManager.default.temporaryDirectory.path))?.filter { $0.hasSuffix(".partial") } ?? []
            expect(partials.isEmpty, "No .partial file is left behind")

            // Reading while the writer keeps writing (the whole point of the second connection)
            let burst = Task.detached { for i in 0..<300 { try? store.saveEvent(ObservatoryEvent(category: "system", message: "Burst \(i)")) } }
            for _ in 0..<30 { _ = reader.page(filter: EventFilter(text: "Burst"), limit: 50); _ = reader.count(filter: EventFilter()) }
            await burst.value
            expect(reader.count(filter: EventFilter(text: "Burst")) == 300, "A reader running alongside the writer sees every event once the burst ends")

            // The search index follows deletes (clearing history must not leave searchable ghosts)
            try! store.clearAllHistory()
            expect(reader.count(filter: EventFilter()) == 0 && reader.count(filter: EventFilter(text: "Speakers")) == 0, "Clearing history clears the search index too")
            for u in [csvURL, jsonURL, emptyURL] { try? FileManager.default.removeItem(at: u) }
            for ext in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: dbPath + ext) }
            print("  [PASS] Observatory timeline (keyset paging, trigram search, filters, live head, streamed CSV/JSON export, concurrent reads)")
        }

        // Notch activity: system blips never wake the notch
        do {
            let click = AudioSourceDescriptor(bundleID: SystemAudioClient.systemSounds.rawValue, name: "System sounds", isPlaying: true)
            let other = AudioSourceDescriptor(bundleID: SystemAudioClient.otherSystem.rawValue, name: "Other", isPlaying: true)
            let siri = AudioSourceDescriptor(bundleID: SystemAudioClient.siri.rawValue, name: "Siri", isPlaying: true)
            let call = AudioSourceDescriptor(bundleID: SystemAudioClient.calls.rawValue, name: "Calls", isPlaying: true)
            let spotify = AudioSourceDescriptor(bundleID: "com.spotify.client", name: "Spotify", isPlaying: true)
            expect(NotchActivityPolicy.isTransientSystemSound(bundleID: click.bundleID) && NotchActivityPolicy.isTransientSystemSound(bundleID: other.bundleID),
                   "System sounds and other macOS audio are transient")
            expect(!NotchActivityPolicy.isTransientSystemSound(bundleID: siri.bundleID) && !NotchActivityPolicy.isTransientSystemSound(bundleID: call.bundleID)
                   && !NotchActivityPolicy.isTransientSystemSound(bundleID: "com.spotify.client"), "Siri, calls and real apps still count")
            let seen = NotchActivityPolicy.forNotch([click, other, siri, call, spotify])
            expect(seen.map(\.isPlaying) == [false, false, true, true, true] && seen[0].playingSince == nil, "Only the system blips are made quiet for the notch")
            expect(NotchPeekTarget.resolve(from: NotchActivityPolicy.forNotch([click])) == .output, "A lone system click leaves the notch on the output, not on System Settings")
            if case .single(let s) = NotchPeekTarget.resolve(from: NotchActivityPolicy.forNotch([click, spotify])) { expect(s.bundleID == "com.spotify.client", "With music playing, a click does not steal the notch") } else { expect(false, "Music + click resolves to the music alone") }
            expect(click.isPlaying, "The original source is untouched (the Mixer still shows it playing)")
            print("  [PASS] NotchActivityPolicy (system blips never wake the notch; Siri, calls and apps still do)")
        }

        // Silence tracker: pauses are heard in ~1 s, track gaps are not mistaken for pauses
        do {
            var tr = SilenceTracker(floorDB: -75, holdSeconds: 1.0)
            let t0 = Date(timeIntervalSince1970: 1_800_000_000)
            expect(tr.update(peaks: ["app:a": -10], now: t0).isEmpty, "A loud slot is never silent")
            expect(tr.update(peaks: ["app:a": -120], now: t0.addingTimeInterval(0.1)).isEmpty, "Silence is not reported at once (a gap between songs)")
            expect(tr.update(peaks: ["app:a": -120], now: t0.addingTimeInterval(0.9)).isEmpty, "…nor before the hold time")
            expect(tr.update(peaks: ["app:a": -120], now: t0.addingTimeInterval(1.2)) == ["app:a"], "…but is, after a second of it")
            expect(tr.update(peaks: ["app:a": -20], now: t0.addingTimeInterval(1.3)).isEmpty, "A loud block ends the silence at once")
            expect(tr.update(peaks: ["app:a": -120], now: t0.addingTimeInterval(1.4)).isEmpty, "…and the hold starts over (a 0.2 s gap is never a pause)")
            _ = tr.update(peaks: ["global": -120, "app:b": -120], now: t0.addingTimeInterval(2.0))
            let both = tr.update(peaks: ["global": -120, "app:b": -3], now: t0.addingTimeInterval(3.2))
            expect(both == ["global"], "Slots are tracked independently")
            _ = tr.update(peaks: [:], now: t0.addingTimeInterval(3.3))
            expect(tr.update(peaks: ["global": -120], now: t0.addingTimeInterval(3.4)).isEmpty, "A slot that disappeared and came back starts from zero")
            let spotify = AudioSourceDescriptor(bundleID: "com.spotify.client", name: "Spotify", isPlaying: true)
            let chrome = AudioSourceDescriptor(bundleID: "com.google.Chrome", name: "Chrome", isPlaying: true)
            let seen = NotchActivityPolicy.forNotch([spotify, chrome], silent: ["com.spotify.client"])
            expect(seen.map(\.isPlaying) == [false, true] && spotify.isPlaying, "A silent app is not playing for the notch; the other one still is; the source is untouched")
            expect(NotchActivityPolicy.forNotch([spotify, chrome]).allSatisfy(\.isPlaying), "With no silence information nothing changes")
            print("  [PASS] SilenceTracker (1 s hold, instant resume, independent slots) and the notch policy's silent set")
        }

        // Listening time (ADR-0023): counts time and volume, never dB
        do {
            func dev(_ n: String, _ t: DeviceTransport) -> AudioDeviceDescriptor { AudioDeviceDescriptor(uid: n, name: n, transport: t) }
            expect(ListeningPolicy.isPersonalListening(dev("AirPods Pro de Vinícius", .bluetoothA2DP)) && ListeningPolicy.isPersonalListening(dev("MOMENTUM 4", .bluetoothHFP)),
                   "Bluetooth headphones are personal listening")
            expect(!ListeningPolicy.isPersonalListening(dev("MacBook Air Speakers", .builtIn)) && !ListeningPolicy.isPersonalListening(dev("LG UltraFine Display Audio", .usb))
                   && !ListeningPolicy.isPersonalListening(dev("JBL Soundbar", .bluetoothA2DP)) && !ListeningPolicy.isPersonalListening(dev("HDMI", .hdmi)),
                   "Speakers, displays, soundbars and HDMI are not")
            expect(ListeningPolicy.isPersonalListening(dev("Headphones", .builtIn)) && ListeningPolicy.isPersonalListening(dev("Fone de ouvido", .wiredAnalog))
                   && ListeningPolicy.isPersonalListening(dev("USB Headset", .usb)), "The headphone jack and USB headsets count")
            expect(ListeningPolicy.duration(0.4) == "0 min" && ListeningPolicy.duration(30) == "< 1 min" && ListeningPolicy.duration(35 * 60) == "35 min"
                   && ListeningPolicy.duration(3600) == "1 h" && ListeningPolicy.duration(4320) == "1 h 12 min", "Durations read naturally")
            expect(ListeningPolicy.dayKey(Date(timeIntervalSince1970: 1_800_000_000), calendar: { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }()) == "2027-01-15", "Day keys use the calendar day")

            var t = ListeningTracker(day: "2027-01-15")
            for _ in 0..<600 { t.tick(dayKey: "2027-01-15", dt: 2, listening: true, volume: 0.45) }   // 20 min, comfortable
            expect(abs(t.today.personalSeconds - 1200) < 0.01 && t.today.highSeconds == 0 && !t.isHigh && !t.adviceActive, "Comfortable listening counts as listening, not as high")
            for _ in 0..<1800 { t.tick(dayKey: "2027-01-15", dt: 2, listening: true, volume: 0.80) }  // 60 min high
            expect(t.isHigh && abs(t.streakSeconds - 3600) < 0.01 && t.adviceActive, "An hour at high volume raises the advice")
            t.tick(dayKey: "2027-01-15", dt: 2, listening: true, volume: 0.58)
            expect(t.isHigh && t.adviceActive, "Hysteresis: 58 % does not end a high streak that started at 60 %")
            t.tick(dayKey: "2027-01-15", dt: 2, listening: true, volume: 0.40)
            expect(!t.isHigh && !t.adviceActive && t.streakSeconds > 3600, "Lowering the volume dismisses the advice at once, but the streak is remembered")
            for _ in 0..<(8 * 60 / 2) { t.tick(dayKey: "2027-01-15", dt: 2, listening: false, volume: 0.80) }
            expect(t.streakSeconds > 3600, "A short pause is not a rest")
            for _ in 0..<(8 * 60 / 2) { t.tick(dayKey: "2027-01-15", dt: 2, listening: false, volume: 0.80) }
            expect(t.streakSeconds == 0, "15 minutes away from high volume is a rest: the streak resets")
            t.tick(dayKey: "2027-01-15", dt: 30, listening: true, volume: 0.9)
            expect(t.streakSeconds == 0, "A tick longer than 6 s (sleep, stall) counts for nothing")
            t.tick(dayKey: "2027-01-15", dt: 2, listening: true, volume: nil)
            expect(!t.isHigh, "Unknown volume is never counted as high")
            let pending = t.takePending()
            expect(pending != nil && pending!.day == "2027-01-15" && pending!.personal > 3000 && pending!.high > 3500 && t.takePending() == nil, "Pending seconds are handed over once for the store")
            t.tick(dayKey: "2027-01-16", dt: 2, listening: true, volume: 0.9)
            expect(t.today.day == "2027-01-16" && abs(t.today.personalSeconds - 2) < 0.01, "A new day starts its own totals")

            let path = FileManager.default.temporaryDirectory.appendingPathComponent("timbr-listen-\(UUID().uuidString).sqlite").path
            let st = try! SQLiteStore(path: path)
            st.addListening(day: "2027-01-15", personal: 100, high: 40)
            st.addListening(day: "2027-01-15", personal: 50, high: 10)
            st.addListening(day: "2027-01-14", personal: 7, high: 0)
            let days = st.loadListening(days: 7)
            expect(days.map(\.day) == ["2027-01-15", "2027-01-14"] && days[0].personalSeconds == 150 && days[0].highSeconds == 50, "The store adds up a day and lists newest first")
            try! st.clearAllHistory()
            expect(st.loadListening().isEmpty, "Clearing history clears the listening days too")
            for ext in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: path + ext) }
            print("  [PASS] ListeningTracker (time and volume only: 60/60 streak, hysteresis, rest, sleep, day rollover, storage)")
        }

        // Feedback by e-mail: local, visible, switchable (ADR-0024)
        do {
            let ctx = FeedbackContext(appVersion: "1.0 (12)", macOS: "Version 26.6 (Build 25G72)", outputKind: "Bluetooth", equalizerMode: "10 bandas", language: "pt-BR")
            expect(FeedbackComposer.recipient == "vinicius@v1torres.dev", "Feedback goes to the owner's address")
            expect(!FeedbackComposer.isSendable("curto") && !FeedbackComposer.isSendable("   \n\t  ") && FeedbackComposer.isSendable("Queria mais bandas no EQ."), "Too-short messages are not sendable")
            expect(FeedbackComposer.normalize("  a\r\nb\u{0007}c  ") == "a\nbc", "Line breaks unified, control characters dropped, edges trimmed")
            expect(FeedbackComposer.normalize(String(repeating: "x", count: 5000)).count == FeedbackComposer.maxMessageLength, "Messages are capped")
            expect(FeedbackComposer.subject(.bug) == "[timbr.] Problema" && FeedbackComposer.subject(.suggestion) == "[timbr.] Sugestão", "Subject names the category")
            let all = FeedbackComposer.body(message: "Adorei o notch!", context: ctx, options: FeedbackOptions())
            expect(all.contains("timbr.: 1.0 (12)") && all.contains("macOS: Version 26.6") && all.contains("Saída: Bluetooth") && all.contains("Equalizador: 10 bandas") && all.contains("pt-BR"), "Every enabled fact is in the body")
            var none = FeedbackOptions(); none.app = false; none.system = false; none.output = false; none.equalizer = false; none.language = false
            let bare = FeedbackComposer.body(message: "Adorei o notch!", context: ctx, options: none)
            expect(bare == "Adorei o notch!", "With every fact switched off, only the message is sent")
            var some = FeedbackOptions(); some.system = false; some.output = false
            let part = FeedbackComposer.body(message: "Mensagem de teste aqui", context: ctx, options: some)
            expect(!part.contains("macOS") && !part.contains("Saída") && part.contains("timbr.: 1.0"), "Each fact switches off on its own")
            expect(FeedbackComposer.outputKind(for: .bluetoothA2DP) == "Bluetooth" && !FeedbackComposer.outputKind(for: .builtIn).lowercased().contains("macbook"), "The output is a kind, never a device name")
            let url = FeedbackComposer.mailtoURL(category: .suggestion, message: "Que tal 'Graves & Agudos' = 100%?\nSegunda linha: ação", context: ctx, options: FeedbackOptions())!
            let s = url.absoluteString
            expect(s.hasPrefix("mailto:vinicius@v1torres.dev?subject=") && s.contains("&body="), "A mailto: URL to the owner")
            expect(!s.dropFirst(7).contains(" ") && !s.contains("\n") && s.contains("%0D%0A"), "Spaces and line breaks are percent-encoded (CRLF)")
            expect(s.contains("%26") && s.contains("%3D") && s.contains("%C3%A7"), "&, = and accents are encoded, so the message cannot break the URL")
            let back = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "body" }?.value ?? ""
            expect(back.hasPrefix("Que tal 'Graves & Agudos' = 100%?") && back.contains("ação"), "The e-mail body decodes to exactly what the person wrote")
            print("  [PASS] Feedback (local mailto, preview == body, per-fact switches, safe encoding, no device names)")
        }

        print("[TimbreCoreTests] ALL PASSED")
    }
}
