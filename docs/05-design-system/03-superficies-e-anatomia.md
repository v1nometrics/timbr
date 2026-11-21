# 03 · Superfícies e anatomia

> Implementação: `NotchOverlay.swift` (notch e pílula), `MenuBarPanel.swift` (barra de menus), `StudioWindow.swift` (Estúdio), `OnboardingWindow.swift` (Introdução). Regras de comportamento em `02-produto/especificacao-funcional.md §3`.

## 1. O notch

### 1.1 O preto (e o limite físico dele)

O preenchimento é `Color(.sRGB, 0, 0, 0, 1)`: zero absoluto, sem contorno, sem sombra, sem blur, sem transparência (lei L1).

**Limite do hardware, dito com honestidade.** O notch físico é um vazio sem pixels. A área que o timbr. desenha ao redor dele são pixels de tela exibindo preto:

| Tela | O preto desenhado parece… | Por quê |
|---|---|---|
| **Liquid Retina (LCD IPS, MacBook Air)** | Levemente acinzentado ao lado do notch físico, em sala escura | O LCD não apaga a luz de fundo; o pixel preto deixa vazar luz (contraste ~1000:1). Nenhum software corrige isso. |
| **Liquid Retina XDR (mini-LED, MacBook Pro)** | Quase indistinguível | Zonas de escurecimento local apagam a luz de fundo, com halo leve perto de áreas claras |
| **OLED (MacBook Pro 2026)** | Idêntico | Pixel preto = pixel apagado |

O que está sob nosso controle, e foi corrigido na v2.0: (1) não existe mais contorno de 11% de branco, que era o que tornava a borda visível em qualquer tela; (2) o topo é reto e encosta na moldura, sem frestas da barra de menus entre a moldura e a forma; (3) os ombros côncavos continuam a curva do hardware; (4) em repouso não desenhamos nada, só o notch físico aparece.

### 1.2 Geometria

`NotchScreenGeometry.measure()` escolhe a tela com `safeAreaInsets.top > 0` e mede:
- **largura do notch** = `auxiliaryTopRightArea.minX − auxiliaryTopLeftArea.maxX` (mínimo 120);
- **altura do notch** = `safeAreaInsets.top`.

`NotchShape` (animável) desenha, a partir do centro superior:

```
(left − s, top) ─╮                         ╭─ (right + s, top)     s = ombro côncavo (9 pt)
                  │                         │
                  │                         │
                   ╰── r ─────────────── r ─╯                        r = raio inferior contínuo
```

- Ombros: curva quadrática de `(left − s, top)` a `(left, top + s)`, com controle em `(left, top)`. É côncava como a do hardware.
- Cantos inferiores: duas cúbicas com controles a 38% do raio (aproxima o squircle da Apple).
- Sem notch físico: a forma vira uma pílula contínua flutuando 6 pt abaixo do topo.

### 1.3 Estados e medidas

`W` e `H` são a largura e a altura do notch físico. A **orelha** mede 42 pt.

| Estado | Largura do corpo | Altura | Raio inferior | Conteúdo |
|---|---|---|---|---|
| Repouso | W | H | min(10, H/2) | Nada (só o hardware) |
| Compacto | W + 2×42 | H | min(11, H/2) | Orelha esquerda: ícone do app em foco (17 pt). Direita: MiniMeter (nível real) ou ponto do Guardião. Nada sob a câmera. |
| HUD | max(W + 120, 300) | H + 20 | 16 | Orelhas: ícone de volume e valor; abaixo da câmera, barra de 3 pt |
| Espiada | max(W + 300, 480) | H + 50 | 20 | Faixa superior: app em foco e volume; corpo: fader da fonte em foco |
| Expandido | max(W + 300, 516) | H + 10 + foco (76, ou 58 sem fonte) + 34×linhas (≤3) + alerta (44) + rodapé (46) + 8 | 26 | Marca e saída na faixa superior; bloco da fonte em foco; até 3 outras fontes; alerta; rodapé |

**Faixa superior:** tudo que fica na altura `H` é dividido em esquerda | vão da câmera | direita. Nada é desenhado sob a câmera.

### 1.4 Expandido: anatomia

