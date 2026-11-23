# Laboratório Momentum 4, AirPods Pro e Arquitetura de Drivers (`DeviceDriver`)

> **Status:** Plano seguro para **E-09** · Baseado em [Nota 07](../00-pesquisa/notas-fase-2/07_momentum4_protocolo_e_ecossistema.md) e [ADR-0011](../07-decisoes/ADR-0011-drivers-de-dispositivo.md).
> **Regra de segurança inegociável:** nenhuma escrita Bluetooth vai a hardware real fora deste protocolo, sem identificação prévia de UUID + leitura de modelo/firmware e sem snapshot/restauração de estado. **Proibido** implementar OTA/DFU (`0x02xx`), reset de fábrica (`0x0040`), limpeza de pareamento (`0x1405`/`0x1406`) ou o comando letal **`0x0607`**.

---

## 1. Objetivo de E-09 e Pergunta Decisória

**Pergunta:** Um app macOS não-sandboxed (Developer ID + `NSBluetoothAlwaysUsageDescription`) consegue abrir um canal `IOBluetoothRFCOMMChannel` com o **Sennheiser Momentum 4** usando o UUID GAIA v3 (`A2129FF3-081B-4C45-8AFE-469D9C4842EC`) **enquanto o áudio A2DP está tocando**, sem degradar ou desconectar o stream de áudio?

### Respostas possíveis e impacto no roadmap
- **Cenário A (RFCOMM simultâneo estável):** habilitamos o driver Momentum 4 no **Estúdio e Notch** (bateria real inclusive no USB-C, ANC/Transparency, codec real `0x0800`, sample rate `0x089A`, detecção real de EQ interno para Guardião G-04).
- **Cenário B (RFCOMM derruba/engasga A2DP no macOS):** investigar fallback via **BLE GATT** (`63331337-23C1-11E5-B696-FEFF819CDC9F`, característica `...3B` write / `...3C` notify).
- **Cenário C (macOS bloqueia ambos em paralelo ao A2DP):** o driver Bluetooth avançado é adiado/descartado como controle ativo e o Momentum 4 continua com suporte 100% HAL + perfis AutoEq separados (BT/USB/3.5mm-Ativo vs 3.5mm-Passivo).

---

## 2. Contrato Arquitetural `DeviceDriver` (Extensível Multi-Marca)

O núcleo de dispositivos do `timbr` opera pelo protocolo `DeviceDriver` (em processo/actor isolado do motor de áudio, conforme [ADR-0006](../07-decisoes/ADR-0006-processo-do-motor.md) e [ADR-0011](../07-decisoes/ADR-0011-drivers-de-dispositivo.md)):

```swift
public enum CapabilityAccess: String, Sendable { case readOnly, readWrite }

public enum DriverCapability: Hashable, Sendable {
    case batteryTelemetry          // % exato + estado de carga
    case ancMode                   // Off / Adaptive / Custom
    case transparencyLevel         // 0...100
    case antiWind                  // Off / Max / Auto
    case onboardEQState            // Neutral vs UserEQ vs Podcast vs Personalized (para G-04!)
    case codecTelemetry            // AAC / aptX / SBC + sample rate reportado pelo fone
    case behaviorFlags             // Smart Pause, On-Head, Touch Lock, Auto Power-Off
    case sidetoneLevel             // 0...N
}

public protocol DeviceDriver: Actor {
    var driverID: String { get }
    var supportedCapabilities: [DriverCapability: CapabilityAccess] { get }
    func probeMatch(deviceUID: String, bluetoothAddress: String?) async -> DriverMatchConfidence
    func connectReadOnly() async throws -> DeviceDriverSnapshot
    func apply(_ command: DriverCommand) async throws -> DeviceDriverSnapshot
    func disconnect() async
}
```

- **Princípio P11 (Sem promessas falsas):** a UI só renderiza um controle de hardware se `supportedCapabilities[cap]` existir **e** o `connectReadOnly()` tiver confirmado o firmware mínimo exigido.
- **Deny-list no Framer:** antes de serializar qualquer quadro no `IOBluetoothRFCOMMChannel`, o `GaiaV3Framer` valida uma lista de bloqueio imutável (`0x0607`, `0x0605...0x06FF` fora de `0x0600..0x0603`, `0x0040`, `0x1405`, `0x1406`, `0x02xx`, `0x001D:0x0Cxx`), abortando em debug (`assertionFailure`) e rejeitando em release.

---

## 3. Protocolo Seguro de Bancada — E-09 (Passo a Passo)

### Fase 9.1 · Simulação Offline (Zero Hardware)
1. Validar o parser/framer GAIA v3 em Swift usando os vetores sintéticos MIT de `android-momentum-4-widget/protocol-vectors.json` (adaptados e verificados).
2. Validar o decodificador de firmware (`0x1301`), bateria (`0x0703`), estado EQ Gen1 vs Gen2 (`< 3.18.0` vs `>= 3.18.0`), tabela ANC (`0x1B01`) e proteção da denylist.

