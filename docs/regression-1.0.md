# Regression 1.0 (Build 80e78e5)

Umbau des Kerns (Einträge statt Einzelschlüssel); alle älteren Aufgaben neu geprüft, weil ihre Quellen sich geändert haben.

| Prüfung | Beobachtung |
|---|---|
| build | `swift build` grün; `script/build.sh` Developer-ID-signiert, eingebettetes Profil, Entitlement keychain-access-groups |
| unit | `swift test`: 30/30 grün (Modell, Tresor, Feld verschieben, run mit Dateien, Konfigurationsschutz, Register-Export, CLI-Befehle, import/import-file, inject inkl. Git-Schutz, Ziele mit Verteilstand, scan, Argumente, 5 Projektanweisungs-Tests) |
| macos | Installierte App auf dem M4 normal gestartet: Fenster „Secretariat“ zeigt „Alle Einträge“ nach Konto gruppiert, „Ziele“, Projektprofil menulens-worker (Screenshot geprüft). `check menulens-worker` bereit nach Migration |
| inspection | Signatur gültig; `--version` 1.0.0 auf M4, Mini, M1; Mini und M1 sehen per iCloud 16 Einträge, `get moinsen/apple-developer/team_id` = VXX45ZYNM8; keine LaunchAgents |

Grenzen: M5 offline (noch 0.4.1, Migration dort ausstehend); Codex-Sandbox erreicht den Schlüsselbund nicht (Status -25291), Secretariat meldet „nicht verfügbar“ und startet nichts.
