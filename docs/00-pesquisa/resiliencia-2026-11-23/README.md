# Snapshot de rastreadores públicos

> **Nota de higiene do repositório:** os arquivos brutos de issues de terceiros (`*.json` e `inventario.csv`, ~13 MB) ficam fora do Git via `.gitignore` para manter o repositório leve e evitar redistribuição em massa de trackers externos. O manifesto da coleta (`coleta.json`), o resumo abaixo e a cobertura bibliográfica (`cobertura-bibliografia.md`) permanecem versionados; os arquivos brutos podem ser regenerados localmente conforme o comando de atualização abaixo.

7682 issues de 19 repositórios. Coleta: 2026-11-23T20:35:50.918727+00:00.

Paginação integral dos endpoints consultados, abertas e fechadas; PRs excluídos. O corpo está no JSON. Comentários, anexos, discussions e PRs ainda não foram coletados. Não equivale a todas as falhas existentes nem à revisão humana de todos os registros.

`inventario.csv`: uma linha por issue, URL e estado upstream. Categorias são sugestões por palavras no título, incluindo feature requests; não são diagnóstico. Todas começam pendentes e sem teste vinculado. Não use contagem de issues como contagem de bugs.

Atualização: a coleta pode ser refeita via GitHub REST `/repos/{owner}/{repo}/issues?state=all&per_page=100`, seguindo todos os links de paginação e excluindo `pull_request`. `scripts/index_resilience_research.py` regenera somente o índice.

| Repositório | Issues coletadas |
|---|---:|
| MrKai77/DynamicNotchKit | 31 |
| Sakuleta/tapmix | 0 |
| jatinindia/MacEQ | 1 |
| Lakr233/NotchDrop | 52 |
| ungive/mediaremote-adapter | 28 |
| Torteous44/radioform | 14 |
| HEnquist/camilladsp | 271 |
| vincentneo/LosslessSwitcher | 100 |
| belugaming/tapline | 3 |
| MonitorControl/MonitorControl | 1042 |
| sparkle-project/Sparkle | 1432 |
| Ebullioscopic/Atoll | 396 |
| jaakkopasanen/AutoEq | 985 |
| ExistentialAudio/BlackHole | 420 |
| bitgapp/eqMac | 900 |
| TheBoredTeam/boring.notch | 948 |
| kyleneideck/BackgroundMusic | 729 |
| insidegui/AudioCap | 0 |
| ronitsingh10/FineTune | 330 |
