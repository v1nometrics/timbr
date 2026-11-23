# Arquitetura Geral do Sistema

> **ADRs vinculados:** [ADR-0002](../07-decisoes/ADR-0002-plataforma-nativa.md), [ADR-0003](../07-decisoes/ADR-0003-nucleo-dsp.md), [ADR-0004](../07-decisoes/ADR-0004-captura-por-process-taps.md), [ADR-0006](../07-decisoes/ADR-0006-processo-do-motor.md), [ADR-0011](../07-decisoes/ADR-0011-drivers-de-dispositivo.md), [ADR-0013](../07-decisoes/ADR-0013-superficies.md).

---

## 0. Estado implementado (2026-11-23)

> O resto deste documento descreve a **arquitetura alvo**. Esta seção diz o que o código faz hoje. Classe de evidência: **Comprovado** (código executado, CI e autoteste E2E).

```
Timbr.app (Swift 6 + SwiftUI/AppKit · alvo Mach-O macOS 15.0)
├─ TimbreApp      AppState (estado e orquestração) · NotchOverlay (NSPanel + sensor + NotchSpaceOverlay + FullscreenEvaluator)
│                 MenuBarIconController (NSStatusItem condicional) · StudioWindow · OnboardingWindow · DSComponents (audiocn + InfoHintButton)
├─ TimbreEngine   HALManager (dispositivos, snapshot P3) · ProcessTapEngine (taps + agregados + TapRenderer) · MuteKeeperClient
│                 AudioProcessMonitor (eventos do Core Audio) · AudioProcessAttribution · AudioSelfTest · MutePersistenceSelfTest
│                 DisplayBrightness · MediaKeyTap · drivers M4 e linha Apple
├─ TimbreCore     modelos, presets/APO, i18n PT/ES/EN, Guardião, SQLite + FTS5 trigram (ADR-0018), ListeningTime (ADR-0023),
│                 FeedbackComposer (ADR-0024), PersistentMutePolicy / MuteKeeperProtocol (ADR-0017), AutoEq, IA local, IPC
├─ CTimbreDSP     C++20 Float64 + vDSP via C ABI (EQ, preamp, limiter true-peak, LUFS, FFT, crossfeed, atraso)
└─ TimbrMuteKeeper  binário auxiliar isolado em `Contents/Helpers/timbr-mute-keeper` (ADR-0017, mantém mudo ativo se o app encerrar)
```

| Tema | Alvo (abaixo) | Implementado |
|---|---|---|
| Processo do motor | Helper XPC separado (ADR-0006) | **Mesmo processo da UI.** ADR-0006 continua Proposto (E-16 não executado) |
| Topologia | Um motor por saída física, com soma e limiter pós-soma | Um agregado privado por *slot*: por app, global e por espelho (ADR-0004, lições) |
| Parâmetros para a thread de áudio | Fila SPSC ou ponteiro atômico com rampa | **Buffer triplo wait-free** (`timbre_dsp_update`); ganho e A/B por atômico com de-zipper de 10/20 ms |
| Detecção de fontes | Listeners do HAL | `AudioProcessMonitor` (lista de processos, `IsRunning`, `IsRunningOutput`, coalescência de 120 ms) + varredura de reserva a cada 2 s |
| Atribuição | Árvore de processos | Processo responsável → pacote `.app` do executável → cadeia de pais → bundle ID do Core Audio; serviços do macOS agrupados |
| Snapshot e fail-safe (P3) | Snapshot + restauração | Implementado; 20× `kill -9` sem agregado órfão no CI |
| Mudo à prova de falha (ADR-0017) | — | `timbr-mute-keeper` (`Contents/Helpers/`), processo auxiliar independente que mantém apps mudos mesmo após crash/`kill -9`; validado por `selftest_mute_persistence.sh` e `listen_mute_crash.sh` |
| Resiliência & alvo macOS 15 | Recuperação de `coreaudiod` e sleep/wake | Binários fixados em `macosx15.0` (verificado por `check_deployment_target.py`); recuperação completa pós-reset do `coreaudiod` e sleep/wake seguem abertas em [`auditoria-resiliencia-2026-11-23.md`](../08-registro/auditoria-resiliencia-2026-11-23.md) |
| Verificação | Bancada | `ci_check.sh` (headless + `TimbreTokensTests` + `check_deployment_target.py` + 20× `kill -9`) + `selftest_audio.sh` + `selftest_mute_persistence.sh` |

---

## 1. Visão Macro em Camadas e Processos

```
┌─────────────────────────────────────────────────────────────────────────┐
│ Processo Principal (UI · Swift 6 + SwiftUI/AppKit)                      │
│  ├─ Superfícies: Notch (NSPanel) · Pílula · MenuBar · Estúdio · Observ. │
│  ├─ Camada de Inteligência: Foundation Models / Ollama / PairwiseGP     │
│  ├─ Ecossistema: Presets JSON/APO · AutoEq Cache · Lyrics · ShazamKit   │
│  └─ Media Bridge: mediaremote-adapter + AppleScript/HTTP + Extensões    │
└───────────────────────────────▲───────────────────────▲─────────────────┘
                                │ XPC (cdhash verif.)   │ XPC / Worker
                                ▼                       ▼
┌───────────────────────────────────────┐  ┌──────────────────────────────┐
│ Audio Engine Helper (XPC / LoginItem) │  │ Device Drivers (Isolados)    │
│  ├─ Sonda HAL & Snapshot/Restore      │  │  ├─ Protocolo DeviceDriver   │
│  ├─ Tap Manager (1 motor/saída física)│  │  ├─ Momentum 4 Driver (E-09) │
│  ├─ Thread RT C ABI (sem malloc/lock) │  │  └─ Futuro: Sony/Bose/etc.  │
│  │   └─ Núcleo DSP Float64 + Limiter  │  └─ Nunca bloqueia Audio Engine │
│  ├─ Ring Buffers (Meters/FFT/Shazam)  │
│  └─ Watchdog & ServiceRestarted       │
└───────────────────────────────────────┘
```

