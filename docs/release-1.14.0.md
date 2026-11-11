# Release 1.14.0 (2026-11-11)

Inhalt: Fill Login (T028, ⌃⌥⌘P) und Save Login (T029, ⌃⌥⌘S). Prüfungen: `docs/regression-1.14.0.md`,
`docs/login-fill-2026-11-11.md`, `docs/save-login-2026-11-11.md`, Kritik `docs/review-*-2026-11-11.md`.

| Schritt | Beobachtung |
|---|---|
| Version | `Info.plist` 1.14.0 (Build 30), `Launcher.version` 1.14.0; Unit 108/108 (3×), CLI-Regression 24/24 |
| Release-Build | `secretariat run werkzeuge -- script/release.sh`: Notarisierung `Accepted`, `stapler validate` ok, `spctl` accepted („Notarized Developer ID“); `dist/Secretariat-1.14.0.zip` (SHA-256 01f25d8f68ec6abb…), `appcast.xml` sparkle:version 30 |
| Installation lokal (M4) | `script/install.sh`, `--version` 1.14.0, `codesign --verify --deep --strict` ok, `status`: 273 Einträge, 176 Profile; TinIdeas-MCP „Connected“ |
| Verteilung | `mesh deliver`: m1 und mini „delivered secretariat“; M1 per SSH `--version` 1.14.0; M5 offline (Tailscale), folgt beim nächsten Lauf |
| Website | Stage `dist/site-1.14.0` (site/ ohne Testseite, alle Zips, `Secretariat-latest.zip` byte-gleich mit 1.14.0, `appcast.xml`); Deploy durch Uli ausstehend |
| GitHub | Push ausstehend (Repo öffentlich, Ulis Go) |
