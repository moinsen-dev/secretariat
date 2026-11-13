# Release 1.17.0 (2026-11-13)

Inhalt: Website-Logins rund um Zugangsdaten (Richtung Uli 2026-11-13): Passwort-Import aus Browser-Exporten mit „Found in“ je Profil (T034), Inventur der Logins mit Online-Prüfung und Entscheidungen (T035), Lösch-Wege aus JustDeleteMe (T036), MCP-Werkzeuge, mit denen Agenten Lösch-Wege recherchieren und eintragen (T037). Website-Logins bleiben aus der Agenten-Registry. Berichte: `docs/password-import-2026-11-13.md`, `docs/login-inventory-2026-11-13.md`, `docs/deletion-guides-2026-11-13.md`, `docs/agent-deletion-routes-2026-11-13.md`, `docs/research-trial-2026-11-13.md`.

| Schritt | Beobachtung |
|---|---|
| Version | `Info.plist` 1.17.0 (Build 33), `Launcher.version` 1.17.0, Commit 786f1ab; Unit 137/137, CLI-Regression 24/24 |
| Release-Build | `secretariat run werkzeuge -- script/release.sh`: App notarisiert und gestapelt, `spctl` accepted („Notarized Developer ID“), `sdk 27.2`, `minos 14.0`; `dist/Secretariat-1.17.0.zip` (SHA-256 9ef9f7f2bd040afb…), `appcast.xml` sparkle:version 33 / 1.17.0 |
| MDM-Paket | erstmals gebaut: `dist/Secretariat-1.17.0.pkg` signiert mit „Developer ID Installer“, Notarisierung `Accepted`, gestapelt, `spctl` accepted (SHA-256 998d11bab255b957…) |
| Installation lokal (M4) | Ulis Go („ja release“): `script/install.sh` → `~/Applications/Secretariat.app`, `secretariat --version` 1.17.0, `codesign --verify --deep --strict` ok, `spctl` ok; `status`: Tresor geöffnet, Lizenz aktiv, nichts zu rotieren |
| App mit echtem Tresor | View → Inventory (⌥⌘I) öffnet die Inventur, Liste „To Review“ mit den importierten Logins, Profilfilter und „Check Online“; `audit-logins` zählt Lösch-Wege (nur Zahlen hier) |
| Verteilung | über das Mesh innerhalb von 15 Minuten an die anderen Macs (nicht einzeln geprüft) |
| GitHub | Ulis Go („Ja, beides“): Push nach `main` (be476f4..83fe4d6); vorher die ungepushten Commits auf Adressen und Namen aus dem Tresor geprüft: keine |
| Website | Ulis Go: `secretariat run werkzeuge -- wrangler pages deploy dist/site-1.17.0 --project-name secretariat --branch main` (Deployment 1516f035). Live geprüft: Feed 1.17.0; `Secretariat-1.17.0.zip` und `Secretariat-latest.zip` byte-gleich mit dem notarisierten Zip (9ef9f7f2bd040afb…), `Secretariat-1.17.0.pkg` und `Secretariat-latest.pkg` byte-gleich mit dem Paket (998d11bab255b957…); Abschnitt `#accounts` mit `import-logins` online; 1.16.0 weiter erreichbar |

## Neubindung der älteren Aufgaben (T001–T033)

Anlass: T034–T037 änderten Dateien, die ältere Aufgaben in `Files` nennen (`Models.swift` Login-Template um „Found in“ und „Inventory decision“, `Storage.swift` Registry ohne Website-Logins, `Commands.swift`/`Launcher.swift` um `import-logins`, `audit-logins`, `login-sites`, `login-route`, `Mcp.swift` um drei Werkzeuge, `Views.swift`/`Entry.swift`/`AppModel.swift` um Inventur, Menüpunkte und Import-Sheet, `Package.swift` um eine Ressource). Bestehende Abläufe bleiben; alle Änderungen sind Ergänzungen.

| Prüfung | Beobachtung (Stand 786f1ab) |
|---|---|
| build | `script/release.sh` (siehe oben), Developer ID, notarisiert |
| unit | `xcrun swift test` 137/137, alle bisherigen Tests unverändert grün |
| cli | `script/regression_cli.sh` 24/24 |
| macos | installierte App: Hauptfenster, Seitenleiste, Liste, Inventur, Menüs; Testinstanzen für Import, Inventur und Lösch-Wege (Berichte oben) |
| inspection | Diff der gemeinsam genutzten Dateien seit 1.16.0 durchgesehen: nur neue Fälle, Felder, Menüpunkte und Sheets; keine geänderte Bedeutung bestehender Befehle, Felder oder Exporte außer der bewussten Registry-Regel (Website-Logins nicht mehr in `accounts.toml`) |

Kritik: Selbstprüfung (keine unabhängige Abnahme für diese Neubindung).
Grenze: Ältere GUI-Abläufe (Sicherung, Verlauf, Screenshots, Teilen, Fill/Save Login) wurden nicht einzeln erneut durchgespielt.
