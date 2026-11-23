# Nota 07 · Sennheiser Momentum 4, Protocolo GAIA v3, AirPods Pro e Ecossistema Bluetooth

> **Status:** Auditoria primária concluída em 2026-11-21 · **Escopo:** OS 5 links enviados pelo autor + ecossistema estendido (Sennheiser Smart Control / Plus, AirPods Pro AACP/LibrePods, multi-marca Sony/Bose/Nothing/Jabra/B&W).
> **Regra de evidência:** Cada fato está rotulado como **Comprovado** (código/especificação auditada ou captura em hardware documentada), **Provável** (convergência de múltiplas fontes independentes sem teste local no nosso Mac), **Hipótese** ou **Desconhecido**. **Zero escrita Bluetooth foi executada em hardware próprio.**

---

## 1. Síntese Executiva ("Isto é realidade para nós?")

1. **Sennheiser Momentum 4 no macOS via RFCOMM/GAIA v3 — SIM, com alta probabilidade técnica e ROI excepcional (Comprovado no protocolo / Provável no macOS sob E-09):**
   - O Momentum 4 não exige autenticação nem handshake criptográfico no canal **Qualcomm GAIA v3** sobre Bluetooth Classic RFCOMM (Service UUID `A2129FF3-081B-4C45-8AFE-469D9C4842EC`, **Comprovado** em `bundle.pretty.js` do Smart Control 4.9.3 e testado em hardware fw `3.38.3` por `xndbogdan/sennheiser-control` e `DanSmith888/omarchy-momentum4`).
   - Diferente do Linux (onde apps como `omarchy-momentum4` precisam abrir sockets `AF_BLUETOOTH` ou `PipeWire/BlueZ`), o macOS expõe **`IOBluetoothRFCOMMChannel`** em user-space (com `NSBluetoothAlwaysUsageDescription`), permitindo abrir um canal serial de controle lado a lado com o stream **A2DP** ativo no mesmo `BD_ADDR` (**Provável**, validar coexistência sem dropouts no macOS durante **E-09**).
   - **O que conseguimos controlar no M4 (se E-09 confirmar):** bateria real (mesmo no cabo USB carregando, `0x0603`), estado de carregamento (`0x0602`), modos ANC (`Off` / `Adaptive` / `Custom 0–100`), Anti-Wind (`Off/Max/Auto`), Bass Boost (`0x1008/0x1009`), EQ interno de 5 bandas Gen2 (`0x1001/0x1002`), AudioMode (`0=Off/Neutral, 1=UserEQ, 2=Podcast, 3=PersonalizedSound`), Smart Pause, On-Head Detection, Comfort Calls, Touch Lock (`0x1606/0x1607`), Auto Power-Off, Sidetone (`0–4`), leitura do codec ativo reportado pelo fone (`0x0800`) e sample rate do stream (`0x089A`) — algo que **nem o Core Audio público do macOS informa**.
2. **AirPods Pro no macOS — CONTROLE PROPRIETÁRIO BLOQUEADO EM USER-SPACE; VALOR VIA HAL + CONTINUITY READ-ONLY:**
   - **Realidade técnica:** o protocolo proprietário da Apple (**AAP/AACP** sobre L2CAP PSM `0x1001`) é reservado exclusivamente ao `bluetoothd` e exige entitlements privados não disponíveis para apps distribuídos via Developer ID sem desativar SIP (**Comprovado** por `LibrePods`, `BeatsBar`, `NoiseBuddy`). Portar `LibrePods` para abrir L2CAP `0x1001` no macOS **não funciona** em um Mac padrão.
   - **O que é realidade para AirPods Pro no timbr:** controle completo pelo **Core Audio HAL** (volume, mudo, balance, seleção, detecção de Spatial/Head-Tracking via APIs públicas aplicáveis), proteção ativa **"Output Only"** contra queda A2DP→HFP (**Comprovado**), calibração AutoEq / presets específicos, e **investigação read-only** de beacons **BLE Continuity (`0x004C`)** via `CoreBluetooth` para bateria L/R/Case se o macOS expuser os dados de anúncio sem mascaramento (**Hipótese**, testar em E-07/E-08).
