# Projektplan

## Project

- schema: app-workflow/1
- profile: macos
- template_version: 1.1.0
- targets: macos
- goal: Secretariat 0.1: native lokale Mac-App für Keychain-Schlüssel, Projektprofile und Terminalstart; Legacy archiviert, lokale Installation und Entfernung sowie echte UI- und Prozessabläufe geprüft

## Personalization

| ID | Value | Source | Reason |
| --- | --- | --- | --- |
| language | Deutsch | user:AGENTS.md | Direkte verständliche Zusammenarbeit |
| collaboration | Autonom bis lokal geprüft | user:ok baue es so | Freigegebenen Vorschlag vollständig ausführen |
| code_conventions | Swift 6, SwiftPM, Swift Testing | default:native Plattform | Kleiner Codebestand ohne Fremdpakete |
| graphic_style | Native Systemfarben, Icon mit Grün und Gold | default:Plattformkonvention | Systemkomponenten und klarer Fokus |
| design_skill | build-macos-apps | session:verfügbare Skills | Native Fenster und Build-Prüfung |
| brand_assets | Eigenes gezeichnetes S/Schlüssel-Icon | default:Originalgrafik | Keine fremden Seriengrafiken |
| bundle_prefix | dev.moinsen.secretariat.local | project:neuer Namespace | Keine Vermischung mit Legacy-Tresor |
| github_user | NONE | user:lokaler Auftrag | Kein neuer Remote beauftragt |
| github_org | moinsen-dev für Legacy | project:archivierter git remote | Legacy-Remote erhalten; Neustart lokal |
| repo_visibility | NONE | user:lokaler Auftrag | Keine Veröffentlichung |
| preferred_stack | Swift + SwiftUI | user:akzeptiertes Konzept | Native Minimalversion ohne Flutter |
| preferred_services | macOS Keychain | user:akzeptiertes Konzept | Lokale vorhandene sichere Ablage |
| localization | de-DE | default:Erstnutzer | Deutsche Oberfläche und Hilfetexte |
| release_defaults | macos:local:local | user:akzeptiertes Konzept | Lokales App-Paket und Terminalzugang |

## Delivery

| ID | Platform | Channel | Goal | AppID | Owner | Tasks |
| --- | --- | --- | --- | --- | --- | --- |
| D001 | macos | local | local | dev.moinsen.secretariat.local | Udi, lokale Developer-ID-Signatur | T006 |

## Requirements

| ID | Outcome |
|---|---|
| R001 | Vollständiges Legacy-Archiv mit Git-Historie und ungecommiteter Arbeit |
| R002 | Native App mit eigener Identität und lokalem Keychain-Namespace, ohne Daemon oder Autostart |
| R003 | Schlüssel anlegen, ändern, löschen; verwendete Schlüssel vor Löschung schützen |
| R004 | Projektordner und eigene Variablenzuordnungen je Profil speichern und bearbeiten |
| R005 | Terminalkommando startet explizites Programm mit Schlüsseln ohne Codeänderung, erhält I/O, Signale und Exitcode |
| R006 | Nach Neustart beständig, keine Secretwerte in Konfiguration oder kopierten Befehlen; Fehler starten keinen Zielprozess |
| R007 | Lokale Installation und Entfernung samt normaler UI-Bedienung und echtem Entwicklungsprojekt geprüft |

## Phases

| ID | Order | Outcome | Depends |
|---|---|---|---|
| P01 | 1 | Legacy erhalten und ausführbarer Plan | - |
| P02 | 2 | Signiertes Bundle mit funktionierendem Keychain- und CLI-Kern | P01 |
| P03 | 3 | Schlüssel- und Profilverwaltung vollständig bedienbar | P02 |
| P04 | 4 | Zusammenhängender Neustart- und Entwicklungsablauf geprüft | P03 |
| P05 | 5 | Lokale Installation, Entfernung und Übergabe | P04 |

## UseCases

| ID | Phase | Outcome | Requirements | Review |
|---|---|---|---|---|
| UC01 | P01 | Archiv und begrenzter Plan erhalten alle Arbeit | R001,R002,R007 | required |
| UC02 | P02 | App-Paket öffnen und Keychain-/Prozesszugriff beweisen | R002,R005,R006 | required |
| UC03 | P03 | Schlüssel und Profile in der nativen Oberfläche verwalten | R003,R004,R006 | required |
| UC04 | P04 | Terminalablauf, Fehler und Neustart vollständig prüfen | R003,R004,R005,R006,R007 | required |
| UC05 | P05 | App lokal installieren, entfernen und wieder öffnen | R002,R007 | required |

