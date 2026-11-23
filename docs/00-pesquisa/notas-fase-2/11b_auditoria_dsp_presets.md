# 11b. Auditoria OSS — Motores DSP/EQ, Resamplers, Loudness, AutoEq e Frameworks de Áudio

- **Data de consulta:** 2026-11-21
- **Escopo:** 24 repositórios open source + REW (proprietário freeware) e SoundTouch (LGPL-2.1).
- **Regra de evidência e licença:** Todas as afirmações **Comprovado** foram verificadas nos arquivos-fonte/manifests/workflows locais ou via `gh api` em **2026-11-21**. Classificações principais assumem núcleo **Permissivo / MPL-2.0** (ADR-0001 Opção B).

---

## Takeaway

- **Correção importante ao ADR-0001 verificada no `Cargo.toml`:** Não só o `HEnquist/camilladsp` **v5** (`v5.0.0-beta.2`, `1ea8b9c551`), mas **também a v4.1.3** (`05e9cfcdf4`) já carrega `license = "GPL-3.0-only OR MPL-2.0"`. A diferença estratégica da **v5** é que ela divide `camilladsp-schema` e `camilladsp` como **crates de biblioteca** embutíveis (`src/lib.rs`), usa `CamillaFloat = f64` por padrão, traz `LookaheadLimiter`, biquads **Direct Form II Transposed** com pipeline *skewed* + FMA em aarch64 (6× mais rápido: 249 µs → 39 µs no benchmark oficial), convolução FFT com NEON/AVX e resampler `Slip` + `rubato` **MIT/Apache-2.0**.
- **Motor alternativo em Swift puro (MIT):** `jatinindia/MacEQ` (**MIT**, `043c626043`) é excelente referência/base permissiva para Swift + `vDSP` (`BiquadCoefficients` em `Double` com guarda de Nyquist, `FIRConvolver`, `SpectrumAnalyzer`, `fenv.h` FTZ/DAZ anti-denormal em x86_64, `KernelHolder` com retire-list para não desalocar na thread de áudio). Porém processa amostras em `Float` (Float32 via `vDSP_biquad`) — para **Float64** audiófilo (ADR-0003), `camilladsp` v5 ou `vDSP_biquadD` próprio em C/Swift vence.
- **Loudness EBU R128 / BS.1770-4:** `sdroege/ebur128` (**MIT**, Rust puro, zero deps C, feature `capi`, `241d390ce4`) e `jiixyj/libebur128` (**MIT**, C, `1f3fc73c95`) são ambos **reutilizáveis diretamente**. Atenção crítica à issue `sdroege/ebur128#69` (*True peak under-reads by ~1.8 dB near 20 kHz* no modo padrão de oversampling 4× vs modo preciso).
- **AutoEq & Presets:** `jaakkopasanen/AutoEq` (**MIT**, `7ae0f56d53`) é a fonte canônica de medições/perfis (`results/`) e otimizador PEQ (`autoeq/peq.py`). Para visualização de curva de EQ interativa em docs/web ou port de matemática SVG para SwiftUI Canvas, `NumberOneBot/dsssp` (**MIT**, `860b891895`) é referência direta.
- **Armadilhas de licença:** `fxsound2/fxsound-app` e `juce-framework/JUCE` (sem licença comercial) são **AGPL-3.0**; `james34602/JamesDSPManager` **não tem arquivo `LICENSE`** no repo (`NONE`); `chirlu/soxr` é **LGPL-2.1** e `lsp-plugins/lsp-plugins` é **LGPL-3.0** (exigiriam dylib substituível pelo usuário se linkados — evitáveis tendo `rubato` MIT/Apache-2.0 e `camilladsp` MPL-2.0).

---

## 1. Motores DSP / EQ Dedicados

