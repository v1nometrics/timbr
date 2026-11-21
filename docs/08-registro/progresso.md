# Registro de Progresso

> **Regra ([AGENTS.md](../../AGENTS.md)):** este arquivo registra o estado real do projeto, o que já foi pesquisado, formalizado e auditado, e qual é o próximo passo exato. Nunca marcar como implementado o que está apenas planejado.

---

## Estado Atual

- **Fase ativa:** **Fase 0 · Planejamento & Arquitetura concluída** → pronto para iniciar **Lote A de Experimentos (`E-01`, `E-06`, `E-07`)**.
- **Código de produção (`macOS app`):** ainda não iniciado (por regra P5/P8, depende do fechamento dos gates da Fase 0).
- **Tokens & Design System:** especificações normativas e geração automatizada (`design-system/scripts/generate_tokens.py` → `TimbreTokens.swift` e `tokens.css`) operacionais e validadas.

---

## Histórico Consolidado

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

## Próximo Passo Imediato (Entrada na Fase 0 · Lote A)

1. Criar estrutura inicial de experimentos em `experiments/` (`E-01-tap-null-test`, `E-06-dsp-float64-bench`, `E-07-hal-probe`).
2. Executar **`E-01`** (Process Tap com ganho `1.0` vs saída direta em BlackHole: medir Null Test, latência e fail-safe `kill -9`) para validar `H-01`.
3. Executar **`E-06`** (benchmark offline + Clang RTSan do núcleo `Float64` em C++20/`vDSP` vs `camilladsp` v5, incluindo shelving Vicanek 2024 e True Peak 4× vs 8×) para fechar [`ADR-0003`](../07-decisoes/ADR-0003-nucleo-dsp.md).
4. Executar **`E-07`** (sonda HAL em saída integrada, DAC USB, Momentum 4 BT/USB/P2 e AirPods Pro) para fechar a matriz empírica de hardware.

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
   - **Pendências honestas de hardware/ambiente:** testes físicos com Momentum 4 / AirPods Pro conectados (E-08/E-09/E-10 completos), TCC interativo de janela em uso contínuo e dogfood de 14 dias / 50 testadores (Gates G2/G3) permanecem abertos fora deste ambiente headless.
