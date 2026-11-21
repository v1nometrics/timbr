// SPDX-License-Identifier: MPL-2.0
//
// Apple Audio Accessory family (AirPods / AirPods Pro / AirPods Max / Beats H1–H2)
// Strategy on macOS Developer ID (ADR-0011 + Nota 07 §4 / airpods-laboratorio):
//   • HAL Core Audio: device match, transport, sample rate, anti-HFP (G-01) — Comprovado
//   • Continuity BLE proximity-pairing (manufacturer 0x004C, type 0x07): passive L/R/Case
//     battery when the lid is open — public RE (furiousMAC/continuity); MIT study refs
//     apple-ble / mubar — reimplemented independently (zero GPL/AGPL / zero LibrePods code)
//   • AACP over L2CAP 0x1001 (ANC / Transparency / head gestures): INVÁVEL em user-space
//     macOS (bluetoothd + entitlements privados; LibrePods GPL-3.0 só Linux/Android)
//   • MagicAccIRK/EncKey decryption: NÃO — exige AACP 0x30/0x31 (bloqueado)
import Foundation
import CoreBluetooth
import TimbreCore

// MARK: - Family & Continuity (pure, testable)

public enum AppleAudioAccessoryKind: String, Codable, Sendable, CaseIterable {
    case airPods
    case airPodsPro
    case airPodsMax
    case beats
    case unknown

    public var displayName: String {
        switch self {
        case .airPods: return "AirPods"
        case .airPodsPro: return "AirPods Pro"
        case .airPodsMax: return "AirPods Max"
        case .beats: return "Beats"
        case .unknown: return "Apple Audio Accessory"
        }
    }

    public var sfSymbolName: String {
        switch self {
        case .airPods: return "airpods"
        case .airPodsPro: return "airpods.pro"
        case .airPodsMax: return "airpodsmax"
        case .beats: return "beats.headphones"
        case .unknown: return "headphones"
        }
    }
}

public struct ContinuityProximitySnapshot: Equatable, Sendable {
    public let modelID: UInt16
    public let kind: AppleAudioAccessoryKind
    public let modelName: String
    public let leftBatteryPercent: Int?
    public let rightBatteryPercent: Int?
    public let caseBatteryPercent: Int?
    public let leftCharging: Bool
    public let rightCharging: Bool
    public let caseCharging: Bool
    public let statusByte: UInt8
    public let colorByte: UInt8

    public var combinedBatteryPercent: Int? {
        let pods = [leftBatteryPercent, rightBatteryPercent].compactMap { $0 }
        guard !pods.isEmpty else { return caseBatteryPercent }
        return pods.reduce(0, +) / pods.count
    }
}

/// Independent reimplementation of Apple Continuity proximity-pairing (type `0x07`)
/// manufacturer payload layout documented by furiousMAC/continuity (public RE).
/// Does **not** decrypt the trailing AES blob (requires MagicAccEncKey via AACP).
public enum ContinuityProximityParser {
    public static let appleCompanyID: UInt16 = 0x004C
    public static let proximityPairingType: UInt8 = 0x07

