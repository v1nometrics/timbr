# ADR-0015 · Tipografia de sistema (SF Pro / SF Mono / New York) no app nativo

- **Status:** Aceito · 2026-11-21
- **Substitui:** a escolha de Geist no app nativo (design system v1)

## Contexto

A v1 do design system especificava Geist (herança do Órbita). O gerador de tokens emitia `Font.custom("Geist-Regular")`, mas **nenhum arquivo de fonte foi empacotado no app** (`Resources/` só tinha o `.icns`) e a Geist não está instalada no sistema. Resultado verificado em 2026-11-21: todo o app renderizava na fonte de fallback, e os valores de tracking e caixa alta dos tokens **nunca eram aplicados** (o campo existia, mas nenhum modificador o usava). O dono pediu estética Apple como direção de arte.

## Decisão

- No app: **SF Pro** (texto e números), **SF Mono** (eyebrows, valores técnicos) e **New York** (letras), via `Font.system(size:weight:design:)`, com optical sizes automáticos.
- Os tokens passam a ser aplicados por `.type(spec)`, que aplica fonte, tracking por tamanho, entrelinha e caixa.
- Na web (docs, playground, site), a pilha CSS começa em `SF Pro / -apple-system` e cai para Geist fora do ecossistema Apple.

## Alternativas

| Alternativa | Por que não |
|---|---|
| Empacotar Geist (OFL) no app | Possível, mas afasta da direção Apple; os arquivos disponíveis eram `.woff2`, que exigiriam conversão; perde optical sizes |
| Manter como estava | Era uma especificação que não se cumpria |

## Consequências

O DNA do Órbita (eyebrows em mono maiúsculo com tracking, números grandes tabulares, hierarquia editorial) é preservado com as fontes do sistema. O app fica coerente com o macOS e com a Dynamic Island.
