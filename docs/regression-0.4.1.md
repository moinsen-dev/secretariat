# Regression 0.4.1 (Build 0d4aefd)

Geänderte gemeinsame Dateien: Storage.swift (Umbenennen schreibt Etikett, Abgleich übernimmt Umbenennungen), AgentProfiles.swift, AgentIntegration.swift, Launcher.swift, Info.plist 0.4.1/5.

| Prüfung | Beobachtung |
|---|---|
| build | `swift build`, `script/build.sh` grün, Developer-ID-signiert mit eingebettetem Profil |
| unit | 32/32 grün (neu: Umbenennen und Abgleich über zweite Konfiguration; CLI-Umbenennen mit Fehlercodes) |
| macos | Installierte App startet normal (Fenster „Secretariat“); `check menulens-worker` ok nach Umbenennung |
| inspection | Signatur gültig, `--version` 0.4.1 auf M4, Mini, M1; M5 nicht erreichbar (offline), bleibt auf 0.4.0 |

Grenze: Die bestehende Namenskonflikt-Logik für neue Schlüssel ist unverändert; ein Umbenennen mit Konflikt behält auf dem Ziel-Mac den lokalen Namen.
