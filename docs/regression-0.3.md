# Regression 0.3 für die abgeschlossenen Phasen P02–P07

Zeit: 2026-10-26, M4 (macOS 27.0). Build: Commit ce7cb30, dist/Secretariat.app 0.3.0, Developer-ID (VXX45ZYNM8),
installiert nach ~/Applications/Secretariat.app, Terminalverweis ~/bin/secretariat → 0.3.0.

## Was sich seit 0.2 (64e0af0) geändert hat

`git diff --stat 64e0af0 ce7cb30 -- Sources/Secretariat script/build.sh script/install.sh script/install.py Package.swift`
ist leer: Oberfläche, Build, Installation und Paketdefinition unverändert. Geändert: CLI-Verteilung (keys/profile),
Hilfetext, Versionsnummer (Info.plist 0.3.0/3), Projektanweisung (Schritt 4), neue Datei AgentProfiles.swift.
Deshalb neu geprüft statt nur neu gebunden.

## Erneut ausgeführt

1. build: `script/build.sh` Exit 0, `codesign --verify --strict` ok, `--version` → 0.3.0.
2. unit: `swift test` → 23/23 grün (alle 19 bisherigen + 4 neue).
3. Paket-Prozessprüfungen (`agent_acceptance.py --clients` → integration_check.py, echter künstlicher Keychain-Eintrag):
   Arbeitsordner/Umgebung/stdin/stdout/Exitcode, gleicher Schlüssel in zwei Profilen, wörtliche Argumente ohne Shell,
   unbekanntes Profil/Programm scheitert, fehlender Keychain-Wert stoppt vor Kindprozess, echtes Strg-C erreicht Ziel,
   beschädigte Konfiguration bleibt erhalten, Metadaten ohne Fixture-Werte — alle true; Fixture entfernt.
4. Verweigerter Zugriff (`--denied-fixture`): check dreimal Exit 2 in 0,02 s ohne Dialog, run Exit 1, Ziel nicht gestartet.
5. Agentenablauf 0.2 mit vorbereitetem Profil (Claude Code): passed, Quittung credential/cwd verifiziert, kein Wert in Ausgabe.
6. Installation: `script/install.sh` → installiert, Signatur ok, keine LaunchAgents, echte Nutzerdaten (0 Profile) unverändert.
7. macos (normale Bedienung, installierte App mit Wegwerf-SECRETARIAT_HOME): Hauptfenster zeigt Schlüssel „Prüfung GUI“
   mit Nutzung; Profil öffnet Detail (Ordner, Variable→Schlüssel, Startbefehl); „Coding-System einrichten“ zeigt Vorschau
   inklusive neuem Schritt 4; „Im Projekt einrichten“ schreibt AGENTS.md (mit `profile bind`) und CLAUDE.md-Verweis;
   „Fertig“, App über Menü beendet. Testordner danach gelöscht.

## Grenzen

Kein erneuter Lauf von Codex/OpenCode; schmales Fenster und Ordnerdialog (T005) nicht erneut bedient — deren UI-Code ist
unverändert. Selbst ausgeführt, nicht unabhängig.
