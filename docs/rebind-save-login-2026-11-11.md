# Neubindung älterer Aufgaben nach „Save Login“ – 2026-11-11, Stand 310f00c

Anlass: Save Login (T029) und die gemeinsame Tippfunktion haben Dateien aus den `Files` älterer Aufgaben ergänzt:

- `Sources/Secretariat/Entry.swift`: `SaveLoginController.shared.install(model)` und Menüpunkt „Save Login …“.
- `Sources/Secretariat/CapturePanel.swift`: dritter Kurzbefehl-Rekorder „Save login“ mit Erklärtext in den Einstellungen.
- `Sources/Secretariat/AppModel.swift`: neue Funktion `storedValue` (Wert ohne Verlaufszeile, nur von Fill Login genutzt);
  `secretValue` und alle übrigen Funktionen unverändert.

Keine bestehende Zeile dieser Dateien ist geändert oder entfernt (`git diff 169888c 310f00c -- Sources/Secretariat/Entry.swift
Sources/Secretariat/CapturePanel.swift Sources/Secretariat/AppModel.swift`). Die belegten Abläufe der älteren Aufgaben laufen
durch unveränderten Code.

Neu gelaufen auf 310f00c: `xcrun swift test` 108/108 grün, `script/build.sh` grün; App mit Test-Tresor gestartet, alle drei
Kurzbefehle im echten Lauf genutzt (`docs/save-login-2026-11-11.md`). Nicht neu gelaufen: GUI- und Inspektionsläufe der älteren
Aufgaben; Begründung: deren Code ist unverändert. Kritik: Selbstprüfung.

Vor dieser Sitzung bereits offen und nicht angefasst: T006, T010, T012; dadurch bleibt P05 (T007, T008) offen.
