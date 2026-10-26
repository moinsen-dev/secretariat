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
