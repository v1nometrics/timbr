// SPDX-License-Identifier: MPL-2.0
import Foundation

public struct AutoEqEntry: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let headphoneName: String
    public let source: String
    public let rig: String
    public let target: String
    public let relativePath: String
    public let bundledAPO: String?

    public init(
        id: String,
        headphoneName: String,
        source: String,
        rig: String,
        target: String,
        relativePath: String,
        bundledAPO: String? = nil
    ) {
        self.id = id
        self.headphoneName = headphoneName
        self.source = source
        self.rig = rig
        self.target = target
        self.relativePath = relativePath
        self.bundledAPO = bundledAPO
    }
}

public enum AutoEqService {
    public static let starterCatalog: [AutoEqEntry] = [
        AutoEqEntry(
            id: "sennheiser-momentum-4-bt-oratory1990",
            headphoneName: "Sennheiser Momentum 4 Wireless (ANC On)",
            source: "oratory1990 (AutoEq)",
            rig: "GRAS 45BC-10",
            target: "Harman over-ear 2018",
            relativePath: "results/oratory1990/over-ear/Sennheiser%20Momentum%204%20Wireless/Sennheiser%20Momentum%204%20Wireless%20ParametricEQ.txt",
            bundledAPO: """
            # Starter AutoEq reference placeholder — fetch live AutoEq on demand for latest measurement
            Preamp: -4.8 dB
            Filter 1: ON LSC Fc 105 Hz Gain -3.5 dB Q 0.70
            Filter 2: ON PK Fc 190 Hz Gain -2.2 dB Q 1.10
            Filter 3: ON PK Fc 1650 Hz Gain 2.8 dB Q 1.40
            Filter 4: ON PK Fc 3200 Hz Gain 3.6 dB Q 1.80
            Filter 5: ON PK Fc 5800 Hz Gain -2.4 dB Q 2.60
            Filter 6: ON HSC Fc 10000 Hz Gain 1.5 dB Q 0.70
            """
        ),
        AutoEqEntry(
            id: "sennheiser-momentum-4-passive-rtings",
            headphoneName: "Sennheiser Momentum 4 Wireless (Passive 60 Ω)",
            source: "Rtings (AutoEq)",
            rig: "HMS II.3",
            target: "Harman over-ear 2018",
            relativePath: "results/Rtings/over-ear/Sennheiser%20Momentum%204%20Wireless/Sennheiser%20Momentum%204%20Wireless%20ParametricEQ.txt",
            bundledAPO: """
            Preamp: -5.5 dB
            Filter 1: ON LSC Fc 95 Hz Gain 3.2 dB Q 0.70
            Filter 2: ON PK Fc 240 Hz Gain -2.8 dB Q 1.20
            Filter 3: ON PK Fc 2900 Hz Gain 4.8 dB Q 1.50
            Filter 4: ON PK Fc 6500 Hz Gain -2.0 dB Q 2.40
            """
        ),
        AutoEqEntry(
            id: "apple-airpods-pro-2-crinacle",
            headphoneName: "Apple AirPods Pro 2",
            source: "crinacle (AutoEq)",
            rig: "IEC 60318-4",
            target: "Harman in-ear 2019",
            relativePath: "results/crinacle/in-ear/Apple%20AirPods%20Pro%202/Apple%20AirPods%20Pro%202%20ParametricEQ.txt",
            bundledAPO: """
            Preamp: -3.4 dB
            Filter 1: ON PK Fc 160 Hz Gain -1.4 dB Q 1.20
            Filter 2: ON PK Fc 3100 Hz Gain 2.4 dB Q 1.70
            Filter 3: ON PK Fc 6200 Hz Gain -1.8 dB Q 2.80
            Filter 4: ON HSC Fc 11500 Hz Gain 2.0 dB Q 0.70
            """
        ),
        AutoEqEntry(
            id: "apple-airpods-pro-1-crinacle",
            headphoneName: "Apple AirPods Pro",
            source: "crinacle (AutoEq)",
            rig: "IEC 60318-4",
            target: "Harman in-ear 2019",
            relativePath: "results/crinacle/in-ear/Apple%20AirPods%20Pro/Apple%20AirPods%20Pro%20ParametricEQ.txt",
            bundledAPO: """
            Preamp: -3.8 dB
            Filter 1: ON PK Fc 180 Hz Gain -1.8 dB Q 1.10
            Filter 2: ON PK Fc 2800 Hz Gain 2.6 dB Q 1.60
            Filter 3: ON PK Fc 6800 Hz Gain -2.2 dB Q 2.40
            """
        ),
        AutoEqEntry(
            id: "apple-airpods-3-crinacle",
            headphoneName: "Apple AirPods (3rd generation)",
            source: "crinacle (AutoEq)",
            rig: "IEC 60318-4",
            target: "Harman in-ear 2019",
            relativePath: "results/crinacle/in-ear/Apple%20AirPods%20%283rd%20generation%29/Apple%20AirPods%20%283rd%20generation%29%20ParametricEQ.txt",
            bundledAPO: """
            Preamp: -4.2 dB
            Filter 1: ON LSC Fc 105 Hz Gain 2.0 dB Q 0.70
            Filter 2: ON PK Fc 2400 Hz Gain 3.0 dB Q 1.40
            Filter 3: ON PK Fc 7500 Hz Gain -2.5 dB Q 2.20
            """
        ),
        AutoEqEntry(
            id: "apple-airpods-max-oratory",
            headphoneName: "Apple AirPods Max",
            source: "oratory1990 (AutoEq)",
            rig: "GRAS 45BC-10",
            target: "Harman over-ear 2018",
            relativePath: "results/oratory1990/over-ear/Apple%20AirPods%20Max/Apple%20AirPods%20Max%20ParametricEQ.txt",
            bundledAPO: """
            Preamp: -6.0 dB
            Filter 1: ON LSC Fc 105 Hz Gain -2.5 dB Q 0.70
            Filter 2: ON PK Fc 210 Hz Gain -2.0 dB Q 1.00
            Filter 3: ON PK Fc 3200 Hz Gain 3.5 dB Q 1.50
            Filter 4: ON PK Fc 6000 Hz Gain -1.8 dB Q 2.00
            Filter 5: ON HSC Fc 10000 Hz Gain 1.2 dB Q 0.70
            """
        )
    ]

