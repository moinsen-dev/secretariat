# Lösch-Wege je Login (T036, UC30) – Prüfbericht 2026-11-13

Anlass: Uli will 500–600 überflüssige Konten loswerden und Secretariat zum umfassenden Werkzeug rund um Zugangsdaten machen („einmal nur machen will ich nicht“). Erster Baustein: zu jedem Login den Weg zum Löschen kennen.

## Daten

JustDeleteMe `sites.json` von GitHub (MIT, Copyright Robb Lewis & contributors), abgerufen 2026-11-13: 477 Anbieter, davon 474 nach Prüfung übernommen (nur http(s)-Links, gültige Schwierigkeit, Domains als reine Hostnamen, Hinweise ohne HTML, höchstens 600 Zeichen). Im Paket: `Sources/SecretariatCore/Resources/deletion-sites.json` und `JustDeleteMe-LICENSE.md`.

## Prüfungen

| Ziel | Ergebnis |
|---|---|
| unit | 135/135 grün; neu: Zuordnung per Host und registrierbarer Domain, lokale Adressen ohne Weg, Link statt Websuche, Zählung je Schwierigkeit; mitgeliefertes Verzeichnis lädt (> 400, Quelle nennt MIT, GitHub bekannt); `audit-logins --closing` |
| build | `script/build.sh`: `Secretariat_SecretariatCore.bundle` liegt in `Contents/Resources`; die signierte CLI im Paket findet das Verzeichnis (Zählung unten) |
| macos | Testinstanz mit künstlichem GitHub-Login: Zeile zeigt „easy“, Liste „Easy to close (1)“; Detail „How to close“: „Easy to close“, Erklärung, „Open Deletion Page …“, Quellenhinweis JustDeleteMe (MIT). CLI-Regression 24/24 |

Echter Tresor (nur gezählt, nichts geändert): 1270 Logins; mit Lösch-Weg 142 (80 einfach, 15 mit Zusatzschritten, 31 über den Support, 16 nicht löschbar), ohne Eintrag 1036, Rest lokale Adressen.

## Grenzen und Folgerung

- Das Verzeichnis deckt nur rund 12 % von Ulis Konten ab. Für die übrigen 1036 braucht es weitere Wege: Löschantrag per Mail an die Datenschutzadresse (aus der Datenschutzerklärung), Suche durch einen Agenten, und den Agenten-Weg über MCP.
- Aufräumen: Testinstanz beendet, Test-Schlüsselbund geleert, Testdateien gelöscht.
