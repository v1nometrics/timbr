# 04 · Componentes e visualização de áudio

> Implementação: `Sources/TimbreApp/DSComponents.swift`, `EQCurveCanvas.swift`, `StudioWindow.swift` (`SpectrumView`). Todo componente lê cores de `@Environment(\.palette)`; a superfície é definida uma vez na raiz com `.surface(.light | .dark | .notch)`.

## 1. Catálogo

| Componente | Substitui | Anatomia | Estados | Inspiração |
|---|---|---|---|---|
| **TFader** | `Slider` | Trilha 3 pt (2 pt em linhas densas), preenchimento em tinta, polegar branco 10→13 pt, marca de unidade 1 pt | normal, hover, arrastando, acima da unidade (preenchimento âmbar), bipolar (preenche a partir do zero) | Bencho `wake-slider`, faders de console |
| — taper de console | — | `unityPosition: 0.75` põe 100% a ¾ do curso e o boost no último ¼ | — | Mesas de som |
| **TSwitch** | `Toggle` | Cápsula 30×18, polegar 14 pt; ligado = tinta (`controlOn`) | on/off, desabilitado | iOS, Bencho `liq-toggle` (sem o líquido) |
| **TSegmented** | `Picker(.segmented)` | Fundo `bg.selected`, segmento ativo `bg.raised` + hairline + sombra 1 pt, desliza com `matchedGeometryEffect` | — | shadcn `toggle-group`, macOS |
| **TButtonStyle** | `.bordered`, `.borderedProminent` | `primary` (tinta cheia), `secondary` (superfície + hairline forte), `ghost`, `accent`, `destructive`; 28 pt (24 compacto); escala 0,97 | normal, pressionado, desabilitado 38% | shadcn `button` |
| **IconButton** | botões de ícone soltos | Quadrado 26 pt, raio 7, lavagem no hover; `active` pinta o ícone e o fundo a 12% | — | macOS toolbar |
| **ScrubValue** | campos numéricos | Valor mono em pastilha; arraste horizontal; frequência logarítmica | hover (cursor ↔), arrastando | FabFilter Pro-Q |
| **MenuChip** | `Menu` com cara de sistema | Cápsula `bg.selected`, rótulo `caption`, ⌃⌄; menu nativo ao abrir | — | macOS |
| **TField** | `.roundedBorder` | 30 pt, `bg.inset`, hairline; foco = borda em tinta 50% | — | shadcn `input` |
| **Hairline** | `Divider` | 0,5 pt em `line.default` (ou `strong`) | — | ronda |
| **Card / ListCard** | cartões empilhados | Raio 12, `bg.surface`, borda 1 pt; ListCard agrupa linhas com hairlines recuadas | — | ronda, Ajustes do macOS |
| **SectionHeader** | títulos soltos | Índice `01` em `eyebrow` + `ink.faint`, título `sectionTitle`, subtítulo `small`, ação à direita | — | ronda ("01 Audiência…") |
| **KPITile** | caixas de métrica | Eyebrow + marca de origem, valor `mediumValue`, unidade mono, nota | sem sinal: "—" | ronda (blocos de KPI) |
| **Badge** | etiquetas | Cápsula, ponto 5 pt, texto `micro`; tons neutral, accent, positive, warning, negative, info | — | ronda |
| **OriginMark** | badges de texto "MEDIDO" | Ponto 7 pt: cheio = medido, anel = reportado, tracejado = inferido, verde = bit-perfect | — | próprio (P4) |
| **AppIcon** | iniciais ou texto | Ícone real do app (`NSWorkspace`), cache; fallback: quadrado com inicial | — | macOS |
| **DeviceGlyph** | ícones genéricos | SF Symbol do dispositivo (airpodspro, headphones, laptopcomputer…) em quadrado 30 pt | ativo/inativo | — |
| **MiniMeter** | visualizador aleatório | Marca harmônica simétrica de 5 barras do `timbr.` (`1,5 pt`); respiração harmônica sutil (~2,6 s, ≤ 1,1 pt) sem medição e envelope suavizado pelo nível real quando há DSP | ativo, inativo (5 pontos em 2,5 pt), reduzir movimento (estático) | Ícone do `timbr.` (`Timbr.icns`) + acústica de harmônicos |
| **LevelBar** | — | Barra 3 pt, segmento âmbar acima de −1 dBFS | — | medidores de pico |

