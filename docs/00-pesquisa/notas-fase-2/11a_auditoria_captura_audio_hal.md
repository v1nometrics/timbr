# 11a. Auditoria OSS — Captura (Process Taps), Mixagem, HAL, Drivers Virtuais e Benchmarks Comerciais

- **Data de consulta:** 2026-11-21
- **Escopo:** 22 repositórios open source de captura por Process Taps, mixagem por app, wrappers HAL Core Audio, sample-rate switching e drivers virtuais `AudioServerPlugIn`, além de 3 benchmarks comerciais (SoundSource, Loopback, EQBase).
- **Regra de evidência e licença:** Nenhuma linha de código GPL/AGPL/PolyForm foi copiada. Afirmações marcadas como **Comprovado** foram verificadas diretamente nos clones locais (`git` / arquivos-fonte) ou via `gh api` em **2026-11-21**. Classificações principais assumem núcleo **Permissivo / MPL-2.0** (ADR-0001 Opção B recomendada); impactos no cenário **GPL-3.0** (Opção A) são sinalizados por item.

---

## Takeaway

- **Captura por Process Taps (Permissivo):** `Sakuleta/tapmix` (**MIT**, `f454eb3457`) e `CJStanfield/CoreAudioTapKit` (**MIT**, `aab395f1e8`) provam em código que captura + processamento + renderização podem rodar **em um único aggregate device e único `IOProc` com relógio único**, com alocação zero no callback e triple-buffering atômico (`Synchronization.Atomic`). `insidegui/AudioCap` (**BSD-2-Clause**, `6f609e8ad1`) segue como referência minimalista didática.
- **Wrappers HAL Core Audio (Permissivo):** `sbooth/CAAudioHardware` (**MIT**, `d295de91f2`) + `sbooth/CoreAudioExtensions` (**MIT**, `b8c116bc7e`) e `orchetect/swift-core-audio` (**MIT**, `91e2d2bce1`) já cobrem `AudioTap`, `AudioSubtap`, `AudioAggregateDevice` e `AudioProcess` em Swift 6 com testes. `ryanfrancesconi/spfk-audio-hardware` (**MIT**, `8e82299e9e`) é o sucessor ativo do arquivado `rnine/SimplyCoreAudio` (23 arquivos de teste e backend mockável), porém sem wrappers de `AudioTap`.
- **Referências GPL de altíssimo valor de estudo:** `ronitsingh10/FineTune` (**GPL-3.0**, `2285279d36`) e `belugaming/tapline` (**GPL-3.0**, `9036e352db`) revelam armadilhas reais de produção no macOS 26/27 (crossfade sem silêncio no switch de device, `OrphanedTapCleanup`, ducking exemption, `CrashGuard`, falha do spectrum abaixo de 40 kHz em HFP, `MediaRemoteUIService` aparecendo como app sem nome). `vincentneo/LosslessSwitcher` (**GPL-3.0**, `d35aeed602`) comprova via issue #231 o risco de ler logs do CoreMedia para troca de sample rate (troca antes do fim da faixa por pre-buffering).
- **Drivers virtuais (`AudioServerPlugIn`):** Sem necessidade no MVP (ADR-0004). Caso surja modo Loopback/dispositivo virtual pós-MVP, `gavv/libASPL` (**MIT**, `633e0f7020`) e `briankendall/proxy-audio-device` (**Unlicense**, `d3d8c8c034`) formam a base permissiva; `BlackHole` (**GPL-3.0** + marca reservada) e `BackgroundMusic` (**GPL-2.0**, 545 issues, status alpha) são descartáveis/apenas estudo.
- **Armadilhas jurídicas descobertas no código:** `GabrielSabadinn/PerAppVolume` usa **PolyForm Noncommercial 1.0.0** (incompatível com qualquer projeto comercial ou OSS permissivo/GPL) e `makeusabrew/audiotee` **não possui arquivo `LICENSE`** no repositório (issue #15 aberta pedindo MIT) — ambos proibidos para reutilização de código.

---

## 1. Captura por Process Taps e Mixers por App

### 1.1 `Sakuleta/tapmix`
- **URL & SHA:** <https://github.com/Sakuleta/tapmix> · `HEAD=f454eb3457` (2026-10-28) · tag/rel `v0.3.3` · 0 stars · 1 contribuidor (`Sakuleta`, 57 commits) · ac. 2026-11-21 (**Comprovado**)
- **Funcionalidades verificadas no código:** Mixer por app via Core Audio Process Taps (`TapManager.swift`, `TapPlan.swift`, `TapController.swift`), EQ paramétrico 10 bandas + importação AutoEQ (`EQProcessor.swift`, `AutoEQCatalog.swift`), host de Audio Units (`AudioUnitHost.swift`), Lookahead Limiter 5 ms (`LookaheadLimiter.swift`), Night Mode (`NightModeProcessor.swift`), Ducking Policy (`DuckingPolicy.swift`), gravação de tap (`TapRecorder.swift`), comando via URL scheme, atalhos globais e updates com Sparkle 2.10.1 (`Package.swift`) (**Comprovado**).
- **Arquitetura e técnicas:** SwiftPM puro (`swift-tools-version: 5.10`, piso `.macOS("15.0")`), núcleo separado em `TapmixCore` sem dependências de UI. `EQProcessor.swift` usa **triple-buffering** com `Synchronization.Atomic<Int>` em 3 bancos pré-alocados (`UnsafeMutablePointer<BiquadCoefficient>`) para atualização lock-free sem destruir setups na thread de áudio; `LookaheadLimiter.swift` pré-aloca linhas de atraso de 5 ms com ceiling `0.98` (**Comprovado**).
- **Módulos reaproveitáveis:** `Sources/TapmixCore/TapManager.swift`, `TapPlan.swift`, `TapRender.swift`, `EQProcessor.swift`, `LookaheadLimiter.swift`, `AutoEQCatalog.swift`, `DuckingPolicy.swift` (**Comprovado**). *(Ressalva de precisão: processa biquads em `Float` / Float32 — para o Timbre precisará adaptação para Float64 ou uso do motor CamillaDSP v5.)*
- **Licença e obrigações:** **MIT** (`LICENSE` na raiz; `THIRD_PARTY_NOTICES.md` documenta AutoEQ). 100% compatível com núcleo MPL-2.0/MIT e App Store (exceto recursos fora do sandbox como Sparkle/atalhos globais se aplicável) (**Comprovado**).
- **Testes e CI:** Excelente cobertura relativa para um projeto solo: **23 arquivos de teste** em `Tests/TapmixTests/` (`AudioEngineTests`, `TapManagerTests`, `TapPlanTests`, `EQProcessorTests`, `LookaheadLimiterTests`, `AutoEQCatalogTests`, `SceneStoreTests`, `TapRecorderTests`) + workflow `.github/workflows/ci.yml` (**Comprovado**).
- **Issues/PRs e riscos:** 0 issues abertas; PRs recentes mesclados (#49 apps não listados pelo LaunchServices, #48 chamadas intocadas). **Risco:** projeto muito jovem (criado em 2026-10-27), bus factor = 1, 0 stars, processamento EQ em Float32 (**Comprovado**).
- **Classificação:** **`ADAPTAR`** — Arquitetura de tap management (`TapPlan`, `TapManager`, `LookaheadLimiter`, triple-buffer atômico) limpa, MIT e testada; adaptar padrões de gerenciamento de taps para nosso helper de motor (substituindo biquads Float32 por Float64/CamillaDSP).

### 1.2 `CJStanfield/CoreAudioTapKit`
- **URL & SHA:** <https://github.com/CJStanfield/CoreAudioTapKit> · `HEAD=aab395f1e8` (2026-09-07) · rel `0.1.0` · 4 stars · 1 contribuidor (`CJStanfield`, 14 commits) · ac. 2026-11-21 (**Comprovado**).
- **Funcionalidades verificadas no código:** Biblioteca SwiftPM para captura de áudio do sistema bound a um `outputUID`, passagem por `AudioProcessor` e renderização de volta no dispositivo de saída (**Comprovado**).
- **Arquitetura e técnicas:** Implementa a lição crítica da PR #1 (*"Single-clock capture and render: one aggregate, one IOProc"*): em vez de criar dois `IOProc`s ou dois dispositivos separados (fonte de drift), cria um único `AudioAggregateDevice` privado combinando tap + dispositivo de saída e roda captura → `scratchBuffer` pré-alocado (`16_384 * 2` floats) → `AudioProcessor` → saída no **mesmo `IOProc`** (`Sources/CoreAudioTapKit/SystemAudioTapEngine.swift`, `SystemTapCapture.swift`) (**Comprovado**).
- **Módulos reaproveitáveis:** `Sources/CoreAudioTapKit/SystemAudioTapEngine.swift`, `SystemTapCapture.swift`, `AudioBufferListUtilities.swift`, `SystemAudioDeviceLookup.swift` (**Comprovado**).
- **Licença e obrigações:** **MIT** (`LICENSE` na raiz). Totalmente compatível com MPL-2.0/MIT e App Store (requer apenas entitlement/permissão padrão de System Audio Recording) (**Comprovado**).
- **Testes e CI:** 3 suítes unitárias em `Tests/CoreAudioTapKitTests/` (`AudioBufferListUtilitiesTests`, `AudioProcessorTests`, `AudioDevicesTests`); sem `.github/workflows` (**Comprovado**).
- **Issues/PRs e riscos:** 0 issues abertas; PR #1 consolidou a topologia single-clock. **Limitação:** escopo apenas de sistema/device (não faz mixagem multi-app por PID individual sem adaptação) e bus factor = 1 (**Comprovado**).
- **Classificação:** **`ADAPTAR`** — Excelente esqueleto MIT da camada Swift/Core Audio para topologia aggregate único + IOProc único por dispositivo (ADR-0004).

### 1.3 `insidegui/AudioCap`
- **URL & SHA:** <https://github.com/insidegui/AudioCap> · `HEAD=6f609e8ad1` (2025-08-07) · sem releases/tags · 513 stars · 1 contribuidor (`insidegui`, 21 commits) · ac. 2026-11-21 (**Comprovado**).
- **Funcionalidades verificadas no código:** App demo macOS que lista processos de áudio (`AudioProcessController.swift`), solicita permissão de captura (`AudioRecordingPermission.swift`), cria `CATapDescription` + aggregate device e grava stream em arquivo (`ProcessTap.swift`) (**Comprovado**).
- **Arquitetura e técnicas:** Código conciso e didático em Swift; captura passiva (`muteBehavior = .unmuted`) focada em gravação, não em processamento in-line nem `.mutedWhenTapped` (**Comprovado**).
- **Módulos reaproveitáveis:** `AudioCap/ProcessTap/ProcessTap.swift`, `AudioProcessController.swift`, `AudioRecordingPermission.swift`, `CoreAudioUtils.swift` (**Comprovado**).
- **Licença e obrigações:** **BSD-2-Clause** (`LICENSE` na raiz). Compatível com núcleo permissivo/MPL-2.0 e App Store (**Comprovado**).
- **Testes e CI:** 0 testes, sem CI (**Comprovado**).
- **Issues/PRs e riscos:** 0 issues; PR #1 aberta (*Real-time Buffer Monitoring and VAD*). Último push em ago/2025 (projeto exemplo estático) (**Comprovado**).
- **Classificação:** **`ESTUDAR COMO REFERÊNCIA`** — Referência canônica mínima de `AudioHardwareCreateProcessTap`, mas superada estruturalmente por `CoreAudioTapKit`, `tapmix` e `CAAudioHardware`.

### 1.4 `ronitsingh10/FineTune`
- **URL & SHA:** <https://github.com/ronitsingh10/FineTune> · `HEAD=2285279d36` (2026-07-09) · rel `v1.9.0` · 10.229 stars · 22 contribuidores (`ronitsingh10` 611/657 commits — alto bus factor) · ac. 2026-11-21 (**Comprovado**).
- **Funcionalidades verificadas no código:** Mixer por app via Process Taps com boost até +12 dB (`4.0`), redirecionamento de dispositivo por app com **crossfade sem corte** (`CrossfadeOrchestrator.swift`), EQ gráfico 10 bandas + AutoEQ per-device (`AutoEQFetcher/Parser/Processor`), compensação de loudness ISO 226 (`ISO226Contours.swift`, `KWeightingFilter.swift`, `LoudnessEqualizer.swift`), Soft Limiter (`SoftLimiter.swift`), controle DDC de volume HDMI/DP (`DDCController.swift`), captura de teclas de mídia (`MediaKeyMonitor.swift`) com HUD estilo Tahoe/Classic (`TahoeStyleHUD.swift`) (**Comprovado**).
- **Arquitetura e técnicas:** `ProcessTapController.swift` isola `@MainActor` da thread RT usando `nonisolated(unsafe)` (leituras/escritas atômicas alinhadas em ARM64/x86-64). Biquads rodam em **Float32 (`vDSP_biquad`)** com barreira `OSMemoryBarrier()` e **destruição diferida de 500 ms** (`BiquadProcessor.swift`) para não liberar `vDSP_biquad_Setup` enquanto o callback de áudio ainda executa. Inclui `CrashGuard.swift` e `OrphanedTapCleanup.swift` para limpar taps órfãos após crash (**Comprovado**).
- **Módulos para estudo (NÃO copiar — GPL-3.0):** `FineTune/Audio/Engine/ProcessTapController.swift`, `CrossfadeOrchestrator.swift`, `OrphanedTapCleanup.swift`, `CrashGuard.swift`, `SoftLimiter.swift`, `FineTune/Audio/Loudness/ISO226Contours.swift`, `FineTune/Audio/Keys/MediaKeyMonitor.swift`, `FineTuneTests/SoftLimiterAdversarialTests.swift` (**Comprovado**).
- **Licença e obrigações:** **GPL-3.0**. Incompatível com núcleo MPL-2.0/MIT; uso exige GPLv3 em todo o app e cria conflito histórico na Mac App Store (**Comprovado**).
- **Testes e CI:** Suite extensiva em `FineTuneTests/` (~48 arquivos de teste verificados no repo, incluindo testes adversariais de limiter, decoder IOKit, fail-open de teclas de mídia, crossfade e ISO 226) (**Comprovado**).
- **Issues/PRs e riscos:** **248 issues+PRs abertas** — excelente fonte de bugs reais do macOS 27: #498 áudio duplicado com Spotifast Soloist, #493 `MediaRemoteUIService` aparecendo como app sem nome no macOS 27, #491 sem áudio em AirPods Max via USB-C no macOS 27.0.1, #483 volume baixíssimo em chamadas WeChat no macOS 27.2, #477 distorção cumulativa no Google Meet, #465 impedir sleep quando ocioso. PRs #487 (race no crossfade deixando app mudo) e #482 (isenção de ducking durante chamadas) documentam soluções valiosas (**Comprovado**).
- **Classificação:** **`ESTUDAR COMO REFERÊNCIA`** (em MPL-2.0) · *(`ADAPTAR` apenas se o ADR-0001 escolher GPL-3.0, ainda exigindo reescrita do DSP para Float64 conforme ADR-0003)*.

### 1.5 `mavericksxx/per-app-audio`
- **URL & SHA:** <https://github.com/mavericksxx/per-app-audio> · `HEAD=bc6535ace0` (2026-09-19) · rel `v1.1` · 0 stars · 1 contribuidor (`mavericksxx`, 39 commits) · ac. 2026-11-21 (**Comprovado**).
- **Funcionalidades e arquitetura:** Roteamento de áudio por app usando Process Taps em pacote `AudioRoutingEngine` (`AudioOutputDevice.swift`, `AudioProcess.swift`, `Route.swift`) + CLI diagnóstico `RouteDiag` + app MenuBar (**Comprovado**).
- **Módulos reaproveitáveis:** `Sources/AudioRoutingEngine/AudioOutputDevice.swift`, `AudioProcess.swift`, `CoreAudioProperties.swift`, `Sources/RouteDiag/main.swift` (**Comprovado**).
- **Licença:** **MIT** (com `NOTICE` reproduzindo licenças de terceiros adaptados). Compatível com MPL-2.0/App Store (**Comprovado**).
- **Testes e CI:** Apenas 1 arquivo misto (`RouteStore.swift`), sem CI (**Comprovado**).
- **Issues/PRs e riscos:** 0 issues/PRs; pouca validação comunitária, bus factor = 1 (**Comprovado**).
- **Classificação:** **`ESTUDAR COMO REFERÊNCIA`** — Boa referência MIT enxuta de `AudioRoutingEngine` e CLI de diagnóstico, mas `tapmix` e `CoreAudioTapKit` são mais completos.

### 1.6 `GabrielSabadinn/PerAppVolume`
- **URL & SHA:** <https://github.com/GabrielSabadinn/PerAppVolume> · `HEAD=d9521e02e9` (2026-11-02) · sem release · 0 stars · 1 contribuidor (**Comprovado**).
- **Funcionalidades e arquitetura:** Mixer por app via Process Taps + **extensão Safari** (`App/SafariWebExtensionHandler.swift`) para controlar volume individual de abas do navegador (Google Meet vs YouTube) (**Comprovado**).
- **Licença e obrigações:** **`PolyForm Noncommercial License 1.0.0`** (detectado como `NOASSERTION` na API do GitHub, verificado no arquivo `LICENSE`!). **Incompatível com qualquer projeto open source OSI (MIT, MPL-2.0, GPL-3.0) e proibido para uso comercial/planos pagos** (**Comprovado**).
- **Testes e CI:** 0 testes, sem CI (**Comprovado**).
- **Classificação:** **`DESCARTAR`** (como fonte de código; apenas notar conceitualmente a ideia da extensão Safari para abas se um dia desejado no backlog).

### 1.7 `makeusabrew/audiotee` e `sbetko/catap`
- **`makeusabrew/audiotee`** (<https://github.com/makeusabrew/audiotee> · `HEAD=56ac954369`, 2026-03-31 · 94 stars · 3 contribuidores): CLI/lib Swift (`AudioTeeCore`) para capturar todo o áudio do sistema via Process Taps e emitir PCM no `stdout` (para ASR/pipelines). Tem 1 arquivo de teste (`AudioBufferTests.swift`), sem CI. **Alerta jurídico:** `lic=NONE` — não tem `LICENSE` no repositório (issue aberta #15 *"Could you add a LICENSE file (MIT)?"* ainda sem resolução!). **Classificação:** **`DESCARTAR`** (sem licença explícita = todos os direitos reservados; além de ser apenas gravador para stdout).
- **`sbetko/catap`** (<https://github.com/sbetko/catap> · `HEAD=b44dd41b60`, 2026-11-05 · rel `v0.6.1` · **MIT** · 1 star · 1 contribuidor): Biblioteca Python que chama um ring buffer lock-free em C (`native/catap_coreaudio/src/catap_coreaudio.c` com `stdatomic.h` acquire/release) sobre Core Audio taps; **17 arquivos de teste** (`pytest`) + CI. Inadequado para runtime nativo Swift/Rust por ser Python, mas o ring buffer SPSC em C é limpo. **Classificação:** **`ESTUDAR COMO REFERÊNCIA`** (ring buffer SPSC em C e suíte de testes de tap em Python para inspiração de harness).

### 1.8 `sacis/Liland`
- **URL & SHA:** <https://github.com/sacis/Liland> · `HEAD=f9dd0ee3c7` (2026-11-21) · rel `v1.1.0` · 36 stars · 1 contribuidor (**Comprovado**).
- **Funcionalidades e arquitetura:** App macOS que combina Notch UI (`NotchGeometry.swift`), Process Taps (`ProcessAudioTap.swift`), Biquads, `BassExciter.swift`, analisador de espectro e separação de stems via Demucs (`DemucsSplitter.swift`) (**Comprovado**).
- **Licença:** **`NONE`** (nenhum arquivo `LICENSE` encontrado no clone — copyright reservado por padrão!). Sem testes unitários e sem CI (**Comprovado**).
- **Classificação:** **`DESCARTAR`** — Ausência de licença impede qualquer reutilização de código.

---

## 2. Wrappers HAL, Dispositivos Core Audio e Sample Rate Switching

### 2.1 `sbooth/CAAudioHardware` e `sbooth/CoreAudioExtensions`
- **URL & SHA:** <https://github.com/sbooth/CAAudioHardware> · `HEAD=d295de91f2` (2026-11-19) · rel `0.9.0` · 23 stars · 3 contribuidores (`sbooth` 133/140 commits) + <https://github.com/sbooth/CoreAudioExtensions> · `HEAD=b8c116bc7e` (2026-06-22) · rel `0.4.0` · 2 stars · ac. 2026-11-21 (**Comprovado**).
- **Funcionalidades verificadas no código:** Cobertura exaustiva e idiomática em Swift da hierarquia Core Audio HAL: `AudioSystem`, `AudioDevice`, `AudioStream`, `AudioControl` (`BooleanControl`, `LevelControl`, `SliderControl`, `StereoPanControl`, `SelectorControl`), `AudioAggregateDevice`, `AudioSubdevice`, **`AudioTap`** (`AudioTap.swift` com `create(description:)`, `makeTap(forUID:)`, `taps`), **`AudioSubtap`**, **`AudioProcess`**, `AudioBox`, `AudioClockDevice`, `AudioEndpointDevice`, `PropertyObservation` e `UnfairLock`. `CoreAudioExtensions` adiciona helpers para `AudioStreamBasicDescription`, `AudioChannelLayout`, `AudioTimeStamp`, `AudioValueRange` (**Comprovado**).
- **Licença:** **MIT** (`LICENSE.txt`, copyright Stephen F. Booth — autor veterano desde 2006 no ecossistema macOS áudio). Totalmente compatível com MPL-2.0 e App Store (**Comprovado**).
- **Testes e CI:** Ambos têm workflow `.github/workflows/swift.yml` e target de testes (`CAAudioHardwareTests.swift`, `CoreAudioExtensionsTests.swift`), ainda que com 1 arquivo de teste básico cada (**Comprovado**).
- **Issues/PRs e risco:** 3 issues/PRs abertas (#80 propriedades faltantes, #52 polyfill macOS 15); manutenção constante e conservadora por mantenedor altamente confiável (mesmo autor de `SFBAudioEngine`). **Risco:** bus factor prático = 1, cobertura de testes unitários rasa (**Comprovado**).
- **Classificação:** **`REUTILIZAR DIRETAMENTE`** (ou **`ADAPTAR`**) — Melhor candidato Swift SPM para abstrair objetos HAL (`AudioDevice`, `AudioControl`, `AudioTap`, `AudioAggregateDevice`, observação de propriedades).

### 2.2 `orchetect/swift-core-audio`
- **URL & SHA:** <https://github.com/orchetect/swift-core-audio> · `HEAD=91e2d2bce1` (2026-11-06) · rel `0.2.5` · 4 stars · 1 contribuidor (`orchetect`, 209 commits) · ac. 2026-11-21 (**Comprovado**).
- **Funcionalidades verificadas no código:** Pacote **Swift 6 strict concurrency** (`swiftLanguageModes: [.v6]`, `Sendable`) cobrindo `AnyAudioDevice`, `AudioAggregateDevice` (com DSL tipada de `Composition`, `SubDevice`, `SubTap`, `DriftCompensationQuality`), `AudioTap`, `AudioSubTap`, `AudioProcess`, `AudioBooleanControl`, `AudioBox`, `BluetoothAudioProduct`, `AsyncAudioPropertyCache`, e app de exemplo `CoreAudio Explorer` (**Comprovado**).
- **Licença:** **MIT**. Compatível com MPL-2.0 e App Store (**Comprovado**).
- **Testes e CI:** **45 arquivos de teste** (Swift Testing) + `.github/workflows/build.yml` e `examples.yml` (**Comprovado**).
- **Risco:** API ainda em `0.2.x` (sujeita a evolução), 3 dependências internas do mesmo autor (`swift-process`, `swift-testing-extensions`, `swift-unit-interval`), bus factor = 1 (**Comprovado**).
- **Classificação:** **`REUTILIZAR DIRETAMENTE`** / **`ADAPTAR`** — Excelente alternativa (ou complemento) a `CAAudioHardware`, especialmente pela tipagem Swift 6 `Sendable` de `AudioTap`, `AudioAggregateDevice.Composition` e `BluetoothAudioProduct`. Validar em E-07/E-02 entre `CAAudioHardware` e `swift-core-audio`.

### 2.3 `ryanfrancesconi/spfk-audio-hardware` e `rnine/SimplyCoreAudio`
- **`rnine/SimplyCoreAudio`** (<https://github.com/rnine/SimplyCoreAudio> · `HEAD=b5430564b1`, 2024-02-25 · **MIT** · **ARQUIVADO**): Wrapper clássico Swift de dispositivos HAL (volume, streams, clock source, hog mode, aggregates), 8 arquivos de teste. Arquivado com issues abertas (#79 AirPods invertidos, #73 `EXC_BAD_ACCESS` em troca durante chamada VoIP). **Classificação:** **`DESCARTAR`** (substituído pelo fork ativo abaixo).
- **`ryanfrancesconi/spfk-audio-hardware`** (<https://github.com/ryanfrancesconi/spfk-audio-hardware> · `HEAD=8e82299e9e`, 2026-11-12 · rel `5.4.6` · **MIT** · 9 stars · 12 contribuidores): Sucessor ativo mantido pelo top contributor de `SimplyCoreAudio`. Possui abstração `AudioBackend` / `CoreAudioBackend` (permitindo testes com mock `NullDeviceTests`!) e **23 arquivos de teste**, além de `SplitAudioDevice.swift` e `AudioDevice+VolumeConversion.swift`. **Limitação:** não implementa `AudioTap` / `CATapDescription` (**Comprovado**). **Classificação:** **`ESTUDAR COMO REFERÊNCIA`** (especialmente o padrão `AudioBackend` testável para mocks de HAL nos testes do Timbre, e `AudioDevice+VolumeConversion.swift`).

### 2.4 `vincentneo/LosslessSwitcher`
- **URL & SHA:** <https://github.com/vincentneo/LosslessSwitcher> · `HEAD=d35aeed602` (2026-06-07) · rel `2.0` / tag `3.0-beta1` · 2.029 stars · 58 contribuidores (`vincentneo` 178/248 commits) · ac. 2026-11-21 (**Comprovado**).
- **Funcionalidades e arquitetura:** App MenuBar que lê logs do `OSLog` / `log stream` do Apple Music buscando `audioCapabilities:` (`asbdSampleRate = ... kHz`, bit depth em `CMPlayerStuff.swift`) e ajusta a taxa nominal do DAC via `SimplyCoreAudio` + metadados via `MediaRemoteAdapter` (**Comprovado**).
- **Licença:** **GPL-3.0**. Sem testes unitários e sem CI (**Comprovado**).
- **Issues/PRs críticos:** 73 issues abertas revelando fragilidade estrutural do método por log: **#231** (*Sample rate switches mid-track to the next track's rate on macOS 27* por pre-buffering do Apple Music), **#214** (audio drops/freezes em DACs externos no Tahoe), **#208** (v3 usando 100% de CPU), PR #229 (tentativa fechada de Exclusive Mode via dispositivo virtual) (**Comprovado**).
- **Classificação:** **`ESTUDAR COMO REFERÊNCIA`** — Prova por evidência negativa os limites do parsing de logs do CoreMedia; se o Timbre fizer bit-perfect/auto-sample-rate, deve correlacionar troca de faixa via MediaRemote/MusicKit/AppleScript com estado do stream e não apenas disparar na primeira linha de log de pre-buffer.

### 2.5 `deweller/switchaudio-osx` e `karaggeorge/macos-audio-devices`
- **`deweller/switchaudio-osx`** (`HEAD=6659247d96`, 2023-04-22 · tag `1.2.2` · 1.460 stars · licença **MIT-like customizada** em `license.txt`, `NOASSERTION` no GitHub): CLI em C (`audio_switch.c`) antiga, 0 testes, 21 issues (#76/#63 não lista AirPlay, #73 falha com AirPods). **Classificação:** **`DESCARTAR`**.
- **`karaggeorge/macos-audio-devices`** (`HEAD=5b5db178bc`, 2020-09-09 · **MIT** · 175 stars): CLI Swift + wrapper Node.js, sem manutenção desde 2020 (issue #31 sobre manutenção, #22 sem AirPlay). **Classificação:** **`DESCARTAR`**.

---

## 3. Drivers Virtuais (`AudioServerPlugIn`), Mixers Cross-Platform e Legado

### 3.1 `gavv/libASPL`
- **URL & SHA:** <https://github.com/gavv/libASPL> · `HEAD=633e0f7020` (2025-04-14) · rel `v3.1.2` · 91 stars · 4 contribuidores (`gavv` 88/92 commits) · ac. 2026-11-21 (**Comprovado**).
- **Funcionalidades e arquitetura:** Framework C++17 moderno para criar `AudioServerPlugIn` (drivers HAL em user space) sem lidar diretamente com boilerplate COM C de `AudioServerPlugInDriverInterface`. Contém `DoubleBuffer.hpp`, `ControlRequestHandler`, `IORequestHandler`, `MuteControl`, `VolumeControl`, e exemplos (`SinewaveDevice`, `NetcatDevice`) (**Comprovado**).
- **Licença:** **MIT** (com avisos de código de exemplo da Apple em `LICENSE.apple2012`/`LICENSE.apple2020` MIT-compatível) (**Comprovado**).
- **Testes e CI:** 9 arquivos de teste C++ (`test/TestDoubleBuffer.cpp`, `TestProperties.cpp`, etc.) + CI `build.yml` (**Comprovado**).
- **Issues/PRs:** 4 abertas (PR #13 sobre `ZeroTimeStampPeriod`, #12 exemplo de troca de sample rate). Bus factor = 1 (**Comprovado**).
- **Classificação:** **`ESTUDAR COMO REFERÊNCIA`** (e candidato nº 1 para **`ADAPTAR`** apenas se o Timbre precisar de driver virtual pós-MVP; fora do MVP pelo ADR-0004).

### 3.2 `briankendall/proxy-audio-device`
- **URL & SHA:** <https://github.com/briankendall/proxy-audio-device> · `HEAD=d3d8c8c034` (2026-10-18) · rel `v1.1.0.1` · 1.116 stars · 9 contribuidores · ac. 2026-11-21 (**Comprovado**).
- **Funcionalidades e arquitetura:** Driver `AudioServerPlugIn` C++ (`ProxyAudioDevice.cpp` + `AudioRingBuffer.cpp`) que espelha outro dispositivo (para dar controle de volume por software a DACs HDMI/USB sem volume de hardware). **Licença:** **Unlicense** (domínio público). 0 testes, sem CI (**Comprovado**).
- **Issues/PRs:** 32 abertas (#77 conflito ao abrir/fechar UAD LUNA, #60 problemas no Sequoia). PR #74/#78/#79/#80 tratam problemas severos de **drift, descontinuidade de timeline e phase-lock de clock** entre proxy e dispositivo físico (**Comprovado**).
- **Classificação:** **`ESTUDAR COMO REFERÊNCIA`** — As PRs #74–#80 são uma aula prática sobre drift de clock e sincronização de ring buffer entre dispositivos Core Audio; não usar driver virtual no MVP (ADR-0004).

### 3.3 `ExistentialAudio/BlackHole`, `kyleneideck/BackgroundMusic`, `bitgapp/eqMac` e `belugaming/tapline`
- **`ExistentialAudio/BlackHole`** (`HEAD=6008d295ff`, 2026-11-07 · rel `v0.7.1` · 20.088 stars · 21 contribuidores): Driver HAL C puro (`BlackHole.c`, zero dependências externas), 1 teste simples em C, sem CI. **Licença:** **GPL-3.0** no código-fonte + restrição explícita de marca/binários oficiais em `LICENSE` (`BlackHole © 2019–2026 Existential Audio Inc.`). **Issues:** #904 (*Playback impossible on macOS 27*), #903 (falha de verificação de assinatura no 0.7.1). **Classificação:** **`DESCARTAR`** (fora da arquitetura Process Taps do ADR-0004, GPL-3.0 e marca protegida).
- **`kyleneideck/BackgroundMusic`** (`HEAD=8c25450e9b`, 2026-06-10 · rel `v0.5.0` · 19.401 stars · 42 contribuidores): Driver HAL C++ (`BGMDriver`) + app ObjC++/Swift + XPC helper. Tem 24 arquivos de teste + CI, mas acumula **545 issues abertas** (#875 impede display wake, #868 distorce, #867 falha no YouTube Safari) e segue em alpha crônico. **Licença:** **GPL-2.0**. **Classificação:** **`DESCARTAR`** (GPL-2.0 incompatível até com GPL-3.0/MPL-2.0 em combinação direta, arquitetura de driver HAL obsoleta para nosso MVP).
- **`bitgapp/eqMac`** (`HEAD=04e5a3a9bd` 2025-11-02 / release binária `v1.9.2` 2026-09-19 · **Apache-2.0** · 6.836 stars · 15 contribuidores): **Descoberta importante verificada no código:** o repositório open source `bitgapp/eqMac` **não contém Process Taps** (`grep` por `AudioHardwareCreateProcessTap`/`CATapDescription` = 0 ocorrências!). Ele usa o driver Swift `EQMDriver` (`native/driver/Source/`) + `AVAudioEngine` + `CircularBuffer<Float>` (`native/app/Source/Audio/Engine.swift`) + Web UI React/Angular embutida. Recursos de captura por tap (mencionados na release note da `v1.9.2`), mixer avançado e EQ paramétrico pro vivem no lado fechado do eqMac Pro. 0 testes, sem CI, 88 issues abertas. **Classificação:** **`ESTUDAR COMO REFERÊNCIA`** (apenas para ver como `EQMDriver` implementa AudioServerPlugIn em Swift e UX do eqMac; não reutilizar `AVAudioEngine` nem driver no núcleo).
- **`belugaming/tapline`** (`HEAD=9036e352db`, 2026-11-03 · rel `v0.7.0` · **GPL-3.0** · 5 stars · 3 contribuidores): App macOS 15+ (Swift + Process Taps) + Windows (C# + Equalizer APO). `Packages/TaplineCore/` possui **25 arquivos de teste** + CI (`ci.yml`) e cobre `LinearPhaseEQ.swift`, `BinauralIRs.swift`, `RoomAdvisor.swift`, `EQFitter.swift`, `ADI2Preset.swift`, `SpectrumAnalyzer.swift` (PR #33 corrigiu crash abaixo de 40 kHz). **Classificação:** **`ESTUDAR COMO REFERÊNCIA`** em MPL-2.0 (ou **`ADAPTAR`** partes de `TaplineCore` se ADR-0001 for GPL-3.0).

---

## 4. Benchmarks Comerciais (Referência Funcional)

| Produto | Fabricante / Preço | Arquitetura verificada | Capacidades-chave vs Timbre | Fonte e Evidência |
|---|---|---|---|---|
| **SoundSource 6.2.0** | Rogue Amoeba · US$ 49 | Híbrido `ARK.driver` (`AudioServerPlugIn` em `/Library/Audio/Plug-Ins/HAL/`) + `arkaudiod` + Process Taps / `HALS_MultiTap` (substituiu o antigo ACE em 2024; exige senha admin na instalação; conflita com outros utilitários de tap puros) | Mixer por app, AirPlay 2 & Output Groups sincronizados, EQ 10 bandas + Audio Units + Headphone EQ (AutoEq), Quick Configs, Preferred Device Order, Super Volume Keys (DDC/software), Bluetooth Output Only (evita HFP) | Documentação Rogue Amoeba / busca técnica, ac. 2026-11-21 (**Provável**) |
| **Loopback 2.5.1** | Rogue Amoeba · US$ 99 | `ARK.driver` + daemon em background | Criação de dispositivos virtuais compostos com roteamento visual em fios, múltiplos apps/mics, drift correction, fontes ocultas do sistema (Siri, Control Center, VoiceOver) | Documentação Rogue Amoeba, ac. 2026-11-21 (**Provável**) |
| **EQBase** | Bold Biscuit · Freemium (Grátis; Pro US$ 39,99/ano ou US$ 79,99 vitalício) | Swift nativo + Core Audio **Process Taps** (sem driver, macOS 14.4+) | Mixer por app, gravador, 10 bandas (free) até 24 bandas paramétricas + fase linear/dinâmico/convolução/medição de sala (Pro), catálogo com 8.666 perfis do **AutoEq (MIT)** e importação direta de REW/EqualizerAPO | `eqbase.app`, ac. 2026-11-21 (**Provável**) |

---

## Inferences

1. **Topologia de captura comprovada para o Timbre:** A combinação de `CJStanfield/CoreAudioTapKit` (1 aggregate privado + 1 `IOProc` single-clock por dispositivo de saída físico) + padrões de `Sakuleta/tapmix` (`TapPlan`, atomic triple-buffering, `LookaheadLimiter`) valida a direção do ADR-0004 sem precisar de nenhum código GPL.
2. **Camada HAL Swift:** `sbooth/CAAudioHardware` e `orchetect/swift-core-audio` são maduros e ambos **MIT**; vale um spike rápido em E-07 para decidir entre usar `CAAudioHardware` (zero dependências externas além de `CoreAudioExtensions`) ou `swift-core-audio` (Swift 6 `Sendable` completo, DSL de `AudioAggregateDevice.Composition`), importando de `spfk-audio-hardware` apenas a ideia de `AudioBackend` mockável para testes de CI sem hardware físico.
3. **Armadilhas de macOS 26/27 a mitigar no dia 1:** (a) apps VoIP/chamadas com volume esmagado ou distorção cumulativa (`FineTune#483`, `#477`, `tapmix#48`); (b) drop para Bluetooth HFP (16/24 kHz) quebrando spectrum analyzers ou filtros acima de Nyquist (`tapline#PR33`, `MacEQ`); (c) `MediaRemoteUIService` vazando na lista de apps (`FineTune#493`); (d) race conditions em crossfade deixando app silenciado (`FineTune#PR487`).

## Gaps

- Não executamos `swift test` localmente em cada clone desta categoria; a qualidade dos testes foi avaliada por inspeção dos arquivos de teste e `.github/workflows/`.
- Os binários fechados do SoundSource 6.2.0, Loopback 2.5.1, eqMac Pro (v1.9.2) e EQBase não foram disassemblados — a descrição de sua arquitetura baseia-se em documentação oficial e notas técnicas externas (**Provável**).
