# Projektplan

## Project

- schema: app-workflow/1
- profile: macos
- template_version: 1.1.0
- targets: macos
- goal: Secretariat 0.2: vorhandene native Mac-App um CLI-Auskunft, dialogfreie Profilprüfung und sichere Projektanweisungen für lokale Coding-Systeme erweitern, normal bedienen und lokal installieren

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
| D001 | macos | local | local | dev.moinsen.secretariat.local | Udi, lokale Developer-ID-Signatur | T006,T010 |

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

| R008 | CLI liefert versionierte JSON-Auskunft zu Profilen und Variablennamen sowie strukturierte Fehler ohne Credentialwerte |
| R009 | Profilprüfung meldet Ordner und Credential-Verfügbarkeit ohne Zielprozess, Schreibzugriff oder interaktive Keychain-Abfrage |
| R010 | UI und CLI zeigen Projektanweisungen und richten AGENTS.md plus CLAUDE.md gezielt ein; bestehende Inhalte, andere Profile und Symlinkziele werden geschützt |
| R012 | CLI-Starts und Prüfungen öffnen keine Keychain-Dialoge; fehlende Freigabe bricht ab; Testeinträge und Signieridentität verursachen keine Wiederholschleife |
| R011 | Lokaler Ablauf aus Codex, Claude Code und OpenCode mit künstlichen Werten wird versucht und tatsächliche Tool-, Rechte- und Auth-Grenzen werden getrennt berichtet |
| R013 | CLI `items [--json]` listet Einträge, Felder und Kennungswerte, nie geheime Werte und ohne geheime Werte zu lesen |
| R014 | CLI legt Profile an, ändert Ordner und Startbefehl, ordnet Variablen per Schlüsselname zu, entfernt Zuordnungen und Profile; gleiche Validierung, Sperre und Revision wie die App; keine Schlüsselwerte über die CLI |
| R015 | Schlüssel sind per iCloud-Schlüsselbund auf allen Macs desselben Apple-Accounts verfügbar; der Name reist im Eintrag mit, Profile bleiben je Mac |
| R016 | Bestehende 0.x-Schlüssel und Profile werden ohne Werteverlust und mit erhaltenen Zuordnungen in 1.0-Einträge übernommen (einmaliges Migrationsprogramm, auf jedem Mac wiederholbar) |
| R017 | App und CLI (`~/bin/secretariat`) sind auf M5, M1 und Mac Mini installiert und dort mit check/run geprüft |
| R018 | `secretariat import DATEI VARIABLE[=PFAD/FELD] …` und `import-file DATEI PFAD/FELD` übernehmen Werte bzw. Dateien direkt in Einträge, optional mit Profil-Zuordnung; Ausgabe und Fehler nennen nur Namen; vorhandene Werte nur mit --replace |
| R019 | `item rename` und `field move` strukturieren Einträge um, ohne dass Werte den Prozess verlassen; Profile und Ziele bleiben zugeordnet; Änderungen erreichen alle Macs |
| R020 | Einträge mit Pfad `<org>/<konto>/<name>`, Art und typisierten Feldern (Kennung, Geheimnis, Datei, Nur für mich) liegen je Eintrag in einem synchronisierten Schlüsselbund-Eintrag; Kennungen per `get` lesbar, Geheimnisse nie ausgegeben, Nur-für-mich-Felder erreichen kein Programm |
| R021 | `run` stellt Dateifelder als temporäre 0600-Datei bereit und entfernt sie nach dem Lauf; `inject` setzt Verweise in Vorlagen ein und schreibt nur an Orte, die Git nicht verfolgt |
| R022 | Ziele (Befehl je Variable mit Wert auf stdin, env-Datei per ssh) führen je Variable einen Verteilstand (aktuell, veraltet, nie, fehlt) über gesalzene Prüfsummen; `push` verteilt |
| R023 | Kennungen werden ins Fleet-Register exportiert; `scan` findet .env-Dateien mit Werten (nur Namen) und erkennt gespeicherte; `log` protokolliert nur Namen; die App zeigt Einträge gruppiert mit Detail, Editor, Dateiexport und Zielen |
| R024 | Profile ohne festen Ordner (`--dir '*'`) laufen im aktuellen Ordner (Werkzeug-Tokens); `profile which` findet das Profil eines Ordners; ein Sitzungsstart-Hinweis nennt Agenten Profil oder .env-Geheimnisse; `bulk_import.py` übernimmt viele .env-Dateien nach einer Prüfliste; eine frische Claude-Sitzung nutzt Secretariat ohne Hinweis im Auftrag |