## Tasks

| ID | Phase | UseCase | Requirements | Accept | Verify | Mode | Depends | Files |
|---|---|---|---|---|---|---|---|---|
| T001 | P01 | UC01 | R001,R002,R007 | 268 archivierte Dateien verifiziert, Scope und gesamte Prüfung konkretisiert | inspection | normal | - | docs/legacy-archive.md,docs/secretariat-minimal-concept.md |
| T002 | P02 | UC02 | R002,R005,R006 | Signiertes App-Paket öffnet normal; echte Keychain-Testwerte und CLI-Start im selben Paket funktionieren; simulierte Verweigerung verhindert Start | build,unit,macos | normal | T001 | Package.swift,Sources/SecretariatCore/Models.swift,Sources/SecretariatCore/Storage.swift,Sources/SecretariatCore/Keychain.swift,Sources/SecretariatCore/Launcher.swift,Sources/Secretariat/Entry.swift,script/build.sh,Resources/Info.plist,Sources/Secretariat/AppModel.swift,Sources/Secretariat/Editors.swift,Sources/Secretariat/Views.swift,Assets/AppIcon.icns |
| T003 | P03 | UC03 | R003,R004,R006 | UI speichert und ändert Schlüssel und Profilbindungen; ungültige Eingaben und Löschen verwendeter Schlüssel sind bedienbar abgesichert; externe Änderungen werden erkannt | macos,unit | normal | T002 | Sources/Secretariat/AppModel.swift,Sources/Secretariat/Views.swift,Sources/Secretariat/Editors.swift,Sources/SecretariatCore/Models.swift,Sources/SecretariatCore/Storage.swift,Sources/SecretariatCore/Keychain.swift,Assets/AppIcon.icns,Sources/Secretariat/Entry.swift,Package.swift,script/draw_icon.swift |
| T004 | P04 | UC04 | R005,R006 | Paket-CLI übergibt Testwerte korrekt, trennt Profile, übernimmt Änderungen, erhält stdin/stdout/Exitcode und Ctrl-C; echtes fehlendes Credential und simulierte Zugriffsverweigerung verhindern den Start; OS-Sperrdialog ist separat als Prüfgrenze dokumentiert; beschädigte Konfiguration bleibt unverändert | unit | normal | T003 | Sources/SecretariatCore/Launcher.swift,Sources/SecretariatCore/Storage.swift,Sources/SecretariatCore/Keychain.swift,Tests/SecretariatCoreTests/CoreTests.swift,script/integration_check.py,Package.swift,Sources/SecretariatCore/Models.swift,Sources/Secretariat/Entry.swift |
| T005 | P04 | UC04 | R003,R004,R006,R007 | Frischer kompletter UI-Ablauf samt Neustart, schmalem Fenster und kopiertem Startbefehl; vorhandenes echtes Entwicklungsprojekt startet mit künstlichem Credential | macos | normal | T003 | Sources/Secretariat/Entry.swift,Sources/Secretariat/AppModel.swift,Sources/Secretariat/Views.swift,Sources/Secretariat/Editors.swift,Sources/SecretariatCore/Storage.swift,Sources/SecretariatCore/Launcher.swift,Sources/SecretariatCore/Keychain.swift,Sources/SecretariatCore/Models.swift,Package.swift,script/build.sh,Resources/Info.plist,Assets/AppIcon.icns |
| T006 | P05 | UC05 | R002,R007 | Installation und Entfernung samt erneutem Installieren ohne Autostart geprüft; installiertes Bundle normal geöffnet und bedient; fremde Apps oder Terminaldateien werden nicht überschrieben | inspection,macos | normal | T004,T005 | script/install.py,script/install.sh,script/uninstall.sh,script/build.sh,Resources/Info.plist,Assets/AppIcon.icns,README.md,Sources/Secretariat/Entry.swift,Sources/Secretariat/Views.swift,Sources/Secretariat/AppModel.swift,Sources/Secretariat/Editors.swift,Sources/SecretariatCore/Keychain.swift,Sources/SecretariatCore/Launcher.swift,Sources/SecretariatCore/Models.swift,Sources/SecretariatCore/Storage.swift,Package.swift |

