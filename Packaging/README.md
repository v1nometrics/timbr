# Packaging · `timbr.`

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
