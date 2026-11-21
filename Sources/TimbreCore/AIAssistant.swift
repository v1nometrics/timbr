// SPDX-License-Identifier: MPL-2.0
import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

public enum AIModelRuntime: String, Codable, Sendable, CaseIterable {
    case appleOnDevice
    case localOllama
    case cloudBYOK
    case offlineHeuristic
}

public enum EQDeltaOperationType: String, Codable, Sendable {
    case adjustBand = "adjust_band"
    case addFilter = "add_filter"
    case removeFilter = "remove_filter"
    case setTilt = "set_tilt"
}

public struct EQDeltaOperation: Codable, Equatable, Sendable {
    public let op: EQDeltaOperationType
    public let filterType: EQFilterType?
    public let freqHz: Double?
    public let gainDB: Double?
    public let q: Double?
    public let tiltDBPerOctave: Double?

    public init(
        op: EQDeltaOperationType,
        filterType: EQFilterType? = .peak,
        freqHz: Double? = nil,
        gainDB: Double? = nil,
        q: Double? = nil,
        tiltDBPerOctave: Double? = nil
    ) {
        self.op = op
        self.filterType = filterType
        self.freqHz = freqHz
        self.gainDB = gainDB
        self.q = q
        self.tiltDBPerOctave = tiltDBPerOctave
    }
}

public struct EQDeltaProposal: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let label: String
    public let rationale: String
    public let runtimeUsed: AIModelRuntime
    public let operations: [EQDeltaOperation]

    public init(
        id: UUID = UUID(),
        label: String,
        rationale: String,
        runtimeUsed: AIModelRuntime,
        operations: [EQDeltaOperation]
    ) {
        self.id = id
        self.label = label
        self.rationale = rationale
        self.runtimeUsed = runtimeUsed
        self.operations = operations
    }
}

public enum EQDeltaValidationError: Error, Equatable, Sendable {
    case tooManyNewFilters(count: Int, maxAllowed: Int)
    case outOfRangeGain(Double)
    case outOfRangeFreq(Double)
    case outOfRangeQ(Double)
    case emptyProposal
}

public enum EQDeltaValidator {
    public static let minFreqHz = 20.0
    public static let maxFreqHz = 20000.0
    public static let maxAbsGainDB = 6.0
    public static let minQ = 0.3
    public static let maxQ = 6.0
    public static let maxNewFiltersPerRequest = 3

    public static func validateAndClamp(_ proposal: EQDeltaProposal, strict: Bool = true) throws -> EQDeltaProposal {
        guard !proposal.operations.isEmpty else { throw EQDeltaValidationError.emptyProposal }
        let addCount = proposal.operations.filter { $0.op == .addFilter }.count
        if addCount > maxNewFiltersPerRequest {
            throw EQDeltaValidationError.tooManyNewFilters(count: addCount, maxAllowed: maxNewFiltersPerRequest)
        }

        var validatedOps: [EQDeltaOperation] = []
        for op in proposal.operations {
            if let f = op.freqHz {
                if !f.isFinite || (strict && (f < minFreqHz || f > maxFreqHz)) {
                    throw EQDeltaValidationError.outOfRangeFreq(f)
                }
            }
            if let g = op.gainDB {
                if !g.isFinite || (strict && abs(g) > maxAbsGainDB) {
                    throw EQDeltaValidationError.outOfRangeGain(g)
                }
            }
            if let q = op.q {
                if !q.isFinite || (strict && (q < minQ || q > maxQ)) {
                    throw EQDeltaValidationError.outOfRangeQ(q)
                }
            }
            let clamped = EQDeltaOperation(
                op: op.op,
                filterType: op.filterType,
                freqHz: op.freqHz.map { min(max($0, minFreqHz), maxFreqHz) },
                gainDB: op.gainDB.map { min(max($0, -maxAbsGainDB), maxAbsGainDB) },
                q: op.q.map { min(max($0, minQ), maxQ) },
                tiltDBPerOctave: op.tiltDBPerOctave.map { min(max($0, -3.0), 3.0) }
            )
            validatedOps.append(clamped)
        }

        return EQDeltaProposal(
            id: proposal.id,
            label: proposal.label,
            rationale: proposal.rationale,
            runtimeUsed: proposal.runtimeUsed,
            operations: validatedOps
        )
    }

