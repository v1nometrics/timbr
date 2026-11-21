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

        // 1. GAIA v3 packet encode/decode & safety denylist (0x0607, 0x02xx DFU)
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
        print("  [PASS] GAIA v3 codec, safety denylist & FW 3.18.0 gate")

        // 2. HALManager live enumeration & snapshot safety
        let hal = HALManager()
        hal.captureInitialSnapshotIfNeeded()
        let devices = hal.enumerateDevices()
        expect(!devices.isEmpty, "HAL enumerated host audio devices (\(devices.count))")
        hal.restoreSnapshotIfModified()
        print("  [PASS] HALManager enumerated \(devices.count) local audio devices")

        // 3. ProcessTapEngine P1 invariant (0 taps when disabled) & curve evaluation
        let engine = ProcessTapEngine(sampleRate: 48000)
        let ok = engine.reconcileTap(processingEnabled: false, outputDevice: devices.first, needsDestinationTap: false, excludedBundleIDs: [])
        expect(ok, "P1 reconcile 0 taps cleanly")
        let bands = [EQBand(type: .peak, design: .vicanek, layer: .taste, freqHz: 1000, gainDB: 6.0, q: 1.4)]
        let curve = engine.evaluateCurve(bands: bands, freqsHz: [100, 1000, 10000])
        expect(curve.magDB.count == 3 && abs(curve.magDB[1] - 6.0) < 0.2, "Curve evaluated accurately at 1 kHz")
        expect(curve.recommendedPreampDB < -5.5, "Recommended preamp includes phase margin")
        engine.stopAndDestroyTap()
        print("  [PASS] ProcessTapEngine P1 invariant & curve metrology")

        // 4. CompetingNotchDetector safe scan
        _ = CompetingNotchDetector.detectRunningCompetitors()
        print("  [PASS] CompetingNotchDetector scan")

        print("[TimbreEngineTests] ALL PASSED")
    }
}
