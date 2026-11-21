# 04 · Componentes e Visualização de Áudio

> **Referências de especificação:** [FabFilter Pro-Q 4](../00-pesquisa/notas-fase-2/08_referencias_ui_componentes.md#6-convenções-de-ui-proaudio-eq-e-medição), [EBU Tech 3341 V4](../00-pesquisa/notas-fase-2/08_referencias_ui_componentes.md#6-convenções-de-ui-proaudio-eq-e-medição), [Órbita/Ronda](../00-pesquisa/notas-fase-2/09_dna_visual_orbita_e_ronda.md#4-componentes), `libraries.dev`, `Bencho`, `shadcn/ui`, `Spell UI` e `DSSSP`.

---

## 1. Gráfico de Equalizador Paramétrico (Padrão Pro-Q 4 × Estética Órbita)

### 1.1 Especificação visual e matemática

- **Motor de render:** SwiftUI `Canvas` dentro de `TimelineView(.animation(minimumInterval: 1/60))` (ou `1/120` em ProMotion quando o espectro ao vivo está ativo), lendo snapshots FFT de um ring-buffer lock-free. Se o espectro de alta resolução pesar em CPU/GPU, escalar o fundo do espectro para `MTKView` (Metal, padrão `AudioKitUI`).
- **Eixo X (Frequência):** escala logarítmica `20 Hz` a `20.000 Hz`. Linhas verticais finíssimas (`line.subtle`, `0.5 pt`) e rótulos em `type.micro` (`Geist Mono 9 pt`, `ink.muted`): `20`, `50`, `100`, `200`, `500`, `1K`, `2K`, `5K`, `10K`, `20K`.
- **Opção Piano Display:** alterna ou sobrepõe uma faixa inferior fina com as notas musicais (`C1`–`C9`), útil para localizar ressonâncias tonais.
- **Eixo Y (Amplitude):** escala linear com faixas selecionáveis em 1 clique, inspiradas no Pro-Q 4:
  - **Mastering / Fino:** `±3 dB` ou `±6 dB` (ideal para ajustar Gosto e curvas AutoEq finas).
  - **Mixing / Correção completa:** `±12 dB` (padrão) ou `±30 dB`.
  - Linha central `0 dB` em `line.default`.

### 1.2 As três curvas e ordem Z (de trás para frente)

1. **Espectro pós-EQ ao vivo (opcional):** preenchimento sutil (`neutral.11 @ 8%` claro / `white @ 10%` escuro) atrás de tudo, sem cores arco-íris.
2. **Curva `Correção` (fone → alvo):** linha tracejada (`[4, 3]`), `1.25 pt`, `ink.muted` a `75%` de opacidade. Mostra objetivamente o que o preset AutoEq/medição está fazendo.
3. **Curva `Gosto` (usuário / IA):** linha contínua `1.5 pt` em `accent.base` (`#7747FF` / `#A78BFF`), com preenchimento vertical translúcido `8%` até `0 dB`.
4. **Curva `Resultado` (soma real enviada ao DSP):** linha contínua `1.75–2 pt` em `ink.primary` (`#0B0B0B` / `#F2F2F2`). É a resposta **digital calculada exatamente pelo método de filtro ativo** (RBJ vs. casado/Vicanek vs. sobreamostrado) na taxa de amostragem atual — mostrando o comportamento real perto de Nyquist.
5. **Alças (Handles) de banda:** como `Canvas` não expõe elementos individuais ao VoiceOver, **as alças são views SwiftUI sobrepostas** posicionadas pelas mesmas coordenadas `(x(Fc), y(Gain))`.
   - Círculo `12 pt` (`16 pt` em foco/hover), borda `1.5 pt` em `bg.surface` para destacar sobre a curva, número da banda em `Geist Mono 8.5 pt`.
   - **Gestos:** arrasto livre = `Fc` + `Gain`; `⇧` + arrasto = trava eixo dominante; `⌥` + arrasto = precisão `1/10`; rolagem do trackpad ou pinça sobre a alça = ajusta `Q`; duplo clique na curva cria banda; duplo clique na alça zera ganho; `Delete` remove.
   - **Spectrum Grab (pós-MVP):** segurar o cursor sobre um pico saliente do espectro permite puxá-lo para baixo criando um notch/peaking direto naquela frequência.

---

## 2. Medidores Normativos (Observatório e Estúdio)

Nunca misturar visual decorativo com medição calibrada. Todos os medidores exibem **a unidade e a norma ativa o tempo todo** (`EBU Tech 3341 V4`, nov/2023).

| Modo | Janela / Balística | Escala | Regra visual |
|---|---|---|---|
| **Peak + True Peak (padrão MVP)** | Instantâneo + oversampling 4× (`ITU-R BS.1770`) | `−60` a `+6 dBTP` (alerta `> −1,0 dBTP`, vermelho `> 0,0 dBTP`) | Barra dupla fina (`6 pt` cápsula) com hold de pico de `1,5 s` e valor numérico `type.monoValue` ao lado |
| **EBU R128 Loudness (DS 1.0)** | `M` (`0,4 s` retangular), `S` (`3,0 s`), `I` (gated `-70 LUFS` / `-10 LU`), `LRA` | **EBU +9** (`−18` a `+9 LU`, padrão) ou **EBU +18** (`−36` a `+18 LU`); alternável `LUFS` / `LU` | Atualização `≥ 10 Hz`; **sem suavização visual extra**; máx. 1 casa decimal; indicar "LRA instável" nos primeiros `60 s` |
| **VU / PPM (DS 1.0)** | **VU:** `300 ms` (`0 VU = −18 dBFS`); **PPM:** DIN `10 ms / 1,7 s`, Nordic N9 `5 ms / 1,7 s`, EBU/BBC `10 ms / 2,8 s` | Conforme preset escolhido | Seleção explícita do preset no menu do medidor |

**Regras de cor em medidores:** fora das zonas de alerta (`warning` perto de `−1 dBTP`, `negative` em `≥ 0 dBTP` / ação de limiter), as barras permanecem monocromáticas (`ink.primary` / `ink.secondary` sobre `bg.track`) para manter a calma visual da Órbita.

---

## 3. Sliders, Controles e Componentes de Interface

### 3.1 Slider de Volume do Mixer (`TimbreSlider`)

- **Geometria:** trilho fino (`4–6 pt` de altura no notch, `6 pt` no Estúdio) com pontas em cápsula (`radius.pill`), preenchimento sólido `ink.primary` (ou `accent.base` apenas na fonte em foco).
- **Zona de boost (`> 100%` / `> 0 dB`):** marca vertical sutil (`1 pt` em `line.strong`) na posição `100%`; além desse ponto, o preenchimento muda para `semantic.warning` e aparece um indicador compacto `+X,X dB · pode clipar`.
- **Física:** arrasto `1:1` direto; `⌥` + arrasto = `1/10`; rolagem horizontal/vertical suave sobre a linha do app altera volume; duplo clique restaura `100%` (`0 dB`).
- **Padrão de gesto inspirado em:** `AudioKit/Controls` (`IndexedSlider` / `ArcKnob`, MIT — portar a lógica de gesto para SwiftUI puro, sem acoplar ao pacote parado) + física de `Bencho wake-slider`.

### 3.2 Controle Segmentado & Toggles

- **Segmentado:** trilho em `bg.track`, pastilha ativa em `bg.surface` (no Estúdio) ou `bg.raised` (no notch) com `matchedGeometryEffect` usando `motion.snappy` (`0.26 s`, `bounce: 0`). Rótulos nunca mudam de peso entre ativo/inativo (evita salto de largura).
- **Selo de origem (P4):** componente `SourceOriginBadge` com três variantes fixas:
  - `MEDIDO` → fundo `positive @ 12%` (OKLab), tinta `positive`.
  - `REPORTADO` → fundo `info @ 12%` (OKLab), tinta `info`.
  - `INFERIDO` → fundo `bg.track`, tinta `ink.muted` + ícone tracejado (nunca azul ou verde).

### 3.3 Letras Sincronizadas (Notch & Estúdio)

- **Tipografia:** `Geist Serif` (`15–17 pt`, peso `400`, `-0.08 pt` tracking).
- **Hierarquia:** linha ativa em `ink.primary` (`#F2F2F2`) com aspas pendentes opcionais em citações; linha anterior e próxima em `ink.muted` (`#7A7A7A`), entrando com transição suave (`opacity` + `blur(2 px → 0)` em `motion.enter`).

### 3.4 Efeitos Audio-Reativos Decorativos (`libraries.dev` — Opcional)

Os kits SwiftUI + Metal da `libraries.dev` (código **MIT**, [Package.swift](https://github.com/Jakubantalik/Libraries.dev/blob/main/Package.swift)) podem enriquecer estados vivos **sem nunca substituir medidores**:
- **`VoiceGlowKit`:** brilho sutil emanando da borda inferior do notch expandido ou da pílula quando há áudio ativo, alimentado pelo nível RMS normalizado (`0–1`) em `accent.base` ou `ink.muted` (desligável pelo usuário).
- **`VoiceRingKit` (estilo `Mono`):** anel reativo discreto para o modo de reconhecimento ShazamKit ou onboarding.
- **`BorderBeamKit`:** feixe fino percorrendo a borda durante otimização/processamento assíncrono (ex.: IA gerando delta ou AutoEq baixando índice).
- **`DistortionWavesKit`:** apenas em transições raras (onboarding, apresentação de novo fone), com fallback imediato para crossfade se `Reduce Motion` estiver ligado.
- *Regra de dependência:* fixar por commit (`revision:`) no SwiftPM; nunca importar modelos ML `.mfxl` (sujeitos à *Libraries.dev Model License* comercial restritiva).

---

## 4. Stack Web (Docs, Design System Playground e Site)

Conforme [ADR-0002](../07-decisoes/ADR-0002-plataforma-nativa.md), o app nativo é 100% Swift/SwiftUI, enquanto o site, a documentação interativa e o playground do design system compartilham exatamente os mesmos tokens via `tokens.css`:

| Necessidade Web | Biblioteca (licença) | Notas de uso |
|---|---|---|
| **Controles base** | `shadcn/ui` (MIT, Base UI) | `slider`, `switch`, `toggle-group`, `tabs`, `command` (`cmdk`), `sonner`, `sheet`, `kbd` |
| **Gráficos estáticos / histórico** | `shadcn/ui chart` + Recharts 3.8 (MIT) | `chart-area-gradient`, `chart-line-linear`, `XAxis scale="log"` para demos de resposta |
| **Playground interativo de EQ** | `DSSSP` (`NumberOneBot/dsssp`, MIT) | Gráfico logarítmico SVG com handles biquad arrastáveis para testar presets no browser |
| **Demos interativas de notch/motion** | `Bencho` free (MIT) + `libraries.dev` npm (MIT) | `dynamic-island`, `sound`, `wake-slider`, `rolling-counter`, `voice-glow` |
| **Landing / tipografia** | `Spell UI` (MIT) | `shimmer-text`, `blur-reveal`, `kbd`, `bars-spinner` |
