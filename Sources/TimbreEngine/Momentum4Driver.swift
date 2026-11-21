// SPDX-License-Identifier: MPL-2.0
// Includes GAIA v3 SPP framing, opcodes, and IOBluetooth RFCOMM read flow
// adapted from Zhengyang-Liu/m4-companion (MIT License). See NOTICE.
import Foundation
import IOBluetooth
import TimbreCore

public enum Momentum4ProtocolError: Error, Equatable, Sendable {
    case denylistedCommandBlocked(UInt16)
    case invalidPacketLength
    case invalidHeader
    case payloadTooLarge
    case unsupportedFirmwareForGen2EQ(String)
    case malformedControlPayload(command: UInt16)
    case invalidControlValue(command: UInt16, value: UInt8)
    case invalidBatteryPercentage(UInt8)
    case headsetNotPaired
    case notConnected
    case ambiguousHeadsets
    case serviceUnavailable
    case connectionTimedOut
    case responseTimedOut(UInt16)
    case rfcommFailure(Int32)
}

public enum Momentum4CommandSafety {
    // Hard safety denylist from 07_momentum4_protocolo_e_ecossistema.md & momentum4-laboratorio.md
    public static let denylistedCommandCodes: Set<UInt16> = [
        0x0607, // Factory reset / destructive disconnect in some firmwares
        0x0040, // Pairing list clear
        0x1405  // Persistent calibration reset
    ]

    public static func isDenylisted(commandCode: UInt16) -> Bool {
        let featureID = UInt8((commandCode >> 8) & 0xFF)
        if featureID == 0x02 { return true } // Upgrade / DFU feature 0x02xx strictly forbidden
        return denylistedCommandCodes.contains(commandCode)
    }

    public static func isDenylisted(featureID: UInt8, pduID: UInt8) -> Bool {
        let code = (UInt16(featureID) << 8) | UInt16(pduID)
        return isDenylisted(commandCode: code)
    }
}

public enum Momentum4Commands {
    public static let vendorID: UInt16 = 0x0495

    // Strictly read-only telemetry opcodes verified against Momentum 4 firmware (m4-companion)
    public static let getBattery: UInt16 = 0x0603
    public static let getBatteryResponse: UInt16 = 0x0703

    public static let getBluetoothCompatibilityMode: UInt16 = 0x0406
    public static let getBluetoothCompatibilityModeResponse: UInt16 = 0x0506

    public static let getSoundMode: UInt16 = 0x0804
    public static let getSoundModeResponse: UInt16 = 0x0904

    public static let getAncModes: UInt16 = 0x1a01
    public static let getAncModesResponse: UInt16 = 0x1b01
    public static let getTransparencyLevel: UInt16 = 0x1a03
    public static let getTransparencyLevelResponse: UInt16 = 0x1b03
    public static let getAncEnabled: UInt16 = 0x1a05
    public static let getAncEnabledResponse: UInt16 = 0x1b05

    public static let getTransparentHearing: UInt16 = 0x1805
    public static let getTransparentHearingResponse: UInt16 = 0x1905

    public static let getEqConfig: UInt16 = 0x1000
    public static let getEqConfigResponse: UInt16 = 0x1100
    public static let getEqBand: UInt16 = 0x1002
    public static let getEqBandResponse: UInt16 = 0x1102
    public static let getBassBoost: UInt16 = 0x1009
    public static let getBassBoostResponse: UInt16 = 0x1109
}

// MARK: - Verified GAIA v3 Wire Framing (SPP 0xFF 0x03 + 4-byte Vendor/Command Header)

public struct Gaia3Packet: Equatable, Sendable {
    public let vendorID: UInt16
    public let commandID: UInt16
    public let payload: Data

    public init(
        vendorID: UInt16 = Momentum4Commands.vendorID,
        commandID: UInt16,
        payload: Data = Data()
    ) {
        self.vendorID = vendorID
        self.commandID = commandID
        self.payload = payload
    }