## Phases

| ID | Order | Outcome | Depends |
|---|---|---|---|
| P01 | 1 | Legacy erhalten und ausführbarer Plan | - |
| P02 | 2 | Signiertes Bundle mit funktionierendem Keychain- und CLI-Kern | P01 |
| P03 | 3 | Schlüssel- und Profilverwaltung vollständig bedienbar | P02 |
| P04 | 4 | Zusammenhängender Neustart- und Entwicklungsablauf geprüft | P03 |
| P05 | 5 | Lokale Installation, Entfernung und Übergabe | P04 |

| P06 | 6 | Agenten-Auskunft, Prüfung und Projekteinrichtung | P05 |
| P07 | 7 | Tatsächliche Coding-Systeme und aktualisierte lokale Lieferung | P06 |
| P08 | 8 | Agenten verdrahten Projekte selbst per CLI | P07 |
| P09 | 9 | Schlüssel über iCloud-Schlüsselbund auf allen Macs | P08 |
| P10 | 10 | Installation auf M5, M1 und Mac Mini | P09 |
| P11 | 11 | Agenten übernehmen Werte aus einer .env ohne sie zu sehen | P10 |
| P12 | 12 | Schlüssel einheitlich benennen (Organisation/Konto/Name) | P11 |
| P13 | 13 | Secretariat 1.0: Einträge mit Feldern und Dateien, Ziele, Register | P12 |
| P14 | 14 | Effizienz: Sitzungshinweis, Werkzeug-Profil, Massenübernahme, End-to-End | P13 |

## UseCases

| ID | Phase | Outcome | Requirements | Review |
|---|---|---|---|---|
| UC01 | P01 | Archiv und begrenzter Plan erhalten alle Arbeit | R001,R002,R007 | required |
| UC02 | P02 | App-Paket öffnen und Keychain-/Prozesszugriff beweisen | R002,R005,R006 | required |
| UC03 | P03 | Schlüssel und Profile in der nativen Oberfläche verwalten | R003,R004,R006 | required |
| UC04 | P04 | Terminalablauf, Fehler und Neustart vollständig prüfen | R003,R004,R005,R006,R007 | required |
| UC05 | P05 | App lokal installieren, entfernen und wieder öffnen | R002,R007 | required |

| UC06 | P06 | Profil entdecken, prüfen und Projektanweisungen erhalten oder sicher einrichten | R008,R009,R010,R012 | required |
| UC07 | P07 | Coding-System nutzt installierte App für Testbefehl; lokale Lieferung und bisherige Kernabläufe erhalten | R002,R005,R006,R007,R011,R012 | required |
| UC08 | P08 | Agent listet Schlüssel, legt Profil an, ordnet Variablen zu, prüft und startet ohne die App | R008,R010,R012,R013,R014 | required |
| UC09 | P09 | Schlüssel auf einem Mac speichern und auf einem zweiten Mac per check und run nutzen | R012,R015,R016 | required |
| UC10 | P10 | Secretariat auf den weiteren Macs installieren und dort ein Profil prüfen | R002,R007,R017 | required |
| UC11 | P11 | Agent übernimmt zwei Werte aus einer .env, ordnet sie einem Profil zu und startet ein Programm damit | R008,R012,R014,R018 | required |
| UC12 | P12 | Agent benennt einen Schlüssel nach dem Schema um; ein zweiter Mac zeigt den neuen Namen, Profile funktionieren weiter | R012,R015,R019 | required |
| UC13 | P13 | Konto mit mehreren Feldern und Schlüsseldatei anlegen; Agent verdrahtet ein Projekt selbst, Programm erhält Werte und Datei; Ziel zeigt Verteilstand; Register zeigt Kennungen | R008,R012,R013,R014,R016,R018,R019,R020,R021,R022,R023 | required |
| UC14 | P14 | Frische Agenten-Sitzung in einem Projekt führt Tests mit Secretariat aus, ohne dass der Nutzer es erwähnt; Werkzeug-Tokens funktionieren in jedem Ordner | R020,R024 | required |

## Tasks