### 1.1 `HEnquist/camilladsp` (v4.1.3 e v5.0.0-beta.2)
- **URL & SHA:** <https://github.com/HEnquist/camilladsp> · v4.1.3 `HEAD=05e9cfcdf4` (2026-04-09) · v5 `v5.0.0-beta.2` `1ea8b9c551` (2026-10-19) · 1.110 stars · 14 contribuidores (`HEnquist` 1.627/1.746 commits — bus factor = 1) · ac. 2026-11-21 (**Comprovado**).
- **Funcionalidades verificadas no código:** Motor completo em Rust (`f64` `CamillaFloat` default; `f32` só via `RUSTFLAGS="--cfg camillafloat_f32"`): Biquads (peaking, shelves, Butterworth/Linkwitz-Riley/Bessel crossovers, Notch, Allpass, `DiffEq` Direct Form II Transposed), convolução FFT particionada com kernels NEON (`src/filters/fftconv_neon.rs`) e AVX (`fftconv_avx.rs`), `LookaheadLimiter` (v5, single e multicanal), `Loudness` com shelves configuráveis (`low_freq`, `high_freq`, `low_q`, `high_q`), compressor, noise gate, TPDF dither, mixer matrix, resampler `rubato` + novo resampler `Slip` para clock drift barato, analisador de espectro (`src/spectrum.rs`) e schema YAML/JSON (`camilladsp-schema`) (**Comprovado**).
- **Arquitetura e técnicas:** No v5 (`README.crates.md`), `camilladsp` e `camilladsp-schema` são crates utilizáveis em 3 níveis: motor completo (com `coreaudio_backend`), apenas `pipeline`/`processing`, ou filtros individuais (`filters::biquad`, `filters::fftconv`). Coeficientes `BiquadCoefficients` são sempre calculados em `f64` em `camilladsp-schema` antes de ir ao runtime. v5 introduziu cascata de biquads *skewed* + FMA em `aarch64` (**Comprovado**).
- **Módulos reaproveitáveis:** `camilladsp-schema/src/filters/biquad.rs`, `src/filters/biquad.rs`, `src/filters/fftconv.rs`, `src/filters/fftconv_neon.rs`, `src/filters/dither.rs`, `src/filters/loudness.rs`, `src/processors/lookahead_limiter.rs` (**Comprovado**).
- **Licença e obrigações:** **`GPL-3.0-only OR MPL-2.0`** (tanto na v4.1.3 quanto na v5.0.0-beta.2, verificado em `Cargo.toml`!). Escolhendo **MPL-2.0**, modificações em arquivos do CamillaDSP continuam MPL-2.0 e podem ser linkadas em um binário Swift/MPL-2.0 ou proprietário futuro, compatível com App Store (**Comprovado**).
- **Testes e CI:** Excelente: **87 arquivos de teste/testdata** na v5, `benches/` com Criterion (`biquad_canon`, `fftconv_kernels`, `pipeline`, `filters`) + 7 workflows CI incluindo **`e2e_coreaudio.yml`**! (**Comprovado**).
- **Issues/PRs e riscos:** 45 abertas (mostly ALSA/PipeWire Linux). **Risco declarado em `README.crates.md`:** audiência primária ainda é o binário CLI; **sem semver garantido na API de biblioteca** (pinar commit/versão exata) e bus factor = 1 (**Comprovado**).
- **Classificação:** **`ADAPTAR`** (ou **`REUTILIZAR DIRETAMENTE`** via crate `camilladsp` v5 + wrapper FFI C/Swift-Rust pinado em versão exata) — Candidato nº 1 do ADR-0003 para motor DSP em Float64 se E-06 confirmar latência/ergonomia de FFI.