## 2. Gráficos e visualização de áudio

### 2.1 Regras gerais

1. **Só dado real.** Se não há sinal na cadeia, o gráfico mostra o estado vazio com uma frase, nunca uma linha em zero que pareça medida.
2. **Eixo de frequência logarítmico 20 Hz–20 kHz**, rótulos `20 · 50 · 100 · 200 · 500 · 1k · 2k · 5k · 10k · 20k` em `monoSmall`; linhas maiores em 100, 1k e 10k.
3. **dB linear**, ±15 dB visível, grade a cada 6 dB, linha de 0 dB mais forte; rótulos com sinal tipográfico (`+6`, `0`, `−6`).
4. **Estilo diferencia camadas**, não cor: Correção = tracejado `ink.secondary` 1 pt; Gosto = contínuo `ink.muted` 1 pt; Resultado = contínuo `accent.signal` 1,75 pt com área `accent.fill` até 0 dB. A legenda desenha o próprio estilo da linha.
5. **Resposta digital real**, avaliada pelo núcleo DSP (`evaluateCurve`) em 240 pontos logarítmicos, nunca o protótipo analógico.
6. Desenho em `Canvas` (uma passada) para custo previsível; sem Swift Charts em tempo real.

### 2.2 Curva de EQ (Estúdio)

- Altura 290 pt; calha direita de 34 pt para dB e inferior de 20 pt para Hz.
- Espectro ao vivo atrás da curva em `ink.primary` a 5%.
- Modo Filtros: alças numeradas de 17 pt (20 em hover/arraste), contorno `accent.signal`; arrastar move frequência (x) e ganho (y, passo 0,5 dB; só para pico e prateleiras).
- Faixa de métricas abaixo: Preamp, Pico real, Limiter, Latência (`eyebrow` + `monoValue`) e o switch de Crossfeed.

### 2.3 Espectro (Observatório)

Linha `accent.signal` 1,25 pt com degradê de 22% a 2% por baixo, piso de −96 dBFS, mesmo eixo logarítmico. Sem sinal: "Sem áudio na cadeia agora".

### 2.4 Caminho do sinal

Sete nós em linha (Fontes → Mixer → Correção → Gosto → Proteção → Dispositivo → Fone), ligados por traços de 14 pt (tinta primária quando o próximo nó está ativo, linha forte quando não). Cada nó: eyebrow, valor `cardTitle`, detalhe `monoSmall`, `OriginMark`. Nó ativo em `bg.surface` com borda forte; inativo em `bg.inset`. Legenda das marcas de origem no cabeçalho da seção.

### 2.5 Medidores (padrões a seguir quando existirem)

Pico de amostra e true peak (ITU-R BS.1770, sobreamostragem 4×), LUFS M (400 ms) e S (3 s). Escala de −60 a 0 dBFS, segmento de alerta acima de −1 dBFS. Balística de queda de 20 dB/s (proposta, a validar em E-06).

## 3. Correspondência web (docs, playground, site)

Na web os mesmos papéis usam shadcn/ui: `slider` → TFader, `switch` → TSwitch, `toggle-group` → TSegmented, `button` → TButtonStyle, `chart` (Recharts, `XAxis scale="log"`, `chart-area-gradient`) → curva de EQ e espectro. Os tokens `--timbre-*` de `tokens.css` alimentam o tema shadcn. Detalhes em `05-assets-iconografia-e-referencias.md`.

## Componentes do notch acrescentados em 2026-11-22/23

