// SPDX-License-Identifier: MPL-2.0
import Foundation

public enum TimbreLanguage: String, Codable, CaseIterable, Sendable {
    case ptBR = "pt-BR"
    case es = "es"
    case en = "en"

    public var displayName: String {
        switch self {
        case .ptBR: return "Português"
        case .es: return "Español"
        case .en: return "English"
        }
    }

    public var tagline: String {
        switch self {
        case .ptBR: return "Som, precisamente seu."
        case .es: return "Sonido, precisamente tuyo."
        case .en: return "Sound, precisely yours."
        }
    }

    public static func fromSystemLocale(_ locale: Locale = .current) -> TimbreLanguage {
        let code = locale.language.languageCode?.identifier.lowercased() ?? "en"
        if code == "pt" { return .ptBR }
        if code == "es" { return .es }
        return .en
    }
}

public enum TimbreStrings {
    public static let table: [String: [TimbreLanguage: String]] = [
        // Brand & Surfaces
        "app.name": [.ptBR: "timbr.", .es: "timbr.", .en: "timbr."],
        "nav.mixer": [.ptBR: "Mixer", .es: "Mezclador", .en: "Mixer"],
        "nav.eq": [.ptBR: "Equalizador", .es: "Ecualizador", .en: "Equalizer"],
        "nav.observatory": [.ptBR: "Observatório", .es: "Observatorio", .en: "Observatory"],
        "nav.settings": [.ptBR: "Ajustes", .es: "Ajustes", .en: "Settings"],
        "nav.support": [.ptBR: "Apoiar projeto", .es: "Apoyar proyecto", .en: "Support & Donate"],

        // Compact Notch short tokens (C-08: strict <= 40pt ear budget)
        "notch.compact.eq": [.ptBR: "EQ", .es: "EQ", .en: "EQ"],
        "notch.compact.bit": [.ptBR: "BIT", .es: "BIT", .en: "BIT"],
        "notch.compact.hfp": [.ptBR: "HFP", .es: "HFP", .en: "HFP"],
        "notch.compact.clip": [.ptBR: "CLIP", .es: "CLIP", .en: "CLIP"],
        "notch.open_studio": [.ptBR: "Abrir Estúdio", .es: "Abrir Estudio", .en: "Open Studio"],
        "notch.bypass": [.ptBR: "Bypass", .es: "Bypass", .en: "Bypass"],
        "notch.ab_neutral": [.ptBR: "A/B neutro", .es: "A/B neutro", .en: "Neutral A/B"],
        "notch.empty_playing": [.ptBR: "Nenhuma fonte tocando", .es: "Sin audio activo", .en: "Nothing playing"],
        "notch.menu_only_badge": [.ptBR: "Só barra de menus", .es: "Solo barra de menús", .en: "Menu bar only"],

        // Mixer & Routing
        "mixer.title": [.ptBR: "Fontes de áudio", .es: "Fuentes de audio", .en: "Audio Sources"],
        "mixer.destinations": [.ptBR: "Destinos", .es: "Salidas", .en: "Outputs"],
        "mixer.voip_ignored": [.ptBR: "Protegido (VoIP/DAW)", .es: "Protegido (VoIP/DAW)", .en: "Protected (VoIP/DAW)"],
        "mixer.boost_warning": [.ptBR: "pode clipar", .es: "puede saturar", .en: "may clip"],
        "mixer.no_taps": [.ptBR: "Caminho nativo sem taps", .es: "Ruta nativa sin taps", .en: "Native path (0 taps)"],
        "mixer.tabs_note": [.ptBR: "Controle por aba requer extensão", .es: "Control por pestaña requiere extensión", .en: "Per-tab control requires extension"],

        // EQ Layers & Controls
        "eq.layer.correction": [.ptBR: "Correção", .es: "Corrección", .en: "Correction"],
        "eq.layer.taste": [.ptBR: "Gosto", .es: "Gusto", .en: "Taste"],
        "eq.layer.result": [.ptBR: "Resultado", .es: "Resultado", .en: "Result"],
        "eq.mode.simple": [.ptBR: "Simples", .es: "Simple", .en: "Simple"],
        "eq.mode.advanced": [.ptBR: "PEQ Livre", .es: "PEQ Libre", .en: "Free PEQ"],
        "eq.taste.bass": [.ptBR: "Graves", .es: "Graves", .en: "Bass"],
        "eq.taste.warmth": [.ptBR: "Calor", .es: "Calidez", .en: "Warmth"],
        "eq.taste.presence": [.ptBR: "Presença", .es: "Presencia", .en: "Presence"],
        "eq.taste.air": [.ptBR: "Ar", .es: "Aire", .en: "Air"],
        "eq.preamp": [.ptBR: "Preamp", .es: "Preamplificador", .en: "Preamp"],
        "eq.headroom": [.ptBR: "Headroom", .es: "Headroom", .en: "Headroom"],
        "eq.limiter_on": [.ptBR: "Limiter True-Peak", .es: "Limitador True-Peak", .en: "True-Peak Limiter"],
        "eq.crossfeed": [.ptBR: "Crossfeed", .es: "Crossfeed", .en: "Crossfeed"],
        "eq.blind_ab": [.ptBR: "A/B Cego (X vs Y)", .es: "A/B Ciego (X vs Y)", .en: "Blind A/B (X vs Y)"],
        "eq.import_apo": [.ptBR: "Importar APO .txt", .es: "Importar APO .txt", .en: "Import APO .txt"],
        "eq.export_apo": [.ptBR: "Exportar APO .txt", .es: "Exportar APO .txt", .en: "Export APO .txt"],
        "eq.ai_placeholder": [.ptBR: "Descreva o ajuste (ex.: menos sibilância)...", .es: "Describe el ajuste (ej.: menos sibilancia)...", .en: "Describe tuning (e.g., less sibilance)..."],
        "eq.ai_apply": [.ptBR: "Propor ajuste", .es: "Proponer ajuste", .en: "Propose tweak"],
        "eq.trainer_title": [.ptBR: "Treinador de Gosto (A/B)", .es: "Entrenador de Gusto (A/B)", .en: "Taste Trainer (A/B)"],

        // Observatory & Trust Badges
        "obs.badge.measured": [.ptBR: "MEDIDO", .es: "MEDIDO", .en: "MEASURED"],
        "obs.badge.reported": [.ptBR: "REPORTADO", .es: "REPORTADO", .en: "REPORTED"],
        "obs.badge.inferred": [.ptBR: "INFERIDO", .es: "INFERIDO", .en: "INFERRED"],
        "obs.badge.bitperfect": [.ptBR: "BIT-PERFECT", .es: "BIT-PERFECT", .en: "BIT-PERFECT"],
        "obs.stage.sources": [.ptBR: "Fontes", .es: "Fuentes", .en: "Sources"],
        "obs.stage.mixer": [.ptBR: "Mixer", .es: "Mezclador", .en: "Mixer"],
        "obs.stage.correction": [.ptBR: "Correção", .es: "Corrección", .en: "Correction"],
        "obs.stage.taste": [.ptBR: "Gosto", .es: "Gusto", .en: "Taste"],
        "obs.stage.protection": [.ptBR: "Proteção", .es: "Protección", .en: "Protection"],
        "obs.stage.device": [.ptBR: "Dispositivo", .es: "Dispositivo", .en: "Device"],
        "obs.stage.headphone": [.ptBR: "Fone", .es: "Auricular", .en: "Headphone"],

        // Momentum 4 & Devices
        "obs.clean_chain": [.ptBR: "Nenhuma anomalia ativa. Cadeia limpa.", .es: "Sin anomalías activas. Cadena limpia.", .en: "No active anomalies. Signal chain clean."],
        "dev.m4.refresh": [.ptBR: "Atualizar telemetria", .es: "Actualizar telemetría", .en: "Refresh telemetry"],
        "dev.m4.battery": [.ptBR: "Bateria", .es: "Batería", .en: "Battery"],
        "dev.m4.anc_on": [.ptBR: "ANC Ativo", .es: "ANC Activo", .en: "ANC On"],
        "dev.m4.anc_off": [.ptBR: "ANC Desligado", .es: "ANC Desactivado", .en: "ANC Off"],
        "dev.m4.transparency": [.ptBR: "Transparência", .es: "Transparencia", .en: "Transparency"],
        "dev.m4.eq_non_flat": [.ptBR: "EQ interno ativo", .es: "EQ interno activo", .en: "Internal EQ active"],
        "dev.m4.p2_active": [.ptBR: "Ativo 470 Ω", .es: "Activo 470 Ω", .en: "Active 470 Ω"],
        "dev.m4.p2_passive": [.ptBR: "Passivo 60 Ω", .es: "Pasivo 60 Ω", .en: "Passive 60 Ω"],
        "dev.m4.read_only": [.ptBR: "Somente leitura", .es: "Solo lectura", .en: "Read-only"],
        "dev.hw_volume": [.ptBR: "Volume de Hardware", .es: "Volumen de Hardware", .en: "Hardware Volume"],
        "dev.sw_volume": [.ptBR: "Volume em Software", .es: "Volumen por Software", .en: "Software Volume"],

        // Guardian rules
        "guard.silent_studio": [.ptBR: "Modo Estúdio Silencioso", .es: "Modo Estudio Silencioso", .en: "Silent Studio Mode"],
        "guard.g01": [.ptBR: "Queda para modo chamada (HFP)", .es: "Cambio a modo llamada (HFP)", .en: "Switched to call mode (HFP)"],
        "guard.g02": [.ptBR: "Reamostragem detectada", .es: "Remuestreo detectado", .en: "Sample rate mismatch"],
        "guard.g03": [.ptBR: "Limiter atuando com frequência", .es: "Limitador actuando con frecuencia", .en: "Limiter engaging frequently"],
        "guard.g04": [.ptBR: "EQ duplo (fone + sistema)", .es: "Ecualización doble (auricular + sistema)", .en: "Double EQ active (headphone + macOS)"],
        "guard.g05": [.ptBR: "Volume em software evitável", .es: "Volumen por software evitable", .en: "Avoidable software volume"],
        "guard.g06": [.ptBR: "Saída alterada pelo sistema", .es: "Salida cambiada por el sistema", .en: "System changed audio output"],
        "guard.g07": [.ptBR: "Conflito com outro app de captura", .es: "Conflicto con otra app de captura", .en: "Audio capture conflict detected"],
        "guard.action.mic_internal": [.ptBR: "Usar microfone interno", .es: "Usar micrófono interno", .en: "Use built-in mic"],
        "guard.action.increase_headroom": [.ptBR: "Aumentar margem do preamp", .es: "Aumentar margen del preamp", .en: "Increase preamp headroom"],
        "guard.action.ignore_pair": [.ptBR: "Silenciar alerta para este par", .es: "Silenciar alerta para este par", .en: "Silence for this pair"],

        // Permissions (Pre-TCC honest explainers)
        "tcc.audio.why": [
            .ptBR: "Necessário para ajustar volume por app e aplicar EQ de sistema. O timbr. nunca grava nem envia seu áudio.",
            .es: "Necesario para ajustar volumen por app y aplicar EQ del sistema. timbr. nunca graba ni envía tu audio.",
            .en: "Needed to adjust per-app volume and apply system EQ. timbr. never records or transmits your audio."
        ],
        "tcc.ax.why": [
            .ptBR: "Opcional: permite que as teclas de volume controlem o destino ativo e exibam o HUD no notch.",
            .es: "Opcional: permite que las teclas de volumen controlen la salida activa y muestren el HUD en el notch.",
            .en: "Optional: lets media volume keys control the active output and show the notch HUD."
        ],
        "tcc.bt.why": [
            .ptBR: "Opcional: lê telemetria (bateria, ANC e EQ interno) no Sennheiser Momentum 4 via RFCOMM.",
            .es: "Opcional: lee telemetría (batería, ANC y EQ interno) del Sennheiser Momentum 4 vía RFCOMM.",
            .en: "Optional: reads telemetry (battery, ANC, internal EQ) on Sennheiser Momentum 4 via RFCOMM."
        ],

        // Support & Donations Tab
        "support.title": [.ptBR: "Apoiar o timbr.", .es: "Apoyar a timbr.", .en: "Support timbr."],
        "support.body": [
            .ptBR: "O timbr. é software livre sob licença MPL-2.0, 100% local e sem telemetria. Se ele melhora sua escuta diária, considere apoiar o desenvolvimento contínuo.",
            .es: "timbr. es software libre bajo licencia MPL-2.0, 100% local y sin telemetría. Si mejora tu escucha diaria, considera apoyar su desarrollo.",
            .en: "timbr. is free open-source software under MPL-2.0, 100% local with zero telemetry. If it elevates your daily listening, consider supporting development."
        ],
        "support.license": [.ptBR: "Licença: MPL-2.0 · Sem assinatura obrigatória", .es: "Licencia: MPL-2.0 · Sin suscripción obligatoria", .en: "License: MPL-2.0 · No mandatory subscription"]
    ]

    public static func get(_ key: String, lang: TimbreLanguage) -> String {
        table[key]?[lang] ?? table[key]?[.en] ?? key
    }

    public static var allKeys: [String] { Array(table.keys).sorted() }
}
