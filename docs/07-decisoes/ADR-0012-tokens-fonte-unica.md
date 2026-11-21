# ADR-0012 · Tokens de design em fonte única

- **Status:** Aceito · 2026-11-21

## Decisão

- Os tokens vivem em `design-system/tokens/*.json` no formato W3C Design Tokens (DTCG).
- Um gerador (Style Dictionary ou script próprio) produz: `TimbreTokens.swift` (Color, Font, Spacing, Radius, Motion como `Animation`/`Spring`), `tokens.css` (variáveis CSS para docs, playground e site) e a tabela de referência dos docs.
- Nenhuma cor, tamanho, raio ou curva de animação é escrita "na mão" no código do app; lint no CI rejeita literais fora do módulo de tokens.

## Motivo

App nativo e superfícies web (docs, playground, site) precisam ser visualmente idênticos; o design system é tratado como "bíblia" e precisa de uma fonte de verdade executável.
