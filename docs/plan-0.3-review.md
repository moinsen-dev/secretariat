# Planprüfung 0.3 (Selbstprüfung)

Datum: 2026-10-26. Prüfer: derselbe Agent, der den Plan erweitert hat (Claude Code auf dem M4) —
**keine unabhängige Kritik**. Grundlage: Nutzerauftrag vom 26.10. („Erst Secretariat erweitern:
Schlüssel per iCloud-Schlüsselbund zwischen den Macs synchronisieren und CLI-Befehle zum Auflisten
von Schlüsselnamen und Anlegen von Profilen. Dann installieren.“), PLAN.md, Katalog macos + sync/files.

## Abdeckung des Auftrags

| Auftrag | Plan |
|---|---|
| Schlüsselnamen per CLI auflisten | R013, T011 |
| Profile per CLI anlegen (und sinnvoll ändern) | R014, T011; Anleitung und echter Agentenlauf T012 |
| iCloud-Abgleich der Schlüssel | R015, R016, T013 (Signatur/Provisioning), T014 (Umbau, Zweit-Mac-Beleg) |
| danach Installation auf M5, M1, Mini | R017, P10 nach P09, T015 |

## Befunde

1. **Externe Voraussetzung sichtbar:** Synchronisierbare Einträge gibt es nur im Data-Protection-Schlüsselbund;
   der verlangt für eine Developer-ID-App ein Provisioning-Profil. `asc` ist nicht angemeldet, und die Anmeldung
   mit Zugangsdaten ist eine Nutzerhandlung. T013 ist korrekt als BLOCKIERT mit konkretem Handgriff geplant;
   P08 hängt nicht davon ab. — ok
2. **Namen reisen mit:** Bisher stehen Schlüsselnamen nur in der lokalen profiles.json und der Dienstname hängt
   vom Pfad ab (M1: Benutzer `doedel`). T014 verlangt festen Dienst und Namen im Eintrag. — ok
3. **Profile bleiben lokal:** begründet (Pfade/Benutzer je Mac). R015 sagt das ausdrücklich. — ok
4. **Keine Wert-Schnittstelle in der CLI:** Entscheidung in „Bestand und Änderungsumfang 0.3“ festgehalten;
   verhindert, dass Agents Werte setzen/lesen. — ok
5. **SYNC-001/002** sind T014 zugeordnet mit prüfbaren Erwartungen (offline, Konflikt gleicher Name,
   erneute Übernahme, Löschen). — ok
6. **Regression:** T014 ändert Keychain-Kern; die Kriterien verlangen dialogfreie CLI (R012). Die alten
   Phasen bleiben unverändert gültig; nach T014 sind die Belege von T002/T004 (Keychain) inhaltlich betroffen —
   beim Umbau mitprüfen. — Hinweis, kein Planfehler
7. **Prüfziele:** T011 build/unit, T012 macos/inspection (echter Claude-Code-Lauf), T014 inkl. zweitem Mac,
   T015 auf den Zielgeräten. Ausführbar. — ok

## Urteil

PASS — mit der Einschränkung, dass es eine Selbstprüfung ist und T013 eine Nutzerhandlung braucht.

## Plan-Prüfung 0.4 (Selbstprüfung)

R018/P11/UC11/T016 ergänzt. Anforderung prüfbar (Namen-only-Ausgabe, --replace, Vorabprüfung), Aufgabe nennt alle geänderten Quellen, Abhängigkeit T015 korrekt, Lockerung der Wertregel als Entscheidung mit Begründung dokumentiert. PASS.

## Plan-Prüfung 0.4.1 (Selbstprüfung)

R019/P12/UC12/T017 ergänzt; Abgleich über Etikett prüfbar mit zwei Konfigurationen; alle geänderten Quellen in Files. PASS.

## Plan-Prüfung 1.0 (Selbstprüfung)

R013/R016/R018/R019 auf das Eintragsmodell umformuliert (Verhalten hat sich geändert), R020–R023, P13, UC13, T018 ergänzt; Files gelöschter Dateien auf die Nachfolger umgestellt; T018 nennt alle geänderten Quellen. Entfernte Befehle ohne Kompatibilitätsschicht, wie im Projektgrundsatz. PASS.

## Plan-Prüfung 1.1 (Selbstprüfung)

R024/P14/UC14/T019 ergänzt; prüfbar über Unit-Tests, echten Werkzeug-Lauf und End-to-End-Sitzung. PASS.
