# Release 1.18.1 (2026-11-14)

Inhalt: Nachsichtige Suche (T039, UC33): Einträge auch über die Variablen und Namen der Projekte und Ziele, die sie binden; Trennzeichen, Groß-/Kleinschreibung und Akzente zählen nicht; ein eingefügter Satz aus einem Agentenbericht findet seinen Eintrag. Bericht `docs/search-2026-11-14.md`.

| Schritt | Beobachtung |
|---|---|
| Version | `Info.plist` 1.18.1 (Build 35), `Launcher.version` 1.18.1, `site/index.html` softwareVersion 1.18.1, Commit d8c9eec; Unit 148/148, CLI-Regression 24/24 |
| Release-Build | `secretariat run werkzeuge -- script/release.sh`: App und Paket notarisiert (Accepted), gestapelt (`stapler validate` ok), `spctl` accepted („Notarized Developer ID“); `dist/Secretariat-1.18.1.zip` (SHA-256 57519315847b8843…), `dist/Secretariat-1.18.1.pkg` (111670e1e015e252…), `appcast.xml` 1.18.1 / 35 |
| Installation lokal (M4) | Ulis Go („Ja, releasen“): `script/install.sh`, `secretariat --version` 1.18.1; Verteilung über das Mesh an die anderen Macs (nicht einzeln geprüft) |
| Website | `wrangler pages deploy dist/site-1.18.1` (Deployment c5fe6f97). Live geprüft: Feed 1.18.1 / 35; `Secretariat-1.18.1.zip` und `Secretariat-latest.zip` byte-gleich (57519315847b8843…), `Secretariat-latest.pkg` byte-gleich (111670e1e015e252…), Seite meldet 1.18.1 |
| GitHub | Push nach `main`; vorher Diff auf Adressen, Benutzernamen und Site-Namen aus dem Tresor geprüft: keine |

Nebenbefund: Im Release-Log stehen einzelne verstümmelte Zeilen („write: Permission denied“) mitten in der `pkgutil`-Ausgabe; Ursache nicht geklärt (vermutlich vermischte Ausgabe im Log), alle Prüfungen danach sind grün.

Kritik: Selbstprüfung. Ältere Aufgaben, deren Dateien sich nur durch die Suche in `Views.swift` änderten, wurden über diese Prüfungen neu gebunden; die bisherigen Tests liefen unverändert grün.
