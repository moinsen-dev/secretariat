# Secretariat

Eine kleine native Mac-App: API-Schlüssel einmal hinterlegen, Projektprofil auswählen und im Terminal starten.

## Benutzen

1. In Secretariat einen Schlüssel hinzufügen. Sein Wert liegt im macOS-Schlüsselbund.
2. Ein Projektprofil anlegen: Name, Projektordner und Variablenzuordnungen auswählen. Den gewünschten Startbefehl eintragen.
3. „Terminalaufruf kopieren“ wählen und den Aufruf im Terminal ausführen.

Alternativ nach der lokalen Installation:

```sh
secretariat profiles
secretariat run mein-projekt -- pnpm dev
```

Ein Schlüssel kann mehreren Profilen zugeordnet werden. Änderungen gelten für den nächsten Programmstart. Bereits laufende Prozesse behalten ihre bisherigen Werte.

## Mit Codex, Claude Code und OpenCode

Wähle im Projektprofil **Coding-System einrichten**. Prüfe die Vorschau und klicke **Im Projekt einrichten**. Secretariat ergänzt einen eigenen Abschnitt in `AGENTS.md` sowie einen Verweis in `CLAUDE.md`. Bestehende Inhalte bleiben erhalten; die Einrichtung lässt sich wiederholen. Das gilt für lokale Sitzungen auf diesem Mac.

Dasselbe geht per CLI:

```sh
~/bin/secretariat profiles --json
~/bin/secretariat describe mein-projekt --json
~/bin/secretariat check mein-projekt --json
~/bin/secretariat setup mein-projekt --dry-run
~/bin/secretariat setup mein-projekt --json
~/bin/secretariat run mein-projekt -- npm test
```

Ab 0.3 verdrahten Agents ein Projekt selbst, ohne die App zu öffnen. Schlüsselwerte bleiben dabei ausschließlich in der App:

```sh
~/bin/secretariat keys --json                                   # Schlüsselnamen, nie Werte
~/bin/secretariat profile create mein-projekt --dir . --command "pnpm dev"
~/bin/secretariat profile bind mein-projekt GEMINI_API_KEY "Gemini"
~/bin/secretariat profile set mein-projekt --command "pnpm test"
~/bin/secretariat profile unbind mein-projekt GEMINI_API_KEY
~/bin/secretariat profile delete mein-projekt
```

Fehlercodes: `profile_exists`, `profile_not_found`, `key_not_found`, `variable_not_bound`, `invalid_profile`, `invalid_arguments`.

`instructions mein-projekt` gibt nur die Anleitung zum Kopieren aus. Vorschau, Auskunft und Einrichtung lesen keine Schlüsselwerte. `check` verwendet nichtinteraktiven Keychain-Zugriff, meldet `available`, `missing`, `invalid` oder `unavailable` je Variable und startet kein Programm. Antwortet macOS nicht innerhalb von zehn Sekunden, endet die CLI mit `keychain_timeout` und Exitcode 2. Bei einem nicht bereiten Profil: Ordner oder Schlüssel in der App prüfen. Auch `run` arbeitet ohne Authentifizierungsdialog. Fehlt die Berechtigung oder ist der Schlüsselbund gesperrt, bricht der Start ab. Freigaben gehören in die geöffnete Secretariat-App; die CLI entsperrt den Schlüsselbund nicht.

JSON-Antworten der Verwaltungsbefehle haben `schemaVersion: 1` und `ok`. Fehler enthalten `error.code` und `error.message`. Exitcodes: `0` erfolgreich/bereit, `2` nicht bereit bei `check`, `1` ungültiger Aufruf oder fehlgeschlagene Verwaltung. `run` erhält den Exitcode des Zielprogramms. Schlüsselwerte sind kein Bestandteil der Auskunft; ein optionaler `keychainStatus` ist ausschließlich ein numerischer macOS-Fehlercode.

Die Einrichtung stoppt bei fremden Profilmarkern, beschädigten Abschnitten, Symlinks, Hardlinks, nicht lesbaren Dateien oder erkannten Änderungen seit der Vorschau. Sie ersetzt Dateien atomar und stellt bei normalen Fehlern die erste Änderung wieder her. Gegen nicht kooperierende Editoren bleibt ein kleines Zeitfenster zwischen letztem Vergleich und Dateitausch; die zwei Dateien bilden keine gemeinsame absturzsichere Transaktion. Globale Agenten-Konfigurationen werden nicht geändert.

