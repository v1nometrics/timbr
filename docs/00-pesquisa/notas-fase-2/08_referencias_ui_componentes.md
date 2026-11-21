# Referências de UI e componentes para o design system (app de notch para audiófilos, macOS)

> Escopo: recursos gratuitos de UI (libraries.dev, Bencho, Spell UI, shadcn/ui), linguagem de design da Apple (Liquid Glass, HIG, SF Symbols, Dynamic Island no Mac, Live Activities no macOS 27.3), convenções de UI pro-audio (EQ, medidores) e referências de implementação em SwiftUI/AppKit para visuais em tempo real.
> Data de acesso de **todas** as fontes: **2026-11-21** (indicada como "ac. 2026-11-21" em cada citação). Metadados de repositório (licença SPDX, estrelas, último push) foram lidos via GitHub API na mesma data.

---

## 1. libraries.dev — "Distortion Waves" e a família de libs (Jakub Antalik)

### Takeaway
libraries.dev é o recurso **mais diretamente aproveitável no app nativo**: além de React, publica **ports em SwiftUI + Metal (MIT)** instaláveis por SwiftPM com piso **macOS 14**. Mas atenção: "waves" **não é um visualizador de áudio**, é uma transição de tela; os itens audio‑reativos são **Voice (VoiceGlowKit)** e **Voice ring (VoiceRingKit)**.