### Fase 9.2 · Passivo SDP & Read-Only (MacBook + Momentum 4 tocando A2DP)
1. Conectar o Momentum 4 normalmente via Bluetooth do macOS e iniciar reprodução de tom/música contínua (48 kHz AAC).
2. Rodar `E-09-probe` executando apenas:
   - Consulta SDP pelo UUID **`A2129FF3-081B-4C45-8AFE-469D9C4842EC`** (nunca enviar pacote em canal não retornado por SDP!).
   - Abertura de `IOBluetoothRFCOMMChannel` assíncrona.
   - Leitura exclusiva (**4 comandos Get + 0 Set**):
     1. `0x1206` (`Versions_ModelId`)
     2. `0x1201` (`Service_SystemReleaseVersion` — ex.: `3.38.3`)
     3. `0x0603` (`Battery_Percent`) e `0x0602` (`Battery_ChargingStatus`)
     4. `0x0800` (`Sound_CodecUsed`) e `0x0804` (`AudioMode`)
     5. `0x1A05` / `0x1A01` / `0x1A03` (estado atual de ANC/Transparência)
3. **Observação obrigatória durante a leitura:** monitorar `log stream --predicate 'subsystem == "com.apple.bluetooth"'` procurando `A2DP Audio Queue full`, `A2DP packet flushed`, `L2CAP Write in progress` ou queda de áudio perceptível.

### Fase 9.3 · Escrita Reversível Controlada (Só após 9.2 estável)
1. Gravar snapshot completo do estado lido na Fase 9.2 antes de escrever qualquer comando.
2. Testar **um único comando reversível por vez** (ex.: alternar `AudioMode` entre atual e `0`/`1`, ou `ANC_Transparency` +5% e voltar), confirmando leitura de retorno (`notification` + `Get`) e restaurando o valor original ao final ou em `defer`/ctrl-C.
3. Verificar **Guardião G-04 na prática:** colocar EQ no Smart Control (app iOS) ou via flag e confirmar que `0x0804` retorna `1` (`userEq`), disparando o detector no Mac.

---

## 4. Matriz de Conexões e Perfis do Momentum 4

| Conexão | Chave de Perfil no Banco Local | Impedância / DSP Interno | Comportamento Esperado no `timbr` |
|---|---|---|---|
| **Bluetooth A2DP** | `bt:<BD_ADDR>:active` | DSP & ANC ativos | Driver GAIA v3 ativo; Guardião G-01 anti-HFP; AutoEq para M4 BT/Ativo. |
| **USB-C (`Momentum 4 USB`)** | `usb:<DeviceUID>:uac1` | UAC 1.0 (teto 16-bit/48 kHz), DSP ativo | Alerta informativo de UAC 1.0 (48 kHz max); fallback automático de volume em software se slider HAL estiver bloqueado no macOS. |
| **3.5 mm P2 Ligado** | `analog:<DeviceUID>:active` | **470 Ω**, DSP interno ativo | Perfil AutoEq "Momentum 4 (Active / Wired)"; aviso de EQ interno se houver perfil gravado. |
| **3.5 mm P2 Desligado** | `analog:<DeviceUID>:passive` | **60 Ω**, DSP desligado (passivo) | Perfil AutoEq **distinto** ("Momentum 4 · Passive 3.5mm"). Como a saída analógica P2 do Mac não detecta se o fone está ligado ou sem bateria, o card do dispositivo exibe **alternância manual de 1 clique (`Ativo 470 Ω` / `Passivo 60 Ω`)**. |

---

## 5. Escopo Realista para AirPods Pro (Sem Quebrar Segurança do macOS)

> **Documento dedicado (paridade M4):** [`airpods-laboratorio.md`](airpods-laboratorio.md) · Nota [`12_airpods_linha_apple.md`](../00-pesquisa/notas-fase-2/12_airpods_linha_apple.md).

| Recurso | Status no macOS (App Developer ID) | Estratégia no `timbr` |
|---|---|---|
| **Volume, mute, balanço, seleção, Spatial status** | **Comprovado (Core Audio HAL)** | Totalmente suportado nativamente. |
| **Proteção anti-HFP ("Output Only")** | **Comprovado (Core Audio HAL)** | Impede queda automática para mic BT de 16 kHz / 24 kHz mono em chamadas ou ao abrir Discord/Slack/Meet. |
| **Controle de ANC / Transparency / Head Gestures (AACP L2CAP `0x1001`)** | **Inviável em user-space macOS** | Bloqueado por `bluetoothd` e entitlements privados (confirmado pelo `LibrePods`). **Não prometemos nem tentaremos burlar.** |
| **Bateria L/R/Case passiva via BLE Continuity (`0x004C`)** | **Hipótese a validar (E-07/E-08)** | Ler apenas anúncios passivos `CoreBluetooth` se o macOS expuser sem pareamento especial; se restrito/instável, exibir apenas o que o HAL/system reportar. |
| **Correção AutoEq (AirPods Pro 1 / 2 / 3 USB-C)** | **Comprovado** | Presets com aviso no Observatório se Áudio Espacial / Head Tracking estiver alterando a curva alvo. |
