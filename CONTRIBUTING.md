# Contributing to timbr.

Obrigado por contribuir com o **timbr.** (*Sound, precisely yours.*).

## Licença e DCO (`Signed-off-by`)

Este projeto é distribuído sob **Mozilla Public License 2.0 (`MPL-2.0`)** ([LICENSE](LICENSE), [ADR-0001](docs/07-decisoes/ADR-0001-licenca.md)).

Todo commit exige o **Developer Certificate of Origin (`DCO`)** usando `git commit -s`:

```
Signed-off-by: Seu Nome <seu@email.com>
```

## Isolamento de Licenças (GPL / AGPL)

- **Nunca copie ou adapte trechos de código de projetos GPL/AGPL** (ex.: `FineTune`, `boring.notch`, `Atoll`, `BackgroundMusic`, `eqMac`) para este repositório.
- Estudo de arquitetura e comportamento em projetos GPL é permitido desde que a implementação seja escrita do zero e a referência estudada seja documentada na descrição do PR.
- Dependências externas permitidas: MIT, BSD-2/3, Apache-2.0, Zlib, ISC, OFL (fontes), MPL-2.0.

## Regras de Engenharia & Design

1. Leia [`AGENTS.md`](AGENTS.md) e [`docs/05-design-system/00-biblia-do-design-system.md`](docs/05-design-system/00-biblia-do-design-system.md).
2. Zero alocações, zero locks e zero Objective-C/Swift ARC na thread de áudio (`Sources/CTimbreDSP`).
3. Todo texto visível ao usuário deve existir em **`pt-BR`**, **`es`** e **`en`**.
4. Rode `./scripts/ci_check.sh` antes de abrir um PR.
