# 05 · Assets, iconografia e referências

## 1. Ícones

**SF Symbols, sempre.** Peso `medium` em navegação e ações, `regular` em glifos de dispositivo; renderização `hierarchical` nos dispositivos.

| Papel | Símbolo |
|---|---|
| Mixer | `slider.vertical.3` |
| Equalizador | `point.bottomleft.forward.to.point.topright.scurvepath` |
| Observatório | `waveform.path.ecg.rectangle` |
| Ajustes / Sobre | `gearshape` / `info.circle` |
| Barra de menus | `waveform` (ativo) · `waveform.slash` (desligado) |
| Volume (HUD) | `speaker.fill` · `speaker.wave.1/2/3.fill` · `speaker.slash.fill` |
| Mudo em linha | `speaker.wave.2` → `speaker.slash.fill` (âmbar) |
| Processamento | `power` |
| Interno / USB / BT / analógico / HDMI | `laptopcomputer` / `cable.connector` / `headphones` / `headphones` / `tv` |
| AirPods / Pro / Max | `airpods` / `airpodspro` / `airpodsmax` |
| Caixa externa | `hifispeaker` |
| Aba de navegador | `globe` |

Ícones de apps vêm do próprio app (`NSWorkspace.icon(forFile:)`). Nunca redesenhe ícones de terceiros.

## 2. Marca

- Wordmark **timbr.**: SF Pro Semibold, tracking negativo proporcional; o ponto em `accent.signal`. Tamanhos usados: 13 (notch), 15 (barra de menus), 19 (barra lateral), 56 (Sobre).
- Ícone do app: `Resources/Timbr.icns`, gerado por `scripts/generate_icns.py`.
- Proibido: contorno na marca, gradiente, sombra, mudar a cor do ponto fora do acento.

## 3. Referências mestras

| Referência | O que tomamos | O que **não** tomamos |
|---|---|---|
| **Órbita / ronda diária (SIP)** — nota `09_dna_visual_orbita_e_ronda.md` | Sistema acromático; um acento violeta com significado; eyebrows em mono maiúsculo com tracking; números grandes tabulares; seções numeradas `01…07`; cartões brancos com borda sutil sobre papel quente; notas "como ler" | Geist como fonte do app (fica para a web); gradiente de marca |
| **Apple HIG + WWDC (skill `apple-design`)** | Molas interrompíveis; tipografia de sistema com tracking por tamanho; squircles; materiais por tom; Dynamic Island como linguagem do notch | Liquid Glass sobre o notch (o notch precisa ser preto opaco) |
| **Emil Kowalski (skill `emil-design-eng`)** | Curvas fortes, pressionar 0,97, blur para unir estados, não animar teclado, assimetria abrir/fechar | Bounce em contexto profissional |
| **FabFilter Pro-Q** | Curva com espectro por trás, alças numeradas, valores arrastáveis | Coloração intensa por banda |
| **macOS Ajustes do Sistema** | Linhas agrupadas com título, subtítulo e controle à direita | — |

## 4. Bibliotecas web: como usar (nota `08_referencias_ui_componentes.md`)

O app é nativo (ADR-0002). As bibliotecas abaixo são usadas no **site, na documentação e no playground** e como **referência de comportamento** para os componentes SwiftUI.

| Biblioteca | Uso no timbr. | Componentes |
|---|---|---|
| **shadcn/ui** (MIT) | Base do site e do playground; gráficos do site | `chart` (Recharts, eixo log, `chart-area-gradient`, `chart-line-linear`, tooltip com indicador de linha), `slider`, `switch`, `toggle-group`, `tabs`, `command`, `sonner`, `sheet` |
| **Bencho** (free, MIT) | Referência de motion e protótipos web | `dynamic-island` (morph pílula→player), `sound` (now playing), `wake-slider`, `liq-toggle`, `rolling-counter`, `time-scrubber` |
| **Spell UI** (MIT) | Landing e docs | `kbd`, `shimmer-text`, `blur-reveal`, `bars-spinner` |
| **libraries.dev** (MIT no código) | Candidatos a efeitos áudio-reativos **opt-in** no notch (sempre alimentados por nível real) | `VoiceRingKit`, `VoiceGlowKit`, `BorderBeamKit`, `DistortionWavesKit` |

Regra: nenhum efeito decorativo entra no notch por padrão; qualquer efeito áudio-reativo é opcional, alimentado por nível medido, e respeita "Reduzir movimento".

## 5. Capturas de referência

Gere com as flags de revisão (`00-biblia §6`). Toda mudança visual de PR anexa capturas de: notch (compacto, espiada, expandido, HUD), Estúdio (5 páginas, claro e escuro), barra de menus e Introdução.
