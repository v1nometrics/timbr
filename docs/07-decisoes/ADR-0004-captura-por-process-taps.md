# ADR-0004 · Captura por process taps, sem plug-in HAL no MVP

- **Status:** Aceito na direção · topologia detalhada decide em E-02 e E-04
- **Data:** 2026-11-21

## Contexto

Há dois caminhos para colocar o áudio de cada app no nosso pipeline: process taps do Core Audio (macOS 14.2+, API pública, sem driver) e plug-ins HAL (AudioServerPlugIn, dispositivo virtual como saída padrão). Um engenheiro da Apple recomenda taps para loopback de áudio do sistema; a Rogue Amoeba aposentou o ACE e, pelos logs do `coreaudiod`, o ARK do SoundSource 6 usa a maquinaria de taps; o BackgroundMusic segue "alpha" e o eqMac acrescentou taps.

## Decisão

- **Captura exclusivamente por process taps** com `.mutedWhenTapped`, aggregates **privados** e IOProc próprio.
- **Topologia candidata:** um motor por dispositivo físico de saída; cada motor contém os taps das fontes roteadas a ele; Bluetooth em aggregate próprio sem drift correction; soma → EQ de dispositivo → limiter → saída.
- **Nenhum tap quando não há processamento** para aquela fonte (P1).
- **Plug-in HAL fica fora do MVP.** Reavaliar apenas se surgir necessidade de um dispositivo virtual selecionável por outros apps (estilo Loopback) ou se um bug de taps se mostrar intransponível.

## Alternativas

| Alternativa | Por que não agora |
|---|---|
| Plug-in HAL como base | Instalador admin que reinicia o `coreaudiod`, indicador de microfone aceso, muda o dispositivo padrão do usuário, menos alinhado à direção da Apple |
| Híbrido taps + plug-in (como o ARK) | Complexidade dupla; o ganho só aparece em recursos que não estão no MVP |

## Trade-offs aceitos

+10–13 ms de latência por app processado; mixdown estéreo Float32 (sem multicanal pelo tap); ponto roxo permanente enquanto houver tap; bugs abertos do 26/27 exigem watchdog e reconstrução.

## Vantagem estrutural

Com `.mutedWhenTapped`, se o motor morrer, o mute acaba e o app volta a tocar direto no dispositivo: o fail-safe (P2) vem da plataforma. **Emenda ([ADR-0017](ADR-0017-mudo-a-prova-de-falha.md)):** para o mudo escolhido pelo usuário isso é o comportamento errado; o mudo é segurado por `timbr-mute-keeper`, um processo separado que sobrevive ao timbr.

## Lições de implementação (2026-11-22, Comprovado)

- **`isExclusive` inverte o sentido do tap.** `CATapDescription(stereoMixdownOfProcesses:)` já nasce com `isExclusive = false` (capturar *só* estes processos), e `stereoGlobalTapButExcludeProcesses:` nasce com `true` (capturar *tudo exceto* estes). O código forçava `true` em todos os taps, e o tap por app virava "todos os outros apps". Medido com o autoteste: 50 % dava +7,87 dB em vez de −6,02 dB. Nunca sobrescrever `isExclusive` depois do inicializador. Ver [teste E2E](../08-registro/teste-e2e-volume-por-app-2026-11-22.md).
- **Topologia implementada hoje** (diferente da candidata acima):
  - um agregado privado por *slot*: um por app com volume ≠ 100 % ou mudo, um global (EQ, crossfeed, ducking, excluindo os apps com slot próprio, os de VoIP e o próprio timbr.) e um por saída espelhada;
  - cada agregado tem a saída física como subdispositivo principal.
  
  A soma num motor único por destino (para um limiter pós-soma) continua sendo o alvo de RF-0201.
- **Efeito colateral de qualquer tap:** enquanto existe, o processo do timbr. aparece com `IsRunningInput = 1` (a entrada é o stream do tap, não o microfone) e o macOS mostra o ponto roxo. Apps que vigiam "quem usa entrada" reagem a isso: o superwhisper anuncia "Meeting detected" com um navegador aberto. Mitigação: o tap global só existe com áudio tocando, com 10 s de folga. Ver [compatibilidade](../08-registro/compatibilidade-apps-2026-11-22.md).
- **Agregados próprios são invisíveis para os outros processos, mas não para o nosso:** o timbr. filtra o prefixo `dev.v1torres.timbr.agg.` da própria lista de dispositivos, senão eles apareciam como saídas.
