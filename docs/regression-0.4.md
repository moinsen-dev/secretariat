# Regression 0.4 (Build f363f6e)

Anlass: 0.4.0 fügt `secretariat import` hinzu und ändert dafür die gemeinsam genutzten Dateien Launcher.swift (Hilfe, Version), AgentIntegration.swift (Befehlsliste), AgentProfiles.swift (Aufruf-Text, Verteilung) und Resources/Info.plist (0.4.0/4). Alle älteren Aufgaben, die diese Dateien nennen, sind neu geprüft.

| Prüfung | Beobachtung |
|---|---|
| build | `swift build` grün; `script/build.sh` erzeugt das Developer-ID-signierte Paket mit eingebettetem Profil, Entitlement keychain-access-groups vorhanden |
| unit | `swift test`: 30 von 30 grün (28 bisherige plus 2 neue Import-Tests) |
| macos | Installiertes Paket ~/Applications/Secretariat.app normal per `open` gestartet: ein Fenster „Secretariat“, danach beendet. CLI `check menulens-worker --json` ok mit zwei synchronisierten Schlüsseln (keine Werte ausgegeben) |
| inspection | `codesign --verify --strict` grün auf M4, Mini, M1, M5; `--version` überall 0.4.0; `keys --json` überall ok; keine LaunchAgents angelegt |

Unverändert: GUI-Quellcode (Sources/Secretariat), Keychain.swift, Storage.swift. Grenzen: kein neuer manueller GUI-Durchlauf aller Schlüssel-/Profilmasken, da deren Code unverändert ist.
