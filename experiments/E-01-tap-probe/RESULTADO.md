# E-01 · Sonda de Process Taps (`CATapDescription`) — RESULTADO

- **Data:** 2026-11-21
- **Máquina:** MacBook Air arm64 · macOS 26.6 (`25G72`)
- **Código medido:** [`main.swift`](main.swift)
- **Veredito:** **Passou no ciclo de criação/destruição de Tap API (`status: 0`)** *(Null Test loopback completo e 20 ciclos `kill -9` dependem de `BlackHole 2ch` e grant TCC interativo em sessão GUI).*

## Resultado Real (`Comprovado`)

- `CATapDescription.bundleIDs` + `isProcessRestoreEnabled` disponíveis e compilando em `MacOSX26.sdk` / macOS 26.6.
- `AudioHardwareCreateProcessTap` retornou `status: 0, tapID: 124`.
- `AudioHardwareDestroyProcessTap` retornou `status: 0` sem deixar dispositivo órfão.
