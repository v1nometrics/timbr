// SPDX-License-Identifier: MPL-2.0
import Foundation
import CTimbreDSP

public enum SignalTrustBadge: String, Codable, Sendable, CaseIterable {
    case measured   // MEDIDO
    case reported   // REPORTADO
    case inferred   // INFERIDO
    case bitPerfect // BIT-PERFECT
}

public enum DeviceTransport: String, Codable, Sendable, CaseIterable {
    case builtIn
    case usb
    case bluetoothA2DP
    case bluetoothHFP
    case wiredAnalog
    case hdmi
    case aggregate
    case virtual
    case continuity
    case unknown

    public var isBluetooth: Bool {
        self == .bluetoothA2DP || self == .bluetoothHFP
    }
}

public enum AnalogImpedanceMode: String, Codable, Sendable, CaseIterable {
    case active470Ohm
    case passive60Ohm

    public var ohms: Int {
        self == .active470Ohm ? 470 : 60
    }
}

public struct AudioDeviceDescriptor: Identifiable, Codable, Hashable, Sendable {
    public var id: String { uid }
    public let uid: String
    public let audioObjectID: UInt32
    public let name: String
    public let manufacturer: String
    public let transport: DeviceTransport
    public let inputChannels: Int
    public let outputChannels: Int
    public let sampleRate: Double
    public let availableRates: [Double]
    public let isSampleRateSettable: Bool
    public let isHWVolumeMasterSettable: Bool
    public let isHWVolumeChannelSettable: Bool
    public let isHWMuteSettable: Bool
    public let isHogModeSettable: Bool
    public let outputLatencyFrames: UInt32
    public let safetyOffsetFrames: UInt32
    public let isDefaultOutput: Bool
    public let isDefaultInput: Bool
    public var analogImpedanceMode: AnalogImpedanceMode?

    public init(
        uid: String,
        audioObjectID: UInt32 = 0,
        name: String,
        manufacturer: String = "",
        transport: DeviceTransport,
        inputChannels: Int = 0,
        outputChannels: Int = 2,
        sampleRate: Double = 48000,
        availableRates: [Double] = [44100, 48000],
        isSampleRateSettable: Bool = true,
        isHWVolumeMasterSettable: Bool = true,
        isHWVolumeChannelSettable: Bool = false,
        isHWMuteSettable: Bool = true,
        isHogModeSettable: Bool = true,
        outputLatencyFrames: UInt32 = 0,
        safetyOffsetFrames: UInt32 = 0,
        isDefaultOutput: Bool = false,
        isDefaultInput: Bool = false,
        analogImpedanceMode: AnalogImpedanceMode? = nil
    ) {
        self.uid = uid
        self.audioObjectID = audioObjectID
        self.name = name
        self.manufacturer = manufacturer
        self.transport = transport
        self.inputChannels = inputChannels
        self.outputChannels = outputChannels
        self.sampleRate = sampleRate
        self.availableRates = availableRates
        self.isSampleRateSettable = isSampleRateSettable
        self.isHWVolumeMasterSettable = isHWVolumeMasterSettable
        self.isHWVolumeChannelSettable = isHWVolumeChannelSettable
        self.isHWMuteSettable = isHWMuteSettable
        self.isHogModeSettable = isHogModeSettable
        self.outputLatencyFrames = outputLatencyFrames
        self.safetyOffsetFrames = safetyOffsetFrames
        self.isDefaultOutput = isDefaultOutput
        self.isDefaultInput = isDefaultInput
        self.analogImpedanceMode = analogImpedanceMode
    }

    public var supportsAnyHWVolume: Bool {
        isHWVolumeMasterSettable || isHWVolumeChannelSettable
    }

    public var totalReportedLatencyMs: Double {
        guard sampleRate > 0 else { return 0 }
        return Double(outputLatencyFrames + safetyOffsetFrames) / sampleRate * 1000.0
    }

    public var recommendedLimiterCeilingDBTP: Double {
        // C-03: -1.0 dBTP extra ceiling for BT AAC encoder protection (ebur128#69 / Lund)
        transport.isBluetooth ? -1.0 : -0.3
    }
}

public enum EQFilterType: String, Codable, Sendable, CaseIterable {
    case bypass, peak, lowShelf, highShelf, lowPass, highPass, bandPass, notch, allPass