    public static func parseManufacturerPayload(_ data: Data) -> ContinuityProximitySnapshot? {
        // Expected: [type=0x07][len][0x01][modelHi][modelLo][status][batt][chg|case][lid][color][0x00][+enc16?]
        // Some stacks strip type/len and pass only the inner body starting at 0x01.
        guard data.count >= 8 else { return nil }

        let body: Data
        if data[0] == proximityPairingType, data.count >= 10 {
            let len = Int(data[1])
            guard len >= 8, data.count >= 2 + len else { return nil }
            body = data.subdata(in: 2..<(2 + len))
        } else if data[0] == 0x01 {
            body = data
        } else {
            return nil
        }
        // Minimum: prefix + model(2) + status + batt + chg/case + lid + color
        guard body.count >= 8, body[0] == 0x01 else { return nil }

        let modelID = (UInt16(body[1]) << 8) | UInt16(body[2])
        let status = body[3]
        let battByte = body[4]
        let chgCase = body[5]
        let color = body.count > 7 ? body[7] : 0

        // Nibbles are 0...10 → 0...100% in 10% steps; 0xF = unknown / not present
        func nibblePercent(_ nibble: UInt8) -> Int? {
            let v = Int(nibble & 0x0F)
            if v >= 0x0F { return nil }
            return min(100, v * 10)
        }

        // Convention used across public Continuity dumps: high nibble = right, low = left
        let right = nibblePercent(battByte >> 4)
        let left = nibblePercent(battByte)
        let caseBatt = nibblePercent(chgCase)
        let rightCharging = (chgCase & 0x20) != 0
        let leftCharging = (chgCase & 0x10) != 0
        let caseCharging = (chgCase & 0x40) != 0

        let (kind, name) = modelLookup(modelID)
        return ContinuityProximitySnapshot(
            modelID: modelID,
            kind: kind,
            modelName: name,
            leftBatteryPercent: left,
            rightBatteryPercent: right,
            caseBatteryPercent: caseBatt,
            leftCharging: leftCharging,
            rightCharging: rightCharging,
            caseCharging: caseCharging,
            statusByte: status,
            colorByte: color
        )
    }

    public static func modelLookup(_ modelID: UInt16) -> (AppleAudioAccessoryKind, String) {
        switch modelID {
        case 0x0220: return (.airPods, "AirPods (1st generation)")
        case 0x0F20: return (.airPods, "AirPods (2nd generation)")
        case 0x1320: return (.airPods, "AirPods (3rd generation)")
        case 0x1920: return (.airPods, "AirPods (4th generation)")
        case 0x0E20: return (.airPodsPro, "AirPods Pro (1st generation)")
        case 0x1420, 0x2420: return (.airPodsPro, "AirPods Pro (2nd generation)")
        case 0x2720: return (.airPodsPro, "AirPods Pro (2nd generation, USB-C)")
        case 0x0A20, 0x1F20: return (.airPodsMax, "AirPods Max")
        case 0x2002, 0x200F, 0x2012, 0x2013, 0x2014:
            return (.beats, "Beats (H1/H2 Continuity)")
        default:
            return (.unknown, String(format: "Apple accessory 0x%04X", modelID))
        }
    }
}

// MARK: - CoreBluetooth passive scanner (thread-safe cache)

public final class ContinuityBLEScanner: NSObject, CBCentralManagerDelegate, @unchecked Sendable {
    public static let shared = ContinuityBLEScanner()

    private let lock = NSLock()
    private var central: CBCentralManager?
    private var latestByModel: [UInt16: ContinuityProximitySnapshot] = [:]
    private var started = false
    public private(set) var bluetoothPoweredOn: Bool = false

    private override init() {
        super.init()
    }

    public func ensureStarted() {
        lock.lock()
        defer { lock.unlock() }
        guard !started else { return }
        started = true
        central = CBCentralManager(delegate: self, queue: DispatchQueue(label: "dev.v1torres.timbr.continuity"), options: [
            CBCentralManagerOptionShowPowerAlertKey: false
        ])
    }

    public func latest(matching kind: AppleAudioAccessoryKind? = nil) -> ContinuityProximitySnapshot? {
        lock.lock()
        let values = Array(latestByModel.values)
        lock.unlock()
        if let kind {
            return values.first(where: { $0.kind == kind })
                ?? values.sorted(by: { ($0.combinedBatteryPercent ?? -1) > ($1.combinedBatteryPercent ?? -1) }).first
        }
        return values.sorted(by: { ($0.combinedBatteryPercent ?? -1) > ($1.combinedBatteryPercent ?? -1) }).first
    }

    public func ingestForTesting(_ snap: ContinuityProximitySnapshot) {
        lock.lock()
        latestByModel[snap.modelID] = snap
        lock.unlock()
    }

