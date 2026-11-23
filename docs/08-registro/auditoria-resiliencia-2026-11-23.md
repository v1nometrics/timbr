# Auditoria de resiliência · 2026-11-23

## Estado e método

**Em andamento; não aprovada como garantia de resiliência.** O limite inicial de 300 issues por consulta não sustentava cobertura completa; a coleta atual segue todas as páginas de 19 rastreadores e preserva título, corpo, estado, datas e URL. Ver [snapshot, limites e instrução de geração local do inventário](../00-pesquisa/resiliencia-2026-11-23/README.md).

Corpo de issue é relato do autor, não reprodução nossa. Issue fechada não prova correção no timbr Feature request não é bug. Sugestão de categoria por título não é análise concluída. Comentários e PRs podem conter a causa e ainda exigem leitura. A auditoria histórica dos 62+ projetos nas notas 11/11a/11b/11c continua sendo insumo, não aceite operacional.

## Lacunas comprovadas no código e no build

| ID | Evidência | Consequência | Estado / aceite exigido |
|---|---|---|---|
| RES-01 | `build_app.sh` não passava `-target`; Mach-O de app e helper tinha `minos 26.0`, plist 14.2, Package.swift 15 | Usuário em versão declarada compatível pode não iniciar o app | Corrigido alvo explícito 15.0 em todos os compiladores do build, plist 15.0; `check_deployment_target.py` verifica ambos os Mach-O no CI. Execução em macOS 15 físico continua pendente; alvo compilável não é bancada |
| RES-02 / R-06 | `HALManager` observa dispositivos e saída padrão; não observa `kAudioHardwarePropertyServiceRestarted`. `AudioProcessMonitor` retém IDs e listeners | Objetos antigos podem sobreviver no estado local após reinício do serviço | Aberto, crítico. Reconstruir listeners e taps, redescobrir IDs; testar EQ/ganho/mudo antes e após reset real |
| RES-03 / R-06 | Ausência de `willSleepNotification` / `didWakeNotification` no motor/app | Reconciliação por timer não garante recuperação após suspensão | Aberto, crítico. Testar suspensão curta/longa, tampa fechada, wake com dock removido, saída indisponível e troca BT |
| RES-04 | Keeper mantém `slots` e confirma `held` por chaves locais; não há validação de existência do tap após reset do serviço | Status pode confirmar um mudo sem objeto válido no HAL | Aberto, crítico. Readback do HAL e recuperação no helper, inclusive com UI encerrada. Medir janela de escape; não prometer silêncio durante queda do servidor só porque o helper sobrevive |
| RES-05 | R-22 não inclui o uso atual de SkyLight em `NotchSpaceOverlay` | API privada de Spaces amplia a superfície de quebra entre versões | Aberto. Exercitar ausência de símbolos/falha de chamada e fallback público; verificar foco, fullscreen e hotplug em cada OS suportado |

## Falhas externas examinadas e critérios para o timbr

Os títulos abaixo foram conferidos no snapshot; o relato não foi reproduzido por nós.