    public var cType: timbre_filter_type_t {
        switch self {
        case .bypass: return TIMBRE_FILTER_BYPASS
        case .peak: return TIMBRE_FILTER_PEAK
        case .lowShelf: return TIMBRE_FILTER_LOW_SHELF
        case .highShelf: return TIMBRE_FILTER_HIGH_SHELF
        case .lowPass: return TIMBRE_FILTER_LOW_PASS
        case .highPass: return TIMBRE_FILTER_HIGH_PASS
        case .bandPass: return TIMBRE_FILTER_BAND_PASS
        case .notch: return TIMBRE_FILTER_NOTCH
        case .allPass: return TIMBRE_FILTER_ALL_PASS
        }
    }
}

public enum EQDesignMethod: String, Codable, Sendable, CaseIterable {
    case vicanek
    case rbj

    public var cType: timbre_design_method_t {
        self == .vicanek ? TIMBRE_DESIGN_VICANEK : TIMBRE_DESIGN_RBJ
    }
}

public enum EQLayer: String, Codable, Sendable, CaseIterable {
    case correction
    case taste
    case source

    public var cType: timbre_eq_layer_t {
        switch self {
        case .correction: return TIMBRE_LAYER_CORRECTION
        case .taste: return TIMBRE_LAYER_TASTE
        case .source: return TIMBRE_LAYER_SOURCE
        }
    }
}

public enum ABCompareMode: String, Codable, Sendable, CaseIterable {
    case full
    case correctionOnly
    case bypassEqualLatency

    public var cType: timbre_ab_mode_t {
        switch self {
        case .full: return TIMBRE_AB_MODE_FULL
        case .correctionOnly: return TIMBRE_AB_MODE_CORRECTION_ONLY
        case .bypassEqualLatency: return TIMBRE_AB_MODE_BYPASS_EQUAL_LATENCY
        }
    }
}

public struct EQBand: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var type: EQFilterType
    public var design: EQDesignMethod
    public var layer: EQLayer
    public var freqHz: Double
    public var gainDB: Double
    public var q: Double
    public var enabled: Bool

    public init(
        id: UUID = UUID(),
        type: EQFilterType = .peak,
        design: EQDesignMethod = .vicanek,
        layer: EQLayer = .taste,
        freqHz: Double,
        gainDB: Double,
        q: Double = 1.0,
        enabled: Bool = true
    ) {
        self.id = id
        self.type = type
        self.design = design
        self.layer = layer
        self.freqHz = min(max(freqHz, 10.0), 22000.0)
        self.gainDB = min(max(gainDB, -24.0), 24.0)
        self.q = min(max(q, 0.1), 24.0)
        self.enabled = enabled
    }

    public var cBand: timbre_band_t {
        timbre_band_t(
            type: type.cType,
            design: design.cType,
            layer: layer.cType,
            freq_hz: freqHz,
            gain_db: gainDB,
            q: q,
            enabled: enabled
        )
    }
}

public struct SimpleTasteControls: Codable, Hashable, Sendable {
    public var bassDB: Double     // 105 Hz low shelf Q=0.7
    public var warmthDB: Double   // 250 Hz peaking Q=0.9
    public var presenceDB: Double // 3000 Hz peaking Q=1.0
    public var airDB: Double      // 10000 Hz high shelf Q=0.7

    public init(bassDB: Double = 0, warmthDB: Double = 0, presenceDB: Double = 0, airDB: Double = 0) {
        self.bassDB = Self.clampStep(bassDB)
        self.warmthDB = Self.clampStep(warmthDB)
        self.presenceDB = Self.clampStep(presenceDB)
        self.airDB = Self.clampStep(airDB)
    }

    public static func clampStep(_ val: Double) -> Double {
        let clamped = min(max(val, -6.0), 6.0)
        return (clamped * 2.0).rounded() / 2.0
    }

    public static let neutral = SimpleTasteControls()

    public func toPEQBands() -> [EQBand] {
        [
            EQBand(type: .lowShelf, design: .vicanek, layer: .taste, freqHz: 105, gainDB: bassDB, q: 0.7, enabled: abs(bassDB) > 0.01),
            EQBand(type: .peak, design: .vicanek, layer: .taste, freqHz: 250, gainDB: warmthDB, q: 0.9, enabled: abs(warmthDB) > 0.01),
            EQBand(type: .peak, design: .vicanek, layer: .taste, freqHz: 3000, gainDB: presenceDB, q: 1.0, enabled: abs(presenceDB) > 0.01),
            EQBand(type: .highShelf, design: .vicanek, layer: .taste, freqHz: 10000, gainDB: airDB, q: 0.7, enabled: abs(airDB) > 0.01)
        ]
    }
}

public struct CorrectionMetadata: Codable, Hashable, Sendable {
    public let headphoneModel: String
    public let sourceCredit: String
    public let measurementRig: String
    public let targetCurve: String
    public let transport: DeviceTransport
    public let fetchedAt: Date

