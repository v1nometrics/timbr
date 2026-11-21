# 01 · Fundações e Tokens de Design

> **Regra:** todos os tokens abaixo são definidos em `design-system/tokens/*.tokens.json` (formato W3C DTCG) e compilados para Swift (`TimbreTokens`) e CSS (`tokens.css`).
> **Origem dos valores:**
> - **Herança Órbita/Ronda (`[Órbita]`):** valores literais extraídos do CSS da Órbita/SIP e da Ronda Diária ([nota 09](../00-pesquisa/notas-fase-2/09_dna_visual_orbita_e_ronda.md)).
> - **Proposta Timbre (`[Proposta]`):** adaptações para a superfície preta `#000000` do notch e escala SwiftUI em pontos. Devem ser validadas em hardware real no experimento **E-12**.

---

## 1. As três superfícies do Timbre

Diferente de um site comum (que tem modo claro e escuro seguindo o sistema), o Timbre opera **três superfícies simultâneas**:

| Superfície | Onde aparece | Aparência | Regra |
|---|---|---|---|
| **Light (`light`)** | Janelas Estúdio e Observatório quando o macOS está em modo claro | `#FAFAFA` (canvas) + `#FFFFFF` (cards) + borda `#E9E9E9` | Editorial limpo; sombra mínima |
| **Dark (`dark`)** | Janelas Estúdio e Observatório quando o macOS está em modo escuro | `#141414` (canvas) + `#191919` (cards) — **nunca preto puro** | Separação por passos de ~2,5% de luminância OKLCH |
| **Notch (`notch`)** | Notch, Pílula flutuante e Live Activity | **`#000000` absoluto**, independente do tema do sistema | Funde-se com a moldura física da câmera; **zero cards internos** |

---

## 2. Sistema de Cores

### 2.1 Escala neutra acromática (`croma = 0` em OKLCH) `[Órbita]`

Todos os neutros possuem croma exatamente `0` para manter neutralidade cirúrgica sob qualquer temperatura de monitor (P3 / True Tone).

| Token primitivo | OKLCH | sRGB Hex (aprox.) | Uso típico |
|---|---|---|---|
| `neutral.0` | `oklch(100% 0 0)` | `#FFFFFF` | Card no claro |
| `neutral.1` | `oklch(99% 0 0)` | `#FCFCFC` | — |
| `neutral.2` | `oklch(97.8% 0 0)` | `#F8F8F8` | Trilho de barra/slider no claro (`track`) |
| `neutral.3` | `oklch(95.8% 0 0)` | `#F1F1F1` | Hover sutil |
| `neutral.4` | `oklch(91.5% 0 0)` | `#E3E3E3` | — |
| `neutral.5` | `oklch(84% 0 0)` | `#CACACA` | — |
| `neutral.6` | `oklch(72% 0 0)` | `#A4A4A4` | — |
| `neutral.7` | `oklch(59% 0 0)` | `#7D7D7D` | Texto `ink.muted` no claro |
| `neutral.8` | `oklch(46% 0 0)` | `#585858` | Texto `ink.secondary` no claro |
| `neutral.9` | `oklch(34% 0 0)` | `#383838` | — |
| `neutral.10` | `oklch(23% 0 0)` | `#1D1D1D` | — |
| `neutral.11` | `oklch(15% 0 0)` | `#0B0B0B` | Texto `ink.primary` no claro (nunca `#000000`) |

### 2.2 Tokens semânticos por superfície

| Token semântico | Claro (`light`) `[Órbita]` | Escuro (`dark`) `[Órbita]` | Notch (`notch`) `[Proposta]` | Papel |
|---|---|---|---|---|
| `bg.canvas` | `#FAFAFA` (`oklch(98.4% 0 0)`) | `#141414` (`oklch(19% 0 0)`) | `#000000` | Fundo raiz da superfície |
| `bg.surface` | `#FFFFFF` | `#191919` (`oklch(21.5% 0 0)`) | `#000000` | Card / painel principal |
| `bg.raised` | `#FFFFFF` + sombra | `#1F1F1F` (`oklch(24% 0 0)`) | `white @ 7%` (`~#121212`) | Popover, submenu interno |
| `bg.track` | `#F8F8F8` (`neutral.2`) | `#242424` (`oklch(26% 0 0)`) | `white @ 12%` (`~#1F1F1F`) | Trilho de barra, slider, ring |
| `ink.primary` | `#0B0B0B` (`neutral.11`) | `#F2F2F2` (`oklch(96% 0 0)`) | `#F2F2F2` | Títulos, valores, faixa atual (nunca `#FFFFFF` puro) |
| `ink.secondary` | `#585858` (`neutral.8`) | `#B4B4B4` (`oklch(77% 0 0)`) | `#B4B4B4` | Subtítulos, artista, nomes de app |
| `ink.muted` | `#7D7D7D` (`neutral.7`) | `#8C8C8C` (`oklch(64% 0 0)`) | `#7A7A7A` | Eyebrows, unidades, letras inativas |
| `line.default` | `#E9E9E9` (`oklch(93.5% 0 0)`) | `#2B2B2B` (`oklch(29% 0 0)`) | `white @ 11%` (`~#1C1C1C`) | Contorno de cards/controles |
| `line.subtle` | `#F3F3F3` (`oklch(96.5% 0 0)`) | `#222222` (`oklch(25% 0 0)`) | `white @ 7%` (`~#121212`) | Divisórias internas entre linhas |
| `line.strong` | `#C4C4C4` (`oklch(82% 0 0)`) | `#484848` (`oklch(40% 0 0)`) | `white @ 28%` (`~#484848`) | Hover de borda, linha de referência neutra |

