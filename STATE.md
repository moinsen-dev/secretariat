# Aktueller Arbeitsstand

## Übergabe

- Kaufen in Safari (2026-11-14, T041, UC35, nicht released): Der Knopf „Buy License“ öffnet den Polar-Checkout über `Checkout.open` in Safari (Apple Pay), Fallback Standardbrowser; Website-Kleingedrucktes nennt „Apple Pay is available in Safari“. Bericht `docs/apple-pay-safari-2026-11-14.md`; Nachweise der Aufgaben mit `Views.swift` neu gebunden, Kritik unabhängig PASS. Nicht deployt, nicht gepusht.
- Release 1.18.2 (2026-11-14): Löschen mit Entkoppeln (T040, UC34) – der Löschdialog nennt Projekte/Ziele mit Variablen und bietet „Unbind and Delete“. Berichte `docs/unbind-delete-2026-11-14.md`, `docs/release-1.18.2.md`; Nachweise neu gebunden, `check` ohne Fehler (nur Selbstprüfungs-Hinweise).
- Release 1.18.1 (2026-11-14): Nachsichtige Suche. Berichte `docs/search-2026-11-14.md`, `docs/release-1.18.1.md`.
- Offen: Klick auf „Unbind and Delete“ in der echten Oberfläche nur per Unit-Test belegt (Testfenster wechselte den Schreibtisch).
- Nächster Arbeitsschritt: Release mit Kaufen in Safari, sobald Uli es freigibt; sonst Nacharbeiten aus BACKLOG.
- Regel: In docs/, PLAN, TRACKER, STATE und Tests keine Adressen, Benutzernamen oder Site-Namen aus Ulis Tresor (öffentliches Repo).

## State

- schema: app-workflow/1
- status: ACTIVE
- phase: P31
- use_case: UC35
- task: T041
- next: Release mit Kaufen in Safari, sobald Uli es freigibt; sonst Nacharbeiten aus BACKLOG
- updated: 2026-11-14T12:48:38+00:00
- plan_sha256: 7791339748ebe970620089530ab1f1d90de2cf7368530ac49fb490b582e79380
- tracker_sha256: f668b354eeabebbf095a5d97d0b4a4ed1213ca86a01fe0e81191af0b16254a79

Einstieg: `AGENTS.md`. Verbindliche Aufgabenstatus und Nachweise: `TRACKER.md`. Diese Zusammenfassung mit dem Werkzeug aus Plan und Tracker aktualisieren.
