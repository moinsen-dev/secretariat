# Release 1.18.3 (2026-11-14)

Inhalt: Kaufen in Safari (T041, UC35): „Buy License“ öffnet den Polar-Checkout in Safari, damit Apple Pay erscheint; ohne Safari der Standardbrowser. Website-Kleingedrucktes nennt „Apple Pay is available in Safari“. Bericht `docs/apple-pay-safari-2026-11-14.md`.

| Schritt | Beobachtung |
|---|---|
| Version | `Info.plist` 1.18.3 (Build 37), `Launcher.version` 1.18.3, `site/index.html` softwareVersion 1.18.3, Commit 34d4086; Unit 149/149 |
| Release-Build | `secretariat run werkzeuge -- script/release.sh`: App und Paket notarisiert (Accepted), gestapelt („The staple and validate action worked!“), `spctl` accepted („Notarized Developer ID“); `dist/Secretariat-1.18.3.zip` (SHA-256 1ef69bbfac8c31a2…), `dist/Secretariat-1.18.3.pkg` (1c9aed5927e36e36…), `appcast.xml` 1.18.3 / 37 |
| CLI-Regression | `script/regression_cli.sh` gegen `dist/Secretariat.app`: 24/24 |
| Installation lokal (M4) | Ulis Go („Ja, releasen“): `script/install.sh`, `secretariat --version` 1.18.3; Verteilung über das Mesh an die anderen Macs (nicht einzeln geprüft) |
| Website | `wrangler pages deploy dist/site-1.18.3` (Deployment 465ade5a). Live geprüft: Feed 1.18.3 / 37; `Secretariat-1.18.3.zip` und `Secretariat-latest.zip` byte-gleich (1ef69bbfac8c31a2…), `Secretariat-latest.pkg` byte-gleich (1c9aed5927e36e36…), Seite meldet 1.18.3 und zeigt „Apple Pay is available in Safari“; `/buy` leitet weiter zu `buy.polar.sh` |
| GitHub | Push nach `main`; vorher Diff auf Adressen, Benutzernamen und Site-Namen aus dem Tresor geprüft |

Kritik: Die Änderung selbst hat ein unabhängiger Kritiker geprüft (PASS, siehe `docs/apple-pay-safari-2026-11-14.md`). Ältere Aufgaben, deren Dateien sich nur durch den Versionssprung (`Info.plist`, `Launcher.swift`, `site/index.html`) änderten, wurden über diese Prüfungen neu gebunden (Selbstprüfung); die bisherigen Tests liefen unverändert grün.
