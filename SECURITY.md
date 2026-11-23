# Security Policy · timbr

O **timbr** processa áudio **100% localmente** no seu Mac, sem conta, sem nuvem e sem telemetria ([ADR-0008](docs/07-decisoes/ADR-0008-ia-propoe-dsp-decide.md), [Segurança & Privacidade](docs/04-engenharia/seguranca-privacidade-distribuicao.md)).

## Escopo de segurança

Relatos de segurança são especialmente bem-vindos para:

- **IPC local das extensões de navegador** (`127.0.0.1:48192`): validação de token efêmero e `Origin`.
- **Parsers de entrada não confiável**: importação EqualizerAPO `.txt`, presets JSON e perfis AutoEq (limites de tamanho, finitude numérica, memória).
- **Motor DSP C++20 (`Sources/CTimbreDSP`)**: segurança de memória (ASan/UBSan) e tempo real.
- **Mudo à prova de falha (`timbr-mute-keeper`)** e isolamento de permissões macOS (TCC).
- **Exportação de diagnósticos e linha do tempo**: garantias de que nenhum áudio bruto ou dado sensível vaze.

## Como reportar uma vulnerabilidade

Por favor, **não** abra uma issue pública para vulnerabilidades exploráveis.

Envie um relato direto para **vinicius@v1torres.dev** com:

1. Descrição clara do problema e impacto esperado.
2. Passos mínimos para reprodução (ou PoC).
3. Versão do `timbr` (ou commit SHA) e versão do macOS.

Você também pode usar o recurso **Private vulnerability reporting** do GitHub na aba **Security** deste repositório, se habilitado.

## Política de tratamento

- Confirmação de recebimento assim que possível.
- Correção priorizada e publicada em PR/release com atribuição opcional ao pesquisador (mediante consentimento).