## Modules

| ID | Applies | Reason |
| --- | --- | --- |
| auth | NO | OS-Schlüsselbund statt eigener Konten oder Sitzungen; Zugriffsschutz in T002/T004 |
| remote | NO | Vollständig lokal |
| sync | NO | Nur ein Mac |
| ai | NO | Keine Modelle oder Agentenfunktionen |
| payments | NO | Keine Käufe |
| sensors | NO | Keine Sensoren |
| notify | NO | Kein Autostart, Hintergrunddienst oder Mitteilungen |
| files | YES | Benutzer wählt Projektordner, Abbruch und fehlenden Ordner prüfen |

## Checklist

| ID | Check | Applies | Tasks | Reason |
| --- | --- | --- | --- | --- |
| CORE-001 | Nutzerziel und beobachtbare Abschlusskriterien | YES | T001 | Im begrenzten lokalen Produktumfang prüfen |
| CORE-002 | Ist-Zustand, bestehende Anweisungen und Toolchain | YES | T001 | Im begrenzten lokalen Produktumfang prüfen |
| CORE-003 | Zielplattformen, App-Modus und Auslieferungsziel | YES | T001 | Im begrenzten lokalen Produktumfang prüfen |
| CORE-004 | Phasen, Abhängigkeiten und Wiederaufnahme | YES | T001 | Im begrenzten lokalen Produktumfang prüfen |
| CORE-005 | Startbare App und verständlicher Einstieg | YES | T002 | Im begrenzten lokalen Produktumfang prüfen |
| CORE-006 | Navigation und komplette Kernabläufe | YES | T003,T005 | Im begrenzten lokalen Produktumfang prüfen |
| CORE-007 | Leere Daten, Fehler, Abbruch und erneuter Versuch | YES | T003,T004 | Im begrenzten lokalen Produktumfang prüfen |
| CORE-008 | Eingaben, Validierung und Mehrfachaktionen | YES | T003 | Im begrenzten lokalen Produktumfang prüfen |
| CORE-009 | Verständliche, zugängliche und passende Darstellung | YES | T003,T005 | Im begrenzten lokalen Produktumfang prüfen |
| CORE-010 | Datenhaltung und Wiederöffnen | YES | T005 | Im begrenzten lokalen Produktumfang prüfen |
| CORE-011 | Offline-Verhalten und Wiederverbindung | NO | - | Keine Netzverbindung oder Legacy-Schemamigration; eigener neuer Datenbereich |
| CORE-012 | Löschen, Rückgängig oder Wiederherstellung | YES | T003 | Im begrenzten lokalen Produktumfang prüfen |
| CORE-013 | Datenzugriff, Geheimnisse und minimale Protokolle | YES | T002,T004 | Im begrenzten lokalen Produktumfang prüfen |
| CORE-014 | Daten- und Schemaänderungen | NO | - | Keine Netzverbindung oder Legacy-Schemamigration; eigener neuer Datenbereich |
| CORE-015 | Zusammenhängender Nutzerablauf und unabhängige Kritik | YES | T005 | Im begrenzten lokalen Produktumfang prüfen |
| CORE-016 | Reaktionsfähigkeit und längere Abläufe | YES | T004 | Im begrenzten lokalen Produktumfang prüfen |
| CORE-017 | Vereinbarte Installation oder Auslieferung | YES | T006 | Im begrenzten lokalen Produktumfang prüfen |
| CORE-018 | Ehrlicher Abschluss und fortsetzbarer Reststand | YES | T006 | Im begrenzten lokalen Produktumfang prüfen |
| CORE-019 | Persönliche Standards und konkrete Projektentscheidungen | YES | T001 | Im begrenzten lokalen Produktumfang prüfen |
| CORE-020 | App-Identität und Eigentümer | YES | T002 | Im begrenzten lokalen Produktumfang prüfen |
| CORE-021 | App-Icons, Startdarstellung und Grafikressourcen | YES | T003,T006 | Im begrenzten lokalen Produktumfang prüfen |
| CORE-022 | Vollständige Berechtigungsdeklaration | YES | T002 | Im begrenzten lokalen Produktumfang prüfen |
| CORE-023 | Produktionsvoraussetzungen und beauftragter Endzustand | YES | T001 | Im begrenzten lokalen Produktumfang prüfen |
| MACOS-001 | Build-, Bundle- und Signing-Weg | YES | T002 | Im begrenzten lokalen Produktumfang prüfen |
| MACOS-002 | App-Einstieg und Fensterverhalten | YES | T002 | Im begrenzten lokalen Produktumfang prüfen |
| MACOS-003 | Tastatur, Fokus, Größe und Dialoge | YES | T003,T005 | Im begrenzten lokalen Produktumfang prüfen |
| MACOS-004 | Systemrechte und konkrete Aktionsziele | YES | T002,T003 | Im begrenzten lokalen Produktumfang prüfen |
| MACOS-005 | Fenster schließen, App-Neustart und Wiederaufnahme | YES | T005 | Im begrenzten lokalen Produktumfang prüfen |
| MACOS-006 | Tatsächliches Installations- und Verteilungsziel | YES | T006 | Im begrenzten lokalen Produktumfang prüfen |
| FILES-001 | Auswahl, begrenzter Zugriff und Abbruch | YES | T003 | Im begrenzten lokalen Produktumfang prüfen |
| FILES-002 | Fehlerhafter Import oder unterbrochener Export | YES | T004 | Im begrenzten lokalen Produktumfang prüfen |

