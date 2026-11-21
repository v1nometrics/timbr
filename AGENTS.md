# Instruções para agentes e futuras sessões

Este repositório é a **fonte de verdade** do projeto **`timbr.`** *(codinome de repositório: Timbre · ver [ADR-0014](docs/07-decisoes/ADR-0014-nome-identidade-e-i18n.md))*: uma plataforma de controle de áudio para macOS (`PT / ES / EN` na v1) cuja interface principal é o notch do MacBook. Qualquer sessão de trabalho deve conseguir continuar daqui sem depender da memória de conversas anteriores.

## Antes de começar qualquer tarefa

1. Leia `README.md` (mapa do repositório e estado atual).
2. Leia `docs/08-registro/progresso.md` (o que foi feito, o que está em andamento, próximo passo).
3. Leia os ADRs aceitos em `docs/07-decisoes/`. Um ADR "Proposto" ainda não vale como decisão.
4. Para qualquer tarefa de interface, leia `docs/05-design-system/` inteiro. O design system é lei, não sugestão.

## Regras de evidência (valem para código, docs e mensagens de commit)

Toda afirmação técnica relevante recebe uma das classes abaixo:

| Classe | Significado | Exemplo de fonte |
|---|---|---|
| **Comprovado** | Verificado por nós (teste, medição, código auditado e executado) ou por documentação oficial explícita | Header do SDK, doc da Apple, teste do nosso repositório |
| **Provável** | Várias fontes independentes concordam, sem verificação nossa | Dois projetos open source com o mesmo comportamento |
| **Hipótese** | Inferência plausível, ainda não testada | "O tap com ganho 1.0 é bit-transparente" |
| **Desconhecido** | Não sabemos e precisamos descobrir | Política da App Review para EQ via taps |

- Nunca invente resultado de benchmark, teste ou medição. Se não foi executado, escreva "não medido".
- Métrica inferida nunca é exibida (nem na UI, nem nos docs) como medição.
- Ao promover uma hipótese a comprovada, registre em `docs/08-registro/hipoteses.md` como foi provada (teste, data, commit).

## Regras de trabalho

- Toda decisão de arquitetura relevante vira ADR (`docs/07-decisoes/ADR-XXXX-*.md`) com contexto, alternativas, trade-offs, evidência e status.
- Ao terminar uma sessão, atualize `docs/08-registro/progresso.md` (data, o que mudou, próximo passo).
- Ao descobrir algo novo (bug do macOS, limitação, projeto útil), registre em `docs/08-registro/descobertas.md`.
- Não copie código de projetos GPL/AGPL enquanto o ADR-0001 (licença) não estiver aceito. Estudar é permitido; copiar não.
- Não execute comandos que escrevam em dispositivos Bluetooth (firmware, pareamento, configurações persistentes) fora dos experimentos aprovados em `docs/06-plano/plano-de-experimentos.md`.
- Idioma da documentação: português do Brasil. Identificadores técnicos, nomes de API e de repositórios ficam no original.
