# ADR-0021 · O notch percebe a pausa sem esperar o macOS

- **Status:** Aceito · 2026-11-23 (pedido do dono do produto: "muito delay para perceber que o áudio parou")

## Contexto

O notch decidia "está tocando" só por `kAudioProcessPropertyIsRunningOutput`. Medido no macOS 26.6:

| Evento | A propriedade vira falsa depois de |
|---|---|
| `NSSound.stop()` | 2,1 s |
| `NSSound.pause()` | 7,4 s |
| Spotify, pausa de verdade | ~3,7 a 4,1 s (estimado: o instante do clique não foi registrado) |

`IsRunning`, `IsRunningOutput` e `DeviceIsRunningSomewhere` viram falsos juntos, e o macOS **não notifica** a mudança para falso (nenhum evento do monitor no stop). Além do atraso do sistema, havia um defeito nosso: a espera de 3 s antes de recolher o compacto era **cancelada e reiniciada a cada reavaliação** (a cada 2 s), então podia ser empurrada indefinidamente. Na build anterior, o compacto **não saiu** nos ~11 s medidos depois de um stop ou de um pause.

## Alternativas medidas e descartadas

- **Notificações do Spotify** (`PlaybackStateChanged`): nenhuma chegou durante uma sessão real de play e pause.
- **MediaRemote** ("Now Playing"): ficou em `false` o tempo todo com o Spotify tocando; o macOS bloqueia apps de terceiros.
- **Uma propriedade do Core Audio mais rápida:** não há; todas atrasam igual.
- **Tap só para medir o nível:** acende o indicador de gravação e dispara a detecção de reunião do superwhisper (docs/08-registro/compatibilidade-apps).

## Decisão

1. **Debounce armado uma vez** (`updateCompactState`): 0,35 s depois do último som, em vez de 3 s reiniciados. O atraso do macOS já funciona como debounce.
2. **Vigia de 250 ms enquanto algo toca**, barato (algumas leituras de propriedade; só relê tudo quando uma fonte que tocava parou), porque o macOS não avisa.
3. **Silêncio medido pelo nosso DSP quando já há tap** (EQ, crossfeed, ducking ou volume por app): `SilenceTracker` marca um slot como silencioso depois de 1,0 s abaixo de −75 dB e deixa de marcar no primeiro bloco alto. A pausa é percebida em ~1,6 s. Sem EQ ou volume por app, não há tap e não há sinal para medir: vale o tempo do macOS.
4. Mudo, volume zero e VoIP ficam de fora dessa lógica: um app mudo pelo timbr. gera silêncio por construção, mas continua "tocando".

## Medido (janela real do notch, ~7 quadros/s; "some" = pílula preta sai da faixa do notch)

| Cenário | Antes | Depois |
|---|---|---|
| Caminho nativo, stop | não saiu em 11 s | 2,6 s (macOS: 2,1 s) |
| Caminho nativo, pause | não saiu em 11 s | 8,1 s (macOS: 7,4 s) |
| Com tap (crossfeed ligado), pause | — | **1,6 s** |
| Com tap, stop | — | **1,7 s** |

CPU com som tocando: 9,1–9,9% contra 8,2% na versão anterior (uma medição); parado, 3,2–3,9%.

## Chave opcional (implementada)

Em Ajustes > Notch, **"Perceber pausas na hora"** (desligada por padrão) mantém um tap global enquanto algo toca, mesmo com EQ plano e sem volume por app, para o silêncio poder ser medido. Medido: pausa em **1,63 s** e stop em 1,77 s no caminho antes nativo (contra 8,07 s e 2,6 s). O custo está escrito na própria opção: o áudio passa pelo DSP (sai do "caminho nativo"), o indicador de gravação do macOS fica aceso e o superwhisper pode sugerir uma reunião.

## Limites

- **Com a chave desligada, no caminho nativo, sem tap, a pausa leva o tempo do macOS** (2 a ~8 s, ~4 s no Spotify). Para ter ~1,6 s também aí seria preciso um tap permanente, o que tira o "caminho nativo" (o áudio passaria pelo DSP) e acende o indicador de gravação. Fica como opção para o dono decidir, não ligada por padrão.
- Entre duas faixas, um silêncio maior que 1 s é visto como pausa e o compacto recolhe; volta no primeiro som.
