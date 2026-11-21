# ADR-0011 · Drivers de dispositivo plugáveis

- **Status:** Aceito · M4 GAIA + Apple Continuity/HAL documentados; E-08/E-09 físicos ainda abertos
- **Data:** 2026-11-21

## Decisão

- O núcleo trata todo dispositivo pelo **HAL do Core Audio** e por uma **sonda de capacidades** executada em runtime (o que existe, o que é gravável). Nenhum controle aparece sem capacidade confirmada (P11).
- **Drivers de fabricante** são módulos opcionais que implementam um protocolo `DeviceDriver` com capacidades declaradas (`battery`, `ancMode`, `transparency`, `onboardEQ`, `sidetone`, `multipoint`, `firmwareInfo`, …), cada uma marcada `read` ou `readWrite`.
- **Read-first:** todo driver entra lendo estado; escrita só depois de validada no laboratório, só para operações reversíveis, com restauração do estado anterior e registro.
- **Lista negra explícita:** nenhum driver implementa atualização de firmware, reset de fábrica, alteração de pareamento ou comandos de fabricação.
- Driver roda isolado (ver ADR-0006); falha de driver nunca afeta o motor de áudio.
- O primeiro driver é o Sennheiser Momentum 4 (GAIA v3 RFCOMM read-first).
- O segundo driver é a **linha Apple Audio Accessory** (`AirPodsProAdapter` / `AirPodsFamilyDriver.swift`): HAL + Continuity BLE proximity read-only + AutoEq; **sem AACP** (ANC/Transparency permanecem no macOS). Ver [`airpods-laboratorio.md`](../03-viabilidade/airpods-laboratorio.md) e Nota [`12`](../00-pesquisa/notas-fase-2/12_airpods_linha_apple.md).
- **Status:** Aceito para HAL+Continuity (parser + UI); bancada física Continuity/E-08 ainda pendente.
