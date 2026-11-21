# Observatório da Cadeia de Sinal e Guardião de Qualidade

> **Princípios vinculados:** **P4 (Verdade no caminho do sinal)**, **P1 (Fidelidade antes de recursos)**, **P11 (Consciente do hardware)**.
> **Design System:** selos `MEDIDO` (`semantic.ok`), `REPORTADO` (`semantic.info`), `INFERIDO` (`semantic.warn`) conforme [04 · Componentes e Visualização de Áudio](../05-design-system/04-componentes-e-visualizacao-audio.md).

---

## 1. Regra Cardinal de Honestidade Epistêmica (P4)

Nenhuma métrica inferida ou heurística pode ser apresentada com a mesma linguagem visual de uma grandeza medida em buffer ou reportada diretamente por API do Core Audio. Todo nó do Observatório carrega obrigatoriamente um `SourceOriginBadge` com uma das três origens:

| Selo na UI | Origem | Definição técnica | Exemplo no Timbre |
|---|---|---|---|
| **MEDIDO** | Amostras ou contadores reais dentro do processo/DSP do Timbre | Calculado diretamente sobre o fluxo Float64 ou contadores atômicos de callback | True Peak (`dBTP`), Pico de amostra (`dBFS`), RMS, LUFS M/S (EBU R128), contagem de clipes, atuação do limiter, espectro FFT, silêncio/zero-buffer (`0.0f`), latência medida entre tap e saída via loopback de teste |
| **REPORTADO** | Propriedade explícita lida de API pública do sistema ou firmware lido via driver | Lido de HAL (`AudioObjectGetPropertyData`), `AVAudioSession`/`AVCaptureDevice`, `MediaRemote` (quando disponível) ou driver de dispositivo | Nome do device, transporte (`USB`/`BT`/`HDMI`/`BuiltIn`), `NominalSampleRate`, `BufferFrameSize`, `SafetyOffset`, `StreamPhysicalFormat`, `Latency` declarada no HAL, `IsRunningInput`, bateria e estado ANC/EQ reportados pelo driver M4 |
| **INFERIDO** | Correlação indireta, tabela de sensibilidade ou cálculo derivado não garantido pelo SO | Quando o macOS ou Bluetooth não expõem API pública confiável | Bit-depth efetivo antes da mixagem do app, codec BT ativo (quando obtido apenas via `log stream` ou `system_profiler` fora do canal de áudio), estimativa de SPL (`dB SPL` por sensibilidade informada pelo usuário), "EQ duplicado" inferido por comparação |

---

## 2. Anatomia do Grafo Horizontal no Observatório

Cada destino ativo renderiza um grafo horizontal contínuo (coluna 7/12 no layout 7/5):

```
[1. Fontes] ─▶ [2. Mixer] ─▶ [3. Correção] ─▶ [4. Gosto] ─▶ [5. Proteção] ─▶ [6. Dispositivo HAL] ─▶ [7. Fone / Transdutor]
```

| Estágio | Dados exibidos | Selos típicos | Clique no nó abre |
|---|---|---|---|
| **1. Fontes** | Lista de apps/abas capturados; ganho (`dB` / `%`); nível RMS/pico por fonte | `MEDIDO` (nível pós-tap), `REPORTADO` (PID, `bundleID`, estado de entrada/saída HAL) | Controles do app, estado do tap, atraso de arranque |
| **2. Mixer** | Soma de *N* fontes; taxa de processamento do motor; headroom de soma | `MEDIDO` (pico pré-EQ, soma ativa) | Diagnóstico de `AggregateDevice` e clock master |
| **3. Correção** | Origem do perfil (AutoEq/REW/nenhum), nº de bandas ativas, preamp de correção | `REPORTADO` (configuração ativa) + `MEDIDO` (pico pós-correção) | Curva tracejada, crédito da medição, comparação com alvo |
| **4. Gosto** | Delta de graves/médios-agudos/presença ou bandas PEQ de gosto; A/B ativo | `REPORTADO` (estado) + `MEDIDO` (ganho máximo somado) | Curva roxa (`accent.base`), histórico de revisões |
| **5. Proteção** | Preamp final calculado, Limiter True-Peak (`dBTP`), contadores de redução de ganho e clipes | `MEDIDO` (`dBTP`, `GR dB`, clipes = `0`) | Histórico de picos, modo Bypass verdadeiro |
| **6. Dispositivo HAL** | Nome, transporte, `NominalSampleRate`, `BufferFrameSize`, volume HW vs SW, estado do selo `BIT-PERFECT` | `REPORTADO` (HAL) + `INFERIDO` (se formato da fonte original não for acessível) | Matriz de capacidades HAL sondadas (E-07), seletor de taxa |
| **7. Fone / Transdutor** | Modelo associado (`DeviceUID`), codec (se disponível), bateria, ANC, EQ interno, SPL estimado | `REPORTADO` (driver M4 / `SPBluetoothDataType`) ou `INFERIDO` (codec/SPL) | Painel do driver (ADR-0011), aviso WHO/ITU H.870 |

