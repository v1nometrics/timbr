// SPDX-License-Identifier: MPL-2.0
// Feedback by e-mail (ADR-0024). The app promises "100% local, zero telemetry", so nothing here is sent
// by timbr: the person writes, sees exactly what the e-mail will contain, and their own mail app sends it.
// The context that travels with it is five coarse facts, each one switchable. Never device names, event
// logs, file paths, user names or audio.
import Foundation

public enum FeedbackCategory: String, CaseIterable, Sendable {
    case suggestion, bug, device, praise, other

    /// The recipient reads Portuguese, whatever language the app is in.
    public var subjectLabel: String {
        switch self {
        case .suggestion: return "Sugestão"
        case .bug: return "Problema"
        case .device: return "Pedido de fone ou app"
        case .praise: return "Elogio"
        case .other: return "Outro"
        }
    }
}

/// Which coarse facts go along. All on by default; the person can switch each one off.
public struct FeedbackOptions: Equatable, Sendable {
    public var app = true
    public var system = true
    public var output = true
    public var equalizer = true
    public var language = true
    public init() {}
}

public struct FeedbackContext: Equatable, Sendable {
    public var appVersion: String        // "1.0 (12)"
    public var macOS: String             // "Version 26.6 (Build 25G72)"
    public var outputKind: String        // "Bluetooth", "fone com fio"… a kind of output, never its name
    public var equalizerMode: String     // "10 bandas"
    public var language: String          // "pt-BR"
    public init(appVersion: String, macOS: String, outputKind: String, equalizerMode: String, language: String) {
        self.appVersion = appVersion; self.macOS = macOS; self.outputKind = outputKind
        self.equalizerMode = equalizerMode; self.language = language
    }
}

public enum FeedbackComposer {
    public static let recipient = "vinicius@v1torres.dev"
    public static let minMessageLength = 10
    public static let maxMessageLength = 1500

    /// A kind of output for the context line. Deliberately not the device's name.
    public static func outputKind(for transport: DeviceTransport) -> String {
        switch transport {
        case .builtIn: return "alto-falantes ou saída interna"
        case .bluetoothA2DP, .bluetoothHFP: return "Bluetooth"
        case .wiredAnalog: return "fone com fio"
        case .usb: return "USB"
        case .hdmi: return "HDMI"
        case .aggregate, .virtual: return "virtual"
        case .continuity: return "Continuity"
        case .unknown: return "desconhecida"
        }
    }

    /// Trims, unifies line breaks, drops control characters and caps the length.
    public static func normalize(_ text: String) -> String {
        let unified = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let cleaned = String(unified.unicodeScalars.filter { $0 == "\n" || $0 == "\t" || !CharacterSet.controlCharacters.contains($0) })
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(maxMessageLength))
    }

    public static func isSendable(_ message: String) -> Bool { normalize(message).count >= minMessageLength }

    public static func subject(_ category: FeedbackCategory) -> String { "[timbr] \(category.subjectLabel)" }

    public static func body(message: String, context: FeedbackContext, options: FeedbackOptions) -> String {
        var lines: [String] = [normalize(message)]
        var ctx: [String] = []
        if options.app { ctx.append("timbr: \(context.appVersion)") }
        if options.system { ctx.append("macOS: \(context.macOS)") }
        if options.output { ctx.append("Saída: \(context.outputKind)") }
        if options.equalizer { ctx.append("Equalizador: \(context.equalizerMode)") }
        if options.language { ctx.append("Idioma do app: \(context.language)") }
        if !ctx.isEmpty {
            lines.append("")
            lines.append("—")
            lines.append("Contexto (só o que você deixou marcado):")
            lines.append(contentsOf: ctx)
        }
        return lines.joined(separator: "\n")
    }

    /// RFC 6068: everything except unreserved characters is percent-encoded, including line breaks.
    public static func mailtoURL(category: FeedbackCategory, message: String, context: FeedbackContext, options: FeedbackOptions) -> URL? {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        func enc(_ s: String) -> String { s.addingPercentEncoding(withAllowedCharacters: allowed) ?? "" }
        let crlf = body(message: message, context: context, options: options).replacingOccurrences(of: "\n", with: "\r\n")
        return URL(string: "mailto:\(recipient)?subject=\(enc(subject(category)))&body=\(enc(crlf))")
    }
}