Die Coding-Sitzung bleibt bei ihrer normalen Anmeldung. Projekt-Credentials erhält der konkrete Test- oder Entwicklungsprozess. Frei ausführbarer Code kann seine Umgebung dennoch ausgeben; die Anweisung ist keine Zugriffssperre. MCP und Cloud-Zugriff sind kein Teil dieser Version.

## Lokal bauen und starten

Voraussetzungen: macOS 14 oder neuer, Xcode/Swift 6.2 oder neuer und die macOS-Kommandozeilenwerkzeuge. Keine Paketabhängigkeiten.

```sh
./script/build_and_run.sh
swift test
```

Standardtests verwenden künstliche CredentialStores und sperren keinen Schlüsselbund. Ein echter ungesperrter Keychain-Roundtrip ist nur mit `SECRETARIAT_RUN_KEYCHAIN_TESTS=1 swift test` aktiviert; normale macOS-Zugriffsabfragen sind dabei möglich. Die dokumentierte lokale Abnahme steht in [docs/acceptance.md](docs/acceptance.md).

Der Run-Button in Codex verwendet dasselbe Skript. Das App-Paket liegt unter `dist/Secretariat.app`. Das Buildskript verwendet eine vorhandene Developer-ID-Application-Identität; ohne eine solche Identität signiert es lokal ad hoc. Die aktuelle lokale Abnahme verwendet Developer-ID-Signierung, keine Notarisierung.

## Installieren und entfernen

```sh
./script/install.sh
open ~/Applications/Secretariat.app
./script/uninstall.sh
```

Installationsorte: `~/Applications/Secretariat.app` und `~/bin/secretariat`. Der kopierte Terminalaufruf verwendet einen absoluten Pfad und funktioniert auch ohne `~/bin` im PATH. Es werden keine Shell-Profile, LaunchAgents oder Hintergrunddienste eingerichtet. Bereits belegte fremde Installationspfade werden nicht überschrieben.

Beim Entfernen landet das App-Paket im Papierkorb. Schlüssel und Profile bleiben erhalten. Die Quellskripte erlauben mit `--app-dir` und `--bin-dir` auch isolierte Installationsprüfungen.

## Daten und Grenzen

- Metadaten: `~/Library/Application Support/SecretariatLocal/profiles.json`; Datei-Modus 0600.
- Schlüsselwerte: nicht synchronisierte generische Passworteinträge im macOS-Schlüsselbund, Service `dev.moinsen.secretariat.local.v1.<Pfad-Hash>`.
- Eigener Speicherbereich: keine automatische Übernahme alter Secretariat-Tresore oder iCloud-Daten. Der Schlüsselbund-Zugriff richtet sich nach macOS und der signierten Anwendung. Es wird keine obligatorische Touch-ID-Abfrage bei jedem Start versprochen.
- Konfiguration und kopierte Aufrufe enthalten keine von Secretariat eingesetzten Schlüsselwerte. Das gestartete Programm und seine Unterprozesse erhalten echte Werte und können sie selbst ausgeben. Secretariat ist keine Sandbox für Agenten mit Shell-Zugriff.
- Schreibsperre, atomarer Dateiersatz und Formularrevisionen schützen Metadaten. Bei normalen Speicherfehlern nach einer Schlüsseländerung wird der vorherige Wert wiederhergestellt. Keychain und JSON bilden keine gemeinsame absturzsichere Datenbanktransaktion; ein Prozessabbruch zwischen beiden Änderungen ist eine verbleibende lokale Grenze.
- Für getrennte Testbestände kann `SECRETARIAT_HOME` auf ein anderes Verzeichnis zeigen; daraus folgt ein eigener Keychain-Service. Das ist keine zusätzliche Sicherheitsgrenze gegenüber demselben Mac-Nutzer.

Architektur: ein SwiftPM-Projekt, native SwiftUI-Oberfläche und CLI-Modus im selben App-Executable. Beim Start ersetzt sich die CLI durch den Zielprozess; Terminal-I/O, Prozessgruppe und Exitcode bleiben erhalten.

Der vollständige Altstand ist im [Legacy-Archiv](docs/legacy-archive.md) dokumentiert. Anforderungen und tatsächliche Prüfnachweise liegen in [PLAN.md](PLAN.md) und [TRACKER.md](TRACKER.md).
