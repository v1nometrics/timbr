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
| `notchOpen` | mola, duração 0,42 s, bounce 0,2 | Repouso/compacto → espiada, expandido, HUD. O bounce é a assinatura da Dynamic Island (DynamicNotchKit usa `.bouncy(0,4)`; boring.notch, amortecimento 0,8). |
| `notchPop` | mola, 0,26 s, bounce 0,35 | Hover sobre o notch fechado: cresce 5 pt para os lados e 3 pt para baixo, na hora |
| `notchClose` | mola, 0,34 s, bounce 0 | Fechar. Mais rápido que abrir (assimetria: o sistema responde rápido). |
| `morph` | mola, 0,42 s, bounce 0 | Mudanças de layout grandes |
| `smooth` | mola, 0,36 s, bounce 0 | Entrada/saída de linhas no mixer do notch |
| `snappy` | mola, 0,24 s, bounce 0 | Switch, segmentado, polegar, alças da curva |
| `enter` | `cubic-bezier(.16,1,.3,1)`, 240 ms | Conteúdo entrando (com blur 6→0) |
| `exit` | `cubic-bezier(.7,0,.84,0)`, 180 ms | Conteúdo saindo |
| `pressOut` | `cubic-bezier(.23,1,.32,1)`, 140 ms | Escala 0,97 no pressionar |

## 3. Coreografia do notch

Modelo estudado no código dos apps de referência (DynamicNotchKit e NotchDrop, MIT; boring.notch, GPL, só parâmetros):

1. **A janela não anima nem muda de tamanho.** Canvas fixo; só a `NotchShape` (5 medidas animáveis: meia-largura esquerda e direita, altura, raio de baixo, ombro) se move.
2. **Hover em dois tempos.** O pop (`notchPop`) responde no mesmo quadro em que o ponteiro entra. A abertura vem após 150 ms de permanência, para que varrer a barra de menus com o mouse nunca abra o notch por acidente. Abrir por hover dispara um toque háptico leve no trackpad.
3. **Abre para os lados e para baixo ao mesmo tempo**, colado na borda da tela, com os ombros côncavos crescendo de 7 para 14 pt e o raio de baixo de 10 para 20–24 pt.
4. **Conteúdo revelado pela própria forma.** Entra com blur 8→0, escala 0,8→1 ancorada no topo e opacidade, numa mola de 0,36 s. Sai em 90 ms, para a forma nunca arrastar conteúdo velho.
5. **Um ícone persistente** (`focusIcon`) fica sempre na mesma linha, a da barra de menus. Ao abrir, ele só desliza na horizontal da orelha para a asa esquerda. Nada de copiar e cruzar.
6. **Fechar segue o ponteiro** (`dismissProgress`): `interactiveSpring(response: 0.16, damping: 0.86)` a cada movimento, com curva elástica `1 − (1 − d)^1.8`. Ao passar o limite, `notchClose` assume a partir do valor atual. O limite é de 64 pt na espiada e 104 pt no expandido, mas cai para 30 pt quando o ponteiro está na faixa da barra de menus. Ir para um menu solta a barra quase na hora. A transição entre os dois limites é contínua em y, sem salto.
7. **A origem é o hardware.** Toda abertura nasce do notch e volta para ele.
8. Números com `contentTransition(.numericText)`; ícone de volume com `.symbolEffect(.replace)`.

**Verificação:** `Timbr --demo` executa a coreografia completa (pop, abrir, fechar seguindo o ponteiro, expandir, fechar, HUD). Grave com `screencapture -v -V 9` e inspecione quadro a quadro (folhas de contato com `ffmpeg … tile=3x5`).

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