| ID | Phase | UseCase | Requirements | Accept | Verify | Mode | Depends | Files |
|---|---|---|---|---|---|---|---|---|
| T001 | P01 | UC01 | R001,R002,R007 | 268 archivierte Dateien verifiziert, Scope und gesamte Prüfung konkretisiert | inspection | normal | - | docs/legacy-archive.md,docs/secretariat-minimal-concept.md |
| T002 | P02 | UC02 | R002,R005,R006 | Signiertes App-Paket öffnet normal; echte Keychain-Testwerte und CLI-Start im selben Paket funktionieren; simulierte Verweigerung verhindert Start | build,unit,macos | normal | T001 | Package.swift,Sources/SecretariatCore/Models.swift,Sources/SecretariatCore/Storage.swift,Sources/SecretariatCore/Keychain.swift,Sources/SecretariatCore/Launcher.swift,Sources/Secretariat/Entry.swift,script/build.sh,Resources/Info.plist,Sources/Secretariat/AppModel.swift,Sources/Secretariat/Editors.swift,Sources/Secretariat/Views.swift,Assets/AppIcon.icns |
| T003 | P03 | UC03 | R003,R004,R006 | UI speichert und ändert Schlüssel und Profilbindungen; ungültige Eingaben und Löschen verwendeter Schlüssel sind bedienbar abgesichert; externe Änderungen werden erkannt | macos,unit | normal | T002 | Sources/Secretariat/AppModel.swift,Sources/Secretariat/Views.swift,Sources/Secretariat/Editors.swift,Sources/SecretariatCore/Models.swift,Sources/SecretariatCore/Storage.swift,Sources/SecretariatCore/Keychain.swift,Assets/AppIcon.icns,Sources/Secretariat/Entry.swift,Package.swift,script/draw_icon.swift |
| T004 | P04 | UC04 | R005,R006 | Paket-CLI übergibt Testwerte korrekt, trennt Profile, übernimmt Änderungen, erhält stdin/stdout/Exitcode und Ctrl-C; echtes fehlendes Credential und simulierte Zugriffsverweigerung verhindern den Start; OS-Sperrdialog ist separat als Prüfgrenze dokumentiert; beschädigte Konfiguration bleibt unverändert | unit | normal | T003 | Sources/SecretariatCore/Launcher.swift,Sources/SecretariatCore/Storage.swift,Sources/SecretariatCore/Keychain.swift,Tests/SecretariatCoreTests/CoreTests.swift,script/agent_acceptance.py,Package.swift,Sources/SecretariatCore/Models.swift,Sources/Secretariat/Entry.swift |
| T005 | P04 | UC04 | R003,R004,R006,R007 | Frischer kompletter UI-Ablauf samt Neustart, schmalem Fenster und kopiertem Startbefehl; vorhandenes echtes Entwicklungsprojekt startet mit künstlichem Credential | macos | normal | T003 | Sources/Secretariat/Entry.swift,Sources/Secretariat/AppModel.swift,Sources/Secretariat/Views.swift,Sources/Secretariat/Editors.swift,Sources/SecretariatCore/Storage.swift,Sources/SecretariatCore/Launcher.swift,Sources/SecretariatCore/Keychain.swift,Sources/SecretariatCore/Models.swift,Package.swift,script/build.sh,Resources/Info.plist,Assets/AppIcon.icns |
| T006 | P05 | UC05 | R002,R007 | Installation und Entfernung samt erneutem Installieren ohne Autostart geprüft; installiertes Bundle normal geöffnet und bedient; fremde Apps oder Terminaldateien werden nicht überschrieben | inspection,macos | normal | T004,T005 | script/install.py,script/install.sh,script/uninstall.sh,script/build.sh,Resources/Info.plist,Assets/AppIcon.icns,README.md,Sources/Secretariat/Entry.swift,Sources/Secretariat/Views.swift,Sources/Secretariat/AppModel.swift,Sources/Secretariat/Editors.swift,Sources/SecretariatCore/Keychain.swift,Sources/SecretariatCore/Launcher.swift,Sources/SecretariatCore/Models.swift,Sources/SecretariatCore/Storage.swift,Package.swift |

