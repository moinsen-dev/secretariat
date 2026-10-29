# Regression 1.10 (Build 051679f, erneut auf 30cbcd5: unit 57/57, CLI 24/24, Zwischenablage-Ablauf in der GUI grün; signiertes `dist/Secretariat.app` 1.10.0, 2026-10-29)

Anlass: Commits a56bad3 (Eintrags-Dialog) und 3e5ce0a (Zwischenablage-Eingang, Hauptfenster in drei Spalten) ändern Quellen fast aller Aufgaben. Alle älteren Aufgaben neu geprüft. Alle Läufe in isolierten Test-Tresoren (`SECRETARIAT_HOME`, Schlüsselbund-Dienst `…items.test.<hash>`) mit künstlichen Werten; echter Tresor unberührt.

| Prüfung | Beobachtung |
|---|---|
| build | `xcrun swift build` grün; `script/build.sh` Developer-ID-signiert (Team VXX45ZYNM8), `codesign --verify --deep --strict` ok, eingebettetes Provisioning-Profil, Entitlement `keychain-access-groups` = `VXX45ZYNM8.dev.moinsen.secretariat.local`, KeyboardShortcuts-Ressourcenbundle in `Contents/Resources` |
| unit | `xcrun swift test`: 56/56 grün |
| cli | `script/regression_cli.sh` gegen das Paket: 24/24 grün – import (nur Namen in der Ausgabe), items ohne Werte, item create, get verweigert Geheimnisse, profiles/describe/check (Schema, keine Werte), profile which, run (Werte, stdin, Exitcode 7, Maskierung in Pipe), fehlender Wert startet nichts, Dateifeld als 0600-Tempdatei und danach entfernt, field move und item rename behalten Bindungen, inject nur in ignorierte Dateien, Ziel never → push → current, scan nur Namen, setup Vorschau und idempotente Markerblöcke, log ohne Werte, Löschschutz, Aufräumen |
| macos | Paket-GUI mit Test-Tresor: Eintrag „Company“ über den Dialog angelegt und bearbeitet (Kennungen per `get` und `run` korrekt); Projekt erscheint nach Neustart; Bindung von außen erscheint nach View › Reload (⌘R), Detail zeigt „Used in: rg“; Löschen eines gebundenen Eintrags verweigert („still in use: rg“); Zwischenablage-Ablauf siehe `docs/t021-evidence.md` |
| agents | `script/agent_acceptance.py --binary dist/… --clients claude codex --self-wire` (Paket-SHA256 ba58c41c…): Claude Code listet Einträge, legt Profil an, bindet, prüft und startet selbst – `passed` in 26 s, kein künstlicher Wert in der Ausgabe, keine .env. Codex: `not_verified` – die Sandbox erreicht Schlüsselbund/Konfiguration nicht, `items --json` meldet `operation_failed`, nichts gestartet (bekannte Grenze, wie im Lauf 1.0). Fixture entfernt (`fixture_item_removed: true`) |
| fleet | Installierte Release 1.10.0 (aus d73e298, Lesezugriff per SSH): M4, Mac Mini und M1 melden `--version` 1.10.0 und sehen per iCloud-Schlüsselbund dieselben 221 Einträge (`items --json`, nur Namen); M5 offline (Tailscale, zuletzt vor 15 Min.) |
| inspection | `--version` 1.10.0; keine LaunchAgents; `spctl`: nicht notarisiert (lokaler Build, Notarisierung macht `release.sh`) |

## Behoben in diesem Lauf

- Der Umbau des Hauptfensters hatte den Knopf „Refresh“ entfernt; Änderungen aus CLI, Agenten oder anderen Macs waren erst nach einem Neustart sichtbar (Verstoß gegen T003 „externe Änderungen werden erkannt“). Jetzt: Neuladen beim Aktivieren der App und View › Reload (⌘R). Commit 051679f.

- Umwandeln einer Erfassung löschte sie auch ohne übernommenen Wert (unabhängige Kritik `docs/review-uc16.md`). Behoben in 30cbcd5, siehe `docs/t021-evidence.md`.

## Grenzen

- Geheime Felder und der Ordner-Dialog lassen sich in der Hintergrundsteuerung nicht bedienen; Werteingabe über die GUI ist über den Zwischenablage-Eingang belegt, Projektanlage per CLI, Anzeige in der GUI.
- Neuladen beim Aktivieren nicht ausgelöst (würde den Fokus stehlen), nur ⌘R geprüft.
- M5 offline, dort nicht geprüft; OpenCode nicht erneut versucht (bisher ECONNRESET vor Werkzeugausführung). Der Eintragsspeicher und seine Synchronisation (`SyncedItemStore`) sind seit dem letzten Lauf auf 9faa20d unverändert. `git diff 9faa20d 051679f -- Sources/SecretariatCore` betrifft: zusätzlichen Lizenzspeicher (eigener Dienst `…license…`), Hygiene (sweep/tidy/lint), Guard, Launcher-Hilfe, neue CLI-Befehle, Capture und die Vorlage „capture“. Die Abläufe, die die alten Aufgaben belegen, sind im CLI-Lauf oben erneut ausgeführt.
- Kleinere Oberflächenbefunde (nicht blockierend): Projekt-Bearbeiten nur im Überlaufmenü „Weitere“; Fenstertitel behält nach dem Löschen den alten Namen; deutsche Reste in der englischen Oberfläche („29. Okt.“, „Anzeigen“, „Kopieren“, „Weitere“); Toolbar in der Vorlagen-Ansicht über der mittleren Spalte.
