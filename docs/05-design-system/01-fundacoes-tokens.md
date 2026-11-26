# 01 · Fundações e tokens

> Valores copiados de `design-system/tokens/*.tokens.json` (fonte da verdade). Se divergir, o JSON vence e este arquivo está desatualizado.

## 1. Cor

O sistema é **acromático** (nenhum cinza azulado, nenhum gradiente decorativo) e **não tem cor de marca** (ADR-0016): a ênfase é feita por tinta, peso e espessura; matizes só existem com significado semântico. Três superfícies: `light` (Estúdio claro, papel quente), `dark` (Estúdio escuro, grafite) e `notch` (preto absoluto do hardware).

### 1.1 Fundos

| Token | Claro | Escuro | Notch | Uso |
|---|---|---|---|---|
| `bg.canvas` | `#F5F5F2` | `#0B0B0C` | `#000000` | Fundo da página |
| `bg.surface` | `#FFFFFF` | `#131314` | `#000000` | Cartões, listas |
| `bg.raised` | `#FFFFFF` | `#19191B` | `rgba(255,255,255,.07)` | Segmento selecionado, nós ativos |
| `bg.sidebar` | `#EEEEEA` | `#0E0E0F` | `#000000` | Barra lateral do Estúdio |
| `bg.inset` | `#F7F7F5` | `#101011` | `rgba(255,255,255,.04)` | Campos, linhas aninhadas (abas) |
| `bg.track` | `#E6E6E2` | `#262628` | `rgba(255,255,255,.16)` | Trilha de faders e switches |
| `bg.hover` | `rgba(17,17,17,.04)` | `rgba(255,255,255,.04)` | `rgba(255,255,255,.06)` | Hover |
| `bg.selected` | `rgba(17,17,17,.07)` | `rgba(255,255,255,.075)` | `rgba(255,255,255,.11)` | Item ativo, chips |

### 1.2 Tinta

| Token | Claro | Escuro | Notch | Uso |
|---|---|---|---|---|
| `ink.primary` | `#111111` | `#F3F3F1` | `#FFFFFF` | Texto principal, valores |
| `ink.secondary` | `#5C5C58` | `#A3A3A0` | `#A1A1A1` | Subtítulos, rótulos |
| `ink.muted` | `#8C8C87` | `#6F6F6C` | `#6A6A6A` | Eyebrows, notas |
| `ink.faint` | `#B4B4AF` | `#4A4A48` | `#3E3E3E` | Índices "01", especificações discretas |
| `ink.inverse` | `#FFFFFF` | `#0B0B0C` | `#000000` | Texto sobre botão primário |

### 1.3 Linhas

| Token | Claro | Escuro | Notch |
|---|---|---|---|
| `line.default` | `rgba(17,17,17,.09)` | `rgba(255,255,255,.075)` | `rgba(255,255,255,.09)` |
| `line.subtle` | `rgba(17,17,17,.055)` | `rgba(255,255,255,.045)` | `rgba(255,255,255,.06)` |
| `line.strong` | `rgba(17,17,17,.18)` | `rgba(255,255,255,.15)` | `rgba(255,255,255,.18)` |
| `line.grid` | `rgba(17,17,17,.06)` | `rgba(255,255,255,.05)` | `rgba(255,255,255,.05)` |

Linhas internas são **hairlines de 0,5 pt** (um pixel em Retina). Bordas de cartão: 1 pt em `line.default`. **O notch não tem contorno**; a única luz na casca é `glass.edgeLight` (§1.6).

### 1.4 Ênfase (tinta) e semântica

| Token | Claro | Escuro | Notch | Regra |
|---|---|---|---|---|
| `accent.signal` / `accent.base` | `#111111` | `#F3F3F1` | `#FFFFFF` | Ênfase em tinta: curva de resultado (2 pt), espectro, "processando", índice de banda ativa |
| `accent.strong` | `#000000` | `#FFFFFF` | `#FFFFFF` | Ênfase máxima |
| `accent.subtle` | `rgba(17,17,17,.08)` | `rgba(255,255,255,.10)` | `rgba(255,255,255,.12)` | Fundo de destaque |
| `accent.fill` | `rgba(17,17,17,.05)` | `rgba(255,255,255,.06)` | `rgba(255,255,255,.07)` | Área sob a curva de resultado |
| `accent.controlOn` | `#111111` | `#F3F3F1` | `#FFFFFF` | Switch ligado, segmento ativo, botão primário |
| `semantic.positive` | `#1E8A5A` | `#4CC38A` | `#4CC38A` | Caminho nativo, concedido, bit-perfect |
| `semantic.warning` | `#B06A00` | `#E9A23B` | `#F0AA45` | Boost acima de 100%, alerta do Guardião, volume em software |
| `semantic.negative` | `#C2334D` | `#F2637E` | `#F2637E` | Ação destrutiva, crítico |
| `semantic.info` | `#2D6CB0` | `#6AB0E8` | `#6AB0E8` | Alerta informativo |

**Por que não há cor de marca:** decisão de arquitetura visual (ADR-0016). Permanece a estrutura editorial — papel quente, hierarquia de tinta, eyebrows em mono e números grandes tabulares — sem qualquer matiz decorativa. Os tokens `accent.*` continuam como papéis de ênfase, apontando para a tinta da superfície; o sinal processado se distingue por forma (linha sólida de 2 pt contra tracejado e linhas finas), não por cor.

### 1.5 Contraste (texto sobre fundo, WCAG 2.2)

`ink.primary` e `ink.secondary` passam 4,5:1 em todas as superfícies. `ink.muted` é reservado a texto ≥ 11 pt em mono maiúsculo (eyebrows) e notas não essenciais. `ink.faint` nunca carrega informação sozinho.