| T007 | P06 | UC06 | R008,R009,R012 | profiles --json, describe und check liefern Schema 1, stabile Fehlercodes und Exitstatus; check liest Credentials ohne Interaktion, startet nichts; Defaulttests bleiben ohne echten Schlüsselbund | build,unit | normal | T006 | Package.swift,Sources/SecretariatCore/Models.swift,Sources/SecretariatCore/Storage.swift,Sources/SecretariatCore/Keychain.swift,Sources/SecretariatCore/Launcher.swift,Sources/SecretariatCore/AgentIntegration.swift,Sources/SecretariatCore/ProjectInstructions.swift,Sources/Secretariat/Entry.swift,Sources/Secretariat/AppModel.swift,Sources/Secretariat/Views.swift,Sources/Secretariat/AgentSetupView.swift,Resources/Info.plist,Tests/SecretariatCoreTests/CommandTests.swift,Sources/Secretariat/Editors.swift,script/build.sh,Assets/AppIcon.icns,Tests/SecretariatCoreTests/CoreTests.swift |
| T008 | P06 | UC06 | R010 | Vorschau vor Einrichtung; idempotente eigene Markerblöcke in AGENTS.md und CLAUDE.md; andere Inhalte und Profile erhalten; Symlinks, beschädigte Marker und erkannte Änderungen seit der Vorschau stoppen; Abbruch schreibt nichts; UI normal geprüft | unit,macos | normal | T007 | Package.swift,Sources/SecretariatCore/Models.swift,Sources/SecretariatCore/Storage.swift,Sources/SecretariatCore/Keychain.swift,Sources/SecretariatCore/Launcher.swift,Sources/SecretariatCore/AgentIntegration.swift,Sources/SecretariatCore/ProjectInstructions.swift,Sources/Secretariat/Entry.swift,Sources/Secretariat/AppModel.swift,Sources/Secretariat/Views.swift,Sources/Secretariat/AgentSetupView.swift,Resources/Info.plist,Tests/SecretariatCoreTests/CommandTests.swift,Sources/Secretariat/Editors.swift,script/build.sh,Assets/AppIcon.icns |
| T009 | P07 | UC07 | R005,R006,R011 | Alle drei lokal vorhandenen Coding-CLIs lesen Projektanweisung und versuchen check plus künstlichen Teststart; echte Ausführung mit Receipt von bloßer Dokumentkompatibilität unterscheiden; fehlende Auth oder Sandbox konkret belegen | inspection | normal | T008 | Package.swift,Sources/SecretariatCore/Models.swift,Sources/SecretariatCore/Storage.swift,Sources/SecretariatCore/Keychain.swift,Sources/SecretariatCore/Launcher.swift,Sources/SecretariatCore/AgentIntegration.swift,Sources/SecretariatCore/ProjectInstructions.swift,Sources/Secretariat/Entry.swift,Sources/Secretariat/AppModel.swift,Sources/Secretariat/Views.swift,Sources/Secretariat/AgentSetupView.swift,Resources/Info.plist,script/agent_acceptance.py,docs/coding-system-integration-research.md,Sources/Secretariat/Editors.swift,script/build.sh,Assets/AppIcon.icns |
| T010 | P07 | UC07 | R002,R005,R006,R007,R012 | Aktualisierte App 0.2.0 signiert installiert; GUI-Einrichtung und CLI daraus geprüft, Basistests und Paket-Prozessprüfungen ohne Regression; keine neuen Autostarts und Testdaten entfernt | build,unit,macos,inspection | normal | T009 | Package.swift,Sources/SecretariatCore/Models.swift,Sources/SecretariatCore/Storage.swift,Sources/SecretariatCore/Keychain.swift,Sources/SecretariatCore/Launcher.swift,Sources/SecretariatCore/AgentIntegration.swift,Sources/SecretariatCore/ProjectInstructions.swift,Sources/Secretariat/Entry.swift,Sources/Secretariat/AppModel.swift,Sources/Secretariat/Views.swift,Sources/Secretariat/AgentSetupView.swift,Resources/Info.plist,Sources/Secretariat/Editors.swift,Assets/AppIcon.icns,script/build.sh,script/install.py,script/agent_acceptance.py,README.md,Tests/SecretariatCoreTests/CoreTests.swift,Tests/SecretariatCoreTests/CommandTests.swift |
| T011 | P08 | UC08 | R013,R014 | `keys --json` ohne Werte; `profile create/set/bind/unbind/delete` mit JSON-Schema 1, stabilen Fehlercodes und Exitstatus; gleiche Validierung und Revision wie die App; Unit-Tests und Paket-CLI mit Test-Home | build,unit | normal | T010 | Package.swift,Sources/SecretariatCore/Models.swift,Sources/SecretariatCore/Storage.swift,Sources/SecretariatCore/Keychain.swift,Sources/SecretariatCore/Launcher.swift,Sources/SecretariatCore/AgentIntegration.swift,Sources/SecretariatCore/Commands.swift,Sources/SecretariatCore/ProjectInstructions.swift,Sources/Secretariat/Entry.swift,Tests/SecretariatCoreTests/CommandTests.swift,Tests/SecretariatCoreTests/CoreTests.swift |
| T012 | P08 | UC08 | R008,R010,R013,R014 | Projektanweisungen, README und Hilfe nennen die neuen Befehle; ein echter Claude-Code-Lauf verdrahtet ein Testprojekt selbst (keys, profile create, bind, check, run mit künstlichem Wert) | macos,inspection | normal | T011 | Package.swift,Sources/SecretariatCore/Models.swift,Sources/SecretariatCore/Storage.swift,Sources/SecretariatCore/Keychain.swift,Sources/SecretariatCore/Launcher.swift,Sources/SecretariatCore/AgentIntegration.swift,Sources/SecretariatCore/Commands.swift,Sources/SecretariatCore/ProjectInstructions.swift,Sources/Secretariat/Entry.swift,README.md |
| T013 | P09 | UC09 | R015 | App-ID und Developer-ID-Provisioning-Profil mit Keychain-Zugriffsgruppe liegen vor und werden beim Build eingebettet; Entitlements im Paket geprüft | build,inspection | normal | T011 | script/build.sh,Resources/Info.plist,Resources/Secretariat.entitlements |
| T014 | P09 | UC09 | R012,R015,R016 | Data-Protection-Schlüsselbund mit synchronisierbaren Einträgen und gemeinsamem Dienst; Name im Eintrag; keys zeigt synchronisierte Schlüssel; Übernahme lokaler Schlüssel ohne Werteverlust; Schlüssel vom M4 auf zweitem Mac per check und run nutzbar; CLI bleibt dialogfrei | build,unit,macos | normal | T013 | Package.swift,Sources/SecretariatCore/Models.swift,Sources/SecretariatCore/Storage.swift,Sources/SecretariatCore/Keychain.swift,Sources/SecretariatCore/Launcher.swift,Sources/SecretariatCore/AgentIntegration.swift,Sources/SecretariatCore/Commands.swift,Sources/SecretariatCore/ProjectInstructions.swift,Sources/Secretariat/Entry.swift,Sources/Secretariat/AppModel.swift,Sources/Secretariat/Views.swift,Sources/Secretariat/Editors.swift,script/build.sh,Tests/SecretariatCoreTests/CoreTests.swift |
| T015 | P10 | UC10 | R002,R007,R017 | Signiertes Paket 0.3 auf M5, M1 und Mac Mini installiert; CLI-Verweis vorhanden; dort Profil per CLI angelegt, check und run mit synchronisiertem Testschlüssel; keine Autostarts | macos,inspection | normal | T014 | script/install.sh,script/install.py,script/build.sh,Resources/Info.plist |
| T016 | P11 | UC11 | R008,R012,R014,R018 | import-Befehl mit dotenv-Parser, Vorabprüfung aller Namen, --replace und --profile; Unit-Tests ohne Werte in der Ausgabe; 0.4.0 signiert auf M4, M5, M1, Mini installiert; echter Import mit check auf dem M4 | build,unit,macos | normal | T015 | Sources/SecretariatCore/Commands.swift,Sources/SecretariatCore/AgentIntegration.swift,Sources/SecretariatCore/Launcher.swift,Tests/SecretariatCoreTests/CommandTests.swift,Resources/Info.plist |
| T017 | P12 | UC12 | R012,R015,R019 | key rename per CLI; Umbenennen schreibt das Schlüsselbund-Etikett neu; Abgleich übernimmt Umbenennungen anderer Macs ohne Namenskonflikt; Unit-Tests; 0.4.1 signiert installiert; echte Umbenennung zweier Schlüssel auf dem M4, Ankunft auf Mini und M1 beobachtet | build,unit,macos | normal | T016 | Sources/SecretariatCore/Commands.swift,Sources/SecretariatCore/Storage.swift,Sources/SecretariatCore/AgentIntegration.swift,Sources/SecretariatCore/Launcher.swift,Tests/SecretariatCoreTests/CoreTests.swift,Tests/SecretariatCoreTests/CommandTests.swift,Resources/Info.plist |
| T018 | P13 | UC13 | R008,R012,R013,R014,R016,R018,R019,R020,R021,R022,R023 | Kern, CLI und App auf Einträge umgestellt; 30 Unit-Tests; signiertes 1.0 auf M4, Mini, M1 installiert, 0.x-Daten migriert und alte Einträge entfernt; Register-Konten und zwei .p8-Dateien übernommen; echter run mit Datei (Prüfsumme gleich, Temp-Datei entfernt); Claude verdrahtet selbst und über Anweisungen; App zeigt gruppierte Einträge | build,unit,macos,inspection | normal | T017 | Sources/SecretariatCore/Models.swift,Sources/SecretariatCore/Keychain.swift,Sources/SecretariatCore/Storage.swift,Sources/SecretariatCore/Commands.swift,Sources/SecretariatCore/AgentIntegration.swift,Sources/SecretariatCore/Launcher.swift,Sources/SecretariatCore/ProjectInstructions.swift,Sources/Secretariat/AppModel.swift,Sources/Secretariat/Views.swift,Sources/Secretariat/Editors.swift,Sources/Secretariat/Entry.swift,Tests/SecretariatCoreTests/CoreTests.swift,Tests/SecretariatCoreTests/CommandTests.swift,Tests/SecretariatCoreTests/TestSupport.swift,script/migrate_v1.swift,script/build_migrate_v1.sh,script/agent_acceptance.py,Resources/Info.plist |
| T019 | P14 | UC14 | R020,R024 | Profil `*` und `profile which` mit Tests (32/32); 1.1.0 auf allen vier Macs; Profil werkzeuge läuft im aktuellen Ordner mit Datei; Prüfliste 296 Werte/20 Kennungen/144 Profile ohne Werte; frische Claude-Sitzung ohne und mit Hinweis grün, kein Wert in der Ausgabe | build,unit,macos | normal | T018 | Sources/SecretariatCore/Models.swift,Sources/SecretariatCore/Storage.swift,Sources/SecretariatCore/Commands.swift,Sources/SecretariatCore/AgentIntegration.swift,Sources/SecretariatCore/Launcher.swift,Sources/SecretariatCore/ProjectInstructions.swift,Tests/SecretariatCoreTests/CoreTests.swift,Tests/SecretariatCoreTests/CommandTests.swift,script/bulk_import.py,script/e2e_session.py,script/cleanup_test_items.swift,script/build_cleanup_test_items.sh,Resources/Info.plist |

