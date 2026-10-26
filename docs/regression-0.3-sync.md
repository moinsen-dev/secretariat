# Regression 0.3 nach dem Schlüsselbund-Umbau (Build 9c64dac)

Zeit: 2026-10-26, M4. Geändert seit ce7cb30: Keychain.swift (neuer synchronisierter Speicher, Kombi-Speicher), Storage.swift
(Dienstnamen, Import, Übernahme), Launcher/AgentIntegration (Speicherauswahl), AgentProfiles (Import bei keys/bind),
AppModel (Übernahme und Import beim Start), build.sh (Profil, Entitlements). Darum erneut geprüft:

- build: script/build.sh Exit 0, Signatur mit Entitlements, --version 0.3.0; install.sh auf dem M4, keine LaunchAgents.
- unit: swift test 28/28.
- Paket-Prozessprüfungen mit echtem Fixture im Login-Schlüsselbund (Fallback-Pfad): alle acht Prüfungen true.
- Verweigerter Zugriff: check 3× Exit 2 in 0,02–0,03 s ohne Dialog, run Exit 1, Ziel nicht gestartet.
- Claude Code mit vorbereitetem Profil: passed. Claude Code verdrahtet selbst: passed, keine .env, kein Wert in Ausgabe.
- macos (normale Bedienung dieses Builds): Leerzustand, „Schlüssel hinzufügen“ mit Name und Wert gespeichert, Liste mit
  Nutzung „Noch keinem Profil zugeordnet“, Löschdialog geöffnet; App-Start übernimmt einen Altwert ohne Dialog
  (siehe docs/t013-t015-evidence.md, Schritte 2 und 5).
- Zwei Macs: Speichern, Nutzen, Löschen über iCloud (Mini) — siehe t013-t015-evidence.md.

Grenzen: Codex/OpenCode nicht erneut; schmales Fenster/Ordnerdialog nicht erneut bedient. Selbst ausgeführt.
