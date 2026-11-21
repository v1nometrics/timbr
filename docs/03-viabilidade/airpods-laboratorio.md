# Laboratório · Linha Apple Audio Accessory (AirPods → AirPods Max)

> **Status:** Especificação + implementação headless **2026-11-21** · Paridade documental com [`momentum4-laboratorio.md`](momentum4-laboratorio.md).
> **Princípios:** P3 (sem rastro), P7 (local), P11 (sem promessa falsa), [ADR-0011](../07-decisoes/ADR-0011-drivers-de-dispositivo.md), bíblia DS [`05-design-system/`](../05-design-system/), Nota [`07`](../00-pesquisa/notas-fase-2/07_momentum4_protocolo_e_ecossistema.md) §4 + [`12_airpods_linha_apple.md`](../00-pesquisa/notas-fase-2/12_airpods_linha_apple.md).
> **Marcas:** “AirPods”, “AirPods Max”, “Beats” e “Apple” são marcas de terceiros; uso exclusivamente descritivo/nominativo.

---

## 1. Pergunta decisória

O que um app **Developer ID** (sem SIP off, sem entitlements privados) consegue entregar, com honestidade audiófila, para **AirPods / AirPods Pro / AirPods Max / Beats H1–H2** no macOS moderno?

| Camada | Veredito | Evidência |
|---|---|---|
| HAL Core Audio (volume, mute, default device, sample rate, HFP detect) | **Comprovado** | APIs públicas; Guardião G-01 |
| Continuity BLE proximity-pairing `0x004C` / type `0x07` (bateria L/R/Case, in-ear, lid, modelo) | **Implementado** (parser flip-aware + scan + matriz de capacidades); validação física pendente com case aberto | furiousMAC/continuity (público); MIT `apple-ble`, `mubar` (estudo); reimplementação própria |
| AACP L2CAP `0x1001` (ANC, Transparency, head gestures, Conversational Awareness, Hearing Aid EQ) | **Inviável** em user-space macOS | LibrePods (GPL-3.0, Linux/Android only); BeatsBar / NoiseBuddy |
| Decrypt MagicAccIRK / MagicAccEncKey (`0x30`/`0x31`) | **Inviável** (depende de AACP) | LibrePods DeepWiki; apple-ble docs |
| AutoEq / correção Float64 por modelo | **Comprovado** (presets offline) | Catálogo starter + fetch AutoEq |

---

## 2. Escopo do driver `AirPodsProAdapter` (`apple-audio-accessory-hal-continuity`)

Código: [`Sources/TimbreEngine/AirPodsFamilyDriver.swift`](../../Sources/TimbreEngine/AirPodsFamilyDriver.swift).

1. **Classificação por nome HAL** → `AppleAudioAccessoryKind` (`airPods` / `airPodsPro` / `airPodsMax` / `beats`).
2. **Telemetria HAL** → codec inferido (`AAC (A2DP)` vs `HFP/SCO (degraded)`), status `hal-observed · aacp-closed`.
3. **Scan Continuity passivo** (burst duty-cycle ~8 s por `ensureStarted`/`requestScanBurst`, TTL 120 s, sem cross-family; same-family ambíguo → sem guess) → inicia **somente** quando a saída HAL ativa é Apple; L/R/Case + charging (`trustBadge = reported`). In-ear/lid parseados no snapshot para testes/lab; ainda **não** na UI.
4. **Matriz de capacidades** por Model ID (`AppleModelCapabilityProfile`) — chips somente leitura; nunca toggles AACP.
5. **Nunca inventa ANC/Transparency** (`ancEnabled = nil`) — P11.
6. **Aviso Spatial Audio** no card Apple **e** no painel AutoEq quando A2DP.

### O que a UI mostra (bíblia + Apple Design)

