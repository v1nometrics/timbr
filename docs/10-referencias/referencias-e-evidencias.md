# Referências, Fontes e Taxonomia de Evidências

> **Data de corte da pesquisa:** `2026-11-21`.
> **Regra de evidência ([AGENTS.md](../../AGENTS.md)):** toda afirmação não trivial distingue fonte oficial, código auditado, norma técnica, benchmark comercial ou relato de terceiros, sob quatro classes: **Comprovado**, **Provável**, **Hipótese**, **Desconhecido**.

---

## 1. Taxonomia de Fontes

| Classe no Timbre | Tipos de fonte aceitos | Exemplos |
|---|---|---|
| **Comprovado** | Documentação/headers oficiais Apple SDK, normas técnicas públicas, código-fonte clonado e inspecionado neste repositório, ou medição própria documentada em `RESULTADO.md` | `AudioHardware.h` (SDK 27.0), EBU Tech 3341 V4, `Cargo.toml` CamillaDSP v5, tokens gerados |
| **Provável** | Convergência de múltiplos projetos ou relatos técnicos independentes, ou documentação oficial de produto comercial fechado | Comportamento do SoundSource 6 (`ARK.driver`), bugs macOS 26/27 reportados em múltiplas issues |
| **Hipótese** | Inferência de engenharia derivada de fatos comprovados ainda não testada em bancada | Bit-transparência de Process Tap com ganho `1,0` e taxa casada (`E-01`) |
| **Desconhecido** | Lacuna factual assumida antes do experimento ou revisão em hardware | Compatibilidade real de `DynamicNotchKit` com MacBook Pro OLED (`DynamicNotchKit#50`) |

---

## 2. Documentação Oficial Apple & Plataforma macOS (ac. 2026-11-21)

