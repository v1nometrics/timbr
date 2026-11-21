// SPDX-License-Identifier: MPL-2.0
import Foundation

public struct SanitizedDiagnosticReport: Codable, Sendable {
    public let generatedAt: Date
    public let appName: String
    public let osVersion: String
    public let devices: [AudioDeviceDescriptor]
    public let activeAlerts: [GuardianAlert]
    public let recentEvents: [ObservatoryEvent]
    public let audioBuffersIncluded: Bool

    public init(
        generatedAt: Date = Date(),
        appName: String = "timbr.",
        osVersion: String = ProcessInfo.processInfo.operatingSystemVersionString,
        devices: [AudioDeviceDescriptor],
        activeAlerts: [GuardianAlert],
        recentEvents: [ObservatoryEvent]
    ) {
        self.generatedAt = generatedAt
        self.appName = appName
        self.osVersion = osVersion
        self.devices = devices
        self.activeAlerts = activeAlerts
        self.recentEvents = recentEvents
        self.audioBuffersIncluded = false
    }

    public func toJSONPretty() throws -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        let data = try enc.encode(self)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
