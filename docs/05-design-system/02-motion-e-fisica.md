# 02 · Motion e Física de Interação

> **Fontes normativas:** diretrizes `$apple-design` (molas criticamente amortecidas, *velocity handoff*, projeção de momento), `$emil-design-eng` (orçamento por frequência, < 300 ms, sem `scale(0)`, origem ancorada, `blur` para troca de estados) e tokens de movimento da [Órbita](../00-pesquisa/notas-fase-2/09_dna_visual_orbita_e_ronda.md#5-movimento).

---

## 1. Regra Zero: Quando NÃO animar

Antes de escolher uma curva, o desenvolvedor responde: **"Quantas vezes por dia o usuário verá isto?"**

| Frequência de uso | Exemplos no Timbre | Decisão obrigatória |
|---|---|---|
| **100+ vezes/dia ou iniciado por teclado** | Atalho `⌥⌘V` (abrir notch), `⌥⌘B` (bypass), `⌥⌘A` (A/B), `⌥⌘M` (mute mic), navegação por setas, troca de banda por tecla | **Sem animação (`0 ms`).** Mudança instantânea de estado. |
| **Dezenas de vezes/dia (UI recorrente)** | Hover em linhas do mixer, tooltips subsequentes após o primeiro aberto, atualização de medidores (60–120 Hz direto, sem interpolação artificial em modo EBU) | Sem animação ou micro-transição ≤ `120 ms`. |
| **Ocasional (gestos e superfícies)** | Expandir notch por clique/hover, arrastar slider de volume/EQ, abrir popover de destinos, trocar preset | Mola criticamente amortecida (`bounce: 0`) ou `ease.enter` ≤ `260 ms` (`400 ms` apenas no morph do notch). |
| **Raro / primeira vez** | Onboarding, transição de tela de calibração A/B, `bar-in` ao abrir o Estúdio pela primeira vez | Pode usar `0.42–0.70 s` com `ease.enter` ou `DistortionWavesKit` (se `Reduce Motion` desligado). |

> **Por que atalhos de teclado nunca animam?** Quem ajusta áudio durante o trabalho dispara atalhos centenas de vezes por dia. Qualquer atraso de `250 ms` parece lentidão do app, não suavidade.

---

## 2. Catálogo de curvas e molas (`TimbreMotion`)

O Timbre adota o princípio da Órbita: **bounce zero (`bounce: 0`)** como padrão em todo o app. Um utilitário audiófilo transmite precisão de instrumento, não elasticidade de brinquedo.

| Token | Parâmetro SwiftUI | Parâmetro CSS (Web/Docs) | Duração efetiva | Onde usar |
|---|---|---|---|---|
| `motion.instant` | `nil` (ou `0`) | `0ms` | `0 ms` | Teclado, tooltips consecutivos, bypass A/B |
| `motion.snappy` | `.spring(duration: 0.26, bounce: 0)` | `cubic-bezier(0.23, 1, 0.32, 1)` `220ms` | `~260 ms` | Toggles, segmentado (`matchedGeometryEffect`), press/release |
| `motion.smooth` | `.spring(duration: 0.40, bounce: 0)` | `cubic-bezier(0.16, 1, 0.3, 1)` `360ms` | `~400 ms` | Expandir/recolher notch (via mouse/hover), reordenar mixer |
| `motion.morph` | `.spring(duration: 0.42, bounce: 0)` | `cubic-bezier(0.16, 1, 0.3, 1)` `400ms` | `~420 ms` | Morfologia de geometria entre Compacto ↔ Espiada ↔ Expandido |
| `motion.responsive` | `.interpolatingSpring(stiffness: 520, damping: 44)` | — | Contínuo | Slider de volume e alça de EQ seguindo ponteiro/trackpad |
| `motion.enter` | `.timingCurve(0.16, 1, 0.3, 1, duration: 0.24)` | `cubic-bezier(0.16, 1, 0.3, 1)` `240ms` | `240 ms` | Entrada de popovers, troca de faixa (com blur), aparição de alerta |
| `motion.exit` | `.timingCurve(0.7, 0, 0.84, 0, duration: 0.18)` | `cubic-bezier(0.7, 0, 0.84, 0)` `180ms` | `180 ms` | Saída de HUD de volume, recolhimento de alerta |
| `motion.barIn` | `.timingCurve(0.16, 1, 0.3, 1, duration: 0.70)` | `cubic-bezier(0.16, 1, 0.3, 1)` `700ms` | `700 ms` | Entrada inicial de barras estáticas no Estúdio (`scaleX` de `0 → 1`, âncora à esquerda) |

**Exceção de laboratório (E-12):** se o teste em hardware real mostrar que o gesto de arrastar o notch para baixo parece "seco" ao soltar, admite-se testar no máximo `bounce: 0.08` **exclusivamente** na soltura de gesto com momento (`DragGesture.onEnded`), registrando em ADR se aprovado.

---

## 3. Física de gestos: *Velocity Handoff* e Interrompibilidade

### 3.1 Continuidade de velocidade (`$apple-design`)
Quando o usuário arrasta um slider, puxa o notch para baixo ou desliza uma alça do PEQ e solta com velocidade, a animação subsequente não começa parada:

- A velocidade final do gesto (`velocity` em pt/s) é convertida em velocidade inicial relativa para a mola SwiftUI:
  $$\text{relativeVelocity} = \frac{v_{\text{gesto}}}{\text{valorAlvo} - \text{valorAtual}}$$
- O usuário pode **interromper no meio**: se clicar fora enquanto o notch ainda abre, `.spring` preserva o estado atual e inverte a trajetória sem salto ou corte.

### 3.2 Projeção de momento em gestos do notch
Ao soltar um gesto de abrir/fechar o notch por arrasto vertical, a decisão "abre ou fecha?" usa a **posição projetada** após desaceleração ($\tau = 0.08\text{ s}$ a $0.12\text{ s}$), não apenas a posição instantânea do dedo, para que um movimento curto e rápido ("flick") sempre complete a intenção.

---

## 4. Micro-regras de componentes (`$emil-design-eng`)

| Regra | Errado | Certo no Timbre |
|---|---|---|
| **Nunca `scale(0)`** | Aparecer de `scale(0)` | Entrar de `scale(0.95)` + `opacity: 0` → `scale(1)` + `opacity: 1` |
| **Resposta tátil no clique** | Botão estático ao clicar | `scale(0.97)` ao pressionar (`120–160 ms ease-out`) em botões e chips |
| **Popover nasce do gatilho** | Escalar do centro da tela | Escalar a partir da âncora do botão (`.topLeading`, `.topTrailing`, `--transform-origin`) |
| **Troca de texto/faixa** | Troca seca ou slide longo | Crossfade + deslocamento vertical mínimo (`4 pt`) + `blur(3–4 px → 0)` em `240 ms` (`motion.enter`) |
| **Entrada em cascata** | Tudo aparece duro ou demora `1 s` | `stagger = 0.035 s` por linha do mixer, teto absoluto de `0.35 s` no total |
| **Tooltips em sequência** | Esperar `500 ms` em cada ícone da toolbar | Primeiro tooltip espera `400 ms`; mover para o vizinho abre em `0 ms` sem animação |
| **Números em movimento** | Texto saltando largura | `.monospacedDigit()` + `.contentTransition(.numericText(value:))` |
| **Sliders sem atraso** | Animar o thumb atrás do cursor | Durante `onChanged`, atualização direta `1:1` (ou `1/10` com `⌥`); mola atua apenas ao soltar ou clicar na trilha |

---

## 5. Medidores e gráficos em tempo real: movimento = verdade física

- **Medidores calibrados (EBU R128, Peak, True Peak):** nunca recebem suavização de UI (`withAnimation` é **proibido** em barras de nível normativas). A balística já é matemática (ex.: `300 ms` VU, `0,4 s` M, queda de `20 dB / 1,7 s` PPM DIN) calculada no buffer ou no snapshot de `TimelineView(.animation)`.
- **Curva de EQ ao editar:** ao arrastar uma alça, a resposta de magnitude composta redesenha no mesmo frame (`120 Hz` em ProMotion) — zero lag visual. Ao clicar num preset salvo ou alternar A/B, a transição visual da curva pode interpolar os pontos em `180 ms` (`motion.snappy`) **enquanto o DSP faz crossfade/rampa de coeficientes sem cliques** (atenção: nunca atrasar o áudio por causa da animação).
- **Reatividade decorativa (`VoiceGlowKit` / `VoiceRingKit`):** permitida **somente** fora dos medidores calibrados (ex.: halo sutil na borda inferior do notch em repouso ativo), desativável em Preferências ("Notch silencioso").

---

## 6. Acessibilidade e `Reduce Motion`

Quando `@Environment(\.accessibilityReduceMotion)` (ou `prefers-reduced-motion: reduce` na web) estiver ativo:

1. Todo morph de notch, stagger, `bar-in`, deslocamento vertical e `blur` de troca de faixa é **desligado**.
2. Transições viram fade puro de opacidade com duração máxima de `120 ms` (ou `0 ms` para teclado).
3. Efeitos baseados em shader (`VoiceGlowKit`, `VoiceRingKit`, `DistortionWavesKit`) caem para indicador estático de borda/tinta sem movimento contínuo.