    public init(data: Data) throws {
        guard data.count >= 4 else { throw Momentum4ProtocolError.invalidPacketLength }
        let base = data.startIndex
        self.vendorID = (UInt16(data[base]) << 8) | UInt16(data[data.index(base, offsetBy: 1)])
        self.commandID = (UInt16(data[data.index(base, offsetBy: 2)]) << 8) | UInt16(data[data.index(base, offsetBy: 3)])
        self.payload = Data(data.dropFirst(4))
    }

    public func encode() throws -> Data {
        guard !Momentum4CommandSafety.isDenylisted(commandCode: commandID) else {
            throw Momentum4ProtocolError.denylistedCommandBlocked(commandID)
        }
        guard payload.count <= Int(UInt16.max) else {
            throw Momentum4ProtocolError.payloadTooLarge
        }
        return Data([
            UInt8((vendorID >> 8) & 0xFF),
            UInt8(vendorID & 0xFF),
            UInt8((commandID >> 8) & 0xFF),
            UInt8(commandID & 0xFF)
        ]) + payload
    }
}

public enum GaiaSPP {
    public static func frame(_ gaiaPacket: Data) throws -> Data {
        guard gaiaPacket.count >= 4 else { throw Momentum4ProtocolError.invalidPacketLength }
        let payloadLength = gaiaPacket.count - 4
        guard payloadLength <= Int(UInt16.max) else { throw Momentum4ProtocolError.payloadTooLarge }
        return Data([
            0xFF, 0x03,
            UInt8((payloadLength >> 8) & 0xFF),
            UInt8(payloadLength & 0xFF)
        ]) + gaiaPacket
    }
}

public struct GaiaSPPDeframer: Sendable {
    private var buffer = Data()

    public init() {}

    public mutating func ingest(_ incoming: Data) -> [Data] {
        buffer.append(incoming)
        var packets: [Data] = []
        while true {
            while buffer.count >= 2 {
                let first = buffer.startIndex
                let second = buffer.index(after: first)
                guard buffer[first] != 0xFF || buffer[second] != 0x03 else { break }
                buffer.removeFirst()
            }
            guard buffer.count >= 4 else { break }
            let start = buffer.startIndex
            let lengthHigh = buffer[buffer.index(start, offsetBy: 2)]
            let lengthLow = buffer[buffer.index(start, offsetBy: 3)]
            let payloadLength = (Int(lengthHigh) << 8) | Int(lengthLow)
            let frameLength = 8 + payloadLength
            guard buffer.count >= frameLength else { break }
            let packetStart = buffer.index(start, offsetBy: 4)
            let packetEnd = buffer.index(start, offsetBy: frameLength)
            packets.append(Data(buffer[packetStart..<packetEnd]))
            buffer.removeFirst(frameLength)
        }
        return packets
    }
}

// MARK: - Momentum 4 Telemetry & Control Codecs

public enum Momentum4SoundMode: UInt8, Codable, CaseIterable, Sendable {
    case off = 0
    case equalizer = 1
    case podcast = 2
    case soundPersonalization = 3
}

public enum Momentum4BluetoothCompatibilityMode: UInt8, Codable, Sendable {
    case betterAudio = 0
    case betterCompatibility = 1
}

public struct Momentum4EqConfig: Equatable, Codable, Sendable {
    public let bandCount: UInt8
    public let minimumGainDB: Double
    public let maximumGainDB: Double

    public init(bandCount: UInt8, minimumGainDB: Double, maximumGainDB: Double) {
        self.bandCount = bandCount
        self.minimumGainDB = minimumGainDB
        self.maximumGainDB = maximumGainDB
    }
}

public struct Momentum4EqBand: Equatable, Codable, Sendable {
    public let index: UInt8
    public let gainDB: Double

    public init(index: UInt8, gainDB: Double) {
        self.index = index
        self.gainDB = gainDB
    }
}