### 1.2 `jatinindia/MacEQ`
- **URL & SHA:** <https://github.com/jatinindia/MacEQ> · `HEAD=043c626043` (2026-11-01) · rel `v1.4.1` · 14 stars · 1 contribuidor (48 commits) · ac. 2026-11-21 (**Comprovado**).
- **Funcionalidades verificadas no código:** App macOS SwiftPM (`MacEQ` + `MacEQCore`) com captura via Process Taps, EQ paramétrico + importador EqualizerAPO (`APOConfig.swift`), convolutor FIR (`FIRConvolver.swift`), isolamento de voz (`VoiceIsolator.swift`), `SpectrumAnalyzer.swift` via `vDSP_DFT_zrop` (**Comprovado**).
- **Arquitetura e técnicas:** `BiquadCoefficients.swift` calcula coeficientes RBJ em `Double` com **proteção explícita de Nyquist** (`frequency < sampleRate / 2` para não explodir quando fones BT caem para 16/24 kHz em HFP). `AudioTapEngine.swift` executa `_FE_DFL_DISABLE_SSE_DENORMS_ENV` por callback (evita pico de CPU em x86_64 durante silêncio após 0,6 s!) e usa `KernelHolder` com retire-list para que o thread de áudio nunca libere memória. Processamento usa `vDSP_biquad` (Float32) e `vDSP_vrampmul` para rampa de ganho (**Comprovado**).
- **Módulos reaproveitáveis:** `Sources/MacEQCore/BiquadCoefficients.swift`, `APOConfig.swift`, `FIRConvolver.swift`, `SpectrumAnalyzer.swift`, padrão `disableDenormalsOnCurrentThread` e `KernelHolder` em `Sources/MacEQ/AudioTapEngine.swift` (**Comprovado**).
- **Licença:** **MIT** (`LICENSE`). Compatível com MPL-2.0 e App Store (**Comprovado**).
- **Testes e CI:** 1 runner de testes (`Tests/MacEQTests/main.swift`), sem CI (**Comprovado**).
- **Issues/PRs e riscos:** 3 abertas, destaque para **#3** (*Zoom audio cuts out after ~1 second when MacEQ is running*), PR #1 sobre validação de input APO. Bus factor = 1 (**Comprovado**).
- **Classificação:** **`ADAPTAR`** — Excelente biblioteca de referência prática MIT em Swift (`MacEQCore`) para parser APO, guarda de Nyquist, FTZ/DAZ e FFT via `vDSP` (se o DSP fosse Swift; se usarmos CamillaDSP v5, ainda vale adaptar `APOConfig`, `SpectrumAnalyzer` e `disableDenormals`).

### 1.3 `Torteous44/radioform`
- **URL & SHA:** <https://github.com/Torteous44/radioform> · `HEAD=fdf98d4dca` (2026-07-21) · tag `v2.1.4` · 174 stars · 4 contribuidores · ac. 2026-11-21 (**Comprovado**).
- **Funcionalidades e arquitetura:** Driver virtual + motor DSP C++ próprio (`packages/dsp/src/biquad.cpp`, `engine.cpp`, `smoothing.h`, `limiter.h`, `dc_blocker.h`) + bridge ObjC++ (`RadioformDSPEngine.mm`) + SwiftUI. Processamento em **Float32** (`struct BiquadCoeffs { float b0, b1, b2; float a1, a2; }`) (**Comprovado**).
- **Licença:** **GPL-3.0**. **Testes e CI:** 10 arquivos de teste C++ (`test_biquad.cpp`, `test_smoothing.cpp`, `test_frequency_response.cpp`, `test_preset.cpp`) + `ci.yml` (**Comprovado**).
- **Issues críticas:** **#84** (*Treble roll-off for about 55 s after playback starts* causado por interpolação linear na compensação de drift entre driver e saída física!). PRs #79/#80 de AutoEq fechados (**Comprovado**).
- **Classificação:** **`ESTUDAR COMO REFERÊNCIA`** — GPL-3.0, usa driver virtual + Float32; ótimo para estudar os testes de resposta em frequência (`test_frequency_response.cpp`) e a lição da issue #84.