## Modules

| ID | Applies | Reason |
| --- | --- | --- |
| auth | NO | OS-Schlüsselbund statt eigener Konten oder Sitzungen; Zugriffsschutz in T002/T004 |
| remote | NO | Vollständig lokal |
| sync | YES | Schlüsselwerte und -namen über iCloud-Schlüsselbund (Apple), Profile bewusst lokal je Mac; T014 |
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
| SYNC-001 | Lokaler Stand und verzögerte Übertragung | YES | T014 | Schlüssel offline auf einem Mac speichern, später verbinden; Wert und Name erscheinen auf dem zweiten Mac genau einmal |
| SYNC-002 | Konflikt, Wiederholung und Mehrfachzustellung | YES | T014 | Gleicher Name auf zwei Macs, erneute Übernahme lokaler Schlüssel und Löschen eines synchronisierten Schlüssels führen zu definiertem Ergebnis |

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
| Keychain | Vom Nutzer eingetragene Schlüssel; ab 0.3 synchronisierbar über iCloud-Schlüsselbund desselben Apple-Accounts | Data-Protection-Schlüsselbund mit `keychain-access-groups` und `com.apple.application-identifier`, Developer-ID-Provisioning-Profil eingebettet; bei gesperrter oder verweigerter Ablage verständlicher Fehler | T002,T004,T013,T014 |
| Dateizugriff | Gewählter Projektordner und app-eigene Metadaten | Nativer Ordnerdialog über fileImporter, bewusst lokale nicht sandboxed Entwicklungs-App; keine TCC-weiten Zusatzrechte | T003,T005 |
| Prozessstart | Expliziter Terminalbefehl im Profilordner | Normaler Nutzerprozess, keine privilegierten Helfer | T002,T004 |