### Por que separar UI, Motor de Áudio e Drivers (ADR-0006 / ADR-0011)?
1. **Isolamento de falhas (P2):** um crash de layout SwiftUI, de WebKit/browser bridge ou de parser de letras nunca derruba a thread RT de áudio; inversamente, se o Helper morrer, `.mutedWhenTapped` devolve o áudio ao app original em < 1 s.
2. **Isolamento de drivers Bluetooth:** operações de RFCOMM/GATT em fones de terceiros travam ou sofrem timeout de hardware com frequência. Rodar o `DeviceDriver` fora do processo de áudio impede qualquer impacto na latência do IOProc.
3. **Permissão TCC previsível (E-16):** a fronteira entre UI e Helper deve preservar uma única identidade `NSAudioCaptureUsageDescription` estável, validada no experimento E-16 antes de consolidar o empacotamento final.

---

## 2. Fronteira Real-Time vs. Não-Real-Time

| Domínio | Linguagem / Runtime | Regras estritas |
|---|---|---|
| **Callback RT (`AudioDeviceIOProc`)** | C / C++ ou Rust (`no_alloc`) via C ABI | Zero `malloc`/`free`, zero `os_unfair_lock`/`Mutex`, zero `objc_msgSend`, zero Swift ARC/existentials, zero I/O ou `os_log`. Comunicação via ring buffers SPSC atômicos e troca de parâmetros por ponteiro atômico / fila lock-free com interpolação/rampa de 10 ms. |
| **Controle do Motor (não-RT)** | Swift 6 (`actor` isolado) | Gerencia `AudioObjectAddPropertyListener`, criação/teardown de taps e aggregates, watchdog de buffers `0.0f`, cálculo de coeficientes IIR fora da thread RT, compilação de filtros casados/AutoEq. |
| **UI & Observabilidade** | SwiftUI + `Canvas` + `TimelineView` | Consome apenas snapshots lock-free do ring buffer de medidores/FFT (`60–120 Hz`) e eventos de estado do motor. |

---

## 3. Persistência e Estado Local

| Dado | Armazenamento | Chave primária |
|---|---|---|
| **Presets nativos (Correção & Gosto)** | Arquivos JSON (`timbre.preset/v1`) em `Application Support/Timbre/Presets/` | UUID + hash de conteúdo + versão |
| **Associação Dispositivo ↔ Perfil** | SQLite local (`timbre.sqlite`) | `kAudioDevicePropertyDeviceUID` + transporte (BT / USB / Analógico) |
| **Snapshot de Sistema (P3)** | JSON atômico gravado antes de qualquer alteração do Timbre | Timestamp + estado original (default devices, sample rate, volume HW) |
| **Histórico do Observatório / A/B** | SQLite local com rotação configurável (ex.: 30 dias) | Timestamp monotônico + UID |
| **Cache AutoEq** | Arquivos locais com TTL de 7 dias | Fonte + modelo + equipamento de medição |

---

## 4. Ciclo de Vida, Fail-Safe e Recuperação

1. **Arranque frio:** tira snapshot do estado de áudio atual; sonda capacidades HAL de todos os dispositivos; **não cria nenhum tap** (P1) enquanto todas as fontes e EQ estiverem em neutro.
2. **Ativação sob demanda / precoce:** conforme decisão de **E-02**, ativa taps apenas quando necessário (ou pré-arma por `bundleIDs` se E-02 provar que é a única forma de evitar estouro de 500 ms).
3. **Troca / `ServiceRestarted`:** ao receber `kAudioHardwarePropertyServiceRestarted`, invalida todos os `AudioObjectID` em cache, reconstrói listeners usando `DeviceUID`, e reanexa motores ativos.
4. **Saída limpa ou crash:** `SIGTERM`/`NSApplication.willTerminate` destrói todos os aggregates privados e restaura o snapshot do sistema; em `SIGKILL`, o Core Audio libera os taps automaticamente e o som volta aos apps de origem. No próximo arranque, detecta snapshot órfão de crash e oferece/executa restauração.

---

## 5. Fronteira Local vs. Rede (100% Offline Core)

Todo o plano de dados de áudio (Captura → Mixer → `Float64` DSP → Proteção → Saída), o Observatório, o Guardião, os drivers locais (Momentum 4 via `IOBluetooth`), as cenas e os modelos locais de IA/otimização (`Apple Foundation Models`, `Ollama`, `PairwiseGP`) executam **100% no dispositivo sem qualquer dependência de rede**. A tabela completa de funcionalidades offline vs. opt-in de rede e fallback está formalizada em [requisitos-nao-funcionais.md §2](requisitos-nao-funcionais.md).