    public init(
        headphoneModel: String,
        sourceCredit: String,
        measurementRig: String,
        targetCurve: String,
        transport: DeviceTransport,
        fetchedAt: Date = Date()
    ) {
        self.headphoneModel = headphoneModel
        self.sourceCredit = sourceCredit
        self.measurementRig = measurementRig
        self.targetCurve = targetCurve
        self.transport = transport
        self.fetchedAt = fetchedAt
    }
}

public struct TimbrePreset: Identifiable, Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let id: UUID
    public var name: String
    public var deviceUID: String?
    public var correctionMetadata: CorrectionMetadata?
    public var correctionBands: [EQBand]
    public var tasteBands: [EQBand]
    public var simpleTaste: SimpleTasteControls
    public var useAdvancedPEQ: Bool
    public var crossfeedEnabled: Bool
    public var limiterCeilingDBTP: Double
    public var updatedAt: Date

    public init(
        schemaVersion: Int = 1,
        id: UUID = UUID(),
        name: String,
        deviceUID: String? = nil,
        correctionMetadata: CorrectionMetadata? = nil,
        correctionBands: [EQBand] = [],
        tasteBands: [EQBand] = [],
        simpleTaste: SimpleTasteControls = .neutral,
        useAdvancedPEQ: Bool = false,
        crossfeedEnabled: Bool = false,
        limiterCeilingDBTP: Double = -0.3,
        updatedAt: Date = Date()
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.name = name
        self.deviceUID = deviceUID
        self.correctionMetadata = correctionMetadata
        self.correctionBands = correctionBands
        self.tasteBands = tasteBands
        self.simpleTaste = simpleTaste
        self.useAdvancedPEQ = useAdvancedPEQ
        self.crossfeedEnabled = crossfeedEnabled
        self.limiterCeilingDBTP = limiterCeilingDBTP
        self.updatedAt = updatedAt
    }

    public var effectiveTasteBands: [EQBand] {
        useAdvancedPEQ ? tasteBands : simpleTaste.toPEQBands()
    }

    public var allEffectiveBands: [EQBand] {
        correctionBands + effectiveTasteBands
    }
}

public struct AudioSourceDescriptor: Identifiable, Codable, Hashable, Sendable {
    public var id: String { bundleID }
    public let bundleID: String
    public var name: String
    public var pids: [Int32]
    public var volume: Double // 0.0 .. 4.0 (+12 dB boost)
    public var isMuted: Bool
    public var isPlaying: Bool
    public var isVoIPExcluded: Bool
    public var targetDestinationUIDs: [String]
    public var delayMsByDestination: [String: Double]
    public var lastActiveAt: Date
    /// When the current playback run started (nil while silent). Keeps the order stable when
    /// several apps play at once: the most recently started one leads.
    public var playingSince: Date?

    public init(
        bundleID: String,
        name: String,
        pids: [Int32] = [],
        volume: Double = 1.0,
        isMuted: Bool = false,
        isPlaying: Bool = false,
        isVoIPExcluded: Bool = false,
        targetDestinationUIDs: [String] = [],
        delayMsByDestination: [String: Double] = [:],
        lastActiveAt: Date = Date()
    ) {
        self.bundleID = bundleID
        self.name = name
        self.pids = pids
        self.volume = min(max(volume, 0.0), 4.0)
        self.isMuted = isMuted
        self.isPlaying = isPlaying
        self.isVoIPExcluded = isVoIPExcluded
        self.targetDestinationUIDs = targetDestinationUIDs
        self.delayMsByDestination = delayMsByDestination
        self.lastActiveAt = lastActiveAt
        self.playingSince = isPlaying ? lastActiveAt : nil
    }

    /// Display order: playing (newest run first) → muted → most recently active.
    public static func displayOrder(_ a: AudioSourceDescriptor, _ b: AudioSourceDescriptor) -> Bool {
        if a.isPlaying != b.isPlaying { return a.isPlaying }
        if a.isPlaying, let sa = a.playingSince, let sb = b.playingSince, sa != sb { return sa > sb }
        if a.isMuted != b.isMuted { return a.isMuted }
        if a.lastActiveAt != b.lastActiveAt { return a.lastActiveAt > b.lastActiveAt }
        return a.bundleID < b.bundleID
    }

    public var boostDB: Double? {
        guard volume > 1.001 else { return nil }
        return 20.0 * log10(volume)
    }

