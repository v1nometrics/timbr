// SPDX-License-Identifier: MPL-2.0
//
// Apple Audio Accessory family (AirPods → AirPods Max 2 / Beats H1–H2)
// Strategy on macOS Developer ID (ADR-0011 + airpods-laboratorio + Nota 12):
//   • HAL Core Audio: match, transport, anti-HFP (G-01) — Comprovado
//   • Continuity BLE proximity (0x004C / type 0x07): L/R/Case, in-ear, lid — public RE
//     (furiousMAC, cidermill-apple-ble, CAPod consensus); MIT study refs apple-ble / mubar
//     — reimplemented independently (zero GPL/AGPL / zero LibrePods code)
//   • AACP L2CAP 0x1001 (ANC, Adaptive Audio, Conversation Awareness, Hearing Aid EQ):
//     INVÁVEL em user-space macOS — UI declara features como systemManaged (P11)
//   • MagicAccIRK/EncKey: NÃO (exige AACP 0x30/0x31)
import Foundation
import CoreBluetooth
import TimbreCore

// MARK: - Family

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

/// Features of interest on recent AirPods firmware — all system-owned on macOS (no AACP).
public enum AppleSystemManagedFeature: String, Codable, Sendable, CaseIterable {
    case activeNoiseCancellation
    case transparency
    case adaptiveAudio
    case conversationAwareness
    case personalizedSpatialAudio
    case hearingAid
    case hearingTest
    case hearingProtection
    case voiceIsolation

    public var localizationKey: String { "dev.apple.feature.\(rawValue)" }
}

public struct AppleModelCapabilityProfile: Sendable, Equatable {
    public let kind: AppleAudioAccessoryKind
    public let marketingName: String
    public let systemManagedFeatures: Set<AppleSystemManagedFeature>
    public let supportsContinuityBattery: Bool
    public let autoEqCatalogHints: [String]