### 1.6 Vidro sem translucidez (ADR-0027)

| Token | Claro | Escuro | Notch | Uso |
|---|---|---|---|---|
| `glass.specular` | `rgba(17,17,17,.07)` | `rgba(255,255,255,.11)` | `rgba(255,255,255,.15)` | Topo da lente: borda de 0,75 pt iluminada por cima em chips, botões secundários, polegar do segmentado, `MenuChip` |
| `glass.rim` | `rgba(17,17,17,.17)` | `rgba(255,255,255,.035)` | `rgba(255,255,255,.04)` | Base da lente (degradê de cima para baixo) |
| `glass.edgeLight` | `0` | `0` | `rgba(255,255,255,.15)` | Luz da silhueta inferior do notch aberto: zero na altura da barra de menus, máxima na base |

O preenchimento continua opaco em todas as superfícies. O "vidro" é só a luz descrevendo a borda do material, para não revelar a costura com o notch físico nem depender do que está atrás.

## 2. Tipografia (ADR-0015)

**Famílias:** SF Pro (`sans`), SF Mono (`mono`), New York (`serif`), via `Font.system(design:)`. Optical sizes automáticos. Na web (docs, playground, site), a pilha CSS começa em `SF Pro / -apple-system` e cai para Geist, para que Mac e web fiquem idênticos.

**Aplicação:** sempre `.type(TimbreTypography.x)`, que aplica fonte, peso, tracking, entrelinha e caixa.

| Token | Família | Tamanho | Peso | Tracking | Caixa | Uso |
|---|---|---|---|---|---|---|
| `micro` | mono | 9 | 500 | +0,6 | ALTA | Badges, status ("TOCANDO") |
| `eyebrow` | mono | 10 | 500 | +1,1 | ALTA | Rótulos de KPI, índices de página, cabeçalhos de coluna |
| `monoSmall` | mono | 10 | 400 | 0 | — | Especificações ("48 kHz · USB · 2.2 ms"), eixos |
| `monoValue` | mono | 11 | 400 | 0 | — | Valores em linhas e tabelas |
| `caption` | sans | 11 | 400 | +0,06 | — | Notas, subtítulos de linha |
| `small` | sans | 12 | 400 | 0 | — | Texto secundário |
| `body` | sans | 13 | 400 | −0,08 | — | Texto padrão do macOS |
| `bodyStrong` | sans | 13 | 600 | −0,1 | — | Nome de app/dispositivo em linha |
| `prose` | sans | 14 | 400 | −0,15 | — | Parágrafos |
| `cardTitle` | sans | 14 | 600 | −0,2 | — | Título de painel |
| `notchTitle` | sans | 13 | 600 | −0,15 | — | Nome da fonte no notch |
| `sectionTitle` | sans | 17 | 600 | −0,35 | — | Seção numerada |
| `notchValue` | sans | 22 | 500 | −0,7 | — (tabular) | Volume no notch |
| `mediumValue` | sans | 22 | 500 | −0,6 | — (tabular) | Valor de KPI |
| `pageTitle` | sans | 28 | 600 | −0,9 | — | Título de página |
| `displayValue` | sans | 34 | 500 | −1,3 | — (tabular) | Número herói |
| `lyric` | serif | 16 | 400 | −0,1 | — | Letras sincronizadas |

**Marca:** "timbr" em SF Pro Semibold com tracking −0,6 a −2,6 conforme o tamanho; sem ponto final (ADR-0025). Nunca outra fonte, nunca contorno.

## 3. Espaço

Escala de 4 pt: `4 · 8 · 12 · 16 · 20 · 24 · 32 · 40 · 48 · 64`.

| Contexto | Valor |
|---|---|
| Margem lateral do conteúdo do Estúdio | 40 |
| Topo do conteúdo do Estúdio | 44 (abaixo dos semáforos) |
| Entre seções de página | 36 |
| Entre cabeçalho de seção e conteúdo | 14 |
| Padding horizontal de linha em lista | 20 |
| Altura de linha: fonte / saída / ajuste / abas | 62 / 62 / 54 / 48 |
| Grade de KPIs | 4 colunas (Mixer), 5 (Observatório), gap 12 |
| Largura útil máxima do conteúdo | 1120 |
| Barra lateral | 224 |

## 4. Raios

| Token | Valor | Uso |
|---|---|---|
| `badge` | 5 | Valores arrastáveis, badges retangulares |
| `control` | 7 | Itens de navegação, chips quadrados, botões de console (`M`) |
| `field` | 8 | Campos de texto |
| `card` | 12 | Cartões e listas |
| `panel` | 16 | Painéis flutuantes |
| `notchShoulder` | 9 | Ombro côncavo do notch |
| `notchExpanded` | 28 | Cantos inferiores do notch expandido (rodapé concêntrico: chip 28 pt a 14 pt da borda) |
| `notchPeek` | 24 | Cantos inferiores da espiada |
| `notchHud` | 16 | Cantos inferiores do HUD |
| `pill` | ∞ | Cápsulas |

Todos os cantos usam `style: .continuous` (squircle da Apple). Botões (`TButtonStyle`), chips (`TChip`, `MenuChip`) e o segmentado são **cápsulas**, como os controles do macOS 26. **Concentricidade:** um elemento dentro de outro usa raio interno = raio externo − margem.

## 5. Elevação

Sem sombras em cartões: profundidade vem do **tom** (canvas → surface → raised) e da **lente** nos controles elevados (§1.6). Exceções: polegar do fader e do switch (sombra 1,5 pt, 22%; 2,5 pt, 28% ao arrastar o fader), segmento selecionado (1 pt, 6%). O notch, só enquanto aberto, tem sombra preta em duas camadas: contato (30%, raio 2, y 1) e ambiente (42%, raio 22, y 12).