| Tema | Fonte / Link | Classe | Notas |
|---|---|---|---|
| **Core Audio Process Taps (`AudioHardwareCreateProcessTap`, `CATapDescription`)** | [Capturing system audio with Core Audio taps](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps) · SDK `AudioHardwareTapping.h` | **Comprovado** | Base do ADR-0004 (`muteBehavior = .mutedWhenTapped`, `bundleIDs` no macOS 26) |
| **HAL Properties, Process Objects & Mic VAD** | [`kAudioProcessPropertyIsRunningInput`](https://developer.apple.com/documentation/coreaudio/kaudioprocesspropertyisrunninginput) · [`kAudioDevicePropertyVoiceActivityDetectionEnable`](https://developer.apple.com/documentation/coreaudio/kaudiodevicepropertyvoiceactivitydetectionenable) | **Comprovado** | Inclui `kAudioDevicePropertySuggestedReferenceDevice` (SDK 27) |
| **Mic Modes & TCC Screen/Audio Recording** | [`AVCaptureDevice.preferredMicrophoneMode`](https://developer.apple.com/documentation/avfoundation/avcapturedevice/preferredmicrophonemode) · [Apple Support TCC](https://support.apple.com/guide/mac-help/control-access-to-screen-and-system-audio-recording-mchld6aa7d23/mac) | **Comprovado** | App público só abre seletor de modo de mic; não altera diretamente |
| **Accelerate / vDSP (`Float64` Biquads & Ramp)** | [`vDSP_biquadD`](https://developer.apple.com/documentation/accelerate/vdsp_biquadd) · [`vDSP_biquadm_SetTargetsDoubleD`](https://developer.apple.com/documentation/accelerate/vdsp_biquadm_settargetsdoubled) | **Comprovado** | Candidato C++/Swift para `Float64` com interpolação anti-zipper |
| **AVAudioUnitEQ (limites)** | [`AVAudioUnitEQFilterParameters`](https://developer.apple.com/documentation/avfaudio/avaudiouniteqfilterparameters) | **Comprovado** | Parâmetros float, ganho ±24 dB, protótipo Butterworth não detalhado |
| **Apple Foundation Models (on-device)** | [Apple Foundation Models Tech Report 2025](https://machinelearning.apple.com/research/apple-foundation-models-tech-report-2025) | **Comprovado** | Base de IA on-device no macOS 26+ (janela 4.096 tokens; ADR-0008) |
| **Hearing Health & Headphone Accommodations** | [Apple Hearing Health White Paper (out/2024)](https://images.apple.com/health/pdf/Hearing_Health_Features_on_AirPods_Pro_2_October_2024.pdf) | **Comprovado** | Referência de limites não-diagnósticos vs AirPods validados |
| **macOS Tahoe / OLED Dynamic Island / 27.3 Live Activities** | [Apple Tahoe PDF](https://www.apple.com/au/os/pdf/All_New_Features_macOS_Tahoe_Sept_2025_AU_Final.pdf) · [MacRumors OLED (28/10/2026)](https://www.macrumors.com/2026/10/28/pill-shaped-macos-27-dynamic-island-macbook-pro/) · [MacRumors 27.3 (04/11/2026)](https://www.macrumors.com/2026/11/04/macos-27-3-live-activities-in-menu-bar/) | **Comprovado** (Tahoe) / **Relato** (MacRumors) | Fundamenta arquitetura multi-superfície (ADR-0013) |

---

## 3. DSP, Psicoacústica, Normas e Medição de Fones (ac. 2026-11-21)

| Tema | Fonte / Link | Classe | Notas |
|---|---|---|---|
| **RBJ Audio EQ Cookbook** | [W3C Audio EQ Cookbook](https://www.w3.org/TR/audio-eq-cookbook/) | **Comprovado** | Fórmulas analíticas de referência para coeficientes biquad |
| **Filtros Casados anti-cramping** | [Vicanek — *Matched Second Order Digital Filters*](https://vicanek.de/articles/BiquadFits.pdf) | **Comprovado** | Base para peaking filters acima de 10 kHz em 44,1/48 kHz |
| **Loudness & True Peak** | [EBU Tech 3341 V4](https://tech.ebu.ch/docs/tech/tech3341.pdf) · [TI SLYT375](https://ti.com/lit/SLYT375) · [Archimago ISP (ago/2025)](https://archimago.blogspot.com/2025/08/a-look-at-music-library-how-much.html) | **Comprovado** | EBU Mode (`0,4 s` M / `3 s` S), 44% de 31.400 faixas com `> +0,1 dBTP` |
| **Fase linear vs. mínima** | [FabFilter Pro-Q 4 Processing Mode](https://www.fabfilter.com/help/pro-q/using/processingmode) · [FabFilter Linear Phase](https://www.fabfilter.com/learn/equalization/linear-phase-eq/) | **Comprovado** | Fase mínima padrão (0 latência); fase linear opcional com alerta |
| **Headroom & Signal Path** | [Roon Headroom Management](https://help.roonlabs.com/portal/en/kb/articles/dsp-engine-headroom-management) · [Roon Signal Path](https://help.roonlabs.com/portal/en/kb/articles/signal-path) | **Comprovado** | Transparência de cadeia e perda de bit-perfect em DSP ativo |
| **Curvas alvo & Preferência (Harman / B&K 5128 / Rtings)** | [Olive & Clark AES 159 Paper 394 (2025)](https://aes2.org/publications/elibrary-page/?id=23068) · [Rtings 1.8](https://www.rtings.com/headphones/learn/research/frequency-response-1-8) · [GraphWorks (out/2026)](https://headphones.com/blogs/features/our-headphone-measurement-database-is-finally-here) | **Comprovado / Provável** | Valores exatos do paper AES 159 são paywalled |
| **Otimização Bayesiana (`PairwiseGP`) & IA para EQ** | [Nielsen et al. (Widex)](https://www.researchgate.net/publication/278402217_Perception-Based_Personalization_of_Hearing_Aids_Using_Gaussian_Processes_and_Active_Learning) · [B&O / Sony LLM2Fx (2025–2026)](https://arxiv.org/abs/2507.13575) · [SAFE/SocialEQ](https://www.open-access.bcu.ac.uk/3258/1/Semantically%20Controlled%20Adaptive%20Equalisation.pdf) | **Comprovado** | Justifica espaço 2–4D + deltas limitados + múltiplas variantes |
| **Formatos de Intercâmbio** | [EqualizerAPO Config Reference](https://sourceforge.net/p/equalizerapo/wiki/Configuration%20reference/) · [REW File Menu](https://www.roomeqwizard.com/help/help/html/file.html) | **Comprovado** | Base do ADR-0009 (`ParametricEQ.txt`, CamillaDSP YAML) |

---

## 4. Design System, UI & Referências Visuais (ac. 2026-11-21)

| Referência | Fonte / Link | Papel no Timbre |
|---|---|---|
| **Órbita (SIP) & Ronda Diária** | Referências locais documentadas em [09 · DNA Visual](../00-pesquisa/notas-fase-2/09_dna_visual_orbita_e_ronda.md) | Neutros OKLCH croma 0, acento único `#7747FF`/`#A78BFF`, regra OKLab, grade 7/5, 3 vozes Geist |
| **Apple Design & Emil Kowalski** | Skills locais `$apple-design` e `$emil-design-eng` | Springs `bounce: 0`, *velocity handoff*, `0 ms` teclado, `scale(0.97)`, nunca `scale(0)` |
| **FabFilter Pro-Q 4** | [Pro-Q 4 Release](https://www.fabfilter.com/news/1733994000/fabfilter-releases-pro-q-4-equalizer-plug-in) · [Sound On Sound](https://www.soundonsound.com/reviews/fabfilter-pro-q-4?amp) | Ergonomia do editor PEQ no Estúdio (escalas dB, spectrum grab, curvas) |
| **Libraries.dev / Bencho / Spell UI / shadcn** | [libraries.dev/waves](https://libraries.dev/waves) · [bencho.dev](https://bencho.dev/) · [spell.sh](https://spell.sh/docs/components) · [ui.shadcn.com](https://ui.shadcn.com/charts) | Pacotes MIT Swift (`VoiceGlowKit`, `BorderBeamKit`) e stack Web/Playground (`tokens.css`) |

---

## 5. Repositórios Open Source Auditados & Benchmarks Comerciais

A matriz completa de 62+ repositórios com **URL, SHA exato, licença verificada em arquivo, contagem de testes, issues críticas e classificação** vive em:
- [11 · Auditoria Consolidada OSS (Índice e BOM)](../00-pesquisa/notas-fase-2/11_auditoria_repositorios_oss.md)
- [11a · Captura, HAL & Benchmarks Comerciais (SoundSource / Loopback / EQBase)](../00-pesquisa/notas-fase-2/11a_auditoria_captura_audio_hal.md)
- [11b · Motores DSP, Resamplers, EBU R128 & AutoEq](../00-pesquisa/notas-fase-2/11b_auditoria_dsp_presets.md)
- [11c · Notch UI, MediaRemote, LRCLIB & Infra macOS](../00-pesquisa/notas-fase-2/11c_auditoria_ui_notch_midia.md)
- [09-open-source/inventario-e-classificacao.md](../09-open-source/inventario-e-classificacao.md)

---

## 6. Pesquisas Fase 1 e Fase 2 (Índice Completo do Acervo)

- **Relatório Mestre Fase 1:** [relatorio-fase-1-notch-audiofilo.md](../00-pesquisa/relatorio-fase-1-notch-audiofilo.md)
- **Notas Fase 1:** [01 Captura](../00-pesquisa/notas-fase-1/01_captura_roteamento_volume_por_app.md) · [02 Motor EQ](../00-pesquisa/notas-fase-1/02_motor_eq_hifi_e_presets.md) · [03 Dispositivos](../00-pesquisa/notas-fase-1/03_controle_dispositivos_entrada_saida.md) · [04 Now Playing](../00-pesquisa/notas-fase-1/04_now_playing_letras_reconhecimento.md) · [05 Personalização/IA](../00-pesquisa/notas-fase-1/05_personalizacao_aprendizado_ia_eq.md) · [06 Mercado/Restrições](../00-pesquisa/notas-fase-1/06_mercado_benchmarks_restricoes.md)
- **Notas Fase 2:**
  - [07 · Momentum 4, Protocolo GAIA v3, AirPods Pro e Ecossistema Bluetooth](../00-pesquisa/notas-fase-2/07_momentum4_protocolo_e_ecossistema.md)
  - [12 · Linha Apple Audio Accessory (AirPods → Max) no macOS](../00-pesquisa/notas-fase-2/12_airpods_linha_apple.md)
  - [Laboratório AirPods](../03-viabilidade/airpods-laboratorio.md)
  - [08 · Referências UI e Componentes](../00-pesquisa/notas-fase-2/08_referencias_ui_componentes.md)
  - [09 · DNA Visual Órbita e Ronda](../00-pesquisa/notas-fase-2/09_dna_visual_orbita_e_ronda.md)
  - [10 · Engenharia de Áudio, Precisão DSP, Segurança Auditiva e Testes](../00-pesquisa/notas-fase-2/10_engenharia_de_audio_qualidade_e_testes.md)
  - [11 · Auditoria de Repositórios OSS](../00-pesquisa/notas-fase-2/11_auditoria_repositorios_oss.md) (`11a`, `11b`, `11c`)

---

## 7. Referências Adicionais de Protocolo, Metrologia & Identidade (Fase 2)

| Domínio | Referência | Uso no `timbr.` |
|---|---|---|
| **Momentum 4 (GAIA v3)** | `timmo001/omarchy-momentumctl` (Apache-2.0) · `f3y0/momentum4-control` (MIT) · `Picazsoo/android-momentum-4-widget` (MIT) · `gjabell/momentumctl` (MIT) · `DanSmith888/omarchy-momentum4` (MIT) · `xndbogdan/sennheiser-control` · `dvf` Gist #4841058 | Mapa de opcodes `0x0495`, firmware gates Gen1/Gen2, denylist `0x0607`, vetores binários de teste e confirmação da obsolescência de `bluetoothaudiod` defaults |
| **Áudio RT & Metrologia** | Ross Bencina (*RT Audio 101*) · Timur Doumler · Apple *Audio Workgroups* & *Audio System Trace* · Vicanek (2016/2024) · Orfanidis (1997) · Cytomic SVF · Gardner (1995) · Wannamaker et al. (2000) · Farina (2000 ESS) · ITU-R BS.1770-5 · EBU Tech 3341 · Lund/AES (*0 dBFS+*) · WHO-ITU H.870 · ITU-R BS.1116/1534 · InfiniteWave | Critérios numéricos dos RNFs, RTSan CI gate, null test, THD+N `< -130 dB`, `4× dBTP`, ABX `p < 0,05` |
| **Identidade do Autor** | `v1torres.dev` (`v1dev app/frontend/DESIGN_SYSTEM.md` v3.0) + Wordmark `timbr.` | Alinhamento filosófico lowercase, neutros puros OKLCH e tipografia Geist ([ADR-0014](../07-decisoes/ADR-0014-nome-identidade-e-i18n.md)) |
