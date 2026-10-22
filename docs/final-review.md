# Abschließende unabhängige Prüfung

Zeit: 2026-10-22T17:29:34+02:00. Prüfer: delegierter Kritiker.
Geprüfter Plan SHA-256: `9c487d954f7301d488a86b118b819963364ae9be78b749852b9812cca909ba37`.
Geprüft: aktueller Plan, Quellen, Tests/Prüfskripte, README, `docs/acceptance.md`, frühere unabhängige Archiv-/Coreberichte, reales Projekt-Prüfartefakt und installiertes App-Paket.

**Gesamturteil: PASS für den dokumentierten lokalen Minimalumfang.** Keine offenen blockierenden Befunde. Die Einzelurteile beruhen auf unabhängiger Quell-/Artefaktprüfung und auf den ausdrücklich vom implementierenden Agenten beobachteten Nutzerabläufen. Sie behaupten keine unabhängige Wiederholung der UI-Abnahme.

## Einzelurteile

| Scope | Urteil | Maßgebliche Prüfung und Grenzen |
|---|---|---|
| PLAN | PASS | Nutzerauftrag auf drei Kernfunktionen begrenzt, Legacy archiviert, nativer Stack, lokale Lieferung, kein neuer Dienst/Autostart. Simulierte Verweigerung und nicht abgenommener OS-Sperrdialog werden jetzt getrennt benannt. Native Systemfarben und tatsächlicher fileImporter sind korrekt beschrieben. Files-Abhängigkeiten wurden bei dieser Review ergänzt. |
| UC01 | PASS | Frühere unabhängige Prüfung bestätigte 268/268 Hashes/Größen sowie Legacy-HEAD/Branch und Workspace-Alias. Vollständigkeitsgrenze der Inventory-Liste ist dokumentiert. Kein erneutes Lesen archivierter Inhalte nötig. |
| UC02 | PASS | Unabhängige Coreprüfung ohne verbleibenden Blocker. Installiertes und gebautes Executable unabhängig gehasht, Signatur/Metadaten geprüft. Tatsächliches Anlegen und Lesen künstlicher Werte durch dasselbe signierte Paket sowie GUI-Start berichtet der implementierende Agent. Mock-Verweigerung ist kein echter OS-Sperrtest. |
| UC03 | PASS | Quellprüfung bestätigt SecureField, Keychain-/Metadatenaufteilung, Validierung, Schutz benutzter Schlüssel, formuliergebundene Revision, Reparatur fehlender Werte und Fehlerrollback. Normale UI-Verwaltung, sichtbare Fehler/Korrektur, Ordnerauswahl, Abbruch, Wertänderung und abschließendes Löschen sind in acceptance.md als beobachtete Abläufe dokumentiert; nicht unabhängig wiederholt. |
| UC04 | PASS | Integrationstest deckt Paket-CLI, cwd, Environment, stdin/stdout/Exitcode, wörtliche Argumente, echte fehlende Credentials, PTY-Ctrl-C und beschädigte JSON-Daten konkret ab. Bericht nennt acht erfolgreiche Checks und Wiederholung nach Wertänderung. Unabhängig gelesenes `.artifacts/real-project-check.json` hält Stillday-Start, künstliches Credential, HTTP 200/1341 Bytes und Prozessende fest. Neustart und Scrollen sind als Root-Beobachtungen klar gekennzeichnet. |
| UC05 | PASS | Installationsquellen schützen fremde Pfade und erhalten Daten; Entfernung verschiebt eigene App in Papierkorb. Bericht dokumentiert Installieren/Entfernen/Neuinstallieren und Konfliktprüfungen. Das final installierte Paket und CLI-Ziel wurden unabhängig lesend bestätigt. Kein öffentlicher Vertrieb beauftragt. |

## Unabhängige Artefaktbefunde

- `dist/Secretariat.app/Contents/MacOS/Secretariat` und `~/Applications/Secretariat.app/Contents/MacOS/Secretariat` sind identisch: SHA-256 `e360dc03836bccdb624a5f167a141ad9cecb92d6094a61285eadc656e8f0bc5f`.
- `codesign --verify --deep --strict ~/Applications/Secretariat.app` erfolgreich. Developer ID Application: Ulrich Diedrichsen, Team `VXX45ZYNM8`; Hardened Runtime, arm64. Keine zusätzlichen Entitlements ausgegeben.
- Bundle-ID `dev.moinsen.secretariat.local`, Version `0.1.0` / Build `1`, Minimum macOS `14.0`, Icondatei vorhanden.
- `~/bin/secretariat` ist ein Symlink exakt auf das installierte Executable. Kopierte Aufrufe verwenden absolute Pfade.
- `script/build.sh` verwendet den lokalen SwiftPM-Standardbuild ohne `-c release`. Die zuvor ungenaue Bezeichnung „Release-Build“ wurde im Abnahmebericht korrigiert; das lokale Auslieferungsziel verlangt keine andere Optimierungsstufe.

## Nachweisgrenzen und konkrete Restpunkte

1. **OS-Schlüsselbunddialog:** Tatsächlich gesperrter Keychain-Zugriff ist nicht abgenommen. Der frühere Test führte zu einem Passwortdialog, wurde beendet und entfernt. Aktuelle Standardtests sperren/erzeugen keine Schlüsselbünde. Verweigerungs-Mocks belegen Anwendungsabbruch; mögliche macOS-Berechtigungsdialoge bleiben eine Systemgrenze. Diese Schlussprüfung hat keine UI-/Keychain-Tests gestartet und keine Credentials gelesen, erzeugt oder gesperrt.
2. **Fenster:** Standardfenster und etwa 960px-Kachel, zwölf Zuordnungen mit Scrollen, Schließen/Beenden/Neustart sind berichtet. Exakte Mindestgröße 760×500 und Dock-Reopen einer noch laufenden App ohne Fenster werden ausdrücklich nicht als visuell abgenommen behauptet. Kein blockierender Quellbefund daraus ersichtlich.
3. **Daten/Verteilung:** Normale Speicherfehler werden zurückgerollt; Keychain und JSON sind keine gemeinsame absturzsichere Transaktion. Zielprogramme erhalten echte Werte; keine Agent-Isolation. Kein öffentlicher Release und keine Notarisierung behauptet.
4. **Formaler Abschluss:** Beim letzten Leseabgleich sind E002–E011 mit den zugehörigen normalen Prüfmethoden und L001 als LOCAL-Release für den bestätigten Paketstand registriert. T002–T006 warten noch auf die Eintragung dieser Kritik, danach Aufgabenabschluss und State-Neuberechnung durch Root. Die Quell-/Artefaktfreigabe ersetzt diesen letzten Dokumentationsschritt nicht.

Keine neuen Funktionsanforderungen oder externen Freigaben erforderlich. Die ergänzten Files-Listen erfassen für Paketabnahmen jetzt alle App-/Corequellen sowie Package, Buildskript, Info.plist und Icon; T003 erfasst zusätzlich die Icon-Erzeugung, T004 Models und CLI-Entry. Sonstige Planinhalte und Implementierung blieben unverändert.