### 1.4 `denzam/SystemEQ-for-Mac`
- **URL & SHA:** <https://github.com/denzam/SystemEQ-for-Mac> · `HEAD=a6a62b1565` (2026-11-04) · rel `v1.4.9` · 64 stars · 3 contribuidores (`denzam` 297/303 commits) · ac. 2026-11-21 (**Comprovado**).
- **Funcionalidades e arquitetura:** EQ de sistema via Process Taps (`ProcessTapEngine.swift`, `SPSCRingBuffer.swift`, `RealtimeThread.swift`), biquads via `vDSP_biquad` (`BiquadFilterVDSP.swift` + `OutputSafetyProcessor` com boost até 12 dB e ceiling `0.891`), base AutoEq (`Scripts/generate_autoeq_index.swift`), **calibração auditiva/equal-loudness estilo Neutralizer** e sala (`CalibrationEngine.swift`, `PersonalizedHearingProfile.swift`, `SineSweepGenerator.swift`, `PinkNoiseGenerator.swift`), além de visualizador ProjectM helper via IPC (**Comprovado**).
- **Licença:** **GPL-3.0**. **Testes e CI:** 34 arquivos de teste/scripts (`EQDatabaseTest.swift`, `benchmark_dsp.swift`, `measure_loopback_latency.swift`, `test_ipc_server.swift`) + 4 workflows CI (**Comprovado**).
- **Issues/PRs:** #36 (Auto Preamp em perfis de calibração), PR #37 corrigiu crash de sweep/test tone em saídas com >2 canais (**Comprovado**).
- **Classificação:** **`ESTUDAR COMO REFERÊNCIA`** — GPL-3.0, mas o módulo de calibração auditiva relativa + sweeps + scripts de benchmark de latência loopback são referências preciosas de estudo para o Timbre.

### 1.5 `brimell/SoundMaxx` e `snap-sites/SoundMax`
- **`brimell/SoundMaxx`** (`HEAD=7526cf3d2f`, 2026-04-23 · rel `v1.4.0` · **MIT** · 25 stars · 1 contribuidor): Evolução de `snap-sites/SoundMax` (`HEAD=92ec4e1f5d`, 2025-12-31 · **MIT** · 61 stars). Usa `AudioUnit` + `RingBuffer` (não Process Taps) para rotear entrada virtual/dispositivo com biquads Swift (`BiquadFilter.swift`), AutoEQ, `SpectrumAnalyzer` e `DeviceProfile`. **0 testes, sem CI** (**Comprovado**).
- **Classificação:** **`ESTUDAR COMO REFERÊNCIA`** (ou `DESCARTAR` para captura; no máximo referência simples MIT de UI/modelos de `AutoEQManager`/`DeviceProfile`, já que não usa taps nem tem testes).

### 1.6 `NumberOneBot/dsssp`
- **URL & SHA:** <https://github.com/NumberOneBot/dsssp> · `HEAD=860b891895` (2026-08-12) · rel `v0.8.0` · 80 stars · 1 contribuidor · ac. 2026-11-21 (**Comprovado**).
- **Funcionalidades e arquitetura:** Biblioteca React/TypeScript + SVG puro para **gráficos interativos de resposta em frequência de biquads** (`FrequencyResponseGraph`, `CompositeCurve`, `FilterCurve`, `FilterPoint`, `FilterGradient`, `PointerTracker`) com arrasto, scroll de Q e transições animadas. 2 arquivos de configuração Vitest + CI Storybook (`storybook.yml`, `ci.yml`) (**Comprovado**).
- **Licença:** **MIT**. **Classificação:** **`ESTUDAR COMO REFERÊNCIA`** (e **`REUTILIZAR DIRETAMENTE`** se o site/playground web do design system tiver demo interativa de EQ; no app nativo SwiftUI, portar a matemática da resposta composta para `Canvas`/Metal).

