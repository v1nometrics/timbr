# ADR-0017 · Mudo à prova de falha: `timbr-mute-keeper`

- **Status:** Aceito · 2026-11-23 (pedido do dono do produto: "isso em hipótese alguma pode acontecer")
- **Emenda:** P2 em [visão e princípios](../01-visao/visao-e-principios.md) e a nota de fail-safe da [ADR-0004](ADR-0004-captura-por-process-taps.md), **somente para o mudo**
- **Relaciona-se com:** [ADR-0006](ADR-0006-processo-do-motor.md) (motor em processo separado, ainda Proposto)

## Contexto

O mudo por app era um process tap privado `.mutedWhenTapped`, lido por um IOProc que escrevia silêncio dentro do processo do timbr. O Core Audio destrói os taps privados junto com o processo que os lê. Quando o timbr. morria por crash, SIGKILL, atualização ou "Forçar encerramento", todo app silenciado voltava a tocar. Esse era o P2 ("se o app morrer, o som volta") funcionando como projetado. Para o mudo, porém, ele é o comportamento errado: um Spotify silenciado no meio de uma aula volta a tocar sozinho.

O mesmo vale para um app com o fader em 0 %, que na prática também é um mudo.

## O que foi medido antes de decidir (2026-11-23, macOS 26.6)

| Hipótese | Resultado | Como |
|---|---|---|
| Um tap **público** (`isPrivate = false`) sobrevive ao processo que o criou | **Comprovado** | O tap continua listado em `kAudioHardwarePropertyTapList` depois do SIGKILL do criador, e outro processo consegue assumi-lo e destruí-lo |
| Um tap `.muted` **sem ninguém lendo** silencia o app | **Refutado** | Teste de ouvido: os bipes continuaram com o tap `.muted` criado e o processo vivo, e também depois do SIGKILL |
| `bundleIDs` + `processRestoreEnabled` (macOS 26) fazem o tap seguir o app quando ele reabre | **Comprovado** | O tap sobrevivente passou a listar o processo novo (`[125]`) do player relançado |
| Um processo separado que lê o tap segura o mudo depois do SIGKILL do timbr. | **Comprovado** | `selftest_mute_persistence.sh` (mecânica) e teste de ouvido `listen_mute_crash.sh`: silêncio com o timbr. vivo **e** depois do `kill -9` |

Conclusão: **só silencia um tap que esteja sendo lido**, e só um processo vivo consegue ler. Um mudo que precisa sobreviver ao timbr. precisa, portanto, de outro processo vivo.

## Decisão

1. **`timbr-mute-keeper`**, um executável mínimo dentro do bundle (`Contents/MacOS/`), segura os mudos. Não tem UI, DSP nem rede, então tem muito pouco que possa travar. Para cada app silenciado ele mantém um tap `.mutedWhenTapped`, um aggregate privado na saída padrão e um IOProc que escreve silêncio, o mesmo mecanismo que o timbr. sempre usou. O tap leva os `bundleIDs` do app e dos helpers dele (`<owner>.…`), com `processRestoreEnabled`, para continuar mudo se o app reabrir. Processos de sistema compartilhados, como `com.apple.WebKit.GPU`, nunca entram por bundle ID.
2. **Contrato por arquivo** ([`MuteKeeperProtocol`](../../Sources/TimbreCore/MuteKeeperProtocol.swift)) em `~/Library/Application Support/dev.v1torres.timbr/mute-keeper/`: `request.json` (o que o timbr. quer mudo, com geração), `status.json` (o que o keeper confirma segurar) e `keeper.lock` (`flock` exclusivo, uma instância só). O `request.json` também é o registro que um timbr. reaberto lê de volta.
3. **Troca sem janela.** O timbr. continua silenciando o app dentro do próprio processo até o keeper confirmar aquele app para a geração atual (`confirmedHeld`). Só então solta o mudo dele. Na troca do dispositivo de saída, o keeper monta o tap novo antes de destruir o antigo.
4. **Vida do keeper.** O timbr. dispara o keeper com `posix_spawn` + `POSIX_SPAWN_SETSID`, em sessão própria e com outro nome de processo, para que nem `pkill -x Timbr` nem o "Forçar encerramento" do timbr. o atinjam. O keeper sai sozinho quando a lista fica vazia. Ao reabrir, o timbr. adota o que um keeper vivo segura e mostra esses apps como mudos.
5. **Sair pelo menu** com apps mudos pergunta o que fazer: "Sair e manter o silêncio" (padrão), "Restaurar o som e sair" ou "Cancelar". Logout, reinício e quits por script não perguntam e mantêm o mudo.
6. **Saída de emergência:** `Timbr --release-all-mutes` libera tudo, mesmo com o timbr. fechado.
7. **Instâncias auxiliares** (`--smoke-check`, `--review-*`, `--demo`, `--notch`, `--studio`, `--selftest*`) não recebem keeper, então nunca reescrevem nem liberam o mudo da instância real.
8. **Degradação:** se o keeper não abrir (binário ausente ou falha no spawn), o mudo continua dentro do timbr., como antes. Ele funciona, só deixa de ser à prova de falha, e a falha vai para o log de eventos.