### 2.3 Acento violeta — Regra de unicidade `[Órbita]`

| Token | Claro | Escuro | Notch `[Proposta]` |
|---|---|---|---|
| `accent.base` | `#7747FF` (`oklch(56.7% .253 287.3)`) | `#A78BFF` (`oklch(71.2% .166 292.8)`) | `#A78BFF` |
| `accent.strong` | `#5528CE` | `#C7B7FF` | `#C7B7FF` |
| `accent.subtle` | `rgba(119, 71, 255, 0.13)` | `rgba(119, 71, 255, 0.22)` | `rgba(119, 71, 255, 0.26)` |
| `control.on` | `#7747FF` | `#8A66FF` | `#A78BFF` |

**Onde o violeta entra no Timbre:**
1. **Curva `Gosto` (preferência do usuário)** no editor de EQ e na comparação de curvas.
2. **Item selecionado / fonte em foco** no mixer e na navegação lateral do Estúdio.
3. **Slider ativo sob o dedo/ponteiro** ou toggle ligado.
4. **Atmosfera mínima de onboarding/Sobre** (anéis concêntricos a 11% e 7% — **proibido no notch**).

**Onde o violeta nunca entra:** em texto corrido, em mais de um componente competindo na mesma tela, ou para enfeitar bordas estáticas.

### 2.4 Cores semânticas de sinal e estado `[Órbita]`

| Token | Claro (`L ≈ 50%`) | Escuro / Notch | Significado no Timbre |
|---|---|---|---|
| `semantic.positive` | `#00774D` (`oklch(50% .12 162)`) | `#55D69F` (`oklch(79% .14 162)`) | Bit-perfect confirmado, caminho íntegro, headroom seguro |
| `semantic.warning` | `#9F6202` (`oklch(55% .12 68)`) | `#F2BD68` (`oklch(83% .12 78)`) | Reamostragem ativa, ganho `> 100%`, pré-clipping (`-1` a `0 dBTP`) |
| `semantic.negative` | `#BB2C54` (`oklch(53% .18 10)`) | `#F0738F` (`oklch(71% .155 8)`) | Clipping / limiter atuando, HFP de chamada degradando áudio, erro de tap |
| `semantic.info` | `#136D9E` (`oklch(51% .11 240)`) | `#7CC4F0` (`oklch(79% .095 236)`) | Driver conectado, status neutro informativo, selo `REPORTADO` |

**Regra crítica de tintura (OKLab, nunca RGB/OKLCH direto):**
Na Órbita, badges e fundos sutis usam `color-mix(in oklab, cor, superfície)`. Misturar em sRGB deixa o tom acinzentado; misturar em OKLCH puxa tons frios para rosa em build de produção. No SwiftUI, implementaremos `Color.mix(_ a: Color, _ b: Color, weight: Double, space: .oklab)` (~30 linhas de conversão linear sRGB ↔ OKLab) com proporções:
- Badge/Chip fundo: `10%` claro / `12%` escuro/notch.
- Badge/Chip tinta: `84%` claro / `94%` escuro/notch.

### 2.5 Paleta de dados (séries e curvas de EQ)