| Zona | Elementos | Tipografia |
|---|---|---|
| Faixa superior | `timbr.` + ponto de estado (verde = nativo, violeta = processando, cinza = desligado) · glifo + nome da saída | marca 13 semibold · `caption` |
| Foco | Ícone do app 30 pt · nome · "Tocando · 0.0 dB" · valor grande `72` `%` · mudo · fader com unidade a 75% do curso | `notchTitle`, `caption`, `notchValue` |
| Lista | Até 3 fontes: ícone 16 pt, nome, fader fino (2 pt), valor, mudo | `caption`, `monoSmall` |
| Alerta | Ponto âmbar, título, ação | `caption` |
| Rodapé | Chip "Ativo" (liga/desliga processamento) · "A/B neutro" · seletor de saída · "Estúdio ↗" | `caption` medium |

### 1.5 Interação

- Hover sobre o notch físico por 120 ms → espiada. Sair da espiada por 300 ms → volta. Clique → expandido.
- Detecção por um painel-sensor invisível com `NSTrackingArea` do tamanho do notch (mais as orelhas, no compacto). **Zero polling** em repouso.
- Expandido: clique fora ou `Esc` fecha. O painel não ativa o app (`nonactivatingPanel`); só aceita foco de teclado no estado expandido.
- Telas cheias: `.fullScreenAuxiliary`; HUD e expandido sobem ao nível `popUpMenu`.
- Vários monitores: o notch vive na tela que tem notch. Troca de tela recalcula a geometria.

### 1.6 Personalização permitida

O notch é **sempre preto absoluto**: não há tema de notch claro nem degradê. Personalizações seguras: mostrar ou não a atividade nas orelhas; usar só a barra de menus. Propostas futuras (acento monocromático branco no lugar do violeta) exigem ADR e teste em sala escura.

## 2. Barra de menus

Painel `MenuBarExtra(.window)` de 348 pt, nas cores do Estúdio (claro ou escuro, conforme o sistema): marca, estado do caminho e saída, switch de processamento; até 5 fontes com fader; lista de saídas com taxa e ✓; botões Abrir Estúdio, A/B neutro e Sair. É o fallback universal (Mac sem notch, outro app de notch ativo, usuário de teclado).

## 3. Estúdio

```
┌────────────┬──────────────────────────────────────────────────────┐
│ ● ● ●      │ 01 — MIXER                                           │
│ timbr.     │ Cada fonte no seu volume                [Ação]       │
│            │ Frase-resumo do caminho do sinal                     │
│ ▤ Mixer    │ ┌KPI┐ ┌KPI┐ ┌KPI┐ ┌KPI┐                              │
│ ∿ EQ       │ 01 Fontes de áudio ───────────────────────────────── │
│ ⌁ Observ.  │ ┌ lista em cartão com hairlines ──────────────────┐ │
│ APP        │ └──────────────────────────────────────────────────┘ │
│ ⚙ Ajustes  │ 02 Saídas …                                         │
│ ⓘ Sobre    │ 03 Entrada …                                        │
│ ─────────  │                                                      │
│ ● Caminho  │                                                      │
│ [Desligar] │                                                      │
└────────────┴──────────────────────────────────────────────────────┘
```

- Janela com conteúdo em tamanho total (`fullSizeContentView`), barra de título transparente; a barra lateral passa sob os semáforos. 1180×780 inicial, mínimo 980×640, posição lembrada.
- Barra lateral: marca, navegação (⌘1–5), bloco de estado no rodapé com o botão de desligar o processamento (⌥⌘B).
- Tema: Sistema, Claro ou Escuro (Ajustes). O notch não segue o tema.

| Página | Tarefa principal (acima da dobra) | Secundário (abaixo) |
|---|---|---|
| Mixer | KPIs + volumes por fonte | Saídas (padrão, espelho, atraso, impedância do M4), Entrada (microfone, mudo global, ducking) |
| Equalizador | Curva + métricas + Gosto (4 controles) ou Filtros (tabela Pro-Q) | Correção do fone · Comparar às cegas + treinador · Descreva o som (IA) |
| Observatório | Caminho do sinal com marcas de origem + KPIs medidos | Espectro real · driver do fone · Guardião · linha do tempo |
| Ajustes | Aparência · Notch · Permissões · Navegadores · Dados | — |
| Sobre | Marca, propósito, código-fonte, apoiar | Versão, licença, motor, privacidade |

## 4. Introdução

Janela escura de 720×520 com barra de título transparente, quatro passos com indicador de progresso em cápsulas, sem decoração (os círculos "atmosféricos" da v1 foram removidos por parecerem template). Idioma em `TSegmented`; botões `TButtonStyle`.
