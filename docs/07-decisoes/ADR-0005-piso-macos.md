# ADR-0005 · Versão mínima do macOS

- **Status:** Proposto · decide em E-02
- **Data:** 2026-11-21

## Contexto

Taps existem desde o 14.2, mas a prática recomenda 14.4+ (categorias de TCC mudaram). O macOS 26 traz `bundleIDs` e `isProcessRestoreEnabled` (taps por bundle ID que se restauram quando o app reinicia), que podem eliminar o estouro inicial, além do Foundation Models on-device. Em nov/2026 as versões correntes são 26 (Tahoe) e 27 (Golden Gate).

## Opções

| Piso | Alcance | Custo |
|---|---|---|
| 14.4 | Máximo | Dois caminhos de captura; testes em 3 versões maiores |
| **15 (proposto)** | Bom | Ainda exige caminho sem `bundleIDs` |
| 26 | Menor | Um caminho só; Foundation Models garantido |

## Decisão proposta

**Piso no macOS 15**, com recursos do 26 ativados por disponibilidade (`if #available`). Se E-02 mostrar que sem `bundleIDs` o estouro inicial não tem mitigação aceitável, o piso sobe para 26.

## Observação

O público-alvo (audiófilo com MacBook de notch, 2021+) atualiza o sistema com frequência; o custo de suportar o 14 dificilmente se paga.
