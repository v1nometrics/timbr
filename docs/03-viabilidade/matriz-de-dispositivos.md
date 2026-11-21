# Matriz Real de Capacidades por Dispositivo (Template para E-07)

> **Status:** Aguardando execução da sonda CLI `E-07` (`AudioObjectGetPropertyData` / `IsPropertySettable`).
> **Princípio vinculado:** **P11** (*nenhum controle aparece na UI sem capacidade confirmada pela sonda*) e **P4** (*nada inferido é exibido como medido*).

| Dispositivo de Teste | Transporte | UID / Modelo | Taxas suportadas (`AvailableNominalSampleRates`) | Taxa gravável? (`IsPropertySettable`) | Volume HW (L/R/Master) | Mute HW | Fontes de Clock / Data Source | Latência declarada HAL (`SafetyOffset` + `DeviceLatency`) | Observações / Bugs macOS 26/27 |
|---|---|---|---|---|---|---|---|---|---|
| **Alto-falantes MacBook** | Built-In | *pendente E-07* | — | — | — | — | — | — | — |
| **Microfone MacBook** | Built-In | *pendente E-07* | — | — | — | — | — | — | — |
| **Sennheiser Momentum 4** | Bluetooth (A2DP) | *pendente E-07* | — | — | — | — | — | — | Validar queda HFP em `E-08` e RFCOMM em `E-09` |
| **Sennheiser Momentum 4** | USB-C (DAC integrado) | *pendente E-07* | — | — | — | — | — | — | Verificar volume HW vs SW e taxa max |
| **AirPods Pro** | Bluetooth | *pendente E-07* | — | — | — | — | — | — | Verificar interação com troca automática Apple |
| **DAC USB externo** *(se disponível)* | USB | *pendente E-07* | — | — | — | — | — | — | Validar volume HW vs SW e regra G-05 |
| **Saída HDMI / DisplayPort** | HDMI / DP | *pendente E-07* | — | — | — | — | — | — | Verificar necessidade de volume SW ou DDC (`MonitorControl`) |
