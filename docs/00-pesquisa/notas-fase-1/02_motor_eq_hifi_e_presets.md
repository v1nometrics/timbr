# HiFi EQ/DSP engine for a macOS notch app, and the open preset and headphone-correction ecosystem (as of Nov 21, 2026)

Scope: DSP engine quality, open-source engines to study or embed, bit-perfect and sample-rate behaviour, correction data and targets, preset formats, AU hosting, and extra audiophile DSP. Audio interception and routing are out of scope (another researcher covers them).
Method: primary sources wherever possible. These were GitHub repos read with the GitHub API on 2026-11-21 (license, language, last push, releases, source code), the local macOS 27.0 SDK headers (`MacOSX27.0.sdk`), vendor documentation, and papers. Forum and secondary claims are labelled as such.

---

## 1. DSP quality fundamentals: filter design, phase, precision, headroom, dither, latency

### Takeaway
Respected engines all build parametric EQ from cascaded second-order sections (biquads). The baseline is RBJ-cookbook coefficients computed in double precision, run in a transposed/direct form with 64-bit state (CamillaDSP default; Roon "64-bit expansion"), with a negative preamp sized to the maximum boost. Engines that care about the top octave either oversample ("decramp", as in LSP) or use analog-matched designs (Orfanidis, Vicanek, or FabFilter's "Zero Latency/Natural Phase" analog matching) to avoid the bilinear-transform "cramping" near Nyquist. Linear-phase FIR is offered as an option, not as the default. FabFilter's own documentation says it is "not better or more transparent… it is different", and it costs pre-ringing plus 70–116 ms of latency.

### Cited Findings

**Biquad design (RBJ / bilinear transform) and its limits**
- The RBJ "Audio EQ Cookbook" is now a W3C Working Group Note dated 08 June 2021, edited by Raymond Toy (Google) and adapted from Robert Bristow-Johnson's text "with permission". It defines LPF, HPF, BPF (2 variants), Notch, APF, Peaking EQ, Low/High shelf. All filters are "digitized using the Bilinear Transform (BLT)", with frequency prewarping and "bandwidth readjustment" because "the bandwidth is compressed when mapped from analog to digital using the BLT". — [W3C Audio EQ Cookbook](https://www.w3.org/TR/audio-eq-cookbook/)
- Cookbook parameter definitions: for peaking EQ the "classic Q" is A·Q, so a boost and an equal cut with the same Q/f0 cancel to flat. BW is in octaves, measured between the −3 dB points for BPF/notch and between the midpoint (dBgain/2) frequencies for peaking. The shelf slope S = 1 is the steepest slope that stays monotonic. — [W3C Audio EQ Cookbook](https://www.w3.org/TR/audio-eq-cookbook/)
- Martin Vicanek, "Matched Second Order Digital Filters" (14 Feb 2016): "One problem with the BLT is frequency warping towards the Nyquist frequency. For a lowpass filter with a resonant peak the result is a steeper than nominal (12 dB/octave) falloff for high cutoff frequencies, and a narrowing of the resonant peak. Similar effects are present for other standard filter types. Oversampling provides remedy but at a high CPU cost." — [Vicanek PDF](https://vicanek.de/articles/BiquadFits.pdf)
- Vicanek's method maps the poles by impulse invariance (z = e^(sT)) and solves the zeros in closed form to match the analog magnitude at DC, at the centre frequency and at Nyquist. It covers lowpass, highpass, bandpass and **peaking EQ** (the outline has no shelves), and is meant to allow "near sample rate updating" (smooth modulation). The paper also reviews Orfanidis' peaking EQ, which "matches closely that of its analog counterpart throughout the Nyquist interval and does not suffer from the prewarping effect of the bilinear transformation near the Nyquist frequency", and Massberg's method. — [Vicanek PDF](https://vicanek.de/articles/BiquadFits.pdf)
- The LSP Parametric Equalizer exposes the design choice per band:
  - Filter classes: RLC, BWC (Butterworth-Chebyshev), LRX (Linkwitz-Riley) and APO ("digital biquad filters derived from canonic analog biquad prototypes digitalized through Bilinear transform", modelled on EqualizerAPO).
  - Transforms: BT (bilinear), MT (matched Z-transform) or DR (direct design "without performing transforms").
  - The manual warns that BT "distorts the form of the filter's curve" towards high frequencies ("cramping": a BT low-pass is −∞ dB at Nyquist). It warns that MT "can alias at high frequencies… not audible in most cases".
  - A "Decramp" control oversamples to a target rate (a multiple of 44.1 kHz) "to minimize cramping".
  
  — [LSP Para EQ manual](https://lsp-plug.in/?page=manuals&section=para_equalizer_x16_stereo)
- FabFilter Pro-Q has three modes. "Zero Latency" matches "the magnitude response of analog EQing as closely as possible" with no latency. "Natural Phase" also "closely matches the analog phase response", with only a "very small, inaudible deviation above 20 kHz". "Linear Phase" changes only magnitude. Pro-Q 4 release notes cite "better analogue matching in Zero Latency and Natural Phase modes" and "greater precision for Linear Phase". — [FabFilter Pro-Q processing modes](https://www.fabfilter.com/help/pro-q/using/processingmode); [FabFilter Pro-Q 4 release news](https://www.fabfilter.com/news/1733994000/fabfilter-releases-pro-q-4-equalizer-plug-in). An older help page states a deviation above 18 kHz for Zero Latency (minor source conflict, same help page set).

**Minimum-phase IIR vs linear-phase FIR vs mixed; pre-ringing; latency**
- Pro-Q's Linear Phase latency: Low resolution is 3072 samples (~70 ms @ 44.1 kHz) and Medium is 5120 samples (~116 ms). FabFilter states "linear-phase processing is not better or more transparent than normal processing, it is different!" and calls it a problem-solving tool, mainly for avoiding phase-cancellation problems. — [FabFilter Pro-Q processing modes](https://www.fabfilter.com/help/pro-q/using/processingmode)
- FabFilter: pre-ringing is negligible with subtle EQ but "with higher Q values, steep filter slopes and large gain changes the effect will be more audible". — [FabFilter Learn: linear-phase EQ](https://www.fabfilter.com/learn/equalization/linear-phase-eq/)
- Head-Fi argument (forum opinion): headphone frequency-response deviations are largely minimum-phase themselves, so minimum-phase EQ is the natural correction. Phase shift in normal amounts is benign, while audible pre-ringing is the bigger problem. — [Head-Fi: linear vs minimum phase EQ](https://www.head-fi.org/threads/linear-phase-vs-minimum-phase-eq-for-powerful-and-tight-bass-boost.616153)
- LSP offers IIR ("does not add noticeable latency" in most cases), linear-phase FIR/FFT ("adds noticeable latency"), SPM (spectral magnitude processing) and minimum-phase FIR/FFT/SPM variants. It notes that IIR "never can have linear phase characteristic while performing realtime processing". — [LSP Para EQ manual](https://lsp-plug.in/?page=manuals&section=para_equalizer_x16_stereo)
- AutoEq's constants set `DEFAULT_PHASE = 'minimum'`, `DEFAULT_FS = 44100` and `DEFAULT_BIT_DEPTH = 16`. The phase default is used for its convolution/FIR output; how the other two are used was not traced in code. — [AutoEq constants.py](https://github.com/jaakkopasanen/AutoEq/blob/master/autoeq/constants.py)
- CamillaDSP convolution is FFT-based with FFT length 2×chunksize. It switches to segmented (partitioned) convolution when the FIR is longer than the chunk, and a smaller chunk means lower latency but more CPU. Pipeline latency can reach "(2 + queuelimit) * chunksize". — [CamillaDSP README](https://github.com/HEnquist/camilladsp/blob/master/README.md)

**Numeric precision (32 vs 64-bit), structure, coefficient updates**
- CamillaDSP "converts the samples to 64-bit floats (or optionally 32-bit)", and internal processing defaults to 64-bit floats. — [CamillaDSP README](https://github.com/HEnquist/camilladsp/blob/master/README.md)
- CamillaDSP 5.0 changes (beta, Oct 2026):
  - "Configuration values and filter coefficient math are now always 64-bit, independent of the processing precision… This noticeably improves f32 accuracy for low-frequency biquads."
  - Biquads use fused multiply-add where available (~18% faster on aarch64, "rounds once instead of twice").
  - The DiffEq filter "is now a direct form 2 transposed structure, the same form the biquads use".
  - Biquads are run "several at a time".
  
  — [CamillaDSP CHANGELOG_5.0_details](https://github.com/HEnquist/camilladsp/blob/v5.0.0-beta.2/CHANGELOG_5.0_details.md); [v5.0.0-beta.1 release](https://github.com/HEnquist/camilladsp/releases/tag/v5.0.0-beta.1)
- Apple CoreAudio mailing list (2016): a single-precision DF2T biquad is "probably adequate for most cases", but cascading several sections can raise noise issues at low-frequency settings. `vDSP_biquadD()` is the double-precision drop-in. — [coreaudio-api list, Dec 2016](https://lists.apple.com/archives/coreaudio-api/2016/Dec/msg00017.html)
- Wikipedia (secondary): floating-point implementations usually prefer the transposed forms, and direct-form round-off noise grows with Q. — [Digital biquad filter](https://en.wikipedia.org/wiki/Digital_biquad_filter). An XMOS app note treats double-precision float as "to all intents and purposes equal to a mathematical real value" when benchmarking biquad noise. — [XMOS AN02004](https://www.xmos.com/documentation/XM-015057-AN/pdf/an02004_v1.1.0.pdf)
- Accelerate (macOS 27.0 SDK `vDSP.h`, verified locally):
  - `vDSP_biquad` (Float) and `vDSP_biquadD` (Double) for single-channel use.
  - `vDSP_biquadm` / `vDSP_biquadm_CreateSetupD` for multichannel. `vDSP_biquad_CreateSetup` takes **double** coefficients even for the float filter.
  - `vDSP_biquad_SetCoefficientsDouble/Single` update coefficients in place.
  - `vDSP_biquadm_SetTargetsDouble[D]` sets *target* coefficients with `interp_rate`/`interp_threshold`. This is built-in coefficient interpolation for zipper-free parameter changes.
  
  — [Apple: vDSP_biquadD](https://developer.apple.com/documentation/accelerate/vdsp_biquadd); [Apple: vDSP_biquadm_SetTargetsDoubleD](https://developer.apple.com/documentation/accelerate/vdsp_biquadm_settargetsdoubled); [Apple vDSP biquad guide (archived)](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/vDSP_Programming_Guide/UsingBiquadraticFilterFunctions/UsingBiquadraticFilterFunctions.html). An older forum reply says the single-channel double setup lacked a coefficient setter (the workaround was `vDSP_biquadm_SetCoefficientsDoubleD`). The current SDK has `vDSP_biquad_SetCoefficientsDouble`, so that reply looks dated. — [Apple Developer Forums 708528](https://developer.apple.com/forums/thread/708528)
- EqualizerAPO upstream (v1.4.2, 2025-03-21) ships "x64" builds, which refers to the architecture, not double-precision DSP. A third-party fork, TheFireKahuna/equalizerAPO64, advertises "internal double precision processing (64 bit)" and AVX2/AVX-512 builds that are installed by overwriting the official DLL. — [EqualizerAPO files (SourceForge)](https://sourceforge.net/projects/equalizerapo/files/); [equalizerAPO64 fork](https://github.com/TheFireKahuna/equalizerAPO64)
- Roon: when Parametric EQ is enabled, Roon "will perform the 64bit expansion process even if all of the bands are left flat" (Roon staff, community thread). — [Roon community: flat EQ shows clipping](https://community.roonlabs.com/t/bug-enabling-flat-eq-shows-clipping/101395)

**Headroom, preamp, inter-sample peaks, limiting**
- EqualizerAPO convention: `Preamp: <negative number> dB` at the top of the config. — [EqualizerAPO Configuration reference](https://sourceforge.net/p/equalizerapo/wiki/Configuration%20reference/)
- AutoEq computes the preamp with `PREAMP_HEADROOM = 0.2` dB of extra margin. — [AutoEq constants.py](https://github.com/jaakkopasanen/AutoEq/blob/master/autoeq/constants.py)
- eqMac's Basic EQ sets `globalGain = -highestGain` (auto preamp equal to the largest band boost) on Apple's AVAudioUnitEQ. — [eqMac BasicEqualizer.swift](https://github.com/bitgapp/eqMac/blob/master/native/app/Source/Audio/Effects/Equalizers/Basic/BasicEqualizer.swift)
- FineTune clamps the imported preamp to ±30 dB. It applies the preamp before the biquad cascade, and a "bypass preamp, rely on limiter" option exists. — [FineTune AutoEQProfile.swift](https://github.com/ronitsingh10/FineTune/blob/main/FineTune/Models/AutoEQProfile.swift); [FineTune AutoEQProcessor.swift](https://github.com/ronitsingh10/FineTune/blob/main/FineTune/Audio/AutoEQ/AutoEQProcessor.swift)
- Roon calls insufficient headroom one of the most common reasons DSP "doesn't sound right". Its clipping indicator triggers on a single clipped sample, and its "Headroom Management" applies fixed negative gain. — [Roon KB: Headroom Management](https://help.roonlabs.com/portal/en/kb/articles/dsp-engine-headroom-management). Users have requested automatic post-DSP headroom/limiting (a feature request, not a shipped feature). — [Roon community: Post-DSP volume limiter request](https://community.roonlabs.com/t/post-dsp-volume-limiter-auto-headroom-management/307812)
- Inter-sample peaks:
  - Archimago measured ~31,400 tracks: 44% have true peaks above +0.1 dBTP, and the worst was +5.88 dBTP (Aug 2025). — [Archimago](https://archimago.blogspot.com/2025/08/a-look-at-music-library-how-much.html)
  - Benchmark (via Headphonesty, Dec 2025) claims inter-sample peaks can exceed 0 dBFS by up to 3.01 dB and recommends ~3.5 dB of digital headroom before the D/A. This is a manufacturer claim and is contested on forums. — [Headphonesty](https://www.headphonesty.com/2025/12/dac-industry-broken-filters-useless-chip-specs/)
  - TI recommends scaling the signal down before any boost relative to DAC full scale. — [TI SLYT375](https://ti.com/lit/SLYT375)
- CamillaDSP limiting:
  - The `Limiter` filter does hard or soft clipping, and "soft clipping introduces some harmonic distortion". — [CamillaDSP README](https://github.com/HEnquist/camilladsp/blob/master/README.md)
  - v5 adds a `LookaheadLimiter`, a single-channel filter plus a linked multichannel processor. It delays by the attack time, detects peaks ahead, ramps gain reduction linearly and releases exponentially, with `limit` defaulting to 0.0 dB. — [CamillaDSP v5 README](https://github.com/HEnquist/camilladsp/blob/v5.0.0-beta.2/README.md)

**Dither**
- CamillaDSP's `Dither` filter must sit at the end of the pipeline. Its types include Flat TPDF ("objectively optimal non-shaped dither", amplitude 2 LSB to linearize), Highpass (Wannamaker), F-weighted, Gesemann, Lipshitz and Shibata (from SSRC 1.32) noise shapers per sample rate. Guidance: "For sample rates above 48 kHz there is no need for anything more advanced than the 'Highpass' subtype". `bits` should match the DAC's linear bit depth. — [CamillaDSP README](https://github.com/HEnquist/camilladsp/blob/master/README.md)
- On macOS, "CamillaDSP always uses 32-bit float when transferring data to and from CoreAudio. The conversion from 32-bit float to the sample format used by the actual DAC (the physical format) is performed by CoreAudio." — [CamillaDSP CoreAudio backend](https://github.com/HEnquist/camilladsp/blob/master/backend_coreaudio.md)

### Inferences
- A trustworthy engine for this app:
  - Compute coefficients in Double.
  - Run the cascade in Double with Float64 state, as CamillaDSP and Roon do. On Apple Silicon the cost is trivial for 10–20 biquads.
  - Use DF2T (or DF1 if heavy real-time modulation is planned).
  - Interpolate coefficients on parameter changes (vDSP_biquadm SetTargets, or your own per-sample/per-block ramp) to avoid zipper noise and clicks.
  
  Single-precision `vDSP_biquad`, as FineTune uses it, is the weaker choice for low-frequency high-Q bands.
- For "faithful" treble, plain RBJ bilinear filters are fine at 96/192 kHz but visibly cramp peaking and shelving filters above ~10 kHz at 44.1/48 kHz. Offer an "analog-matched" design (Orfanidis, or Vicanek for peaking; there is no published Vicanek shelf, so shelves need oversampling or another matched design) or 2× oversampling as a "high precision" toggle. Always plot the *actual digital* response, not the analog prototype.
- The default should be minimum-phase IIR (zero latency, no pre-ringing). Linear-phase or mixed-phase FIR convolution should be optional, with the latency displayed (system-wide use also affects video A/V sync).
- Headroom policy: compute the preamp from the **maximum of the summed magnitude response** (not just the largest band gain, since overlapping bands add). Optionally add the ~3 dB inter-sample allowance. Put a transparent true-peak (oversampled) lookahead limiter last, as a safety net only, with a visible "limiter engaged" indicator. CamillaDSP's lookahead limiter appears to detect sample peaks only (its docs do not mention oversampling).
- Dither matters only when the app itself quantizes to integer. With a float32 hand-off to CoreAudio, the HAL does the conversion, so app-side TPDF dither is relevant mainly for a 16-bit device or an integer/hog-mode output path.

### Gaps
- No primary source found on AUNBandEQ's/AVAudioUnitEQ's internal arithmetic precision or design (BLT vs matched). Apple only says "Parametric filter based on Butterworth analog prototype". Needs measurement (sweep vs analog prototype at 44.1/48 kHz).
- No quantitative published comparison (found) of Float32 vs Float64 DF2T biquad noise for typical headphone EQs (e.g., 20 Hz shelf, Q 0.7, at 192 kHz). This should be measured in-house.
- The Vicanek PDF did not extract cleanly beyond its structure and key equations. Matched shelving formulas were not found in this session.

---

## 2. Open-source engines and libraries: license, language, last activity, architecture

### Takeaway
The strongest base for a "faithful" engine is **CamillaDSP** (Rust, 64-bit, IIR+FIR, CoreAudio backend, very active, v5 beta Oct 2026). Its v5 README is **dual-licensed GPL-3.0 OR MPL-2.0**, and the crates are being prepared for crates.io. As a format reference, **EqualizerAPO** (GPL-2.0) defines the de facto text syntax. As a data and optimizer source, **AutoEq** (MIT) is the reference. Existing macOS EQ apps (eqMac, FineTune, SoundSource) use Apple's AVAudioUnitEQ or single-precision vDSP biquads and are not audiophile-grade references for the DSP core. JUCE is now **JUCE 9**, dual AGPLv3/commercial.

### Cited Findings

**Metadata table** (GitHub API, queried 2026-11-21; "last push" = repo `pushed_at`)

| Project | License | Language | Last push | Latest release / note | Source |
|---|---|---|---|---|---|
| CamillaDSP | GPL-3.0 (v5 README: GPL-3.0 **or** MPL-2.0) | Rust | 2026-11-12 | v5.0.0-beta.2 (2026-10-18); stable v4.1.3 (2026-04-09) | [repo](https://github.com/HEnquist/camilladsp), [v5 README](https://github.com/HEnquist/camilladsp/blob/v5.0.0-beta.2/README.md) |
| CamillaGUI | GPL-3.0 | TypeScript | 2026-10-31 | web GUI | [repo](https://github.com/HEnquist/camillagui) |
| pyCamillaDSP | GPL-3.0 | Python | 2026-10-19 | websocket client | [repo](https://github.com/HEnquist/pycamilladsp) |
| rubato (resampler) | MIT + Apache-2.0 files | Rust | 2026-11-12 | used by CamillaDSP | [repo](https://github.com/HEnquist/rubato) |
| coreaudio-rs | Apache-2.0 | Rust | 2026-06-18 | CoreAudio bindings used by CamillaDSP | [repo](https://github.com/RustAudio/coreaudio-rs) |
| AutoEq | MIT | Python | 2026-11-05 (master's last commit 2025-07-20) | v4.0.0 restructure 2023-10-29 | [repo](https://github.com/jaakkopasanen/AutoEq), [commits](https://github.com/jaakkopasanen/AutoEq/commits/master) |
| eqMac | Apache-2.0 | Swift | 2026-09-19 | v1.9.2 (2026-09-19); **public code = v1.3.2, newer releases from a private fork** | [repo](https://github.com/bitgapp/eqMac), [releases](https://github.com/bitgapp/eqMac/releases) |
| FineTune | GPL-3.0 | Swift | 2026-07-09 | v1.9.0 (2026-07-09); ~10.2k stars | [repo](https://github.com/ronitsingh10/FineTune) |
| Background Music | GPL-2.0 | C++ | 2026-06-10 | per-app volume, not an EQ reference | [repo](https://github.com/kyleneideck/BackgroundMusic) |
| EasyEffects | GPL-3.0 | Qt/QML (GitHub reports "HTML") | 2026-11-20 | tag v8.3.2; now Qt/QML/Kirigami | [repo](https://github.com/wwmm/easyeffects) |
| LSP Plugins | LGPL-3.0 | C++ (meta-repo reports Makefile) | 2026-11-05 | 1.2.37 (2026-11-01) | [repo](https://github.com/lsp-plugins/lsp-plugins) |
| JamesDSP for Linux (JDSP4Linux) | GPL-3.0 | C | 2026-11-11 | last release 2.7.0 (2023-12-09) | [repo](https://github.com/Audio4Linux/JDSP4Linux) |
| RootlessJamesDSP (Android) | GPL-3.0 | C | 2026-08-31 | | [repo](https://github.com/timschneeb/RootlessJamesDSP) |
| JamesDSPManager (original) | no license detected | C | 2025-06-18 | | [repo](https://github.com/james34602/JamesDSPManager) |
| x42-plugins (meta) | none detected by GitHub | C/Makefile | 2025-06-06 | fil4.lv2 (4-band PEQ): GPL-2.0, pushed 2026-09-07 | [x42-plugins](https://github.com/x42/x42-plugins), [fil4.lv2](https://github.com/x42/fil4.lv2) |
| LosslessSwitcher | GPL-3.0 | Swift | 2026-06-07 | 2.0 (2026-02-28), 3.0-beta1 (2026-03-01) | [repo](https://github.com/vincentneo/LosslessSwitcher) |
| AudioKit | MIT | Swift | 2026-07-26 | | [repo](https://github.com/AudioKit/AudioKit) |
| SoundpipeAudioKit | MIT | C | 2026-04-15 | | [repo](https://github.com/AudioKit/SoundpipeAudioKit) |
| JUCE | AGPLv3 / commercial "JUCE 9" EULA | C++ | 2026-11-20 | 9.0.6 (2026-11-19) | [LICENSE.md](https://github.com/juce-framework/JUCE/blob/master/LICENSE.md), [releases](https://github.com/juce-framework/JUCE/releases) |
| Faust | LGPL-2.1 (compiler, per COPYING; v2.94.1 header) | C++ | 2026-11-20 | | [repo](https://github.com/grame-cncm/faust) |
| r8brain-free-src | MIT | C++ | 2026-11-11 | | [repo](https://github.com/avaneev/r8brain-free-src) |
| libsoxr (chirlu mirror) | LGPL-2.1 | C | 2023-11-14 | stale | [repo](https://github.com/chirlu/soxr) |
| CrinGraph (squig.link engine) | 0BSD | JavaScript | 2023-06-28 | | [repo](https://github.com/mlochbaum/CrinGraph) |
| EqualizerAPO | GPL-2.0 (SourceForge) | (Windows APO) | 1.4.2 on 2025-03-21 | | [SourceForge](https://sourceforge.net/projects/equalizerapo/files/) |
| New small macOS EQs (signal only) | BalanceEQ GPL-3.0 / eqmini MIT | Swift | 2026-11-10 / 2026-10-17 | ~0–2 stars | [BalanceEQ](https://github.com/x5mii/BalanceEQ), [eqmini](https://github.com/elmsec/eqmini) |

**CamillaDSP (engine to study or embed)**
- It is a CLI engine for Linux, macOS and Windows. Its IIR filters are biquads and its FIR filters use FFT convolution, and it aims "to provide both FIR and IIR filtering… stable, fast and flexible". Prebuilt binaries exist for macOS Intel and Apple Silicon (CoreAudio). The IIR code is "heavily inspired by biquad-rs" and FIR uses rustfft. — [CamillaDSP README](https://github.com/HEnquist/camilladsp/blob/master/README.md)
- Biquad types: Free (raw coefficients), Highpass/Lowpass (2nd order), HighpassFO/LowpassFO, High/Lowshelf (slope or q), HighshelfFO/LowshelfFO, Peaking (q or bandwidth), Notch, GeneralNotch, Bandpass, Allpass, AllpassFO, LinkwitzTransform.
- BiquadCombo types: Butterworth and Linkwitz-Riley HP/LP of any order, Tilt, FivePointPeq (v5: generalised to **NPointPeq** with a `bands` list), and GraphicEqualizer (N log-spaced peaking bands, zero-gain bands skipped).
- Other filter types: DiffEq (arbitrary IIR, DF2T in v5), Conv (FIR from WAV/raw/inline), Gain, Volume, Loudness, Delay, Dither, Limiter. Processors: Compressor, NoiseGate, RACE (crosstalk cancellation).

  — [CamillaDSP README](https://github.com/HEnquist/camilladsp/blob/master/README.md); [CHANGELOG_5.0_details](https://github.com/HEnquist/camilladsp/blob/v5.0.0-beta.2/CHANGELOG_5.0_details.md)
- The v5 beta adds a spectrum analyzer over websocket (computed in 32-bit float), the LookaheadLimiter and an end-to-end test suite including CoreAudio. It also moves config types to a `camilladsp-schema` crate and prepares "camilladsp and camilladsp-schema for publishing on crates.io", with the binary becoming a "thin wrapper". — [v5.0.0-beta.1 notes](https://github.com/HEnquist/camilladsp/releases/tag/v5.0.0-beta.1); [CHANGELOG_5.0_details](https://github.com/HEnquist/camilladsp/blob/v5.0.0-beta.2/CHANGELOG_5.0_details.md)
- Its control plane is a websocket API. It has a web GUI (CamillaGUI) and a Python client, and `camilladsp-controller` provides automatic sample-rate switching. — [CamillaDSP v5 README](https://github.com/HEnquist/camilladsp/blob/v5.0.0-beta.2/README.md)
- Performance claim: a Raspberry Pi 4 runs 8 channels × 262k-tap FIR at 192 kHz. — [CamillaDSP README](https://github.com/HEnquist/camilladsp/blob/master/README.md)

**EqualizerAPO / Peace**
- EqualizerAPO is a Windows APO EQ. Its text configuration language includes Preamp, Filter, GraphicEQ, Convolution, Include, Device, Channel, Stage, Copy, Delay and If/Eval with inline expressions. See §5 for the syntax. — [EqualizerAPO Configuration reference](https://sourceforge.net/p/equalizerapo/wiki/Configuration%20reference/)
- License GPL-2.0. Version 1.4 came out 2024-11-24, 1.4.1 on 2024-12-18 and 1.4.2 on 2025-03-21, adding ARM64 support. — [EqualizerAPO SourceForge](https://sourceforge.net/projects/equalizerapo/files/)
- Peace is listed by AutoEq as a separate target app (8 peaking + shelves). — [AutoEq equalizers.js](https://github.com/jaakkopasanen/AutoEq/blob/master/webapp/ui/src/equalizers.js)

**eqMac (macOS)**
- Its EQ core is Apple's `AVAudioUnitEQ`, with every band set to `.parametric` and bandwidth 0.5 octave. The Advanced EQ has fixed bands at 32, 64, 125, 250, 500, 1k, 2k, 4k, 8k and 16k Hz. — [eqMac Equalizer.swift](https://github.com/bitgapp/eqMac/blob/master/native/app/Source/Audio/Effects/Equalizers/Equalizer.swift); [AdvancedEqualizer.swift](https://github.com/bitgapp/eqMac/blob/master/native/app/Source/Audio/Effects/Equalizers/Advanced/AdvancedEqualizer.swift)
- README: "the code in this repository corresponds to v1.3.2 of eqMac without any Pro Features and all the newer releases are done on a private fork". The Pro features are Expert EQ (unlimited bands with type, frequency, gain and bandwidth), Spectrum analyzer, AU hosting, Spatial Audio and Volume Mixer. AutoEQ integration is free for Advanced EQ and Pro for Expert EQ. — [eqMac README](https://github.com/bitgapp/eqMac)
- Recent releases: v1.9.1 (2026-09-13) "Completely removed Helper which caused issues on macOS 27". v1.9.2 adds per-device capture-method selection (macOS 14.2+) and a spectrum analyzer that "takes into account both channels". — [eqMac releases](https://github.com/bitgapp/eqMac/releases)

**FineTune (macOS, the most popular open-source SoundSource alternative)**
- Its EQ uses RBJ cookbook coefficients computed in Double and normalised for vDSP. Graphic-EQ bands use Q = 1.4. — [FineTune BiquadMath.swift](https://github.com/ronitsingh10/FineTune/blob/main/FineTune/Audio/EQ/BiquadMath.swift)
- Processing goes through **single-precision** `vDSP_biquad` on stereo-interleaved Float32 with Float delay buffers. The setup is swapped atomically on changes. — [FineTune BiquadProcessor.swift](https://github.com/ronitsingh10/FineTune/blob/main/FineTune/Audio/EQ/BiquadProcessor.swift)
- It has an AutoEQ module (fetcher, parser, processor), a Loudness module (`KWeightingFilter.swift`, `LoudnessEqualizer.swift`) and adversarial biquad tests. — [FineTune repo tree](https://github.com/ronitsingh10/FineTune)

**EasyEffects / LSP / JamesDSP / x42 (Linux and Android references)**
- EasyEffects was formerly PulseEffects, moved to GTK4 with native PipeWire filters and is now ported to Qt/QML/KDE Kirigami. Its effects include Convolver, Crossfeed and Equalizer, built on LSP plugins, Calf, ZamAudio, zita-convolver, x42 and **libbs2b**. — [EasyEffects README](https://github.com/wwmm/easyeffects)
- The LSP para-EQ provides IIR/FIR/FFT/SPM modes, RLC/BWC/LRX/APO filter classes, BT/MT/DR transforms and decramp oversampling (details in §1). — [LSP manual](https://lsp-plug.in/?page=manuals&section=para_equalizer_x16_stereo)
- JamesDSP (Linux) features:
  - "Interpolated FIR equalizer with flexible bands".
  - An "Arbitrary response equalizer (also known as GraphicEQ from EqualizerAPO)" with AutoEQ database integration.
  - A partitioned convolver supporting mono, stereo and true-stereo IRs.
  - Crossfeed, ViPER-DDC parametric EQ and an output limiter.
  - Live-programmable DSP in EEL2.

  — [JDSP4Linux README](https://github.com/Audio4Linux/JDSP4Linux)

**Apple built-ins (AVAudioUnitEQ / AUNBandEQ)**
- Header facts (macOS 27.0 SDK, verified locally):
  - Filter types: Parametric ("based on Butterworth analog prototype"), 2nd-order Butterworth LP/HP, Resonant LP/HP, BandPass, BandStop, Low/High shelf and Resonant Low/High shelf.
  - Ranges: frequency 20 Hz to SR/2, **bandwidth 0.05–5.0 octaves (default 0.5)**, gain −96 to +24 dB, global gain −96 to +24 dB. Properties are `float`.

  — [Apple: AVAudioUnitEQFilterParameters](https://developer.apple.com/documentation/avfaudio/avaudiouniteqfilterparameters)
- AutoEq's `AUNBANDEQ` preset targets these limits: a low shelf at 105 Hz/Q 0.7, a high shelf at 10 kHz/Q 0.7 and 8 peaking bands with Q 0.182479–10 (the comment reads "AUNBandEq has maximum bandwidth of 5 octaves which is Q of 0.182479"). — [AutoEq constants.py](https://github.com/jaakkopasanen/AutoEq/blob/master/autoeq/constants.py)

**Swift/C++ libraries**
- AudioKit and SoundpipeAudioKit are MIT-licensed. — [AudioKit](https://github.com/AudioKit/AudioKit), [SoundpipeAudioKit](https://github.com/AudioKit/SoundpipeAudioKit)
- JUCE: "The JUCE Framework modules are dual-licensed under the AGPLv3 and the commercial JUCE licence". The current EULA is "JUCE 9". — [JUCE LICENSE.md](https://github.com/juce-framework/JUCE/blob/master/LICENSE.md). A JUCE 8 forum note says the open-source option moved from GPLv3 (JUCE 7) to AGPLv3 (JUCE 8). — [JUCE forum](https://forum.juce.com/t/juce8-license-and-open-source-projects/60987)
- The Faust compiler is LGPL-2.1 per COPYING. — [Faust](https://github.com/grame-cncm/faust)

### Inferences
- **Recommended core:** a native Swift/C (or Rust via FFI) double-precision biquad and FIR engine that mirrors CamillaDSP's filter taxonomy and semantics. Alternatively, embed CamillaDSP v5 as a Rust library: the MPL-2.0 option is file-level copyleft and compatible with most open-source app licenses, and the crates.io publication makes linking plausible. Using CamillaDSP's YAML as the "advanced" interchange format gives instant compatibility with REW and CamillaGUI.
- Do **not** base the core on AVAudioUnitEQ. Its precision and design are undocumented, it caps gain at +24 dB and bandwidth at 0.05–5 oct, and it exposes no coefficients or phase info. It is acceptable only as a "lite" fallback.
- JUCE's AGPLv3 is a heavy obligation for an app and complicates the App Store. Faust-generated code or the LSP DSP (LGPL-3.0) are viable references. LSP's `lsp-dsp-lib` would need its license checked (not verified here).
- eqMac's public code is 1.3.2-era and not representative of the shipped app. Use it for architecture lessons, not as a DSP quality reference.

### Gaps
- Not verified: whether `camilladsp` v5 is already published on crates.io as a usable library API (the changelog only says "prepare… for publishing").
- Not verified: the licenses of LSP's sub-libraries (`lsp-dsp-lib`), Peace (believed freeware, closed), and Wavelet (closed-source Android app).
- Not researched in depth: AudioKit's specific EQ node implementations (most wrap AVAudioUnitEQ or Soundpipe filters).

---

## 3. Bit-perfect, sample-rate switching, hog/exclusive mode, and how EQ interacts with them

### Takeaway
On macOS, apps exchange float32 with CoreAudio and the HAL converts to the device's physical format. Apple Music does **not** auto-switch the device sample rate (forum reports through Tahoe), which is why LosslessSwitcher exists. Audiophile players reach bit-perfect output with **hog (exclusive) mode plus integer mode**. Any active EQ makes the path non-bit-perfect by definition. The best practice (Roon) is an explicit signal-path indicator ("Lossless" vs "Enhanced") plus a true bypass.

### Cited Findings
- CoreAudio hardware AudioUnits have two formats: the client format (typically 32-bit float) and the physical format. The physical format can be set in Audio MIDI Setup or programmatically. CamillaDSP's `exclusive: true` requests **hog mode**. It recommends BlackHole for capturing other apps' audio, and notes that "Some player applications can use hog mode… Using this with a virtual soundcard like BlackHole causes problems". — [CamillaDSP CoreAudio backend](https://github.com/HEnquist/camilladsp/blob/master/backend_coreaudio.md)
- CamillaDSP on macOS: "If the capture device sample rate changes, then CamillaDSP will stop" (the StopReason is reported via websocket). Automatic switching is delegated to `camilladsp-controller`. — [CamillaDSP CoreAudio backend](https://github.com/HEnquist/camilladsp/blob/master/backend_coreaudio.md); [CamillaDSP v5 README](https://github.com/HEnquist/camilladsp/blob/v5.0.0-beta.2/README.md)
- Apple Music on macOS: user threads (2021–2025, including Sonoma and Tahoe) report that it plays at whatever rate Audio MIDI Setup is set to, and users request automatic sample-rate switching. — [Apple Discussions 256138473](https://discussions.apple.com/thread/256138473); [Apple Discussions 255993822](https://discussions.apple.com/thread/255993822)
- LosslessSwitcher (GPL-3.0) reads Apple Music's logs to detect the current track's sample rate, then sets the output device rate via CoreAudio (SimplyCoreAudio). Details:
  - It supports Apple Music only and requires admin rights, Lossless enabled in Music, and no sandbox.
  - Playback "may briefly be interrupted" during a switch.
  - Bit-depth switching reduces detection accuracy and is not recommended.
  - Version 2.0 targets macOS 15.4+; 3.0-beta1 was released 2026-03-01.

  — [LosslessSwitcher](https://github.com/vincentneo/LosslessSwitcher); [releases via GitHub API](https://github.com/vincentneo/LosslessSwitcher/releases)
- SoundSource added an automatic sample-rate adjustment setting for Tahoe (5.8.7, Sep 17 2025), renamed "Fix Sample Rates on Tahoe" in 5.8.8. It also lists a Tahoe issue where capture fails when an app's target device rate differs from the default output (5.8.6). — [SoundSource release notes](https://rogueamoeba.com/soundsource/releasenotes.php)
- Audirvana gets "direct access to the DAC, bypassing the system mixer". On Mac, "an integer (non-floating) format must be imposed to neutralize the mixer". — [Audirvana: Exclusive Playback Technology](https://audirvana.com/exclusive-playback-technology/)
- Integer mode rationale (Tonal article): 32-bit IEEE-754 floats represent integers only up to 25-bit signed, so 32-bit integer sources need integer mode to stay bit-accurate. For 16/24-bit sources, integer mode mainly avoids one lossless float-to-int conversion in the driver. — [Secrets of Audiophile Playback on macOS (Medium/Tonal)](https://medium.com/tonal-app/secrets-of-audiophile-playback-on-macos-8f940e8f4625)
- Audirvana user reports (2021–2023) show plugins sometimes not applied in exclusive mode depending on version and "realtime vs offline" effect settings. These are anecdotal forum reports. — [Audirvana community](https://community.audirvana.com/t/no-signal-processing-with-exclusive-mode/30122)
- Roon's Signal Path uses colour-coded quality: Lossless (file to device unmodified), **Enhanced** (DSP such as Volume Leveling or the DSP Engine), High Quality (e.g., OS mixer or compatibility conversions) and Low Quality (lossy). — [Roon Signal Path KB](https://help.roonlabs.com/portal/en/kb/articles/signal-path); [Roon blog: Signal Path](https://blog.roonlabs.com/signal-path)

### Inferences
- An EQ path can never be bit-perfect. The honest UX is:
  - A Roon-style per-stage signal-path view (source rate/bits → resampler? → EQ (64-bit) → preamp → limiter → output format).
  - A "Bit-perfect" badge only when EQ is truly bypassed (no processing, no gain, matched rates).
  - A one-click A/B bypass that is **level-matched**: bypass should apply the same preamp, or the louder "EQ off" will bias listening tests.
- For system-wide processing, the app should follow the source rate (switch the device rate to the current content rate when possible) rather than resample. Recompute biquad coefficients per sample rate, and keep a high-quality resampler only for unavoidable mismatches.
- Hog mode conflicts with system-wide capture: hogging the DAC prevents other clients. The app should offer it only for its own output stream and explain the trade-off.

### Gaps
- No primary Apple documentation was found on whether the HAL dithers when converting float32 to an integer physical format.
- Not verified: Apple Music behaviour changes in macOS 27 (no 2026 source found either way).
- Roon on macOS with exclusive mode plus DSP: no authoritative doc found on the macOS-specific path.

---

## 4. Headphone/speaker correction data, targets, and auto-selection

### Takeaway
AutoEq (MIT code) remains the hub. It aggregates oratory1990, crinacle, Rtings, Innerfidelity, legacy Headphone.com and squig.link-hosted measurements, ships ~60 target CSVs (Harman 2013–2019 variants, diffuse-field, 5128-based) and a parametric optimizer, and per-model results are fetchable over raw GitHub. Its master branch data has not been updated since **July 2025**. Targets are fragmenting by fixture: in Oct 2025 Olive & Clark defined Harman-equivalent targets for the B&K 5128 and GRAS 45CA-10, and in 2026 headphones.com launched GraphWorks with "2026 Preference Bounds". Measurement-data licensing for bundling is unresolved.

### Cited Findings
**AutoEq: sources, structure, optimizer**
- AutoEq aggregates measurements from oratory1990, crinacle, Innerfidelity, Rtings and legacy headphone.com. It ships a collection of targets, precomputed results and a web app at autoeq.app ("normal users" should use the web app). AutoEq itself "does not do the equalization itself". — [AutoEq README](https://github.com/jaakkopasanen/AutoEq)
- History: the PEQ optimizer was reworked on 2022-09-18. The new optimizer supports shelf filters, runs 10× faster, has Fc/Q/gain limits and "treats +10 kHz range as average value instead of trying to fix it precisely". AutoEq 4.0.0 came out 2023-10-29. — [AutoEq README](https://github.com/jaakkopasanen/AutoEq)
- `DBS = ['crinacle', 'Headphone.com Legacy', 'Innerfidelity', 'oratory1990', 'Rtings']`. There is a squig branch (Dec 2023, "Measurement files and results for squig.link sites") and a master commit of 2025-07-13: "Added new measurements and results for first half of Squigsites". — [AutoEq constants.py](https://github.com/jaakkopasanen/AutoEq/blob/master/autoeq/constants.py); [squig branch commits](https://github.com/jaakkopasanen/AutoEq/commits/squig); [master commits](https://github.com/jaakkopasanen/AutoEq/commits/master)
- Recent data activity: support for Rtings v1.8 (2025-04-07), new Rtings/oratory1990 results (2025-05-14), and the last master commit "New measurements and results" (2025-07-20). — [AutoEq commits](https://github.com/jaakkopasanen/AutoEq/commits/master)
- Optimizer: `scipy.optimize.fmin_slsqp` with a per-filter "sharpness penalty". Defaults:
  - Peaking Fc 20 Hz–10 kHz, Q 0.18248–6, gain ±20 dB.
  - Shelf Q 0.4–0.7 ("shelf filters start to overshoot" outside this range).
  - 1/12-octave smoothing, with a 2-octave treble smoothing window above 6–8 kHz.
  - `DEFAULT_FS = 44100`.
  - The "8_PEAKING_WITH_SHELVES" config is used for EqualizerAPO ParametricEq, Peace, EasyEffects, eqMac Expert, SoundSource and Rockbox.

  — [AutoEq peq.py](https://github.com/jaakkopasanen/AutoEq/blob/master/autoeq/peq.py); [constants.py](https://github.com/jaakkopasanen/AutoEq/blob/master/autoeq/constants.py); [equalizers.js](https://github.com/jaakkopasanen/AutoEq/blob/master/webapp/ui/src/equalizers.js); [peq.yaml](https://github.com/jaakkopasanen/AutoEq/blob/master/peq.yaml)
- The AutoEq targets directory includes:
  - Harman over-ear 2013/2015/2018 (with and without bass) and Harman in-ear 2016/2017-1/2017-2/2019 (with and without bass).
  - Harman loudspeaker in-room flat 2013.
  - Diffuse field 5128 (plus a −1 dB/oct variant), Diffuse field GRAS KEMAR and Diffuse field ISO 11904-1.
  - "711 5128 delta", "LMG 5128 0.6", "oratory1990 optimum hifi over-ear", "AutoEq in-ear", "JM-1 with Harman filters" and "zero".
  - Rig-specific Harman variants for Rtings, Innerfidelity, Headphone.com Legacy, crinacle EARS+711 and HMS II.3.

  — [AutoEq targets](https://github.com/jaakkopasanen/AutoEq/tree/master/targets)

**Concrete auto-selection implementation (FineTune)**
- FineTune downloads the catalog from `https://raw.githubusercontent.com/jaakkopasanen/AutoEq/master/results/INDEX.md` and per-profile files from `…/results/`. It caches to disk (7-day TTL) and dedupes by source priority. The user searches a model name, the profile applies per output device, a "Correction" switch does A/B, and up to 10 filters are supported. — [FineTune AutoEQFetcher.swift](https://github.com/ronitsingh10/FineTune/blob/main/FineTune/Audio/AutoEQ/AutoEQFetcher.swift); [FineTune AutoEQ guide](https://github.com/ronitsingh10/FineTune/blob/main/guide/autoeq.md)
- AutoEq results are organised per source, type and model (e.g., `results/oratory1990/over-ear/Sennheiser HD 800/`). — [AutoEq README](https://github.com/jaakkopasanen/AutoEq)

**Commercial and other implementations**
- SoundSource "Headphone EQ" (originally built on AutoEq data per a forum report, with sources including oratory1990, crinacle, Innerfidelity and Rtings) can target specific apps as of 6.0.0 (Dec 3 2025). 6.1.6 (Oct 26 2026) makes imported profiles respect "OFF" bands and fixes shelf slope. — [SoundSource release notes](https://rogueamoeba.com/soundsource/releasenotes.php); [headphones.com forum](https://forum.headphones.com/t/soundsource-5-with-headphone-eq/9940)
- **Licensing risk (forum claim, unverified):** oratory1990 reportedly objected to SoundSource bundling AutoEq presets derived from his data without a license. — [headphones.com forum](https://forum.headphones.com/t/soundsource-5-with-headphone-eq/9940)
- Wavelet (Android, closed-source) ships thousands of AutoEq profiles (one listing says 3,600+, a later one 5,000+) based on Harman. It imports AutoEq GraphicEQ files and custom optimisations from autoeq.app or squig.link and has a 9-band graphic EQ. Release 26.05 updated the AutoEq database. — [Wavelet features](https://pittvandewitt.github.io/Wavelet/Features); [XDA](https://www.xda-developers.com/wavelet-latest-update-more-features-headphones-sound-better/); [APKMirror 26.05](https://www.apkmirror.com/?p=13969488)
- Sonarworks SoundID Reference: its standalone "Systemwide" app calibrates all computer audio on Mac and Windows, with per-output-device presets and profiles. Sonarworks notes "latency and compatibility trade-offs on macOS" and still recommends the DAW plugin for most workflows. A reseller listing claims 500+ supported headphone models. — [Sonarworks support: standalone app](https://support.sonarworks.com/hc/en-us/articles/360019916480); [Plugin Boutique listing](https://pluginboutique.com/products/7408-SoundID-Reference-for-Headphones)

**Measurement sources and comparability**
- squig.link hosts many independent collections with inconsistent rigs and procedures. Its measurements "should only be compared with others in the same database". — [IEM EQ Guide: Measurement Databases](https://4ciemg.github.io/IEM-EQ-Guide/measurement-databases)
- crinacle's older graph database is a legacy rig with single-channel data, and users are pointed to the current official database. — [crinacle legacy headphones](https://crinacle.com/graphs/headphones-legacy/)
- CrinGraph, the open-source engine behind squig-style graph sites, is 0BSD and was last pushed 2023-06. — [CrinGraph](https://github.com/mlochbaum/CrinGraph)
- GraphWorks (headphones.com, Oct 22 2026) is a free core database with a $5/month supporter tier for on-head datasets and EQ. It uses rig-specific diffuse-field-compensated data and "2026 Preference Bounds": headphone bounds from the spread of preferred curves in Harman's 2018–2019 tests, IEM bounds (beta) from Olive's studies. The bounds drop the old DF to "Harman in-room flat" equivalence assumption. The company sells GraphWorks EQ for macOS and Windows. Data export, API and reuse terms are not stated. — [headphones.com GraphWorks](https://headphones.com/blogs/features/our-headphone-measurement-database-is-finally-here)

**Target research**
- Olive & Clark, AES Convention 159 Paper 394 (2025-10-14), "A Preferred Headphone Target Curve Defined for the B&K 5128 and GRAS45CA-10 Test Fixtures": the Harman OE target (GRAS 45CA + RA045/711 + custom pinna) "is often misused with other fixtures". The paper defines fixture-specific equivalents and is paywalled. — [AES E-Library 23068](https://aes2.org/publications/elibrary-page/?id=23068); [headphones.com forum discussion](https://forum.headphones.com/t/new-study-by-dr-olive-and-dan-clark-on-the-harman-target-and-its-compatibility-or-lack-thereof-with-current-measurement-rigs/26699)
- Oct 2024 (older): in Olive's AES comparison, the SoundGuys Headphone Preference Curve and Harman IE2019 were statistically tied as most preferred for in-ears. — [Headphonesty](https://www.headphonesty.com/2024/10/harman-target-curve-alive/); [SoundGuys](https://www.soundguys.com/harman-target-soundguys-preference-curve-validated-125420/)
- Sean Olive retired from Harman in 2025 after 32 years. — [Crutchfield](https://www.crutchfield.com/learn/crutchfield-visits-harman.html)
- Rtings Test Bench 1.8 research is titled "One Curve Doesn't Fit All: 350 Headphone Listening Tests Show That Many Sound Profiles Can Be Preferred". The body is behind a login. — [Rtings 1.8 research](https://www.rtings.com/headphones/learn/research/frequency-response-1-8)

**Speakers and rooms (REW)**
- REW (V5.20.14+) exports filters directly as CamillaDSP YAML (filters plus pipeline steps), and CamillaGUI can import them. CamillaDSP also ships `translate_rew_xml.py`. — [CamillaDSP README: Using filters from REW](https://github.com/HEnquist/camilladsp/blob/master/README.md)
- REW cannot reload filter settings from text files; the `.req` format is used to save and reload. — [REW help: File menu](https://www.roomeqwizard.com/help/help/html/file.html)

### Inferences
- UX: "pick your headphone model" should search a locally cached AutoEq index, falling back to network. Display the measurement source and rig ("oratory1990 / GRAS 43AG", "crinacle / 711", "Rtings 1.8") and the target used. Let the user switch target and re-optimise locally: port AutoEq's optimizer logic, or call the PyPI `autoeq` package at build time to precompute.
- Because AutoEq master data stalled in July 2025, plan for multiple data sources: AutoEq results, user-imported ParametricEQ/GraphicEQ, and possibly CSV frequency-response imports with on-device optimisation against selectable targets (Harman 2018/2019, DF-5128, Olive & Clark 5128 equivalents once public).
- Licensing: AutoEq code is MIT, but the measurement data belong to third parties (oratory1990, crinacle, Rtings). For an open-source app, fetching from the AutoEq repo at runtime, as FineTune does, is safer than bundling derived presets, and sources should be credited in the UI.
- Re-optimising per device sample rate matters little for AutoEq's outputs (Fc capped at 10 kHz, treble treated as an average), but bilinear cramping still alters high shelves at 44.1/48 kHz. This supports a matched or oversampled design (§1).

### Gaps
- Not confirmed whether autoeq.app's backend data is newer than the GitHub master (July 2025).
- No official license terms found for oratory1990, crinacle or Rtings data reuse in third-party apps.
- The exact Olive & Clark 2025 target values are paywalled. Forum speculation about names ("KB5000_7", "5128_7") is not confirmed.
- SoundID's macOS system-wide implementation (virtual driver vs taps) is not documented in the sources found.

---

## 5. Preset formats to import/export, and the de facto interchange standard

### Takeaway
The **EqualizerAPO ParametricEQ text syntax** (`Preamp: -6.2 dB` / `Filter 1: ON PK Fc 100 Hz Gain -2.3 dB Q 1.41`) is the de facto interchange standard. REW's "Generic" text export uses it, AutoEq emits it, and FineTune documents importing it. SoundSource and eqMac Expert are AutoEq targets using the same "8 peaking + shelves" parametric config, though their exact import file formats were not verified. The secondary standards are AutoEq/EqualizerAPO **GraphicEQ** (127 freq/gain points), **CamillaDSP YAML** for advanced pipelines (REW exports it natively), and **WAV impulse responses** for convolution.

### Cited Findings
- EqualizerAPO syntax:
  - `Preamp: <dB>`, and `Filter <n>: ON <Type> Fc <f> Hz Gain <g> dB Q <q>` or `… BW Oct <bw>`. The filter number "is not interpreted and can be omitted".
  - Types: `PK`/`Modal`/`PEQ`, `LP`/`LPQ`, `HP`/`HPQ`, `BP`, `LS`/`LSC x dB`, `HS`/`HSC x dB`, `LS 6dB`/`LS 12dB`, `HS 6dB`/`HS 12dB`, `NO` (notch), `AP` (all-pass).
  - Raw coefficients: `Filter: ON IIR Order <m> Coefficients b0…bm a0…am`.
  - Other commands: `GraphicEQ: f g; f g; …`, `Convolution: <file>` (sample rate must match the device), `Delay`, `Copy`, `Channel`, `Device`, `Stage`, `Include`, `If/Eval`, and inline backtick expressions.

  — [EqualizerAPO Configuration reference](https://sourceforge.net/p/equalizerapo/wiki/Configuration%20reference/)
- The EqualizerAPO wiki describes the REW route: File → Export → "Filter Settings as text" for equaliser type "Generic", which is the same syntax (the BW variant corresponds to the FBQ2496 type). — [EqualizerAPO wiki / Configuration reference](https://sourceforge.net/p/equalizerapo/wiki/Configuration%20reference/)
- FineTune documents its accepted import format with this example: `Preamp: -6.2 dB`, `Filter 1: ON PK Fc 100 Hz Gain -2.3 dB Q 1.41`, `Filter 2: ON LSC Fc 105 Hz Gain 7.0 dB Q 0.71`, `Filter 3: ON HSC Fc 8000 Hz Gain 2.1 dB Q 0.71`. It supports PK/PEQ, LS/LSC and HS/HSC. — [FineTune AutoEQ guide](https://github.com/ronitsingh10/FineTune/blob/main/guide/autoeq.md); [AutoEQParser.swift](https://github.com/ronitsingh10/FineTune/blob/main/FineTune/Audio/AutoEQ/AutoEQParser.swift)
- AutoEq output targets (web app list):
  - Fixed-band EQs: 10-band GEQ, 31-band GEQ, eqMac Advanced, iTunes, Spotify.
  - Parametric EQs: AUNBandEq, EqualizerAPO ParametricEq, Peace, EasyEffects, eqMac Expert, SoundSource, Rockbox, Poweramp, Neutron, USB Audio Player PRO, Qudelix-5K, MiniDSP 2x4HD and IL-DSP, Moondrop Free DSP, Voicemeeter, Ears (Chrome), Custom.
  - Graphic: EqualizerAPO GraphicEq, Wavelet.
  - Convolution: Convolution Eq, Viper4Android.

  — [AutoEq equalizers.js](https://github.com/jaakkopasanen/AutoEq/blob/master/webapp/ui/src/equalizers.js)
- AutoEq GraphicEQ uses `DEFAULT_GRAPHIC_EQ_STEP = 1.0563`, which "produces 127 samples with greatest frequency of 19871" Hz. — [AutoEq constants.py](https://github.com/jaakkopasanen/AutoEq/blob/master/autoeq/constants.py)
- Wavelet's import format is the AutoEq GraphicEQ type. — [AutoEq equalizers.js](https://github.com/jaakkopasanen/AutoEq/blob/master/webapp/ui/src/equalizers.js); [XDA on Wavelet GraphicEQ import](https://www.xda-developers.com/wavelet-latest-update-more-features-headphones-sound-better/)
- JamesDSP's "Arbitrary response equalizer" is explicitly "GraphicEQ from EqualizerAPO". — [JDSP4Linux README](https://github.com/Audio4Linux/JDSP4Linux)
- CamillaDSP YAML: a `filters:` map of named filters (`type: Biquad`, `parameters: {type: Peaking, freq, gain, q|bandwidth}`, etc.) plus a `pipeline:` of steps. FIR coefficients can come from WAV, raw or inline sources. REW 5.20.14+ exports this format. — [CamillaDSP README](https://github.com/HEnquist/camilladsp/blob/master/README.md)
- REW's native filter save/reload format is `.req`; text export is one-way. — [REW help](https://www.roomeqwizard.com/help/help/html/file.html)

### Inferences
- **Import:**
  - EqualizerAPO ParametricEQ/config (support the full filter-type table, `BW Oct`, `IIR Order … Coefficients`, and `GraphicEQ:` lines; ignore or flag `Device:`/`If:`).
  - AutoEq GraphicEQ.
  - CamillaDSP YAML (filters subset).
  - WAV IR (with resampling to the device rate, since EqualizerAPO requires the IR rate to match the device).
  - REW-exported text.
- **Export:** the same formats, plus a native JSON preset that stores intent rather than coefficients: filter type, Fc/gain/Q, design method (RBJ vs matched), preamp, target/source metadata, and the sample rate the preset was optimised for. Recompute coefficients per sample rate.
- Round-trip caveat: EqualizerAPO's `LSC/HSC` shelves defined by Q, AUNBandEQ's octave bandwidth and CamillaDSP's `slope` vs `q` differ. Normalise to cookbook definitions and convert Q↔BW explicitly (cookbook definitions in §1).

### Gaps
- Poweramp's and Wavelet's native preset file formats (beyond AutoEq's text outputs) were not documented in sources found.
- Not verified in this session: EasyEffects' exact APO/GraphicEQ import features in the Qt (v8) version.

---

## 6. Audio Unit hosting (AUv2/AUv3) system-wide: feasibility and precedent

### Takeaway
System-wide AU hosting is a proven pattern on macOS. SoundSource does it commercially, with AUv3 improvements and a latency warning, and eqMac Pro, the free Hosting AU, MenuBUS and Audirvana also host AUs. AUv3 units load **out-of-process by default**; in-process is a macOS-only request that may fail. Per a search summary of SoundSource's release notes, Apple now requires third-party AUs to be signed and notarized. Pro-Q is available as an AU, but no official confirmation was found of it being tested inside SoundSource.

### Cited Findings
- macOS 27.0 SDK `AudioComponent.h` (verified locally): "A version 3 audio unit… can be loaded into a separate extension service process, and this is the default behavior". `kAudioComponentInstantiation_LoadInProcess` is "Only available on macOS" and requires the AU to be packaged "in a bundle separate from the application extension". "These options are just requests… It may fail and fall back to the default." — [Apple: AudioComponentInstantiationOptions](https://developer.apple.com/documentation/audiotoolbox/audiocomponentinstantiationoptions)
- Apple TN2312: the `com.apple.security.temporary-exception.audio-unit-host` entitlement allows a sandboxed host to open Audio Units that are not sandbox-safe. — [Apple TN2312](https://developer.apple.com/library/archive/technotes/tn2312/_index.html)
- SoundSource hosts AUs (built-in 10-band EQ plus "advanced Audio Unit plugins") on the system output or per app. AUv3 support was improved in 6.0.4 (Feb 12 2026) and 6.1.0 (Jul 21 2026). 6.0.0 (Dec 3 2025) added a warning naming effects that add notable delay, 5.8.0 limited live parameter updates for some AUs to prevent glitches, and 6.2.0 (Nov 11 2026) is the latest. — [SoundSource product page](https://www.rogueamoeba.com/soundsource/); [SoundSource release notes](https://rogueamoeba.com/soundsource/releasenotes.php). Search summaries of the same notes say Apple "now requires third-party Audio Unit plugins to be properly signed and notarized" (not re-read in the fetched excerpt).
- eqMac Pro lists "AudioUnit (AU) Hosting - add 3rd party effects to the Audio Pipeline". — [eqMac README](https://github.com/bitgapp/eqMac)
- Hosting AU by Ju-X is a free AU host (v1.5.0, macOS 10.6+, old). It was historically used with Soundflower as a loopback for system-wide processing. — [KVR: Hosting AU](https://www.kvraudio.com/product/hosting-au-by-juno-ju-x)
- MenuBUS is a virtual soundcard between apps and the interface that hosts AU plug-ins. — [Sound On Sound review](https://www.soundonsound.com/reviews/menubusau-plug-host-mac-os)
- FabFilter plug-ins ship as VST, VST3, AU, CLAP and AAX. A user report says plug-ins run fine system-wide via SoundSource (this concerned Audirvana, not Pro-Q specifically). — [Audirvana community: SoundSource and plugins](https://community.audirvana.com/t/soundsource-and-plugins/31024)

### Inferences
- Implement AU hosting via `AVAudioUnit.instantiate(with:options:)` / `AUAudioUnit`. Default to out-of-process for stability (a crashing plug-in will not take down the audio engine). Offer in-process for lower overhead where the AU supports it.
- Report each plug-in's `latency` and `tailTime`. Show total chain latency (SoundSource's warning is a precedent), and manage the plug-in's internal sample rate when the device rate changes.
- Insert third-party AUs after the native EQ and before the final limiter. Keep the 64-bit native path for the core EQ, since most AUs run float32 internally (not verified per vendor).

### Gaps
- No measurements found of the added latency or CPU overhead of out-of-process AUv3 hosting in a real-time system-wide chain.
- No official FabFilter or Rogue Amoeba statement that Pro-Q 4 runs correctly in SoundSource.

---

## 7. Other audiophile DSP: crossfeed, loudness compensation, room correction/convolution, resampling, spectrum analysis

### Takeaway
The proven open building blocks are:
- **Crossfeed:** bs2b (GPLv2/MIT, with a Jan Meier preset) as used by EasyEffects, or a Rust MIT port.
- **Loudness:** RME ADI-2-style volume-tracking shelves as in CamillaDSP, which is simpler and more predictable than full ISO 226 contours. ISO 226:2023 differs from 2003 by ≤0.6 dB.
- **Convolution/room correction:** partitioned FFT convolution of REW/rePhase/DRC FIRs, as in CamillaDSP and JamesDSP.
- **Resampling:** rubato (MIT/Apache, Rust) or r8brain (MIT, C++). libsoxr is LGPL and stale.

### Cited Findings
**Crossfeed**
- bs2b (Bauer stereophonic-to-binaural): the official project page lists GPLv2 and MIT, © 2005 Boris Mikhaylov. Its "Jan Meier" preset (650 Hz / 9.5 dB) is "close to the parameters of a crossfeeder implemented in Jan Meier's CORDA amplifiers". — [bs2b](https://bs2b.sourceforge.net/)
- A Rust `bs2b` crate (MIT) is implemented from the reference C code. — [docs.rs bs2b 0.2.0](https://docs.rs/crate/bs2b/0.2.0)
- A Hydrogenaudio user reports bs2b's Meier preset sounding almost identical to a Meier crossfeed foobar2000 component at strength 4 (anecdotal). — [Hydrogenaudio](https://hydrogenaudio.org/index.php?msg=853466)
- EasyEffects uses libbs2b for its crossfeed. — [EasyEffects README](https://github.com/wwmm/easyeffects)
- A CamillaDSP crossfeed project exists (license not checked). — [camilladsp-crossfeed](https://github.com/Wang-Yue/camilladsp-crossfeed)

**Loudness compensation**
- CamillaDSP `Loudness` "is the same as the one implemented by the RME ADI-2 DAC FS". It uses shelving boosts above 3500 Hz and below 70 Hz (default 10 dB each, max 20). Only gain is applied above `reference_level`, the full boost applies below `reference_level − 20`, and the boost is linear in between. `attenuate_mid` avoids clipping when the volume control is downstream. v5 makes the shelf frequencies and Q configurable. — [CamillaDSP README](https://github.com/HEnquist/camilladsp/blob/master/README.md); [v5.0.0-beta.1 notes](https://github.com/HEnquist/camilladsp/releases/tag/v5.0.0-beta.1)
- ISO 226:2023 revises 2003. The differences are at most 0.6 dB, mainly at 20 Hz (following ISO 389-7:2019), and the reviewers call the two "practically equivalent". The data cover 20 Hz–12.5 kHz in third-octave steps for listeners aged 18–25. — [Acoustical Science & Technology 2024 review](https://doi.org/10.1250/ast.e23.66); [ISO 226:2023 preview](https://webstore.ansi.org/preview-pages/ISO/preview_ISO+226-2023.pdf)
- FineTune has a loudness module with a K-weighting filter (ITU-style, inferred from file names). — [FineTune repo tree](https://github.com/ronitsingh10/FineTune)

**Convolution / room correction**
- CamillaDSP FIR supports partitioned convolution with long filters. Its related tools include rePhase, REW, DRC and CamillaFIR for generating FIRs, and there are docs on loading coefficients from WAV. — [CamillaDSP README](https://github.com/HEnquist/camilladsp/blob/master/README.md)
- JamesDSP has a partitioned convolver (mono, stereo and full/true stereo LL/LR/RL/RR IRs). — [JDSP4Linux README](https://github.com/Audio4Linux/JDSP4Linux)
- EqualizerAPO's `Convolution:` requires the IR sample rate to match the device. — [EqualizerAPO Configuration reference](https://sourceforge.net/p/equalizerapo/wiki/Configuration%20reference/)

**Resampling**
- CamillaDSP resampling uses rubato: AsyncSinc (with anti-aliasing), AsyncPoly (without) and Synchronous. Async modes enable rate matching between capture and playback clocks. — [CamillaDSP README](https://github.com/HEnquist/camilladsp/blob/master/README.md)
- r8brain-free-src is "high-quality professional audio sample rate converter" (MIT). Per forum reports its free version lacks continuous ratio change, while libsoxr supports varying the rate. Quality comparisons are anecdotal; InfiniteWave's listing of the old "r8brain free" was flagged as outdated. — [r8brain-free-src](https://github.com/avaneev/r8brain-free-src); [KVR SRC thread](https://www.kvraudio.com/forum/viewtopic.php?p=8303878)
- libsoxr (chirlu mirror) is LGPL-2.1, last pushed 2023-11-14. — [soxr](https://github.com/chirlu/soxr)

**Spectrum analyzer**
- The CamillaDSP v5 spectrum analyzer streams over websocket, computes in 32-bit float, and fills buffers only when a client requests them. — [CHANGELOG_5.0_details](https://github.com/HEnquist/camilladsp/blob/v5.0.0-beta.2/CHANGELOG_5.0_details.md)
- eqMac 1.9.2's analyzer now sums both channels. — [eqMac releases](https://github.com/bitgapp/eqMac/releases)

### Inferences
- Crossfeed: implement bs2b-style (first-order low-pass cross path plus high-shelf direct path) with Default/Chu Moy/Jan Meier presets, under the MIT terms or by porting the MIT Rust crate.
- Loudness: offer CamillaDSP/RME-style shelving tied to the app's own volume. Clearly label it as level-dependent. Tying it to ISO 226 is optional and gives little benefit given the 2023 revision is ≤0.6 dB from 2003.
- Spectrum analyzer accuracy for audiophiles needs:
  - A windowed FFT (Blackman-Harris or flat-top for level accuracy) with selectable resolution (e.g., 1/24-oct smoothing).
  - A true-peak meter (4× oversampled) next to sample-peak.
  - A post-EQ clip/limiter indicator.
  
  These are design inferences; no single source benchmarked analyzer accuracy.

### Gaps
- No 2025–2026 independent benchmark (InfiniteWave or ASR) comparing rubato, r8brain and libsoxr at 44.1↔48 kHz was retrieved.
- Meier's own crossfeed algorithm license and implementation details were not found.
- Not researched: HQPlayer (commercial, Signalyst) as a high-end resampling/convolution reference on macOS.
