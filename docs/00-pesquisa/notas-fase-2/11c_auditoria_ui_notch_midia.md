# 11c. Auditoria OSS — UI de Notch, Now Playing, Letras e Infraestrutura macOS

- **Data de consulta:** 2026-11-21
- **Escopo:** 18 repositórios open source cobrindo janelas de notch/pílula, MediaRemote/now playing, letras sincronizadas (LRCLIB + clientes) e infraestrutura macOS (teclas de mídia/DDC, atalhos, auto-update, atômicos, testes).
- **Regra de evidência e licença:** Todas as afirmações **Comprovado** foram verificadas nos clones locais ou via `gh api` em **2026-11-21**. Classificações principais assumem núcleo **Permissivo / MPL-2.0** (ADR-0001 Opção B).

---

## Takeaway

- **Casca do Notch (Permissivo):** `MrKai77/DynamicNotchKit` (**MIT**, `cd0b3e52d5`, Swift 6 SPM) + geometria `NSScreen` de `Lakr233/NotchDrop` (**MIT**, `e70b3d715a`) formam a base permissiva ideal para pílula/notch sem copiar código GPL-3.0 de `boring.notch` ou `Atoll`. **Atenção:** `boring.notch#1760` (MacBook Air M5 com altura do notch diferente) e `DynamicNotchKit#50` (suporte futuro ao Dynamic Island em MacBooks OLED) exigem abstração da geometria de superfície (ADR-0013).
- **Now Playing (macOS 15.4–27):** `ungive/mediaremote-adapter` (**BSD-3-Clause**, `6571499027`, testado até macOS 27.0 `26A5425a`) e seu wrapper SwiftPM `ejbills/mediaremote-adapter` (**BSD-3-Clause**, `7d5b6cc99b`) são o padrão de fato via `/usr/bin/perl`. **Atenção:** `ungive/media-control` **não tem arquivo `LICENSE`** (`NONE`), mas é só CLI consumidor; usar o adapter BSD-3 diretamente (ou adaptar PR #7 do fork `ejbills` para Swift 6 + correção de CPU spin no pipe-reader).
- **Letras sincronizadas:** `tranxuanthang/lrclib` (**MIT**, `ffdfed4dd8`, API pública sem chave, `User-Agent` obrigatório) + parser/cliente inspirado em `aviwad/LyricFever` (**MIT**, `20a44f0fc1`) e `ddddxxx/LyricsKit` (**MPL-2.0**, `8a61b97cfc`). `Yudaotor/lyrimuse` (**GPL-3.0**, `9d74d785be`) é excelente referência de engenharia (incluindo `Package.swift` documentando o problema real de `KeyboardShortcuts` 2.2+/3.0 usar macros SwiftUI que falham no `swift build` sem Xcode completo!).
- **Infraestrutura macOS:** `sparkle-project/Sparkle` (**MIT**, `b7debdbd5c`, já definido no ADR-0007), `sindresorhus/KeyboardShortcuts` (**MIT**, `772133d9db`), `apple/swift-atomics` (**Apache-2.0**, `3414b07b3a`) e `swiftlang/swift-testing` (**Apache-2.0**, `cfa4315124`) são **`REUTILIZAR DIRETAMENTE`**. `MonitorControl/MonitorControl` (**MIT**, `7cfe64500d`) é fonte direta para adaptar `MediaKeyTapManager` (`CGEventTap`) e DDC em Apple Silicon (`Arm64DDC.swift`).

---

## 1. Interface de Notch e Janelas Flutuantes

### 1.1 `MrKai77/DynamicNotchKit`
- **URL & SHA:** <https://github.com/MrKai77/DynamicNotchKit> · `HEAD=cd0b3e52d5` (2026-02-18, push 2026-04-24) · rel `1.1.0` · 486 stars · 6 contribuidores (`mrkai77` 131/151 commits) · ac. 2026-11-21 (**Comprovado**).
- **Funcionalidades verificadas no código:** Biblioteca SwiftPM (`swift-tools-version: 6.0`, macOS 13+) para renderizar conteúdo expansível no notch (ou pílula flutuante em Macs sem notch / monitores externos) com `DynamicNotch`, `DynamicNotchPanel` (`NSPanel` sem sombra, nível `.screenSaver`, `.canJoinAllSpaces`, `.stationary`), estilos (`notch` vs `floating`), `DynamicNotchHoverBehavior` e transições configuráveis (**Comprovado**).
- **Arquitetura e módulos reaproveitáveis:** `Sources/DynamicNotchKit/DynamicNotch/DynamicNotch.swift`, `DynamicNotchStyle.swift`, `DynamicNotchTransitionConfiguration.swift`, `Sources/DynamicNotchKit/Utility/DynamicNotchPanel.swift`, `NSScreen+Extensions.swift` (**Comprovado**).
- **Licença:** **MIT** (`LICENSE`). Compatível com MPL-2.0 e App Store (sem APIs privadas tipo SkyLight!) (**Comprovado**).
- **Testes e CI:** 1 arquivo (`Tests/DynamicNotchKitTests/DynamicNotchKitTests.swift`), sem CI (**Comprovado**).
- **Issues/PRs:** 1 aberta: **#50** (*Support for the new MacBook Pro Dynamic Island?*). PRs #45/#46 corrigiram engasgo (stutter) na animação de expansão/recolhimento (**Comprovado**).
- **Classificação:** **`REUTILIZAR DIRETAMENTE`** (ou **`ADAPTAR`** forkando se precisarmos de `.fullScreenAuxiliary` / comportamentos customizados de hover/arrasto do Timbre).

### 1.2 `Lakr233/NotchDrop`
- **URL & SHA:** <https://github.com/Lakr233/NotchDrop> · `HEAD=e70b3d715a` (2026-05-18) · tag `2.16.42` · 2.130 stars · 14 contribuidores (`Lakr233` 139/169 commits) · ac. 2026-11-21 (**Comprovado**).
- **Funcionalidades e arquitetura:** App utilitário de drag-and-drop/AirDrop no notch (`NotchView.swift`, `NotchViewController.swift`, `EventMonitors.swift`). Destaque para `Ext+NSScreen.swift`: cálculo preciso de `notchSize` via `safeAreaInsets.top` e `auxiliaryTopLeftArea`/`auxiliaryTopRightArea`, além de detecção do display interno (`CGDisplayIsBuiltin`) (**Comprovado**).
- **Licença:** **MIT** (`LICENSE`). **Testes e CI:** 0 testes, sem CI. 5 issues abertas (#61 conflito de hit-testing no topo da tela/menubar) (**Comprovado**).
- **Classificação:** **`ADAPTAR`** — Adaptar o cálculo de geometria (`Ext+NSScreen.swift`) e lições de `EventMonitors.swift` (hit-testing sem bloquear a barra de menus).

### 1.3 `TheBoredTeam/boring.notch` e `Ebullioscopic/Atoll`
- **`TheBoredTeam/boring.notch`** (<https://github.com/TheBoredTeam/boring.notch> · `HEAD=b7611bbf32`, 2026-10-31 · rel `v2.7.3` / tag `v2.8-rc.2` · **GPL-3.0** · 11.421 stars · 49 contribuidores · 439 issues+PRs abertas):
  - **Verificado no código:** Usa `BoringNotchSkyLightWindow.swift` com `dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/...")` + `SLSRemoveWindowsFromSpaces` (inviabiliza App Store!), integra `MediaRemoteAdapter` (BSD-3 via `BoringNotchXPCHelper`), AppleScript/HTTP para Apple Music/Spotify/YouTube Music, `VolumeManager.swift` (varrendo elementos 0–4 do HAL) e `NotchShape.swift` (**Comprovado**).
  - **Issues/PRs:** #1760 (notch mais curto no MacBook Air M5), #1766 / PR #1765 (tentativa de exceção de licença para extensões), PR #1771 (letras sob o notch fechado), PR #1769 (barras de espectro sob o notch fechado). 0 testes unitários reais (`TestView.swift` é view de preview) apesar de 10 workflows CI (**Comprovado**).
  - **Classificação:** **`ESTUDAR COMO REFERÊNCIA`** (em MPL-2.0; se ADR-0001 fosse GPL-3.0, ainda evitaríamos `SkyLight` privado no núcleo por fragilidade entre versões e preferência por `DynamicNotchKit`).
- **`Ebullioscopic/Atoll`** (<https://github.com/Ebullioscopic/Atoll> · `HEAD=64bedd3171`, 2026-11-21 · rel `v2.3.3` · **GPL-3.0** · 5.322 stars · 61 contribuidores · 256 issues+PRs):
  - **Verificado no código:** Fork derivado do `boring.notch` (`NOTICE` explícito), muito ativo, adicionou `AppleMusicAirPlayManager`, `BluetoothAudioManager`, `CustomOSDWindowManager`, `ExtensionLiveActivityManager` e **41 arquivos de teste/helpers** (`DynamicIslandTests/`) + 7 workflows CI. Issues: #933 sobreposição música/calendário, PR #939 vazar processos de `log stream` ao fechar o app (**Comprovado**).
  - **Classificação:** **`ESTUDAR COMO REFERÊNCIA`** (GPL-3.0; ótimo para estudar suíte `DynamicIslandTests/` e armadilhas de `log stream` e fullscreen).

---

## 2. Now Playing e MediaRemote

### 2.1 `ungive/mediaremote-adapter` e `ejbills/mediaremote-adapter`
- **`ungive/mediaremote-adapter`** (<https://github.com/ungive/mediaremote-adapter> · `HEAD=6571499027`, 2026-11-20 · rel `v0.8.0` · **BSD-3-Clause** · 311 stars · 5 contribuidores, bus factor alto `ungive` 222/236 commits):
  - **Mecanismo verificado:** Contorna a restrição do macOS 15.4+ à framework privada `MediaRemote.framework` executando `/usr/bin/perl` (binário do sistema com entitlement) que carrega dinamicamente o bundle/dylib `MediaRemoteAdapter` e transmite JSON via stdout (`bin/mediaremote-adapter.pl`, `src/adapter/now_playing.m`). Testado no **macOS 27.0 (`26A5425a`)**. PR #42 adicionou `--bundle-id` para consultar apps específicos além da sessão eleita; PR #46 (aberta) lê comando *like* nativo (**Comprovado**).
  - **Testes:** 4 arquivos em `src/test/` (`NowPlayingTest.m`), sem CI (**Comprovado**).
  - **Classificação:** **`REUTILIZAR DIRETAMENTE`** (com ressalva de risco: depende de comportamento de `/usr/bin/perl` + API privada que a Apple pode fechar em futuros updates, portanto isolado atrás de protocolo `NowPlayingProvider`).
- **`ejbills/mediaremote-adapter`** (<https://github.com/ejbills/mediaremote-adapter> · `HEAD=7d5b6cc99b`, 2026-11-04 · **BSD-3-Clause** · 57 stars · 7 contribuidores):
  - Empacotamento SwiftPM pronto (`Package.swift` com targets `MediaRemoteAdapter` + `CIMediaRemote` + `Resources/run.pl`), 0 testes, sem CI. **PR #7 (aberta)** traz **Swift 6 strict concurrency** e corrige **CPU spin no pipe-reader**! (**Comprovado**).
  - **Classificação:** **`ADAPTAR`** — Usar como ponte SPM sobre a versão mais recente do `ungive/mediaremote-adapter` (incorporando a correção de pipe-reader da PR #7 e suporte `--bundle-id`).

### 2.2 `ungive/media-control` e `kirtan-shah/nowplaying-cli`
- **`ungive/media-control`** (<https://github.com/ungive/media-control> · `HEAD=e711d3ffbd`, 2026-11-20 · rel `v0.8.0` · 134 stars · 1 contribuidor): CLI Perl + wrapper que usa `mediaremote-adapter` como submódulo. **Sem arquivo `LICENSE` (`NONE`)**, 0 testes reais (**Comprovado**). **Classificação:** **`DESCARTAR`** (usar `mediaremote-adapter` BSD-3 diretamente).
- **`kirtan-shah/nowplaying-cli`** (<https://github.com/kirtan-shah/nowplaying-cli> · `HEAD=8c8c1fa482`, 2026-04-06 · rel `v2.1.0` · **GPL-3.0** · 307 stars · 6 contribuidores): CLI Objective-C que embute `mediaremote-mini` + script perl (PR #33 aberta sobre `elapsedTime == 0` no 15.4+). **Classificação:** **`DESCARTAR`** (GPL-3.0 e inferior ao `ungive/mediaremote-adapter` original).

---

## 3. Letras Sincronizadas (LRCLIB e Clientes)

| Projeto | URL & SHA (ac. 2026-11-21) | Licença | Métricas & Testes | Funcionalidades & Achados Técnicos | Classificação |
|---|---|---|---|---|---|
| **`tranxuanthang/lrclib`** | <https://github.com/tranxuanthang/lrclib> · `ffdfed4dd8` (2026-11-10) | **MIT** | 2.284 stars · 7 contrib · 0 testes/CI | Servidor/backend oficial LRCLIB em Rust + SQLite FTS5. Issues relevantes ao cliente: **#129** (`/api/get` varia por `duration`), **#140** (duplicatas), **#133** (anúncios injetados em letras). API gratuita sem key; exige header `User-Agent` identificando o app. | **`REUTILIZAR DIRETAMENTE`** (como serviço externo via API HTTP `/api/get` e `/api/search`) |
| **`aviwad/LyricFever`** | <https://github.com/aviwad/LyricFever> · `20a44f0fc1` (2026-04-03) · rel `v3.3` | **MIT** | 644 stars · 3 contrib · 0 testes, sem CI | Cliente macOS SwiftUI com `LRCLIBLyricProvider.swift`, NetEase, Apple Music/Spotify helpers, karaoke floating window. Issues no macOS 27 (#202 janela não arrasta no 27.0, #198 congela em fullscreen). | **`ADAPTAR`** (`LRCLIBLyricProvider.swift` + parser LRC timestampado, adicionando testes unitários que faltam no original) |
| **`ddddxxx/LyricsKit`** | <https://github.com/ddddxxx/LyricsKit> · `8a61b97cfc` (2022-04-28) · tag `v0.11.3` | **MPL-2.0** | 149 stars · 3 contrib · 3 arqs teste + CI | Framework SwiftPM maduro para modelo/parsing de letras LRC/LRCX (`Lyrics.swift`, `LyricsLine.swift`, `Furigana`), porém sem commits desde 2022 e focado em provedores chineses antigos (Kugou/QQ/NetEase), sem LRCLIB. | **`ESTUDAR COMO REFERÊNCIA`** (modelo de dados `Lyrics`/`LyricsLine` MPL-2.0 se precisarmos de furigana/word-by-word; caso contrário modelo próprio sobre `LyricFever` é mais leve) |
| **`ddddxxx/LyricsX`** | <https://github.com/ddddxxx/LyricsX> · `c16b6a413d` (2022-05-03) · rel `v1.6.3` | **MPL-2.0** | 5.260 stars · 5 contrib · 1 arq teste | App desktop macOS histórico em cima do `LyricsKit`, **sem manutenção desde 2022** (309 issues abertas, #646 problemas no macOS 26). | **`DESCARTAR`** |
| **`Yudaotor/lyrimuse`** | <https://github.com/Yudaotor/lyrimuse> · `9d74d785be` (2026-11-19) · rel `v1.14.0` | **GPL-3.0** | 447 stars · 6 contrib · 933 arqs/selftests + 3 CI | App SwiftPM muito bem engenheirado com `LyrimuseCore` isolado, `lyrimuse-selftest`, extrapolação de progresso, 22 players, romanização e tradução on-device. **Achado crítico em `Package.swift`:** prova que `KeyboardShortcuts` 2.2.4+/3.0.x quebra `swift build` sem Xcode completo por macros `@Entry`/`#Preview`! | **`ESTUDAR COMO REFERÊNCIA`** (em MPL-2.0; excelente referência de arquitetura SwiftPM e tolerância a players) |

---

## 4. Infraestrutura macOS (Teclas, DDC, Atalhos, Updates, Concorrência, Testes)

### 4.1 `MonitorControl/MonitorControl`
- **URL & SHA:** <https://github.com/MonitorControl/MonitorControl> · `HEAD=7cfe64500d` (2026-10-14) · rel `v4.4.0` · 34.783 stars · 82 contribuidores · ac. 2026-11-21 (**Comprovado**).
- **Funcionalidades e módulos reaproveitáveis:** Controle de brilho e volume de monitores externos via DDC (`Arm64DDC.swift` usando `IOAVService` privado/estável em Apple Silicon, `IntelDDC.swift`), interceptação de teclas de mídia (`MediaKeyTapManager.swift` via `MediaKeyTap` / `CGEventTap`), e utilitários de OSD (`OSDUtils.swift`) (**Comprovado**).
- **Licença:** **MIT** (`License.txt`). 0 testes, sem CI; 37 issues abertas (#1942 HDMI interno em M1 Pro/Max, #1936/#1935 estado de mute no limite de volume, PR #1932 crash com NaN DDC) (**Comprovado**).
- **Classificação:** **`ADAPTAR`** — Fonte MIT de referência para "Super Volume Keys" (teclas de volume controlando o Timbre + DDC em monitores HDMI/DisplayPort quando o usuário concede Acessibilidade fora da App Store).

### 4.2 `sindresorhus/KeyboardShortcuts`
- **URL & SHA:** <https://github.com/sindresorhus/KeyboardShortcuts> · `HEAD=772133d9db` (2026-09-11) · rel `3.1.0` · **MIT** · 2.745 stars · 35 contribuidores · 3 arquivos de teste + CI (`swiftlint.yml`) · ac. 2026-11-21 (**Comprovado**).
- **Análise:** Padrão de mercado em Swift para atalhos globais via Carbon `RegisterEventHotKey` + `Recorder` SwiftUI/AppKit (sem exigir permissão de Acessibilidade para atalhos normais, compatível com App Store!). Nota verificada em `lyrimuse`: versões 3.x usam `@Entry` macro (exigem Xcode completo no build). Issues #243/#244 sobre atalho com menu aberto (**Comprovado**).
- **Classificação:** **`REUTILIZAR DIRETAMENTE`** (via SPM no Xcode; para builds headless sem Xcode completo, pinar `1.15.0` ou usar Xcode no CI).

### 4.3 `sparkle-project/Sparkle`
- **URL & SHA:** <https://github.com/sparkle-project/Sparkle> · `HEAD=b7debdbd5c` (2026-11-20) · rel `2.10.1` · **MIT** (+ BSD-2 `bsdiff` e `ed25519` permissivos em `LICENSE`) · 9.950 stars · 100+ contribuidores · 141 arquivos de teste/config + CI · ac. 2026-11-21 (**Comprovado**).
- **Análise:** Padrão ouro para auto-update fora da Mac App Store com assinatura EdDSA (`generate_appcast`), deltas binários e XPC sandboxed (`Autoupdate/`). Já decidido no **ADR-0007** (**Comprovado**).
- **Classificação:** **`REUTILIZAR DIRETAMENTE`** (distribuição Developer ID; excluído da eventual versão lite da App Store).

### 4.4 `apple/swift-atomics` e `swiftlang/swift-testing`
- **`apple/swift-atomics`** (<https://github.com/apple/swift-atomics> · `HEAD=3414b07b3a`, 2026-11-09 · rel `1.3.1` · **Apache-2.0** · 1.205 stars · 24 contribuidores · 71 arquivos de teste + `Atomics.xctestplan` + CI): Fornece `UnsafeAtomic`, `ManagedAtomic` e memory orderings explícitos (`acquiring`/`releasing`) para comunicação lock-free com a thread de áudio RT, complementando `Synchronization.Atomic` (que exige macOS 15+ nativamente). **Classificação:** **`REUTILIZAR DIRETAMENTE`** (ou usar `Synchronization.Atomic` da stdlib se o piso for macOS 15+ no ADR-0005, mantendo `swift-atomics` se precisar de `DoubleWord` / atomicidade em tipos customizados).
- **`swiftlang/swift-testing`** (<https://github.com/swiftlang/swift-testing> · `HEAD=cfa4315124`, 2026-11-19 · rel `swift-6.4.3-RELEASE` · **Apache-2.0** · 2.182 stars · 73 contribuidores · 359 arqs teste + 5 CI): Framework oficial moderno da Apple (`@Test`, `#expect`, testes parametrizados e tags), já incluso no Xcode 16+/Swift 6. **Classificação:** **`REUTILIZAR DIRETAMENTE`** (como harness padrão de testes Swift do Timbre junto ao `XCTest` para testes de UI/performance).

---

## Inferences

1. **Pilha de UI Notch + Mídia 100% livre de GPL:** `MrKai77/DynamicNotchKit` (MIT) + geometria `Ext+NSScreen` de `Lakr233/NotchDrop` (MIT) + `ejbills/mediaremote-adapter` atualizado com `ungive/mediaremote-adapter` (BSD-3) + `LRCLIB` API + parser adaptado de `LyricFever` (MIT) entregam todas as capacidades de notch/now-playing/letras sem nenhuma contaminação GPL e sem APIs privadas `SkyLight`.
2. **Isolamento de risco de distribuição:** `MonitorControl` (teclas via `CGEventTap`), `Sparkle` (updates) e `mediaremote-adapter` (`/usr/bin/perl`) devem viver atrás de protocolos/adaptadores desacoplados ou flags de distribuição (ADR-0007), para que uma eventual build "lite" na Mac App Store possa desligá-los limpo em tempo de compilação.

## Gaps

- Não testamos em hardware real o comportamento de `DynamicNotchKit` em MacBook Air M5 (`boring.notch#1760`) nem em MacBooks OLED com Dynamic Island nativa (`DynamicNotchKit#50`).
- A estabilidade de `ejbills/mediaremote-adapter` PR #7 em macOS 27.x não foi compilada/executada localmente nesta rodada.