    public var needsProcessingTap: Bool {
        if isVoIPExcluded { return false }
        return abs(volume - 1.0) > 0.001 || isMuted || !targetDestinationUIDs.isEmpty
    }
}

/// Resolves what the notch Peek (hover without clicking) controls as the primary target:
/// - 0 playing sources: master output device (even if paused/recent sources exist).
/// - 1 playing source: that single source directly.
/// - 2+ playing sources: Master/Geral at top, followed by every playing app equally.
public enum NotchPeekTarget: Equatable, Sendable {
    case output
    case single(AudioSourceDescriptor)
    case masterWithSources([AudioSourceDescriptor])

    public static func resolve(from sources: [AudioSourceDescriptor], limit: Int = 4) -> NotchPeekTarget {
        let playing = sources.filter(\.isPlaying).sorted(by: AudioSourceDescriptor.displayOrder)
        if playing.isEmpty { return .output }
        if playing.count == 1, let sole = playing.first { return .single(sole) }
        return .masterWithSources(Array(playing.prefix(max(2, limit))))
    }
}

/// Resolves what the notch Expanded console leads with, unifying spotlight priority with Peek:
/// - 0 playing sources & no recent/muted sources: `.empty` (output device only).
/// - 0 playing sources & paused/recent sources: `.masterWithSources(recent)` (`Geral` leads + paused/recent apps underneath).
/// - 1 playing source: `.single(sole, others: remaining)` (that playing app leads + other recent rows + `Geral` row underneath).
/// - 2+ playing sources: `.masterWithSources(sources)` (`Geral` leads neutrally at top + all apps equally underneath).
public enum NotchExpandedTarget: Equatable, Sendable {
    public enum LayoutKind: Equatable, Sendable {
        case empty
        case single
        case masterLed
    }

    case empty
    case single(AudioSourceDescriptor, others: [AudioSourceDescriptor])
    case masterWithSources([AudioSourceDescriptor])

    public var layoutKind: LayoutKind {
        switch self {
        case .empty: return .empty
        case .single: return .single
        case .masterWithSources: return .masterLed
        }
    }

    public var singleSource: AudioSourceDescriptor? {
        if case .single(let s, _) = self { return s }
        return nil
    }

    public var listRowCount: Int {
        switch self {
        case .empty: return 0
        case .single(_, let others): return others.count
        case .masterWithSources(let list): return list.count
        }
    }

    public static func resolve(from mixerSources: [AudioSourceDescriptor], singleOtherLimit: Int = 3, masterLimit: Int = 4) -> NotchExpandedTarget {
        let ordered = mixerSources.sorted(by: AudioSourceDescriptor.displayOrder)
        let playing = ordered.filter(\.isPlaying)
        if playing.count == 1, let sole = playing.first {
            let others = ordered.filter { $0.bundleID != sole.bundleID }.prefix(max(0, singleOtherLimit))
            return .single(sole, others: Array(others))
        }
        if ordered.isEmpty {
            return .empty
        }
        return .masterWithSources(Array(ordered.prefix(max(1, masterLimit))))
    }
}

public struct SignalStage: Identifiable, Hashable, Sendable {
    public let id: String
    public let titleKey: String
    public let subtitle: String
    public let badge: SignalTrustBadge
    public let latencyMs: Double?
    public let gainDB: Double?
    public let isActive: Bool

    public init(
        id: String,
        titleKey: String,
        subtitle: String,
        badge: SignalTrustBadge,
        latencyMs: Double? = nil,
        gainDB: Double? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.titleKey = titleKey
        self.subtitle = subtitle
        self.badge = badge
        self.latencyMs = latencyMs
        self.gainDB = gainDB
        self.isActive = isActive
    }
}

public enum GuardianRuleID: String, Codable, Sendable, CaseIterable {
    case g01HFP = "G-01"
    case g02Resampling = "G-02"
    case g03Clipping = "G-03"
    case g04DuplicateEQ = "G-04"
    case g05AvoidableSWVolume = "G-05"
    case g06UnexpectedSwitch = "G-06"
    case g07TapConflict = "G-07"
}

public enum GuardianSeverity: String, Codable, Sendable {
    case info, warning, critical
}

public struct GuardianAlert: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let ruleID: GuardianRuleID
    public let severity: GuardianSeverity
    public let titleKey: String
    public let detail: String
    public let appBundleID: String?
    public let deviceUID: String?
    public let suggestedActionKey: String?
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        ruleID: GuardianRuleID,
        severity: GuardianSeverity,
        titleKey: String,
        detail: String,
        appBundleID: String? = nil,
        deviceUID: String? = nil,
        suggestedActionKey: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.ruleID = ruleID
        self.severity = severity
        self.titleKey = titleKey
        self.detail = detail
        self.appBundleID = appBundleID
        self.deviceUID = deviceUID
        self.suggestedActionKey = suggestedActionKey
        self.timestamp = timestamp
    }
}

