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
        "app.name": [.ptBR: "timbr", .es: "timbr", .en: "timbr"],
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
        "mixer.multi_output": [.ptBR: "Saídas Simultâneas (Multissaída)", .es: "Salidas Simultáneas", .en: "Simultaneous Multi-Output"],
        "mixer.delay_ms": [.ptBR: "Atraso", .es: "Retraso", .en: "Delay"],
        "mixer.auto_duck": [.ptBR: "Atenuar mídia durante chamadas (-12 dB)", .es: "Atenuar medios en llamadas (-12 dB)", .en: "Auto-duck media during calls (-12 dB)"],
        "mixer.tabs_note": [.ptBR: "Controle por aba requer extensão", .es: "Control por pestaña requiere extensión", .en: "Per-tab control requires extension"],
        "mixer.reset_flat": [.ptBR: "Resetar flat", .es: "Restablecer flat", .en: "Reset flat"],
        "mixer.reset_flat_done": [
            .ptBR: "Volumes das fontes em flat (100%).",
            .es: "Volúmenes de fuentes en flat (100%).",
            .en: "Source volumes reset to flat (100%)."
        ],
        "mixer.reset_flat_help": [
            .ptBR: "Volta todos os apps (e abas) para 100% e desmuta. VoIP/DAW permanecem protegidos.",
            .es: "Vuelve todas las apps (y pestañas) a 100% y quita el mute. VoIP/DAW siguen protegidos.",
            .en: "Sets every app (and tab) to 100% and unmutes. VoIP/DAW rows stay protected."
        ],

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
        "eq.ai_placeholder": [.ptBR: "Ex.: menos sibilância em 6 kHz, mais sub-grave…", .es: "Ej.: menos sibilancia en 6 kHz, más sub-grave…", .en: "E.g., less sibilance at 6 kHz, more sub-bass…"],
        "eq.ai_apply": [.ptBR: "Sugerir curva", .es: "Sugerir curva", .en: "Suggest curve"],
        "eq.trainer_title": [.ptBR: "Refinamento A/B", .es: "Refinamiento A/B", .en: "A/B Refinement"],

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
        "dev.apple.family": [.ptBR: "Linha Apple", .es: "Línea Apple", .en: "Apple lineup"],
        "dev.apple.battery_l": [.ptBR: "Esq.", .es: "Izq.", .en: "L"],
        "dev.apple.battery_r": [.ptBR: "Dir.", .es: "Der.", .en: "R"],
        "dev.apple.battery_case": [.ptBR: "Case", .es: "Estuche", .en: "Case"],
        "dev.apple.aacp_closed": [
            .ptBR: "ANC/Transparency: controlados pelo macOS (AACP fechado a apps de terceiros).",
            .es: "ANC/Transparency: controlados por macOS (AACP cerrado a apps de terceros).",
            .en: "ANC/Transparency: controlled by macOS (AACP closed to third-party apps)."
        ],
        "dev.apple.spatial_warn": [
            .ptBR: "Áudio Espacial / Head Tracking pode alterar a resposta — AutoEq é aproximado.",
            .es: "Audio Espacial / Head Tracking puede alterar la respuesta — AutoEq es aproximado.",
            .en: "Spatial Audio / Head Tracking may alter FR — AutoEq is approximate."
        ],
        "dev.apple.continuity_hint": [
            .ptBR: "Bateria L/R/Case via Continuity BLE quando o case está aberto (passivo, sem AACP).",
            .es: "Batería L/R/Estuche vía Continuity BLE con el estuche abierto (pasivo, sin AACP).",
            .en: "L/R/Case battery via Continuity BLE when the lid is open (passive, no AACP)."
        ],
        "dev.apple.refresh_scan": [.ptBR: "Atualizar Continuity", .es: "Actualizar Continuity", .en: "Refresh Continuity"],
        "dev.apple.features_title": [.ptBR: "Recursos do sistema (somente leitura)", .es: "Funciones del sistema (solo lectura)", .en: "System features (read-only)"],
        "dev.apple.features_system": [
            .ptBR: "Gerenciados pelo macOS. O timbr não controla ANC, Adaptive Audio nem Hearing Aid (AACP fechado).",
            .es: "Gestionados por macOS. timbr no controla ANC, Adaptive Audio ni Hearing Aid (AACP cerrado).",
            .en: "Managed by macOS. timbr does not control ANC, Adaptive Audio, or Hearing Aid (AACP closed)."
        ],
        "dev.apple.feature.activeNoiseCancellation": [.ptBR: "ANC", .es: "ANC", .en: "ANC"],
        "dev.apple.feature.transparency": [.ptBR: "Transparência", .es: "Transparencia", .en: "Transparency"],
        "dev.apple.feature.adaptiveAudio": [.ptBR: "Adaptive Audio", .es: "Adaptive Audio", .en: "Adaptive Audio"],
        "dev.apple.feature.conversationAwareness": [.ptBR: "Conversation Awareness", .es: "Conversation Awareness", .en: "Conversation Awareness"],
        "dev.apple.feature.personalizedSpatialAudio": [.ptBR: "Áudio Espacial", .es: "Audio Espacial", .en: "Spatial Audio"],
        "dev.apple.feature.hearingAid": [.ptBR: "Hearing Aid", .es: "Hearing Aid", .en: "Hearing Aid"],
        "dev.apple.feature.hearingTest": [.ptBR: "Hearing Test", .es: "Hearing Test", .en: "Hearing Test"],
        "dev.apple.feature.hearingProtection": [.ptBR: "Hearing Protection", .es: "Hearing Protection", .en: "Hearing Protection"],
        "dev.apple.feature.voiceIsolation": [.ptBR: "Voice Isolation", .es: "Voice Isolation", .en: "Voice Isolation"],
        "dev.apple.mixer_hint": [
            .ptBR: "Destino Apple ativo — bateria via Continuity; EQ no Mac (AutoEq).",
            .es: "Salida Apple activa — batería vía Continuity; EQ en el Mac (AutoEq).",
            .en: "Apple output active — Continuity battery; EQ on Mac (AutoEq)."
        ],
        "notch.compact.bat": [.ptBR: "BAT", .es: "BAT", .en: "BAT"],
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
            .ptBR: "Necessário para ajustar volume por app e aplicar EQ de sistema. Se o timbr não aparecer na lista, ajuste o volume de um app no Mixer para solicitar acesso. O áudio não é salvo nem enviado.",
            .es: "Necesario para ajustar volumen por app y aplicar EQ del sistema. Si timbr no aparece en la lista, ajusta el volumen de una app en el Mezclador para solicitar acceso. El audio no se guarda ni se envía.",
            .en: "Needed to adjust per-app volume and apply system EQ. If timbr is missing from the list, adjust an app’s volume in Mixer to request access. Audio is never saved or sent."
        ],
        "tcc.ax.why": [
            .ptBR: "Ative timbr em Acessibilidade para usar as teclas de volume e brilho no notch. Use + se ele não aparecer.",
            .es: "Opcional: permite que las teclas de volumen controlen la salida activa y muestren el HUD en el notch.",
            .en: "Enable timbr in Accessibility to use volume and brightness keys in the notch. Use + if it is missing."
        ],
        "tcc.bt.why": [
            .ptBR: "Opcional: lê telemetria (bateria, ANC e EQ interno) no Sennheiser Momentum 4 via RFCOMM.",
            .es: "Opcional: lee telemetría (batería, ANC y EQ interno) del Sennheiser Momentum 4 vía RFCOMM.",
            .en: "Optional: reads telemetry (battery, ANC, internal EQ) on Sennheiser Momentum 4 via RFCOMM."
        ],
        "tcc.audio.title": [.ptBR: "Captura de áudio do sistema", .es: "Captura de audio del sistema", .en: "System audio capture"],
        "tcc.ax.title": [.ptBR: "Acessibilidade (teclas de mídia)", .es: "Accesibilidad (teclas de medios)", .en: "Accessibility (media keys)"],
        "tcc.bt.title": [.ptBR: "Bluetooth (Momentum 4)", .es: "Bluetooth (Momentum 4)", .en: "Bluetooth (Momentum 4)"],
        "tcc.open_settings": [.ptBR: "Abrir Ajustes do Sistema", .es: "Abrir Ajustes del Sistema", .en: "Open System Settings"],
        "tcc.status.ok": [.ptBR: "Concedido", .es: "Concedido", .en: "Granted"],
        "tcc.status.check_in_settings": [.ptBR: "Ver nos Ajustes", .es: "Ver en Ajustes", .en: "See in Settings"],
        "tcc.status.pending": [.ptBR: "Pendente", .es: "Pendiente", .en: "Pending"],
        "tcc.status.optional": [.ptBR: "Opcional", .es: "Opcional", .en: "Optional"],

        // First-run onboarding (RF-1401)
        "onboard.install.title": [.ptBR: "Instale o timbr em Aplicativos", .es: "Instala timbr en Aplicaciones", .en: "Install timbr in Applications"],
        "onboard.install.body": [.ptBR: "No disco timbr, arraste o app para Aplicativos. Abra a cópia instalada para configurar as permissões.", .es: "En el disco timbr, arrastra la app a Aplicaciones. Abre la copia instalada para configurar los permisos.", .en: "On the timbr disk, drag the app to Applications. Open the installed copy to set up permissions."],
        "onboard.install.show_disk": [.ptBR: "Mostrar disco no Finder", .es: "Mostrar disco en Finder", .en: "Show disk in Finder"],
        "onboard.install.close": [.ptBR: "Fechar", .es: "Cerrar", .en: "Close"],
        "onboard.kicker": [.ptBR: "Bem-vindo", .es: "Bienvenido", .en: "Welcome"],
        "onboard.step.welcome": [.ptBR: "Olá", .es: "Hola", .en: "Hello"],
        "onboard.step.promise": [.ptBR: "Promessa", .es: "Promesa", .en: "Promise"],
        "onboard.step.permissions": [.ptBR: "Permissões", .es: "Permisos", .en: "Permissions"],
        "onboard.step.ready": [.ptBR: "Pronto", .es: "Listo", .en: "Ready"],
        "onboard.welcome.title": [.ptBR: "Controle de áudio e equalização no Mac.", .es: "Control de audio y ecualización en el Mac.", .en: "Audio routing and equalization for Mac."],
        "onboard.welcome.body": [
            .ptBR: "Volume por app, equalização em 64 bits e um observatório que mostra o caminho do som. No notch do seu Mac, 100% local.",
            .es: "Volumen por app, ecualización en 64 bits y un observatorio que muestra la ruta del sonido. En el notch de tu Mac, 100% local.",
            .en: "Per-app volume, 64-bit equalization and an observatory that shows the path of your sound. In your Mac notch, 100% local."
        ],
        "onboard.language": [.ptBR: "Idioma", .es: "Idioma", .en: "Language"],
        "onboard.promise.title": [.ptBR: "Processamento 100% local", .es: "Procesamiento 100% local", .en: "100% local processing"],
        "onboard.promise.local": [
            .ptBR: "Todo o áudio fica neste Mac. Sem nuvem, sem telemetria, sem conta.",
            .es: "Todo el audio permanece en este Mac. Sin nube, sin telemetría, sin cuenta.",
            .en: "All audio stays on this Mac. No cloud, no telemetry, no account."
        ],
        "onboard.promise.trace": [
            .ptBR: "Ao sair, o sistema volta exatamente como estava (dispositivo padrão, volumes, aggregates).",
            .es: "Al salir, el sistema vuelve exactamente como estaba (salida por defecto, volúmenes, aggregates).",
            .en: "On quit, the system is restored exactly as it was (default device, volumes, aggregates)."
        ],
        "onboard.promise.honest": [
            .ptBR: "O selo BIT-PERFECT só acende quando não há taps ativos. Sem marketing de fidelidade falsa.",
            .es: "El sello BIT-PERFECT solo se enciende sin taps activos. Sin marketing de fidelidad falsa.",
            .en: "The BIT-PERFECT badge only lights when zero taps are active. No fake-fidelity marketing."
        ],
        "onboard.permissions.title": [.ptBR: "Permissões do sistema", .es: "Permisos del sistema", .en: "System permissions"],
        "onboard.permissions.body": [
            .ptBR: "Explicamos antes de pedir. Você decide o que conceder — nada é solicitado automaticamente nesta tela.",
            .es: "Explicamos antes de pedir. Tú decides qué conceder — nada se solicita automáticamente en esta pantalla.",
            .en: "We explain before asking. You choose what to grant — nothing is prompted automatically on this screen."
        ],
        "onboard.permissions.later": [
            .ptBR: "Você pode conceder depois em Ajustes → Permissões, quando for usar EQ ou teclas de mídia.",
            .es: "Puedes conceder después en Ajustes → Permisos, cuando uses EQ o teclas de medios.",
            .en: "You can grant later in Settings → Permissions when you use EQ or media keys."
        ],
        "onboard.ready.title": [.ptBR: "Pronto para usar", .es: "Listo para usar", .en: "Ready to use"],
        "onboard.ready.body": [
            .ptBR: "O timbr vive na barra de menus e no notch. Abra o Estúdio para o mixer e o EQ, ou comece a tocar música e expanda o notch com ⌥⌘V.",
            .es: "timbr vive en la barra de menús y en el notch. Abre el Estudio para el mezclador y el EQ, o reproduce música y expande el notch con ⌥⌘V.",
            .en: "timbr lives in the menu bar and notch. Open Studio for the mixer and EQ, or start playing music and expand the notch with ⌥⌘V."
        ],
        "onboard.ready.try_keys": [.ptBR: "Experimente uma tecla de volume ou brilho. O ajuste aparece no notch.", .es: "Prueba una tecla de volumen o brillo. El ajuste aparece en el notch.", .en: "Try a volume or brightness key. The adjustment appears in the notch."],
        "onboard.ready.hint": [
            .ptBR: "Atalhos: ⌥⌘, Estúdio · ⌥⌘V Notch · ⌥⌘B Bypass · ⌥⌘A A/B neutro",
            .es: "Atajos: ⌥⌘, Estudio · ⌥⌘V Notch · ⌥⌘B Bypass · ⌥⌘A A/B neutro",
            .en: "Shortcuts: ⌥⌘, Studio · ⌥⌘V Notch · ⌥⌘B Bypass · ⌥⌘A Neutral A/B"
        ],
        "onboard.next": [.ptBR: "Continuar", .es: "Continuar", .en: "Continue"],
        "onboard.back": [.ptBR: "Voltar", .es: "Atrás", .en: "Back"],
        "onboard.open_studio": [.ptBR: "Abrir o Estúdio", .es: "Abrir el Estudio", .en: "Open Studio"],
        "onboard.finish_menubar": [.ptBR: "Começar pela barra de menus", .es: "Empezar desde la barra de menús", .en: "Start from the menu bar"],
        "onboard.replay": [.ptBR: "Repetir introdução", .es: "Repetir introducción", .en: "Replay introduction"],

        // Support & Donations Tab
        "support.title": [.ptBR: "Apoiar o timbr", .es: "Apoyar a timbr", .en: "Support timbr"],
        "support.body": [
            .ptBR: "O timbr é software livre sob licença MPL-2.0, 100% local e sem telemetria. Se ele melhora sua escuta diária, considere apoiar o desenvolvimento contínuo.",
            .es: "timbr es software libre bajo licencia MPL-2.0, 100% local y sin telemetría. Si mejora tu escucha diaria, considera apoyar su desarrollo.",
            .en: "timbr is free open-source software under MPL-2.0, 100% local with zero telemetry. If it elevates your daily listening, consider supporting development."
        ],
        "support.license": [.ptBR: "Licença: MPL-2.0 · Sem assinatura obrigatória", .es: "Licencia: MPL-2.0 · Sin suscripción obligatoria", .en: "License: MPL-2.0 · No mandatory subscription"]
    ]

    public static func get(_ key: String, lang: TimbreLanguage) -> String {
        let row = table[key] ?? uiTable[key]
        return row?[lang] ?? row?[.en] ?? key
    }

    public static var allKeys: [String] { Array(Set(table.keys).union(uiTable.keys)).sorted() }

    /// Lookup helper for the full merged table (legacy + UI 2.0).
    public static func row(_ key: String) -> [TimbreLanguage: String]? { table[key] ?? uiTable[key] }
}
