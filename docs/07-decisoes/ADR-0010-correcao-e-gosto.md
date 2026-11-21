# ADR-0010 · Correção e Gosto em camadas separadas

- **Status:** Aceito · 2026-11-21

## Contexto

A ciência de preferência (Olive & Welti, Harman) mostra que a maioria dos ouvintes prefere um alvo próximo ao Harman e que as diferenças individuais se concentram em poucos eixos: nível de graves e inclinação dos agudos. Misturar a correção objetiva de um fone com o gosto pessoal impede trocar de fone mantendo o gosto, e impede auditar o que é "medido" versus "preferido".

## Decisão

A cadeia de EQ de um destino é sempre:

```
Fonte → [EQ por app, opcional] → Soma → Correção (fone + alvo) → Gosto (usuário) → Proteções (limiter) → Saída
```

- **Correção:** derivada de medição (AutoEq ou medição própria) contra um alvo escolhido. Atrelada ao modelo de fone. Editável só como "trocar alvo/fonte" ou "reotimizar".
- **Gosto:** poucos controles semânticos por padrão (graves, agudos, presença, tilt) e PEQ livre no modo avançado. Atrelado ao usuário, e opcionalmente ao contexto. Viaja entre fones.
- O preamp é calculado sobre a resposta **somada** das duas camadas.
- A UI sempre mostra as três curvas: Correção, Gosto e Resultado.
