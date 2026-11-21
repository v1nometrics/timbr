# 02 · Motion e física

> Fonte: `design-system/tokens/motion.tokens.json` → `TimbreMotion`. Regras de `apple-design` (molas interrompíveis, velocidade preservada) e `emil-design-eng` (frequência decide se anima; ease-in proibido; < 300 ms em UI).

## 1. Decisão: deve animar?

| Frequência | Exemplo no timbr. | Decisão |
|---|---|---|
| Centenas por dia | Atalhos ⌥⌘V/⌥⌘B, troca de aba do Estúdio por ⌘1–5 | **Sem animação** (aba do Estúdio: 140 ms de opacidade, só para não piscar) |
| Dezenas por dia | Hover no notch, arrastar fader, hover em linha | Resposta imediata; polegar cresce 10→13 pt em `snappy` |
| Ocasional | Abrir notch, HUD de volume, trocar modo do EQ | Mola padrão |
| Raro | Introdução, revelar resultado do A/B | Pode ter mais presença |

## 2. Tokens

| Token | Definição | Uso |
|---|---|---|
| `notchOpen` | mola, duração 0,38 s, bounce 0,12 | Repouso/compacto → espiada, expandido, HUD. O leve bounce é a assinatura da Dynamic Island. |
| `notchClose` | mola, 0,30 s, bounce 0 | Fechar. Mais rápido que abrir (assimetria: o sistema responde rápido). |
| `morph` | mola, 0,42 s, bounce 0 | Mudanças de layout grandes |
| `smooth` | mola, 0,36 s, bounce 0 | Entrada/saída de linhas no mixer do notch |
| `snappy` | mola, 0,24 s, bounce 0 | Switch, segmentado, polegar, alças da curva |
| `enter` | `cubic-bezier(.16,1,.3,1)`, 240 ms | Conteúdo entrando (com blur 6→0) |
| `exit` | `cubic-bezier(.7,0,.84,0)`, 180 ms | Conteúdo saindo |
| `pressOut` | `cubic-bezier(.23,1,.32,1)`, 140 ms | Escala 0,97 no pressionar |

## 3. Coreografia do notch

1. **A janela não anima nem muda de tamanho.** Canvas fixo; só a `NotchShape` (6 medidas animáveis) se move.
2. **Forma e conteúdo juntos, sem atraso artificial.** O conteúdo do corpo entra com opacidade e 6 pt de deslocamento em 200 ms `easeOut` enquanto a mola da forma corre; sai em 80 ms.
3. **Um ícone persistente** (`focusIcon`) muda de posição e tamanho com a mesma mola. Nada de copiar e cruzar.
4. **Fechar segue o ponteiro** (`dismissProgress`): `interactiveSpring(response: 0.16, damping: 0.86)` a cada movimento; curva elástica `1 − (1 − d)^1.8`; ao passar o limite, `notchClose` assume a partir do valor atual.
5. **A origem é o hardware.** Toda abertura nasce do notch e volta para ele.
6. Números com `contentTransition(.numericText)`; ícone de volume com `.symbolEffect(.replace)`.

**Verificação:** `Timbr --demo` executa a coreografia completa (abrir, fechar seguindo o ponteiro, expandir, fechar, HUD). Grave com `screencapture -v -V 9` e inspecione quadro a quadro (folhas de contato com `ffmpeg … tile=3x5`).

## 4. Pressão, hover e arraste

- Todo botão: escala 0,97 ao pressionar (`pressOut`); feedback no *pointer-down*.
- Fader: rastreio 1:1; `⌥` = ajuste fino 1/10; duplo clique volta ao valor de referência; ímã de 1,2% do curso na unidade (100% / 0 dB).
- Valores arrastáveis (Pro-Q): cursor `resizeLeftRight`; arraste horizontal; frequência em escala logarítmica (dobra a cada 120 pt).
- Alças da curva de EQ: crescem 17→20 pt em hover/arraste (`snappy`).

## 5. Movimento reduzido

Com "Reduzir movimento": o notch troca de estado com 120 ms de opacidade, sem mola e sem blur; números trocam sem transição; o resto mantém apenas mudanças de cor/opacidade.

## 6. Proibições

- `ease-in` em qualquer UI.
- Animar a partir de `scale(0)`.
- Visualizador "decorativo" que finge nível de áudio (o MiniMeter mostra um glifo estático quando não há medição).
- Animação em ação de teclado.
- Loops infinitos em repouso (o notch em repouso não desenha nada).