Für lokale Fertigstellung sind keine neuen Anbieter-Konten, Kosten oder externen Freigaben nötig. Weitergabe außerhalb dieses Macs verlangt gesonderte Signatur-/Notarisierungsprüfung.

## Datenintegrität

Metadaten werden unter exklusiver Schreibsperre atomar ersetzt. UI-Mutationen vergleichen die geladene Revision; veraltete Formulare müssen neu geladen werden. Beschädigte oder unbekannte Konfiguration wird erhalten und als Fehler angezeigt. Installation und Entfernung überprüfen App-Identität und Zielverweis; fremde Dateien bleiben erhalten. T003, T004 und T006 prüfen diese Fälle.

## Bestand und Änderungsumfang 0.2

Ausgangspunkt: Commit 2d027f7, installierte Version 0.1.0, unveränderte Datenstruktur und App-ID. Die vorangegangene Recherche ist als unversionierte eigene Notiz vorhanden und bleibt erhalten. Archivnachweis unverändert; bisherige Quellen-/Paketnachweise werden für betroffene Core- und UI-Pfade nach der Änderung neu geprüft. Alte Evidence bleibt als Historie erhalten.

Neue CLI: `profiles --json`, `describe PROFIL [--json]`, `check PROFIL [--json]`, `instructions PROFIL`, `setup PROFIL [--dry-run] [--json]`. JSON mit schemaVersion 1, ok und stabilen Fehlercodes. Laufbefehle bleiben unverändert; keine get/export-Schnittstelle für Werte. Listen, Vorschau und Einrichtung lesen keine Credentials. check verwendet ausdrücklich nichtinteraktiven Keychain-Zugriff, prüft Ordner und zugeordnete Werte, speichert keine Werte und startet nichts. Kein Erstellen oder Sperren von Testschlüsselbünden.

