# Release 1.12.0 (2026-10-29)

Inhalt: Eintrag aus Screenshot, nur auf dem Mac gelesen (Vision-Texterkennung, Apple Foundation Models on-device; ohne Modell Texterkennung plus Präfix-Heuristik), Kommit 4f322af; überarbeitete Website (Abschnitt „Capture“, neue App-Bilder), 9d130ed. Prüfungen: `docs/t023-evidence.md`, unabhängige Kritik `docs/review-plan-uc18.md` und `docs/review-uc18.md`, `docs/regression-t023.md`.

| Schritt | Beobachtung |
|---|---|
| Version | `Info.plist` 1.12.0 (Build 27), `Launcher.version` 1.12.0; vorher `main` (1.11.0) eingeführt, `xcrun swift test` 70/70 |
| Release-Build | `secretariat run werkzeuge -- script/release.sh` auf 5663ea0: Notarisierung `Accepted` (360c8a5b…), gestapelt, `spctl` accepted („Notarized Developer ID“); `dist/Secretariat-1.12.0.zip` (SHA-256 58ee9dd8…), `appcast.xml` sparkle:version 27 |
| Installation lokal | `script/install.sh`, `--version` 1.12.0, `spctl` und `codesign --verify --deep --strict` ok, normal gestartet: Fenster „All Items – 223 items“; `screenshots` → „0 screenshots (icloud)“ |
| Website | Pages `secretariat`, Deployment 4e260f33 (Production, main): `site/` + `Secretariat-1.12.0.zip` + `Secretariat-1.11.0.zip` + `Secretariat-latest.zip` (= 1.12.0) + `appcast.xml`. Live per URLSession: Feed 1.12.0, `Secretariat-latest.zip` und `Secretariat-1.12.0.zip` byte-gleich (58ee9dd8…), Startseite mit Abschnitt „Capture“ und neuem App-Bild |
| Verteilung | `mesh deliver`: M1 und Mac Mini „delivered secretariat“; per SSH dort `--version` 1.12.0, `codesign --verify --strict` ok, 223 Einträge; M5 offline, folgt beim nächsten Lauf |

Nicht geprüft: Sparkle-Update einer laufenden 1.11.0 auf 1.12.0 über den Update-Dialog (Feed und Signatur liegen vor); „Create Item …“ mit der installierten Release-App (geprüft mit dem gleichen Code als signiertes Paket im Test-Tresor).