public enum Momentum4ControlCodec {
    public static func parseBattery(_ payload: Data) throws -> Int {
        guard let value = payload.first else { throw Momentum4ProtocolError.invalidPacketLength }
        guard value <= 100 else { throw Momentum4ProtocolError.invalidBatteryPercentage(value) }
        return Int(value)
    }

    public static func parseSoundMode(_ payload: Data) throws -> Momentum4SoundMode {
        guard payload.count >= 2, payload[payload.startIndex] == 0,
              let mode = Momentum4SoundMode(rawValue: payload[payload.index(after: payload.startIndex)]) else {
            throw Momentum4ProtocolError.malformedControlPayload(command: Momentum4Commands.getSoundMode)
        }
        return mode
    }

    public static func parseBluetoothCompatibilityMode(_ payload: Data) throws -> Momentum4BluetoothCompatibilityMode {
        guard let raw = payload.first, payload.count == 1,
              let mode = Momentum4BluetoothCompatibilityMode(rawValue: raw) else {
            throw Momentum4ProtocolError.malformedControlPayload(command: Momentum4Commands.getBluetoothCompatibilityMode)
        }
        return mode
    }

    public static func parseBoolean(_ payload: Data, command: UInt16) throws -> Bool {
        guard let value = payload.first else {
            throw Momentum4ProtocolError.malformedControlPayload(command: command)
        }
        guard value <= 1 else {
            throw Momentum4ProtocolError.invalidControlValue(command: command, value: value)
        }
        return value == 1
    }

    public static func parseTransparencyLevel(_ payload: Data) throws -> Int {
        guard let level = payload.first else {
            throw Momentum4ProtocolError.malformedControlPayload(command: Momentum4Commands.getTransparencyLevel)
        }
        guard level <= 100 else {
            throw Momentum4ProtocolError.invalidControlValue(command: Momentum4Commands.getTransparencyLevel, value: level)
        }
        return Int(level)
    }

    public static func parseEqConfig(_ payload: Data) throws -> Momentum4EqConfig {
        guard payload.count >= 3 else {
            throw Momentum4ProtocolError.malformedControlPayload(command: Momentum4Commands.getEqConfig)
        }
        let b0 = payload[payload.startIndex]
        let b1 = payload[payload.index(payload.startIndex, offsetBy: 1)]
        let b2 = payload[payload.index(payload.startIndex, offsetBy: 2)]
        guard b0 > 0 else {
            throw Momentum4ProtocolError.malformedControlPayload(command: Momentum4Commands.getEqConfig)
        }
        let minDB = Double(Int8(bitPattern: b1)) / 10.0
        let maxDB = Double(Int8(bitPattern: b2)) / 10.0
        guard minDB <= maxDB else {
            throw Momentum4ProtocolError.malformedControlPayload(command: Momentum4Commands.getEqConfig)
        }
        return Momentum4EqConfig(bandCount: b0, minimumGainDB: minDB, maximumGainDB: maxDB)
    }

    public static func parseEqBand(_ payload: Data, requestedBand: UInt8) throws -> Momentum4EqBand {
        guard !payload.isEmpty else {
            throw Momentum4ProtocolError.malformedControlPayload(command: Momentum4Commands.getEqBand)
        }
        let rawGain: UInt8
        if payload.count >= 2 {
            let bandIdx = payload[payload.startIndex]
            guard bandIdx == requestedBand else {
                throw Momentum4ProtocolError.invalidControlValue(command: Momentum4Commands.getEqBand, value: bandIdx)
            }
            rawGain = payload[payload.index(after: payload.startIndex)]
        } else {
            rawGain = payload[payload.startIndex]
        }
        return Momentum4EqBand(index: requestedBand, gainDB: Double(Int8(bitPattern: rawGain)) / 10.0)
    }

