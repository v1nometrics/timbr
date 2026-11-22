# Teste E2E · volume por app (2026-11-22)

> Classe de evidência: **Comprovado** (medido no app instalado, MacBook Air, alto-falantes internos a 48 kHz). Reproduzível com `scripts/selftest_audio.sh`.

## Relato

"A regulagem de som não funciona exatamente, acima de 100% não muda nada, e a saída de som que o app cria tem algum bug."

## Como medimos

`Timbr --selftest-audio <relatório.json>` roda dentro do app assinado, que tem a permissão de Gravação de Áudio do Sistema. O teste toca um tom de 1 kHz com `afplay` e aciona o `ProcessTapEngine` real, como a interface faz. A medição usa dois taps independentes, sem silenciar nada:

- **Fonte:** tap no próprio `afplay`, medido antes de o timbr. assumir o processo. É o nível original.
- **Saída:** tap no processo do timbr. É o que o timbr. realmente entrega ao dispositivo.

O ganho medido é a saída menos a fonte, em dB. Nenhum número é simulado.

## Causa raiz

`ensureTapSlot` forçava `tapDesc.isExclusive = true` em **todos** os taps. No Core Audio, `isExclusive = true` significa "capturar tudo **exceto** estes processos". O tap por app (`stereoMixdownOfProcesses`) virava, então, "todos os outros apps":

- mexer no fader de um app silenciava e alterava o volume de todos os outros;
- o app escolhido continuava tocando intocado.

Reproduzimos o bug recolocando a linha temporariamente:

| Caso | Esperado | Com o bug (medido) | Corrigido (medido) |
|---|---|---|---|
| Volume 50 % | −6,02 dB | +7,87 dB (outro áudio do Mac, não o tom) | **−6,02 dB** |
| Volume 25 % | −12,04 dB | +1,18 dB | **−12,04 dB** |
| Boost 200 % (com folga) | +6,02 dB | +14,11 dB, pico no limitador | **+6,02 dB** |
| Boost 150 % | +3,52 dB | +12,88 dB | **+3,52 dB** |
| Mudo | silêncio | silêncio | **silêncio** (−180 dBFS) |
| Boost 200 % num tom de −1 dBFS | pico ≤ −0,3 dBTP | −6,13 dB | **+0,70 dB, pico −0,30 dBFS** |

## Outros defeitos corrigidos na mesma revisão

1. **As saídas agregadas do timbr. apareciam como dispositivos** na lista de saídas do próprio app. Podiam até ser escolhidas como espelho, e a lista mudava a cada tap criado. Agora são filtradas pelo prefixo de UID.
2. **Corrida de parâmetros no DSP.** O buffer duplo podia ser sobrescrito enquanto a thread de áudio ainda o lia. A cada 2 s e a cada movimento de fader, o app publicava a mesma EQ duas vezes seguidas. Agora há buffer triplo wait-free (`timbre_dsp_update`), e a EQ só é publicada quando muda. Um teste de corrida roda sob ASan e UBSan no CI.
3. **Callback de áudio presumia "primeiro buffer, estéreo intercalado".** O `TapRenderer` agora:
   - lê o tap no fim da lista de entradas, depois das entradas do subdispositivo;
   - aceita estéreo intercalado ou dois buffers mono;
   - escreve L/R nos canais 0 e 1 de saídas multicanal, em saídas planares ou como mix mono;
   - zera todo o resto.
4. **Falhas silenciosas.** Erros de criação de tap, agregado, IOProc ou start agora têm motivo (código `OSStatus`) e vão para o Observatório (categoria `routing`).
5. **`updateDSP` mexia num slot por app** quando não havia slot global, e sobrescrevia o ganho do app com o ganho global. Agora toca só no global.
6. **Espelho tocava apps silenciados.** O tap de espelho agora exclui apps no mudo.

## Limites honestos

- **Boost em música alta:** um master moderno já está perto de 0 dBFS. Acima de 100%, o limitador segura o pico em −0,3 dBTP: no teste, 200% sobre um tom de −1 dBFS rendeu só +0,7 dB. O Mixer agora mostra "No limite · mais volume distorceria" quando o limitador de um app passa de 1 dB de redução.
- **Espelhos** recebem cada app no volume original; o volume por app não é replicado nas saídas espelhadas.
- **Mudo de verdade no dispositivo:** o teste mede o que o timbr. emite, não o som que sai do alto-falante. Que o original fica silenciado vem do `.mutedWhenTapped` do Core Audio. Isso não foi medido por loopback físico.
