# Use-Case-Kritik nach 0.3 (Selbstprüfung)

Datum 2026-10-26. Prüfer: derselbe Agent — keine unabhängige Kritik. Grundlage: docs/regression-0.3.md, Code ce7cb30.

| UC | Bewertung |
|---|---|
| UC02 | Paket öffnet, Keychain- und Prozesszugriff unverändert belegt (Prozessprüfungen mit echtem Fixture-Eintrag grün). PASS |
| UC03 | UI-Code unverändert; Schlüssel/Profile in der Oberfläche normal bedient (Liste, Profil-Detail). PASS |
| UC04 | Terminalablauf, Fehler, Strg-C, beschädigte Konfiguration erneut grün. PASS |
| UC05 | Installation 0.3 ohne Autostart, Daten erhalten. PASS |
| UC06 | profiles/describe/check/setup unverändert grün; dialogfreier Fehlerfall Exit 2 ohne Dialog; GUI-Einrichtung schreibt Marker-Blöcke. PASS |
| UC07 | Claude Code nutzt installierte App für Testbefehl (vorbereitetes Profil) erneut erfolgreich; Codex/OpenCode nicht erneut (Grenze). PASS |
| UC08 | keys/profile per Unit- und Paket-CLI belegt; echter Claude-Lauf verdrahtet ein Projekt selbst (Profil, Bindung, check, run, Quittung), keine .env, kein Wert in Ausgabe; GUI zeigt neue Anleitung. PASS |

Hinweis: Agenten-Prüfung nur mit Claude Code; Selbstprüfung.

## UC09 und UC10 (Build 9c64dac)

| UC | Bewertung |
|---|---|
| UC09 | Schlüssel am M4 gespeichert und auf dem Mini per check/run genutzt (echter iCloud-Schlüsselbund, ≤ 10 s); Löschen kommt an, run bricht ohne Start ab; Altwert verlustfrei übernommen; CLI dialogfrei. Namenskonflikt nur per Unit-Test. PASS |
| UC10 | 0.3.0 mit gültiger Signatur auf M4, M1, M5, Mini installiert; keys ohne Fehler (Entitlement greift); keine neuen LaunchAgents. Zweiter-Account-Status auf M1/M5 offen bis zum ersten echten Schlüssel. PASS |

## UC05 und UC07 nach Lieferungseintrag L003 (Build 9c64dac)

Lokale Lieferung D001 neu auf Build 9c64dac erfasst (Belege der Installations- und Coding-System-Aufgaben aus docs/regression-0.3-sync.md). Installierter Startpfad ~/Applications/Secretariat.app, gültige Developer-ID-Signatur mit eingebettetem Profil, normaler GUI-Start beobachtet. UC05 PASS, UC07 PASS.