    public static func matchDeviceName(_ deviceName: String, catalog: [AutoEqEntry] = starterCatalog) -> [AutoEqEntry] {
        let norm = normalize(deviceName)
        guard !norm.isEmpty else { return catalog }
        let tokens = norm.split(separator: " ").map(String.init)
        let scored: [(AutoEqEntry, Int)] = catalog.map { entry in
            let targetNorm = normalize(entry.headphoneName)
            var score = 0
            for t in tokens where targetNorm.contains(t) { score += t.count * 2 }
            if targetNorm.contains("momentum 4") && norm.contains("momentum") { score += 40 }
            if targetNorm.contains("airpods max") && norm.contains("airpods max") { score += 50 }
            if targetNorm.contains("airpods pro") && norm.contains("airpods pro") { score += 50 }
            else if targetNorm.contains("airpods") && norm.contains("airpods") { score += 30 }
            return (entry, score)
        }
        let matches = scored.filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }.map(\.0)
        return matches.isEmpty ? catalog : matches
    }

    private static func normalize(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "[^a-z0-9 ]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    public static func cacheDirectory() -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return caches.appendingPathComponent("dev.v1torres.timbr/autoeq", isDirectory: true)
    }

    public static func loadParametricEQ(
        entry: AutoEqEntry,
        allowNetwork: Bool,
        cacheTTLSeconds: TimeInterval = 7 * 24 * 3600
    ) async throws -> (parsed: ParsedEqualizerAPO, fromCacheOrOffline: Bool) {
        let cacheDir = cacheDirectory()
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        let cachedURL = cacheDir.appendingPathComponent("\(entry.id).txt")

        if let attrs = try? FileManager.default.attributesOfItem(atPath: cachedURL.path),
           let modDate = attrs[.modificationDate] as? Date,
           Date().timeIntervalSince(modDate) < cacheTTLSeconds,
           let cachedText = try? String(contentsOf: cachedURL, encoding: .utf8),
           let parsed = try? EqualizerAPOParser.parse(cachedText, layer: .correction) {
            return (parsed, true)
        }

        if allowNetwork,
           let url = URL(string: "https://raw.githubusercontent.com/jaakkopasanen/AutoEq/master/\(entry.relativePath)") {
            var req = URLRequest(url: url, timeoutInterval: 8.0)
            req.setValue("timbr/1.0", forHTTPHeaderField: "User-Agent")
            if let (data, resp) = try? await URLSession.shared.data(for: req),
               let http = resp as? HTTPURLResponse, http.statusCode == 200,
               let text = String(data: data, encoding: .utf8),
               let parsed = try? EqualizerAPOParser.parse(text, layer: .correction) {
                try? text.write(to: cachedURL, atomically: true, encoding: .utf8)
                return (parsed, false)
            }
        }

        if let bundled = entry.bundledAPO {
            return (try EqualizerAPOParser.parse(bundled, layer: .correction), true)
        }
        throw EqualizerAPOParserError.emptyOrNoFilters
    }
}
