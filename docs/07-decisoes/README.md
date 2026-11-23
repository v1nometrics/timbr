# Registro de decisões (ADRs)

Formato: um arquivo por decisão, `ADR-XXXX-titulo.md`, com as seções Contexto, Decisão, Alternativas, Trade-offs, Evidência, Consequências, Condição de revisão. Status possíveis: **Proposto** (ainda não vale), **Aceito**, **Substituído por ADR-YYYY**, **Rejeitado**.

Uma decisão "Proposta" só vira "Aceita" quando (a) o dono aprova, quando é decisão de produto/negócio, ou (b) o experimento indicado produz o resultado exigido, quando é decisão técnica.

| ADR | Decisão | Status | Depende de |
|---|---|---|---|
| [0001](ADR-0001-licenca.md) | Licença MPL-2.0 + DCO; GPL só como referência de estudo | **Aceito** | — |
| [0002](ADR-0002-plataforma-nativa.md) | App nativo Swift 6 + SwiftUI/AppKit; stack web só para docs, site e playground do design system | Aceito | — |
| [0003](ADR-0003-nucleo-dsp.md) | Núcleo DSP em `Float64` (`C++20 + Accelerate/vDSP`) com fronteira C ABI | **Aceito** (`E-06`) | E-06 |
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
| [ADR-0015](ADR-0015-tipografia-de-sistema.md) | Tipografia de sistema SF Pro / SF Mono / New York no app; Geist só na web | **Aceito** |
| [ADR-0016](ADR-0016-identidade-acromatica.md) | Identidade acromática: sem cor de marca; ênfase por tinta; cor só semântica (substitui a cor da ADR-0014) | **Aceito** |
| [ADR-0019](ADR-0019-equalizador-de-4-5-10-bandas-e-peq-livre.md) | Equalizador de 4, 5 ou 10 bandas + PEQ livre; corrige o ponto que não movia a curva e adiciona Resetar filtros | **Aceito** |
| [ADR-0018](ADR-0018-linha-do-tempo-busca-e-exportacao.md) | Linha do tempo do Observatório: paginação por cursor, busca FTS5 trigram, filtro e exportação CSV/JSON em fluxo, sem travar o app | **Aceito** |
| [ADR-0020](ADR-0020-sons-do-sistema-nao-acordam-o-notch.md) | Sons curtos do sistema (clique inválido, alertas) não acordam o notch; seguem no Mixer | **Aceito** |
| [ADR-0021](ADR-0021-notch-percebe-a-pausa-sem-esperar-o-macos.md) | O notch percebe a pausa sem esperar o macOS: debounce armado uma vez, vigia de 250 ms e silêncio medido quando há tap | **Aceito** |
| [ADR-0022](ADR-0022-icone-do-app-notch-e-som.md) | Ícone do app: o notch pendurado na borda e as cinco barras de som abaixo, em papel quente (substitui o monólito escuro) | **Aceito** |
| [ADR-0017](ADR-0017-mudo-a-prova-de-falha.md) | Mudo à prova de falha: `timbr-mute-keeper` segura apps mudos (e em 0 %) mesmo se o timbr. morrer; emenda P2 só para o mudo | **Aceito** |