    private func startScanIfReady(_ central: CBCentralManager) {
        guard central.state == .poweredOn else { return }
        bluetoothPoweredOn = true
        central.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: true
        ])
    }

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothPoweredOn = central.state == .poweredOn
        if central.state == .poweredOn {
            startScanIfReady(central)
        }
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard let mfg = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data,
              mfg.count >= 4 else { return }
        let company = UInt16(mfg[0]) | (UInt16(mfg[1]) << 8)
        guard company == ContinuityProximityParser.appleCompanyID else { return }
        let payload = mfg.subdata(in: 2..<mfg.count)
        guard let snap = ContinuityProximityParser.parseManufacturerPayload(payload) else { return }
        lock.lock()
        latestByModel[snap.modelID] = snap
        lock.unlock()
    }
}

// MARK: - Driver

public final class AirPodsProAdapter: HeadphoneDeviceDriver, @unchecked Sendable {
    public let driverID = "apple-audio-accessory-hal-continuity"

    public init() {}

    public func matches(device: AudioDeviceDescriptor) -> Bool {
        Self.classify(deviceName: device.name) != .unknown
    }

    public static func classify(deviceName: String) -> AppleAudioAccessoryKind {
        let n = deviceName.lowercased()
        if n.contains("airpods max") { return .airPodsMax }
        if n.contains("airpods pro") { return .airPodsPro }
        if n.contains("airpods") { return .airPods }
        if n.contains("beats") && (
            n.contains("studio") || n.contains("fit") || n.contains("solo")
                || n.contains("powerbeats") || n.contains("headphones") || n.contains("earbuds")
        ) {
            return .beats
        }
        return .unknown
    }

    public func readTelemetry(for device: AudioDeviceDescriptor) -> HardwareDriverTelemetry {
        let kind = Self.classify(deviceName: device.name)
        ContinuityBLEScanner.shared.ensureStarted()

        let transportHint: String
        switch device.transport {
        case .bluetoothA2DP: transportHint = "AAC (A2DP)"
        case .bluetoothHFP: transportHint = "HFP/SCO (degraded)"
        case .builtIn: transportHint = "Built-in path"
        case .usb: transportHint = "USB / host path"
        default: transportHint = device.transport.rawValue
        }

        let continuity = ContinuityBLEScanner.shared.latest(matching: kind == .unknown ? nil : kind)
        let spatialWarning = device.transport == .bluetoothA2DP
        let trust: SignalTrustBadge = continuity != nil ? .reported : .inferred

        let status: String
        if device.transport == .bluetoothHFP {
            status = "hfp-degraded"
        } else if continuity != nil {
            status = "hal+continuity-proximity"
        } else {
            status = "hal-observed · aacp-closed"
        }

        let left = continuity?.leftBatteryPercent
        let right = continuity?.rightBatteryPercent
        let caseBatt = continuity?.caseBatteryPercent
        let combined = continuity?.combinedBatteryPercent
            ?? [left, right].compactMap { $0 }.min()

        return HardwareDriverTelemetry(
            driverName: "\(kind.displayName) (HAL + Continuity)",
            batteryPercent: combined,
            batteryLeftPercent: left,
            batteryRightPercent: right,
            batteryCasePercent: caseBatt,
            isCharging: continuity.map { $0.leftCharging || $0.rightCharging || $0.caseCharging },
            leftCharging: continuity?.leftCharging,
            rightCharging: continuity?.rightCharging,
            caseCharging: continuity?.caseCharging,
            firmwareVersion: nil,
            ancEnabled: nil, // AACP closed — never invent ANC state (P11)
            transparencyPercent: nil,
            internalEQNonFlat: false,
            reportedCodec: transportHint,
            accessoryFamily: kind.rawValue,
            modelIdentifier: continuity?.modelName ?? kind.displayName,
            spatialAudioMayAlterFR: spatialWarning,
            trustBadge: trust,
            connectionStatus: status
        )
    }
}
