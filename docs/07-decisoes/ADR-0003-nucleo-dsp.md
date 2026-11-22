# ADR-0003 · Núcleo DSP

- **Status:** Aceito · 2026-11-21 (decidido por `E-06`: C++20 + Accelerate/vDSP `Float64`)
- **Data:** 2026-11-21

## Contexto

O EQ precisa ser confiável para um audiófilo: processamento e coeficientes em 64 bits, biquads DF2T, filtros casados ou sobreamostragem contra cramping, preamp pela resposta somada, limiter true-peak, FIR opcional, troca de parâmetros sem zipper noise, zero alocação e zero lock na thread de áudio. As referências Mac são insuficientes: o FineTune processa em Float32 (`vDSP_biquad`) e o eqMac usa `AVAudioUnitEQ` (protótipo Butterworth, parâmetros float, desenho interno não documentado).

## Decisão proposta

1. O DSP vive num **núcleo isolado com fronteira C ABI estável** (`timbre_dsp.h`): cria/destrói cadeias, aplica parâmetros por mensagens atômicas, processa blocos. A thread de áudio só chama `process()`.
2. **Matemática em double** em todos os estágios internos; conversão para Float32 apenas na entrada/saída do tap.
3. A implementação é escolhida por E-06 entre:

| Candidato | Prós | Contras |
|---|---|---|
| **C++20 próprio** + Accelerate (`vDSP_biquadD`, `vDSP_biquadm_SetTargetsDoubleD`) | Controle total; integração direta via Swift–C++ interop; RTSan do Clang disponível | Escrevemos e testamos tudo |
| **Crate `camilladsp` v5 (Rust, MPL-2.0)** | Motor maduro e auditado por audiófilos; filtros, FIR particionado, limiter, dither, loudness prontos | Depende de o crate estar publicado como biblioteca; toolchain Rust no build; FFI |
| Swift puro na thread de áudio | Uma linguagem só | ARC, alocações escondidas e checagens de runtime tornam garantias de tempo real difíceis |

## Critérios de decisão (E-06)

Precisão contra a resposta analítica, ruído e THD+N adicionados, CPU por instância, facilidade de testes golden, maturidade e licença compatível com o ADR-0001.

> **Nota de revisão adversarial (`C-06`):** há preferência explícita pelo candidato **C++20 + Accelerate (`vDSP`)** no MVP caso atinja integralmente as metas de RTSan e metrologia do [`estrategia-de-testes.md`](../06-plano/estrategia-de-testes.md), evitando exigir toolchain Rust para novos contribuidores nessa fase. O `camilladsp` v5 continua avaliado em E-06 e reservado para convolução FIR/extras pós-MVP se reduzir complexidade sem perda.

## Consequências

Os testes golden do núcleo (`06-plano/estrategia-de-testes.md`) independem da implementação, o que permite trocar o candidato sem perder verificação.
