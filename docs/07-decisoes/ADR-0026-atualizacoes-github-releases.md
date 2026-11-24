# ADR-0026 — Atualizações oficiais automáticas via GitHub Releases (sem telemetria)

- **Status:** Aceito
- **Data:** 2026-11-24
- **Relacionado:** [ADR-0007](ADR-0007-distribuicao.md), [ADR-0017](ADR-0017-mudo-a-prova-de-falha.md), [ADR-0024](ADR-0024-feedback-por-email-local.md), P3 (*Nunca deixar rastro*), P7 (*Local primeiro, privado por padrão*), L10 (*Calma*)

---

## Contexto

O [ADR-0007](ADR-0007-distribuicao.md) define a trilha de distribuição definitiva com `Developer ID` + notarização Apple + Sparkle 2 + Homebrew cask. Enquanto a conta Apple Developer não está configurada, o repositório ainda precisa entregar uma experiência real de atualização sempre que código do app entra em `main`:

1. Toda mudança no aplicativo mesclada em `main` deve gerar, validar e publicar automaticamente uma release oficial em `v1nometrics/timbr` — sem depender de empacotamento manual e sem disparar releases inúteis para alterações apenas de documentação.
2. Todo usuário com o `timbr` instalado deve ser avisado de forma calma (sem interromper áudio nem acordar o notch sozinho) e poder baixar, verificar e instalar a atualização de dentro do app.
3. O mecanismo não pode violar P7: zero telemetria, zero identificadores de usuário ou máquina, zero cookies, e opção de desligar a verificação automática em um clique.

## Decisão

1. **Versionamento semântico + número de build monotônico:**
   - A raiz do repositório mantém o arquivo [`VERSION`](../../VERSION) (inicialmente `0.1.0`) para `CFBundleShortVersionString`.
   - `scripts/build_app.sh` injeta `CFBundleVersion` com o número monotônico de commits em `main` (`git rev-list --count HEAD`, sobrescrevível via `TIMBR_BUILD_NUMBER`) e `TimbrCommitSHA`.
   - Cada release automática na `main` recebe a tag `v<VERSION>-b<BUILD>` (ex.: `v0.1.0-b86`).

2. **Publicação automática na `main` (`.github/workflows/release.yml`):**
   - Dispara em `push` para `main` filtrado a caminhos que afetam o aplicativo (`VERSION`, `Package.swift`, `Sources/**`, `Resources/**`, `design-system/**`, scripts de build) e via `workflow_dispatch`.
   - Executa a suíte completa `./scripts/ci_check.sh` antes de empacotar qualquer artefato.
   - Gera `Timbr.dmg`, `Timbr.dmg.sha256` e `update-manifest.json` (`schemaVersion: 1`), publica na GitHub Release marcada como `--latest` e valida o `update-manifest.json` ao vivo no CDN antes de concluir.

3. **Manifesto estático no CDN (zero rate-limit, zero telemetria):**
   - O app consulta exclusivamente `https://github.com/v1nometrics/timbr/releases/latest/download/update-manifest.json` via `URLSessionConfiguration.ephemeral` sem cookies (`httpCookieStorage = nil`), sem cache em disco e sem identificadores.
   - Evita a API REST do GitHub (60 req/h por IP), eliminando falhas em redes corporativas/NAT.
   - Verificação automática (ligada por padrão, desligável em **Ajustes → Atualizações**): aguarda 12 s após abrir o app e repete a cada 4 h. Nunca dispara em instâncias auxiliares (`--smoke-check`, `--selftest-*`, `--studio`, `--notch`, `--demo`, etc.).

4. **Política fail-closed (`TimbreCore/UpdateChecker.swift`) e instalador verificado (`TimbreApp/AppUpdater.swift`):**
   - Só aceita `schemaVersion == 1`, URLs `https://github.com/v1nometrics/timbr/releases/...`, SHA-256 exato de 64 caracteres hexadecimais, piso `minimumMacOS` satisfeito e versão/build estritamente superior (nunca faz downgrade).
   - Antes de instalar, baixa o DMG em streaming com limite máximo de 150 MB, confere **SHA-256**, monta somente leitura (`hdiutil attach -nobrowse -readonly`), valida `CFBundleIdentifier == com.timbr.app`, `CFBundleExecutable == Timbr` e `codesign --verify --deep --strict`.
   - Quando o app está instalado em `/Applications` ou `~/Applications` com permissão de escrita, faz cópia de staging no mesmo volume e troca atômica via script `/bin/sh` com backup de rollback (`.timbr-prev`), limpa quarentena do bundle já verificado e reinicia o app. Apps mudos continuam mudos durante a reinicialização graças ao `timbr-mute-keeper` ([ADR-0017](ADR-0017-mudo-a-prova-de-falha.md)).
   - Quando executado fora de `/Applications` (ex.: `dist/Timbr.app` em desenvolvimento ou volume somente leitura), nunca sobrescreve o checkout: salva o DMG verificado em `~/Downloads` e o abre no Finder.