### 2.1 Regra estrita do selo `BIT-PERFECT` (RF-0708 / Glossário)

O selo **`BIT-PERFECT`** só pode acender quando **todas** as condições abaixo forem verificadas simultaneamente:
1. Nenhum `ProcessTap` do Timbre está interceptando a fonte (ou caminho de bypass físico sem reamostragem/ganho ativo — na arquitetura P1, sem tap existe transparência real).
2. Ganho de app = `1,0` (0 dB), Correção = desligada, Gosto = desligado, Crossfeed/Convolução = desligados, volume em software = desativado (`1,0` ou hardware exclusivo).
3. Taxa nominal do dispositivo (`kAudioDevicePropertyNominalSampleRate`) coincide com a taxa conhecida da fonte (quando reportada por player com suporte, ex.: Apple Music via log/integrador ou player hi-res); caso a taxa da fonte seja **desconhecida**, o selo máximo permitido é **`SEM PROCESSAMENTO TIMBRE`** (nunca afirmar `BIT-PERFECT` sem saber a taxa da fonte).

---

## 3. O que é Observável vs. Inacessível no macOS 26/27 (Estado de Evidência)

| Sinal | Viabilidade no macOS 26/27 | Classe de Evidência | Método |
|---|---|---|---|
| Nível de amostra, RMS, True Peak, LUFS, clipes, atuação do limiter | Direto no ring buffer DSP | **Comprovado** | Cálculo próprio no callback/worker |
| Lista de processos com áudio ativo ou capturando mic | `kAudioHardwarePropertyProcessObjectList` + `IsRunningInput/Output` | **Comprovado** | Header `AudioHardware.h` (SDK 27.0) |
| Taxa nominal, formato físico de stream, latência, buffer size, setabilidade de volume/mute | `AudioObjectGetPropertyData` / `IsPropertySettable` | **Comprovado** | HAL Core Audio (confirmado por E-07) |
| Detecção de queda A2DP → HFP/SCO | Queda de taxa nominal (ex.: 48 → 8/16/24 kHz) ou stream de entrada BT ativo + `DefaultInputDevice == BT` | **Comprovado** (lógica HAL; validar em E-08) | Listeners HAL |
| Codec Bluetooth ativo (AAC vs aptX vs SBC) | Não há API pública em `IOBluetooth`/`CoreAudio`; `SPBluetoothDataType` ou `log stream` variam por versão | **Desconhecido / Provável** | Validar em E-08; se obtido por log, marcar `INFERIDO` |
| Taxa de amostragem original do arquivo em apps fechados (ex.: Apple Music, Spotify) | Spotify não expõe; Apple Music exige leitura indireta/log (`LosslessSwitcher` pattern) | **Provável** | Quando indisponível, mostrar `Desconhecido` |
| Bateria, ANC e EQ interno do Momentum 4 | Protocolo próprio RFCOMM/BLE (E-09) | **Desconhecido** (até E-09) | Driver isolado `DeviceDriver` |

---

## 4. Regras do Guardião de Qualidade (G-01 a G-07)

O Guardião opera como um motor de regras determinístico baseado em eventos de estado do motor, do HAL e dos `DeviceDrivers`.

