# Aktueller Arbeitsstand

## Übergabe

- Geändert (2026-11-13): Passwort-Import aus Browser-CSV mit Chrome-Profil („Found in“), Website-Logins raus aus der Registry, Inventur der Logins (Library → Inventory, `audit-logins`). Commits c3de961 bis 773dff6, nicht gepusht.
- Echter Tresor: 1270 Logins aus drei Chrome-Profilen importiert; Inventur offline: 92 lokal, 805 mehrfach, 74 schwach.
- Lösch-Wege (JustDeleteMe, MIT, im Paket): 142 der 1270 Logins haben einen Weg (80 einfach), 1036 keinen. Richtung (Uli): Secretariat wird das umfassende Werkzeug rund um Zugangsdaten; Kontoabwicklung und Nachlass gehören hinein.
- MCP für Agenten: `login_inventory`, `login_sites`, `set_deletion_route` (erforschte Wege mit Pflichtquelle, Vorrang vor JustDeleteMe).
- Halb fertig: T034–T037 OFFEN, schließen mit Release 1.17.0 und Neubindung aller älteren Aufgaben samt Planprüfung (`check` meldet PLAN_REVIEW und veraltete Belege). Uli will das Release später.
- Nächster Schritt: Release 1.17.0 bauen und installieren (nach Ulis Ja), dann in der App „Check Online“.
- Gelaufen: `xcrun swift test` 132/132, `script/regression_cli.sh` 24/24, App-Läufe in Testinstanzen (docs/password-import-2026-11-13.md, docs/login-inventory-2026-11-13.md).

## State

- schema: app-workflow/1
- status: ACTIVE
- phase: P25
- use_case: UC27
- task: T033
- next: Uli: Test-Profil mit TeamMembers installieren, App zeigt verwaltetes Mitglied, Profil wieder entfernen
- updated: 2026-11-13T07:52:42+00:00
- plan_sha256: 14232fb1661398cfdf07e96ede2f00de0084f0dc747ae4add6352d4d5baf8c7e
- tracker_sha256: ba134626095ee39158fe1be967441af3bd18608bf5182221791b8899229ad454

Einstieg: `AGENTS.md`. Verbindliche Aufgabenstatus und Nachweise: `TRACKER.md`. Diese Zusammenfassung mit dem Werkzeug aus Plan und Tracker aktualisieren.
