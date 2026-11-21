# Nota 12 · Linha Apple Audio Accessory (AirPods → Max) no macOS

> **Status:** Auditoria + implementação headless **2026-11-21**.
> **Regra de evidência:** Comprovado / Provável / Hipótese / Desconhecido. **Zero escrita AACP** e **zero código GPL/AGPL**.

---

## 1. Síntese

Para o `timbr.`, a linha Apple **não** é um segundo Momentum 4 (GAIA write/read). É um produto com **fronteira dura** no macOS:

1. **HAL + Guardião G-01** — o que o audiófilo precisa todos os dias (sem queda HFP).
2. **Continuity BLE passivo** — bateria L/R/Case, in-ear, lid e flip primary/secondary quando o case anuncia proximity-pairing.
3. **Matriz de capacidades** por Model ID (AirPods 4 / 4 ANC / Pro 2 / Pro 3 / Max…) — chips systemManaged, sem toggles.
4. **AutoEq por modelo** — AirPods 4 (Rtings 5128) + linhagem Pro/Max; aviso de Spatial Audio.
5. **AACP fechado** — ANC/Transparency/gestures ficam no SO; a UI **explica** isso (P11), não finge controles.

---

## 2. Inventário OSS (estado da arte)

| Projeto | Licença | Plataforma | Valor | Uso no `timbr.` |
|---|---|---|---|---|
| **LibrePods** | GPL-3.0 | Linux / Android | Mapa AACP completo (L2CAP `0x1001`), Magic Pairing, Hearing Aid EQ | **Estudo apenas** — prova que macOS Developer ID não abre `0x1001` |
| **airpods-macfeel** | GPL-3.0 | Linux (LibrePods fork) | UX “Mac-feel”, handoff; alerta fw 9A348 vs VendorID spoof | Estudo de UX / anti-padrões de spoof |
| **AirBattery** | AGPL-3.0 | macOS | Nearbility Engine, widgets | Estudo; **proibido copiar** |
| **apple-ble** | MIT | Python | Parser Continuity proximity puro + decrypt opcional | Estudo MIT; parser Swift **reescrito** |
| **mubar** | MIT | macOS Swift | Scan `0x004C` + GATT 0x180F genérico | Estudo MIT; scan CoreBluetooth próprio |
| **furiousMAC/continuity** | Docs | — | Layout público type `0x07` | Referência de offsets |
| **NoiseBuddy / BeatsBar** | vários | macOS (privado) | Histórico de ANC via privados | Evidência de quebra; fora do escopo |

---

## 3. Fronteira técnica AACP (Comprovado por convergência)

- Canal de controle: L2CAP PSM **`0x1001`**.
- Header típico AACP: `04 00 04 00` + opcode LE16 + payload.
- macOS: `bluetoothd` reserva o canal; apps Developer ID **não** obtêm o socket (sem SIP off / entitlements privados).
- Consequência de produto: **nenhum slider ANC** no `timbr.` para AirPods. Copy honesta no Observatório (`dev.apple.aacp_closed`).

---

## 4. Continuity proximity (implementado)

Ver [`airpods-laboratorio.md`](../../03-viabilidade/airpods-laboratorio.md) §3 e testes em `TimbreEngineTests` (Pro 2 `0x1420`, AirPods 4 `0x1920`/`0x1B20`, Pro 3 `0x2720`, flip-aware).

**Model map (subset crítico):** `0x1920` AirPods 4 · `0x1B20` AirPods 4 ANC · `0x1420`/`0x2420` Pro 2 · **`0x2720` = Pro 3** (não Pro 2 USB-C) · `0x0A20`/`0x1F20` Max.

Limitações honestas:

- Anúncios aparecem sobretudo com **case aberto** / proximidade.
- MAC BLE rotaciona (~15 min) — sem identidade estável sem IRK.
- Blob AES de 16 B **não** é decifrado (precisa MagicAccEncKey via AACP).

---

## 5. UX / Design System

Alinhado à bíblia (`05-design-system`) e à skill Apple Design:

- **Purpose / Simplicity:** [`AppleAccessoryCard`](../../../Sources/TimbreApp/AppleAccessoryViews.swift) + strip compartilhada (Observatório / Mixer / Notch) — não um clone do app Ajustes.
- **Responsibility:** pedir Bluetooth só para Continuity; explicar AACP fechado; features = chips read-only.
- **Familiarity:** SF Symbols oficiais da família; badges L/R/Case com bolt de charging.
- **Craft / motion:** `TimbreMotion.snappy`/`enter`; `Reduce Motion` no card; sem bounce em telemetria estática.
- **Agency:** “Atualizar Continuity” é opt-in de refresh, não um prompt TCC surpresa (onboarding já cobre BT).
- **Notch:** micro-glyph de bateria no compact; strip completa só no expanded (bíblia: notch sem configuração).

---

## 6. Próximos experimentos físicos

- E-08 (HFP) com AirPods / Pro conectados.
- Validar Continuity live (case open) → atualizar [`matriz-de-dispositivos.md`](../../03-viabilidade/matriz-de-dispositivos.md).
- Comparar AutoEq AirPods 4 / Pro 2 com Spatial off vs on (ABX informal).
- Quando AutoEq publicar Pro 3, substituir fallback Pro 2 no starter catalog.
