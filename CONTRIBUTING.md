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

## Preparar a máquina (uma vez)

Requisitos: Mac com Apple Silicon, macOS 15 ou mais novo (o app usa APIs do macOS 26 quando disponíveis), Command Line Tools da Apple. Xcode é opcional.

```bash
git clone https://github.com/v1nometrics/timbr.git && cd timbr
./scripts/setup_dev_signing.sh   # identidade de assinatura local estável (ver abaixo)
./scripts/install_local.sh       # compila, instala em /Applications e abre
```

**Por que `setup_dev_signing.sh`:** o macOS (TCC) prende permissões como Acessibilidade à assinatura do app. Com assinatura ad-hoc, cada build tem outra assinatura e a permissão deixa de valer sem aviso: as teclas de volume e brilho voltam para o HUD do sistema. O script cria um certificado local num keychain próprio, com senha aleatória fora do repositório. Builds de distribuição usam Developer ID (`scripts/build_dmg.sh`).

No primeiro uso, conceda no app: **Gravação de áudio do sistema** (volume por app e EQ) e **Acessibilidade** (teclas de volume e brilho no notch e medição do espaço livre na barra de menus).

## Fluxo de trabalho

1. Crie um branch a partir do `main` (`nome/assunto`) e abra um PR para o `main`.
2. Antes do PR:
   - `./scripts/ci_check.sh` (tokens, extensões, licenças, trava de design, build, testes C++ com ASan/UBSan, núcleo, motor, smoke, 20× `kill -9`);
   - mexeu no caminho de áudio? `./scripts/selftest_audio.sh` (mede o ganho real no app instalado; toca bipes por ~30 s);
   - mexeu na interface? anexe capturas, com as flags de revisão (`--studio`, `--notch`, `--demo`; ver o README).
3. O CI do GitHub roda **Swift 6.1** (Xcode 16.4), mais rígido que o Swift 6.3 local com isolamento de concorrência. Espere o check verde antes de mesclar.
4. Atualize `docs/08-registro/progresso.md` com o que mudou e como foi verificado. Decisão de arquitetura vira ADR; descoberta vira entrada em `descobertas.md`.

## Regras de Engenharia & Design

1. Leia [`AGENTS.md`](AGENTS.md) e [`docs/05-design-system/00-biblia-do-design-system.md`](docs/05-design-system/00-biblia-do-design-system.md).
2. Zero alocações, zero locks e zero Objective-C/Swift ARC na thread de áudio (`Sources/CTimbreDSP`, `TapRenderer`). Parâmetros chegam ao áudio pelo buffer triplo (`timbre_dsp_update`).
3. Todo texto visível ao usuário deve existir em **`pt-BR`**, **`es`** e **`en`** (`Sources/TimbreCore/LocalizationUI.swift`; o teste de paridade reprova chave faltando).
4. Nenhum controle padrão do sistema nas superfícies do produto e nenhuma cor de marca: a etapa 3b do CI reprova.
5. Nunca invente resultado de teste ou medição. Use as classes de evidência do `AGENTS.md`.