Die Einrichtung ändert ausschließlich einen eindeutig markierten Secretariat-Block pro Datei im vom Nutzer gewählten Profilordner. Vorschau vor UI-Schreiben; CLI setup ist die ausdrückliche lokale Schreibaktion. Bestehende Inhalte außerhalb der Marker bleiben bytegetreu, wiederholte Einrichtung ist unverändert; ein anderes Profil, Symlink/Hardlink, ungültiges UTF-8, beschädigte Marker oder bei optimistischen Snapshotvergleichen erkannte Änderungen führen zum Fehler. Beide Dateien werden vor jeder Änderung geprüft; bei normalem Schreibfehler wird die erste Änderung zurückgerollt, keine gemeinsame Crash-Transaktion behauptet. Globalen Toolkonfigurationen wird nichts hinzugefügt.

Anweisungen erklären profilspezifisch, wann check und run zu verwenden sind. Der kopierte Aufruf enthält keine eingesetzten Schlüsselwerte; geerbte Projekt-Credentials werden nicht zum Start des gesamten Coding-Systems verwendet. Ein Prozess mit frei ausführbarem Code kann Werte trotzdem ausgeben. Kein MCP, Proxy oder neue Isolation in diesem Auftrag.

Für 0.2 gelten die Katalogchecks zusätzlich auf T007 (CLI/Fehler/Daten), T008 (Bedienung/Dateien/Abbruch) und T010 (Bundle, Identität, Installation, Regression). Icons und Berechtigungen unverändert, keine zusätzlichen Anbieter-SDKs. Die tatsächlichen Agentensitzungen nutzen ausschließlich künstliche lokale Fixtures; vorhandene Anmeldung verwenden, keine Konten anlegen oder Abrechnung umstellen. Nicht verfügbare Auth/Toolrechte sind Testgrenzen und dürfen nicht als erfolgreicher E2E-Test gelten.

Projektdateien werden nach dem Staging unmittelbar vor dem Dateitausch erneut mit der Vorschau verglichen. Gegen beliebige nicht kooperierende Editoren bleibt zwischen Vergleich und Rename ein kleines nicht atomar schließbares Zeitfenster; der Verzeichnis-Lock koordiniert Secretariat-Aufrufe untereinander. Dies ist kein atomarer Compare-and-Swap und keine allgemeine Sperre fremder Editoren.

Korrektur vom Nutzer am 23.10: Wiederholte OS-Freigaben sind ein Fehler. CLI run und check müssen nichtinteraktiv bleiben; blockierte Berechtigung wird als Fehler gemeldet, keine automatische Entsperrung oder unbegrenzte Wiederholung. Beim klassischen Login-Keychain greifen SecItem-UI-Flags allein nicht zuverlässig (Chromium FB16959400). Deshalb jeder nichtinteraktive Aufruf: serialisierter prozesslokaler SecKeychainGet/SetUserInteractionAllowed-Scope mit Wiederherstellung des vorherigen Werts. Die GUI behält normale Benutzerfreigabe. Testhelfer dürfen App-Trust nur auf .app-Pakete binden; persistente Freigaben werden an einem gleichbleibenden Eintrag geprüft, nicht an ständig neuen Einträgen verwechselt.