| Componente | Onde | Regra |
|---|---|---|
| `MenuChip(iconOnly:)` | Asa direita do expandido (saída) | Só ícone e chevron na asa; o nome vira dica e rótulo de acessibilidade. Asas não levam texto longo |
| `HoverLink` + `DimOnPress` | Nome do app nas asas e nas linhas de fonte | Placa suave no hover que vaza para fora do rótulo sem mexer no layout; pressão por opacidade, sem escala, para o ícone viajante continuar alinhado |
| Faixa **Geral** (master) | Expandido, depois das fontes | Hairline acima, como o master de uma mesa: fader de hardware e mudo da saída; mudo em âmbar |
| Linha "Saída sem som" | Espiada | Explica por que nada soa e oferece **Ativar som** |
| HUD de brilho | HUD | Mesmo HUD do volume com `sun.min.fill`/`sun.max.fill` |


## 4. Primitivas de Áudio Modeladas em `audiocn` (MIT)

Inspiradas na biblioteca open-source [`audiocn/ui`](https://github.com/audiocn/ui) (`MIT`, `audiocn.dev`) e adaptadas nativamente em SwiftUI (`DSComponents.swift`) + `TimbreCore` (`AudioUIMath.swift`) sob a identidade acromática estrita do **ADR-0016**:

| Componente SwiftUI (`DSComponents.swift`) | Equivalente `audiocn` | Matemática / Regra (`AudioUIMath.swift`) | Onde vive no `timbr.` |
|---|---|---|---|
| `TFader` (`liveMeterNorm`, `scaleMarks`) | `Fader` + `Parameter Slider` | Preenchimento de nível ao vivo translúcido dentro da trilha, pino de unidade (`100%` / `0 dB`), marcas de escala opcionais (`scaleMarks`), duplo clique para reset e modo fino (`⌥`/`⇧` a `0,2×`). | Mixer (`SourceRow`, `TabRow`, `OutputRow`), Equalizador (cartões de Gosto), `MenuBarPanel` |
| `TKnob` | `Knob` (`KnobTrack`, `KnobRange`, `KnobCap`, `KnobPointer`, `KnobScale`) | Arco de 270° (`-135°…+135°`), origem bipolar em 12h (`0 dB`), ticks periféricos iluminados apenas na excursão ativa, arraste vertical/horizontal com modo fino (`⌥`/`⇧`) e duplo clique para `0 dB`. | Equalizador — seção `01 Seu gosto` (`Graves`, `Calor`, `Presença`, `Ar`) em par com `TFader` bipolar |
| `TChannelButton` | `Channel Toggle` (`M`, `S`, `BYP`) | Botão quadrado/compacto de console com estados semânticos (`mute` em âmbar `semantic_warning`, `solo`/`monitor` em `semantic_positive`, `neutral` acromático). | Mixer (`SourceRow`, `TabRow`, `OutputRow`) e `MenuBarPanel` (mute por fonte `M`) |
| `TLevelMeter` | `Level Meter` (`peak` + `rms` + `peakHold`) | Barra dupla horizontal/vertical: camada translúcida de True Peak, núcleo sólido de RMS/LUFS Momentary e tick de Peak Hold com queda controlada (`AudioMeterBallistics`). | Equalizador — barra de metrologia abaixo da curva de resposta |
| `TLCDDisplay` + `TLCDMeterRow` | `LCD Display` + `LCD Meter` | Moldura dot-matrix escura com status ao vivo e medidor estéreo `L`/`R` de 32 segmentos com **quantização de bloco inteiro** (`LCDSegmentLayout` — nenhum segmento acende parcialmente), zonas `safe`/`warning` (`≥ -6 dB`)/`clip` (`≥ -1 dB`) e segmento de Peak Hold. | Observatório — monitor `TRUE PEAK & LUFS RECORDER MONITOR` |
| `TdBScale` + `TdBReadout` | `dB Scale` + `dB Readout` | Escala logarítmica com *audio taper* (`expoente 1,65` em `AudioDecibelMath`) e leitura tabular monoespaçada com largura fixa (`-∞` abaixo de `-70 dBFS`, sem deslocamento de layout). | Observatório (`TLCDDisplay`), Equalizador e Mixer |
| `TClipIndicator` | `Clip Indicator` | Indicador com *latch* de borda de subida (`≥ 0,0 dBTP` ou ativação do limiter), contagem acumulada de eventos e clique para resetar o latch (`appState.resetClipLatch()`). | Equalizador (barra de metrologia) e Observatório (`TLCDDisplay`) |