### 1.7 `wwmm/easyeffects`, `lsp-plugins/lsp-plugins`, `fxsound2/fxsound-app`, `james34602/JamesDSPManager`
- **`wwmm/easyeffects`** (`HEAD=b66a890c05`, 2026-11-20 · tag `v8.3.2` · **GPL-3.0** · 10.529 stars · 100+ contribuidores · 284 issues abertas): Suíte DSP completa para PipeWire (Linux), agora migrando UI para Qt/QML. Incompatível com macOS (depende de PipeWire/LADSPA/LV2/Linux) e GPL-3.0. **Classificação:** **`ESTUDAR COMO REFERÊNCIA`** (para UX de loudness/autogain/crossfeed, nunca código).
- **`lsp-plugins/lsp-plugins`** (`HEAD=5dc3474fa7`, 2026-10-31 · rel `1.2.37` · **LGPL-3.0** · 913 stars · 21 contribuidores): Coleção de plugins C++ de estúdio (dependências modulares via `modules.mk`). LGPL-3.0 exige vínculo dinâmico/substituível e foco é DAW Linux/VST3/LV2 (issue #637 documenta suporte experimental macOS). **Classificação:** **`DESCARTAR`** (complexidade de build e LGPL-3.0 desnecessárias quando temos CamillaDSP MPL-2.0).
- **`fxsound2/fxsound-app`** (`HEAD=d6d5b740f3`, 2026-11-13 · **AGPL-3.0** · 4.769 stars · 184 issues): App Windows (DfxInstall / AudioPassthru C++), tem golden harness em `web/dsp-tutorial/tests/golden/`, mas é **AGPL-3.0** e acoplado ao Windows. **Classificação:** **`DESCARTAR`** (apenas referência do padrão de golden tests).
- **`james34602/JamesDSPManager`** (`HEAD=5aed6a4a9a`, 2025-06-18 · 1.005 stars · 35 issues): Repo Android com VM EEL2, convolver particionado e EQ FIR/IIR, **sem arquivo `LICENSE` (`NONE`)** e 0 testes/CI. **Classificação:** **`DESCARTAR`**.

---

## 2. Resamplers, Loudness (EBU R128) e Presets (AutoEq / REW)

### 2.1 `HEnquist/rubato`, `avaneev/r8brain-free-src` e `chirlu/soxr`
- **`HEnquist/rubato`** (<https://github.com/HEnquist/rubato> · `HEAD=f8711e2252`, 2026-11-12 · rel `v5.1.0` · 374 stars · 13 contribuidores): Resampler em **Rust puro** (`f32`/`f64`, sinc, polinomial rápido e assíncrono por razão ajustável em runtime — já integrado ao `camilladsp` v5). **Licença:** **`MIT OR Apache-2.0`** (o GitHub API reporta `NOASSERTION` apenas por ser dual-license, verificado em `LICENSE.txt`). Possui benchmarks Criterion e exemplos, mas sem diretório `tests/` separado no clone (testes unitários inline nos módulos `src/*.rs` — `não verificado` via `cargo test` nesta rodada). **Classificação:** **`REUTILIZAR DIRETAMENTE`** (vem junto com `camilladsp` v5 ou standalone via FFI).
- **`avaneev/r8brain-free-src`** (<https://github.com/avaneev/r8brain-free-src> · `HEAD=5792291ad6`, 2026-11-11 · tag `version-6.5` · **MIT** · 760 stars · 1 contribuidor `avaneev`): Resampler C++ header-only de altíssima qualidade (64-bit double, linear-phase/minimum-phase). **Ressalva crítica no header `CDSPResampler.h`:** usa caches globais estáticos para FFT/filtros; latência de filtro linear-phase pode ser maior que interpoladores assíncronos curtos; 5 arquivos em `bench/`, sem CI. **Classificação:** **`ESTUDAR COMO REFERÊNCIA`** (superado pela integração nativa de `rubato` + `Slip` dentro do `camilladsp` v5).
- **`chirlu/soxr`** (<https://github.com/chirlu/soxr> · `HEAD=945b592b70`, **2018-02-24** · tag `0.1.3` · **LGPL-2.1** · 185 stars · 15 issues): Biblioteca C clássica do SoX com 41 arquivos de teste, porém **sem commits desde 2018** e sob **LGPL-2.1** (exige linkagem dinâmica/relinkável). **Classificação:** **`DESCARTAR`**.

### 2.2 `sdroege/ebur128`, `jiixyj/libebur128` e `csteinmetz1/pyloudnorm`
- **`sdroege/ebur128`** (<https://github.com/sdroege/ebur128> · `HEAD=241d390ce4`, 2026-10-27 · tag `0.1.11` · **MIT** · 135 stars · 10 contribuidores): Port completo em **Rust seguro** da `libebur128` (EBU R128: Momentary 0,4 s, Short-term 3 s, Integrated com gating, LRA, Sample Peak, True Peak), feature opcional `capi` para expor header C (`assets/ebur128.h`), **10 arquivos de teste + benchmarks + CI**. **Bug conhecido a observar:** issue **#69** aponta que o modo True Peak padrão (oversampling 4× com filtro de 49 taps) pode subestimar picos em até ~1,8 dB próximo de 20 kHz (**Comprovado**). **Classificação:** **`REUTILIZAR DIRETAMENTE`** (combinado ao motor Rust/FFI, validando True Peak contra o modo preciso/oversampling maior).
- **`jiixyj/libebur128`** (<https://github.com/jiixyj/libebur128> · `HEAD=1f3fc73c95`, 2026-11-19 · tag `v1.2.6` · **MIT** · 498 stars · 20 contribuidores): Implementação C canônica EBU R128 com **11 arquivos de teste incluindo arquivos WAV oficiais da EBU** (`ebur128-test.ebu_files.cpp`) + CI (`build.yml`). 34 issues abertas (#133 oversample rates, #126 true peak edge case). **Classificação:** **`REUTILIZAR DIRETAMENTE`** (caso o módulo de medição rode direto em Swift/C sem depender do grafo Rust) ou **`ESTUDAR COMO REFERÊNCIA`** (usando os vetores EBU para validar `sdroege/ebur128`).
- **`csteinmetz1/pyloudnorm`** (<https://github.com/csteinmetz1/pyloudnorm> · `HEAD=b8d67bfd3c`, 2026-01-04 · rel `v0.2.0` · **MIT** · 795 stars · 6 contribuidores): Biblioteca Python (ITU-R BS.1770-4, 23 arquivos de teste com WAVs de conformidade ITU + CI). Inadequada para runtime em produção macOS, mas excelente **oráculo de testes golden em Python/CI** (**Comprovado**). **Classificação:** **`ESTUDAR COMO REFERÊNCIA`** (para scripts de geração/validação offline de vetores golden).

### 2.3 `jaakkopasanen/AutoEq` e REW (Room EQ Wizard)
- **`jaakkopasanen/AutoEq`** (<https://github.com/jaakkopasanen/AutoEq> · `HEAD=7ae0f56d53` code / pushes de dados até 2026-11-05 · tag `4.1.2` · **MIT** · 16.476 stars · 18 contribuidores): Repositório oficial com milhares de medições de fones (`results/`) e formatos `ParametricEQ.txt` (EqualizerAPO), `GraphicEQ.txt` (127 bandas) e `FixedBandEQ.txt`, além do otimizador SLSQP (`autoeq/peq.py`) e testes `pytest` (`tests/test_autoeq.py`) (**Comprovado**). **Classificação:** **`REUTILIZAR DIRETAMENTE`** (como catálogo de dados/perfis empacotado/indexado sob MIT — nunca copiando o script Python para o app, e sim gerando o índice de presets no build conforme ADR-0009).
- **REW (Room EQ Wizard)** (`roomeqwizard.com`, ac. 2026-11-21 · **Proprietário freeware** + Pro pago; algoritmo FSAF sob GPLv3+): Padrão de mercado em macOS/Java para medição de sala e exportação de PEQ no formato texto EqualizerAPO (`Filter N: ON PK Fc ...`) ou IR WAV (**Provável**). **Classificação:** **`ESTUDAR COMO REFERÊNCIA`** (suportar importação/exportação do formato de texto genérico do REW/EqualizerAPO conforme ADR-0009, sem nenhuma dependência de código).

---

## 3. Frameworks Gerais de Áudio e Concorrência/Time-Stretching

| Projeto | URL & SHA (ac. 2026-11-21) | Licença | Métricas & Testes | Análise Técnica | Classificação |
|---|---|---|---|---|---|
| **`AudioKit/AudioKit`** | <https://github.com/AudioKit/AudioKit> · `c358c15fdc` (2026-07-26) · rel `5.7.2` | **MIT** | 11.507 stars · 100+ contrib · 71 arqs teste + CI | Wrapper alto nível sobre `AVAudioEngine` / `AVAudioUnit` (`ParametricEQ`, `PeakLimiter`, `Mixer`, `FFTTap`). Issues #2968/#3020 mostram overhead e ciclo de vida de `AVAudioEngine`/`BaseTap`. Inadequado para callbacks RT HAL `IOProc` sem `AVAudioEngine` (ADR-0004). | **`DESCARTAR`** (no motor RT; estudar apenas se precisar utilitários de arquivo offline) |
| **`sbooth/SFBAudioEngine`** | <https://github.com/sbooth/SFBAudioEngine> · `41196de9db` (2026-11-19) · rel `0.15.0` | **MIT** | 718 stars · 9 contrib · 1 arqs teste + CI (C++ linter + Swift) | Player/decoder/encoder áudio completo em ObjC++/Swift (FLAC, DSD/DoP, ReplayGain em `SFBReplayGainAnalyzer.mm`, converter). Excelente para reprodução de arquivos locais de referência/teste A/B ou análise offline. | **`ESTUDAR COMO REFERÊNCIA`** (ou **`ADAPTAR`** para player de calibração/teste A/B se necessário) |
| **`grame-cncm/faust`** | <https://github.com/grame-cncm/faust> · `e3665b800a` (2026-11-20) · rel `2.88.0` | **LGPL-2.1** (compilador; código gerado tem exceção/licença própria conforme DSP; `architecture/AU` usa headers Apple) | 3.216 stars · 100+ contrib · 1.281 arqs teste + 6 CI | DSL funcional DSP compilando para C++/Rust/LLVM. Issue #1251 aberta sobre falta de arquitetura SwiftUI macOS moderna. Pesado demais para o que queremos (biquads/FIR já existem no CamillaDSP v5). | **`DESCARTAR`** (a menos que surjam efeitos experimentais futuros gerados offline) |
| **`juce-framework/JUCE`** | <https://github.com/juce-framework/JUCE> · `654bdbc7a9` (2026-11-19) · rel `9.0.6` | **AGPL-3.0 OR Comercial** | 9.164 stars · 48 contrib · 255 arqs teste + CI | Framework C++ completo para DAWs/plugins. **AGPL-3.0** é incompatível com nosso núcleo MPL-2.0/MIT (e obriga abrir código até de serviços de rede); licença comercial paga desnecessária. | **`DESCARTAR`** |
| **SoundTouch** (`surina.net/soundtouch`) | `surina.net` (não no GitHub oficial; mirrors verificados via busca) | **LGPL-2.1** (ou comercial paga) | `não verificado` localmente | Biblioteca C++ para time-stretch / pitch-shift. Irrelevante para EQ/mixer audiófilo em tempo real (que não altera pitch/tempo) e LGPL-2.1 adiciona atrito de linkagem. | **`DESCARTAR`** |

---

## Inferences

1. **Escolha do motor DSP (para validar em E-06):**
   - **Caminho principal (Rust FFI):** **`HEnquist/camilladsp` v5 (`MPL-2.0`)** + **`HEnquist/rubato` (`MIT/Apache-2.0`)** + **`sdroege/ebur128` (`MIT`)** entrega tudo em **Float64** com filtros biquad/FIR/loudness/lookahead-limiter/dither e medição EBU R128 auditados, com zero contaminação GPL. Único cuidado: pinar commit exato da v5 (sem semver de lib) e testar ergonomia de bridging Swift ↔ C-ABI ↔ Rust no Xcode/SwiftPM.
   - **Caminho secundário (Swift + C puro, se FFI Rust gerar atrito no E-06):** Adaptar `jatinindia/MacEQ` (`MacEQCore`, **MIT**) reescrevendo o kernel de `vDSP_biquad` (Float32) para `vDSP_biquadD` (Float64) + `jiixyj/libebur128` (**MIT**, C) + `Sakuleta/tapmix` (`LookaheadLimiter`, **MIT**).
2. **Testes golden:** Combinar os vetores EBU de `jiixyj/libebur128` (`ebur128-test.ebu_files.cpp`), os testes de resposta em frequência de `Torteous44/radioform` (ideia, sem copiar GPL) e `csteinmetz1/pyloudnorm` como referência de CI.

## Gaps

- Os 41 arquivos de teste do `camilladsp` v5, `rubato` e `sdroege/ebur128` não foram executados localmente com `cargo test` durante a auditoria (`não medido`).
- `SoundTouch` foi avaliado via documentação oficial/busca (não clonado de repositório upstream Codeberg/GitLab).
- O comportamento exato do bug de zoom/taps (`jatinindia/MacEQ#3`) e do under-read de True Peak (`sdroege/ebur128#69`) precisa de verificação prática no laboratório (E-04 / E-06).