    public static func profile(forModelID modelID: UInt16, kind: AppleAudioAccessoryKind, name: String) -> AppleModelCapabilityProfile {
        // Feature sets mirror Apple's public compare matrix (2024–2026). None are controllable via AACP here.
        let ancFamily: Set<AppleSystemManagedFeature> = [
            .activeNoiseCancellation, .transparency, .adaptiveAudio,
            .conversationAwareness, .personalizedSpatialAudio, .voiceIsolation
        ]
        let hearingPro: Set<AppleSystemManagedFeature> = ancFamily.union([
            .hearingAid, .hearingTest, .hearingProtection
        ])
        switch modelID {
        case 0x1920: // AirPods 4
            return AppleModelCapabilityProfile(
                kind: .airPods, marketingName: name,
                systemManagedFeatures: [.personalizedSpatialAudio, .voiceIsolation],
                supportsContinuityBattery: true,
                autoEqCatalogHints: ["airpods", "4"]
            )
        case 0x1B20: // AirPods 4 ANC
            return AppleModelCapabilityProfile(
                kind: .airPods, marketingName: name,
                systemManagedFeatures: ancFamily,
                supportsContinuityBattery: true,
                autoEqCatalogHints: ["airpods", "4"]
            )
        case 0x0E20: // Pro 1
            return AppleModelCapabilityProfile(
                kind: .airPodsPro, marketingName: name,
                systemManagedFeatures: [
                    .activeNoiseCancellation, .transparency,
                    .personalizedSpatialAudio, .voiceIsolation
                ],
                supportsContinuityBattery: true,
                autoEqCatalogHints: ["airpods pro"]
            )
        case 0x1420, 0x2420: // Pro 2 Lightning / USB-C
            return AppleModelCapabilityProfile(
                kind: .airPodsPro, marketingName: name,
                systemManagedFeatures: hearingPro,
                supportsContinuityBattery: true,
                autoEqCatalogHints: ["airpods pro", "2"]
            )
        case 0x2720: // Pro 3
            return AppleModelCapabilityProfile(
                kind: .airPodsPro, marketingName: name,
                systemManagedFeatures: hearingPro,
                supportsContinuityBattery: true,
                autoEqCatalogHints: ["airpods pro", "3"]
            )
        case 0x0A20, 0x1F20: // Max / Max USB-C (Max 2 shares Continuity family)
            return AppleModelCapabilityProfile(
                kind: .airPodsMax, marketingName: name,
                systemManagedFeatures: ancFamily.union([.hearingProtection]),
                supportsContinuityBattery: true,
                autoEqCatalogHints: ["airpods max"]
            )
        default:
            var features: Set<AppleSystemManagedFeature> = [.personalizedSpatialAudio]
            if kind == .airPodsPro || kind == .airPodsMax {
                features.formUnion([.activeNoiseCancellation, .transparency])
            }
            return AppleModelCapabilityProfile(
                kind: kind, marketingName: name,
                systemManagedFeatures: features,
                supportsContinuityBattery: kind != .unknown,
                autoEqCatalogHints: [kind.displayName.lowercased()]
            )
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
    public let leftInEar: Bool?
    public let rightInEar: Bool?
    public let lidOpen: Bool?
    public let statusByte: UInt8
    public let colorByte: UInt8
    public let capabilityProfile: AppleModelCapabilityProfile

    public var combinedBatteryPercent: Int? {
        let pods = [leftBatteryPercent, rightBatteryPercent].compactMap { $0 }
        guard !pods.isEmpty else { return caseBatteryPercent }
        return pods.reduce(0, +) / pods.count
    }
}

/// Clean-room Continuity proximity-pairing (type `0x07`) parser.
/// Layout consensus: furiousMAC + cidermill-apple-ble + CAPod / PodBridge research notes.
public enum ContinuityProximityParser {
    public static let appleCompanyID: UInt16 = 0x004C
    public static let proximityPairingType: UInt8 = 0x07

    public static func parseManufacturerPayload(_ data: Data) -> ContinuityProximitySnapshot? {
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
        guard body.count >= 8, body[0] == 0x01 else { return nil }

        // Model bytes appear on-air as 0xNN20 (BE when read as UInt16 big-endian)
        let modelID = (UInt16(body[1]) << 8) | UInt16(body[2])
        let status = body[3]
        let battByte = body[4]
        let chgCase = body[5]
        let lidByte = body.count > 6 ? body[6] : 0
        let color = body.count > 7 ? body[7] : 0

        // Primary/secondary flip: status bit5 == 1 → primary is left
        let primaryIsLeft = (status & 0x20) != 0

        func nibblePercent(_ nibble: UInt8) -> Int? {
            let v = Int(nibble & 0x0F)
            if v == 0x0F { return nil }
            if v == 0x0A { return 100 }
            if v > 0x0A { return nil }
            return min(100, v * 10)
        }

        let primaryBatt = nibblePercent(battByte)
        let secondaryBatt = nibblePercent(battByte >> 4)
        let leftBatt = primaryIsLeft ? primaryBatt : secondaryBatt
        let rightBatt = primaryIsLeft ? secondaryBatt : primaryBatt

        let caseBatt = nibblePercent(chgCase)
        let primaryCharging = (chgCase & 0x10) != 0
        let secondaryCharging = (chgCase & 0x20) != 0
        let caseCharging = (chgCase & 0x40) != 0
        let leftCharging = primaryIsLeft ? primaryCharging : secondaryCharging
        let rightCharging = primaryIsLeft ? secondaryCharging : primaryCharging

        // In-ear: bit1 primary, bit3 secondary (with flip)
        let primaryInEar = (status & 0x02) != 0
        let secondaryInEar = (status & 0x08) != 0
        let leftInEar = primaryIsLeft ? primaryInEar : secondaryInEar
        let rightInEar = primaryIsLeft ? secondaryInEar : primaryInEar

        // Lid: bit3 of lid byte == 1 → closed (only trustworthy for in-case ads)
        let inCaseBroadcast = (status & 0x44) != 0
        let lidOpen: Bool? = inCaseBroadcast ? ((lidByte & 0x08) == 0) : nil

        let (kind, name) = modelLookup(modelID)
        let profile = AppleModelCapabilityProfile.profile(forModelID: modelID, kind: kind, name: name)

        return ContinuityProximitySnapshot(
            modelID: modelID,
            kind: kind,
            modelName: name,
            leftBatteryPercent: leftBatt,
            rightBatteryPercent: rightBatt,
            caseBatteryPercent: caseBatt,
            leftCharging: leftCharging,
            rightCharging: rightCharging,
            caseCharging: caseCharging,
            leftInEar: leftInEar,
            rightInEar: rightInEar,
            lidOpen: lidOpen,
            statusByte: status,
            colorByte: color,
            capabilityProfile: profile
        )
    }

    public static func modelLookup(_ modelID: UInt16) -> (AppleAudioAccessoryKind, String) {
        // Table: cidermill-apple-ble / CAPod / LibrePods public model maps (facts only).
        switch modelID {
        case 0x0220: return (.airPods, "AirPods (1st generation)")
        case 0x0F20: return (.airPods, "AirPods (2nd generation)")
        case 0x1320: return (.airPods, "AirPods (3rd generation)")
        case 0x1920: return (.airPods, "AirPods 4")
        case 0x1B20: return (.airPods, "AirPods 4 (ANC)")
        case 0x0E20: return (.airPodsPro, "AirPods Pro (1st generation)")
        case 0x1420: return (.airPodsPro, "AirPods Pro 2")
        case 0x2420: return (.airPodsPro, "AirPods Pro 2 (USB-C)")
        case 0x2720: return (.airPodsPro, "AirPods Pro 3")
        case 0x0A20: return (.airPodsMax, "AirPods Max")
        case 0x1F20: return (.airPodsMax, "AirPods Max (USB-C)")
        case 0x2002, 0x200F, 0x2012, 0x2013, 0x2014:
            return (.beats, "Beats (H1/H2 Continuity)")
        default:
            return (.unknown, String(format: "Apple accessory 0x%04X", modelID))
        }
    }
}

// MARK: - CoreBluetooth passive scanner

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
        let filtered: [ContinuityProximitySnapshot]
        if let kind {
            let exact = values.filter { $0.kind == kind }
            filtered = exact.isEmpty ? values : exact
        } else {
            filtered = values
        }
        return filtered.sorted(by: { ($0.combinedBatteryPercent ?? -1) > ($1.combinedBatteryPercent ?? -1) }).first
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

        let profile = continuity?.capabilityProfile
            ?? AppleModelCapabilityProfile.profile(forModelID: 0, kind: kind, name: kind.displayName)

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
            systemManagedFeatureKeys: profile.systemManagedFeatures.map(\.rawValue).sorted(),
            trustBadge: trust,
            connectionStatus: status
        )
    }
}
