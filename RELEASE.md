# Secretariat Release Process

## Übersicht

Secretariat hat zwei verteilbare Komponenten:

| Komponente | Stack | Distribution |
|---|---|---|
| **Daemon + CLI** (`secd`/`sec`) | Rust | GitHub Release + Homebrew |
| **macOS App** (Secretariat.app) | Flutter | DMG via GitHub Release |

Der Rust-Teil wird automatisch via GitHub Actions gebaut.  
Die macOS App muss **auf einem Mac mit Developer ID Zertifikat** gebaut und signiert werden — also auf deinem MacBook Pro.

---

## Voraussetzungen

### Auf dem MacBook Pro (für Signing + Notarization)

```bash
# Xcode CLI Tools
xcode-select --install

# Rust (falls nicht installiert)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Flutter
# Von https://docs.flutter.dev/get-started/install/macos

# create-dmg (optional — für schönere DMGs)
brew install create-dmg

# GitHub CLI (für Releases)
brew install gh
gh auth login
```

### Apple Developer Account

- Developer ID Application Zertifikat im Schlüsselbund
- Notarytool konfigurieren:

```bash
xcrun notarytool store-credentials "SECRETARIAT" \
  --apple-id "deine@email.com" \
  --team-id "XXXXXXXXXX" \
  --password "app-specific-password"
```

---

## Release-Schritte

### 1. Version erhöhen

```bash
cd ~/secretariat

# Rust Workspace Version (secd + sec)
# In Cargo.toml die version hochsetzen (z.B. 0.2.0 → 0.3.0)

# Flutter App Version  
# In app/pubspec.yaml die version anpassen
```

### 2. Auf Mac Mini: GitHub Release (Rust Binaries)

Push den Tag — GitHub Actions baut automatisch und erstellt ein Draft-Release:

```bash
git tag -a v0.2.0 -m "Secretariat v0.2.0"
git push origin v0.2.0
```

→ https://github.com/moinsen-dev/secretariat/actions läuft automatisch  
→ Draft-Release unter https://github.com/moinsen-dev/secretariat/releases

### 3. Auf MacBook Pro: macOS App Release

```bash
git pull
cd ~/secretariat
```

**Variante A: Komplett (empfohlen)**
```bash
./scripts/build-release.sh --release
```
→ Baut universal, signiert, notarized, erstellt DMG

**Variante B: Schrittweise**
```bash
# Nur bauen
./scripts/build-release.sh --universal

# Dann signieren + notarizen + DMG
./scripts/build-release.sh --sign --notarize --dmg
```

### 4. DMG zum GitHub Release hochladen

```bash
# Release öffnen und DMG als Asset hinzufügen
open https://github.com/moinsen-dev/secretariat/releases

# Oder via gh CLI:
gh release upload v0.2.0 build/release/Secretariat.dmg
```

### 5. Release veröffentlichen

- Im GitHub Release auf "Edit" klicken
- Release Notes prüfen
- **Publish** klicken

---

## Homebrew

Nach dem Release die Homebrew Formulae aktualisieren:

```bash
cd ~/homebrew-tap
# SHA256 der neuen Binaries eintragen
# Version in Formula anpassen
git commit -m "secretariat v0.2.0"
git push
```

---

## Schnell-Checkliste

- [ ] Version in `Cargo.toml` + `pubspec.yaml` erhöht
- [ ] Tag gepusht → GitHub Actions Build läuft
- [ ] MacBook Pro: `git pull` + `./scripts/build-release.sh --release`
- [ ] DMG zum Release hochgeladen
- [ ] Homebrew Formulae aktualisiert
- [ ] Release published 🚀
