# timbr.

> **Sound, precisely yours.** · *Som, precisamente seu.* · *Sonido, precisamente tuyo.*  
> Central de controle de áudio, mixer por fonte, EQ de fidelidade 64-bit e Observatório da cadeia de sinal para macOS — com o notch como porta de entrada calma (`v1` trilíngue `PT / ES / EN` · codinome de repositório: `timbre`, ver [ADR-0014](docs/07-decisoes/ADR-0014-nome-identidade-e-i18n.md)).

[![Status](https://img.shields.io/badge/fase-Planejamento_%26_Arquitetura-7747FF)]()
[![Alvo](https://img.shields.io/badge/macOS-15%2B_%7C_26%2F27-000000)]()
[![Licença Proposta](https://img.shields.io/badge/licen%C3%A7a-MPL--2.0_%2B_DCO_(ADR--0001)-1D7A59)]()
[![Idiomas v1](https://img.shields.io/badge/i18n_v1-PT_%7C_ES_%7C_EN-141414)]()

---

## Leitura Obrigatória Antes de Qualquer Código

1. **[AGENTS.md](AGENTS.md)** — Regras do repositório, taxonomia de evidência (`Comprovado`, `Provável`, `Hipótese`, `Desconhecido`), proteção contra contaminação GPL e segurança Bluetooth.
2. **[01 · Visão e Princípios](docs/01-visao/visao-e-principios.md)** — Os 12 princípios testáveis (`P1`–`P12`) e o que o Timbre **não** é.
3. **[05 · Bíblia do Design System](docs/05-design-system/00-biblia-do-design-system.md)** — Lei visual e de movimento (tokens fonte única em `design-system/`, `bounce: 0`, OKLab, Geist OFL).

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
| **07 · Decisões** | Architecture Decision Records | [Índice de ADRs (`ADR-0001`–`ADR-0014`)](docs/07-decisoes/README.md) |
| **08 · Registro** | Registros vivos, riscos, hipóteses e auditoria adversarial | [Progresso](docs/08-registro/progresso.md) · [Hipóteses](docs/08-registro/hipoteses.md) · [Descobertas](docs/08-registro/descobertas.md) · [Riscos](docs/08-registro/riscos-e-mitigacoes.md) · [Revisão Adversarial](docs/08-registro/revisao-adversarial.md) |
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

> **Nota de ambiente (macOS 26.6 CLT sem Xcode.app):** nesta máquina, o binário `swift-package` do CommandLineTools 26.6 falha com erro de `dyld` (`BuildServerProtocol`), portanto os scripts abaixo invocam diretamente `clang++` + `swiftc` com `-sdk .../MacOSX26.sdk`. O `Package.swift` permanece sincronizado para builds via Xcode/SwiftPM completo.

```bash
# Verificar tokens, extensões, zero-GPL, compilar todos os módulos,
# rodar testes C++20 (ASan+UBSan), Swift 6 Core/Engine, montar dist/Timbr.app e smoke check:
./scripts/ci_check.sh

# Apenas montar e assinar ad-hoc o bundle dist/Timbr.app:
./scripts/build_app.sh

# Gerar o instalador distribuível dist/Timbr.dmg:
./scripts/build_dmg.sh

# Abrir o Playground interativo do Design System:
open design-system/playground/index.html
```

### Estrutura de Código & Extensões

- [`Sources/CTimbreDSP`](Sources/CTimbreDSP): núcleo DSP `Float64` em C++20 + `Accelerate/vDSP` (biquads Vicanek/RBJ, Auto-Preamp + margem de fase, True-Peak Lookahead Limiter, BS.1770 K-weighting, crossfeed `bs2b`, TPDF dither, FFT ~60 Hz, A/B crossfade de latência equalizada, zero alocações no caminho RT).
- [`Sources/TimbreCore`](Sources/TimbreCore): modelos, parser EqualizerAPO, i18n trilíngue `PT-BR / ES / EN`, Guardião (`G-01`–`G-07`), persistência SQLite, catálogo AutoEq, roteador de IA local com bounds rígidos, treinador Bayesiano (`PairwiseGP`), servidor IPC loopback autenticado (`127.0.0.1:48192`) e exportador sanitizado.
- [`Sources/TimbreEngine`](Sources/TimbreEngine): HAL Core Audio + snapshot/restauração P3, `ProcessTapEngine` (`CATapDescription` + P1 `0 taps` em neutro/bypass), driver read-only Sennheiser Momentum 4 (GAIA v3 + denylist `0x0607`/`0x02xx`), driver linha Apple (HAL + Continuity BLE L/R/Case, sem AACP), detector de apps de notch concorrentes e `MediaKeyTap`.
- [`Sources/TimbreApp`](Sources/TimbreApp): app nativo SwiftUI + AppKit (`NSPanel` não ativante em 5 estados + Pílula externa, MenuBarExtra, Estúdio com Mixer, Canvas EQ+FFT, Observatório/Guardião, Ajustes Pre-TCC e aba Apoiar/Doações).
- [`extensions/chrome-mv3`](extensions/chrome-mv3) & [`extensions/safari-web-ext`](extensions/safari-web-ext): extensões MV3 para controle por aba via IPC autenticado por token efêmero.

### Licença & Apoio

Software livre sob **MPL-2.0** ([`LICENSE`](LICENSE), atribuições em [`NOTICE`](NOTICE)) com DCO ([`CONTRIBUTING.md`](CONTRIBUTING.md)), 100% local e sem telemetria. Se o projeto for útil no seu dia a dia, há uma aba dedicada de apoio voluntário dentro do próprio Estúdio.
