# Regression für Release 1.13.0 (Build 0b2024c, 2026-10-30)

Anlass: 1.13.0 bringt `secretariat header` (T025), den Verlauf mit Herkunft (T024) und die automatische verschlüsselte Sicherung (T026). Geändert wurden dabei Dateien, die in den `Files` fast aller älteren Aufgaben stehen: `Commands.swift`, `Launcher.swift`, `Storage.swift` (Vault mit Sicherungsschlüssel und Screenshot-Schlüsselbund, Protokoll mit Herkunft und Sperre), `Models.swift` (Einstellung zum Löschen des Verlaufs), `Mcp.swift` (Herkunft, Markierung für `run_command`), `Hygiene.swift` (Wache-Regeln), `ProjectInstructions.swift` (Sperre mit kurzer Wartezeit), `License.swift` (Bezeichnung), `AppModel.swift`, `Views.swift`, `Entry.swift`. Bestehende Abläufe ändern sich nicht; neu sind nur zusätzliche Protokollfelder, Befehle und Bereiche.

| Prüfung | Beobachtung |
|---|---|
| build | `xcrun swift build` grün; `script/build.sh` signiert wie bisher (Developer ID), `codesign --verify --deep --strict` ok, `--version` 1.13.0, keine neuen Entitlements |
| unit | `xcrun swift test`: 94/94, dreimal hintereinander auf 8e1a9b3, einmal auf 0b2024c (nur Text „1 file“ geändert) |
| cli | `script/regression_cli.sh` gegen `dist/Secretariat.app` (0b2024c): 24/24 grün (Import ohne Ausgabe von Werten, items/get/describe ohne Werte, run/check, Ziele und Push, scan, setup, log nur Namen, Schutz benutzter Einträge, Aufräumen) |
| macos | Paket im Test-Tresor: Hauptfenster mit Eintrag, Feldern (Datei, verdecktes Geheimnis), „Used in“; Verlauf mit 2 748 Einträgen ohne Verschiebung; Backup-Bereich „Backup is on“. Neue Abläufe: `docs/t024-evidence.md`, `docs/t025-evidence.md`, `docs/t026-evidence.md` |
| inspection | Diff seit 1.12.0 durchgesehen: Werte verlassen den Prozess weiterhin nur über run/inject/push und neu über `header` (nur in eine Pipe, nicht für MCP-Kinder, Wache verweigert); Protokoll und Sicherungskopf ohne Werte |

Nicht erneut am Gerät: Screenshot-Erfassung und „Create Item …“ (unverändert seit 1.12.0, nur `AppModel.swift` um Felder ergänzt).
