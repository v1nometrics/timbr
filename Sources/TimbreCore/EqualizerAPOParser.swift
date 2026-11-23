// SPDX-License-Identifier: MPL-2.0
import Foundation

public enum EqualizerAPOParserError: Error, Equatable, Sendable {
    case inputTooLarge
    case tooManyLines
    case invalidNumericValue(line: Int)
    case emptyOrNoFilters
}

public struct ParsedEqualizerAPO: Equatable, Sendable {
    public var preampDB: Double
    public var bands: [EQBand]

    public init(preampDB: Double, bands: [EQBand]) {
        self.preampDB = preampDB
        self.bands = bands
    }
}

public enum EqualizerAPOParser {
    public static let maxBytes = 256 * 1024 // 256 KB hard cap against malformed input (Security §3)
    public static let maxLines = 1000
    public static let maxBands = 32

    public static func parse(_ text: String, layer: EQLayer = .correction) throws -> ParsedEqualizerAPO {
        guard text.utf8.count <= maxBytes else {
            throw EqualizerAPOParserError.inputTooLarge
        }
        let lines = text.components(separatedBy: .newlines)
        guard lines.count <= maxLines else {
            throw EqualizerAPOParserError.tooManyLines
        }

        var preamp = 0.0
        var bands: [EQBand] = []

        for (idx, rawLine) in lines.enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line.hasPrefix("#") || line.hasPrefix("Channel:") { continue }

            // Preamp: -4.2 dB
            if line.lowercased().hasPrefix("preamp:") {
                let parts = line.split(whereSeparator: { $0.isWhitespace })
                if parts.count >= 2, let val = Double(parts[1]), val.isFinite, val >= -36.0, val <= 24.0 {
                    preamp = val
                } else {
                    throw EqualizerAPOParserError.invalidNumericValue(line: idx + 1)
                }
                continue
            }

            // Filter [N]: ON|OFF PK|LS|LSC|HS|HSC|LP|HP|BP|NO|AP Fc <hz> Hz [Gain <db> dB] [Q <q>]
            if line.lowercased().hasPrefix("filter") {
                if bands.count >= maxBands { break }
                let tokens = line.split(whereSeparator: { $0.isWhitespace }).map(String.init)
                guard let colonIdx = tokens.firstIndex(where: { $0.hasSuffix(":") }) else { continue }
                let rest = Array(tokens.dropFirst(colonIdx + 1))
                guard rest.count >= 2 else { continue }

                let enabled = rest[0].uppercased() == "ON"
                let typeToken = rest[1].uppercased()
                let filterType: EQFilterType
                switch typeToken {
                case "PK", "PEQ": filterType = .peak
                case "LS", "LSC", "LS6", "LS12": filterType = .lowShelf
                case "HS", "HSC", "HS6", "HS12": filterType = .highShelf
                case "LP", "LPQ": filterType = .lowPass
                case "HP", "HPQ": filterType = .highPass
                case "BP": filterType = .bandPass
                case "NO": filterType = .notch
                case "AP": filterType = .allPass
                default: continue
                }

                var fc: Double?
                var gain: Double = 0.0
                var q: Double = 0.707

                var i = 2
                while i < rest.count {
                    let key = rest[i].lowercased()
                    if key == "fc", i + 1 < rest.count, let v = Double(rest[i + 1]) {
                        fc = v
                        i += 2
                    } else if key == "gain", i + 1 < rest.count, let v = Double(rest[i + 1]) {
                        gain = v
                        i += 2
                    } else if key == "q", i + 1 < rest.count, let v = Double(rest[i + 1]) {
                        q = v
                        i += 2
                    } else {
                        i += 1
                    }
                }

                guard let validFc = fc, validFc.isFinite, validFc >= 10.0, validFc <= 22000.0,
                      gain.isFinite, gain >= -24.0, gain <= 24.0,
                      q.isFinite, q >= 0.05, q <= 24.0 else {
                    throw EqualizerAPOParserError.invalidNumericValue(line: idx + 1)
                }

                bands.append(EQBand(
                    type: filterType,
                    design: .vicanek,
                    layer: layer,
                    freqHz: validFc,
                    gainDB: gain,
                    q: q,
                    enabled: enabled
                ))
            }
        }

        if bands.isEmpty && abs(preamp) < 1e-6 {
            throw EqualizerAPOParserError.emptyOrNoFilters
        }

        return ParsedEqualizerAPO(preampDB: preamp, bands: bands)
    }

    public static func export(preampDB: Double, bands: [EQBand]) -> String {
        var lines: [String] = [
            "# Exported by timbr (ADR-0009 EqualizerAPO ParametricEQ interchange)",
            String(format: "Preamp: %.2f dB", preampDB)
        ]
        for (i, b) in bands.enumerated() {
            let code: String
            switch b.type {
            case .peak: code = "PK"
            case .lowShelf: code = "LSC"
            case .highShelf: code = "HSC"
            case .lowPass: code = "LPQ"
            case .highPass: code = "HPQ"
            case .bandPass: code = "BP"
            case .notch: code = "NO"
            case .allPass: code = "AP"
            case .bypass: continue
            }
            let state = b.enabled ? "ON" : "OFF"
            lines.append(String(
                format: "Filter %d: %@ %@ Fc %.1f Hz Gain %.2f dB Q %.3f",
                i + 1, state, code, b.freqHz, b.gainDB, b.q
            ))
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
