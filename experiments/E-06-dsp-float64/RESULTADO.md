# E-06 · Núcleo DSP: Precisão, Desempenho e Linguagem — RESULTADO

- **Data:** 2026-11-21
- **Máquina:** MacBook Air arm64 · macOS 26.6 (`25G72`) · Apple clang 21.0.0 (`MacOSX26.sdk`, `-O2`)
- **Código medido:** [`Sources/CTimbreDSP/src/timbre_dsp.cpp`](../../Sources/CTimbreDSP/src/timbre_dsp.cpp) + [`main.cpp`](main.cpp)
- **Veredito:** **Passou · `ADR-0003` promovido a Aceito (C++20 + Accelerate/vDSP `Float64`)**

## Medições Reais Executadas

| Teste | Resultado Medido | Meta / Referência | Classe |
|---|---|---|---|
| Null Test (bypass/neutro, limiter off) | `max_abs_diff = 0.000e+00 (-240.0 dBFS)` | `< -140 dBFS` | **Comprovado** |
| Peak `12 kHz` `+6 dB Q=1.8` @ `48 kHz` (erro max 20 Hz–20 kHz vs analítico) | Vicanek: **`0.3019 dB`** vs RBJ: `1.6869 dB` | Redução de cramping | **Comprovado** |
| Peak `12 kHz` `+6 dB Q=1.8` @ `192 kHz` (erro max 20 Hz–20 kHz vs analítico) | Vicanek: **`0.0205 dB`** vs RBJ: `0.1035 dB` | `< 0.05 dB` em alta taxa | **Comprovado** |
| `20 Hz, +8 dB, Q=4.0` @ `192 kHz`, tom coerente `999.0 Hz -20 dBFS` (`THD+N`) | Float32: **`-43.86 dB`** vs Float64: **`-149.23 dB`** | Justifica `Float64` (`H-06`) | **Comprovado** |
| Limiter True-Peak (`+6 dBFS` entrada, teto `-0.3 dBTP`) | `max_sample = -0.3000 dBFS`, `GR = -6.32 dB` | Zero amostra `> ceiling` | **Comprovado** |
| Limiter True-Peak (`+6 dBFS` entrada, teto `-1.0 dBTP` BT AAC) | `max_sample = -1.0000 dBFS`, `GR = -7.02 dB` | Zero amostra `> -1.0 dBTP` | **Comprovado** |
| Crossfade A/B `20 ms` latência equalizada (`C-04`) | Delta na fronteira = `0.017147` (contínuo, sem clique) | Sem descontinuidade | **Comprovado** |
| CPU 10 bandas @ `48 kHz` (`512` frames) | **`28.90 µs/bloco`** (`0.27%` de `10.67 ms`) | `< 5%` | **Comprovado** |
| CPU 20 bandas @ `48 kHz` (`512` frames) | **`33.87 µs/bloco`** (`0.32%` de `10.67 ms`) | `< 5%` | **Comprovado** |
| CPU 20 bandas @ `192 kHz` (`512` frames) | **`78.12 µs/bloco`** (`2.93%` de `2.67 ms`) | `< 10%` | **Comprovado** |

## Decisão

1. **H-06 promovida a Comprovado:** `Float32` DF2T degrada o piso de ruído/distorção para `-43.86 dB` em filtros graves de Q alto a `192 kHz`, enquanto `Float64` mantém **`-149.23 dB`** (+105 dB de margem).
2. **Núcleo MVP definido:** **C++20 + `Accelerate/vDSP` (`Float64`)** atrás de `timbre_dsp.h` entrega `0.27%–0.32%` de orçamento RT a `48 kHz` sem exigir toolchain Rust.
