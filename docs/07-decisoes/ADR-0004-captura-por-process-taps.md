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

Com `.mutedWhenTapped`, se o motor morrer, o mute acaba e o app volta a tocar direto no dispositivo: o fail-safe (P2) vem da plataforma.
