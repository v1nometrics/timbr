# E-07 · Sonda de Capacidades de Dispositivos HAL — RESULTADO

- **Data:** 2026-11-21
- **Máquina:** MacBook Air arm64 · macOS 26.6 (`25G72`) · Swift 6.3.3 (`MacOSX26.sdk`)
- **Código medido:** [`main.swift`](main.swift)
- **Veredito:** **Passou nos dispositivos locais presentes** *(Sennheiser Momentum 4 e AirPods Pro estavam desconectados no momento da execução e seguem marcados como pendentes de bancada física).*

## Dispositivos Medidos (`Comprovado`)

- `BuiltInSpeakerDevice` (**MacBook Air Speakers**): `outChannels=2`, taxas `[44100, 48000, 88200, 96000]` graváveis, **`hwVolumeOutputMainSettable=true`** (element `0`), **`hwVolumeOutputCh1Settable=false`** (element `1`), `hwMuteOutputSettable=true`, `hogModeSettable=true`, `outputLatencyFrames=60` (`1.25 ms`), `outputSafetyOffsetFrames=48` (`1.0 ms`).
- `BuiltInMicrophoneDevice` (**MacBook Air Microphone**): `inChannels=1`, `[44100, 48000, 88200, 96000]` graváveis.
- `38FD4B68-828B-4C3D-8144-80B100000003` (**Microfone do iPhone de Vinícius**, Continuity): `inChannels=1`, `[48000]` gravável.
