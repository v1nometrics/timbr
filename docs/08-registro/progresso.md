# Registro de Progresso

> **Regra ([AGENTS.md](../../AGENTS.md)):** este arquivo registra o estado real do projeto, o que já foi pesquisado, formalizado e auditado, e qual é o próximo passo exato. Nunca marcar como implementado o que está apenas planejado.

---

## Estado Atual

- **Fase ativa:** **Fase 1/2 implementação E2E headless no sweetspot máximo alcançável neste ambiente** (branch `vinicius/e2e-implementation`, PR #1).
- **Código de produção (`macOS app`):** `dist/Timbr.app` + `dist/Timbr.dmg` gerados; `./scripts/ci_check.sh` verde (tokens, zero-GPL, ASan/UBSan DSP, TimbreCore/Engine, smoke, **20× `kill -9` fail-safe P3**).
- **Tokens & Design System:** geração automatizada operacional; playground HTML/CSS/JS validado no CI.
- **Empacotamento B-110 (parcial):** `scripts/build_dmg.sh` com gate opcional `DEVELOPER_ID` + `NOTARY_PROFILE`; cask Homebrew em `Packaging/Homebrew/timbr.rb`. Notarização pública real exige certificado Apple (fora deste ambiente).
- **Pendências honestas fora de CI headless:** E-08/E-09/E-10 com Momentum 4 / AirPods conectados (Continuity live);  grants TCC interativos; dogfood 14 dias (G2); 50 testadores + notarização Developer ID (G3); Sparkle 2 (B-208, Fase 2).

---

## Histórico Consolidado



### 2026-11-21 · Notch v2.1 — fluidez, espaço da barra de menus e fechamento que segue o ponteiro

1. **Causas:** ícone duplicado (cópias por estado cruzando opacidade), atraso de 60 ms na entrada do conteúdo, redimensionamento da janela, notch alargando na altura da barra de menus, fechamento só após 300 ms parado.
2. **Forma pescoço + corpo** (`NotchShape` com 6 medidas animáveis): na altura da barra, nunca mais larga que o notch (+ orelhas medidas); espiada, expandido e HUD descem abaixo da barra.
3. **Orelhas medidas** (`MenuBarSpace`: CGWindowList para status items, Acessibilidade para menus do app) e queixo quando não há espaço.
4. **Ícone único viajante**, canvas fixo, molas 0,38/0,30 s, hover 70 ms.
5. **Fechamento contínuo** guiado pela distância do ponteiro, reversível, com commit sem salto.
6. **Verificação:** capturas com Finder e Chrome em primeiro plano; vídeo `--demo` inspecionado quadro a quadro (abrir, fechar seguindo o ponteiro, expandir). CI verde.

### 2026-11-21 · UI/UX v2.0 — redesign completo, notch preto de hardware e auditoria E2E

1. **Diagnóstico com causa no código** (notch com contorno 11% e topo arredondado, controles padrão do macOS, Geist nunca empacotada, métricas sem sinal mostrando zero, polling de 50 ms): ver [auditoria-e2e-2026-11-21.md](auditoria-e2e-2026-11-21.md).
2. **Notch reescrito** (`NotchOverlay.swift`): `NotchShape` com topo reto e ombros côncavos, preto `sRGB 0,0,0` sem contorno/sombra, morph em canvas estável, hover por `NSTrackingArea`, compacto/HUD/espiada/expandido redesenhados.
3. **Componentes próprios** (`DSComponents.swift`) e **Estúdio** reescrito (`StudioWindow.swift`, `EQCurveCanvas.swift`), **barra de menus** desenhada (`MenuBarPanel.swift`), Introdução limpa.
4. **Tokens v2** (paleta acromática quente + acento único de sinal; SF Pro/Mono/New York com tracking aplicado — ADR-0015).
5. **~170 textos novos** PT/ES/EN (`LocalizationUI.swift`), paridade 308 chaves.
6. **Preset por dispositivo** aplicado ao trocar de saída (RF-0404/0607).
7. **CI:** nova etapa 3b reprova controles padrão e contorno no notch. `./scripts/ci_check.sh` → **ALL PASSED**.
8. **Bíblia do design system v2.0** reescrita (`docs/05-design-system/`).
9. **Em aberto (sem maquiagem):** roteamento por app (P0), Sparkle (P0), now playing, cenas, bancada física M4/AirPods.

### 2026-11-21 · Encerramento da Fase 0 de Planejamento, Pesquisa & Auditoria E2E (`timbr.`)

1. **Pesquisa Técnica & Benchmarking (Fase 1 e Fase 2):**
   - SDK macOS 15–27, Audio Process Taps, Core Audio HAL, DSP `Float64`, dispositivos de entrada/saída, Now Playing/MediaRemote, personalização/IA e panorama competitivo (`docs/00-pesquisa/relatorio-fase-1-notch-audiofilo.md` e `notas-fase-1/01..06`).
   - Protocolo Sennheiser Momentum 4 (GAIA v3 RFCOMM, UUID `A2129FF3-081B-4C45-8AFE-469D9C4842EC`, gate de firmware `3.18.0`, `AudioMode=1`, USB-C UAC 1.0, 3,5 mm `470 Ω`/`60 Ω`, denylist de segurança `0x0607`/`0x0040`/`0x1405`/`0x02xx`, obsolescência de `bluetoothaudiod` do gist `dvf` no Sonoma+ e travamento L2CAP `0x1001` dos AirPods Pro) em [`07_momentum4_protocolo_e_ecossistema.md`](../00-pesquisa/notas-fase-2/07_momentum4_protocolo_e_ecossistema.md).
   - Engenharia de áudio em tempo real, Audio Workgroups, Clang RTSan, filtros Vicanek 2016/2024, dBTP (`ITU-R BS.1770-5` / Lund `0 dBFS+`), `libebur128`, `WHO-ITU H.870`, SRC, TPDF, Null Test, Farina ESS (`AES17`) e validação ABX em [`10_engenharia_de_audio_qualidade_e_testes.md`](../00-pesquisa/notas-fase-2/10_engenharia_de_audio_qualidade_e_testes.md).
   - Auditoria de código-fonte de **62+ repositórios OSS** (captura/HAL, DSP/presets, UI/notch/mídia e ecossistema Momentum 4), com inventário BOM de licenças e bloqueio estrito de contaminação GPL em [`11_auditoria_repositorios_oss.md`](../00-pesquisa/notas-fase-2/11_auditoria_repositorios_oss.md) e [`inventario-e-classificacao.md`](../09-open-source/inventario-e-classificacao.md). Diretórios temporários de clone (`oss-audit-tmp/`, `m4-audit-tmp/`) removidos após auditoria.

2. **Produto, Mercado, Viabilidade & Arquitetura E2E:**
   - Visão, 12 princípios testáveis (`P1`–`P12`) e glossário controlado (`docs/01-visao/`).
   - PRD (`EP-01`–`EP-15`), especificação funcional e matriz competitiva + ideias fora da caixa avaliadas (`docs/02-produto/PRD.md`, `especificacao-funcional.md`, [`mercado-e-diferenciacao.md`](../02-produto/mercado-e-diferenciacao.md)).
   - Matriz de viabilidade, matriz de dispositivos e laboratório seguro do Momentum 4 + AirPods Pro (`docs/03-viabilidade/matriz-de-viabilidade.md`, `matriz-de-dispositivos.md`, [`momentum4-laboratorio.md`](../03-viabilidade/momentum4-laboratorio.md)).
   - Arquitetura completa (`docs/04-engenharia/`): processos, motor DSP `Float64`, roteamento/abas, Observatório & Guardião, inteligência/personalização (`PairwiseGP`), segurança/privacidade/distribuição e **Requisitos Não Funcionais + Matriz 100% Local vs Rede/Nuvem** ([`requisitos-nao-funcionais.md`](../04-engenharia/requisitos-nao-funcionais.md)).

3. **Design System & Identidade Oficial (`timbr.`):**
   - Bíblia do Design System completa (`docs/05-design-system/00..05`), tokens fonte única (`design-system/tokens/*.tokens.json`) e gerador `generate_tokens.py` validado.
   - **[ADR-0014](../07-decisoes/ADR-0014-nome-identidade-e-i18n.md) (Aceito):** definição do nome oficial **`timbr.`** (*Sound, precisely yours.* / *Som, precisamente seu.* / *Sonido, precisamente tuyo.*), alinhamento filosófico/tipográfico avaliado contra **`v1torres.dev`** (`v1dev app`), glifo geométrico `.icns` (`curva + .`) e suporte **trilíngue obrigatório (`PT / ES / EN`)** via `Localizable.xcstrings` desde a v1.

4. **Plano de Experimentos, Testes & Revisão Adversarial Obrigatória:**
   - Plano de 17 experimentos (`E-01`–`E-17`), roadmap em 4 fases com gates (`G0`–`G3`), pirâmide de testes metrológicos (`estrategia-de-testes.md`) e critérios de aceitação (`criterios-de-aceitacao.md`).
   - **[Revisão Adversarial](revisao-adversarial.md):** crítica de 5 especialistas independentes resultando em **8 reformulações aplicadas (`C-01`–`C-08`)** diretamente nos documentos normativos (in-process `Engine` no MVP, preferência C++20/`vDSP`, exclusão VoIP/DAW segura por padrão, teto BT AAC `-1,0 dBTP`, A/B cego com latência equalizada, toggle manual `470 Ω / 60 Ω` no M4 P2, Modo Estúdio Silencioso e orçamento `≤ 40 pt` no notch 14" + variantes curtas `PT/ES/EN`).

---

## Próximo Passo Imediato (fora de CI headless)

1. Instalar localmente com `./scripts/install_local.sh --reset-onboarding` e percorrer o onboarding (RF-1401) + conceder TCC na hora do uso.
2. Conectar Momentum 4 + AirPods Pro e fechar **E-08 / E-09 / E-10** (HFP, GAIA RFCOMM live, coexistência de taps).
3. Iniciar dogfood diário de 14 dias (**Gate G2**).
4. Com certificado Developer ID: `DEVELOPER_ID=… NOTARY_PROFILE=… ./scripts/build_dmg.sh` → publicar release + atualizar `sha256` do cask Homebrew; depois Sparkle 2 (**B-208** / Gate G3).

---

### 2026-11-21 · Fase 2 — Implementação E2E, `CLEAN_SWEEP` e Verificação Automatizada (`vinicius/e2e-implementation`)

1. **Governança Open Source & Portfolio (`ADR-0001` Aceito):**
   - Adicionados [`LICENSE`](../../LICENSE) (**MPL-2.0**) e [`CONTRIBUTING.md`](../../CONTRIBUTING.md) (DCO + isolamento GPL/AGPL); [`ADR-0001`](../07-decisoes/ADR-0001-licenca.md) e [`README.md`](../07-decisoes/README.md) promovidos para **Aceito**.
2. **Experimentos de Fase 0 executados no hardware local:**
   - `E-06`, `E-07`, `E-12` e `E-01` executados com binários reais compilados e resultados documentados em `experiments/*/RESULTADO.md`; `H-06` e `ADR-0003` promovidos para **Comprovado / Aceito**.
3. **Implementação completa dos 4 módulos + extensões + playground + bundle `.app`:**
   - `CTimbreDSP` (C++20 + `Accelerate/vDSP` Float64 RT-safe), `TimbreDesignSystem` (tokens gerados fonte única + playground HTML/CSS/JS), `TimbreCore` (Swift 6: modelos, EqualizerAPO, i18n `PT/ES/EN`, Guardião `G-01`–`G-07`, SQLite, AutoEq, IA com bounds, `PairwiseGP`, IPC loopback Bearer+Origin, diagnósticos sanitizados), `TimbreEngine` (HAL + snapshot P3, Process Tap P1, GAIA v3 read-only + denylist, AirPods HAL, detector de notch concorrente, `MediaKeyTap`), `TimbreApp` (`timbr.` SwiftUI+AppKit com 5 estados de notch + Pílula, MenuBarExtra, Estúdio completo + aba Apoiar/Doações, atalhos globais `⌥⌘V/B/A/O/M/,`) e extensões MV3 (`chrome-mv3` / `safari-web-ext`).
4. **Testes & `CLEAN_SWEEP`:**
   - `./scripts/ci_check.sh` passou integralmente após os ajustes finais da auditoria: geração de tokens, validação JSON das extensões, guarda zero-GPL, build `dist/Timbr.app` assinado ad-hoc (`codesign --verify`), `CTimbreDSPTests` sob ASan+UBSan, `TimbreCoreTests`, `TimbreEngineTests` e `--smoke-check` no binário `Timbr.app`.
5. **Auditoria Competitiva Ampliada & Upgrades MIT (`Notchy`, `OmniMac`, `ILoveNotch`, `R9-EQ`, `m4-companion`, `AudioRouter`):**
   - Incorporados [`NOTICE`](../../NOTICE), [`OrphanedTapCleanup`](../../Sources/TimbreEngine/ProcessTapEngine.swift) (MIT `AudioRouter`) e framing/codecs GAIA v3 SPP `[0xFF, 0x03]` + cliente RFCOMM *read-only* em [`Momentum4Driver.swift`](../../Sources/TimbreEngine/Momentum4Driver.swift) (MIT `m4-companion`), mantendo a denylist de segurança bloqueada e alimentando o Guardião `G-04` (Duplo EQ).
   - Novos testes unitários de `GaiaSPPDeframer`, decodificadores Momentum 4, `G-04` e `OrphanedTapCleanup` validados em `./scripts/ci_check.sh`, além de atualização completa da matriz de mercado e inventário OSS (`docs/02-produto/mercado-e-diferenciacao.md`, `11_auditoria_repositorios_oss.md`, `inventario-e-classificacao.md`).
   - **Pendências honestas de hardware/ambiente:** testes físicos com Momentum 4 / AirPods Pro conectados (E-08/E-09/E-10 completos), TCC interativo de janela em uso contínuo e dogfood de 14 dias / 50 testadores (Gates G2/G3) permanecem abertos fora deste ambiente headless.

### 2026-11-21 · Sweetspot headless — multi-tap, P3 crash recovery, fail-safe, packaging

1. **Motor & roteamento:**
   - `ProcessTapEngine.reconcileMultiTap` com `kAudioHardwarePropertyTranslatePIDToProcessObject`, slots multi-tap, `MirrorOutputTarget` (atraso 0–250 ms) e invariante P1 (`0` taps ativos com bypass/desligado).
   - DSP C++: linha de atraso RT pré-alocada (`delay_ms`) para alinhamento multi-saída.
   - `HALManager`: snapshot persistido + `recoverLeftoverSnapshotIfPresent()` pós-crash; watchdog de devices/default output.
   - App: auto-duck em chamada VoIP, espelho multi-saída no Estúdio, IPC/extensões MV3 com volume por aba.
2. **CI & higiene P3:**
   - `scripts/verify_failsafe.sh` — 20× `SIGKILL` sem aggregates `dev.v1torres.timbr.agg.*` vazados e default output idêntico.
   - `ci_check.sh` — RTSan opcional (Homebrew LLVM) + fail-safe como etapa 9.
   - `build_dmg.sh` — assinatura Developer ID + `notarytool`/`stapler` quando `DEVELOPER_ID`/`NOTARY_PROFILE` estão definidos.
   - `Packaging/Homebrew/timbr.rb` (B-110 scaffold).
3. **Verificação local (2026-11-21):** `./scripts/ci_check.sh` **ALL PASSED**; `hdiutil verify dist/Timbr.dmg` **VALID**; SHA-256 `83f4b4e1749f82704a80a85c871e9b9d86031a5945cd3f9956693e9a614e47fd`.
4. **O que o plano total ainda exige (não esquecido, só impossível headless):** hardware M4/AirPods (E-08/09/10), TCC real, G2 dogfood, G3 beta+notarização, Sparkle 2 (B-208). A parte pesada de engenharia/código/CI deste ambiente está fechada.

### 2026-11-21 · First-run onboarding (RF-1401) + install local

1. **Onboarding em 4 passos** (`OnboardingWindow`): marca → promessa de privacidade/P3 → permissões explicadas *antes* de abrir Ajustes (nada auto-prompt) → pronto com atalhos e CTA Estúdio / barra de menus.
2. **Persistência:** `onboardingCompleted` no SQLite; idioma inicial via locale do sistema; `--smoke-check` pula a intro; Ajustes → “Repetir introdução”.
3. **`scripts/install_local.sh`:** instala em `/Applications`, limpa quarentena Gatekeeper e opcionalmente reseta onboarding para ensaio de 1ª abertura.
4. **CI:** `./scripts/ci_check.sh` verde (114 chaves PT/ES/EN).


### 2026-11-21 · Linha Apple (AirPods → Max) — paridade documental com Momentum 4

1. **Código:** [`AirPodsFamilyDriver.swift`](../../Sources/TimbreEngine/AirPodsFamilyDriver.swift) — classificador família, parser Continuity flip-aware (in-ear/lid), matriz `AppleModelCapabilityProfile`, scan CoreBluetooth passivo, telemetria HAL honesta (sem ANC inventado).
2. **UI:** [`AppleAccessoryViews.swift`](../../Sources/TimbreApp/AppleAccessoryViews.swift) — card Observatório + strip Mixer + Notch (compact glyph / expanded strip); AACP fechado; chips systemManaged.
3. **AutoEq starter:** AirPods 4 + 4 ANC (Rtings 5128), Pro 1/2, AirPods 3, Max; Pro 3 aguarda índice público.
4. **Docs:** [`airpods-laboratorio.md`](../03-viabilidade/airpods-laboratorio.md), Nota [`12_airpods_linha_apple.md`](../00-pesquisa/notas-fase-2/12_airpods_linha_apple.md), ADR-0011, matriz, PRD RF-0808/0809, NOTICE §3.
5. **Testes:** Pro 2 / AirPods 4 / 4 ANC / Pro 3 + flip + capabilities no `TimbreEngineTests`.
6. **Ainda físico:** Continuity live com case aberto + E-08 HFP com AirPods conectados.

### 2026-11-21 · CLEAN_SWEEP pré-merge (correções adversarial)

1. **GAIA:** denylist completa Nota 07 (`0x0605–0x06FF`, `0x1403/05/06`, DFU) + allowlist read-only no `Gaia3Packet.encode`.
2. **IA:** `adjust_band`/`setTilt` contam no cap de 3 bandas; teto absoluto de taste = ±6 dB.
3. **Continuity:** sem fallback cross-family; scan duty-cycled; start só com saída Apple; Mixer strip só no destino ativo.
4. **AutoEq:** match específico AirPods 4/Pro/Max; allowlist de `relativePath`; aviso Spatial no painel.
5. **IPC:** clamp BOPLA de volume/título; CI `permissions: contents: read`; rollback de taps `mutedWhenTapped` em falha parcial (mirrors best-effort).
7. **Passe D:** `requestScanBurst` rearmável; match Continuity same-family por tokens HAL; writes GAIA `0x1001`/`0x1003`/… na denylist; docs duty-cycle alinhadas.