| Papel de dado | Claro | Escuro / Notch |
|---|---|---|
| **Curva Resultado (EQ total)** | `ink.primary` (`#0B0B0B`, 1.75 pt) | `ink.primary` (`#F2F2F2`, 1.75 pt) |
| **Curva Gosto (usuário)** | `accent.base` (`#7747FF`, 1.5 pt) | `accent.base` (`#A78BFF`, 1.5 pt) |
| **Curva Correção (fone → alvo)** | `ink.muted` (`#7D7D7D`, tracejada `4 3`, opacidade `.75`) | `ink.muted` (`#8C8C8C`, tracejada `4 3`, opacidade `.75`) |
| **Espectro ao vivo (atrás da curva)** | `neutral.11 @ 8%` preenchido / `18%` contorno | `white @ 10%` preenchido / `22%` contorno |
| **Referência / Alvo (Harman, B&K)** | `line.strong` (`#C4C4C4`, opacidade `.55`) | `white @ 35%` (opacidade `.55`) |
| **Séries múltiplas (bandas / saídas)** | `s1 #1F7DCF`, `s2 #7128A5`, `s3 #E58F00`, `s4 #009E84` (ou rotação CVD-safe ΔE 9 do acento) | `s1 #55ADFF`, `s2 #9C37BE`, `s3 #E66E00`, `s4 #00A861` |

---

## 3. Tipografia (Três Vozes, Dois Pesos, Dois Registros)

### 3.1 Famílias e licenciamento

- **Primária (conteúdo, UI, display):** **Geist** (`Geist-Regular` 400, `Geist-Medium` 500) — licença SIL OFL 1.1. Embarcar instâncias estáticas no bundle (`ATSApplicationFontsPath`), evitando variação imprevisível de eixos de fonte variável em `Font.custom`.
- **Técnica (rótulos, unidades, índices, cabeçalhos):** **Geist Mono** (`GeistMono-Regular` 400, `GeistMono-Medium` 500) — SIL OFL 1.1.
- **Editorial / Humana (letras de música sincronizadas e citações):** **Geist Serif** (`GeistSerif-Regular` 400) — SIL OFL 1.1.
- **Fallback do sistema:** `SF Pro` / `SF Mono` (se Geist não carregar). Se usado em display, reduzir tracking negativo à metade porque o SF já aplica tracking óptico automático.

### 3.2 Escala tipográfica canônica (pt = px CSS em @1x)

A página evita tamanhos "mornos" (16–20 pt para texto): vive no registro **micro (9–14 pt)** e salta para **display (22–46 pt)**.

| Token | Família | Tamanho | Peso | Tracking | Line-height | Uso |
|---|---|---|---|---|---|---|
| `type.micro` | Geist Mono | `9 pt` | 400 | `+0.72 pt` (`+.08em`) | `1.2` | Marcas de eixo EQ (`20`, `1K`, `20K`), timestamps |
| `type.kicker` | Geist Mono | `10 pt` | 500 | `+1.0 pt` (`+.10em`) | `1.3` | Índices `01`, `02`, cabeçalhos de tabela |
| `type.eyebrow` | Geist Mono | `11 pt` | 500 | `+1.21 pt` (`+.11em`) | `1.4` | **Eyebrow canônico** (`CAIXA ALTA`, `ink.muted`, separador `·`) |
| `type.monoValue` | Geist Mono | `10.5–11 pt` | 400 | `+0.22 pt` (`+.02em`) | `1.3` | Unidades (`DB`, `HZ`, `KHZ`, `LUFS`, `MS`), selos |
| `type.caption` | Geist | `11 pt` | 400 | `-0.11 pt` (`-.01em`) | `1.45` | Rodapé de card, selo de fonte de medição |
| `type.small` | Geist | `12 pt` | 400 / 500 | `-0.12 pt` (`-.01em`) | `1.4` | Subtítulo de card, notas, linha secundária de faixa |
| `type.body` | Geist | `13–14 pt` | 400 / 500 | `-0.14 pt` (`-.01em`) | `1.4` | Nome de app no mixer, título de faixa, controles |
| `type.prose` | Geist | `14.5 pt` | 400 | `-0.15 pt` | `1.6` | Explicações do Guardião, "Como ler", onboarding |
| `type.cardTitle` | Geist | `18 pt` | 500 | `-0.45 pt` (`-.025em`) | `1.25` | Título de painel no Estúdio / Observatório |
| `type.mediumValue` | Geist | `22–27 pt` | 500 | `-0.9` a `-1.1 pt` (`-.04em`) | `1.0` | Valor central de dial / donut / notch expandido compacto |
| `type.displayValue` | Geist | `34–39 pt` | 500 | `-1.5` a `-1.76 pt` (`-.045em`) | `1.05` | Volume grande no HUD/Estúdio, KPI principal |
| `type.heroTitle` | Geist | `44–46 pt` | 500 | `-2.3 pt` (`-.05em`) | `1.01` | Apenas onboarding e página web/Sobre |
| `type.lyric` | Geist Serif | `15–17 pt` | 400 | `-0.08 pt` | `1.45` | **Letras sincronizadas** no notch e no Estúdio |

