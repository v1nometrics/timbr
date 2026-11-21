# 01 · Fundações e tokens

> Valores copiados de `design-system/tokens/*.tokens.json` (fonte da verdade). Se divergir, o JSON vence e este arquivo está desatualizado.

## 1. Cor

O sistema é **acromático** (herança do Órbita: nenhum cinza azulado, nenhum gradiente decorativo) com **um acento violeta reservado ao sinal de áudio**. Três superfícies: `light` (Estúdio claro, papel quente da ronda), `dark` (Estúdio escuro, grafite) e `notch` (preto do hardware).

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

Linhas internas são **hairlines de 0,5 pt** (um pixel em Retina). Bordas de cartão: 1 pt em `line.default`. **O notch não tem linha alguma.**

### 1.4 Acento e semântica

| Token | Claro | Escuro | Notch | Regra |
|---|---|---|---|---|
| `accent.signal` / `accent.base` | `#6B46FF` | `#A08BFF` | `#A592FF` | Só sinal processado: curva resultado, espectro, "processando", índice de banda ativa |
| `accent.fill` | `rgba(107,70,255,.07)` | `rgba(160,139,255,.10)` | `rgba(165,146,255,.10)` | Área sob a curva de resultado |
| `accent.controlOn` | `#111111` | `#F3F3F1` | `#FFFFFF` | Switch ligado, segmento ativo, botão primário |
| `semantic.positive` | `#1E8A5A` | `#4CC38A` | `#4CC38A` | Caminho nativo, concedido, bit-perfect |
| `semantic.warning` | `#B06A00` | `#E9A23B` | `#F0AA45` | Boost acima de 100%, alerta do Guardião, volume em software |
| `semantic.negative` | `#C2334D` | `#F2637E` | `#F2637E` | Ação destrutiva, crítico |
| `semantic.info` | `#2D6CB0` | `#6AB0E8` | `#6AB0E8` | Alerta informativo |

**Por que o violeta não marca controles:** no Órbita o acento marca o sujeito dos dados ("citam Tereza"). Aqui o sujeito é o som processado. Se botões também fossem violeta, o usuário não saberia mais o que é sinal e o que é interface.

### 1.5 Contraste (texto sobre fundo, WCAG 2.2)

`ink.primary` e `ink.secondary` passam 4,5:1 em todas as superfícies. `ink.muted` é reservado a texto ≥ 11 pt em mono maiúsculo (eyebrows) e notas não essenciais. `ink.faint` nunca carrega informação sozinho.

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

**Marca:** "timbr" em SF Pro Semibold com tracking −0,6 a −2,6 conforme o tamanho; o ponto final em `accent.signal`. Nunca outra fonte, nunca contorno.

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
| `control` | 7 | Botões, itens de navegação, chips quadrados |
| `field` | 8 | Campos de texto |
| `card` | 12 | Cartões e listas |
| `panel` | 16 | Painéis flutuantes |
| `notchShoulder` | 9 | Ombro côncavo do notch |
| `notchExpanded` | 26 | Cantos inferiores do notch expandido |
| `pill` | ∞ | Cápsulas |

Todos os cantos usam `style: .continuous` (squircle da Apple).

## 5. Elevação

Sem sombras em cartões: profundidade vem do **tom** (canvas → surface → raised). Exceções: polegar do fader e do switch (sombra 1,5 pt, 22%), segmento selecionado (1 pt, 6%). O notch nunca tem sombra.