## Entscheidungen

- Altprojekt wurde vollständig nach `_archive/Secretariat-legacy-2026-10-22_16-08-57` verschoben. Der alte Workspace-Pfad verweist auf diesen frischen Projektordner.
- SwiftPM, macOS 14+, native SwiftUI-Oberfläche, ein App-Executable mit CLI-Modus. Bestehende Developer-ID-Signatur lokal, keine Notarisierung oder Store-Veröffentlichung beauftragt.
- CLI ersetzt sich nach erfolgreicher Vorbereitung per exec durch den Zielprozess. Dadurch bleiben Terminal-I/O, Prozessgruppe und Signalverhalten erhalten; es gibt keinen dauerhaften Launcherprozess.
- Profile sind bewusste Benutzerauswahl, keine Sicherheitsidentität. Zielprozesse erhalten echte Werte und können diese ausgeben. Keine Zusage von Agent-Isolation oder obligatorischer Touch-ID bei jedem Lesen.
- Neuer Keychain-Service und neue Konfiguration; Legacy-Daten bleiben erhalten. Tests nutzen eindeutig getrennte Namespaces mit künstlichen Werten.
- Installation unter `~/Applications/Secretariat.app`, Terminalverweis `~/bin/secretariat`. Entfernen erhält Daten; keine globalen LaunchAgents, PATH-Änderungen oder Systemdienste.
- Eigene gezeichnete Icon-Ressource; ein ruhiges natives Fenster mit zugänglichen System-Controls. Kein Serienmaterial übernommen.

## Permissions

| Capability | Zweck und Daten | Deklaration | Tasks |
|---|---|---|---|
| Keychain | Vom Nutzer eingetragene lokale Schlüssel, nicht synchronisiert | Signiertes App-Paket, System-Keychain-Zugriffsregeln; bei gesperrter oder verweigerter Ablage verständlicher Fehler | T002,T004 |
| Dateizugriff | Gewählter Projektordner und app-eigene Metadaten | Nativer Ordnerdialog über fileImporter, bewusst lokale nicht sandboxed Entwicklungs-App; keine TCC-weiten Zusatzrechte | T003,T005 |
| Prozessstart | Expliziter Terminalbefehl im Profilordner | Normaler Nutzerprozess, keine privilegierten Helfer | T002,T004 |

Für lokale Fertigstellung sind keine neuen Anbieter-Konten, Kosten oder externen Freigaben nötig. Weitergabe außerhalb dieses Macs verlangt gesonderte Signatur-/Notarisierungsprüfung.

## Datenintegrität

Metadaten werden unter exklusiver Schreibsperre atomar ersetzt. UI-Mutationen vergleichen die geladene Revision; veraltete Formulare müssen neu geladen werden. Beschädigte oder unbekannte Konfiguration wird erhalten und als Fehler angezeigt. Installation und Entfernung überprüfen App-Identität und Zielverweis; fremde Dateien bleiben erhalten. T003, T004 und T006 prüfen diese Fälle.