### 3.3 Regras tipográficas para números

1. Todo número dinâmico ou alinhado em coluna usa `.monospacedDigit()` (`tabular-nums`).
2. Números grandes **não usam fonte mono**; usam `Geist` peso `500` com tracking negativo forte (`-0.045em`).
3. A unidade fica menor e em `ink.muted` ao lado do número (ex.: `−12,4` em `34 pt` + `dBTP` em `11 pt` Mono) ou abaixo dele (`48,0 kHz` / `24 bit`).
4. Sinal negativo é sempre o menos tipográfico `−` (`U+2212`), nunca hífen `-`.
5. Números que mudam discretamente (volume HUD, dB de preamp, taxa nominal) usam `.contentTransition(.numericText(value:))` (equivalente nativo ao `AnimatedCounter` da Órbita).

---

## 4. Espaçamento, Grade, Raios e Elevação

### 4.1 Grade de espaçamento (`2 pt` micro / `4 pt` macro)

- **Escala base:** `2, 4, 6, 8, 12, 16, 20, 24, 32, 40, 48, 64 pt`.
- **Padding de card no Estúdio:** `20–24 pt` (ou `18 pt` em vistas densas do Observatório).
- **Padding interno do notch expandido:** `16 pt` horizontal, `12 pt` vertical abaixo da área segura do hardware.
- **Linhas de lista (mixer):** padding vertical `7–9 pt`, separadas por `line.subtle` (`0.5 pt` no notch, `1 pt` no Estúdio), **sem caixas individuais por linha**.

### 4.2 Grade 7/5 (assinatura de composição) `[Órbita]`

No Estúdio, Observatório e página web, o layout principal usa grade de 12 colunas (`gap: 18–20 pt`) com assimetria **7 / 5**:
- **Coluna principal (`7/12`):** o objeto ativo (gráfico de curva EQ, fluxo do Observatório, lista principal do mixer).
- **Coluna de apoio (`5/12`):** contexto e controle fino (tabela de bandas / Gosto simples, linha do tempo do Guardião, capacidades do dispositivo).
- **Blocos completos (`12/12`):** faixa de KPIs/resumo do sinal dividida por filetes verticais de `1 pt` (sem cards separados).

### 4.3 Raios concêntricos (`$apple-design` + `[Órbita]`)

Regra geométrica: **todo elemento aninhado mantém concentricidade**: `raio_externo = raio_interno + padding` (com piso mínimo `2 pt`).

| Uso | Valor | Notas |
|---|---|---|
| `radius.pill` | `9999 pt` (capsule) | Chips, toggles, barras finas, pílula flutuante |
| `radius.notchExpanded` | `20–24 pt` (apenas cantos inferiores; topo acoplado ao recorte) | Casamento visual com `continuous` (`RoundedRectangle(..., style: .continuous)`) |
| `radius.window` / `card` | `14 pt` | Cards no Estúdio (`14 pt` Órbita / `16 pt` janela macOS) |
| `radius.control` | `8–10 pt` | Botões, campos, popovers internos (`10 pt` `.md`) |
| `radius.badge` | `4–6 pt` | Selos `MEDIDO` / `REPORTADO`, tags |
| `radius.bar` | `2–3 pt` (ou `999 pt` para barras 4–6 pt) | Barras de espectro e sliders |

**Importante:** no SwiftUI, usar sempre `RoundedRectangle(cornerRadius: r, style: .continuous)` (squircle Apple), nunca curvas circulares padrão.

### 4.4 Bordas, sombras e materiais

- **Separação por borda, não por sombra.** No Estúdio claro, cards usam `1 pt` em `line.default` (`#E9E9E9`) e sombra quase imperceptível (`0 1px 2px rgb(0 0 0 / 0.035)`).
- **No notch, 0,5 pt (`1 / displayScale`)** em `line.subtle` (`white @ 7%`). Sem sombras externas além de um recorte limpo contra a barra de menus.
- **Liquid Glass (macOS 26/27 HIG):** usar `.glassEffect()` **apenas em controles flutuantes ou sob interação** (thumb do slider, popover destacado, barra flutuante sobre o gráfico de EQ no Estúdio) — **nunca** em barras de título, nunca atrás de texto denso de medição e **nunca no corpo do notch** (que é `#000000` opaco por design e pela regra HIG do Dynamic Island).