5. **Superfícies calmas (L10):**
   - Nunca abre nem acorda o notch sozinho.
   - Exibe ponto discreto em **Ajustes** na barra lateral do Estúdio, faixa dispensável no topo do Estúdio com barra de progresso e ações (*Atualizar e reiniciar*, *Ver novidades*, *Ignorar versão*), grupo dedicado **05 Atualizações** em Ajustes, item no menu de contexto do notch, pílula sutil no rodapé do notch expandido e linha discreta no painel da barra de menus.

## Consequências e honestidade sobre assinatura

- **Positivo:** qualquer mudança aprovada e mesclada em `main` chega a todos os usuários em minutos, com verificação criptográfica de integridade (HTTPS + SHA-256 + `codesign`) e sem servidor próprio nem telemetria.
- **Limitação transitória (honesta):** enquanto as compilações do GitHub Actions usarem assinatura **ad-hoc** (sem `Developer ID` + notarização Apple do [ADR-0007](ADR-0007-distribuicao.md)), o `cdhash` muda a cada release e o macOS pode pedir reconfirmação das permissões TCC (Gravação de áudio do sistema / Acessibilidade) após atualizar. A interface informa isso explicitamente.
- **Caminho de evolução:** ao habilitar `DEVELOPER_ID` e `NOTARY_PROFILE` no workflow de release (ou migrar o transporte para Sparkle 2 com EdDSA), o mesmo pipeline de build/versionamento/manifesto e os mesmos testes de política continuam válidos.

### 2026-11-24 · Identidade de assinatura e HUD

Na build pública 89, o macOS deixou de reconhecer a autorização de Acessibilidade após a troca da assinatura local por uma assinatura ad hoc. O atualizador agora só troca o bundle automaticamente quando o candidato satisfaz o requisito de assinatura do app instalado. Caso contrário, entrega o DMG verificado para instalação manual. Preservar a autorização entre diferentes builds públicas requer uma identidade de distribuição estável. Ao perder a autorização, o app encerra o monitor de teclas. Com autorização válida, ele recria o monitor se ficar inválido ou desabilitado.

### 2026-11-24 · Preparação para distribuição notarizada

A trilha pública passa a exigir Developer ID Application do time configurado e tickets de notarização válidos para app e DMG. Builds de validação ficam nos artefatos do Actions até que a distribuição seja habilitada. O pacote público tem um manifesto imutável por versão. O fallback manual mostra os passos e deixa a pessoa decidir quando abrir o DMG. A instalação automática preserva a identidade, mantém a quarentena do macOS e restaura o app anterior se o comando de abertura falhar. A abertura aceita pelo LaunchServices não substitui um teste de relançamento funcional.

O [guia de instalação](../instalacao.md) reúne os passos para o usuário. O [procedimento de publicação](../../Packaging/README.md) especifica a validação com dois builds assinados e perfis limpos. A credencial Apple ainda não foi configurada e o aceite de distribuição está pendente.

### 2026-11-24 · Canal automático de pré-lançamento beta (`ad-hoc-beta`)

Enquanto `TIMBR_SIGNED_BUILDS` / `TIMBR_PUBLIC_RELEASES` não estão habilitados com certificado Apple Developer ID, cada merge na `main` publica uma **pré-lançamento** (`--prerelease`, `distribution: "ad-hoc-beta"`) com `Timbr.dmg`, `Timbr.dmg.sha256` e `update-manifest.json`, além de atualizar o manifesto do canal `beta` (`releases/download/beta/update-manifest.json`). Cópias instaladas sem assinatura Apple (`!anchor apple generic`) consultam ambos os canais (`Latest` e `beta`), preferindo a versão mais nova (com empate para o canal oficial); cópias assinadas com Developer ID consultam exclusivamente `/releases/latest/download/update-manifest.json` e nunca regridem para betas ad-hoc.
