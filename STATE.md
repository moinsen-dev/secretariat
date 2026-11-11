# Aktueller Arbeitsstand

## Übergabe (2026-11-11, Claude Code)

- **Neu:** Fill Login (T028, P22, UC22): ⌃⌥⌘P füllt ein gespeichertes Passwort nach Touch ID in das fokussierte Passwortfeld, auch im eingebauten Browser von Claude Code. Echter Lauf durch Uli, unabhängige Kritik PASS. Commits 548ff65..18d7e2a, **nicht gepusht, kein Release**. Bericht: `docs/login-fill-2026-11-11.md`, Kritik: `docs/review-login-fill-2026-11-11.md`.
- **Website:** Der Kaufknopf zeigt bis zur Freischaltung durch Lemon Squeezy den Testdownload (2568981). Deploy macht Uli. Go-live-Schritte stehen in `site/index.html` und `site/_redirects`.
- **Wartet auf Uli:** Release mit Fill Login (im Release die Bedienungshilfen neu freigeben); Lemon Squeezy prüft seit 28.10., die Support-Nachfrage liegt als Entwurf in developer@moinsen.dev; T026 Sicherung im echten Tresor.
- **Werkzeug:** `check` scheitert an Altlasten von vor dieser Sitzung (T006, T010, T012; dadurch ist P05 mit T007/T008 offen), deshalb aktualisiert `state` diese Datei nicht. Neubindungen: `docs/rebind-*.md`.
- **Prüfungen gelaufen:** `xcrun swift test` 103/103, `script/build.sh`.

## State

- schema: app-workflow/1
- status: ACTIVE
- phase: P21
- use_case: UC21
- task: T026
- next: GEPARKT (2026-10-30 abends). Live: 1.13.1 auf M4/M1/M5/Mini, Website mit Feed 1.13.1 und neuem Abschnitt 'Couldn't I just vibe-code this?'. Neu seit 1.12: secretariat header (MCP-Tokens ohne Klartext; tinideas, feedback-cafe, testerpaykit umgestellt), Verlauf mit Herkunft, automatische verschluesselte Sicherung (HPKE, Wiederherstellungsschluessel), Liste 'Needs a Value' (24 Eintraege aus dem Import vom 26.10. ohne echten Wert, nichts geloescht). OFFEN T026: Uli richtet Sicherung im echten Tresor ein (Bibliothek > Backup, Schluessel nur er), testet 'Wiederherstellen ...' und 'Schluessel pruefen' in der App, oeffnet eine in iCloud ausgelagerte Sicherung; danach unabhaengige UC21-Abnahme und T026 ERLEDIGT. DANACH: Vision 2.0 (docs/vision-2.0.md, Recherche docs/research/2026-10-30-schluessel-per-api-anlegen-rotieren.md) - erster Durchstich Cloudflare-Adapter (Schluessel anlegen, begrenzen, rotieren, ohne dass ihn jemand sieht). HINWEISE: Website-Deploy blockiert der Auto-Modus, Uli fuehrt wrangler selbst aus (Stage: site/ + dist-Zips + appcast.xml); lokale Installation erreicht per mesh binnen 15 Min. alle Macs; immer xcrun swift/swiftc; Kreislauf-Plugin connect.sh traegt noch ~/bin/mcp-bearer ein (Hinweis im Brain).
- updated: 2026-10-30T20:53:08+00:00
- plan_sha256: e3180757baf656e936ff54765faa323eb26729fb6596bb7758bbb000db890c53
- tracker_sha256: ec03de8d0ceeb95572f6c7ca59d9c328f4f1631985b90b421cf59fd80cef9593

Einstieg: `AGENTS.md`. Verbindliche Aufgabenstatus und Nachweise: `TRACKER.md`. Diese Zusammenfassung mit dem Werkzeug aus Plan und Tracker aktualisieren.
