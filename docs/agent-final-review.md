# Unabhängige Abschlusskritik Secretariat 0.2

Stand: 2026-10-23T09:08:08+02:00. Geprüft: aktueller PLAN und Quellen, `docs/agent-acceptance.md`, aktuelle JSON-Artefakte und installiertes Paket. Keine Produktionsquellen verändert, keine Credential-/Keychainaktionen oder UI-Tests ausgeführt.
PLAN-SHA-256: `05e211a3897bdf141394a203be50edefc5edd545db78bdb5b14d37192e91b705`.

**Gesamturteil: BLOCKED für die vollständige 0.2-Abnahme. Plan und aktuelle Produktionsquellen: PASS.** Die externe UI-Prüfung und ein altes künstliches Restobjekt verhindern den vollständigen Abschluss.

| Scope | Urteil | Konkreter Stand |
|---|---|---|
| PLAN | PASS | Lokale CLI und Projektanweisungen passen zum Nutzerziel. R012 bildet die Nutzerkorrektur gegen wiederholte OS-Dialoge ab. Snapshot-/Crash-/Agenten-Isolationsgrenzen sind ausdrücklich benannt. |
| Keychain-Dialogfix | PASS für Quellen und beschriebenen negativen Paketfall | Alle Storeoperationen werden serialisiert. Get/Set(false) wird geprüft, exakt vorheriger Prozesszustand per defer wiederhergestellt. CLI-run/check sind nichtinteraktiv, GUI bleibt benutzergeführt. Aktuelles Root-Artefakt: drei check-Aufrufe Exit 2 in **0,023 / 0,031 / 0,024 s**, run Exit 1 ohne Zielmarker; Cleanup=true. Kein Locktest und keine universelle Zusage für jedes OS-Szenario. |
| CLI / Dateieinrichtung | PASS Quelle | Metadaten/Status statt Werteausgabe; profilspezifische Marker, Byteerhalt, Idempotenz, Links-/UTF-8-/Snapshotprüfung, Previewrevision und normaler Zweidatei-Rollback. Unabhängig reproduzierter Stagingkonflikt nach Fix erhalten. Verbleibendes Check/Rename-Fenster ist keine atomare CAS-Garantie. |
| Fixture-ACL / neue Cleanupquelle | PASS Quelle | Tatsächliches .app-Bundle und eigener gleichsignierter Helper werden gezielt vertraut; denied-Seed vertraut nur dem Helper. Alle Helper-Keychainpfade liegen im Legacy-No-UI-Scope. Delete ist auf Testlabel, Service und Account begrenzt. Kein ungeschützter security-Fallback. |
| Paket / Regression | PASS | dist und installiertes Executable unabhängig identisch gehasht: `a4f33226e4a3b1f7a3155d1162b0902d8ab6e9e60129c2e43e024dab78d501b0`. codesign deep/strict erfolgreich, Team VXX45ZYNM8. Aktuelles Root-Artefakt: acht Prozesschecks=true, Cleanup=true. |
| Claude Code | PASS für dokumentierten Lauf | Aktueller Binaryhash, Exit 0, Receipt credential_verified/cwd_verified=true, keine künstliche Wertausgabe, Cleanup=true. Sitzung nicht vom Kritiker wiederholt. |
| Codex | PASS für aktuellen erneuten Lauf | Aktueller Binaryhash, Exit 0, Receipt beide true, keine künstliche Wertausgabe, Cleanup=true. Der vorherige Cleanupfehler bleibt historische Testgrenze; neuer Lauf jetzt sauber abgeschlossen. |
| OpenCode | BLOCKED für E2E | Aktueller Versuch ohne Receipt, Transport ECONNRESET laut Root; Timeout nach 90,2 s, Exit 130, Cleanup=true. Früherer OAuth-401 separat historisch. Versuche und Grenzen sind dokumentiert; erfolgreiche Ausführung nicht belegt. |
| UC06 gesamt | BLOCKED | CLI-/Quellteile geprüft; normale neue UI-Vorschau, Abbruch und explizites Einrichten wegen `Sky Computer Use native pipe startup failed` nicht tatsächlich abgenommen. 0.1-UI-Nachweise ersetzen das nicht. |
| UC07 gesamt | BLOCKED | Codex/Claude und Paketpfad belegt; neue UI-/Regressionsabnahme und vollständige Testdatenbereinigung fehlen. OpenCode bleibt konkreter externer Transport-/Authgrenzfall, kein erfundener E2E-Erfolg. |

## Verbleibender Umfang

- **Altes künstliches Restobjekt:** Root meldet genau einen früher erzeugten denied-Fixture-Eintrag. Unter dialogfreier Richtlinie ist dessen gezielte Entfernung mit -25244 blockiert. Die exakten Attribute stehen in `docs/agent-acceptance.md`. Aktuelle erfolgreiche Cleanup-Ergebnisse betreffen die jeweiligen neuen Läufe und beweisen nicht die Entfernung dieses alten Eintrags. Keine weitere automatische Freigabeschleife erzwingen.
- **Native UI:** Nach Wiederherstellung der externen Steuerung normale 0.2-Abläufe tatsächlich prüfen; bis dahin keine UI-PASS- oder vollständige 0.2-Fertigmeldung.
- **Dokumentation:** Aktuelle Evidence/Reviews/State mit diesen Grenzen registrieren. OpenCode-Ausführungsversuch transparent als Transport-/Authgrenze abschließen, sofern kein autorisierter sinnvoller weiterer Weg besteht.

Die JSON-Artefakte und der Abnahmebericht stammen vom implementierenden Agenten; sie wurden unabhängig lesend bewertet, nicht als eigene erneut ausgeführte Sitzungen ausgegeben. Der Kritiker bestätigte unabhängig Quelle, Signatur/Hash sowie zuvor einen reinen Tempdatei-Race- und Memory-Watchdogfall. Der künstliche erwartete Wert in verify.py und Receipts belegen Prozessinjektion/Ausgabehygiene, keine Isolation gegenüber Agenten mit Lese-/Shellrechten.
