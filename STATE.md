# Aktueller Arbeitsstand

## Übergabe

- Öffnen und anmelden: Nacharbeiten (2026-11-14, T042, UC36, committet und gepusht, **nicht released**): Hinweis bei Touch-ID-Abbruch, Anmeldung in zwei Schritten, Umleitung zu Anmeldediensten (fremder Host nur vorderste Seite, https, von Touch ID benannt), Tresor-Bindung der CLI-Anfrage. Bericht `docs/open-login-followups-2026-11-14.md`. Kritik unabhängig REWORK, Punkte übernommen, Nachprüfung Selbstprüfung. Live in Chrome mit Ulis Touch ID belegt (einstufig, zweistufig, Umleitung, vor der Überarbeitung); Abbruch-Hinweis nicht live gesehen. Reste in BACKLOG.
- Release 1.18.3 (2026-11-14): Kaufen in Safari (T041, UC35): Der Knopf „Buy License“ öffnet den Polar-Checkout über `Checkout.open` in Safari (Apple Pay), Fallback Standardbrowser; Website-Kleingedrucktes nennt „Apple Pay is available in Safari“. Bericht `docs/apple-pay-safari-2026-11-14.md`; Nachweise der Aufgaben mit `Views.swift` neu gebunden, Kritik unabhängig PASS. Release-Bericht `docs/release-1.18.3.md`, live geprüft.
- Release 1.18.2 (2026-11-14): Löschen mit Entkoppeln (T040, UC34) – der Löschdialog nennt Projekte/Ziele mit Variablen und bietet „Unbind and Delete“. Berichte `docs/unbind-delete-2026-11-14.md`, `docs/release-1.18.2.md`; Nachweise neu gebunden, `check` ohne Fehler (nur Selbstprüfungs-Hinweise).
- Release 1.18.1 (2026-11-14): Nachsichtige Suche. Berichte `docs/search-2026-11-14.md`, `docs/release-1.18.1.md`.
- Offen: Klick auf „Unbind and Delete“ in der echten Oberfläche nur per Unit-Test belegt (Testfenster wechselte den Schreibtisch).
- Nächster Arbeitsschritt: Release 1.18.4 mit T042, wenn Uli es freigibt; sonst BACKLOG.
- Regel: In docs/, PLAN, TRACKER, STATE und Tests keine Adressen, Benutzernamen oder Site-Namen aus Ulis Tresor (öffentliches Repo).

## State

- schema: app-workflow/1
- status: ACTIVE
- phase: P32
- use_case: UC36
- task: T042
- next: Release 1.18.4 mit T042, wenn Uli es freigibt; sonst BACKLOG
- updated: 2026-11-14T15:53:36+00:00
- plan_sha256: 3ce49ff410f797a03dfa16b0c1427a7abfb1a089adf4acb95f81f5569a9b4cae
- tracker_sha256: 28fa1df6c223d9db52652b4b75c17f27a9734ea0ac805daff75821124dc24e1a

Einstieg: `AGENTS.md`. Verbindliche Aufgabenstatus und Nachweise: `TRACKER.md`. Diese Zusammenfassung mit dem Werkzeug aus Plan und Tracker aktualisieren.
