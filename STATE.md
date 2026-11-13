# Aktueller Arbeitsstand

## Übergabe

- Release 1.17.0 (2026-11-13): Passwort-Import mit „Found in“, Inventur, Lösch-Wege (JustDeleteMe), MCP-Werkzeuge für Agenten. Notarisiertes Zip und MDM-.pkg in `dist/`, lokal installiert, Website-Ordner `dist/site-1.17.0` gebaut. Bericht `docs/release-1.17.0.md`.
- Tracker neu gebunden (T001–T037, Selbstprüfung), `check`: STRUCTURE_OK.
- Offen bei Uli: Website deployen (`wrangler pages deploy dist/site-1.17.0 --project-name secretariat --branch main`) und `git push` (lokale Commits seit 93fe7eb).
- Nächster Arbeitsschritt: in der Inventur Logins als „Close account“ markieren; Agenten recherchieren nur diese Sites (MCP `login_sites --decision close --needs-route`). Danach Bausteine Löschanträge per Mail und Abwickeln per Agent.
- Regel: In docs/, PLAN, TRACKER, STATE und Tests keine Adressen, Benutzernamen oder Site-Namen aus Ulis Tresor (öffentliches Repo).

## State

- schema: app-workflow/1
- status: ACTIVE
- phase: P27
- use_case: UC31
- task: T037
- next: Uli: Website dist/site-1.17.0 veröffentlichen und pushen; dann in der App Logins als Close markieren, Agenten recherchieren nur diese
- updated: 2026-11-13T09:22:36+00:00
- plan_sha256: 5fdb3479c00ca18c5711f5319f12594cf3048e9e6a9639cd098149734a5e01b7
- tracker_sha256: 3435db58422e5049c46ce6706b12cacd4b73975c008ea5eef3b14c4d9827aaca

Einstieg: `AGENTS.md`. Verbindliche Aufgabenstatus und Nachweise: `TRACKER.md`. Diese Zusammenfassung mit dem Werkzeug aus Plan und Tracker aktualisieren.
