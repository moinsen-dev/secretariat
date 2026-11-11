# Neubindung älterer Aufgaben nach „Fill Login“ – 2026-11-11, Stand 169888c

Anlass: `Sources/Secretariat/Entry.swift` und `Sources/Secretariat/CapturePanel.swift` stehen in den `Files` vieler älterer
Aufgaben. „Fill Login“ (T028) hat dort nur ergänzt:

- `Entry.swift`: `FillController.shared.install(model)` beim Start und Menüpunkt „Fill Login …“.
- `CapturePanel.swift`: in den Einstellungen ein zweiter Kurzbefehl-Rekorder „Fill login“ mit Erklärtext.

Keine bestehende Zeile ist geändert oder entfernt (`git diff 190c091 169888c -- Sources/Secretariat/Entry.swift
Sources/Secretariat/CapturePanel.swift`). Die belegten Abläufe der älteren Aufgaben (Tresor, Profile, run, Erfassen per
⌃⌥⌘V, Screenshots, Verlauf) laufen durch unveränderten Code.

Neu gelaufen auf 169888c: `xcrun swift test` 103/103 grün, `script/build.sh` grün; App startet mit Test-Tresor, beide
Kurzbefehle registriert (Fill Login im echten Lauf genutzt, docs/login-fill-2026-11-11.md). Nicht neu gelaufen: die GUI- und
Inspektionsläufe der älteren Aufgaben; Begründung: deren Code ist unverändert. Kritik: Selbstprüfung.

Vor dieser Sitzung bereits offen und hier nicht angefasst: T006, T010, T012 (alte Inspektions-/GUI-Belege) und
T026 (Sicherung, wartet auf Uli).
