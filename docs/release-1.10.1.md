# Release 1.10.1 (2026-10-29)

Inhalt: Zwischenablage-Eingang und Hauptfenster in drei Spalten (3e5ce0a), Eintrags-Dialog (a56bad3), Neuladen beim Aktivieren und ⌘R (051679f), Erfassung bleibt ohne übernommenen Wert im Eingang (30cbcd5). Prüfungen: `docs/regression-1.10.md`, `docs/t021-evidence.md`, unabhängige Kritik `docs/review-uc16.md`.

| Schritt | Beobachtung |
|---|---|
| Version | `Info.plist` 1.10.1 (Build 25), `Launcher.version` 1.10.1 |
| Release-Build | `secretariat run werkzeuge -- script/release.sh`: Developer-ID-signiert, Notarisierung `Accepted`, gestapelt; `spctl`: accepted, „Notarized Developer ID“; `dist/Secretariat-1.10.1.zip` (SHA-256 5eda71a0…), `dist/appcast.xml` (sparkle:version 25) |
| Installation lokal | `script/install.sh` → `~/Applications/Secretariat.app`, `~/bin/secretariat --version` 1.10.1, `spctl` accepted; normal per `open` gestartet: Fenster „All Items – 222 items“, Menü View enthält „Reload“; keine LaunchAgents |
| Installer-Fehler behoben | `install.py` kopierte das Bundle mit `shutil.copytree` ohne `symlinks=True`; seit Sparkle (1.10.0) brach dadurch die Signatur von `Sparkle.framework` („bundle format is ambiguous“), die Installation brach vor dem Austausch ab (alte App unberührt). Jetzt `symlinks=True` |
| Website | Pages-Projekt `secretariat` (Direct Upload), Inhalt `site/` + `Secretariat-1.10.1.zip` + `Secretariat-1.10.0.zip` + `Secretariat-latest.zip` (= 1.10.1) + `appcast.xml`; Deployment ca35a16d. Live: `appcast.xml` meldet 1.10.1, `Secretariat-latest.zip` byte-gleich mit dem Release (SHA-256 5eda71a0…) |
| Update-Feed erreichbar | `secretariat.moinsen.dev` hat eine Cloudflare-Challenge für curl (403, `cf-mitigated: challenge`); URLSession (wie Sparkle) bekommt `appcast.xml` mit 200 |
| Verteilung | `mesh deliver`: M1 und Mac Mini „delivered secretariat“, dort `--version` 1.10.1, `codesign --verify --strict` ok, 222 Einträge per iCloud; M5 offline, bekommt es beim nächsten Lauf (launchd alle 15 Min.) |

Nicht geprüft: globaler Kurzbefehl ⌃⌥⌘V aus einer anderen App (muss ein Mensch auslösen); Sparkle-Update einer laufenden 1.10.0 auf 1.10.1 (Feed und Signatur liegen vor, der Update-Dialog selbst wurde nicht durchlaufen).
