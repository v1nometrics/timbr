# ADR-0001 · Licença do projeto

- **Status:** Proposto · aguarda decisão do dono
- **Data:** 2026-11-21

## Contexto

O projeto nasce open source "a princípio", com possibilidade futura de um plano pago. As referências mais úteis são copyleft: FineTune, boring.notch, Atoll, LosslessSwitcher, Lyrimuse e BlackHole (com restrição adicional de marca) são GPL-3.0; BackgroundMusic é GPL-2.0; JUCE (sem licença comercial), FxSound e AirBattery são AGPL-3.0; PerAppVolume usa PolyForm Noncommercial; audiotee, Liland, media-control e JamesDSPManager não possuem arquivo `LICENSE` (`NONE`). Copiar código GPL/AGPL ou usar repositórios sem licença contamina ou inviabiliza o projeto. Em contrapartida, a auditoria da Fase 2 (nota 11) comprovou um núcleo permissivo completo: `CoreAudioTapKit` e `tapmix` (MIT), `AudioCap` (BSD-2), `sbooth/CAAudioHardware` e `orchetect/swift-core-audio` (MIT), `mediaremote-adapter` (BSD-3), `AutoEq` (MIT), `libASPL` (MIT), `spfk-audio-hardware` (MIT), `DynamicNotchKit` e `NotchDrop` (MIT), `KeyboardShortcuts` e `MonitorControl` (MIT), `rubato` (`MIT OR Apache-2.0`), `sdroege/ebur128` e `jiixyj/libebur128` (MIT), `r8brain-free-src` (MIT), `LyricFever` (MIT), e o `CamillaDSP` (v4.1.3 e v5.0.0-beta.2 em `Cargo.toml` sob licença dupla `GPL-3.0-only OR MPL-2.0`, com a v5 expondo `camilladsp` e `camilladsp-schema` como crates de biblioteca).

## Opções

| Opção | Permite reusar código GPL | Impede forks fechados | Permite plano pago futuro | Mac App Store | Atrito para contribuidores |
|---|---|---|---|---|---|
| **A. GPL-3.0** | Sim | Sim | Só vendendo binários GPL, ou com CLA + nenhum código de terceiros GPL | Conflito histórico (VLC/iOS 2011), não testado no Mac desde então | Baixo |
| **B. MPL-2.0 + DCO** (recomendada) | Não (só estudo) | Parcialmente: arquivos MPL modificados continuam abertos | Sim: módulos pagos podem ser arquivos separados | Compatível | Baixo |
| C. Apache-2.0 | Não | Não | Sim | Compatível | Baixo |
| D. GPL-3.0 + CLA (dual license) | Só o que o CLA cobre; código de terceiros GPL trava o dual license | Sim | Sim, com CLA | Via licença comercial | Alto (CLA afasta contribuidores) |

## Decisão proposta

**MPL-2.0 para todo o código do projeto, com DCO (`Signed-off-by`) em vez de CLA.** Projetos GPL/AGPL entram apenas como **referência de estudo** (ler, entender, reimplementar de forma independente), nunca como fonte de código copiado. O CamillaDSP v5 pode ser usado como dependência pela opção MPL-2.0.

## Trade-offs

- Perdemos o atalho de copiar o mixer do FineTune e a casca do boring.notch. Na prática, o FineTune processa em Float32 e tem 248 issues abertas, então reescrever o motor com nossos critérios já estava no plano; a casca do notch tem alternativa MIT (DynamicNotchKit, NotchDrop).
- A MPL é copyleft por arquivo: protege as melhorias no nosso código sem contaminar módulos separados.
- Mantém viável uma versão "lite" na Mac App Store e um plano pago com módulos próprios.

## Regra operacional enquanto o ADR estiver "Proposto"

Nenhum trecho de código de projeto GPL/AGPL é copiado. Ao estudar um projeto GPL, a reimplementação é feita a partir da documentação e do comportamento observado, e o PR cita o projeto estudado na descrição.

## Condição de revisão

Se o dono preferir proteger o ecossistema com GPL-3.0 (opção A), a mudança é barata **antes** do primeiro commit de código e cara depois.
