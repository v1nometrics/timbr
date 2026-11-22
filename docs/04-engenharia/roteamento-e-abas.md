# Arquitetura de Roteamento, Múltiplas Saídas e Controle por Aba

> **Princípios vinculados:** P1, P2, P8, [ADR-0004](../07-decisoes/ADR-0004-captura-por-process-taps.md).
> **Experimentos bloqueadores:** E-01, E-02, E-04, E-05, E-10.

---

## 0. Estado implementado (2026-11-23)

> Classe: **Comprovado** (código + autoteste E2E + capturas), salvo indicação.

- **Slots de captura** (`ProcessTapEngine.reconcileMultiTap`):
  - um tap `stereoMixdownOfProcesses` por app com volume ≠ 100 % ou mudo, com `.mutedWhenTapped` e ganho próprio;
  - um tap global `stereoGlobalTapButExcludeProcesses` quando há EQ, crossfeed ou ducking. Ele exclui os apps com slot próprio, os de VoIP e o próprio timbr., e só existe enquanto há áudio tocando (desmontado 10 s depois do silêncio);
  - um tap sem mudo por saída espelhada, que exclui os apps no mudo. Limite conhecido: o volume por app não é replicado nos espelhos.
- **Ganho medido:** 50/25/200/150 % = −6,02/−12,04/+6,02/+3,52 dB; mudo em silêncio. Acima de 100 %, o limiter segura −0,3 dBTP, e música já masterizada perto de 0 dBFS quase não fica mais alta. O Mixer mostra "No limite".
- **Atribuição (`AudioProcessAttribution`):** processo responsável (`responsibility_get_pid_responsible_for_pid`, buscado em runtime) → pacote `.app` mais externo do executável → cadeia de pais → bundle ID reportado. Apps de barra de menus (accessory) contam como donos. Resultado: o áudio WebKit do Raycast é "Raycast" (antes era "Safari"), e o helper do Chrome é "Google Chrome".
- **Chrome/Chromium:** todas as abas e PWAs tocam pelo mesmo processo de áudio (`Google Chrome Helper`). O controle por aba depende da extensão (§4). Vídeo mudo no player não gera áudio nenhum para o macOS e não aparece como fonte (verificado com o player do YouTube).
- **Fontes do macOS:** `SystemAudioClient` agrupa daemons sem app, como Sons do sistema (systemsoundserverd, PowerChime, NotificationCenter…), Siri e Ditado, Chamadas (protegidas como VoIP) e Leitura em voz alta.
- **Não implementado:** rotear um app para outra saída (RF-0201; `targetDestinationUIDs` não é usado pelo motor), extensões ligadas ao Mixer na UI de abas, e o ducking por cena além do ducking em chamada.

---

## 1. Topologia do Motor: Um Aggregate por Saída Física

Em vez de criar um aggregate por par `(app, dispositivo)` (modelo Atoll, que multiplica domínios de relógio e soma múltiplas streams antes do limiter), o Timbre adota a topologia **um motor por dispositivo de saída físico ativo**:

```
App A (ganho + EQ fonte) ─┐
                          ├─▶ [Soma Float64] ─▶ Correção ─▶ Gosto ─▶ Preamp ─▶ Limiter ─▶ Saída Física 1
App B (ganho + EQ fonte) ─┘     (Aggregate Privado 1 · Clock = Saída Física 1)

App A (mesma fonte, roteada também para Saída 2)
  └─▶ Tap paralelo (ou fan-out em memória, ver E-04) ─▶ [Motor Saída Física 2]
```

### Vantagens desta topologia
1. **Limiter e preamp corretos no destino:** duas fontes tocando juntas não estouram o teto porque passam pelo mesmo limiter pós-soma (`per-app-audio` identificou o risco oposto).
2. **Domínios de relógio isolados:** cada dispositivo físico é o *Clock Source* do próprio aggregate. Se a fonte estiver na mesma taxa do dispositivo, evita-se SRC desnecessário.
3. **Regra Bluetooth explícita:** dispositivos Bluetooth rodam sempre em motor próprio **sem `Drift Correction`** ativado no sub-device (em linha com a mudança do SoundSource 6.1.0 e orientação da Apple para evitar instabilidade/latência exagerada em BT).

