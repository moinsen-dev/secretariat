# Release 1.13.1 (2026-10-30)

Inhalt: „Needs a Value“ (T027) – Liste in der Bibliothek und Hinweis am Feld für gespeicherte Werte, die ein `.env`-Kommentar oder Platzhalter sind; nichts wird gelöscht. Anlass: Prüfung des echten Tresors nach Ulis Frage (226 Einträge, 412 Zuordnungen verfügbar, alle Werte lesbar, keine Löschung; 24 Einträge aus dem Massenimport vom 26.10. ohne echten Wert). Prüfungen: `docs/t027-evidence.md`, `docs/regression-1.13.1.md`.

| Schritt | Beobachtung |
|---|---|
| Version | `Info.plist` 1.13.1 (Build 29), `Launcher.version` 1.13.1; Unit 94/94 (3×), CLI-Regression 24/24 |
| Release-Build | `secretariat run werkzeuge -- script/release.sh`: Notarisierung `Accepted`, `stapler validate` ok, `spctl` accepted („Notarized Developer ID“); `dist/Secretariat-1.13.1.zip` (SHA-256 d8edf06168d60dc3…), `appcast.xml` sparkle:version 29 |
| Installation lokal (M4) | `script/install.sh`, `--version` 1.13.1, `spctl` und `codesign --verify --deep --strict` ok, 226 Einträge, `lint` 24 Funde, TinIdeas-MCP „Connected“ |
| GitHub | `git push origin main`: `6dac53c..576801c` |
| Verteilung | `mesh deliver` 21:34: m1, m5, mini „delivered secretariat“, Zustand aller Macs „1.13.1 (29)“; per SSH auf M1: `--version` 1.13.1, Signatur ok |
| Website-Feed | Deploy vom Auto-Modus-Filter als Produktions-Deploy blockiert, Uli hat ihn selbst ausgeführt. Erster Lauf (Deployment fd72a9bf) mit noch altem Stage-Ordner (das Zusammenstellen steckte im blockierten Aufruf): Feed blieb 1.13.0. Stage neu zusammengestellt, zweiter Lauf (Deployment 317f5a98). Live per URLSession: Feed 1.13.1, `Secretariat-latest.zip` und `Secretariat-1.13.1.zip` byte-gleich mit dem notarisierten Zip (d8edf06168d60dc3…), `Secretariat-1.13.0.zip` weiter da, Startseite und Bedrohungsmodell unverändert vollständig |
