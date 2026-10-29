# Release 1.11.0 (2026-10-29)

Inhalt: verschlüsselte Screenshots mit Notiz über den iCloud-Drive-Container, verdeckt bis „Show“ (cc0ef1a … 03de498), `secretariat screenshots` (nur Anzahlen). Prüfungen: `docs/t022-evidence.md`, unabhängige Kritik `docs/review-uc17.md`, `docs/regression-1.10.md`.

| Schritt | Beobachtung |
|---|---|
| Version | `Info.plist` 1.11.0 (Build 26), `Launcher.version` 1.11.0 |
| Release-Build | `secretariat run werkzeuge -- script/release.sh`: Notarisierung `Accepted`, gestapelt, `spctl` accepted („Notarized Developer ID“); Entitlements mit iCloud-Container (Profil „Secretariat Developer ID iCloud“); `dist/Secretariat-1.11.0.zip` (SHA-256 ac430955…), `appcast.xml` sparkle:version 26 |
| Installation lokal | `script/install.sh`, `--version` 1.11.0, `spctl` accepted, normal gestartet: Fenster „All Items – 223 items“, Menü File mit „New Screenshot from Clipboard …“ und „Import Screenshot …“; `screenshots` → „0 screenshots (icloud)“ |
| Website | Pages `secretariat`, Deployment ce6f8f91: `site/` + `Secretariat-1.11.0.zip` + `Secretariat-1.10.1.zip` + `Secretariat-latest.zip` (= 1.11.0) + `appcast.xml`; live: Feed 1.11.0, Download byte-gleich (ac430955…) |
| Verteilung | `mesh deliver`: M1 und Mac Mini „delivered secretariat“; dort `--version` 1.11.0, Signatur ok, 223 Einträge, `screenshots` → iCloud; M5 offline, folgt beim nächsten Lauf |

Synchronisation zwischen zwei Macs mit dem gleichen Code: `docs/t022-evidence.md` (M4 → Mini, Bild auf dem Mini entschlüsselt, Löschen synchronisiert). Nicht erneut mit den installierten Apps durchgespielt.