    public static func apply(proposal: EQDeltaProposal, toTasteBands existing: [EQBand]) throws -> [EQBand] {
        let valid = try validateAndClamp(proposal)
        var result = existing
        for op in valid.operations {
            switch op.op {
            case .addFilter:
                if let f = op.freqHz, let g = op.gainDB {
                    result.append(EQBand(
                        type: op.filterType ?? .peak,
                        design: .vicanek,
                        layer: .taste,
                        freqHz: f,
                        gainDB: g,
                        q: op.q ?? 1.0,
                        enabled: true
                    ))
                }
            case .adjustBand:
                if let f = op.freqHz, let g = op.gainDB {
                    if let idx = result.enumerated().min(by: { abs($0.element.freqHz - f) < abs($1.element.freqHz - f) })?.offset,
                       abs(result[idx].freqHz - f) < f * 0.25 {
                        result[idx].gainDB = min(max(result[idx].gainDB + g, -12.0), 12.0)
                    } else {
                        result.append(EQBand(
                            type: op.filterType ?? .peak,
                            design: .vicanek,
                            layer: .taste,
                            freqHz: f,
                            gainDB: g,
                            q: op.q ?? 1.0,
                            enabled: true
                        ))
                    }
                }
            case .removeFilter:
                if let f = op.freqHz {
                    result.removeAll { abs($0.freqHz - f) < f * 0.15 }
                }
            case .setTilt:
                let tilt = op.tiltDBPerOctave ?? 0.0
                result.append(EQBand(type: .lowShelf, design: .vicanek, layer: .taste, freqHz: 140, gainDB: -tilt, q: 0.7, enabled: true))
                result.append(EQBand(type: .highShelf, design: .vicanek, layer: .taste, freqHz: 4500, gainDB: tilt, q: 0.7, enabled: true))
            }
        }
        return result
    }
}

public enum AIAssistantRouter {
    public static func proposeVariants(
        prompt: String,
        language: TimbreLanguage,
        allowNetworkOllama: Bool = false
    ) async -> [EQDeltaProposal] {
        let lower = prompt.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            if let onDevice = await tryAppleFoundationModels(prompt: prompt, language: language) {
                return onDevice
            }
        }
        #endif

        if allowNetworkOllama, let ollama = await tryLocalOllama(prompt: prompt, language: language) {
            return ollama
        }

