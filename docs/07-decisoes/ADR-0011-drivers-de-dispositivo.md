# ADR-0011 · Drivers de dispositivo plugáveis

- **Status:** Aceito na direção · detalhes do primeiro driver decidem em E-09
- **Data:** 2026-11-21

## Decisão

- O núcleo trata todo dispositivo pelo **HAL do Core Audio** e por uma **sonda de capacidades** executada em runtime (o que existe, o que é gravável). Nenhum controle aparece sem capacidade confirmada (P11).
- **Drivers de fabricante** são módulos opcionais que implementam um protocolo `DeviceDriver` com capacidades declaradas (`battery`, `ancMode`, `transparency`, `onboardEQ`, `sidetone`, `multipoint`, `firmwareInfo`, …), cada uma marcada `read` ou `readWrite`.
- **Read-first:** todo driver entra lendo estado; escrita só depois de validada no laboratório, só para operações reversíveis, com restauração do estado anterior e registro.
- **Lista negra explícita:** nenhum driver implementa atualização de firmware, reset de fábrica, alteração de pareamento ou comandos de fabricação.
- Driver roda isolado (ver ADR-0006); falha de driver nunca afeta o motor de áudio.
- O primeiro driver é o Sennheiser Momentum 4; o segundo candidato é AirPods (somente o que for público ou estável).