## Bestand und Änderungsumfang 0.3

Ausgangspunkt: Commit 64e0af0, Version 0.2.0 installiert auf dem M4, null Profile. Anlass: Coding-Agents auf allen Macs sollen Projekt-Credentials selbst verdrahten, und Schlüssel sollen nicht je Mac neu eingetragen werden.

CLI-Erweiterung (P08): `keys [--json]` liest nur die Konfiguration. `profile create NAME --dir PFAD [--command BEFEHL]`, `profile set NAME [--dir] [--command]`, `profile bind NAME VARIABLE SCHLÜSSELNAME`, `profile unbind NAME VARIABLE`, `profile delete NAME`. Alle über denselben `Vault` mit Sperre, Validierung und Revision. Schlüsselwerte bleiben ausschließlich in der App; es gibt bewusst keinen CLI-Befehl zum Setzen oder Lesen von Werten.

Abgleich (P09): Schlüsselbund-Einträge wechseln vom dateibasierten Login-Schlüsselbund in den Data-Protection-Schlüsselbund mit `kSecAttrSynchronizable`, einem festen gemeinsamen Dienstnamen (statt des pfadabhängigen Hashes) und dem Schlüsselnamen im Eintrag. `keys` vereinigt lokale Konfiguration und synchronisierte Einträge. Profile bleiben je Mac, weil Projektpfade und Benutzer abweichen (M1: `doedel`). Voraussetzung ist eine App-ID mit Developer-ID-Provisioning-Profil; diese Kontoaktion braucht Uli (Anmeldung von `asc` oder Anlage im Developer-Portal). Bis dahin ist T013 blockiert, P08 läuft unabhängig.

Installation (P10, gleicher lokaler Lieferweg wie D001, eigene Aufgabe T015): per SSH vom M4 aus nach `~/Applications/Secretariat.app` und `~/bin/secretariat` auf M5, M1 und Mac Mini; die Schlüsselwerte selbst kommen über iCloud oder trägt Uli in der App ein.

## Änderungsumfang 0.4

Anlass: Ein Projekt brauchte zwei Werte, die schon in einer anderen .env standen; bisher hätte Uli sie von Hand in die App tippen müssen. Neu (P11): `secretariat import DATEI VARIABLE[=SCHLÜSSELNAME] … [--profile PROFIL] [--replace] [--json]`. Der Wert geht innerhalb des Prozesses von der Datei in den Schlüsselbund; Ausgabe und Fehler nennen nur Namen. Bewusste Lockerung von „Werte nur über die App“ (Uli, 2026-10-26): ein Agent kann die .env ohnehin lesen, der Import hält die Werte aus seinem Kontext. Ausgeben oder Lesen von Werten bleibt unmöglich.

## Änderungsumfang 0.4.1

Anlass: Fleet-Register (Uli, 2026-10-26). Kennungen liegen im Register `~/.claude/registry`, Geheimnisse in Secretariat; Schlüsselnamen folgen dem Schema `<org>/<konto>/<name>[@umgebung]`, damit Register-Verweise `secret:<name>` eindeutig sind. Neu: `secretariat key rename`; ein Umbenennen (CLI oder App) schreibt das Etikett des synchronisierten Eintrags neu, und der Abgleich auf den anderen Macs übernimmt den Namen.

## Änderungsumfang 1.0

Anlass (Uli, 2026-10-26): Konten bestehen aus mehreren Angaben und teils Dateien; vertrauliche und nicht vertrauliche Angaben sollen für Nutzer und Agenten im ganzen Rechnerverbund nutzbar sein. Umstellung von Einzelschlüsseln auf Einträge mit typisierten Feldern (Kennung, Geheimnis, Datei, Nur für mich) in einem synchronisierten Schlüsselbund-Eintrag je Eintrag; Profile und Ziele je Mac. Neu: `items/item/get/field move/import-file/inject/target/targets/push/registry export/scan/log`; Dateien im `run`; Register-Export der Kennungen. Entfernt ohne Kompatibilitätsschicht: `keys`, `key rename`, Legacy-Login-Schlüsselbund. Einmalige Übernahme per `script/migrate_v1` (eigenes signiertes Hilfsprogramm, nicht Teil der App). Grenze: Codex' Sandbox erreicht den Schlüsselbund nicht (Status -25291); Secretariat meldet das als nicht verfügbar und startet nichts.
