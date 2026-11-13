# Agenten erforschen Lösch-Wege (T037, UC31) – Prüfbericht 2026-11-13

Anlass: Für 1036 von Ulis 1270 Logins kennt das JustDeleteMe-Verzeichnis keinen Weg. Agenten sollen die Wege recherchieren und in Secretariat ablegen, damit sie in der Inventur, bei späteren Löschanträgen und beim Abwickeln per Agent bereitliegen.

## Verhalten

- MCP: `login_inventory` (Zahlen, optional Pfade nach Befund oder Schwierigkeit), `login_sites` (je Site: Logins, Benutzernamen, Profile, Befunde, Entscheidungen, bekannter Weg; `needs_route`, `limit`/`offset`), `set_deletion_route` (Site, Schwierigkeit, Löschseite und/oder Kontakt, Quelle Pflicht, Notiz einzeilig).
- CLI dazu: `secretariat login-sites …`, `secretariat login-route SITE …`.
- Ablage: Kennungsfelder `deletion_url`, `deletion_contact`, `deletion_difficulty`, `deletion_note`, `deletion_source`, `deletion_checked` an jedem Login der Site; erneutes Eintragen ersetzt. Vorrang vor dem Verzeichnis. Die Inventur zeigt „Researched <Datum> from <Quelle>“.
- Grenzen bewusst: Kein Werkzeug schließt ein Konto, setzt eine Entscheidung oder zeigt einen Wert. Logins bleiben aus der Registry.

## Prüfungen

| Ziel | Ergebnis |
|---|---|
| unit | 137/137 grün; neu: Weg gilt für alle Logins der Site (auch Subdomain), Passwort unverändert, Vorrang vor Verzeichnis, Ersetzen statt Anhäufen, Ablehnung ungültiger Eingaben, unbekannte Site; MCP-Werkzeuge in Folge ohne Werte in der Ausgabe |
| build | `script/build.sh`, signiertes Paket |
| macos | `dist/…/Secretariat mcp` über stdio gegen Test-Tresor (2 künstliche Logins): initialize (secretariat 1.16.0), tools/list mit `login_inventory`, `login_sites`, `set_deletion_route`; `login_sites needs_route` → nur `unknown-shop.test` (GitHub hat Verzeichnis-Weg); `set_deletion_route` → `web/unknown-shop.test`; `login_inventory` → easy 1, hard 1; keine Testwerte in der Ausgabe; Verlauf: „MCP · Test: MCP tool set_deletion_route“, „inventory.route“ |

Aufräumen: Test-Schlüsselbund geleert, Testdateien gelöscht. Echter Tresor unberührt.

## Nächste Bausteine

Löschanträge als Mail-Entwürfe aus den Kontakten; Abwickeln per Agent im Browser mit Fill Login und Freigabe je Konto; Entscheidungen bleiben bei Uli in der App.
