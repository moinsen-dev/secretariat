# Regression für Release 1.13.1 (Build 7a1e34b, 2026-10-30)

Anlass: 1.13.1 bringt „Needs a Value“ (T027): eine Liste in der Bibliothek und einen Hinweis am Feld für gespeicherte Werte, die ein `.env`-Kommentar oder ein Vorlagen-Platzhalter sind. Geändert: `Views.swift` (Seitenleiste, Listenfilter, Feldhinweis), `AppModel.swift` (Prüfung beim Laden, abseits des Hauptthreads), Version. Kern, CLI, Speicher und Schlüsselbund unverändert seit 1.13.0 (`git diff --stat 2d58044 7a1e34b -- Sources/SecretariatCore` nur `Launcher.swift`: Versionsnummer).

| Prüfung | Beobachtung |
|---|---|
| build | `xcrun swift build` grün; `script/build.sh` signiert (Developer ID), `codesign --verify --deep --strict` ok, `--version` 1.13.1 |
| unit | `xcrun swift test`: 94/94, dreimal hintereinander |
| cli | `script/regression_cli.sh` gegen `dist/Secretariat.app`: 24/24 |
| macos | Paket im Test-Tresor: Hauptfenster mit zwei Einträgen, Bibliothek mit „Needs a Value · 1“, Verlauf (7 Tage, Diagramm, Herkunft), Backup „on“; T027-Ablauf in `docs/t027-evidence.md` |
| inspection | Diff seit 1.13.0 durchgesehen: nur Anzeige; die Prüfung liest Werte wie `secretariat lint`, hält nur Namen und Gründe im Speicher, ändert oder löscht nichts |

## Nachtrag beim Parken (2026-10-30)

Nur Testwerkzeug, kein Produktcode: `script/cleanup_test_items.swift` entfernt jetzt Testeinträge aller Test-Namensräume (`dev.moinsen.secretariat.<items|templates|license|screenshots|backup>.test.*`, synchronisiert und nur auf diesem Mac), `script/build_cleanup_test_items.sh` baut mit `xcrun swiftc`. Lauf: 22 Testeinträge entfernt; echter Tresor danach unverändert (226 Einträge, 150 Profile, `status` ok, TinIdeas-MCP „Connected“).
