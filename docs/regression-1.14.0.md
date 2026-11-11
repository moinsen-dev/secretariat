# Regression für Release 1.14.0 (2026-11-11)

Anlass: 1.14.0 bringt Fill Login (T028, ⌃⌥⌘P) und Save Login (T029, ⌃⌥⌘S): Passwörter nach Touch ID in Passwortfelder tippen
(auch im eingebauten Browser von Claude Code) und neue Logins von der Seite aufnehmen. Neu: `LoginFill.swift`, `FillPanel.swift`,
`SaveLoginPanel.swift`; ergänzt: `Entry.swift` (Kurzbefehle, Menü), `CapturePanel.swift` (Einstellungen), `AppModel.swift`
(`storedValue`); Version. Kern von Tresor, CLI, Profilen, Agentenschutz und Sicherung unverändert.

| Prüfung | Beobachtung |
|---|---|
| build | `script/build.sh` signiert (Developer ID), `codesign --verify --deep --strict` ok, `--version` 1.14.0 |
| unit | `xcrun swift test`: 108/108, dreimal hintereinander |
| cli | `script/regression_cli.sh` gegen `dist/Secretariat.app`: 24/24 |
| macos | Echte Läufe mit Uli im eingebauten Claude-Browser gegen lokale Testseiten im Test-Tresor: `docs/login-fill-2026-11-11.md`, `docs/save-login-2026-11-11.md` |
| inspection | Unabhängige Kritik je drei Runden, zuletzt PASS: `docs/review-login-fill-2026-11-11.md`, `docs/review-save-login-2026-11-11.md` |
