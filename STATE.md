# Aktueller Arbeitsstand

## Übergabe

- 2026-11-14 nach 1.18.1: Löschen mit Entkoppeln (T040, R044/UC34) – der Löschdialog nennt Projekte/Ziele mit Variablen und bietet „Unbind and Delete“. Commit 6435b47, 149 Tests grün, Dialog in Testinstanz belegt, Klick auf den Knopf nur per Unit-Test (docs/unbind-delete-2026-11-14.md). Noch nicht released, nicht gepusht.
- `check` meldet veraltete Nachweise vieler Aufgaben (Dateien `Storage.swift`, `Views.swift`, `AppModel.swift`); `state` verweigert deshalb. Neubindung beim nächsten Release (Ablauf wie docs/release-1.18.1.md).
- Release 1.18.1 (2026-11-14): Nachsichtige Suche. Berichte `docs/search-2026-11-14.md`, `docs/release-1.18.1.md`.
- Nächster Arbeitsschritt: Release 1.18.2 mit dem Löschdialog, dann Nachweise neu binden; sonst Nacharbeiten aus BACKLOG.
- Regel: In docs/, PLAN, TRACKER, STATE und Tests keine Adressen, Benutzernamen oder Site-Namen aus Ulis Tresor (öffentliches Repo).

## State

- schema: app-workflow/1
- status: ACTIVE
- phase: P29
- use_case: UC33
- task: T039
- next: Nacharbeiten aus BACKLOG (Öffnen und anmelden) oder Close-Markierungen in der Inventur
- updated: 2026-11-14T07:40:23+00:00
- plan_sha256: e57582e4ddb2b3b68ffea60cf3a691f1d8726929556869a61390b0a29dc500ac
- tracker_sha256: b30fe5b2169a8225ce2f3cfd727026ba6d6d6817ec874e72e33a659e2f4dcb02

Einstieg: `AGENTS.md`. Verbindliche Aufgabenstatus und Nachweise: `TRACKER.md`. Diese Zusammenfassung mit dem Werkzeug aus Plan und Tracker aktualisieren.
