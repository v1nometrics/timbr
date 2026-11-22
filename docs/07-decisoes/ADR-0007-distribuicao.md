# ADR-0007 · Distribuição

- **Status:** Aceito · 2026-11-21

## Decisão

- **Developer ID + Hardened Runtime + notarização** (`notarytool`, `stapler`) em todo release.
- **Atualizações por Sparkle 2** com feed assinado (EdDSA) e appcast em HTTPS; canais `stable` e `beta`.
- **Homebrew cask** oficial no primeiro release público.
- **Sem Mac App Store** para o produto completo (Acessibilidade para teclas de mídia, helper do MediaRemote, Automation, possíveis protocolos Bluetooth). Uma versão "lite" é investigada em E-17, pós-MVP.
- Builds reproduzíveis no CI, SBOM gerado por release, dependências fixadas por hash.

## Motivo

É o caminho de todos os utilitários de áudio sérios (FineTune, SoundSource) e evita o atrito de apps não notarizados (boring.notch obriga `xattr`).

## Consequências

Exige conta Apple Developer paga (US$ 99/ano) antes do primeiro release público. Até lá, builds de desenvolvimento são assinados localmente; taps exigem identidade de assinatura estável para o prompt de permissão aparecer.

## Nota 2026-11-22 · Assinatura em desenvolvimento

Até existir Developer ID, os builds locais são assinados por `scripts/setup_dev_signing.sh` + `build_app.sh`, com uma identidade autoassinada ("timbr Local Signing") num keychain próprio. Motivo (Comprovado): o TCC prende Acessibilidade ao requisito designado do app. Com ad-hoc, esse requisito é o `cdhash`, que muda a cada build, e a permissão deixava de valer em silêncio. Com a identidade local, o requisito passa a `identifier "com.timbr.app" and certificate leaf = H"…"` e se mantém entre builds. Isso não substitui a notarização: só vale nesta máquina.
