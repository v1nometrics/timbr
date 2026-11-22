# E-12 · Geometria Real do Notch (`NSScreen`) — RESULTADO

- **Data:** 2026-11-21
- **Máquina:** MacBook Air arm64 · macOS 26.6 (`25G72`)
- **Código medido:** [`main.swift`](main.swift)
- **Veredito:** **Passou · geometria dinâmica via `NSScreen` validada**

## Medição Real (`Comprovado`)

- Tela `Built-in Retina Display` (`1470 × 956 pt`, `backingScaleFactor = 2.0`):
  - `safeAreaTopInset = 32 pt`
  - `auxiliaryTopLeftArea = { x: 0, y: 924, w: 646, h: 32 }`
  - `auxiliaryTopRightArea = { x: 825, y: 924, w: 645, h: 32 }`
  - **`computedNotchWidthPt = 179 pt`**
- Confirma que calcular a largura do notch dinamicamente a partir de `auxiliaryTopRightArea.minX - auxiliaryTopLeftArea.maxX` elimina dependência de tabelas fixas entre modelos Air/Pro.
- *Pendência física:* medição de energia em `Instruments / powermetrics` em repouso prolongado e MacBook Pro OLED.
