// SPDX-License-Identifier: MPL-2.0
import Foundation
import IOBluetooth
import TimbreCore

public enum Momentum4ProtocolError: Error, Equatable, Sendable {
    case denylistedCommandBlocked(UInt16)
    case invalidPacketLength
    case invalidHeader
    case unsupportedFirmwareForGen2EQ(String)
}

public struct GAIAv3Packet: Equatable, Sendable {
    public static let sof: UInt8 = 0xFF
    public static let version: UInt8 = 0x01
    public static let sennheiserVendorID: UInt16 = 0x0495

    public let flags: UInt8
    public let featureID: UInt8
    public let pduType: UInt8 // 0x00 command, 0x01 response, 0x02 notification
    public let pduID: UInt8
    public let payload: [UInt8]

    public var commandCode: UInt16 {
        (UInt16(featureID) << 8) | UInt16(pduID)
    }

    public init(flags: UInt8 = 0x00, featureID: UInt8, pduType: UInt8 = 0x00, pduID: UInt8, payload: [UInt8] = []) {
        self.flags = flags
        self.featureID = featureID
        self.pduType = pduType
        self.pduID = pduID
        self.payload = payload
    }

    // Hard safety denylist from 07_momentum4_protocolo_e_ecossistema.md & momentum4-laboratorio.md
    public static let denylistedCommandCodes: Set<UInt16> = [
        0x0607, // Factory reset / destructive disconnect in some firmwares
        0x0040, // Pairing list clear
        0x1405  // Persistent calibration reset
    ]

    public static func isDenylisted(featureID: UInt8, pduID: UInt8) -> Bool {
        if featureID == 0x02 { return true } // Upgrade / DFU feature 0x02xx strictly forbidden
        let code = (UInt16(featureID) << 8) | UInt16(pduID)
        return denylistedCommandCodes.contains(code)
    }

    public func encode() throws -> [UInt8] {
        guard !Self.isDenylisted(featureID: featureID, pduID: pduID) else {
            throw Momentum4ProtocolError.denylistedCommandBlocked(commandCode)
        }
        guard payload.count <= 240 else { throw Momentum4ProtocolError.invalidPacketLength }
        var bytes: [UInt8] = [
            Self.sof,
            Self.version,
            flags,
            UInt8(payload.count),
            UInt8((Self.sennheiserVendorID >> 8) & 0xFF),
            UInt8(Self.sennheiserVendorID & 0xFF),
            featureID,
            UInt8(((pduType & 0x0F) << 4) | (pduID & 0x0F))
        ]
        bytes.append(contentsOf: payload)
        return bytes
    }

    public static func decode(_ bytes: [UInt8]) throws -> GAIAv3Packet {
        guard bytes.count >= 8 else { throw Momentum4ProtocolError.invalidPacketLength }
        guard bytes[0] == sof, bytes[1] == version else { throw Momentum4ProtocolError.invalidHeader }
        let len = Int(bytes[3])
        guard bytes.count >= 8 + len else { throw Momentum4ProtocolError.invalidPacketLength }
        let featureID = bytes[6]
        let pduByte = bytes[7]
        let pduType = (pduByte >> 4) & 0x0F
        let pduID = pduByte & 0x0F
        let payload = Array(bytes[8..<(8 + len)])
        return GAIAv3Packet(flags: bytes[2], featureID: featureID, pduType: pduType, pduID: pduID, payload: payload)
    }
}

public enum Momentum4FirmwareGate {
    // Gen2 5-band EQ on 0x1002 requires firmware >= 3.18.0
    public static func supportsGen2EQ(firmwareVersion: String) -> Bool {
        let parts = firmwareVersion.split(separator: ".").compactMap { Int($0) }
        guard parts.count >= 2 else { return false }
        if parts[0] > 3 { return true }
        if parts[0] < 3 { return false }
        return parts[1] >= 18
    }

    public static func eqFeatureCommand(firmwareVersion: String) -> (featureID: UInt8, pduID: UInt8) {
        supportsGen2EQ(firmwareVersion: firmwareVersion) ? (0x10, 0x02) : (0x04, 0x01)
    }
}

public protocol HeadphoneDeviceDriver: Sendable {
    var driverID: String { get }
    func matches(device: AudioDeviceDescriptor) -> Bool
    func readTelemetry(for device: AudioDeviceDescriptor) -> HardwareDriverTelemetry
}

public final class Momentum4Driver: HeadphoneDeviceDriver, @unchecked Sendable {
    public let driverID = "sennheiser-momentum4-gaia-v3"
    public static let gaiaServiceUUIDString = "A2129FF3-081B-4C45-8AFE-469D9C4842EC"

    public init() {}

    public func matches(device: AudioDeviceDescriptor) -> Bool {
        device.name.localizedCaseInsensitiveContains("MOMENTUM 4")
    }

    public func readTelemetry(for device: AudioDeviceDescriptor) -> HardwareDriverTelemetry {
        // Check paired/connected IOBluetooth devices safely without forcing RFCOMM write
        let paired = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
        guard let btDev = paired.first(where: { ($0.name ?? "").localizedCaseInsensitiveContains("MOMENTUM 4") }) else {
            return HardwareDriverTelemetry(
                driverName: "Sennheiser Momentum 4 (GAIA v3)",
                connectionStatus: device.transport == .usb ? "usb-uac1-read-only" : "not-paired"
            )
        }
        let connected = btDev.isConnected()
        let codecHint = device.transport == .usb ? "USB-C UAC 1.0 (16-bit/48 kHz)" : "Bluetooth (macOS reported)"
        return HardwareDriverTelemetry(
            driverName: "Sennheiser Momentum 4 (GAIA v3)",
            batteryPercent: nil, // Populated once RFCOMM E-09 read handshake completes in GUI session
            firmwareVersion: nil,
            ancEnabled: nil,
            internalEQNonFlat: nil,
            reportedCodec: codecHint,
            connectionStatus: connected ? "connected-ready-for-read" : "paired-disconnected"
        )
    }
}

public final class AirPodsProAdapter: HeadphoneDeviceDriver, @unchecked Sendable {
    public let driverID = "apple-airpods-pro-hal"

    public init() {}

    public func matches(device: AudioDeviceDescriptor) -> Bool {
        device.name.localizedCaseInsensitiveContains("AirPods Pro")
    }

    public func readTelemetry(for device: AudioDeviceDescriptor) -> HardwareDriverTelemetry {
        HardwareDriverTelemetry(
            driverName: "AirPods Pro (HAL)",
            reportedCodec: "AAC (Apple AudioAccessory)",
            connectionStatus: "hal-observed-aacp-closed"
        )
    }
}