    /// Computes whether the Momentum 4 internal DSP is altering tonal balance,
    /// feeding Guardian G-04 (Double EQ) alongside Timbr's AutoEq layer.
    public static func isInternalEQNonFlat(
        soundMode: Momentum4SoundMode,
        eqBands: [Momentum4EqBand],
        bassBoostEnabled: Bool
    ) -> Bool {
        if bassBoostEnabled { return true }
        switch soundMode {
        case .off:
            return false
        case .podcast, .soundPersonalization:
            return true
        case .equalizer:
            return eqBands.contains { abs($0.gainDB) >= 0.05 }
        }
    }
}

// MARK: - Legacy PDU Compatibility & Firmware Gate

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

    public static let denylistedCommandCodes: Set<UInt16> = Momentum4CommandSafety.denylistedCommandCodes

    public static func isDenylisted(featureID: UInt8, pduID: UInt8) -> Bool {
        Momentum4CommandSafety.isDenylisted(featureID: featureID, pduID: pduID)
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

// MARK: - Live Read-Only IOBluetooth RFCOMM Transport

@MainActor
final class Momentum4RFCOMMTransport: NSObject, @preconcurrency IOBluetoothRFCOMMChannelDelegate {
    var onPacket: ((Data) -> Void)?
    var onClose: (() -> Void)?

    private static let serviceBytes: [UInt8] = [
        0xa2, 0x12, 0x9f, 0xf3, 0x08, 0x1b, 0x4c, 0x45,
        0x8a, 0xfe, 0x46, 0x9d, 0x9c, 0x48, 0x42, 0xec
    ]

    private var device: IOBluetoothDevice?
    private var channel: IOBluetoothRFCOMMChannel?
    private var deframer = GaiaSPPDeframer()
    private var continuation: CheckedContinuation<Void, Error>?
    private var timeoutTask: Task<Void, Never>?

    var isConnected: Bool { channel?.isOpen() == true }

    static func resolveConnectedHeadset() throws -> IOBluetoothDevice {
        guard let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            throw Momentum4ProtocolError.headsetNotPaired
        }
        let matching = devices.filter { ($0.name ?? "").localizedCaseInsensitiveContains("MOMENTUM 4") }
        guard matching.count <= 1 else { throw Momentum4ProtocolError.ambiguousHeadsets }
        guard let headset = matching.first else { throw Momentum4ProtocolError.headsetNotPaired }
        guard headset.isConnected() else { throw Momentum4ProtocolError.notConnected }
        return headset
    }

    func connect() async throws {
        if isConnected { return }
        let headset = try Self.resolveConnectedHeadset()
        self.device = headset
        let uuid = Self.serviceUUID()

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                self.timeoutTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(6))
                    guard !Task.isCancelled else { return }
                    self?.finishConnection(.failure(Momentum4ProtocolError.connectionTimedOut))
                }

                if let record = headset.getServiceRecord(for: uuid) {
                    openChannel(device: headset, record: record)
                } else {
                    let status = headset.performSDPQuery(self, uuids: [uuid])
                    if status != kIOReturnSuccess {
                        finishConnection(.failure(Momentum4ProtocolError.rfcommFailure(status)))
                    }
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.finishConnection(.failure(CancellationError()))
            }
        }
    }

    func send(_ packetData: Data) throws {
        guard let channel, channel.isOpen() else { throw Momentum4ProtocolError.notConnected }
        let frame = try GaiaSPP.frame(packetData)
        let status = frame.withUnsafeBytes { bytes in
            channel.writeSync(
                UnsafeMutableRawPointer(mutating: bytes.baseAddress),
                length: UInt16(bytes.count)
            )
        }
        guard status == kIOReturnSuccess else {
            throw Momentum4ProtocolError.rfcommFailure(status)
        }
    }

    func disconnect() {
        timeoutTask?.cancel()
        timeoutTask = nil
        closeChannel()
        if let continuation {
            self.continuation = nil
            continuation.resume(throwing: CancellationError())
        }
    }

    @objc func sdpQueryComplete(_ remoteDevice: IOBluetoothDevice, status: IOReturn) {
        guard continuation != nil else { return }
        guard status == kIOReturnSuccess,
              let record = remoteDevice.getServiceRecord(for: Self.serviceUUID()) else {
            finishConnection(.failure(Momentum4ProtocolError.serviceUnavailable))
            return
        }
        openChannel(device: remoteDevice, record: record)
    }

    private func openChannel(device: IOBluetoothDevice, record: IOBluetoothSDPServiceRecord) {
        guard continuation != nil else { return }
        var channelID = BluetoothRFCOMMChannelID()
        let chStatus = record.getRFCOMMChannelID(&channelID)
        guard chStatus == kIOReturnSuccess else {
            finishConnection(.failure(Momentum4ProtocolError.rfcommFailure(chStatus)))
            return
        }
        var opened: IOBluetoothRFCOMMChannel?
        let status = device.openRFCOMMChannelAsync(&opened, withChannelID: channelID, delegate: self)
        guard status == kIOReturnSuccess else {
            finishConnection(.failure(Momentum4ProtocolError.rfcommFailure(status)))
            return
        }
        channel = opened
    }

    @objc func rfcommChannelOpenComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel, status: IOReturn) {
        guard continuation != nil else {
            rfcommChannel.close()
            return
        }
        guard status == kIOReturnSuccess else {
            finishConnection(.failure(Momentum4ProtocolError.rfcommFailure(status)))
            return
        }
        channel = rfcommChannel
        finishConnection(.success(()))
    }

    @objc func rfcommChannelData(
        _ rfcommChannel: IOBluetoothRFCOMMChannel,
        data pointer: UnsafeMutableRawPointer,
        length: Int
    ) {
        for packet in deframer.ingest(Data(bytes: pointer, count: length)) {
            onPacket?(packet)
        }
    }

    @objc func rfcommChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel) {
        channel = nil
        device = nil
        onClose?()
    }

    private func finishConnection(_ result: Result<Void, Error>) {
        timeoutTask?.cancel()
        timeoutTask = nil
        if case .failure = result { closeChannel() }
        guard let continuation else { return }
        self.continuation = nil
        switch result {
        case .success: continuation.resume()
        case let .failure(error): continuation.resume(throwing: error)
        }
    }

    private func closeChannel() {
        if let channel, channel.isOpen() { channel.close() }
        channel = nil
        device = nil
    }

    private static func serviceUUID() -> IOBluetoothSDPUUID {
        serviceBytes.withUnsafeBytes { bytes in
            IOBluetoothSDPUUID(bytes: bytes.baseAddress!, length: bytes.count)
        }
    }
}