        return deterministicVariants(forLowerPrompt: lower, language: language)
    }

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private static func tryAppleFoundationModels(prompt: String, language: TimbreLanguage) async -> [EQDeltaProposal]? {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return nil }
        let session = LanguageModelSession(instructions: """
        You are an acoustic EQ delta proposer. Output ONLY strict JSON array of 1 to 2 objects with keys:
        {"label": string, "rationale": string, "operations": [{"op":"add_filter","filterType":"peak|lowShelf|highShelf","freqHz":20..20000,"gainDB":-6..6,"q":0.3..6}]}.
        Max 3 operations per variant. Language: \(language.rawValue).
        """)
        guard let response = try? await session.respond(to: prompt),
              let parsed = parseJSONVariants(response.content, runtime: .appleOnDevice) else {
            return nil
        }
        return parsed
    }
    #endif

    private static func tryLocalOllama(prompt: String, language: TimbreLanguage) async -> [EQDeltaProposal]? {
        guard let url = URL(string: "http://127.0.0.1:11434/api/generate") else { return nil }
        var req = URLRequest(url: url, timeoutInterval: 4.0)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "model": "llama3.2:3b",
            "stream": false,
            "prompt": "Return JSON array of EQ deltas (freqHz 20..20000, gainDB -6..6, q 0.3..6, max 3 ops) in \(language.rawValue) for: \(prompt)"
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, http.statusCode == 200,
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = root["response"] as? String else { return nil }
        return parseJSONVariants(text, runtime: .localOllama)
    }

    private struct RawVariant: Decodable {
        let label: String
        let rationale: String
        let operations: [EQDeltaOperation]
    }

    private static func parseJSONVariants(_ text: String, runtime: AIModelRuntime) -> [EQDeltaProposal]? {
        guard let start = text.firstIndex(of: "["), let end = text.lastIndex(of: "]") else { return nil }
        let slice = String(text[start...end])
        guard let data = slice.data(using: .utf8),
              let raw = try? JSONDecoder().decode([RawVariant].self, from: data) else { return nil }
        let validated = raw.compactMap { v -> EQDeltaProposal? in
            let p = EQDeltaProposal(label: v.label, rationale: v.rationale, runtimeUsed: runtime, operations: v.operations)
            return try? EQDeltaValidator.validateAndClamp(p)
        }
        return validated.isEmpty ? nil : validated
    }

    public static func deterministicVariants(forLowerPrompt lower: String, language: TimbreLanguage) -> [EQDeltaProposal] {
        if lower.contains("sibil") || lower.contains("harsh") || lower.contains("ardid") || lower.contains("estriden") {
            let reason = language == .ptBR
                ? "Atenua a região de sibilância (6,8 kHz) e suaviza brilho áspero em 8,5 kHz."
                : (language == .es
                    ? "Atenúa la región de sibilancia (6,8 kHz) y suaviza brillo áspero en 8,5 kHz."
                    : "Attenuates sibilance region (6.8 kHz) and tames harsh upper treble at 8.5 kHz.")
            return [
                try! EQDeltaValidator.validateAndClamp(EQDeltaProposal(
                    label: "A · Suave (6.8 kHz)",
                    rationale: reason,
                    runtimeUsed: .offlineHeuristic,
                    operations: [EQDeltaOperation(op: .addFilter, filterType: .peak, freqHz: 6800, gainDB: -2.5, q: 3.0)]
                )),
                try! EQDeltaValidator.validateAndClamp(EQDeltaProposal(
                    label: "B · Amplo (6.5 + 8.5 kHz)",
                    rationale: reason,
                    runtimeUsed: .offlineHeuristic,
                    operations: [
                        EQDeltaOperation(op: .addFilter, filterType: .peak, freqHz: 6500, gainDB: -2.0, q: 2.2),
                        EQDeltaOperation(op: .addFilter, filterType: .peak, freqHz: 8500, gainDB: -1.5, q: 2.4)
                    ]
                ))
            ]
        }

        if lower.contains("grav") || lower.contains("bass") || lower.contains("bajo") || lower.contains("sub") {
            let reason = language == .ptBR
                ? "Reforço controlado de subgraves (85 Hz) evitando embolar médio-graves."
                : (language == .es
                    ? "Refuerzo controlado de subgraves (85 Hz) sin enturbiar medios graves."
                    : "Controlled sub-bass lift (85 Hz) without muddying upper bass.")
            return [
                try! EQDeltaValidator.validateAndClamp(EQDeltaProposal(
                    label: "A · Sub limpo (+2.5 dB)",
                    rationale: reason,
                    runtimeUsed: .offlineHeuristic,
                    operations: [EQDeltaOperation(op: .addFilter, filterType: .lowShelf, freqHz: 85, gainDB: 2.5, q: 0.7)]
                )),
                try! EQDeltaValidator.validateAndClamp(EQDeltaProposal(
                    label: "B · Punch (+3.5 dB / -1 dB 220 Hz)",
                    rationale: reason,
                    runtimeUsed: .offlineHeuristic,
                    operations: [
                        EQDeltaOperation(op: .addFilter, filterType: .lowShelf, freqHz: 95, gainDB: 3.5, q: 0.7),
                        EQDeltaOperation(op: .addFilter, filterType: .peak, freqHz: 220, gainDB: -1.0, q: 1.2)
                    ]
                ))
            ]
        }

        if lower.contains("voz") || lower.contains("vocal") || lower.contains("presen") {
            let reason = language == .ptBR
                ? "Traz voz e presença à frente em 2,6 kHz sem forçar agudos."
                : (language == .es
                    ? "Acerca voces y presencia en 2,6 kHz sin forzar agudos."
                    : "Brings vocals forward around 2.6 kHz without adding upper-treble glare.")
            return [
                try! EQDeltaValidator.validateAndClamp(EQDeltaProposal(
                    label: "A · Presença vocal (+2.0 dB)",
                    rationale: reason,
                    runtimeUsed: .offlineHeuristic,
                    operations: [EQDeltaOperation(op: .addFilter, filterType: .peak, freqHz: 2600, gainDB: 2.0, q: 1.1)]
                ))
            ]
        }

        let warmReason = language == .ptBR
            ? "Adiciona corpo nos médio-graves (240 Hz) e inclinação suave de agudos."
            : (language == .es
                ? "Añade cuerpo en medios graves (240 Hz) e inclinación suave de agudos."
                : "Adds low-mid warmth (240 Hz) with gentle treble relaxation.")
        return [
            try! EQDeltaValidator.validateAndClamp(EQDeltaProposal(
                label: "A · Calor sutil",
                rationale: warmReason,
                runtimeUsed: .offlineHeuristic,
                operations: [
                    EQDeltaOperation(op: .addFilter, filterType: .peak, freqHz: 240, gainDB: 1.5, q: 0.9),
                    EQDeltaOperation(op: .addFilter, filterType: .highShelf, freqHz: 8000, gainDB: -1.0, q: 0.7)
                ]
            )),
            try! EQDeltaValidator.validateAndClamp(EQDeltaProposal(
                label: "B · Tilt quente",
                rationale: warmReason,
                runtimeUsed: .offlineHeuristic,
                operations: [
                    EQDeltaOperation(op: .addFilter, filterType: .lowShelf, freqHz: 120, gainDB: 2.0, q: 0.7),
                    EQDeltaOperation(op: .addFilter, filterType: .highShelf, freqHz: 6000, gainDB: -1.5, q: 0.7)
                ]
            ))
        ]
    }
}