public struct ObservatoryEvent: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let category: String
    public let message: String
    public let badge: SignalTrustBadge?
    public let deviceUID: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        category: String,
        message: String,
        badge: SignalTrustBadge? = nil,
        deviceUID: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.category = category
        self.message = message
        self.badge = badge
        self.deviceUID = deviceUID
    }
}

public struct AudioScene: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var triggerDeviceUID: String?
    public var presetID: UUID?
    public var duckingEnabled: Bool
    public var duckingAmountDB: Double

    public init(
        id: UUID = UUID(),
        name: String,
        triggerDeviceUID: String? = nil,
        presetID: UUID? = nil,
        duckingEnabled: Bool = false,
        duckingAmountDB: Double = -12.0
    ) {
        self.id = id
        self.name = name
        self.triggerDeviceUID = triggerDeviceUID
        self.presetID = presetID
        self.duckingEnabled = duckingEnabled
        self.duckingAmountDB = duckingAmountDB
    }
}

public struct HardwareDriverTelemetry: Codable, Hashable, Sendable {
    public let driverName: String
    public var batteryPercent: Int?
    public var batteryLeftPercent: Int?
    public var batteryRightPercent: Int?
    public var batteryCasePercent: Int?
    public var isCharging: Bool?
    public var leftCharging: Bool?
    public var rightCharging: Bool?
    public var caseCharging: Bool?
    public var firmwareVersion: String?
    public var ancEnabled: Bool?
    public var transparencyPercent: Int?
    public var internalEQNonFlat: Bool?
    public var reportedCodec: String?
    public var accessoryFamily: String?
    public var modelIdentifier: String?
    public var spatialAudioMayAlterFR: Bool?
    public var systemManagedFeatureKeys: [String]?
    public var trustBadge: SignalTrustBadge?
    public var updatedAt: Date
    public var connectionStatus: String

    public init(
        driverName: String,
        batteryPercent: Int? = nil,
        batteryLeftPercent: Int? = nil,
        batteryRightPercent: Int? = nil,
        batteryCasePercent: Int? = nil,
        isCharging: Bool? = nil,
        leftCharging: Bool? = nil,
        rightCharging: Bool? = nil,
        caseCharging: Bool? = nil,
        firmwareVersion: String? = nil,
        ancEnabled: Bool? = nil,
        transparencyPercent: Int? = nil,
        internalEQNonFlat: Bool? = nil,
        reportedCodec: String? = nil,
        accessoryFamily: String? = nil,
        modelIdentifier: String? = nil,
        spatialAudioMayAlterFR: Bool? = nil,
        systemManagedFeatureKeys: [String]? = nil,
        trustBadge: SignalTrustBadge? = nil,
        updatedAt: Date = Date(),
        connectionStatus: String = "unavailable"
    ) {
        self.driverName = driverName
        self.batteryPercent = batteryPercent
        self.batteryLeftPercent = batteryLeftPercent
        self.batteryRightPercent = batteryRightPercent
        self.batteryCasePercent = batteryCasePercent
        self.isCharging = isCharging
        self.leftCharging = leftCharging
        self.rightCharging = rightCharging
        self.caseCharging = caseCharging
        self.firmwareVersion = firmwareVersion
        self.ancEnabled = ancEnabled
        self.transparencyPercent = transparencyPercent
        self.internalEQNonFlat = internalEQNonFlat
        self.reportedCodec = reportedCodec
        self.accessoryFamily = accessoryFamily
        self.modelIdentifier = modelIdentifier
        self.spatialAudioMayAlterFR = spatialAudioMayAlterFR
        self.systemManagedFeatureKeys = systemManagedFeatureKeys
        self.trustBadge = trustBadge
        self.updatedAt = updatedAt
        self.connectionStatus = connectionStatus
    }
}

public struct NowPlayingInfo: Hashable, Sendable {
    public var title: String
    public var artist: String
    public var album: String
    public var sourceName: String
    public var isPlaying: Bool
    public var sampleRateHz: Double?

    public init(
        title: String = "",
        artist: String = "",
        album: String = "",
        sourceName: String = "",
        isPlaying: Bool = false,
        sampleRateHz: Double? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.sourceName = sourceName
        self.isPlaying = isPlaying
        self.sampleRateHz = sampleRateHz
    }
}
