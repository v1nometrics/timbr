# Packaging · `timbr`

## Instalação local (primeira abertura)

```bash
./scripts/build_app.sh
./scripts/install_local.sh --reset-onboarding
```

Copia `dist/Timbr.app` para `/Applications`, remove quarentena (`xattr -cr`) e abre o app. Com `--reset-onboarding`, a janela de boas-vindas (RF-1401) aparece de novo.

## DMG local (ad-hoc)

```bash
./scripts/build_app.sh
./scripts/build_dmg.sh
hdiutil verify dist/Timbr.dmg
```

## Gate G3 · Developer ID + Notarização

Requer certificado **Developer ID Application** na Keychain e um perfil `notarytool`:

```bash
xcrun notarytool store-credentials "timbr-notary" \
  --apple-id "…" --team-id "…" --password "app-specific-password"

DEVELOPER_ID="Developer ID Application: … (TEAMID)" \
NOTARY_PROFILE="timbr-notary" \
  ./scripts/build_dmg.sh
```

O script assina o `.app` com Hardened Runtime, submete o DMG, staplea e valida.

## Homebrew Cask

Template em [`Homebrew/timbr.rb`](Homebrew/timbr.rb). Em cada release tagada, substituir `sha256 :no_check` pelo SHA-256 do `Timbr.dmg` publicado.

## Publicação automatizada com Apple Developer ID

O workflow **Release** compila apenas o commit da `main`. Enquanto `TIMBR_SIGNED_BUILDS` não estiver habilitado, cada push na `main` publica automaticamente uma **pré-lançamento beta (`--prerelease`)** e atualiza o manifesto do canal `beta` (sem marcar como `Latest`). Quando `TIMBR_SIGNED_BUILDS=true` estiver configurado (antes de `TIMBR_PUBLIC_RELEASES=true`) ou em execuções `staging`, entrega apenas o artefato de validação no GitHub Actions. Para validar uma build assinada, configure:

| Tipo | Nome | Valor |
|---|---|---|
| Variável | `TIMBR_APPLE_TEAM_ID` | Team ID Apple de 10 caracteres |
| Segredo | `TIMBR_DEVELOPER_ID_P12` | PKCS#12 do certificado Developer ID Application e sua chave privada, em Base64 |
| Segredo | `TIMBR_DEVELOPER_ID_PASSWORD` | Senha do PKCS#12 |
| Segredo | `TIMBR_NOTARY_KEY` | Chave de equipe `.p8` do App Store Connect em Base64 |
| Segredo | `TIMBR_NOTARY_KEY_ID` | ID da chave de equipe |
| Segredo | `TIMBR_NOTARY_ISSUER` | Issuer ID do App Store Connect |
| Variável | `TIMBR_SIGNED_BUILDS` | `true` depois de configurar a assinatura |
| Variável | `TIMBR_PUBLIC_RELEASES` | `true` só depois da validação abaixo |

Inclua a cadeia de assinatura necessária ao certificado conforme a [documentação da Apple](https://developer.apple.com/documentation/xcode/creating-distribution-signed-code-for-the-mac/). Guarde os valores no GitHub Secrets. O runner usa Keychain temporária e fixa o time no requisito de assinatura. O script assina o helper e o app, aplica Hardened Runtime, notariza e anexa tickets ao app e ao DMG. Qualquer falha de assinatura, notarização ou avaliação Gatekeeper impede a publicação.

### Aceite antes de habilitar a publicação

1. Rode **Release** em modo `staging` em dois commits de build distintos da `main`, com o mesmo Team ID. Guarde os dois artefatos.
2. Em um perfil macOS limpo, baixe o primeiro DMG pelo navegador, copie o app para Aplicativos e abra. Verifique Gatekeeper, os destinos dos botões de permissão, o mixer e as teclas. Repita em macOS 15 e na versão atual do macOS.
3. Conceda áudio e Acessibilidade, personalize o app e crie eventos. Valide a troca pela UI com duas builds de validação. Use um repositório separado para o feed de teste. Nas builds de validação desse repositório, configure `UpdatePolicy.repositorySlug` e `defaultManifestURL` para que o atualizador use exclusivamente os assets de teste. Reabra e confirme a mesma identidade, as permissões e o controle de volume e brilho, além das preferências e do histórico. Teste também a transição de uma beta com assinatura diferente, que exige uma instalação manual guiada.
4. Depois do aceite, configure `TIMBR_PUBLIC_RELEASES=true` e execute o workflow com `staging=false`. Confirme código do commit, SHA-256 do DMG e manifesto públicos. O link final é o da página da versão notarizada no GitHub Releases.
