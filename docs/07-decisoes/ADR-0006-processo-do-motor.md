# ADR-0006 · Motor de áudio em processo separado da UI

- **Status:** Proposto · decide em E-16
- **Data:** 2026-11-21

## Contexto

A UI (SwiftUI, animações do notch, gráficos, IA) e o motor de tempo real têm perfis de risco opostos. Um crash ou travamento da UI não deveria interromper o áudio; um vazamento de memória da UI não deveria competir com a thread de áudio.

## Decisão proposta

Três processos:

| Processo | Responsabilidade | Ciclo de vida |
|---|---|---|
| `Timbre.app` (UI) | Notch, Estúdio, Observatório, IA, regras | Pode reiniciar a qualquer momento |
| `TimbreEngine` (helper, `SMAppService` login item) | Taps, aggregates, DSP, watchdog, estado do roteamento | Sempre ativo quando há processamento; morre limpo sem deixar rastro |
| `TimbreDeviceAgent` (opcional, dentro do helper no MVP) | Bluetooth/protocolos de fabricante | Isola falhas de drivers de terceiros |

Comunicação por XPC com mensagens versionadas; o estado de verdade do roteamento vive no motor; a UI é uma projeção.

## Riscos a verificar em E-16

- A qual processo a permissão "System Audio Recording" é atribuída e como o prompt aparece.
- Custo de memória do helper.
- **Atualização da revisão adversarial (`C-01`):** o **MVP (Fase 1) roda in-process** com fronteira estrita no módulo `Engine` (sem dependência de UI) + watchdog, evitando dobrar a complexidade de TCC/Audio Workgroups/XPC antes da validação com usuários; **`E-16`** decide a promoção para processo auxiliar XPC no Beta/1.0.
