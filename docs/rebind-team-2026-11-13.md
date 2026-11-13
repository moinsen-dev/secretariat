# Neubindung nach dem Team-Ausbau (2026-11-13)

Anlass: T031–T033 änderten Dateien, die ältere Aufgaben in `Files` nennen (`Models.swift` um `rotateReason`, `Storage.swift` um den
Team-Speicher und das Löschen der Markierung bei Wertänderung, `Commands.swift`/`Launcher.swift` um `team code|list` und `status`,
`Backup.swift` um einen öffentlichen Initialisierer, `AgentIntegration.swift` um `rotateReason` in `items --json`, `Views.swift`/
`Entry.swift`/`AppModel.swift`/`Info.plist` um Team-Bereich, Menüs, Dateityp und ein Hauptfenster). Bestehende Abläufe sind
unverändert; neue Felder sind optional und rückwärts lesbar.

| Prüfung | Beobachtung (Stand 2643bfc) |
|---|---|
| build | `script/build.sh` grün, Developer ID, `sdk 27.2` |
| unit | `xcrun swift test` 117/117 (alle bisherigen Tests unverändert grün) |
| cli | `script/regression_cli.sh` 24/24 |
| macos | Testinstanzen A, B, C: Hauptfenster, Liste, Detail, Menüs „Item“ und „File“, Neu laden; ein Hauptfenster beim Öffnen eines Pakets; siehe `docs/team-2026-11-12.md` |

Grenze: Ältere GUI-Abläufe (Sicherung, Verlauf, Screenshots, Fill/Save Login) wurden nicht einzeln erneut durchgespielt; ihre Dateien sind unverändert.
