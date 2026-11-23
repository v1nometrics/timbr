# Inventário Open Source, Classificação e Bill of Materials (BOM)

> **Fonte primária:** Auditorias de engenharia em `docs/00-pesquisa/notas-fase-2/` ([11a Captura/HAL](../00-pesquisa/notas-fase-2/11a_auditoria_captura_audio_hal.md), [11b DSP/Presets](../00-pesquisa/notas-fase-2/11b_auditoria_dsp_presets.md), [11c UI/Mídia/Infra](../00-pesquisa/notas-fase-2/11c_auditoria_ui_notch_midia.md) e [08 Referências UI](../00-pesquisa/notas-fase-2/08_referencias_ui_componentes.md)).
> **Regra operacional ([ADR-0001](../07-decisoes/ADR-0001-licenca.md)):** Núcleo oficial sob **MPL-2.0 + DCO**, com atribuições de mecanismos `MIT` em [`NOTICE`](../../NOTICE). Projetos **GPL/AGPL** são listados exclusivamente em **ESTUDAR COMO REFERÊNCIA** ou **DESCARTAR** — zero cópia de código permitida.

---

## 1. Bill of Materials (BOM) Recomendado (Caminho MPL-2.0)

| Camada | Candidato Principal | Alternativa Permissiva | Licença | Papel no Timbre |
|---|---|---|---|---|
| **Captura & Topologia Single-Clock** | `CJStanfield/CoreAudioTapKit` + padrões de `Sakuleta/tapmix` (`TapPlan`, triple-buffering) | Reimplementação própria sobre `CAAudioHardware` | **MIT** | 1 aggregate privado + 1 `IOProc` por saída física (ADR-0004) |
| **Wrapper HAL Core Audio** | `sbooth/CAAudioHardware` + `CoreAudioExtensions` | `orchetect/swift-core-audio` (Swift 6 `Sendable`) | **MIT** | Sonda de capacidades (E-07), `AudioTap`, `AudioDevice`, listeners |
| **Núcleo DSP 64-bit (E-06)** | `HEnquist/camilladsp` v5 (`camilladsp` + `camilladsp-schema`, opção **MPL-2.0**) | `jatinindia/MacEQ` (`MacEQCore` **MIT**) portado para `vDSP_biquadD` (`Float64`) + `LookaheadLimiter` (`tapmix`) | **MPL-2.0** / **MIT** | Biquads Float64, FIR particionado, `LookaheadLimiter`, loudness, dither |
| **Medição EBU R128 / True Peak** | `sdroege/ebur128` (Rust + feature `capi`) | `jiixyj/libebur128` (C, com testes oficiais EBU) | **MIT** | LUFS M/S/I, LRA, True Peak (validar issue #69 em 20 kHz no E-06) |
| **Resampler Assíncrono** | `HEnquist/rubato` (já integrado ao CamillaDSP v5) | `avaneev/r8brain-free-src` (**MIT**, se C++) | **MIT OR Apache-2.0** | SRC de alta precisão quando necessário |
| **Banco de Fones (AutoEq)** | `jaakkopasanen/AutoEq` (fetch sob demanda + cache/índice) | Importação manual REW / EqualizerAPO `.txt` | **MIT** (código/índice) | Perfis de Correção com crédito obrigatório do rig/autor |
| **Casca do Notch & Geometria** | `MrKai77/DynamicNotchKit` + `Ext+NSScreen` (`Lakr233/NotchDrop`) | `NSPanel` próprio em AppKit | **MIT** | Notch não-ativante + pílula flutuante (sem API privada `SkyLight`) |
| **Shaders & Reatividade UI** | `libraries.dev` (`VoiceGlowKit`, `VoiceRingKit`, `BorderBeamKit`, `DistortionWavesKit` por commit fixado) | SwiftUI `Canvas` + `Metal` próprio | **MIT** | Efeitos reativos de áudio no notch (proibido importar modelos `.mfxl`) |
| **Now Playing & Letras** | `ungive/mediaremote-adapter` (+ wrapper SPM de `ejbills` PR #7) + `LRCLIB` API / parser `LyricFever` | `NSAppleScript` (Music/Spotify) | **BSD-3-Clause** / **MIT** | Metadados multi-sessão + letras sincronizadas em New York (ADR-0015) |
| **Teclas de Mídia / DDC / Atalhos** | `MonitorControl` (trechos DDC/`CGEventTap`) + `sindresorhus/KeyboardShortcuts` | APIs nativas macOS sem macro `@Entry` | **MIT** | Super Volume Keys + atalhos globais `⌥⌘V/B/A/O/M` |
| **Atualizações & Testes** | `sparkle-project/Sparkle` 2.10+ · `apple/swift-atomics` · `swiftlang/swift-testing` | `Synchronization.Atomic` (macOS 15+) | **MIT** / **Apache-2.0** | Auto-update EdDSA (Developer ID) + ring buffers + suíte Swift Testing |
| **Site, Docs & Playground DS** | `shadcn/ui` + `NumberOneBot/dsssp` + `Bencho` (free) + `Spell UI` | HTML/CSS estático com `tokens.css` | **MIT** | Paridade 1:1 com `tokens.css` (ADR-0012) |

---

## 2. Matriz de Compatibilidade de Licenças (com Núcleo `MPL-2.0`)

| Licença Externa | Compatível com `MPL-2.0`? | Obrigação ao usar no Timbre | Exemplos |
|---|---|---|---|
| **MIT / BSD-2 / BSD-3 / ISC / Unlicense / 0BSD / Apache-2.0** | ✅ Sim | Preservar aviso de copyright em `THIRD_PARTY_NOTICES.md` | `CoreAudioTapKit`, `tapmix`, `CAAudioHardware`, `rubato`, `ebur128`, `DynamicNotchKit`, `mediaremote-adapter`, `Sparkle`, `AutoEq` |
| **MPL-2.0** (ou `GPL-3.0 OR MPL-2.0` escolhendo MPL-2.0) | ✅ Sim | Arquivos MPL modificados seguem MPL-2.0; não contamina módulos externos | `camilladsp` v5, `LyricsKit` |
| **SIL OFL 1.1** (Fontes) | ✅ Sim | Embutir texto da OFL no bundle; não vender a fonte isoladamente | `Geist`, `Geist Mono`, `Geist Serif` (só na web; o app usa fontes do sistema, ADR-0015) |
| **LGPL-2.1 / LGPL-3.0** | ⚠️ Evitar | Exige linkagem dinâmica e capacidade do usuário substituir a dylib (fricção na notarização/App Store) | `soxr`, `lsp-plugins` (ambos descartados) |
| **GPL-2.0 / GPL-3.0 / AGPL-3.0** | ❌ Não (com MPL-2.0) | Copyleft viral obriga licenciar todo o executável em GPL/AGPL | `FineTune`, `boring.notch`, `Atoll`, `LosslessSwitcher`, `BlackHole`, `BackgroundMusic`, `JUCE`, `FxSound` |
| **PolyForm Noncommercial / Sem `LICENSE` (`NONE`)** | ❌ Proibido | Não é Open Source (OSI) ou é *all rights reserved* | `PerAppVolume` (PolyForm NC), `audiotee`, `Liland`, `media-control`, `JamesDSPManager` (`NONE`) |

---

## 3. Classificação Consolidada por Ação

### 3.1 `REUTILIZAR DIRETAMENTE` (Dependência / Serviço)
- `sbooth/CAAudioHardware` + `sbooth/CoreAudioExtensions` (MIT) — ou `orchetect/swift-core-audio` (MIT) após validação em E-07.
- `sdroege/ebur128` (MIT) ou `jiixyj/libebur128` (MIT) — medição LUFS/True Peak (validar issue #69).
- `HEnquist/rubato` (MIT OR Apache-2.0) — resampler Rust (via CamillaDSP v5).
- `jaakkopasanen/AutoEq` (MIT) — catálogo remoto indexado em runtime com atribuição.
- `MrKai77/DynamicNotchKit` (MIT) — base do overlay de notch/pílula (monitorar issue #50 OLED).
- `ungive/mediaremote-adapter` (BSD-3) — bridge Now Playing via `/usr/bin/perl` (isolado por protocolo).
- `tranxuanthang/lrclib` (MIT) — API HTTP pública de letras sincronizadas.
- `sindresorhus/KeyboardShortcuts` (MIT), `sparkle-project/Sparkle` (MIT), `apple/swift-atomics` (Apache-2.0), `swiftlang/swift-testing` (Apache-2.0).
- `libraries.dev` (`VoiceGlowKit`, `VoiceRingKit`, `BorderBeamKit`, `DistortionWavesKit` — apenas pacotes Swift MIT pinados por commit; nunca `.mfxl`).
- `shadcn/ui`, `NumberOneBot/dsssp`, `Bencho` free, `Spell UI` (todos MIT — camada web).

### 3.2 `ADAPTAR` (Fork cirúrgico ou extração de padrões MIT/MPL-2.0)
- `HEnquist/camilladsp` v5 (`MPL-2.0`) — adaptar como biblioteca FFI com fronteira C ABI (`timbre_dsp.h`), pinando commit exato (sem semver ainda).
- `Sakuleta/tapmix` (MIT) — adaptar `TapPlan`, atomic triple-buffering e `LookaheadLimiter` (substituindo biquads Float32 por Float64).
- `CJStanfield/CoreAudioTapKit` (MIT) — adaptar arquitetura single-clock (`1 aggregate + 1 IOProc` por saída).
- `jatinindia/MacEQ` (MIT) — adaptar parser `APOConfig.swift`, proteção de Nyquist em HFP, FTZ/DAZ (`disableDenormals`) e `KernelHolder`.
- `Lakr233/NotchDrop` (MIT) — extrair cálculo geométrico `Ext+NSScreen.swift` e padrões de hit-testing.
- `ejbills/mediaremote-adapter` (BSD-3) — incorporar PR #7 (Swift 6 + fix de CPU spin) sobre `ungive` v0.8.0.
- `aviwad/LyricFever` (MIT) — adaptar `LRCLIBLyricProvider` e parser LRC adicionando testes unitários.
- `MonitorControl/MonitorControl` (MIT) — adaptar `Arm64DDC` e `MediaKeyTapManager` atrás de módulo opcional.
- `Zhengyang-Liu/m4-companion` (MIT) — framing `GaiaSPP` (`0xFF 0x03`), `GaiaSPPDeframer`, opcodes read-only GAIA v3 e fluxo `IOBluetoothRFCOMMChannel` adaptados em [`Momentum4Driver.swift`](../../Sources/TimbreEngine/Momentum4Driver.swift) (creditado em [`NOTICE`](../../NOTICE)).
- `AbhisekGanguly/AudioRouter` (MIT) — padrão `OrphanedTapCleanup` adaptado em [`ProcessTapEngine.swift`](../../Sources/TimbreEngine/ProcessTapEngine.swift) para limpeza de aggregate devices órfãos pós-crash (creditado em [`NOTICE`](../../NOTICE)).
- `hudsonbrendon/apple-ble` + `imranhwafa/mubar` (MIT) — semântica Continuity proximity `0x004C` / type `0x07` e scan CoreBluetooth; **reimplementados** em [`AirPodsFamilyDriver.swift`](../../Sources/TimbreEngine/AirPodsFamilyDriver.swift) (creditado em [`NOTICE`](../../NOTICE) §3).

### 3.3 `ESTUDAR COMO REFERÊNCIA` (Leitura arquitetural / Proibida cópia GPL)
- `ronitsingh10/FineTune` (GPL-3.0) — lições preciosas de produção no macOS 26/27: `OrphanedTapCleanup`, `CrashGuard`, crossfade sem silêncio, isenção de chamadas VoIP e issues #477/#483/#491/#493/#498.
- `belugaming/tapline` (GPL-3.0) — arquitetura de `TaplineCore` e correção de crash abaixo de 40 kHz (PR #33).
- `denzam/SystemEQ-for-Mac` (GPL-3.0) — fluxo de calibração auditiva relativa e scripts de latência loopback.
- `Torteous44/radioform` (GPL-3.0) — testes de resposta em frequência e lição de *treble roll-off* em drift (issue #84).
- `vincentneo/LosslessSwitcher` (GPL-3.0) — lição negativa da issue #231 (troca prematura de sample rate por pre-buffering em logs do Apple Music).
- `TheBoredTeam/boring.notch` & `Ebullioscopic/Atoll` (GPL-3.0) — ergonomia de notch, `DynamicIslandTests`, mas evitar `SkyLight` privado e leaks de `log stream`.
- `ryanfrancesconi/spfk-audio-hardware` (MIT) — padrão `AudioBackend` mockável para CI sem hardware.
- `BySergiMM/OmniMac` (MIT) — referência de UX multi-utilitário no notch e confirmação de que EQ `Float32` RBJ 10 bandas fica abaixo do padrão `Float64` Vicanek do `timbr`.
- `niyamvora/ILoveNotch` (MIT) — referência de ergonomia SwiftUI de notch multi-tool.
- `librepods-org/librepods` (GPL-3.0) — mapa AACP L2CAP `0x1001` e Magic Pairing; **prova de inviabilidade no macOS user-space**; zero código.
- `lihaoyun6/AirBattery` (AGPL-3.0) — Nearbility no macOS; **proibida cópia**.
- `furiousMAC/continuity` (docs públicas) — offsets proximity-pairing type `0x07`.
- `bitgapp/eqMac` (Apache-2.0 no v1.3.2 legado), `gavv/libASPL` (MIT), `briankendall/proxy-audio-device` (Unlicense), `sbooth/SFBAudioEngine` (MIT), `Yudaotor/lyrimuse` (GPL-3.0), `csteinmetz1/pyloudnorm` (MIT).

### 3.4 `DESCARTAR` (Incompatíveis, sem licença, abandonados ou fora da arquitetura)
- **Sem código aberto auditável / sem licença:** `XPro-Gamer-Rhine/R9-EQ-app` (`NONE` — repositório contém apenas docs e instaladores binários).
- **Bloqueio jurídico (`NONE` / `PolyForm` / `AGPL`):** `GabrielSabadinn/PerAppVolume` (PolyForm NC), `makeusabrew/audiotee` (`NONE`), `sacis/Liland` (`NONE`), `ungive/media-control` (`NONE`), `james34602/JamesDSPManager` (`NONE`), `fxsound2/fxsound-app` (AGPL-3.0), `juce-framework/JUCE` (AGPL-3.0 / comercial).
- **Arquitetura / Licença / Abandono:** `ExistentialAudio/BlackHole` (GPL-3.0 + marca restrita, driver HAL), `kyleneideck/BackgroundMusic` (GPL-2.0, 545 issues), `chirlu/soxr` (LGPL-2.1, parado em 2018), `lsp-plugins/lsp-plugins` (LGPL-3.0), `rnine/SimplyCoreAudio` (arquivado), `deweller/switchaudio-osx` & `karaggeorge/macos-audio-devices` (obsoletos), `ddddxxx/LyricsX` (parado em 2022), `kirtan-shah/nowplaying-cli` (GPL-3.0), `AudioKit/AudioKit` (`AVAudioEngine` inadequado para RT HAL), `grame-cncm/faust` (overhead desnecessário).
