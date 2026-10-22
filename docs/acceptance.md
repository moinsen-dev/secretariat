# Lokale Abnahme Secretariat 0.1.0

Stand: 22.10.2026, 17:27 CEST. Durchführender: implementierender Agent. Modus: normale native App und installiertes signiertes Paket; ausschließlich künstliche Testschlüssel. Quellkritik separat in `core-review.md`; diese Beobachtungen sind keine unabhängig wiederholte UI-Prüfung.

## Umgebung und geprüfter Stand

- macOS 27.0.1, Apple Silicon, Xcode 27.1 / Swift 6.4; Ziel macOS 14+.
- `dist/Secretariat.app` und `~/Applications/Secretariat.app` enthalten identische Executables, SHA-256 **e360dc03836bccdb624a5f167a141ad9cecb92d6094a61285eadc656e8f0bc5f**.
- Developer ID Application, Team VXX45ZYNM8; `codesign --verify --deep --strict` erfolgreich. Bundle-ID `dev.moinsen.secretariat.local`, Version 0.1.0 (1), Icon vorhanden, Minimum 14.0. Keine Entitlements oder Usage-Descriptions für zusätzliche TCC-Rechte erforderlich; lokale App ohne Sandbox, Sensorzugriff, Netzwerkdienst oder privilegierte Helfer. Keine Notarisierung beauftragt.
- Terminalverweis `~/bin/secretariat` zeigt exakt auf das installierte Executable. Kopierte Aufrufe verwenden einen absoluten Pfad und benötigen keine PATH-Änderung.

## T001 / UC01: Archiv

`archive-evidence.md` bestätigt unabhängig 268/268 Dateihashes und Größen, Legacy-HEAD und Branch. Vollständiger alter Ordner samt `.git` und ignorierten Build-Dateien wurde verschoben; die 268-Hash-Aussage betrifft die inventarisierten Dateien. Quellpfad ist jetzt `Secretariat`; alter Workspace-Pfad ist ein Symlink dorthin. Das unveränderte Legacy-Archiv bleibt erhalten. Konzept und aktueller Plan entsprechen dem begrenzten nativen Neustart, ohne neuen Remote.

## T002 / UC02: Paket, Keychain und Prozesskern

1. `script/build.sh`: lokaler Swift-Build, Bundle und gültige Developer-ID-Signatur; normaler Start als Mac-App beobachtet.
2. In der signierten App künstlichen Schlüssel angelegt und über dasselbe installierte Executable gelesen. App beenden, CLI weiterhin nutzbar; nach Neuinstallation Eintrag weiter verfügbar. Wertänderung in der App gilt beim nächsten CLI-Start.
3. Letzter Standardlauf `swift test` am 22.10.2026 um 17:20:07: **11 Tests bestanden, 1 optionaler echter Keychain-Test übersprungen**, keine Fehler. Der optionale ungesperrte Keychain-Roundtrip war vor seiner Opt-in-Markierung erfolgreich; er wird für den aktuellen Standardlauf ausdrücklich nicht als ausgeführt gezählt.
4. Fehlende echte Keychain-Referenz beendet den Launcher, bevor ein Zielprozess entsteht. Simulierte Zugriffsverweigerung verhindert bereits das Vorbereiten eines Starts. Kein echter gesperrter Login-Schlüsselbund wurde geprüft.

## T003 / UC03: Schlüssel und Profile

Normale UI-Bedienung durch Computer Use, keine UI-Test-Sonderansicht:

- Leerer Start, Schlüssel hinzufügen, verdecktes SecureField, Profil mit nativer Ordnerauswahl erstellen, Variable dem Schlüssel zuordnen, speichern.
- Profilordner DailyInspirations gewählt, gespeichert und nach Neustart erneut sichtbar. Benutzerdefinierter Startbefehl editierbar; Abbruch einer ungespeicherten Änderung erhält den vorherigen Befehl.
- Referenzierten Schlüssel löschen versucht: Bestätigung, anschließend verständlicher Fehler mit Profilname; Schlüssel bleibt erhalten. Schlüsselwert im Editor geändert, gespeichert und folgenden Start mit neuem Wert verifiziert.
- Ungültiger Profilname führt zu sichtbarem Inlinefehler; Korrektur und erneutes Speichern erfolgreich.
- Shell-Aufruf kopiert und in ungespeichertes Feld eingefügt: absoluter Launcher, Profil und expliziter zsh-Befehl, kein eingesetzter Schlüsselwert. Entwurf anschließend verworfen.
- Standardfenster 990×650 sowie native Kachel mit etwa 960 px Breite betrachtet. Mit zwölf Testzuordnungen sind auch die unteren Aktionen per Scrollen erreichbar. Exakte Mindestgröße 760×500 ist im Code festgelegt, hier nicht als separat visuell abgenommen ausgegeben. Systemakzent verbessert Lesbarkeit im dunklen Modus.
- Standardtests decken doppelte/ungültige Variablen, veraltete Revision vor Credential-Mutation, gleiche Variable in getrennten Profilen, Löschen referenzierter Schlüssel, Reparatur fehlender Werte sowie Rollback bei echtem Dateispeicherfehler mit Memory-CredentialStore ab.

## T004 / UC04: Paket-CLI und Fehler

`script/integration_check.py` mit installiertem Paket und ausschließlich künstlichem, zuvor in der UI angelegtem Schlüssel ausgeführt. Acht erfolgreiche Prüfungen:

1. Arbeitsordner, injizierte Umgebung, stdin/stdout und Exitcode 7 korrekt.
2. Derselbe Schlüssel ist in zwei Profilen verfügbar.
3. Argumente mit Leerzeichen, Quotes und Shellsyntax bleiben wörtlich; keine implizite Shellausführung.
4. Unbekanntes Profil und fehlendes Programm scheitern.
5. Echtes fehlendes Keychain-Credential verhindert das Anlegen einer Zielprozess-Markerdatei.
6. Echtes PTY und eingegebenes Ctrl-C erreichen den Zielprozess; dessen Signalhandler beendet ihn mit Code 42.
7. Ungültige JSON-Konfiguration wird als Fehler gemeldet und bytegenau erhalten.
8. Metadaten enthalten keinen künstlichen Credentialwert.

Nach Änderung des UI-Schlüsselwerts mit der neuen Erwartung erneut erfolgreich ausgeführt. Ursprüngliche Metadaten wurden nach jedem Durchlauf wiederhergestellt. Unit-Tests ergänzen getrennte Profile, Dateimodus 0600, Namespaces, unbekannte Schemaversion, Schreibfehler-Rollback und simulierte Verweigerung. Die CLI ersetzt sich per execve, daher bleibt kein Wrapper-Daemon zurück.

## T005 / UC04: echter Entwicklungsablauf und Neustart

- Tatsächliches vorhandenes Expo-Projekt `/Users/udi/work/moinsen/ideas/DailyInspirations` (Stillday), künstliche Variable im gestarteten Prozess vor Start von Expo geprüft.
- Über installiertes Secretariat im gewählten Projektordner gestartet; direkter Node-Aufruf des vorhandenen Expo-CLI, Offlinebetrieb und lokale Bindung. HTML von `http://localhost:18186` mit **HTTP 200**, 1341 Bytes empfangen. Server anschließend beendet.
- Maschinenlesbares Ergebnis unter `.artifacts/real-project-check.json`, Buildlog lokal ignoriert. Keine echten Anbieter-Credentials verwendet und keine neue App-Version veröffentlicht.
- Temporär erzeugte pnpm-Lockdatei entfernt, npm-Abhängigkeiten aus vorhandenem Lock wiederhergestellt. Fremdprojekt anschließend ausschließlich mit vorbestehendem `?? .pumuckl`; keine Quelländerung.
- App-Neustart und Installation/Entfernung erhalten Profil und Schlüssel. Fenster schließen und danach App beenden/neu starten geprüft. CUA konnte ein geschlossenes Fenster eines noch laufenden Prozesses nicht erneut erfassen; es wird keine separate Dock-Reopen-Abnahme behauptet.
- Zum Schluss künstliches Profil und unreferenzierten künstlichen Schlüssel über die normale UI gelöscht. Leerer Einstieg sichtbar; Metadaten enthalten null Profile und null Schlüssel, Revision 7. Legacy-Credentials unverändert.

## T006 / UC05: lokale Installation und Entfernung

- Installieren, normales Öffnen, Entfernen und erneutes Installieren mit finalem Paket durchgeführt. Letzter Durchlauf etwa 17:20 CEST.
- Entfernung verschiebt eigenes App-Paket in den Papierkorb, entfernt nur den passenden Terminalsymlink und erhält Profile sowie Credentials. Anschließend erneut installiert; Daten weiter verwendbar.
- Isolierte Prüfordner mit fremder Terminaldatei bzw. fremder App-ID werden abgelehnt und bleiben unverändert. Keine globalen Prozessnamen beendet.
- Final installiertes Paket stimmt bytegenau mit dem lokaler Swift-Build überein und ist gültig signiert. Native App nach Neuinstallation normal geöffnet.
- Kein LaunchAgent, Login-Item oder Autostart angelegt; Installer und Quellen enthalten dafür keine Einrichtung. Prozessinventar zum Abschluss zeigt die laufende GUI und Apples `/usr/libexec/secd`, keinen alten Secretariat-Daemon oder swiftpm-testing-helper.

## Passwortdialog und konkrete Prüfgrenzen

Ein zusätzlicher Test mit einem separat erzeugten und gesperrten temporären Testschlüsselbund führte zu dem vom Nutzer gezeigten Passwortdialog. Das ist kein erfolgreich geprüfter Sperrfall. Der eigene Testprozess wurde beendet, der genaue temporäre Schlüsselbund entfernt und der gesamte Sperrtest aus den Quellen entfernt. `security list-keychains -d user` enthält nur den Login-Schlüsselbund; kein Testhelfer läuft mehr. Keine Passwortangabe des Nutzers war erforderlich.

Standardtests erzeugen und sperren keine echten Schlüsselbünde. Der verbleibende echte ungesperrte Roundtrip ist ausdrücklich Opt-in. Mock-Verweigerung belegt die Fehlerbehandlung der App, nicht das Dialogverhalten von macOS. Normale macOS-Keychain-Berechtigungsabfragen bleiben möglich.

Weitere Grenzen: keine obligatorische Touch-ID je Lesen, keine Agent-Isolation, keine gemeinsame absturzsichere Transaktion zwischen Keychain und JSON; gestartete Programme erhalten echte Schlüsselwerte. Lokale Installation ist abgenommen, öffentliche Verteilung oder Notarisierung sind nicht Teil dieses Auftrags.

## Ergebnis

**PASS für den beschriebenen lokalen Minimalumfang**, mit den ausdrücklich genannten Prüfgrenzen. Native Verwaltung, echte Keychain-Nutzung, Paket-Prozessablauf, vorhandenes Entwicklungsprojekt, Datenpersistenz und Installation/Entfernung sind konkret belegt.
