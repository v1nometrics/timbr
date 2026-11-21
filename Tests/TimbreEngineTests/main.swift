// SPDX-License-Identifier: MPL-2.0
import Foundation
import TimbreCore
import TimbreEngine

func expect(_ condition: @autoclosure () -> Bool, _ msg: String) {
    if !condition() {
        fputs("FAIL: \(msg)\n", stderr)
        exit(1)
    }
}

@main
struct TimbreEngineTestRunner {
    static func main() {
        print("[TimbreEngineTests] Running Momentum 4 protocol, HAL & ProcessTap tests...")

        // 1. Legacy GAIA v3 packet encode/decode & safety denylist (0x0607, 0x02xx DFU)
        let safePkt = GAIAv3Packet(featureID: 0x06, pduType: 0x00, pduID: 0x01, payload: [0x01, 0x02])
        let encoded = try! safePkt.encode()
        let decoded = try! GAIAv3Packet.decode(encoded)
        expect(decoded == safePkt, "GAIAv3 encode/decode roundtrip")

        for (fid, pid) in [(UInt8(0x06), UInt8(0x07)), (UInt8(0x02), UInt8(0x01)), (UInt8(0x00), UInt8(0x40)), (UInt8(0x14), UInt8(0x05))] {
            let blocked = GAIAv3Packet(featureID: fid, pduID: pid)
            do {
                _ = try blocked.encode()
                expect(false, "Denylisted command \(fid):\(pid) must throw")
            } catch Momentum4ProtocolError.denylistedCommandBlocked {
                // expected
            } catch {
                expect(false, "Unexpected GAIA error: \(error)")
            }
        }
        expect(!Momentum4FirmwareGate.supportsGen2EQ(firmwareVersion: "3.17.9"), "FW < 3.18.0 -> Gen1")
        expect(Momentum4FirmwareGate.supportsGen2EQ(firmwareVersion: "3.18.0"), "FW 3.18.0 -> Gen2")
        expect(Momentum4FirmwareGate.eqFeatureCommand(firmwareVersion: "3.18.0") == (0x10, 0x02), "Gen2 command 0x1002")
        print("  [PASS] Legacy GAIA v3 codec, safety denylist & FW 3.18.0 gate")

        // 2. Verified GaiaSPP framing, GaiaSPPDeframer & Gaia3Packet safety denylist (m4-companion MIT)
        let batReq = Gaia3Packet(commandID: Momentum4Commands.getBattery)
        let batWire = try! batReq.encode()
        let batFrame = try! GaiaSPP.frame(batWire)
        expect(Array(batFrame) == [0xFF, 0x03, 0x00, 0x00, 0x04, 0x95, 0x06, 0x03], "GaiaSPP battery wire bytes")

        for badCmd: UInt16 in [0x0607, 0x0040, 0x1405, 0x0200, 0x02AB] {
            do {
                _ = try Gaia3Packet(commandID: badCmd).encode()
                expect(false, "Gaia3Packet denylist must block 0x\(String(badCmd, radix: 16))")
            } catch Momentum4ProtocolError.denylistedCommandBlocked {
                // expected
            } catch {
                expect(false, "Unexpected Gaia3Packet error: \(error)")
            }
        }

        let resp1 = try! GaiaSPP.frame(try! Gaia3Packet(commandID: Momentum4Commands.getBatteryResponse, payload: Data([87])).encode())
        let resp2 = try! GaiaSPP.frame(try! Gaia3Packet(commandID: Momentum4Commands.getSoundModeResponse, payload: Data([0x00, 0x01])).encode())
        var deframer = GaiaSPPDeframer()
        // Feed leading noise + split across chunks + coalesced second frame
        let combined = Data([0x00, 0x12]) + resp1 + resp2
        let splitIdx = combined.count / 2
        let out1 = deframer.ingest(combined.prefix(splitIdx))
        let out2 = deframer.ingest(combined.dropFirst(splitIdx))
        let allFrames = out1 + out2
        expect(allFrames.count == 2, "GaiaSPPDeframer resynced & emitted 2 coalesced packets")
        let parsedResp1 = try! Gaia3Packet(data: allFrames[0])
        let parsedResp2 = try! Gaia3Packet(data: allFrames[1])
        expect(try! Momentum4ControlCodec.parseBattery(parsedResp1.payload) == 87, "Battery decoded 87%")
        expect(try! Momentum4ControlCodec.parseSoundMode(parsedResp2.payload) == .equalizer, "Sound mode decoded .equalizer")

        // Decode EQ config & bands -> Guardian G-04 non-flat detection
        let eqCfg = try! Momentum4ControlCodec.parseEqConfig(Data([5, UInt8(bitPattern: Int8(-60)), UInt8(bitPattern: Int8(60))]))
        expect(eqCfg.bandCount == 5 && abs(eqCfg.minimumGainDB - (-6.0)) < 0.001, "EqConfig parsed 5 bands -6..+6 dB")
        let band0 = try! Momentum4ControlCodec.parseEqBand(Data([0, UInt8(bitPattern: Int8(25))]), requestedBand: 0)
        let band1 = try! Momentum4ControlCodec.parseEqBand(Data([1, UInt8(bitPattern: Int8(-32))]), requestedBand: 1)
        expect(abs(band0.gainDB - 2.5) < 0.001 && abs(band1.gainDB - (-3.2)) < 0.001, "EqBand tenths dB parsed")
        expect(!Momentum4ControlCodec.isInternalEQNonFlat(soundMode: .off, eqBands: [band0], bassBoostEnabled: false), "SoundMode off + no bass boost is flat")
        expect(Momentum4ControlCodec.isInternalEQNonFlat(soundMode: .equalizer, eqBands: [band0], bassBoostEnabled: false), "Equalizer with +2.5 dB triggers G-04")
        expect(Momentum4ControlCodec.isInternalEQNonFlat(soundMode: .equalizer, eqBands: [], bassBoostEnabled: true), "Bass Boost triggers G-04")
        print("  [PASS] Verified GaiaSPPDeframer, Gaia3Packet, M4 control codecs & G-04 check")

        // 3. HALManager live enumeration & snapshot safety
        let hal = HALManager()
        hal.captureInitialSnapshotIfNeeded()
        let devices = hal.enumerateDevices()
        expect(!devices.isEmpty, "HAL enumerated host audio devices (\(devices.count))")
        hal.restoreSnapshotIfModified()
        print("  [PASS] HALManager enumerated \(devices.count) local audio devices")

        // 4. OrphanedTapCleanup UID matching & safe cleanup + ProcessTapEngine P1 invariant
        let leakedUID = "\(ProcessTapEngine.aggregateUIDPrefix)1234-5678"
        let activeUID = "\(ProcessTapEngine.aggregateUIDPrefix)active-9999"
        expect(OrphanedTapCleanup.isOrphanedAggregateUID(leakedUID, activeUIDs: [activeUID]), "Matches leaked timbr aggregate UID")
        expect(!OrphanedTapCleanup.isOrphanedAggregateUID(activeUID, activeUIDs: [activeUID]), "Skips currently active aggregate UID")
        expect(!OrphanedTapCleanup.isOrphanedAggregateUID("com.apple.audio.AggregateDevice.1", activeUIDs: []), "Never touches non-timbr aggregates")
        _ = OrphanedTapCleanup.cleanupOrphanedAggregates()

        let engine = ProcessTapEngine(sampleRate: 48000)
        let ok = engine.reconcileTap(processingEnabled: false, outputDevice: devices.first, needsDestinationTap: false, excludedBundleIDs: [])
        expect(ok, "P1 reconcile 0 taps cleanly")
        let bands = [EQBand(type: .peak, design: .vicanek, layer: .taste, freqHz: 1000, gainDB: 6.0, q: 1.4)]
        let curve = engine.evaluateCurve(bands: bands, freqsHz: [100, 1000, 10000])
        expect(curve.magDB.count == 3 && abs(curve.magDB[1] - 6.0) < 0.2, "Curve evaluated accurately at 1 kHz")
        expect(curve.recommendedPreampDB < -5.5, "Recommended preamp includes phase margin")
        engine.stopAndDestroyTap()
        print("  [PASS] OrphanedTapCleanup, ProcessTapEngine P1 invariant & curve metrology")

        // 5. CompetingNotchDetector safe scan
        _ = CompetingNotchDetector.detectRunningCompetitors()
        print("  [PASS] CompetingNotchDetector scan")

        print("[TimbreEngineTests] ALL PASSED")
    }
}
