# Arquitetura Geral do Sistema

> **ADRs vinculados:** [ADR-0002](../07-decisoes/ADR-0002-plataforma-nativa.md), [ADR-0003](../07-decisoes/ADR-0003-nucleo-dsp.md), [ADR-0004](../07-decisoes/ADR-0004-captura-por-process-taps.md), [ADR-0006](../07-decisoes/ADR-0006-processo-do-motor.md), [ADR-0011](../07-decisoes/ADR-0011-drivers-de-dispositivo.md), [ADR-0013](../07-decisoes/ADR-0013-superficies.md).

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