### Cited Findings
- **Distortion Waves** é um efeito de **transição de tela**: uma onda colorida leva uma view para outra, partindo do elemento que disparou e deformando um snapshot do DOM (ou da view SwiftUI). Três tipos: Vertical, Horizontal, Center (anel que expande a partir de avatar/ícone). Sem WebGL2 ou com Reduce Motion, cai para crossfade — [libraries.dev/waves](https://libraries.dev/waves), ac. 2026-11-21.
- React: `npm install distortion-waves` (React 18+, WebGL2), componente `DistortionWave` com `palette`, `waveStyle`, `scrub`, `live`, `onFinish` e `ref` com `play()`, `reverse()`, `reset()`, `prepare()`. SwiftUI: produto SwiftPM `DistortionWavesKit` (branch `main`), iOS 17+/macOS 14+, três shaders Metal, precisa compilar via Xcode. React Native "coming soon". Licença: "distortion-waves is MIT" e "DistortionWavesKit is MIT" — [libraries.dev/waves](https://libraries.dev/waves), ac. 2026-11-21.
- Catálogo do site: Border beam, Thinking orbs, Gooey, Voice, Voice ring, Distortion waves, Bot avatars, Metal, Image; "Models": Magnetic UI, Voice position; produtos: Skill e Studio Pro — [libraries.dev/waves](https://libraries.dev/waves), ac. 2026-11-21.
- `Package.swift` raiz (swift-tools 5.9, `platforms: [.iOS(.v17), .macOS(.v14)]`) expõe os produtos: `BorderBeamKit`, `ThinkingOrbsKit`, `VoiceGlowKit`, `BotAvatarsKit`, `MetalFxKit`, `MagnetKit`, `VoiceRingKit`, `VoiceRingEmotion`, `VoicePositionKit`, `DistortionWavesKit`. O próprio manifesto recomenda "Track the branch, not a version: the repo's older semver tags predate this manifest" e diz que os `.metal` são compilados pelo build system do Xcode — [Package.swift no GitHub](https://github.com/Jakubantalik/Libraries.dev/blob/main/Package.swift), ac. 2026-11-21.
- Repositório: licença **MIT** (Copyright (c) 2026 Jakub Antalik), ~4.948 estrelas, último push 2026-11-19; pacotes npm `border-beam`, `thinking-orbs`, `bot-avatars`, `liquid-gooey`, `voice-glow`, `metal-fx`, `img-fx` — [GitHub Jakubantalik/Libraries.dev](https://github.com/Jakubantalik/Libraries.dev), ac. 2026-11-21.
- Os **modelos de ML** (ex.: `Magnet.mfxl`, `VoicePosition.mfxl`) ficam sob a "Libraries.dev Model License" v1.2 (vigente desde 5 nov 2026), separada do código MIT; lançamento comercial com modelo exige Pro/Business — [LICENSE-MODEL.md](https://github.com/Jakubantalik/Libraries.dev/blob/main/LICENSE-MODEL.md), ac. 2026-11-21.
- Preços: Free US$ 0 (variantes free de todas as libs, licença de modelo pessoal/não comercial); Pro US$ 9/mês; Business US$ 29/mês (3 assentos); Lifetime US$ 149. Pro acrescenta Studio (customização/export de config), presets/variants Pro, uso comercial de modelos, Studio AI agent, Pro skill — [libraries.dev/pro.html](https://libraries.dev/pro.html), ac. 2026-11-21.
- **Voice** (`voice-glow` / `VoiceGlowKit`): brilho audio‑reativo que sobe da **borda inferior** do elemento que envolve; entradas `stream` (MediaStream), `level` (0–1 ou getter por frame), `processing` (vira feixe que percorre a faixa). SwiftUI iOS 17+/macOS 14+, shader Metal; exige `NSMicrophoneUsageDescription`. No SwiftUI, "Emotion detection, the live transcript and processing are VoiceGlow Pro" — [libraries.dev/voice.html](https://libraries.dev/voice.html), ac. 2026-11-21.
- **Voice ring** (`voice-ring` / `VoiceRingKit`): anel de luz cujo **espectro se curva com a voz**; estilo alternativo **Mono** (dois loops de tubo cinza). SwiftUI: `source` = `.meter(meter)`, `.level { }` (valor 0–1 próprio) ou `.silence`; `state` = idle/listening/speaking/processing com transições suavizadas; macOS 14+; lente de borda em shader Metal. VoiceRingKit/VoiceRingEmotion/VoicePositionKit são MIT; modelos com licenças próprias — [libraries.dev/voice-ring.html](https://libraries.dev/voice-ring.html), ac. 2026-11-21.
- **Metal** (`metal-fx` / `MetalFxKit`): efeito "liquid metal" em tempo real para botões, ícones, texto e badges, com halo e reflexos; baseado em Paper Shaders; a página cita iOS 17+ para SwiftUI (o manifesto declara macOS 14) — [libraries.dev/metal.html](https://libraries.dev/metal.html), ac. 2026-11-21; [Package.swift](https://github.com/Jakubantalik/Libraries.dev/blob/main/Package.swift), ac. 2026-11-21.

### Inferences
- **Uso no app SwiftUI (direto, via SwiftPM)**: `VoiceRingKit` com `source: .level { }` alimentado pelo nosso RMS/LUFS pode virar um "orb" de presença sonora no estado expandido do notch; `VoiceGlowKit` (brilho a partir de uma borda) é análogo natural a um **halo na borda inferior do notch** reagindo ao nível de saída; `BorderBeamKit` serve como indicador de estado (ex.: processamento/EQ ativo) contornando a pílula; `DistortionWavesKit` (Center) pode ser a transição de onboarding ou de troca de dispositivo — com moderação, dado o tom "Apple‑clean".
- Esses efeitos são **decorativos, não métricos**: não substituem medidores calibrados (PPM/LUFS) nem analisador de espectro. Para o "observatório" usar renderização própria (seção 7).
- Risco: dependência de branch `main` sem semver → fixar por commit (`revision:`) no SwiftPM e vendorizar se necessário; medir custo de GPU de shaders sempre ativos num app residente de menu bar.
- Para a landing page/docs, os pacotes npm equivalentes (`voice-ring`, `voice-glow`, `distortion-waves`) permitem demos web idênticas ao app.

### Gaps
- Não foi possível confirmar se `VoiceGlowKit`/`VoiceRingKit` já foram testados em macOS (as páginas falam de iPhone; o manifesto declara macOS 14). Precisa de teste local.
- Não há visualizador de **waveform/espectro métrico** em libraries.dev; nada sobre EQ.
- Termos completos do plano Pro para uso em apps open source não foram lidos ([terms.html](https://libraries.dev/terms.html) não consultado).

---

## 2. Bencho (bencho.dev — Lorenzo Cabra)

### Takeaway
Biblioteca de **181 "blocks"** React de micro‑interações; **48 blocos free são MIT** em repositório público e instaláveis via **shadcn registry**; o resto exige Pro (€ 99/ano). Excelente **referência de motion/interação** (dynamic island, now playing, sliders "físicos", liquid toggle) para portar padrões ao SwiftUI e para o site.

### Cited Findings
- Bencho é "a library of interactive React UI components and micro-interactions"; 181 blocos; "Free blocks are MIT licensed; Bencho Pro unlocks the source of every block and an MCP server"; inclui também **Sounds** (sons sintetizados de interface), **Finds** (galeria curada) e **Bench** (canvas para afinar blocos lado a lado); feito por **Lorenzo Cabra** — [bencho.dev/about](https://bencho.dev/about), ac. 2026-11-21.
- Pricing: Free (seleção de Blocks e Sounds); **Pro € 99/ano** (todos os blocos e sons, source completo, MCP); **Forever** pagamento único (valor não exibido) — [bencho.dev/pricing](https://bencho.dev/pricing), ac. 2026-11-21.
- Repositório dos blocos free: **MIT (Copyright (c) 2026 Lorenzo Cabra)**, último push 2026-11-18; README: "**48 blocks and 24 sounds**, free and MIT licensed" (a descrição curta do repo diz "41 free… blocks" — divergência; a pasta `blocks/` lista 48) — [GitHub cabralorenzo/bencho](https://github.com/cabralorenzo/bencho), ac. 2026-11-21.
- Instalação: "Every block is in Bencho's shadcn registry" — `npx shadcn@latest add https://bencho.dev/r/<bloco>.json`; cores com prefixo `--bencho-` para não colidir com o tema; dark mode segue `.dark`/`data-theme="dark"`; manual: copiar a pasta e `npm install framer-motion lucide-react`, importar `tokens.css` — [README cabralorenzo/bencho](https://github.com/cabralorenzo/bencho), ac. 2026-11-21.
- Stack do repo: `react ^19.2.8`, `framer-motion ^13.1.1`, `three ^0.169.0`, `typescript ~6.0.2`, `vite ^8.2.0`; CSS próprio por bloco (não há Tailwind no package.json) — [package.json](https://github.com/cabralorenzo/bencho/blob/main/package.json), ac. 2026-11-21.
- Blocos **free** relevantes (pasta `blocks/`): `dynamic-island` ("A live timer in a black pill: press it to grow into the full activity, and back again"), `sound` = **Now playing** ("A now-playing bar that opens into a full player and folds back as one"), `liq-toggle` (**Liquid toggle**, gota que estica ao deslizar), `slosh` (**Slosh slider**, preenchimento com "peso" que passa do handle), `wake-slider` (range de barras finas sem thumb, com "esteira"), `time-scrubber` (régua com inércia que assenta no passo), `context-meter` (barra empilhada/campo de pontos), `rolling-counter` (dígitos tipo odômetro), `dock`, `toast-stack`, `seek` (busca), `stacked-bars`, `palette`, `glass-bubble`, `voice-note`, `step-player` — [GitHub cabralorenzo/bencho/blocks](https://github.com/cabralorenzo/bencho/tree/main/blocks), ac. 2026-11-21.
- Blocos **Pro** (só no site) relevantes: Range dial (`/blocks/sleep`), Wheel (`/blocks/humidity`), Score gauge (`/blocks/gauge`), Arc ring (`/blocks/expenses`), Heart rate (`/blocks/heart-rate`), Wave loader, Audio trim (`/blocks/wave-trim`), Music island (`/blocks/music-island`), Call island, Command bar (`/blocks/command`), Jelly tabs, Tab bar, Icon bar, Range (`/blocks/range`), Magnifying dock — [bencho.dev](https://bencho.dev/), ac. 2026-11-21.

### Inferences
- Para o app nativo, Bencho vale como **especificação de comportamento** (curvas de mola, "peso" do slider, morph pill→player) a ser reimplementada em SwiftUI (`spring`, `matchedGeometryEffect`, `PhaseAnimator`) — não há port Swift.
- `dynamic-island` + `sound` (free, MIT) são protótipos web quase prontos para o **playground do design system** e para a **landing** demonstrar o morph do notch.
- `rolling-counter` é boa referência para leitura numérica de volume/dB com dígitos que rolam (no SwiftUI: `.contentTransition(.numericText())`).
- Blocos Pro (Range dial, Score gauge, Arc ring) são as referências mais próximas de **knob/medidor radial**, mas o código não é livre — usar só como inspiração visual.

### Gaps
- A página [bencho.dev/licence](https://bencho.dev/licence) não renderizou o texto dos termos (conteúdo via JS); termos da licença **Pro** (redistribuição em projeto open source) não confirmados.
- Sounds: só confirmado que existem 24 sons free em `sounds/sounds.ts`; licença dos sons segue o MIT do repo (não verificado individualmente; há um `THIRD_PARTY.md` não lido).

---

## 3. Spell UI (spell.sh — xxtomm)

### Takeaway
Coleção MIT de **33 componentes** React/Tailwind v4/Motion distribuídos por **registry shadcn (`@spell/...`)**, com foco em polimento de texto/botões/fundos; para nós, útil quase só no **site/docs** (Chart de linha minimalista, Kbd, Badge, Shimmer/Blur text, Light Rays). Não tem sliders, knobs, meters nem toggles.

### Cited Findings
- 33 componentes por categoria — General: Chart, Perspective Book, Badge, Keyboard Shortcuts (`kbd`), Marquee, Tweet, Spotify Card, Logos Carousel, QR Code, Fallback Avatar; Text Animations: Blur Reveal, Special Text, Shimmer Text, Highlighted Text, Slide Up Text, Text Marquee, Words Stagger, Signature, Randomized Text, Gradient Wave Text; Buttons: Rich Button, Flow Button, Copy Button, Pop Button; Inputs: Color Selector, Label Input, Animated Checkbox, Exploding Input; Feedback: Spinner, Bars Spinner; Backgrounds: Light Rays, Animated Gradient (WebGL); Interactive: Tilt Card — [spell.sh/docs/components](https://spell.sh/docs/components), ac. 2026-11-21.
- Licença **MIT**; ~1.379 estrelas; último push 2026-10-10; tópicos React, Next.js, Tailwind CSS, TypeScript, shadcn-ui, motion; contém `registry.json`/`components.json` — [GitHub xxtomm/spell-ui](https://github.com/xxtomm/spell-ui), ac. 2026-11-21.
- Stack (package.json): `next 16.0.10`, `react 19.1.2`, `tailwindcss ^4`, `motion ^12.23.12`, `three ^0.181.2` — [package.json](https://github.com/xxtomm/spell-ui/blob/main/package.json), ac. 2026-11-21.
- **Chart**: "Interactive line chart with a cursor-tracked tooltip card, snap-to-point hover, and built-in X-axis labels"; instalação `pnpm dlx shadcn@latest add @spell/chart` (registry item `https://spell.sh/r/chart.json`); props `data: number[]`, `labels`, `color` (default `#0090FD`), `width`, `formatValue`, `tickCount`, `reveal`, `showFill`, `showDot`, `animated`… — [spell.sh/docs/chart](https://spell.sh/docs/chart), ac. 2026-11-21.
- O `chart.tsx` importa só `react` e `cn` e desenha em **SVG puro** (`<svg>`, `<path>`), sem Recharts — [registry/spell-ui/chart.tsx](https://github.com/xxtomm/spell-ui/blob/main/registry/spell-ui/chart.tsx), ac. 2026-11-21.
- A lista pedida (sliders, knobs, waveform, meters, toggles, segmented controls, command palette, toasts, sheets, dynamic island, number tickers) **não aparece** no catálogo — [spell.sh/docs/components](https://spell.sh/docs/components), ac. 2026-11-21.

### Inferences
- O `Chart` em SVG puro (sem Recharts) é um bom **modelo de estética mínima** (linha fina + preenchimento cinza + tooltip que segue o cursor) para portar ao SwiftUI `Canvas`/Swift Charts nas telas de histórico (ex.: loudness ao longo do tempo no "observatório").
- `Kbd` para documentar atalhos; `Bars Spinner` é visualmente próximo de um mini‑equalizador "now playing" para estados de carregamento no site.

### Gaps
- Nenhum componente de áudio; não há port nativo. Não foi verificada a acessibilidade dos componentes.

---

## 4. shadcn/ui (ui.shadcn.com) — charts, blocks e componentes base

### Takeaway
shadcn/ui (MIT) é a **base recomendada para o site/docs/playground**: em nov/2026 usa **Recharts 3.8.0**, **Tailwind 4.3**, **Base UI como padrão** (desde jul/2026), Motion 12, Sonner, Vaul e cmdk. O sistema de charts (70 variantes) traz o padrão de **ChartConfig + CSS variables (`--chart-N`, `--color-KEY`)** que vale replicar como tokens no SwiftUI.

### Cited Findings
- "The `chart` component now uses Recharts v3"; `ChartContainer` recebe `config` e precisa de `min-h-[VALUE]` para ser responsivo; `ChartConfig` separa labels/ícones/cores dos dados, com `color` ou `theme: { light, dark }`; `<ChartTooltip content={<ChartTooltipContent />} />` com props `labelKey`, `nameKey`, `indicator` (`dot`/`line`/`dashed`), `hideLabel`, `hideIndicator`; `<ChartLegend content={<ChartLegendContent />} />` com `nameKey`; cores via `--chart-1`, `--chart-2` em `:root`/`.dark` em `oklch(...)` e referência nas séries como `var(--color-KEY)`; `accessibilityLayer` adiciona navegação por teclado e leitor de tela; instalação `pnpm dlx shadcn@latest add chart` — [ui.shadcn.com/docs/components/chart](https://ui.shadcn.com/docs/components/chart), ac. 2026-11-21.
- Dependências do site v4 (package.json): `recharts 3.8.0`, `@base-ui/react 1.6.0`, `radix-ui ^1.4.3`, `tailwindcss ^4.3.0`, `motion ^12.12.1`, `next 16.4.5`, `react 19.2.3`, `sonner ^2.0.0`, `vaul 1.1.2`, `cmdk ^1.1.1` — [apps/v4/package.json](https://github.com/shadcn-ui/ui/blob/main/apps/v4/package.json), ac. 2026-11-21.
- Repositório: MIT, ~128.655 estrelas, push 2026-11-20 — [GitHub shadcn-ui/ui](https://github.com/shadcn-ui/ui), ac. 2026-11-21. Recharts: MIT, ~27.726 estrelas — [GitHub recharts/recharts](https://github.com/recharts/recharts), ac. 2026-11-21.
- Changelog 2026 (seleção): "Base UI as the Default" (jul/2026), "Toast" (jul/2026), "React Aria" (jul/2026), "shadcn/cli v4" (mar/2026), "Blocks for Radix and Base UI" (fev/2026), "shadcn preset"/"shadcn apply" (abr/2026), "shadcn eject" (mai/2026), "GitHub Registries" (jun/2026), "Private GitHub Registries" (ago/2026), "Trace, Code Block and AI Elements" (out/2026); "npx shadcn create" (dez/2025); "Tailwind v4" (fev/2025) — [ui.shadcn.com/docs/changelog](https://ui.shadcn.com/docs/changelog), ac. 2026-11-21.
- Galeria de charts em 7 categorias (Area, Bar, Line, Pie, Radar, Radial, Tooltip), "built with Recharts" — [ui.shadcn.com/charts](https://ui.shadcn.com/charts), ac. 2026-11-21.
- Variantes no registry (`apps/v4/registry/new-york-v4/charts`), 70 no total: **Area (10)** axes, default, gradient, icons, interactive, legend, linear, stacked, stacked-expand, step; **Bar (10)** active, default, horizontal, interactive, label, label-custom, mixed, multiple, negative, stacked; **Line (10)** default, dots, dots-colors, dots-custom, interactive, label, label-custom, linear, multiple, step; **Pie (11)**; **Radar (14)**; **Radial (6)** grid, label, shape, simple, stacked, text; **Tooltip (9)** default, advanced, formatter, icons, indicator-line, indicator-none, label-custom, label-formatter, label-none — [árvore do repo shadcn-ui/ui](https://github.com/shadcn-ui/ui/tree/main/apps/v4/registry/new-york-v4/charts), ac. 2026-11-21.
- Componentes UI (62 arquivos em `new-york-v4/ui`) incluem os que mapeiam para nós: `slider`, `switch`, `toggle`, `toggle-group` (segmented), `tabs`, `command` (palette, via cmdk), `sonner` (toasts), `sheet`, `drawer` (Vaul), `popover`, `hover-card`, `tooltip`, `progress`, `kbd`, `chart`, `button-group`, `empty`, `item`, `field`, `spinner`, `resizable`, `scroll-area` — [árvore do repo shadcn-ui/ui](https://github.com/shadcn-ui/ui/tree/main/apps/v4/registry/new-york-v4/ui), ac. 2026-11-21.
- Recharts `XAxis` aceita `scale="log"` ("a string shortcut to a d3 scale"), `domain`, `allowDataOverflow` (recorta ao domínio) e `ticks` numéricos — [Recharts API XAxis](https://recharts.github.io/en-US/api/XAxis/), ac. 2026-11-21.

### Inferences
- **Curva de EQ no site**: `chart-area-gradient`/`chart-line-linear` + `XAxis type="number" scale="log" domain={[20, 20000]} ticks={[20,50,100,200,500,1000,2000,5000,10000,20000]}` + `allowDataOverflow` reproduz a convenção pro‑audio; `chart-tooltip-indicator-line` dá o tooltip "frequência/ganho". Para **handles arrastáveis** e curva composta, DSSSP (seção 7) é mais adequado que Recharts.
- **Medidores radiais**: `chart-radial-text`/`chart-radial-shape`/`chart-radial-stacked` servem como base visual para um "gauge" de LUFS no site; no app, desenhar em `Canvas`.
- **Tokens**: copiar a ideia de `ChartConfig` (chave semântica → cor light/dark) para um `enum ChartToken` em SwiftUI (`Color` com variantes por `colorScheme`), mantendo nomes idênticos aos do site (`--chart-1…`, `--color-lufs-momentary` etc.) para que docs e app compartilhem a mesma fonte de verdade.
- **Playground do design system**: shadcn `create`/registry próprio permite publicar nossos componentes web (curva de EQ, meter) como registry — consistente com Bencho e Spell que já distribuem via registry.
- Em tempo real (60 Hz) Recharts tende a ser caro; no site desativar animação/limitar pontos ou usar Canvas próprio para o espectro.

### Gaps
- Não consegui listar os títulos visíveis das variantes pela página (renderização client-side); usei os nomes dos arquivos do registry.
- O conteúdo do item "Toast" (jul/2026) não foi lido — não sei se substitui ou complementa o `sonner`.
- Não verifiquei a página `/blocks` (dashboards/sidebars) em detalhe.

---

## 5. Linguagem de design Apple (macOS 26 Tahoe → macOS 27 "Golden Gate", nov/2026)

### Takeaway
A base é **Liquid Glass para a camada de controles/navegação** (nunca no conteúdo), materiais padrão + vibrancy no conteúdo, **SF Pro/SF Mono** via APIs do sistema, SF Symbols com **variable color** (ideal para nível de áudio). Em out/2026 a Apple lançou o **MacBook Pro OLED com Dynamic Island** e o **macOS 27.3 beta** abriu **Live Activities nativas no Mac** (menu bar em Macs sem Dynamic Island) — isso muda a estratégia "notch" do produto.

### Cited Findings
**Materiais / Liquid Glass**
- "Liquid Glass forms a distinct functional layer for controls and navigation elements… that floats above the content layer"; "**Don't use Liquid Glass in the content layer**… An exception… controls in the content layer with a transient interactive element like **sliders and toggles**; in these cases, the element takes on a Liquid Glass appearance… when a person activates it"; "Use Liquid Glass effects sparingly"; variantes **regular** (desfoca e ajusta luminosidade; usar em popovers/alertas/sidebars) e **clear** (só sobre fundos visualmente ricos, avaliar camada de escurecimento) — [HIG Materials](https://developer.apple.com/design/human-interface-guidelines/materials), ac. 2026-11-21 (changelog: atualizado 9 set 2025).
- macOS: "several standard materials with designated purposes, and vibrant versions of all system colors"; modos de blending **behind window** e **within window**; "use vibrant colors on top of materials" — [HIG Materials](https://developer.apple.com/design/human-interface-guidelines/materials), ac. 2026-11-21.
- APIs: `glassEffect(_:in:)` "Applies the Liquid Glass effect to a view" e `GlassEffectContainer` "combines multiple Liquid Glass shapes into a single shape that can morph" — ambos macOS 26.0+ — [glassEffect](https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:)), [GlassEffectContainer](https://developer.apple.com/documentation/swiftui/glasseffectcontainer), ac. 2026-11-21. `NSVisualEffectView` (macOS 10.10+) "adds translucency and vibrancy effects" — [NSVisualEffectView](https://developer.apple.com/documentation/appkit/nsvisualeffectview), ac. 2026-11-21.
- WWDC 2026 / ciclo 27: slider de transparência do Liquid Glass "from ultra clear to fully tinted"; glass "more effectively diffuses complex content", borda escurecida e highlights especulares mais brilhantes; respeita Reduce Transparency/Increase Contrast; macOS 27 com "further sidebar refinements and window corner radius updates" — [MacRumors, 10 jun 2026](https://www.macrumors.com/2026/06/10/how-liquid-glass-is-changing-in-ios-27/), ac. 2026-11-21. Página oficial: "New platform design refinements improve consistency, readability, and accessibility" — [WWDC26 Design guide](https://developer.apple.com/wwdc26/guides/design/), ac. 2026-11-21.

**Menu bar extras e popovers**
- "Consider using a symbol to represent your menu bar extra… icons and symbols use black and clear colors… the system can apply other colors"; "**The menu bar's height is 24 pt**"; "**Display a menu — not a popover** — when people click your menu bar extra. Unless the app functionality… is too complex for a menu"; "Let people — not your app — decide whether to put your menu bar extra in the menu bar"; "Avoid relying on the presence of menu bar extras" (o sistema oculta extras quando falta espaço) — [HIG The menu bar](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar), ac. 2026-11-21.
- Popovers: "expose a small amount of information or functionality"; "Show one popover at a time"; "Provide a smooth transition when changing the size of a popover"; no macOS, "Consider letting people detach a popover" (vira painel) com "minimal appearance changes" — [HIG Popovers](https://developer.apple.com/design/human-interface-guidelines/popovers), ac. 2026-11-21.
- `MenuBarExtra`: "A scene that renders itself as a persistent control in the system menu bar", macOS 13.0+ — [MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra), ac. 2026-11-21.

**SF Symbols**
- Quatro rendering modes (monochrome, hierarchical, palette, multicolor); **SF Symbols 7** adicionou "Draw animations and gradient rendering" (gradiente linear a partir de uma cor) — [HIG SF Symbols](https://developer.apple.com/design/human-interface-guidelines/sf-symbols), ac. 2026-11-21 (changelog 28 jul 2025).
- **Variable color**: "represent a characteristic that can change over time — like capacity or strength"; exemplo oficial com `speaker.wave.3` mapeando camadas a faixas de decibéis; "Use variable color to communicate change — don't use it to communicate depth" — [HIG SF Symbols](https://developer.apple.com/design/human-interface-guidelines/sf-symbols), ac. 2026-11-21.
- **SF Symbols 8** (WWDC26): "over 7,000 symbols", nove pesos e três escalas, alinhamento automático com texto — [WWDC26 Design guide](https://developer.apple.com/wwdc26/guides/design/), ac. 2026-11-21.

**Tipografia**
- Família San Francisco inclui SF Pro, SF Compact, **SF Mono** etc.; fontes variáveis com "dynamic optical sizes"; "don't embed system fonts in your app"; "SF Pro is the system font in macOS"; "macOS doesn't support Dynamic Type" — [HIG Typography](https://developer.apple.com/design/human-interface-guidelines/typography), ac. 2026-11-21.
- Tamanho padrão macOS **13 pt**, mínimo **10 pt**; estilos macOS: Large Title 26/32, Title 1 22/26, Title 2 17/22, Title 3 15/20, Headline 13 Bold, Body 13/16, Callout 12/15, Subheadline 11/14, Footnote 10/13, Caption 1/2 10/13 — [HIG Typography](https://developer.apple.com/design/human-interface-guidelines/typography), ac. 2026-11-21.

**Charts (HIG)**
- "Keep a chart simple, letting people choose when they want additional details"; "Make every chart in your app accessible"; "Prefer consistency across multiple charts"; "Maintain continuity among multiple charts that use the same data" — [HIG Charting data](https://developer.apple.com/design/human-interface-guidelines/charting-data), ac. 2026-11-21.

**Dynamic Island no Mac (MacBook Pro OLED, 28 out 2026)**
- Apple levou o Dynamic Island ao Mac nos novos MacBook Pro 14"/16" touchscreen, "bringing Live Activities, Spotlight, and Siri AI together in an interactive area of the display"; permite "control music playback"; "actions such as pausing a song can also simply be performed with a tap"; pré‑venda 28 out, lançamento 6 nov 2026; a partir de US$ 2.899 (14") / US$ 3.399 (16") — [MacRumors, 28 out 2026](https://macrumors.com/2026/10/28/apple-brings-dynamic-island-to-mac/), ac. 2026-11-21.
- Nome do painel **"PROLED XDR"** e nomenclatura do chip divergem entre veículos (M5 Pro/Max vs. "M6") — [Macworld](https://macworld.com/article/3271736/top-features-new-apple-macbook-pro-with-proled-xdr-display.html); [Tom's Guide](https://www.tomsguide.com/computing/macbooks/apple-reveals-oled-touchscreen-macbook-pro), ac. 2026-11-21.

**Live Activities no Mac (macOS 27.3 beta)**
- macOS 27.3 (1º beta na semana de 4 nov 2026, final esperada em dezembro) traz Live Activities **na menu bar** para Music, Clock e Voice Memos em outros Macs Apple silicon; "**Third-party Mac apps can also implement Live Activities support now**"; antes (macOS 26) só havia atividades espelhadas do iPhone — [MacRumors, 4 nov 2026](https://www.macrumors.com/2026/11/04/macos-27-3-live-activities-in-menu-bar/), ac. 2026-11-21.
- Relatos secundários citam ActivityKit no macOS 27.3 e um único `ActivityConfiguration` cobrindo menu bar e regiões do Dynamic Island; há divergência sobre ser beta 1 ou 2 — resumo de [Macworld](https://macworld.com/article/3277220/you-dont-need-a-3000-macbook-to-get-live-activities-in-your-menu-bar.html) e [9to5Mac](https://9to5mac.com/?p=1078006), ac. 2026-11-21 (não verificado em documentação Apple).
- HIG Live Activities (changelog **13 out 2026**: "Added guidance for limited width layouts"): apresentações **compact** (leading/trailing), **minimal**, **expanded**; "adapt your compact and minimal presentations to fit inside a **28pt-diameter circle**" para largura limitada; "Live Activities in the Dynamic Island use a **black opaque background**"; "Consider using bold colors"; "Tint your Live Activity's key line color"; "Don't draw content all the way to the edge of the Dynamic Island"; "**Don't add elements to your app that draw attention to the Dynamic Island**"; ao terminar, na menu bar do Mac a atividade permanece até 4 h — [HIG Live Activities](https://developer.apple.com/design/human-interface-guidelines/live-activities), ac. 2026-11-21.
- Conflito: a seção "macOS" da mesma página HIG ainda diz que Live Activities aparecem na menu bar de um Mac pareado e que clicar "launches iPhone Mirroring" — ou seja, **não reflete o macOS 27.3 beta** — [HIG Live Activities](https://developer.apple.com/design/human-interface-guidelines/live-activities), ac. 2026-11-21; contrastado por [MacRumors](https://www.macrumors.com/2026/11/04/macos-27-3-live-activities-in-menu-bar/).

### Inferences
- **Estratégia de superfícies**: (a) Macs com notch → overlay próprio (NSPanel) em volta do notch; (b) MacBook Pro OLED com Dynamic Island → evitar desenhar sobre/ao redor da ilha (HIG proíbe chamar atenção para ela) e oferecer **Live Activity via ActivityKit** (now playing/medidor compacto); (c) qualquer Mac no 27.3+ → Live Activity na menu bar + `MenuBarExtra` com **menu** (não popover) para ações simples, e janela/painel destacável para o "observatório".
- Paleta: o "preto opaco" exigido pelo Dynamic Island coincide com a direção de arte (pílula preta, contraste branco). Reservar cor saturada apenas para dados (curva de EQ, zonas de medidor) e para a key line.
- Sliders/toggles do mixer podem ganhar Liquid Glass **só durante a interação** (regra da HIG) — usar controles do sistema sempre que possível para herdar isso.
- Volume por app em SF Symbols: `speaker.wave.3` com `variableValue` é a forma nativa de um "mini‑meter" em listas/menu.
- Valores numéricos (dB, Hz, LUFS) em **SF Mono** ou SF Pro com dígitos tabulares (`.monospacedDigit()`) para não "dançar".

### Gaps
- Não há (ainda) página HIG específica do **Dynamic Island no Mac** nem dimensões em pt para Live Activities no macOS (a tabela de especificações só lista CarPlay, iOS, iPadOS, watchOS).
- Documentação oficial do ActivityKit para macOS 27.3 não foi verificada diretamente.
- Não confirmei se apps de terceiros podem desenhar no entorno da câmera do MacBook OLED (equivalente ao truque do notch).
- Detalhes macOS‑específicos de SF Symbols 8 (novas animações) não encontrados.

---

## 6. Convenções de UI pro‑audio (EQ e medição)

### Takeaway
O padrão‑ouro de EQ é o **FabFilter Pro‑Q 4**: analisador em tempo real atrás da curva, faixas de display de ganho **3/6 dB (mastering) e 12/30 dB (mixing)**, Spectrum Grab, Piano Display, EQ Sketch e UI GPU redimensionável. Para medidores, **EBU Tech 3341 (V4, nov/2023)** define M = 0,4 s, S = 3 s, I com gating, escalas EBU +9/+18 e alvo −23 LUFS; balísticas PPM/VU variam por norma e devem ser selecionáveis.

### Cited Findings
**EQ (FabFilter Pro‑Q 4, lançado 12 dez 2024)**
- "Powerful real-time spectrum analyzer with separate mastering (3/6dB) and mixing (12/30dB) display ranges"; "Piano Display switches the frequency scale to musical note values"; Spectrum Grab para "grab and adjust filters directly in the spectrum analyzer"; EQ Sketch: "drag the mouse across the main display to instantiate a series of filters set up to match the curve you draw"; Instance List "zoomable from a rack of miniaturized spectrum displays all the way up to fully interactive displays"; "Fresh new design, with resizable GPU-accelerated graphical interface and full-screen mode"; edição de parâmetros arrastando/rolando no próprio valor — [FabFilter News](https://www.fabfilter.com/news/1733994000/fabfilter-releases-pro-q-4-equalizer-plug-in), ac. 2026-11-21.
- Esquema de cores mais escuro que o Pro‑Q 3; passar o mouse na linha central mostra um "blob" que vira banda ao clicar — [Sound On Sound review](https://www.soundonsound.com/reviews/fabfilter-pro-q-4?amp), ac. 2026-11-21 (via resumo de busca). Até 24 bandas; Spectrum Grab marca os picos mais importantes — [KVR Audio](https://www.kvraudio.com/news/fabfilter-releases-pro-q-4-equalizer-plugin-62490); [Plugin Boutique](https://www.pluginboutique.com/products/14125-FabFilter-Pro-Q-4), ac. 2026-11-21 (via resumo de busca).

**Loudness (EBU R128 / Tech 3341)**
- Tech 3341 V4, Genebra, **novembro 2023** (V2 2011 mudou o gate relativo de −8 para −10 LU; V3 2016) — [EBU Tech 3341](https://tech.ebu.ch/docs/tech/tech3341.pdf), ac. 2026-11-21.
- "Momentary Loudness uses a sliding rectangular time window of length **0.4 s**… not gated"; "Short-term Loudness… **3 s**… not gated. The update rate for 'live meters' shall be **at least 10 Hz**"; Integrated com gating BS.1770, atualização ≥ 1 Hz; gate absoluto **−70 LUFS**, relativo **10 LU** abaixo; blocos de 400 ms com 75 % de sobreposição; "Further slowdown of the attack or release… shall not be employed in 'EBU Mode'" — [EBU Tech 3341](https://tech.ebu.ch/docs/tech/tech3341.pdf), ac. 2026-11-21.
- Escalas: "**EBU +9 scale**" −18 a +9 LU (−41 a −14 LUFS), **padrão**; "**EBU +18 scale**" −36 a +18 LU (−59 a −5 LUFS); alvo "−23.0 LUFS = 0.0 LU"; o medidor deve oferecer escala absoluta (LUFS) e relativa (LU) com a posição do alvo fixa; "**at most 1 decimal place**"; a unidade "shall be displayed for all values and scales, at all times"; mínimo: Programme Loudness, **LRA** e **Maximum True Peak Level** — [EBU Tech 3341](https://tech.ebu.ch/docs/tech/tech3341.pdf), ac. 2026-11-21.
- "**The physical properties of the loudness meter, such as size, colours, and design, are not part of the 'EBU Mode' specification**"; LRA em LU (1 LU = 1 dB) deve indicar instabilidade nos primeiros 60 s — [EBU Tech 3341](https://tech.ebu.ch/docs/tech/tech3341.pdf), ac. 2026-11-21.

**Balísticas PPM/VU**
- Tabela de presets (FLUX:: Analyzer): **VU** 300 ms de integração, escala −20 a +3 VU, 0 VU = −18 dBFS (IEC 60268‑17); **DIN 45406** 10 ms (90 %), retorno 1,7 s/20 dB, −50 a +5 dB, ref −9 dBFS; **Nordic N9** 5 ms (80 %), 1,7 s/20 dB, −40 a +9 dB, ref −18 dBFS (IEC 60268‑10/1); **BBC Normal** 10 ms (80 %), 2,8 s/24 dB (IEC 60268‑10/2a); **EBU Normal** 10 ms (80 %), 2,8 s/24 dB, −12 a +12 dB, ref −18 dBFS (IEC 60268‑10/2b); **K‑System/VU** 300 ms, release 66,7 dB/s, peak release 12 dB/s — [FLUX:: RMS metering](https://doc.flux.audio/analyzer/Metering_RMS.html), ac. 2026-11-21.
- VU: rise de 300 ms (99 % de 0 VU), overshoot 1–1,5 %, fall igual ao rise — [Wikipedia: VU meter](https://www.wikipedia.org/wiki/VU_meter), ac. 2026-11-21 (via resumo de busca). PPM: Sound On Sound descreve fall‑back "over 1.5 seconds to fall back 20dB (the specifications vary slightly for Type I and II meters)" — [Sound On Sound Q&A](https://www.soundonsound.com/sound-advice/q-whats-difference-between-ppm-and-vu-meters), ac. 2026-11-21 (via resumo de busca). Há **conflito** entre fontes sobre tempos de integração por Tipo (I = 4 ms vs. 10 ms) — mesmas fontes.
- IEC 60268‑18 é um **Technical Report de 1995** sobre indicador de pico digital (cláusulas de delay time e return time); texto integral é pago — [IEC webstore](https://webstore.iec.ch/publication/1217); [VDE preview](https://vde-verlag.de/iec-normen/preview-pdf/info_iectr60268-18{ed1.0}b.img.pdf), ac. 2026-11-21.

### Inferences
- **Display de EQ** (spec proposta): eixo X **logarítmico 20 Hz–20 kHz** com grid em 20/50/100/200/500/1k/2k/5k/10k/20k (labels "1k", "10k"); eixo Y com faixas comutáveis ±3/±6/±12/±30 dB (espelhando Pro‑Q); espectro pós‑EQ atrás da curva em cinza translúcido, curva composta em branco 1,5–2 pt, curvas por banda em cor da banda com baixa opacidade, handles circulares numerados; opção "Piano Display".
- **Medidores**: oferecer modos selecionáveis (Digital Peak + True Peak, VU, PPM EBU/Nordic, EBU R128 M/S/I + LRA) e exibir sempre a unidade; ponteiros/barras sem suavização extra no modo EBU; atualização visual a 60/120 Hz mas cálculo conforme norma.
- **Cor**: como a EBU não normatiza cores, usar a convenção de mercado verde/amarelo/vermelho apenas como zonas relativas ao alvo (ex.: abaixo de −1 dBTP / acima), mantendo a estética monocromática fora das zonas de alerta. (Convenção amplamente usada, mas sem fonte normativa — ver Gaps.)

### Gaps
- Não obtive o manual online do Pro‑Q 4 (URLs de help retornaram 404) — faltam detalhes de resolução/velocidade/tilt do analisador e cores exatas.
- Valores normativos de IEC 60268‑10/‑17/‑18 não acessíveis (pagos); balísticas acima vêm de implementação comercial (FLUX) e de fontes secundárias.
- Sem fonte primária para a convenção de cores verde/amarelo/vermelho em medidores nem para o limite −1 dBTP do R128 (não extraído da Tech 3341; está no R 128 propriamente dito, não lido).
- Faixa de audição 20 Hz–20 kHz como convenção de eixo: não citada de fonte primária nesta rodada.

---

## 7. Implementação SwiftUI/AppKit de visuais em tempo real e bibliotecas OSS

### Takeaway
**Swift Charts** serve para gráficos estáticos/históricos e para a **curva de EQ como função** (`LinePlot`/`AreaPlot` de função, WWDC24), mas não para espectro a 60 fps; para tempo real usar **`Canvas` + `TimelineView`** (ou Metal/`MTKView` quando houver muitos pontos). Bibliotecas OSS úteis: **AudioKitUI** (MIT, inclui visualizações Metal), **AudioKit Controls** (MIT, knobs/sliders — parado desde 2024), **AudioKit Waveform** (MIT, GPU). Não achei editor de curva de EQ em SwiftUI open source; a melhor referência de interação é **DSSSP** (React, MIT).

### Cited Findings
- Swift Charts com muitos pontos: relatos de lentidão até inutilizável perto de 500K pontos, uso de downsampling LTTB fora da main thread; LineMark em atualização real‑time lento; saturação de CPU em plot real‑time via Bluetooth — [Apple Forums 740314](https://developer.apple.com/forums/thread/740314); [728636](https://developer.apple.com/forums/thread/728636); [745167](https://developer.apple.com/forums/thread/745167), ac. 2026-11-21 (via resumo de busca).
- WWDC24 "Swift Charts: Vectorized and function plots": `LinePlot(x:y:) { x in … }` plota uma **função matemática** inteira; `AreaPlot` entre curvas; `domain:` limita amostragem; retornar `.nan` para indefinidos; plots vetorizados (`PointPlot`, `RectanglePlot`…) para datasets grandes; "Use Vectorized Plots for larger datasets where the entire plot is customized with the same modifiers"; usar propriedades armazenadas e especificar bounds conhecidos melhora desempenho — [WWDC24 sessão 10155](https://developer.apple.com/videos/play/wwdc2024/10155/), ac. 2026-11-21.
- `Canvas` (macOS 12+): "immediate mode drawing"; "A canvas doesn't offer interactivity or accessibility for individual elements… However, it might provide better performance for a complex drawing that involves dynamic data" — [SwiftUI Canvas](https://developer.apple.com/documentation/swiftui/canvas), ac. 2026-11-21. `TimelineView` (macOS 12+): "A view that updates according to a schedule that you provide" — [SwiftUI TimelineView](https://developer.apple.com/documentation/swiftui/timelineview), ac. 2026-11-21.
- **AudioKitUI**: "Controls and Visualization for AudioKit apps", **MIT**, iOS 13+/macOS 10.15+, push 2026-04-15; pasta `Visualizations` contém `FFTView`, `NodeFFTView`, `NodeOutputView`, `NodeRollingView`, `AmplitudeView`, `RawOutputView`, `SpectrogramView`, `SpectrogramFlatView`, `SpectrumView`, `AudioWaveform`, `MetalView` + `shaders.metal` — [GitHub AudioKit/AudioKitUI](https://github.com/AudioKit/AudioKitUI), ac. 2026-11-21.
- **AudioKit Controls**: "SwiftUI Knobs, Sliders, X-Y Pads, and more", **MIT**; componentes `ArcKnob`, `SmallKnob`, `IndexedSlider`, `Ribbon`, `PitchModWheel`, `XYPad`, `Joystick`; recomenda fixar versão porque a API muda; **último push 2024-09-12** — [GitHub AudioKit/Controls](https://github.com/AudioKit/Controls), ac. 2026-11-21.
- **AudioKit Waveform**: "GPU accelerated waveform view", MIT, push 2026-06-26; **AudioKit Keyboard** (SwiftUI), MIT — [GitHub AudioKit/Waveform](https://github.com/AudioKit/Waveform); [AudioKit/Keyboard](https://github.com/AudioKit/Keyboard), ac. 2026-11-21.
- **DSSSP**: "React Library for Audio Equalizers & Filter Visualization", **MIT**, push 2026-08-12; gráfico de frequência logarítmico, filtros biquad arrastáveis (edição de ganho, frequência, Q), curva composta, render **SVG**, `npm i dsssp` — [GitHub NumberOneBot/dsssp](https://github.com/NumberOneBot/dsssp); [dsssp.io](https://dsssp.io/), ac. 2026-11-21.
- Apps macOS de EQ open source (referência de UX/arquitetura): **eqMac** (Apache‑2.0, ~6.836 estrelas) — a UI é **web (Angular + TypeScript) hospedada remotamente** dentro do app, permitindo OTA; o repo corresponde à v1.3.2 sem Pro — [GitHub bitgapp/eqMac](https://github.com/bitgapp/eqMac), ac. 2026-11-21. **SoundMaxx** (MIT, EQ paramétrico 10 bandas) e **SoundMax** (MIT, perfis por dispositivo, AutoEQ) — [brimell/SoundMaxx](https://github.com/brimell/SoundMaxx); [snap-sites/SoundMax](https://github.com/snap-sites/SoundMax), ac. 2026-11-21. **Radioform** (GPL‑3.0) e **SystemEQ‑for‑Mac** (GPL‑3.0, com visualizador e AutoEQ) — [Torteous44/radioform](https://github.com/Torteous44/radioform); [denzam/SystemEQ-for-Mac](https://github.com/denzam/SystemEQ-for-Mac), ac. 2026-11-21.

### Inferences
- **Arquitetura de render proposta**: áudio → buffer lock‑free → snapshot por frame consumido em `TimelineView(.animation)` → `Canvas` (espectro, meters, curva de EQ com `Path` pré‑computado); handles de banda como **views SwiftUI sobrepostas** (para acessibilidade e gesto), já que `Canvas` não oferece acessibilidade por elemento. Escalar para Metal (padrão `MetalView` do AudioKitUI) se o espectro de alta resolução/espectrograma pesar.
- **Curva de EQ em Swift Charts**: viável para telas não‑real‑time (ex.: comparação de presets, docs geradas), com `LinePlot` de função (magnitude da soma dos biquads) e `.chartXScale(type: .log)`; para a interação principal, `Canvas` dá mais controle.
- **Licenças**: MIT/Apache‑2.0 (AudioKitUI, Controls, Waveform, DSSSP, eqMac, SoundMaxx) são compatíveis com copiar/adaptar código; **evitar copiar** de Radioform/SystemEQ (GPL‑3.0) se o app não for GPL — usar só como referência conceitual.
- AudioKit Controls está parado há ~2 anos → melhor **portar o padrão de gesto** (arrasto vertical/rotativo, fine‑tune com modificador) do que depender do pacote.
- **WebView** é precedente real (eqMac), mas contraria a direção "nativa Apple‑like" e custa memória num app residente; recomendo restringir WebView a no máximo um painel de docs/"sobre", nunca para meters.

### Gaps
- Não encontrei benchmark público de `Canvas`+`TimelineView` vs. Metal para espectros a 120 Hz em ProMotion.
- Não verifiquei se AudioKitUI pode ser usado sem o core AudioKit (dependências não inspecionadas).
- Não encontrei editor de curva de EQ open source em **SwiftUI** com handles arrastáveis.

---

## 8. Síntese — "o que usar para quê" (ranking)

### Takeaway
Ranking por **valor direto para o produto** (app nativo SwiftUI primeiro, depois site/docs/playground). Cada linha remete às citações das seções 1–7.

### Cited Findings
- Ver seções 1–7 (todas as fontes acessadas em 2026‑11‑21).

### Inferences

| # | Necessidade | Usar (recurso / componente) | Onde | Como | Licença | Fonte |
|---|---|---|---|---|---|---|
| 1 | Regras de materiais, menu bar, popover, tipografia, símbolos | Apple HIG (Materials, The menu bar, Popovers, Typography, SF Symbols, Live Activities) | App | Seguir como norma; `glassEffect`, `MenuBarExtra`, `NSVisualEffectView`, `.monospacedDigit()` | — | [HIG](https://developer.apple.com/design/human-interface-guidelines/materials) |
| 2 | Presença no Dynamic Island (MBP OLED) e menu bar (macOS 27.3+) | Live Activity (compact/minimal/expanded; fundo preto opaco; caber em círculo de 28 pt) | App | ActivityKit + WidgetKit; now playing + mini‑meter | — | [HIG Live Activities](https://developer.apple.com/design/human-interface-guidelines/live-activities), [MacRumors](https://www.macrumors.com/2026/11/04/macos-27-3-live-activities-in-menu-bar/) |
| 3 | Spectrum + curva de EQ + meters em tempo real | `Canvas` + `TimelineView` (Metal se necessário), padrões do AudioKitUI (`FFTView`, `SpectrogramView`, `MetalView`) | App | Implementação própria; copiar trechos MIT | MIT | [Canvas](https://developer.apple.com/documentation/swiftui/canvas), [AudioKitUI](https://github.com/AudioKit/AudioKitUI) |
| 4 | Especificação de display de EQ | FabFilter Pro‑Q 4 (faixas 3/6/12/30 dB, Spectrum Grab, Piano Display, Sketch) + DSSSP (interação de handles) | App (spec) / Site (DSSSP) | Portar padrão; DSSSP como protótipo web | DSSSP MIT | [FabFilter](https://www.fabfilter.com/news/1733994000/fabfilter-releases-pro-q-4-equalizer-plug-in), [DSSSP](https://github.com/NumberOneBot/dsssp) |
| 5 | Medidores normativos | EBU Tech 3341 (M 0,4 s, S 3 s, I gated, +9/+18, LRA, TP) + presets PPM/VU (FLUX) | App | Modos selecionáveis; unidade sempre visível | — | [EBU Tech 3341](https://tech.ebu.ch/docs/tech/tech3341.pdf), [FLUX](https://doc.flux.audio/analyzer/Metering_RMS.html) |
| 6 | Efeitos audio‑reativos decorativos no notch (orb, glow de borda, beam) | libraries.dev `VoiceRingKit`, `VoiceGlowKit`, `BorderBeamKit`; `DistortionWavesKit` para transições | App | SwiftPM (fixar commit), alimentar com nível 0–1 | MIT (código) | [libraries.dev](https://libraries.dev/waves), [Package.swift](https://github.com/Jakubantalik/Libraries.dev/blob/main/Package.swift) |
| 7 | Site/docs/playground: charts, tooltip, legend, tokens | shadcn/ui `chart` (Recharts 3.8; `chart-area-gradient`, `chart-line-linear`, `chart-radial-text`, `chart-tooltip-indicator-line`) + `XAxis scale="log"` | Site | `pnpm dlx shadcn@latest add chart`; tokens `--chart-N` espelhados no SwiftUI | MIT | [shadcn chart](https://ui.shadcn.com/docs/components/chart), [Recharts XAxis](https://recharts.github.io/en-US/api/XAxis/) |
| 8 | Site: controles base (slider, switch, segmented, command palette, toasts, sheets) | shadcn/ui `slider`, `switch`, `toggle-group`, `tabs`, `command` (cmdk), `sonner`, `sheet`, `drawer` (Vaul), `kbd` | Site | Base UI padrão desde jul/2026 | MIT | [shadcn repo](https://github.com/shadcn-ui/ui/tree/main/apps/v4/registry/new-york-v4/ui) |
| 9 | Referência de motion: morph pílula→player, sliders "físicos", toggle líquido | Bencho free: `dynamic-island`, `sound` (Now playing), `slosh`, `wake-slider`, `liq-toggle`, `rolling-counter`, `time-scrubber` | Site (código) / App (padrão) | `npx shadcn@latest add https://bencho.dev/r/<bloco>.json`; reimplementar em SwiftUI | MIT (free) | [cabralorenzo/bencho](https://github.com/cabralorenzo/bencho) |
| 10 | Knobs/sliders SwiftUI prontos | AudioKit Controls (`ArcKnob`, `SmallKnob`, `IndexedSlider`, `XYPad`) | App (padrão) | Portar lógica de gesto; pacote parado desde 2024 | MIT | [AudioKit/Controls](https://github.com/AudioKit/Controls) |
| 11 | Gráficos históricos/estáticos e curva de EQ como função | Swift Charts `LinePlot`/`AreaPlot` de função, plots vetorizados | App | Telas não real‑time (presets, histórico de loudness) | — | [WWDC24 10155](https://developer.apple.com/videos/play/wwdc2024/10155/) |
| 12 | Landing: tipografia animada, fundos, atalhos | Spell UI (`chart`, `kbd`, `shimmer-text`, `blur-reveal`, `light-rays`, `bars-spinner`) | Site | `pnpm dlx shadcn@latest add @spell/<item>` | MIT | [spell.sh](https://spell.sh/docs/components) |
| 13 | Referência de arquitetura de EQ/mixer no Mac | eqMac (UI web em WebView, Apache‑2.0), SoundMaxx/SoundMax (MIT) | Pesquisa | Estudar; **não** copiar de projetos GPL (Radioform, SystemEQ) | Apache‑2.0 / MIT | [eqMac](https://github.com/bitgapp/eqMac) |
| 14 | Painel WebView dentro do app | Só para docs/"sobre", se necessário | App (exceção) | Evitar para UI principal/meters | — | Inferência (precedente eqMac) |

### Gaps
- O ranking é julgamento editorial baseado nas fontes acima; não foi validado com protótipo nem medição de desempenho.
