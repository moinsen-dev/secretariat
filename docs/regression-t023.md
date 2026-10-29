# Regression nach T023 (Build 4f322af, 2026-10-29)

Anlass: T023 („Eintrag aus Screenshot“) ändert `AppModel.swift`, `Editors.swift` und `ScreenshotsView.swift`, die in den `Files` fast aller älteren Aufgaben stehen. `git diff --stat 36c775b 4f322af -- Sources`: nur diese drei Dateien (+90 Zeilen, nur Ergänzungen) und die neue `ScreenshotReading.swift`. Die Ergänzungen greifen nur bei einem Entwurf aus einem Screenshot (`readNote`) und beim neuen Knopf „Create Item …“; bestehende Abläufe ändern sich nicht.

| Prüfung | Beobachtung |
|---|---|
| build | `xcrun swift build` grün; `script/build.sh` signiert wie bisher, keine neuen Entitlements |
| unit | `xcrun swift test`: 70/70, dreimal hintereinander grün |
| cli | `script/regression_cli.sh` gegen `dist/Secretariat.app`: 24/24 grün |
| macos | Paket-GUI im Test-Tresor (`docs/t023-evidence.md`): Screenshot aus der Zwischenablage speichern, Detailansicht, Eintrags-Dialog öffnen, Art und Felder, speichern, Eintrag erscheint in der Liste und per `item show`; `run` liefert den Wert byte-genau |
| inspection | Diff durchgesehen: keine Änderung an Kern-Speicher, Schlüsselbund, Launcher, CLI, Profilen oder Zielen |

Testeinträge danach per `CleanupTestItems` entfernt; echter Tresor unberührt (Ulis Instanz war nur beendet und wurde neu gestartet).