| Fonte | Falha / risco transferível | Aceite no timbr | Estado |
|---|---|---|---|
| [FineTune #170](https://github.com/ronitsingh10/FineTune/issues/170), [#268](https://github.com/ronitsingh10/FineTune/issues/268), [#273](https://github.com/ronitsingh10/FineTune/issues/273) | Início da reprodução escapa do ganho/EQ | Capturar primeiro bloco após silêncio, novo processo, reinício de app e troca de saída; medir pico e ganho, não só sinal estabilizado | Pendente, R-02 |
| [FineTune #375](https://github.com/ronitsingh10/FineTune/issues/375), [#346](https://github.com/ronitsingh10/FineTune/issues/346) | Reconexão de monitor/USB com volume inesperado, volume preso | Reconectar HDMI/USB com volume 0/25/100%, mudo e ganho por app; verificar saída real e UI | Bancada pendente |
| [FineTune #483](https://github.com/ronitsingh10/FineTune/issues/483), [#404](https://github.com/ronitsingh10/FineTune/issues/404) | Chamadas com volume muito baixo | Matriz FaceTime/WhatsApp/Zoom/Teams, entrada BT/interna e exclusão VoIP; garantir que processo auxiliar não receba tratamento errado | Pendente |
| [boring.notch #420](https://github.com/TheBoredTeam/boring.notch/issues/420), [#371](https://github.com/TheBoredTeam/boring.notch/issues/371), [#241](https://github.com/TheBoredTeam/boring.notch/issues/241) | Notch desaparece/desalinha após wake e monitor externo | Sleep/wake em múltiplas escalas e telas, Mission Control, clamshell, dock; medir geometria e hit-testing | Pendente |
| [Atoll #866](https://github.com/Ebullioscopic/Atoll/issues/866) | Memória cresce na conversão de imagem de fallback | Limitar cache, não converter imagem por frame; soak com fallback e alternância de fontes, RSS estabiliza | Pendente; Now Playing ainda fora do produto |
| [Atoll #892](https://github.com/Ebullioscopic/Atoll/issues/892) | Tecla repetida continua reduzindo volume | Key down/up, auto-repeat, revogação de AX e tap disabled; nenhuma ação após key up | Teste específico pendente |
| [NotchNook oficial](https://lo.cafe/changelog/) | Hotplug deixa overlays em memória; dois displays elevam CPU/RSS; teclas continuam após soltar; tampa não suspende na lock screen | Contar janelas/monitores/listeners após 100 hotplugs; soak CPU/RSS; key up; sleep bloqueado/desbloqueado | Pendente |
| [DynamicLake histórico oficial](https://www.dynamiclake.com/changelogoldversions) | Hover preso, ocultação em telas largas, congelamento sob carga e CPU 100% | Entradas/saídas rápidas do sensor, fullscreen, telas largas; perfil de CPU com painel aberto/fechado e nenhum áudio | Pendente |
| [SoundSource release notes](https://rogueamoeba.com/support/releasenotes/?product=SoundSource) | Recuperação de wake/AirPlay, silêncio em saídas não padrão e configurações problemáticas do OS | Matriz wake, dispositivo sem saída, AirPlay, BT, HDMI, USB e coexistência com capturadores; falha visível e recuperação limitada por backoff | Pendente, R-01/R-06 |

As notas comerciais acima registram correções declaradas pelo fabricante, não certificação independente. A página encontrada para “Alcove” precisa de verificação de identidade com a referência original antes de incorporá-la: o nome sozinho não prova que é o mesmo produto. Sound Control retornou HTTP 429 na coleta das release notes; a leitura permanece pendente.

## Matriz transversal obrigatória

Para cada família, vincular fonte → cenário reproduzível → código → teste executado → artefato → resultado. Uma cobertura só fecha com os seis elos.

- **Ciclo de vida:** lançamento/relaunch, crash/SIGKILL, UI travada, helper morto, reset Core Audio, sleep/wake, lock/unlock, logout, upgrade do OS.
- **Áudio:** primeiro bloco, silêncio verdadeiro vs tap zerado, 44,1/48/96/192 kHz e limites, mono/estéreo/multicanal, interleaved/planar, mudança de formato, clipping pós-soma, canais trocados, drift e latência.
- **Dispositivos:** BT A2DP/HFP, AirPods multiponto, AirPlay, USB/HDMI/dock, dispositivo sem volume/mute settable, nomes iguais com UIDs distintos, saída removida sem substituta.
- **Coexistência e identidade:** navegadores e subprocessos, VoIP, DRM, DAWs/hog mode, agregados de terceiros, capturadores concorrentes; nunca destruir objeto que não pertence ao timbr
- **Interface:** sem notch, telas externas/escaladas, fullscreen vídeo/trabalho, Spaces/Mission Control, menu bar oculta, foco/teclado/AX, reduzir movimento, contraste e idiomas longos.
- **Recursos:** nenhuma atividade sem necessidade, nenhuma assertion impedindo sleep em idle, cache e logs limitados, timers/listeners encerrados, fila de eventos sob carga, exportação grande sem bloquear UI.
- **Dados e distribuição:** preset inválido/NaN/infinito, import excessivo, migração/SQLite cheio/corrompido, export sanitizado, IPC autenticado, TCC negado/revogado, assinatura estável, update interrompido e rollback, notarização e versão mínima real.

## Ordem de fechamento

1. R-06 completo no motor **e keeper**, com ensaio real e medição do escape de mudo. Não confundir restauração de mudo com garantia de continuidade durante queda do serviço.
2. Primeiro bloco e reconexão com volume alto (R-02), multicanal e formatos (R-03), coexistência e voz.
3. Soak de displays/Spaces/hover, memória/CPU e fallback de APIs privadas.
4. Revisar individualmente o inventário, incluindo itens sem classificação e feature requests; ler comentários/PRs relevantes. Ampliar para demais repositórios da bibliografia, reviews/discussions e fontes comerciais ainda faltantes.
5. Somente então consolidar matriz de cobertura e atualizar claims de prontidão. Nenhuma promessa de “não repetir nenhum bug” é sustentada enquanto estes gates estiverem abertos.

## Verificação executada nesta rodada

`./scripts/ci_check.sh` terminou com código 0: build completo, verificação de deployment target dos dois executáveis, DSP ASan/UBSan e RTSan quando disponível no script, Core, Engine, tokens, smoke check e 20/20 SIGKILL sem agregados órfãos e com saída padrão preservada. Nenhum caminho de render/tap/mute foi alterado nesta rodada; os testes acústicos não foram repetidos. Não houve instalação nem publicação desta build. O limite macOS 15 foi conferido no binário; não executado em máquina com esse OS.
