# Matriz Real de Capacidades por Dispositivo (`E-07`)

> **Status:** Parcialmente preenchida com medições reais da sonda CLI `E-07` em **2026-11-21** (MacBook Air arm64, macOS 26.6). Dispositivos Bluetooth/USB externos listados como pendentes até conexão física na bancada.
> **Princípio vinculado:** **P11** (*nenhum controle aparece na UI sem capacidade confirmada pela sonda*) e **P4** (*nada inferido é exibido como medido*).

| Dispositivo de Teste | Transporte | UID / Modelo | Taxas suportadas (`AvailableNominalSampleRates`) | Taxa gravável? (`IsPropertySettable`) | Volume HW (Master / Ch1) | Mute HW | Fontes / Tipo | Latência declarada HAL (`SafetyOffset` + `DeviceLatency` @ 48 kHz) | Observações / Bugs macOS 26.6 |
|---|---|---|---|---|---|---|---|---|---|
| **MacBook Air Speakers** | Built-In | `BuiltInSpeakerDevice` | `44.1 / 48 / 88.2 / 96 kHz` | `Sim` | `Master: Sim (el 0) · Ch1: Não` | `Sim` | Built-in Output (`2 ch`) | `48 + 60 frames` (`2,25 ms`) | **Comprovado (E-07):** exige sondar elemento `0` e `1` separadamente |
| **MacBook Air Microphone** | Built-In | `BuiltInMicrophoneDevice` | `44.1 / 48 / 88.2 / 96 kHz` | `Sim` | `Não (saída)` | `Não` | Built-in Input (`1 ch`) | `Safety 24 + Lat 1` | **Comprovado (E-07)** |
| **Microfone do iPhone de Vinícius** | Continuity | `38FD4B68-828B-4C3D-8144-80B100000003` | `48 kHz` | `Sim` | `Não` | `Não` | Continuity (`1 ch`) | `0 + 0` | **Comprovado (E-07):** aparece automaticamente com iPhone próximo |
| **Sennheiser Momentum 4** | Bluetooth (A2DP) | `80:C3:BA:59:92:3E` *(pareado, desconectado na sonda)* | *pendente conexão física* | — | — | — | — | — | Validar queda HFP em `E-08` e RFCOMM GAIA v3 em `E-09` |
| **Sennheiser Momentum 4** | USB-C (DAC integrado) | *pendente conexão física* | *UAC 1.0 esperado 48 kHz/16-bit* | — | — | — | — | — | Verificar volume HW vs SW |
| **AirPods Pro** | Bluetooth | `98:A5:F9:58:0C:F2` *(pareado, desconectado na sonda)* | *pendente conexão física* | — | — | — | — | — | Verificar interação com troca automática Apple |
| **DAC USB externo / HDMI** | USB / HDMI | *pendente conexão física* | — | — | — | — | — | — | Validar volume HW vs SW e regra G-05 |