3. **O Gist do `dvf` sobre macOS (`aptX` / `AAC` / `bluetoothaudiod`) está OBSOLETO no macOS moderno (Comprovado):**
   - O `Bluetooth Explorer` (Xcode 11 Additional Tools) quebra no macOS Sonoma+ e os comandos `defaults write bluetoothaudiod "Enable AptX codec"` / `"Enable AAC codec"` **pararam de surtir efeito no macOS 14/15+** (**Comprovado** pelos comentários de 2024 no próprio gist `dvf` #5093622, #5155391, #5178248, #5264847). A Apple removeu o suporte a aptX clássico no daemon moderno de áudio Bluetooth, negociando **AAC-LC (256 kbps max VBR)** ou SBC automaticamente, e não oferece API pública para ler nem forçar codec A2DP no Core Audio (**Comprovado**).

---

## 2. Auditoria dos 5 Repositórios/Links Indicados + Ecossistema Estendido

| Projeto / Fonte | URL | Linguagem / Stack | Licença | O que entrega de melhor | Armadilhas / Limitações | Como o `timbr` aproveita |
|---|---|---|---|---|---|---|
| **1. `timmo001/omarchy-momentumctl`** | [GitHub](https://github.com/timmo001/omarchy-momentumctl) | TypeScript / Bun + `Effect` | **Apache-2.0** | Arquitetura limpa (`Gaia.ts`, `Headset.ts`, `Rfcomm.ts`, `Audio.ts`); mapeia **preset Harman de 5 bandas derivado do AutoEq** (`[-3.5, -0.5, 2.5, -0.5, -0.5]`); trata EQ `±12.8 dB` em byte signed centibel (`dB×10`). | Acoplado a Linux (`libc` `AF_BLUETOOTH` + PipeWire/BlueZ); sem lógica Gen1 (< 3.18.0). | **Referência permissiva (Apache-2.0):** inspirar modelagem reativa de estado e valores de preset; reimplementar transporte em Swift (`IOBluetooth`). |
| **2. `f3y0/momentum4-control`** | [GitHub](https://github.com/f3y0/momentum4-control) | Python 3 + PyQt6 + `socket` | **MIT** | Tray minimalista focada no essencial: ANC status (`0x1A04/0x1A05`), Transparency (`0x1A02/0x1A03`), Bass Boost (`0x1008/0x1009`), notificações (`0x0007`), reconexão resiliente. | Constrói frame como `FF 03` + `len.to_bytes(2, "big")` (funde `flags`+`len`, falha se payload > 254B); lista fixa de canais RFCOMM (`[2,1,15...]`) sem SDP UUID. | **Referência MIT:** usar lista de canais fallback **apenas atrás de resolução SDP** pelo UUID `A2129FF3-081B-4C45-8AFE-469D9C4842EC`. |
| **3. `Picazsoo/android-momentum-4-widget`** | [GitHub](https://github.com/Picazsoo/android-momentum-4-widget) | Kotlin + Jetpack Compose | **MIT** | **Ouro em UX e máquina de estados (`NoiseControl.kt`, `EqModel.kt`, `GaiaSession.kt`):**<br>• Slider contínuo de 7 paradas (`[100,83,67,50,33,17,0]`) com readout semântico (`ANC 100%` ↔ `Balanced` ↔ `Transp. 100%`)<br>• **Transições ordenadas sem passo redundante** (`steps(target, confirmed)`)<br>• **Trava acidental no widget** (lock veil)<br>• **Fixtures sintéticos de protocolo (`protocol-vectors.json`)**. | Específico para Android (`BluetoothSocket`); foca em fw `3.38.3` (Gen2). | **Referência MIT direta:** adotar máquina de estados confirmada (`Confirmed`), escala semântica `Balanced` em 50, proteção contra escrita cega e suíte de vetores binários no XCTest/SwiftTesting! |
| **4. `gjabell/momentumctl`** (`~gjabell` / Codeberg `galen/momentumctl`) | [sr.ht](https://git.sr.ht/~gjabell/momentumctl) / [GitHub](https://github.com/gjabell/momentumctl) | Rust (`bluer` / CLI) | **MIT** | Pioneiro na descoberta dos IDs de **Device Settings** (`0x0400/0401` on-head, `0x080A/080B` auto-call, `0x080C/080D` smart pause, `0x0814/0815` comfort calls) e validação BLE/RFCOMM. | Depende de `BlueZ` (`bluer`); `sr.ht` retornou HTTP 500 durante a auditoria (espelho oficial ativo no GitHub/Codeberg). | **Referência MIT:** validar paridade de IDs e comandos de comportamento do fone. |
| **5. `dvf/change-codec.md` (Gist #4841058)** | [Gist](https://gist.github.com/dvf/3771e58085568559c429d05ccc339219?permalink_comment_id=4841058) | Tutorial macOS (`bluetoothaudiod`) | N/A (doc) | Documenta o problema histórico de codecs BT no macOS (SBC vs AAC vs aptX) e os parâmetros de log do `bluetoothd` (`A2DP configured at 44.1 KHz. Codec: AAC-LC, VBR max: 256 kbps`). | **Obsoleto em macOS Sonoma/Sequoia/Tahoe:** `Bluetooth Explorer` crasha e `defaults write bluetoothaudiod` não força mais aptX nem altera bitpool. | **Lição crítica para o Guardião:** nunca prometer "forçar aptX no macOS"; usar leitura passiva do log `bluetoothd` (se acessível) + consulta `0x0800` via GAIA no M4 como **prova real** de codec! |
| **6. `DanSmith888/omarchy-momentum4`** | [GitHub](https://github.com/DanSmith888/omarchy-momentum4) | Bash/Python/QML (`m4ctl`) | **MIT** | **Descobertas críticas de segurança por captura real em 2.13.42 → 3.38.3:**<br>• Descobriu que **`0x0607` derruba/trava o fone da barra Bluetooth** exigindo power-cycle!<br>• Descobriu que `0x1403` [00] / `0x1405` apaga pareamento<br>• Confirmou notificações `0x089A` (sample rate ativo) e `0x0682` (cabo conectado). | Escrito para Linux/Quickshell. | **Obrigatório:** incorporar a **blocklist de comandos letais** do `PROTOCOL.md` deste repo no driver do `timbr`! |
| **7. `xndbogdan/sennheiser-control`** | [GitHub](https://github.com/xndbogdan/sennheiser-control) | Rust + Docs de RE | Docs / RE (verificar `LICENSE`) | **O mapa mais completo já publicado do protocolo Sennheiser:** engenharia reversa estática do **Smart Control 4.9.3/4.9.4** (`m4.json`, `user-eq-1/2`, `audio-mode-1/2`, `sound-personalization-1`) E do **Smart Control Plus 1.6.3** (Flutter/Dart decifrado), + verificação física em M4 fw `3.38.3`. | Apenas fatos de protocolo devem ser extraídos se não houver licença permissiva explícita no código; código proprietário da Sennheiser não foi incluído no repo original. | **Fonte técnica máxima:** resolve a diferença crítica entre **EQ Gen1 (< 3.18.0)** e **EQ Gen2 (≥ 3.18.0)**, mapeia `PersonalizedSound` (`0x2000..0x2009`), e mapeia toda a família GAIA v3 (`ACCENTUM`, `MTW3/4`, `Sport`). |
| **8. `zaval` (sennheiserDesktopClient)** | [Local tmp auditado] | C++ / Qt6 / QML | Sem `LICENSE` clara (apenas referência de fatos) | Tenta trazer GAIA v3 para desktop (macOS/Linux/Windows) com UI QML + `m4.json` extraído. | Interface Qt pesada, mistura OTA (`Upgrade_*`) no schema, sem isolamento de licença. | Usar **apenas fatos confirmados**; **proibido copiar código** e **proibido expor OTA** (`0x02xx`). |
| **9. `librepods-org/librepods`** | [GitHub](https://github.com/librepods-org/librepods) | C++ / Kotlin / Swift (PacketLogger) | **GPL-3.0** | Referência conceitual completa do protocolo Apple **AACP** sobre L2CAP PSM `0x1001` (ANC, detecção intra-auricular, bateria). | **GPL-3.0** + **incompatível com macOS user-space** (bloqueado por `bluetoothd` e entitlements privados). | **Não copiar código**; registra oficialmente por que controle ANC/head-gestures de AirPods via socket privado está fora do escopo user-space no macOS. |
| **10. `HellzYeahh/earshot` & `Omega-Destroyer/PairFree`** | GitHub | Kotlin / C# / Docs | MIT (`earshot`) / GPL/vários | Mapeamento multi-marca (`SonyHeadphonesClient` MIT, `pbpctrl` MIT/Apache-2.0, `nothing-ear-controller` MIT, `mEDIFIER` MIT, `OpenSCQ30` GPL-3.0). | Inclui alerta sobre **vulnerabilidades RACE da Airoha (CVE-2025-20700/1/2)** e risco de enviar frames GAIA para UUID iAP2. | Adotar regra de ouro: **identificação rigorosa por UUID SDP + `Versions_ModelId` antes de qualquer escrita**; arquitetura extensível `DeviceDriver`. |

---

## 3. Especificação Técnica Verificada: Sennheiser Momentum 4 (GAIA v3)

### 3.1 Camada de Transporte & Enquadramento (`SPPGaiaFramer`)

- **Transporte primário (Comprovado):** Bluetooth Classic **RFCOMM / SPP** usando o UUID de serviço exclusivo **`A2129FF3-081B-4C45-8AFE-469D9C4842EC`** (`GAIA3_SPP_UUID`), disponível a partir do firmware **2.11.26**. Não há autenticação nem challenge-response no canal GAIA.
- **Transporte BLE alternativo (Comprovado):** Serviço GATT `63331337-23C1-11E5-B696-FEFF819CDC9F` (Write `...3B`, Notify `...3C`, Data `...3D`), não preferido para o M4 em operação contínua (payload limitado a `ATT MTU - 7`), útil apenas se RFCOMM apresentar bloqueio no macOS.
- **Enquadramento RFCOMM (`version = 0x03`, big-endian):**

```
┌──────┬─────────┬───────┬────────┬───────────┬────────────┬─────────────┬───────────┐
│ 0xFF │ 0x03    │ Flags │ Length │ Vendor ID │ Command ID │ Payload     │ [Chk opt] │
│ 1 B  │ 1 B     │ 1 B   │ 1 B    │ 2 B (BE)  │ 2 B (BE)   │ Length B    │ 0 ou 1 B  │
└──────┴─────────┴───────┴────────┴───────────┴────────────┴─────────────┴───────────┘
```

- **Vendor IDs:** `0x0495` (Sennheiser vendor features — todo o controle de usuário) e `0x001D` (Qualcomm core/DFU — evitar quase tudo, exceto `0x0003` serial se necessário).
- **Decodificação do `Command ID` (16 bits):**
  - `feature = (command_id >> 9) & 0x7F`
  - **Bits de tipo (`(command_id >> 7) & 0x03`):**
    - `0` (`cmd | 0x0000`): Requisição Host → Fone
    - `1` (`cmd | 0x0080`): **Notificação não solicitada** Fone → Host (push)
    - `2` (`cmd | 0x0100`): **Resposta de sucesso**
    - `3` (`cmd | 0x0180`): **Erro** (`payload[0]`: `0x05` = argumento/tamanho inválido, `0x83` = índice fora da faixa)
- **Handshake de sessão recomendado (Read-first):**
  1. Resolver canal RFCOMM exclusivamente via **SDP query** para o UUID `A2129FF3-081B-4C45-8AFE-469D9C4842EC` (nunca enviar pacote cego para canal arbitrário antes de validar SDP!).
  2. Ler `Versions_ModelId` (`0x1206` → ex.: `"M4AEBT"`, `"M4AEBT Denim"`, `"M4AEBT Graphite"`).
  3. Ler `Service_SystemReleaseVersion` (`0x1201` → `UINT16 major, minor, patch`, ex. `3.38.3`) para selecionar o gate de capacidades (Gen1 vs Gen2).
  4. Registrar notificações (`0x0007`, payload `[feature_id]`) para features `2` (Device), `3` (Battery), `4` (GenericAudio), `8` (UserEQ, se Gen2), `11` (MMI), `13` (ANC). Ao registrar, o M4 imediatamente faz **push do estado atual** de todas as propriedades da feature (confirmado em hw `3.38.3`).

### 3.2 Mapa de Comandos Confirmados (`Vendor 0x0495`)

| Domínio | Comando Get → Rsp | Set | Ntf | Payload / Semântica | Gate FW / Notas |
|---|---|---|---|---|---|
| **Identidade / FW** | `0x1201` → `0x1301` / `0x1206` → `0x1306` | — | — | `major, minor, patch` (`u16×3`) / String modelo | Obrigatório no connect |
| **Bateria / Carga** | `0x0603` → `0x0703` / `0x0602` → `0x0702` | — | `0x0683` / `0x0682` | `%` (`0–100`, `255`=desc) / `0`=descon., `1`=carregando, `2`=cheio | `0x0603` responde mesmo no USB! Poll fallback 60s |
| **Auto Power-Off** | `0x0601 [00]` → `0x0701` | `0x0600 [00, u16]` | — | Segundos (`0`=nunca, `900`, `1800`, `3600`) | **Exige byte índice `0x00`** (vazio dá erro `0x05`) |
| **ANC Master** | `0x1A05` → `0x1B05` | `0x1A04` | `0x1A85` | `0`=Off, `1`=On | Exposto como Off no Smart Control Plus (fw ≥ 2.13.32) |
| **ANC Modos** | `0x1A01` → `0x1B01` | `0x1A00` | `0x1A81` | Pares `(id, val)`: `1`=Anti-wind (`0` off, `1` max, `2` auto); `3`=Adaptive (`0` custom, `1` adaptive) | Escrever na ordem correta antes/depois de `0x1A04` |
| **Transparência** | `0x1A03` → `0x1B03` | `0x1A02` | `0x1A83` | `UINT8` `0..100` (`0`=Max ANC, `50`=Balanced, `100`=Max Transp.) | Ignorado enquanto `Adaptive == 1` ou `ANC_Status == 0` |
| **Codec / Sample Rate** | `0x0800` → `0x0900` | — | `0x0880` / `0x089A` | `0` SBC, `1` AAC, `2` aptX, `5` aptX-HD, `8` aptX Adaptive, `9` aptX Lossless, `10` LC3 / `0x089A` = `u32` Hz (`44100`/`48000`/`16000`) | **Vital:** prova objetiva se o Mac caiu para SBC ou HFP 16 kHz! |
| **Audio Mode** | `0x0804` → `0x0904` | `0x0803` | `0x0884` | `UINT16`: `0`=Off/Neutral, `1`=UserEQ, `2`=Podcast/Speech, `3`=PersonalizedSound | **Crítico:** EQ Gen2 não altera o som se `AudioMode != 1`! |
| **EQ Gen2 (≥ 3.18.0)** | `0x1000` (cfg), `0x1002 [band]` | `0x1001 [band, i8]` | `0x1082` | 5 bandas (`63, 250, 1k, 4k, 8k` — HW interno usa `90, 325, 1500, 6500, 6500 Hz`), ganho em `dB × 10` (`-60..+60`) | Presets vivem no app; `0x1002` muda de significado vs Gen1! |
| **Bass Boost** | `0x1009` → `0x1109` | `0x1008` | `0x1089` | `0`/`1` | Rejeitado em fw 2.x; funciona em 3.x |
| **EQ Gen1 (2.12..3.17)** | `0x1003` / `0x1007` | `0x1002` / `0x1006` | — | Master gain + 4 filtros high-shelf (`120, 400, 3000, 6000 Hz`, `Q=1/√2`) + `LevelShift` | **Apenas se fw < 3.18.0** (ver algoritmo completo em `sennheiser-control`) |
| **Sound Personaliz.** | `0x2001/03/05/07` | `0x2000/02/04/06` | `0x2081` | Estado `0..4`, Threshold/Ratio (`f32×6`), Ganhos X/Y | Read-only no v1 (alertar se ativo junto com EQ do Mac!) |
| **Touch Lock** | `0x1607` → `0x1707` | `0x1606` | `0x1687` | **Invertido:** `0`=Toque ativo, `1`=Toque bloqueado | Persistido após reboot em fw ≥ 2.13.32 |
| **Comportamento** | `0x0401` (on-head), `0x080D` (smart pause), `0x080B` (auto-call), `0x0815` (comfort), `0x0806` (sidetone `0..4`) | `0x0400`, `0x080C`, `0x080A`, `0x0814`, `0x0805` | `0x0482` (on-head state) | Bools `0`/`1`; Sidetone `0..4` (`5` dá erro `0x05`) | Só efetivos conforme gate de firmware |
| **Hi-Res / BT Compat.** | `0x0406` → `0x0506` | `0x0405` | — | `0`=BetterAudio (Hi-Res), `1`=BetterCompatibility | Requer confirmação; no Mac sem aptX Adaptive, benefício BT é nulo |
| **Multipoint (Leitura)** | `0x1400` (count), `0x1401 [idx]`, `0x1407` (own idx) | `0x1402/0x1403` (connect/disc) | `0x1484` | Lista dispositivos pareados e quem está conectado | Útil para saber se iPhone + Mac estão conectados simultaneamente |

### 3.3 Lista Negra Absoluta e Regras de Segurança no Hardware

Por segurança do fone do usuário (P3, ADR-0011), os seguintes comandos são **terminantemente proibidos (denylist hardcoded no framer antes do envio)**:

- **`0x0607` (e varreduras em `0x0605–0x06FF`):** Derruba o enlace Bluetooth com *Connection reset by peer* e força *power cycle* físico do fone (**Comprovado** em `omarchy-momentum4`).
- **`0x0040` (`Service_FactoryReset`):** Apaga configurações e pareamento.
- **`0x1405` / `0x1406` (`PairedDevicesDeleteEntry` / `DeleteList`) e `0x1403` sem ação explícita:** Risco de apagar o pareamento do celular/Mac.
- **`0x02xx` / `0x001D:0x0Cxx` (Upgrade / DFU / OTA):** Nunca implementar atualização de firmware.
- **Regra anti-duplo-EQ (Guardião G-04):** Como o M4 já possui EQ interno (`AudioMode = 1` ou `PersonalizedSound = 3`) E Bass Boost (`0x1009`), quando o driver ler que o EQ interno do fone **não está em Neutral (`AudioMode != 0`) ou Bass Boost = 1**, o **Guardião G-04** exibe alerta claro no Observatório com botão de 1 clique *"Colocar EQ interno do Momentum 4 em Neutro para usar a correção de precisão do timbr"* — evitando o erro clássico de somar EQ de 5 bandas do fone + AutoEq de 10 bandas do Mac!

### 3.4 Modos de Conexão do Momentum 4 no macOS (USB-C vs. Bluetooth vs. 3.5 mm)

| Modo | Comportamento no macOS | Áudio / DSP interno do M4 | O que o `timbr` faz |
|---|---|---|---|
| **Bluetooth A2DP** | Stream AAC-LC (macOS não negocia aptX); RFCOMM paralelo para GAIA v3. | DSP/ANC internos ativos; risco de queda para **HFP 16 kHz** se microfone do M4 for aberto. | Guardião G-01 força entrada = mic interno do Mac; Driver lê codec real (`0x0800`), bateria, ANC e estado EQ; DSP do `timbr` aplica AutoEq Float64 no Mac. |
| **USB-C (`Momentum 4 USB`)** | Dispositivo Core Audio **UAC 1.0** (teto **16-bit / 48 kHz** ou 44.1 kHz, **Comprovado**); controle de volume no earcup manda comando HID/OS; bug conhecido em macOS 26.4 deixa slider de sistema cinza em alguns USB DACs. | DSP interno continua ativo + carrega bateria. RFCOMM pode ou não estar simultâneo dependendo de modo voo. | **Sonda HAL** verifica se `kAudioDevicePropertyVolumeScalar` é gravável; se não for (ou bug USB), o motor assume **controle de volume digital em Float64** sinalizado no Observatório; alerta sobre teto 48 kHz/16-bit. |
| **3.5 mm P2 Ligado (Active)** | Conectado via DAC/saída do Mac (ou dongle externo); BT desligado (Flight Mode). | **Impedância 470 Ω**, áudio é re-digitalizado pelo DSP interno (ANC e preset salvo continuam ativos). | Seleciona perfil de correção **Momentum 4 (Active/BT)**; alerta se usuário tiver perfil salvo no fone antes de plugar. |
| **3.5 mm P2 Desligado (Passive)** | Cabo analógico direto com fone desligado. | **Impedância 60 Ω**, DSP interno desligado (resposta acústica diferente do modo ativo!). | Exige **perfil AutoEq separado** ("Momentum 4 · Passive 3.5mm" vs "Momentum 4 · Active/BT") indexado pela chave composta `deviceUID + modo`. |

---

## 4. Realidade dos AirPods Pro no macOS e Outras Marcas

1. **AirPods Pro (1/2/3 / Max):**
   - **Proibido/Inviável em macOS sem desativar SIP:** Abertura de canal L2CAP `0x1001` (`IOBluetoothL2CAPChannel`) para enviar comandos **AACP** (trocar ANC/Transparency, head gestures, conversational awareness) é interceptada/negada pelo `bluetoothd` do macOS para apps de terceiros (**Comprovado**). Não investir tempo tentando burlar isso.
   - **Viável via Core Audio + APIs públicas:**
     - Seleção de dispositivo, volume, mute, proteção implacável contra queda **SCO/HFP** via política *Output Only* (**Comprovado**).
     - Alerta sobre modos do sistema que interferem na resposta em frequência (ex.: Áudio Espacial / Head Tracking ativo altera a resposta medida e invalida parcialmente AutoEq — sinalizar no Observatório).
     - **A investigar no E-07/E-08 (Hipótese):** leitura passiva de anúncios **BLE Continuity (`0x004C`)** via `CoreBluetooth` para estimar bateria L/R/Case na barra sem abrir canal privado.
2. **Extensibilidade Multi-Marca (`DeviceDriver`):**
   - O contrato `DeviceDriver` (ADR-0011) é agnóstico ao transporte (`RFCOMM`, `BLE`, `USB-HID`). Candidatos futuros de licença limpa:
     - **Tier 2 (MIT/Apache bem documentados):** Sony WH/WF-1000XM (`SonyHeadphonesClient` MIT), Google Pixel Buds (`pbpctrl` MIT/Apache-2.0), Nothing/CMF (`nothing-ear-controller` MIT), Edifier (`mEDIFIER` MIT).
     - **Proibição de segurança (Airoha RACE):** Dispositivos Airoha (JBL Tune 770NC, Marshall, alguns Bose/Jabra) exigem **allow-list estrita** devido a falhas de memória/flash (CVE-2025-20700/1/2) — nunca enviar probes genéricos sem identificação SDP exata.

---

## 5. Implicações Diretas para o Planejamento do `timbr`

1. **Separar formalmente perfis do Momentum 4 por modo físico:** BT/USB/3.5mm-Ativo (470 Ω, DSP interno ativo) vs. 3.5mm-Passivo (60 Ω, sem DSP).
2. **E-09 torna-se um protocolo enxuto, read-first e seguro em Swift (`IOBluetooth`):** validar primeiro se o macOS abre `A2129FF3-081B-4C45-8AFE-469D9C4842EC` enquanto toca A2DP sem causar `A2DP Audio Queue full` ou desconexão, usando a blocklist rígida da seção 3.3 e os vetores de teste de `android-momentum-4-widget`.
3. **Observatório ganha telemetria exclusiva no M4:** exibir codec reportado (`0x0800`), taxa (`0x089A`), estado do EQ interno (`AudioMode` + `BassBoost` → gatilho real do Guardião G-04) e bateria confiável mesmo no cabo USB.