public struct Momentum4ControlSnapshot: Equatable, Sendable {
    public let batteryPercent: Int?
    public let soundMode: Momentum4SoundMode?
    public let ancEnabled: Bool?
    public let transparencyLevel: Int?
    public let transparentHearingEnabled: Bool?
    public let bassBoostEnabled: Bool?
    public let eqBands: [Momentum4EqBand]
    public let btCompatibilityMode: Momentum4BluetoothCompatibilityMode?

    public var isInternalEQNonFlat: Bool? {
        guard let soundMode else {
            if let bass = bassBoostEnabled, bass { return true }
            return eqBands.isEmpty ? nil : eqBands.contains { abs($0.gainDB) >= 0.05 }
        }
        return Momentum4ControlCodec.isInternalEQNonFlat(
            soundMode: soundMode,
            eqBands: eqBands,
            bassBoostEnabled: bassBoostEnabled ?? false
        )
    }
}

@MainActor
public final class Momentum4RFCOMMClient {
    public init() {}

    /// Executes strictly read-only GAIA v3 queries over RFCOMM and closes the channel.
    public func readTelemetrySnapshot() async throws -> Momentum4ControlSnapshot {
        let transport = Momentum4RFCOMMTransport()
        try await transport.connect()
        defer { transport.disconnect() }

        let battery: Int? = try? await {
            let pkt = try await exchange(command: Momentum4Commands.getBattery, expecting: Momentum4Commands.getBatteryResponse, on: transport)
            return try Momentum4ControlCodec.parseBattery(pkt.payload)
        }()

        let soundMode: Momentum4SoundMode? = try? await {
            let pkt = try await exchange(command: Momentum4Commands.getSoundMode, expecting: Momentum4Commands.getSoundModeResponse, on: transport)
            return try Momentum4ControlCodec.parseSoundMode(pkt.payload)
        }()

        let ancEnabled: Bool? = try? await {
            let pkt = try await exchange(command: Momentum4Commands.getAncEnabled, expecting: Momentum4Commands.getAncEnabledResponse, on: transport)
            return try Momentum4ControlCodec.parseBoolean(pkt.payload, command: Momentum4Commands.getAncEnabled)
        }()

        let transparentHearing: Bool? = try? await {
            let pkt = try await exchange(command: Momentum4Commands.getTransparentHearing, expecting: Momentum4Commands.getTransparentHearingResponse, on: transport)
            return try Momentum4ControlCodec.parseBoolean(pkt.payload, command: Momentum4Commands.getTransparentHearing)
        }()

        let transparencyLevel: Int? = try? await {
            let pkt = try await exchange(command: Momentum4Commands.getTransparencyLevel, expecting: Momentum4Commands.getTransparencyLevelResponse, on: transport)
            return try Momentum4ControlCodec.parseTransparencyLevel(pkt.payload)
        }()

        let bassBoost: Bool? = try? await {
            let pkt = try await exchange(command: Momentum4Commands.getBassBoost, expecting: Momentum4Commands.getBassBoostResponse, on: transport)
            return try Momentum4ControlCodec.parseBoolean(pkt.payload, command: Momentum4Commands.getBassBoost)
        }()

        let compatMode: Momentum4BluetoothCompatibilityMode? = try? await {
            let pkt = try await exchange(command: Momentum4Commands.getBluetoothCompatibilityMode, expecting: Momentum4Commands.getBluetoothCompatibilityModeResponse, on: transport)
            return try Momentum4ControlCodec.parseBluetoothCompatibilityMode(pkt.payload)
        }()

        var bands: [Momentum4EqBand] = []
        if let eqConfigPkt = try? await exchange(command: Momentum4Commands.getEqConfig, expecting: Momentum4Commands.getEqConfigResponse, on: transport),
           let eqConfig = try? Momentum4ControlCodec.parseEqConfig(eqConfigPkt.payload) {
            let count = min(eqConfig.bandCount, 10)
            for idx in UInt8(0)..<count {
                if let bandPkt = try? await exchange(
                    command: Momentum4Commands.getEqBand,
                    payload: Data([idx]),
                    expecting: Momentum4Commands.getEqBandResponse,
                    on: transport
                ),
                   let band = try? Momentum4ControlCodec.parseEqBand(bandPkt.payload, requestedBand: idx) {
                    bands.append(band)
                }
            }
        }

        return Momentum4ControlSnapshot(
            batteryPercent: battery,
            soundMode: soundMode,
            ancEnabled: ancEnabled,
            transparencyLevel: transparencyLevel,
            transparentHearingEnabled: transparentHearing,
            bassBoostEnabled: bassBoost,
            eqBands: bands,
            btCompatibilityMode: compatMode
        )
    }

