# Neubindung nach dem Redesign (2026-11-12)

Anlass: Das Redesign (T030, `docs/redesign-2026-11-12.md`) änderte Dateien, die viele ältere Aufgaben in `Files` nennen
(`Views.swift`, `Editors.swift`, `Entry.swift`, `Package.swift`, `script/build.sh`). Seit Release 1.14.0 (be9a861) ist
`Sources/SecretariatCore` unverändert (`git diff --stat be9a861 HEAD -- Sources/SecretariatCore` leer); Tresor, CLI, Profile,
Agentenschutz, Sicherung, Verlauf, Fill/Save Login laufen über unveränderten Kern. Geändert sind Darstellung (Formulare, Liste,
Detail, Seitenleiste), Kurzbefehle im Menü „Item“ (⌘E) und die SDK-Angabe beim Linken.

| Prüfung | Beobachtung (Stand 8715d4a) |
|---|---|
| build | `script/build.sh` signiert (Developer ID), `otool` meldet `sdk 27.2` |
| unit | `xcrun swift test`: 108/108 |
| cli | `script/regression_cli.sh` gegen `dist/Secretariat.app`: 24/24 |
| macos | Testinstanz mit Design-Tresor, hell und dunkel: Seitenleiste, Liste, Detail, Neuer Eintrag, Lizenz; über das neue Formular per Bedienungshilfen einen API-Schlüssel angelegt, Wert per Prüfsumme gleich; AX-Liste aller Bedienelemente benannt; Menü „Item“ |
| inspection | Unabhängige Design-Kritik, Runde 2 PASS: `docs/review-redesign-2026-11-12.md` |

Grenzen: Die GUI-Abläufe älterer Aufgaben (Sicherung einrichten/wiederherstellen, Verlauf, Screenshot-Import, Fill/Save Login)
wurden nach dem Redesign nicht einzeln erneut durchgespielt; ihre Logik liegt im unveränderten Kern bzw. in unveränderten
Dateien (`BackupView.swift`, `HistoryView.swift`, `FillPanel.swift`, `SaveLoginPanel.swift`), die Neubindung stützt sich auf
Build, Unit, CLI und den Formular-Lauf oben.
