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

        print("[TimbreCoreTests] ALL PASSED")
    }
}
