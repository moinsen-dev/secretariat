# Release 1.18.2 (2026-11-14)

Inhalt: Löschen mit Entkoppeln (T040, UC34): Ist ein Eintrag noch an Projekte oder Ziele gebunden, nennt der Löschdialog sie samt Variablen und bietet „Unbind and Delete“ an; erst werden genau diese Bindungen entfernt (Verlauf „Unbound … from …“), dann der Eintrag. Bericht `docs/unbind-delete-2026-11-14.md`.

| Schritt | Beobachtung |
|---|---|
| Version | `Info.plist` 1.18.2 (Build 36), `Launcher.version` 1.18.2, `site/index.html` softwareVersion 1.18.2, Commit 4f3bd3a; Unit 149/149, CLI-Regression 24/24 |
| Release-Build | `secretariat run werkzeuge -- script/release.sh`: App und Paket notarisiert (Accepted), gestapelt (`stapler validate` ok), `spctl` accepted („Notarized Developer ID“); `dist/Secretariat-1.18.2.zip` (SHA-256 d35540998a58bdcf…), `dist/Secretariat-1.18.2.pkg` (b1a99e1803163e72…), `appcast.xml` 1.18.2 / 36 |
| Installation lokal (M4) | Ulis Go („Ja, releasen“): `script/install.sh`, `secretariat --version` 1.18.2; Verteilung über das Mesh an die anderen Macs (nicht einzeln geprüft) |
| Website | `wrangler pages deploy dist/site-1.18.2` (Deployment b23cb4eb). Live geprüft: Feed 1.18.2 / 36; `Secretariat-1.18.2.zip` und `Secretariat-latest.zip` byte-gleich (d35540998a58bdcf…), `Secretariat-latest.pkg` byte-gleich (b1a99e1803163e72…), Seite meldet 1.18.2 |
| GitHub | Push nach `main`; vorher Diff auf Adressen, Benutzernamen und Site-Namen aus dem Tresor geprüft: keine |

Nebenbefund: Wie bei 1.18.1 stehen im Release-Log einzelne verstümmelte Zeilen („write: Permission denied“) in der `pkgutil`-Ausgabe; alle Prüfungen danach sind grün.

Kritik: Selbstprüfung. Ältere Aufgaben, deren Dateien sich nur durch den Löschdialog (`Views.swift`, `AppModel.swift`), `Storage.swift`, `History.swift` und den neuen Test änderten, wurden über diese Prüfungen neu gebunden; die bisherigen Tests liefen unverändert grün.
