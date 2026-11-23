# ADR-0018 · Linha do tempo do Observatório: paginação, busca e exportação sem travar o app

- **Status:** Aceito · 2026-11-23
- **Relaciona-se com:** [ADR-0016](ADR-0016-identidade-acromatica.md) (UI sem cor de marca), diagnóstico sanitizado em Ajustes

## Contexto

O app sempre guardou todos os eventos no SQLite (`observatory_events`), mas só uma parte chegava ao usuário: a tela mostrava os 20 mais recentes, a memória guardava 120 e o relatório de diagnóstico exportava esses 120. Não havia como ver o histórico, buscar nem exportar. Havia também riscos de desempenho: nenhum índice em `timestamp`, e toda gravação (`logEvent`) rodava na thread principal.

## Decisão

1. **Um leitor próprio, com conexão própria.** `EventLogReader` abre o banco em modo somente leitura. Com o SQLite em WAL, ler e gravar ao mesmo tempo é seguro, então paginar, buscar ou exportar nunca segura o lock do gravador (`SQLiteStore`). Todas as consultas rodam fora da thread principal; a UI só recebe páginas prontas, e respostas atrasadas (o filtro já mudou) são descartadas por geração.
2. **Paginação por cursor, não por OFFSET.** O cursor é `(timestamp, rowid)`, comparado como tupla (`(timestamp, rowid) < (?, ?)`), que o SQLite resolve com um único salto no índice: a página 2000 custa o mesmo que a primeira, e um evento novo não desloca nem repete o que já está na tela. A UI carrega 100 por página ao rolar, em `LazyVStack`.
3. **Busca com índice.** Tabela FTS5 com tokenizer `trigram` (conteúdo externo, sem duplicar o texto), mantida por gatilhos de inserção e remoção, reconstruída uma vez para o histórico que já existia. Acha qualquer trecho de 3 ou mais caracteres, sem diferenciar maiúsculas ("air spea" acha "MacBook Air Speakers"). O texto digitado é uma frase única entre aspas, então aspas e sintaxe SQL/FTS no campo são só dado. Abaixo de 3 caracteres a busca não é aplicada e a tela avisa. Sem FTS5 no SQLite do sistema, cai para `LIKE` e o app continua funcionando.
4. **Filtro por categoria**, vindo dos dados, combinável com a busca (índice `(category, timestamp)`).
5. **Exportação em fluxo.** CSV (planilha) ou JSON, de **todos** os eventos que casam com a busca e o filtro atuais, não só os da tela: lotes de 1.000 por uma conexão própria, memória constante, escrita em arquivo `.partial` renomeado ao final (nunca fica meio arquivo com o nome real). No CSV, células que uma planilha executaria como fórmula (`=`, `+`, `-`, `@`) ganham um `'` na frente.
6. **Gravações fora da thread principal.** `logEvent` enfileira o `INSERT` numa fila serial; a timeline atualiza o topo quando o evento está no disco (`eventLogRevision`). `shutdown()` esvazia a fila. `saveEvent` passou a `INSERT OR IGNORE`, porque um `REPLACE` apagaria a linha sem disparar o gatilho do índice.
7. **UI** (Observatório, seção "Linha do tempo"): campo de busca, menu de categorias, contador "N de M eventos", menu Exportar. Data e hora em cada linha (o histórico passa de um dia) e o texto completo na dica ao passar o mouse.

## Medido (500 mil eventos, 165 MB, macOS 26.6, MacBook Air)

| Operação | Mediana |
|---|---|
| Primeira página (100 linhas) | 0,11 ms |
| Página 2000 (200 mil linhas adiante) | 0,14 ms |
| Evento novo no topo (consulta de cabeça) | 0,02 ms |
| Filtro por categoria, página 1 | 0,15 ms |
| Busca rara | 7 ms |
| Busca muito comum (45 mil resultados), página 1 | 43 ms |
| Contagem sem filtro / com busca comum | 4 ms / 45 ms |
| Gravar 1 evento (índice + FTS) | 0,07 ms (pior caso de 200: 125 ms, um checkpoint do WAL; por isso fora da thread principal) |
| Exportar os 500 mil para CSV (37 MB) | 4,6 s, em segundo plano |

Para referência, o uso real é de cerca de 360 eventos por dia, então esses volumes representam anos de uso. Antes da correção do cursor (`OR` em vez de tupla), a página 2000 levava 8,8 ms e a consulta de cabeça 22 ms.

## Alternativas

| Alternativa | Por que não |
|---|---|
| `LIKE '%texto%'` | Varre a tabela inteira a cada tecla; cresce com o histórico |
| Paginação por `OFFSET` | Custo cresce com a página e a lista "anda" quando entra evento novo |
| FTS5 com tokenizer padrão (palavras) | Não acha trechos ("spea"), que é como se busca log |
| Carregar tudo em memória e filtrar na UI | Memória e tempo de abertura crescem com o histórico |
| Exportar pelo `recentEvents` | Só 120 eventos, e não respeita busca nem filtro |
| Apagar eventos antigos automaticamente | O histórico pertence ao usuário; limpeza manual explícita em Ajustes evita perda inesperada de contexto (ver abaixo) |

## Limites e pontos em aberto

- **Sem retenção automática.** O banco cresce de forma previsível (~330 bytes por evento com ambos os índices). "Apagar histórico" em Ajustes é a forma explícita de limpeza; qualquer política de teto automático será tratada em ADR futura.
- **Busca de 1 e 2 letras** não existe (limite do trigram). Escolha deliberada: varrer a tabela por 2 letras custaria o que o índice evita.
- **A busca não ignora acentos** ("conexao" não acha "conexão").
- O arquivo exportado contém as mensagens como estão gravadas (nomes de dispositivos incluídos). Ele **não** passa pela sanitização do relatório de diagnóstico de Ajustes, que continua separado.
- A caixa de salvar do macOS (exportação) não foi acionada na UI por automação; o caminho de exportação é coberto pelos testes de unidade e pela medição acima.

## Evidência

- `TimbreCoreTests`: paginação sem repetir nem pular (1.500 eventos, vários com o mesmo `timestamp`), busca por trecho sem diferenciar maiúsculas, busca curta, aspas e SQL no campo, filtro e combinação, cabeça ao vivo, exportação CSV/JSON (conteúdo, escape, filtro, vazio, sem `.partial`), leitura concorrente com o gravador e limpeza do índice.
- Medição acima (500 mil eventos) e capturas reais da interface com histórico populado (sem filtro, busca "speak" e busca curta + categoria).
- `./scripts/ci_check.sh` verde.
