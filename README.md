# timbr.

> **Sound, precisely yours.** · *Som, precisamente seu.* · *Sonido, precisamente tuyo.*  
> Central de controle de áudio, mixer por fonte, EQ de fidelidade 64-bit e Observatório da cadeia de sinal para macOS — com o notch como porta de entrada calma (`v1` trilíngue `PT / ES / EN` · codinome de repositório: `timbre`, ver [ADR-0014](docs/07-decisoes/ADR-0014-nome-identidade-e-i18n.md)).

[![Status](https://img.shields.io/badge/fase-MVP_em_dogfood-111111)]()
[![Alvo](https://img.shields.io/badge/macOS-15%2B_%7C_26%2F27-000000)]()
[![Licença Proposta](https://img.shields.io/badge/licen%C3%A7a-MPL--2.0_%2B_DCO_(ADR--0001)-1D7A59)]()
[![Idiomas v1](https://img.shields.io/badge/i18n_v1-PT_%7C_ES_%7C_EN-141414)]()

---

## Leitura Obrigatória Antes de Qualquer Código

1. **[AGENTS.md](AGENTS.md)** — Regras do repositório, taxonomia de evidência (`Comprovado`, `Provável`, `Hipótese`, `Desconhecido`), proteção contra contaminação GPL e segurança Bluetooth.
2. **[01 · Visão e Princípios](docs/01-visao/visao-e-principios.md)** — Os 12 princípios testáveis (`P1`–`P12`) e o que o Timbre **não** é.
3. **[05 · Bíblia do Design System](docs/05-design-system/00-biblia-do-design-system.md)** — Lei visual e de movimento: tokens fonte única em `design-system/`, notch preto absoluto que abre como Dynamic Island, tipografia de sistema SF ([ADR-0015](docs/07-decisoes/ADR-0015-tipografia-de-sistema.md)), identidade acromática sem cor de marca ([ADR-0016](docs/07-decisoes/ADR-0016-identidade-acromatica.md)).
4. **[08 · Progresso](docs/08-registro/progresso.md)** — Estado real do projeto, o que foi verificado e o próximo passo.

---

## Estado atual (2026-11-23)

O app roda no dia a dia do autor (dogfood). O que está **comprovado** por teste, medição ou captura, e o que ainda **não existe**:

| Área | Estado | Evidência |
|---|---|---|
| Volume e mudo por app (process taps) | Funciona | Autoteste E2E no app instalado: 50/25/200/150 % medem −6,02/−12,04/+6,02/+3,52 dB; mudo = silêncio ([registro](docs/08-registro/teste-e2e-volume-por-app-2026-11-22.md)) |
| Mudo à prova de falha (app mudo continua mudo se o timbr. fechar, travar ou for morto) | Funciona | `timbr-mute-keeper` ([ADR-0017](docs/07-decisoes/ADR-0017-mudo-a-prova-de-falha.md)); `scripts/selftest_mute_persistence.sh` e teste de ouvido com `kill -9` |
| Detecção de fontes simultâneas | Funciona, por evento do Core Audio | Chrome + Spotify juntos; serviços do macOS com nome e ícone ("Sons do sistema", "Siri e Ditado"…) |
| EQ paramétrico `Float64` + limiter true-peak | Funciona | Testes C++ com ASan/UBSan; limiter segura −0,30 dBFS no autoteste |
| Notch (repouso, compacto, espiada, expandido, HUD) | Funciona | Capturas e vídeo quadro a quadro; volume geral (master) e mudo no notch; teclas de volume **e brilho** com HUD próprio |
| Estúdio (Mixer, EQ, Observatório, Ajustes, Sobre) | Funciona | Capturas claro/escuro |
| Ícone na barra de menus | Só aparece quando o notch não é a entrada (sem notch, notch desligado ou opção ligada) | Verificado por estado do `NSStatusItem` |
| Roteamento de cada app para uma saída diferente (RF-0201) | **Não implementado** | — |
| Now playing, letras, reconhecimento, cenas | **Não implementado** | — |
| Atualização automática (Sparkle) e notarização | **Não implementado** (sem conta Apple Developer) | — |
| Bancada com Momentum 4 / AirPods (E-08, E-09) | **Não executada** | — |

Compatibilidade conhecida: [superwhisper e Chrome](docs/08-registro/compatibilidade-apps-2026-11-22.md).

---

## Mapa da Documentação

| Pasta | Conteúdo | Documentos principais |
|---|---|---|
| **00 · Pesquisa** | Evidência bruta de Fase 1 (SDK/mercado) e Fase 2 (M4, UI, Órbita, Qualidade Áudio, 62+ repos OSS) | [Relatório Fase 1](docs/00-pesquisa/relatorio-fase-1-notch-audiofilo.md) · [Notas Fase 1](docs/00-pesquisa/notas-fase-1/) · [Notas Fase 2](docs/00-pesquisa/notas-fase-2/) |
| **01 · Visão** | Princípios e vocabulário controlado | [Visão e Princípios](docs/01-visao/visao-e-principios.md) · [Glossário Técnico](docs/01-visao/glossario-tecnico.md) |
| **02 · Produto** | Requisitos (`EP-01`–`EP-15`), superfícies e diferenciação | [PRD](docs/02-produto/PRD.md) · [Especificação Funcional](docs/02-produto/especificacao-funcional.md) · [Mercado & Diferenciação](docs/02-produto/mercado-e-diferenciacao.md) |
| **03 · Viabilidade** | Matriz de viabilidade por faixa e laboratório Momentum 4 | [Matriz de Viabilidade](docs/03-viabilidade/matriz-de-viabilidade.md) · [Laboratório Momentum 4](docs/03-viabilidade/momentum4-laboratorio.md) |
| **04 · Engenharia** | Processos, DSP Float64, roteamento/abas, Observatório/Guardião, IA, segurança, RNFs | [Arquitetura Geral](docs/04-engenharia/arquitetura-geral.md) · [Motor DSP](docs/04-engenharia/motor-dsp-e-precisao.md) · [Roteamento & Abas](docs/04-engenharia/roteamento-e-abas.md) · [Observatório & Guardião](docs/04-engenharia/observatorio-e-guardiao.md) · [Inteligência & A/B](docs/04-engenharia/inteligencia-e-personalizacao.md) · [Segurança & Distribuição](docs/04-engenharia/seguranca-privacidade-distribuicao.md) · [Requisitos Não Funcionais](docs/04-engenharia/requisitos-nao-funcionais.md) |
| **05 · Design System** | Identidade Órbita + Ronda + `$apple-design` + `$emil-design-eng` | [Bíblia DS](docs/05-design-system/00-biblia-do-design-system.md) · [Fundações & Tokens](docs/05-design-system/01-fundacoes-tokens.md) · [Motion & Física](docs/05-design-system/02-motion-e-fisica.md) · [Superfícies](docs/05-design-system/03-superficies-e-anatomia.md) · [Componentes Áudio](docs/05-design-system/04-componentes-e-visualizacao-audio.md) · [Assets & Refs](docs/05-design-system/05-assets-iconografia-e-referencias.md) |
| **06 · Plano** | Experimentos bloqueadores (`E-01`–`E-17`), fases/gates, testes objetivos e aceite | [Experimentos](docs/06-plano/plano-de-experimentos.md) · [Roadmap & Backlog](docs/06-plano/roadmap-e-backlog.md) · [Estratégia de Testes](docs/06-plano/estrategia-de-testes.md) · [Critérios de Aceitação](docs/06-plano/criterios-de-aceitacao.md) |
| **07 · Decisões** | Architecture Decision Records | [Índice de ADRs (`ADR-0001`–`ADR-0016`)](docs/07-decisoes/README.md) |
| **08 · Registro** | Registros vivos, testes E2E, compatibilidade, riscos, hipóteses e auditorias | [Progresso](docs/08-registro/progresso.md) · [Teste E2E volume por app](docs/08-registro/teste-e2e-volume-por-app-2026-11-22.md) · [Compatibilidade](docs/08-registro/compatibilidade-apps-2026-11-22.md) · [Hipóteses](docs/08-registro/hipoteses.md) · [Descobertas](docs/08-registro/descobertas.md) · [Riscos](docs/08-registro/riscos-e-mitigacoes.md) · [Auditoria E2E](docs/08-registro/auditoria-e2e-2026-11-21.md) · [Revisão Adversarial](docs/08-registro/revisao-adversarial.md) |
| **09 · Open Source** | BOM, matriz de licenças e governança | [Inventário & BOM](docs/09-open-source/inventario-e-classificacao.md) · [Estratégia OSS](docs/09-open-source/estrategia-open-source.md) |
| **10 · Referências** | Bibliografia mestra e taxonomia de evidências | [Referências e Evidências](docs/10-referencias/referencias-e-evidencias.md) |

---

## Tokens Fonte Única (`design-system/`)

```bash
python3 design-system/scripts/generate_tokens.py
```

Gera automaticamente:
- [`design-system/generated/TimbreTokens.swift`](design-system/generated/TimbreTokens.swift) (para o app macOS nativo Swift 6 / SwiftUI)
- [`design-system/generated/tokens.css`](design-system/generated/tokens.css) (para site, documentação e playground interativo do Design System)

---

## Build, Testes e Execução (macOS 14.2+ / Apple Silicon)

> **Nota de ambiente:** os scripts invocam `clang++` + `swiftc` diretamente com `-sdk .../MacOSX26.sdk`, porque o `swift-package` das Command Line Tools falha nesta máquina (`dyld`, `BuildServerProtocol`). O `Package.swift` fica sincronizado para quem usa Xcode/SwiftPM.
>
> **Duas versões de Swift:** localmente o build usa Swift 6.3; o CI do GitHub (`macos-15`, Xcode 16.4) usa **Swift 6.1**, mais rígido com isolamento de concorrência (por exemplo, closures de `Canvas` são `nonisolated`). Código que passa aqui pode falhar lá: confira o check do PR antes de mesclar.

```bash
# Verificar tokens, extensões, zero-GPL, compilar todos os módulos,
# rodar testes C++20 (ASan+UBSan), Swift 6 Core/Engine, montar dist/Timbr.app e smoke check:
./scripts/ci_check.sh

# Uma vez por máquina: identidade de assinatura local estável. Sem ela, cada build tem uma
# assinatura ad-hoc diferente e o macOS deixa de aplicar a permissão de Acessibilidade
# (as teclas de volume e brilho voltam para o HUD do sistema).
./scripts/setup_dev_signing.sh

# Montar e assinar o bundle dist/Timbr.app (identidade local se existir, senão ad-hoc):
./scripts/build_app.sh

# Instalar em /Applications e abrir (primeiro uso):
./scripts/install_local.sh

# Medir o volume por app de ponta a ponta no app instalado (toca bipes por ~30 s):
./scripts/selftest_audio.sh

# Abrir cada superfície direto num estado, para revisão visual e capturas:
./dist/Timbr.app/Contents/MacOS/Timbr --studio mixer|equalizer|observatory|settings|support
./dist/Timbr.app/Contents/MacOS/Timbr --notch compact|peek|expanded|hud [--review-empty|--review-multi]
./dist/Timbr.app/Contents/MacOS/Timbr --demo          # coreografia completa do notch

# Gerar o instalador distribuível dist/Timbr.dmg:
./scripts/build_dmg.sh

# Abrir o Playground interativo do Design System:
open design-system/playground/index.html
```

### Estrutura de Código & Extensões

- [`Sources/CTimbreDSP`](Sources/CTimbreDSP): núcleo DSP `Float64` em C++20 + `Accelerate/vDSP` (biquads Vicanek/RBJ, Auto-Preamp + margem de fase, True-Peak Lookahead Limiter, BS.1770 K-weighting, crossfeed `bs2b`, TPDF dither, FFT ~60 Hz, A/B crossfade de latência equalizada, zero alocações no caminho RT).
- [`Sources/TimbreCore`](Sources/TimbreCore): modelos, parser EqualizerAPO, i18n trilíngue `PT-BR / ES / EN`, Guardião (`G-01`–`G-07`), persistência SQLite, catálogo AutoEq, roteador de IA local com bounds rígidos, treinador Bayesiano (`PairwiseGP`), servidor IPC loopback autenticado (`127.0.0.1:48192`), exportador sanitizado e catálogo de fontes do macOS (`SystemAudioClient`, `SilentOutputApps`).
- [`Sources/TimbreEngine`](Sources/TimbreEngine): HAL Core Audio + snapshot/restauração P3, `ProcessTapEngine` (`CATapDescription` + P1 `0 taps` em neutro/bypass, render que respeita o layout de canais), `AudioProcessMonitor` (detecção por evento), `AudioProcessAttribution` (dono real de cada processo de áudio), `AudioSelfTest` (medição E2E), `DisplayBrightness`, driver read-only Sennheiser Momentum 4 (GAIA v3 + denylist `0x0607`/`0x02xx`), driver linha Apple (HAL + Continuity BLE L/R/Case, sem AACP), detector de apps de notch concorrentes e `MediaKeyTap` (volume e brilho).
- [`Sources/TimbreApp`](Sources/TimbreApp): app nativo SwiftUI + AppKit: notch em `NSPanel` não ativante (5 estados, menu de contexto, volume geral), ícone de barra de menus condicional (`NSStatusItem` + `NSPopover`), Estúdio (Mixer, EQ com Canvas + FFT, Observatório/Guardião, Ajustes, Sobre), Introdução e componentes próprios (`DSComponents.swift`).
- [`extensions/chrome-mv3`](extensions/chrome-mv3) & [`extensions/safari-web-ext`](extensions/safari-web-ext): extensões MV3 para controle por aba via IPC autenticado por token efêmero.

### Contribuir

Veja [`CONTRIBUTING.md`](CONTRIBUTING.md): preparação da máquina, fluxo de branch e PR, e o que conferir antes de abrir um PR.

### Licença & Apoio

Software livre sob **MPL-2.0** ([`LICENSE`](LICENSE), atribuições em [`NOTICE`](NOTICE)) com DCO ([`CONTRIBUTING.md`](CONTRIBUTING.md)), 100% local e sem telemetria. Se o projeto for útil no seu dia a dia, há uma aba dedicada de apoio voluntário dentro do próprio Estúdio.