    private func exchange(
        command: UInt16,
        payload: Data = Data(),
        expecting expectedResponse: UInt16,
        on transport: Momentum4RFCOMMTransport
    ) async throws -> Gaia3Packet {
        var matched: Gaia3Packet?
        transport.onPacket = { data in
            guard let pkt = try? Gaia3Packet(data: data),
                  pkt.vendorID == Momentum4Commands.vendorID,
                  pkt.commandID == expectedResponse else { return }
            matched = pkt
        }
        let wire = try Gaia3Packet(commandID: command, payload: payload).encode()
        try transport.send(wire)

        for _ in 0..<40 { // up to 2.0s per command
            try Task.checkCancellation()
            if let matched { return matched }
            try await Task.sleep(for: .milliseconds(50))
        }
        throw Momentum4ProtocolError.responseTimedOut(command)
    }
}

// MARK: - Headphone Drivers

public protocol HeadphoneDeviceDriver: Sendable {
    var driverID: String { get }
    func matches(device: AudioDeviceDescriptor) -> Bool
    func readTelemetry(for device: AudioDeviceDescriptor) -> HardwareDriverTelemetry
}

public final class Momentum4Driver: HeadphoneDeviceDriver, @unchecked Sendable {
    public let driverID = "sennheiser-momentum4-gaia-v3"
    public static let gaiaServiceUUIDString = "A2129FF3-081B-4C45-8AFE-469D9C4842EC"

