# Release 1.18.0 (2026-11-13)

Inhalt: „Open and Sign In“ (T038, UC32): Login-Seite im Standardbrowser öffnen und nach Touch ID ausfüllen; App-Knopf, `secretariat open PATH`, MCP `open_login`. Bericht `docs/open-login-2026-11-13.md`.

| Schritt | Beobachtung |
|---|---|
| Version | `Info.plist` 1.18.0 (Build 34), `Launcher.version` 1.18.0, Commit 741198e; Unit 142/142, CLI-Regression 24/24 |
| Release-Build | `secretariat run werkzeuge -- script/release.sh`: notarisiert (Accepted), gestapelt, `spctl` accepted („Notarized Developer ID“); `dist/Secretariat-1.18.0.zip` (SHA-256 b2640a66e9bd42ab…), `appcast.xml` 1.18.0 / 34 |
| MDM-Paket | `dist/Secretariat-1.18.0.pkg` notarisiert, `spctl` accepted (SHA-256 02e1c619609376c3…) |
| Installation lokal (M4) | Ulis Go („neue Version bauen und veröffentlichen“): `script/install.sh`, `secretariat --version` 1.18.0; Verteilung über das Mesh an die anderen Macs (nicht einzeln geprüft) |
| Website | `wrangler pages deploy dist/site-1.18.0` (Deployment 3ad17697). Live geprüft: Feed 1.18.0; `Secretariat-1.18.0.zip` und `Secretariat-latest.zip` byte-gleich (b2640a66e9bd42ab…), `Secretariat-latest.pkg` byte-gleich (02e1c619609376c3…); Abschnitt „Open and Sign In“ unter `#logins` online |
| GitHub | Push nach `main` mit Ulis Go; vorher Diff auf Adressen und Namen aus dem Tresor geprüft: keine |

Kritik: Selbstprüfung. Ältere Aufgaben, deren Dateien sich nur um Ergänzungen änderten (neuer Befehl, neues MCP-Werkzeug, neuer Knopf, Verlaufstext), wurden über diese Prüfungen neu gebunden; die bisherigen Tests liefen unverändert grün.
