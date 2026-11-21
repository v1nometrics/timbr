# 05 · Assets, Iconografia e Referências Masters

---

## 1. Inventário de Assets do App Nativo

| Categoria | Asset / Fonte | Formato / Origem | Licença | Notas de empacotamento |
|---|---|---|---|---|
| **Tipografia principal** | `Geist-Regular.ttf`, `Geist-Medium.ttf` | Fontes estáticas (Vercel Geist) | SIL OFL 1.1 | Registrar via `ATSApplicationFontsPath` no `Info.plist`; incluir texto da OFL em `LICENSES/` |
| **Tipografia técnica** | `GeistMono-Regular.ttf`, `GeistMono-Medium.ttf` | Fontes estáticas | SIL OFL 1.1 | Usada em todos os eyebrows, eixos, unidades e timestamps |
| **Tipografia editorial** | `GeistSerif-Regular.ttf` | Fonte estática | SIL OFL 1.1 | Usada exclusivamente em letras sincronizadas e citações humanas |
| **Símbolos de interface** | SF Symbols 8 | Sistema (macOS 15–27) | Apple SDK | Preferir `.symbolRenderingMode(.hierarchical)` e `variableValue` |
| **Wordmark oficial (`timbr.`)** | `timbr.` em caixa baixa + `.` (fundo `#141414`/`#191919`, texto `#F2F2F2`, tagline `#8C8C8C`) | Vetorial SVG/PDF + SwiftUI | Própria | Referência visual do `v1torres.dev` (`›v1_`): lowercase + pontuação final; usar em splash, About, Estúdio e site |
| **Ícone do App (`.icns` / Icon Composer)** | Monólito neutro escuro (`#111111`) com glifo geométrico **curva paramétrica + ponto `.`** (e versão alternativa monocromática com acento `#7747FF` contido) | Icon Composer (macOS 26+) + Asset Catalog | Própria | **Nunca colocar a palavra `timbr.` de 6 letras dentro do ícone `16×16`/`32×32`** (fica ilegível); o glifo `curva + .` preserva o parentesco com `v1torres.dev` em qualquer resolução |
| **Silhuetas de dispositivos** | Ícones vetoriais limpos (over-ear, IEM, DAC USB, HDMI, alto-falante, Momentum 4, AirPods) | PDF / SVG vetorizado monocromático (`template` rendering) | Própria / SF Symbols | Renderização por `renderingMode(.template)` para seguir `ink.primary` / `ink.secondary` nas 3 superfícies |
| **Sons de calibração (E-04 / Teste auditivo)** | Impulsos/clicks e tons senoidais gerados em runtime | Síntese matemática em `Float64` | Própria | Não embarcar WAVs pesados; gerar deterministicamente |

### Mapeamento canônico de SF Symbols

| Conceito | SF Symbol | Recurso |
|---|---|---|
| Volume dinâmico por app/saída | `speaker.wave.3` | `variableValue: Double(volume)` |
| Mudo | `speaker.slash` | Tinta `ink.muted` (ou `negative` se inesperado) |
| Equalizador ativo / bypass | `slider.horizontal.3` / `waveform.path` | `accent.base` quando ativo |
| Bit-perfect / sinal íntegro | `checkmark.seal` | `semantic.ok` |
| Guardião / alerta de degradação | `exclamationmark.triangle` | `semantic.warn` ou `semantic.danger` |
| Fone over-ear (ex.: Momentum 4) | `headphones` | — |
| Intra-auricular / AirPods | `airpodspro` / `earbuds` | Usar símbolo do dispositivo quando o sistema/driver identificar |
| DAC / interface externa | `cable.connector` / `hifispeaker` | — |
| Reconhecimento ShazamKit | `shazam.logo` (ou `waveform.badge.magnifyingglass`) | Verificar disponibilidade de símbolo por versão do SDK |
| Abrir Estúdio | `arrow.up.forward.square` | — |

---

## 2. Diretório de Tokens (`design-system/`)

Conforme [ADR-0012](../07-decisoes/ADR-0012-tokens-fonte-unica.md), os tokens vivem na raiz em `design-system/tokens/` no formato W3C DTCG:

```
design-system/
├── tokens/
│   ├── color.tokens.json         # Escala neutra OKLCH + claro/escuro/notch + acento + semânticas + séries
│   ├── typography.tokens.json    # Famílias, tamanhos, pesos, tracking e line-heights
│   ├── spacing-radius.tokens.json# Espaçamento 2/4pt, grade 7/5, raios concêntricos, bordas
│   └── motion.tokens.json        # Curvas cúbicas, springs (bounce 0), staggers, durações
└── scripts/
    └── generate_tokens.py        # Compila JSON -> Swift (TimbreTokens.swift) + CSS (tokens.css)
```

---

## 3. Referências Masters (Mapa Consolidado)

| Domínio | Referência Master | O que adotamos | O que descartamos | Licença / Tipo |
|---|---|---|---|---|
| **Identidade visual & editorial** | **Órbita (SIP) & Ronda Diária** | Neutros OKLCH croma 0, 2 pesos (`400`/`500`), 3 vozes tipográficas, acento violeta único, mistura OKLab, grade 7/5, "menos caixas" | Sombra de elevação pesada no notch; cores de redes sociais | Referência interna do autor |
| **Física, materiais e plataforma** | **Apple HIG + `$apple-design`** | Springs criticamente amortecidas, *velocity handoff*, concentricidade, `NSPanel` não-ativante, Live Activities `#000000` | Liquid Glass sobre textos densos ou dentro do notch | Documentação oficial Apple |
| **Micro-interações e rigor** | **`$emil-design-eng`** | Zero animação em teclado, `< 300 ms`, `scale(0.97)` ao clicar, sem `scale(0)`, `transform-origin` real, `blur` em crossfade | Curvas genéricas fracas (`ease-in-out` padrão) | Skill de engenharia UI |
| **Editor de EQ** | **FabFilter Pro-Q 4** | Escalas `±3/6/12/30 dB`, Spectrum Grab, Piano Display, curva composta + por banda + espectro atrás, edição por rolagem/arrasto | Visual skeuomórfico/gradiente pesado de DAW | Benchmark comercial (UI spec) |
| **Medição de áudio** | **EBU Tech 3341 V4 & FLUX** | Janelas `0,4 s` M / `3 s` S / I gated, escalas `+9/+18`, `dBTP`, balísticas VU/PPM selecionáveis, unidade sempre visível | Suavização artificial em barras EBU | Norma técnica pública |
| **Shaders & reatividade SwiftUI** | **`libraries.dev` (Jakub Antalik)** | `VoiceGlowKit`, `VoiceRingKit`, `BorderBeamKit`, `DistortionWavesKit` via SwiftPM (commit fixado) | Modelos `.mfxl` proprietários (licença comercial restritiva) | MIT (código) |
| **Protótipos de motion & Web** | **`Bencho` + `shadcn/ui` + `Spell UI` + `DSSSP`** | Referência de física para SwiftUI; componentes React para docs, site e playground de EQ | WebView como UI principal do app residente | MIT |
| **Arquitetura de render real-time** | **`AudioKitUI`** (`FFTView`, `MetalView`) & **`AudioKit/Controls`** | Padrão `Canvas` + `TimelineView` + Metal para `60–120 Hz`; lógica de gesto de knobs/sliders | Dependência acoplada ao core do AudioKit ou pacotes sem manutenção | MIT |
