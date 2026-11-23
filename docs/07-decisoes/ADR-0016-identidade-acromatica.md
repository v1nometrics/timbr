# ADR-0016 · Identidade acromática: sem acento de matiz

- **Status:** Aceito · 2026-11-22 (decisão do dono do produto)
- **Substitui:** a linha "Uso de Cor" da ADR-0014 (1 acento violeta) e a lei L3 da v2.x do design system ("violeta só para o sinal")

## Contexto

O design system herdou do Órbita / ronda diária a estrutura acromática e um único acento violeta, que no timbr. marcava o sinal processado: a curva de resultado, o espectro, o estado "processando", o ponto da marca e o ponto do ícone. O dono pediu para tirar do timbr. qualquer obrigação com o roxo: "a Órbita é perfeita, mas ignore o roxo dela".

## Decisão

- **Nenhuma matiz faz parte da identidade.** A marca, o ícone, o notch, a barra de menus e o Estúdio são só tinta e papel: preto, branco e cinzas quentes de croma zero.
- **A ênfase é feita por tinta, peso e espessura, não por cor.** Os tokens `accent.*` continuam existindo como papéis ("ênfase", "sinal", "controle ligado"), para o código não precisar mudar, mas agora apontam para a tinta da superfície: `#111111` no claro, `#F3F3F1` no escuro, `#FFFFFF` no notch.
- **A hierarquia do sinal sem cor:** resultado = linha sólida de 2 pt em tinta primária com área de 5–7%; correção = tracejado em tinta secundária; gosto = linha fina em tinta esmaecida. No espectro, área em degradê de tinta. "Processando" = ponto em tinta primária; desligado = tinta esmaecida.
- **Cor só com significado semântico, e nunca como marca:** verde = caminho nativo / bit-perfect / concedido; âmbar = aviso (boost, volume em software, Guardião); vermelho = destrutivo / crítico; azul = informativo. Nenhuma delas aparece em repouso.
- **Ícone do app:** ~~monólito `#141414` com as barras da onda e o ponto final~~ substituído pela [ADR-0022](ADR-0022-icone-do-app-notch-e-som.md) (notch + som, papel quente, ainda sem cor).

## Alternativas

| Alternativa | Por que não |
|---|---|
| Trocar o violeta por outra matiz (azul, verde, laranja) | Mantém a obrigação de uma cor de marca, que o dono não quer; e o verde e o âmbar já têm significado semântico |
| Permitir que o usuário escolha um acento | Pode vir depois como personalização, com ADR própria; não pode ser a identidade |
| Remover os tokens `accent.*` | Força uma refatoração ampla sem ganho visual; o papel "ênfase" continua útil |

## Trade-offs

- **Perde-se** a distinção instantânea "violeta = áudio processado". **Compensa-se** com espessura (2 pt contra 1 pt), estilo da linha (sólida contra tracejada) e legenda.
- O notch fica 100% branco sobre preto, o que combina com o hardware e com o modo escuro da Dynamic Island.

## Evidência

- Tokens regenerados sem nenhum valor violeta (`grep` por `6B46FF`, `A08BFF` e `A592FF` em `design-system/generated` dá zero).
- `Resources/Timbr.icns` regenerado com o ponto branco.

## Consequências

- Leis L3 e o checklist da bíblia foram reescritos. Docs 01, 03, 04 e 05 do design system foram atualizados.
- Notas de pesquisa antigas (`docs/00-pesquisa/…`) continuam citando o violeta do Órbita como registro histórico. Os "pontos roxos" citados na pesquisa de captura são o **indicador de gravação do macOS**, não a nossa marca.

## Condição de revisão

Só volta a existir uma matiz de marca com uma nova ADR aprovada pelo dono.
