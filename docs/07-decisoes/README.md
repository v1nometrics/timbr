# Registro de decisões (ADRs)

Formato: um arquivo por decisão, `ADR-XXXX-titulo.md`, com as seções Contexto, Decisão, Alternativas, Trade-offs, Evidência, Consequências, Condição de revisão. Status possíveis: **Proposto** (ainda não vale), **Aceito**, **Substituído por ADR-YYYY**, **Rejeitado**.

Uma decisão "Proposta" só vira "Aceita" quando (a) o dono aprova, quando é decisão de produto/negócio, ou (b) o experimento indicado produz o resultado exigido, quando é decisão técnica.

| ADR | Decisão | Status | Depende de |
|---|---|---|---|
| [0001](ADR-0001-licenca.md) | Licença MPL-2.0 + DCO; GPL só como referência de estudo | Proposto (decisão do dono) | — |
| [0002](ADR-0002-plataforma-nativa.md) | App nativo Swift 6 + SwiftUI/AppKit; stack web só para docs, site e playground do design system | Aceito | — |
| [0003](ADR-0003-nucleo-dsp.md) | Núcleo DSP em double com fronteira C ABI; implementação (C++ próprio vs crate CamillaDSP) decidida por E-06 | Proposto | E-06 |
| [0004](ADR-0004-captura-por-process-taps.md) | Captura por process taps; sem plug-in HAL no MVP | Aceito na direção, topologia fina por E-02/E-04 | E-02, E-04 |
| [0005](ADR-0005-piso-macos.md) | Piso de sistema: macOS 15; recursos de taps do 26 usados quando disponíveis | Proposto | E-02 |
| [0006](ADR-0006-processo-do-motor.md) | Motor de áudio em processo auxiliar separado da UI | Proposto | E-16 |
| [0007](ADR-0007-distribuicao.md) | Developer ID + notarização + Sparkle 2 + Homebrew cask | Aceito | — |
| [0008](ADR-0008-ia-propoe-dsp-decide.md) | IA só emite deltas tipados e validados; local primeiro | Aceito | — |
| [0009](ADR-0009-formato-de-presets.md) | Formato nativo JSON de intenção; EqualizerAPO ParametricEQ como intercâmbio | Aceito | — |
| [0010](ADR-0010-correcao-e-gosto.md) | Correção objetiva e Gosto subjetivo em camadas separadas | Aceito | — |
| [0011](ADR-0011-drivers-de-dispositivo.md) | Drivers de dispositivo plugáveis por capacidade, read-first | Aceito na direção | E-09 |
| [0012](ADR-0012-tokens-fonte-unica.md) | Tokens de design em fonte única (JSON) gerando Swift e CSS | Aceito | — |
| [0013](ADR-0013-superficies.md) | Notch como superfície primária + barra de menus + janela Estúdio + Live Activity quando disponível | Aceito | E-12 |
| [ADR-0014](ADR-0014-nome-identidade-e-i18n.md) | Nome oficial `timbr.`, alinhamento `v1torres.dev` e i18n PT/ES/EN na v1 | **Aceito** |