### 4.1 Política de UX e anti-fadiga
- **Máximo 1 alerta ativo visível por vez** (prioridade: Crítico > Qualidade > Informativo).
- **Histerese e agrupamento:** oscilações rápidas (< 3 s) são suprimidas antes de virar alerta; eventos repetidos no mesmo dispositivo são agrupados na linha do tempo.
- **"Não mostrar de novo para este caso":** persistido por par `(Regra, DeviceUID)` no SQLite local, sempre reversível nas configurações.
- **Todo evento entra na Linha do Tempo do Observatório** (exportável em JSON/Markdown para diagnóstico de bugs, sem áudio bruto).

### 4.2 Catálogo de regras

| ID | Condição de disparo | Severidade | Mensagem objetiva | Ação direta (1 clique) |
|---|---|---|---|---|
| **G-01** | Fone Bluetooth com A2DP torna-se `DefaultInputDevice` ou stream de entrada BT abre (`IsRunningInput`) e `NominalSampleRate` cai para ≤ 24 kHz | Crítica (`error`) | *"Seu [Fone] mudou para perfil de chamada (HFP). A qualidade caiu para voz mono."* | **Voltar entrada ao mic interno** (com opção "Sempre preferir mic interno") |
| **G-02** | Taxa conhecida da fonte ≠ `NominalSampleRate` do DAC/saída atual (e DAC aceita a taxa da fonte) | Atenção (`warn`) | *"A fonte está em [X] kHz, mas a saída está em [Y] kHz (reamostragem ativa)."* | **Ajustar saída para [X] kHz** (se gravável) |
| **G-03** | Limiter atuou `≥ 3` vezes em `10 s` ou reduziu `> 2,0 dB`, ou pico pré-limiter `> 0 dBFS` após ganho de app `> 100%` | Atenção (`warn`) | *"Picos acima de 0 dBTP detectados. O limiter está protegendo sua saída."* | **Reduzir preamp em [Δ] dB** / **Normalizar ganho da fonte** |
| **G-04** | Driver do fone reporta EQ interno ativo (não-plano) enquanto Correção ou Gosto do Timbre também estão ativos | Atenção (`warn`) | *"EQ interno do [Fone] está ativo junto com o Timbre (risco de dupla equalização)."* | **Zerar EQ do fone** (se escrita aprovada) ou **Desativar EQ do Timbre** |
| **G-05** | Volume em software do Timbre `< 100%` em saída USB/DAC que reporta controle de volume em hardware gravável | Informativa (`info`) | *"O DAC aceita controle de volume em hardware; o volume em software reduz o caminho direto."* | **Migrar para volume de hardware** |
| **G-06** | `DefaultOutputDevice` mudou sem comando do usuário dentro do Timbre (ex.: desconexão BT ou troca automática) | Informativa (`info`) | *"Saída mudou para [Novo Device] porque [Anterior] desconectou."* | **Focar perfil atual** / **Voltar ao anterior quando reconectar** |
| **G-07** | Detecção de outro processo com tap ativo concorrente (`Loopback`, `SoundSource`, `FineTune`, `eqMac`) ou erro de `AudioDeviceStart` entre taps | Crítica (`error`) | *"Conflito de captura detectado com [App]. O macOS pode bloquear novos streams de áudio."* | **Pausar captura do Timbre para este app** / **Abrir matriz de coexistência** |

---

## 5. Medidores, Espectro e Privacidade

- **True Peak (4× oversampling):** implementado conforme ITU-R BS.1770-4 / EBU Tech 3341 V4, com janela de hold configurável (padrão 2 s).
- **Loudness EBU R128:** Momentary (`400 ms`) e Short-term (`3 s`), janela deslizante lock-free fora da thread RT.
- **Espectro FFT ao vivo:** **desligado por padrão** no notch se não estiver em exibição; quando ligado, opera apenas sobre o buffer já capturado pelo tap ativo (ou seja, nunca cria novo tap nem acende luz laranja de microfone).
- **Estimativa de exposição sonora (RF-0707):** recurso opt-in **apenas se** o usuário informar modelo com sensibilidade (`dB/mW` ou `dB/V`) e impedância conhecidas e usar volume calibrado; marcado obrigatoriamente como **`INFERIDO`** com aviso explícito de que não substitui dosímetro nem medição SPL real.