- [`AppleAccessoryCard`](../../Sources/TimbreApp/AppleAccessoryViews.swift) no Observatório; strip L/R/Case no Mixer (destino ativo) e no Notch expanded; micro-glyph de bateria no Notch compact.
- SF Symbol tipado (`airpods` / `airpods.pro` / `airpodsmax`), tipografia Timbre, badges `REPORTADO`/`INFERIDO`, copy trilíngue AACP fechado.
- Motion: `TimbreMotion.snappy` / `enter`; `accessibilityReduceMotion` no card; sem bounce em superfícies estáticas (WWDC: bounce só com momentum do gesto).
- Feedback contínuo: “Atualizar Continuity” reativa scan + refresh HAL — sem modal bloqueante.

---

## 3. Protocolo Continuity (read-only) — layout adotado

Manufacturer ID Apple `0x004C`. Mensagem proximity-pairing type `0x07` (público, furiousMAC):

| Offset (após type/len) | Campo | Notas |
|---|---|---|
| 0 | `0x01` prefix | |
| 1–2 | Model ID BE | Ver tabela abaixo |
| 3 | Status | bit5 = primary-is-left (flip); bit1/bit3 = in-ear primary/secondary; bit2/6 = in-case broadcast |
| 4 | Battery nibbles | lo = primary, hi = secondary; após flip → L/R; `0…10` → %×10; `0xA`=100; `0xF` = ausente |
| 5 | Case nibble + charge flags | bits charge primary/secondary/case |
| 6 | Lid | bit3=1 → closed **somente** se in-case broadcast |
| 7 | Color | |
| 8 | `0x00` | |
| 9… | Encrypted 16 B | **não decifrado** (precisa MagicAccEncKey) |

### Model IDs reconhecidos (subset)

| ID | Produto |
|---|---|
| `0x0220` / `0x0F20` / `0x1320` | AirPods 1 / 2 / 3 |
| `0x1920` / `0x1B20` | AirPods 4 / AirPods 4 (ANC) |
| `0x0E20` | AirPods Pro 1 |
| `0x1420` / `0x2420` | AirPods Pro 2 / Pro 2 (USB-C) |
| `0x2720` | **AirPods Pro 3** |
| `0x0A20` / `0x1F20` | AirPods Max / Max (USB-C) |
| `0x2002`… | Beats H1/H2 Continuity |

---

## 4. AutoEq starter (offline)

| ID | Modelo |
|---|---|
| `apple-airpods-4-rtings-5128` | AirPods 4 (Rtings B&K 5128) |
| `apple-airpods-4-anc-rtings-5128` | AirPods 4 ANC on |
| `apple-airpods-pro-2-crinacle` | AirPods Pro 2 |
| `apple-airpods-pro-1-crinacle` | AirPods Pro 1 |
| `apple-airpods-3-crinacle` | AirPods 3 |
| `apple-airpods-max-oratory` | AirPods Max |

> Pro 3: ainda **sem** medição dedicada no índice AutoEq público — matcher prioriza Pro 2 até publicar; UI mantém aviso Spatial.

Aviso obrigatório na UI: Áudio Espacial / Head Tracking **invalida parcialmente** a curva AutoEq.

---

## 5. Protocolo de bancada física (ainda aberto)

1. Parear AirPods Pro (e, se possível, AirPods Max) ao Mac de teste.
2. Abrir o case perto do Mac → confirmar card L/R/Case no Observatório (`hal+continuity-proximity`).
3. Reproduzir A2DP → confirmar G-01 se mic BT for aberto (Discord/Meet).
4. Aplicar preset AutoEq do modelo → A/B com Spatial off.
5. Registrar resultados em `experiments/E-08-*/RESULTADO.md` e preencher [`matriz-de-dispositivos.md`](matriz-de-dispositivos.md).

---

## 6. Fronteiras éticas / licença

| Projeto | Licença | Uso no `timbr.` |
|---|---|---|
| LibrePods | GPL-3.0 | **Só estudo** — prova de inviabilidade AACP no macOS; **zero código** |
| AirBattery | AGPL-3.0 | **Só estudo** — zero código |
| apple-ble / mubar | MIT | Estudo do layout Continuity; parser **reescrito** |
| furiousMAC/continuity | Docs públicas | Referência de offsets |
| AutoEq | MIT | Presets / paths |

Denylist permanente: spoof de VendorID Apple (`bluetooth:004C`), Magic Pairing, escrita AACP, OTA.