## P2 depois desta ADR

- **Volume ≠ 0, EQ, crossfeed e espelhos:** continuam *fail-open*. Se o timbr. morrer, o app volta ao som original (P2 intacto).
- **Mudo e fader em 0 %:** passam a ser *fail-closed*. Se o timbr. morrer, o app continua mudo enquanto o keeper viver.

## Alternativas

| Alternativa | Por que não |
|---|---|
| Tap público `.muted` sem leitor | Implementado e medido: não silencia (teste de ouvido) |
| `LaunchAgent` com `KeepAlive` para relançar o timbr. | O som escapa entre a morte e o relançamento (≥ 1 s, com throttle do launchd) |
| Mover o motor inteiro para fora da UI (ADR-0006) | Resolve mais coisas, mas é bem maior. O keeper é o primeiro passo dessa direção e não fecha a ADR-0006 |
| Mudo global de saída quando o timbr. morre | Ninguém está vivo para aplicar, e silenciaria tudo, não só o app escolhido |

## Trade-offs e limites honestos

- **SIGKILL do próprio keeper** (só deliberado, por `kill -9`) solta o mudo. Nenhum processo consegue segurar um tap depois de morto. Se o timbr. estiver aberto, ele relança o keeper e volta a silenciar no ciclo seguinte (≤ 2 s).
- **Logout e reinício** encerram tudo. Depois do reboot, os apps tocam normalmente e o `request.json` só é adotado se houver um keeper vivo.
- O keeper herda a responsabilidade TCC do timbr. (é filho dele). Recriar taps depois que o timbr. morreu (troca de saída) não foi medido sem permissão. O ouvido confirmou o caso principal (SIGKILL do timbr.).
- O indicador roxo de gravação continua aceso enquanto algum app estiver mudo, igual a antes.
- Esses medidores não conseguem medir o silêncio no alto-falante: taps leem o áudio **antes** do mudo, e o timbr. não tem permissão de microfone. A audibilidade fica coberta pelo teste de ouvido.

## Evidência

- `scripts/selftest_mute_persistence.sh`: 5/5 (player tocando; keeper confirma; keeper sobrevive ao SIGKILL do timbr. e segura o mudo; timbr. reaberto adota; liberar faz o keeper sair).
- `scripts/listen_mute_crash.sh`: dono do produto, 2026-11-23. Silêncio nas partes 2 (timbr. vivo) e 3 (timbr. morto por `kill -9`), som de volta na 4.
- `scripts/selftest_audio.sh`: −6,02 / −12,04 / +6,02 / +3,52 dB, mudo −180 dBFS e limiter em −0,30 dBFS. O caminho de volume não mudou.
- `./scripts/ci_check.sh` verde. Testes de `PersistentMutePolicy` e `MuteKeeperProtocol` em `TimbreCoreTests`.