    private let lock = NSLock()
    private var cachedSnapshot: Momentum4ControlSnapshot?
    private var lastReadAt: Date = .distantPast
    private var isPolling = false

    public init() {}

    public func matches(device: AudioDeviceDescriptor) -> Bool {
        device.name.localizedCaseInsensitiveContains("MOMENTUM 4")
    }

    public func readTelemetry(for device: AudioDeviceDescriptor) -> HardwareDriverTelemetry {
        let paired = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
        guard let btDev = paired.first(where: { ($0.name ?? "").localizedCaseInsensitiveContains("MOMENTUM 4") }) else {
            return HardwareDriverTelemetry(
                driverName: "Sennheiser Momentum 4 (GAIA v3)",
                reportedCodec: device.transport == .usb ? "USB-C UAC 1.0 (16-bit/48 kHz)" : nil,
                connectionStatus: device.transport == .usb ? "usb-uac1-read-only" : "not-paired"
            )
        }
        let connected = btDev.isConnected()

        lock.lock()
        let cached = cachedSnapshot
        let stale = Date().timeIntervalSince(lastReadAt) > 20.0
        let shouldStartPoll = connected && stale && !isPolling
        if shouldStartPoll {
            isPolling = true
        }
        lock.unlock()

        if shouldStartPoll {
            Task { @MainActor [weak self] in
                guard let self else { return }
                let snap = try? await Momentum4RFCOMMClient().readTelemetrySnapshot()
                self.storePolledSnapshot(snap)
            }
        }

        let codecHint: String
        if device.transport == .usb {
            codecHint = "USB-C UAC 1.0 (16-bit/48 kHz)"
        } else if let compat = cached?.btCompatibilityMode {
            codecHint = compat == .betterAudio ? "Bluetooth (Better Audio / aptX-AAC)" : "Bluetooth (Compatibility)"
        } else {
            codecHint = "Bluetooth (macOS reported)"
        }

        let status: String
        if !connected {
            status = "paired-disconnected"
        } else if cached != nil {
            status = "connected-gaia-v3-read-only"
        } else {
            status = "connected-ready-for-read"
        }

        return HardwareDriverTelemetry(
            driverName: "Sennheiser Momentum 4 (GAIA v3)",
            batteryPercent: cached?.batteryPercent,
            firmwareVersion: nil,
            ancEnabled: cached?.ancEnabled,
            transparencyPercent: cached?.transparencyLevel,
            internalEQNonFlat: cached?.isInternalEQNonFlat,
            reportedCodec: codecHint,
            connectionStatus: status
        )
    }

    private func storePolledSnapshot(_ snap: Momentum4ControlSnapshot?) {
        lock.withLock {
            if let snap {
                self.cachedSnapshot = snap
            }
            self.lastReadAt = Date()
            self.isPolling = false
        }
    }

    public func refreshTelemetryNow() async -> Momentum4ControlSnapshot? {
        let snap = try? await Momentum4RFCOMMClient().readTelemetrySnapshot()
        storePolledSnapshot(snap)
        return snap
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