### Múltiplas saídas simultâneas (mesma fonte → N destinos)
- Cada destino recebe o sinal com seu próprio **EQ de Correção** (ex.: Momentum 4 corrigido para Harman + caixas de mesa corrigidas para resposta de sala).
- **Compensação de atraso:** cada motor aceita um buffer circular de delay (`0` a `500 ms`, passo `0,5 ms`) para alinhar manualmente saída cabeada (~10 ms) com saída Bluetooth (~150–300 ms) ou AirPlay.
- **Nota de latência:** o bug do macOS 27.0.1/27.2 que falha com `'stop'` ao juntar dois endpoints de vídeo (HDMI+DP) num único Multi-Output do sistema é contornado por esta arquitetura porque cada monitor tem seu próprio motor independente (validar em **E-04**).

---

## 2. Agrupamento de Processos e Helpers

Apps modernos tocam áudio por subprocessos que não correspondem ao ícone no Dock:
- **Chromium (Chrome, Arc, Brave, Edge):** `Google Chrome Helper` / utility `Audio Service`.
- **WebKit / Safari:** processo compartilhado `com.apple.WebKit.GPU` (com `parentApplicationBundleIdentifier` no macOS 27).
- **Electron (Slack, Discord, Spotify, VS Code):** helpers filhos.

**Estratégia:**
1. Resolver a árvore de processos (`sysctl` / `proc_pidinfo` / `NSRunningApplication`) para agrupar processos filhos sob o aplicativo pai na UI do mixer.
2. Usar `CATapDescription.bundleIDs` + `isProcessRestoreEnabled` no macOS 26+ quando disponível; no macOS 15, rastrear novos PIDs via `kAudioHardwarePropertyProcessObjectList` e associar ao bundle pai.
3. **Exclusão Segura Padrão (Ignore List VoIP/DAW):** apps de chamada bidirecional com AEC/AGC próprio (`Zoom`, `Google Meet`, `Microsoft Teams`, `FaceTime`, `WeChat`, `Discord` voice) e DAWs com exclusividade de hardware vêm **excluídos de tap por padrão** (opt-in explícito por app na UI) para evitar esmagamento de ganho, eco ou travamentos de `AudioDeviceStart` (descoberta `FineTune#477/#493`, E-10).

---

## 3. Ducking e Cenas sem Quebrar Chamadas

- **Regra crítica (E-04):** nunca colocar um process tap sobre Zoom, Meet, Teams ou FaceTime apenas para saber se estão em chamada ou para fazer ducking — isso adiciona latência e pode quebrar cancelamento de eco.
- **Detecção passiva:** observar `kAudioProcessPropertyIsRunningInput` / `IsRunningOutput` no HAL. Quando um app de reunião inicia entrada/saída, o Timbre aplica uma rampa de atenuação (ex.: `−12 dB` em `250 ms`) apenas nos motores/taps de players musicais.

---

## 4. Controle por Aba de Navegador (Extensões)

Como os taps do sistema não enxergam abas individuais dentro do `Audio Service` (Chromium) nem do `WebKit.GPU` (Safari), o controle por aba é entregue por **extensões dedicadas** comunicando com o Timbre:

| Navegador | Mecanismo da extensão | O que é garantido | Limites / O que E-05 decide |
|---|---|---|---|
| **Safari** | Safari Web Extension (incluída no bundle `.app`) interceptando `HTMLMediaElement.volume` + Web Audio gain hook | Atenuação (`0–100%`), mute, título/URL da aba no notch | Não roteia aba para outra saída nativa facilmente; Safari precisa ativar extensão |
| **Chrome / Arc / Brave / Edge** | Manifest V3 (`chrome.tabCapture` + Offscreen Document + Web `AudioContext`) ou content script | Atenuação, mute, identificação da aba; potencial boost/EQ no `AudioContext` | `tabCapture` exige clique/gesto do usuário na extensão; `setSinkId` para rotear aba a outra saída está em aberto (E-05) |
| **Firefox** | WebExtension + Native Messaging | Atenuação/mute via elementos de mídia | Sem API equivalente a `tabCapture` (sem boost/captura universal de Web Audio) |

**Canal de comunicação local:**
- Preferir **Native Messaging** (stdin/stdout via manifesto registrado no navegador) ou WebSocket em `127.0.0.1` com token efêmero de sessão gerado a cada arranque e verificação estrita de origem da extensão.
- Na UI do mixer, quando uma extensão está conectada, a linha do navegador expande sub-linhas recuadas para cada aba com áudio ativo (`tabId`, favicon/título). Sem extensão, o navegador aparece honestamente como uma única linha de aplicativo.
