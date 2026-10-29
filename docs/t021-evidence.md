# T021 – Zwischenablage-Eingang (Nachweis)

Stand: Commit 3e5ce0a (Neuladen-Fix 051679f), signiertes Paket `dist/Secretariat.app` (Build 2026-10-29 14:57), Prüfung 2026-10-29 15:04–15:10.

## Aufbau

- Isolierter Test-Tresor über `SECRETARIAT_HOME` im Scratchpad; Schlüsselbund-Dienst `dev.moinsen.secretariat.items.test.<hash>`, echter Tresor unberührt.
- Die installierte 1.10.0 lief parallel und wurde für den Test beendet (gleiche Bundle-ID), danach wieder gestartet.
- Künstlicher Wert `sk-test_claude-dummy-…` (37 Zeichen) per `pbcopy` in die Zwischenablage, mit Ulis Freigabe.

## Schritte und Beobachtung

| Schritt | Erwartung | Beobachtung |
|---|---|---|
| Hauptfenster öffnen | Eingang leer, Hinweis auf ⌃⌥⌘V | „Inbox is Empty“ mit Kurzbefehl und Knopf „Capture Clipboard“ |
| Knopf „Capture Clipboard“ | Erfassungsfenster mit Vorschau statt Wert | „sk-t… · 37 characters“, Datum und Uhrzeit |
| Name „claude dummy“, „Save to Inbox“ | Erfassung im Eingang, Zwischenablage leer | `inbox/claude-dummy-2026-10-29-1504`, Feld „Only for me“; `pbpaste` liefert 0 Bytes |
| „Turn into Item …“, Anbieter `claude-dummy`, Speichern | Eintrag angelegt, Erfassung entfernt | `moinsen/claude-dummy` (API key, Herkunft „Clipboard · 2026-10-29 15:04“), Eingang 0, Alle 1 |
| `profile create/bind` + `run --no-mask` im Test-Tresor | Programm erhält Wert byte-genau | `VALUE_MATCH` |
| Ziele und Vorlagen öffnen | Ansichten laden | Leerzustand Ziele; Vorlagenliste inkl. „Clipboard capture“ mit Detail |
| Eintrag löschen, solange gebunden | Löschschutz | „This item is still in use: dummy“ |
| Profil entfernen, Eintrag löschen | Tresor leer | `items --json` → `[]`; Test-Tresor-Ordner gelöscht |
| Unit-Tests (`xcrun swift test`) | grün | 56/56 bestanden |

## Nachprüfung nach Kritik (Build 30cbcd5, 2026-10-29 15:23)

Unabhängige Kritik `docs/review-uc16.md` (REWORK) fand: Umwandeln löschte die Erfassung auch ohne übernommenen Wert; scheiterte das Löschen, galt das ganze Speichern als fehlgeschlagen, obwohl der Eintrag schon lag. Behoben in 30cbcd5: „In allen Projekten nutzbar“ läuft vor dem Entfernen, die Erfassung wird nur entfernt, wenn ihr Wert unter den gespeicherten Werten des neuen Eintrags ist, sonst bleibt sie mit Hinweis im Eingang; ein Löschfehler wird gemeldet, ohne das Speichern rückgängig erscheinen zu lassen. Neuer Unit-Test: `value(itemID:field:)` verweigert die Erfassung (`personal_field`), nur die App liest sie.

Wiederholter Ablauf im neuen Paket mit neuem Test-Tresor: File › Capture Clipboard …, Name „claude dummy“, Save to Inbox → `inbox/claude-dummy-2026-10-29-1523`; Turn into Item …, Anbieter `claude-dummy`, Save → `moinsen/claude-dummy`, Eingang 0; `run` → `VALUE_MATCH`; Testdaten entfernt (`items` leer). `xcrun swift test` 57/57.

Nicht in der GUI geprüft: Umwandeln mit geleertem Geheimfeld (das Feld ist ein Passwortfeld und für die Hintergrundsteuerung gesperrt); belegt durch Code-Review der Bedingung.

## Einschränkungen und Befunde (nicht blockierend)

- Der Wert wird beim Erfassen an den Rändern getrimmt (Leerzeichen, Zeilenumbrüche); „byte-genau“ gilt für den getrimmten Wert.
- Globaler Kurzbefehl ⌃⌥⌘V aus einer anderen App nicht ausgelöst (Hintergrundsteuerung sendet keine globalen Tastenkürzel); Erfassung nur über den Knopf geprüft.
- App lud Profiländerungen von außen (CLI) nicht nach: Detail zeigte „Used in: Nowhere yet“, obwohl gebunden. Behoben in 051679f (Neuladen beim Aktivieren, View › Reload ⌘R), geprüft in `docs/regression-1.10.md`. Die leere Seitenleiste „Projects“ lag dagegen am eingeklappten Abschnitt (`sidebar.projects = 0`), kein Fehler.
- Nach dem Löschen des gewählten Eintrags zeigt der Fenstertitel weiter „moinsen/claude-dummy · 0 items“.
- Englische Oberfläche mit deutschen Resten: Datum im Erfassungsfenster „29. Okt. 2026“, Bedienhilfe-Labels „Anzeigen“/„Kopieren“.
- In der Vorlagen-Ansicht sitzen die Fenster-Toolbarknöpfe über der mittleren Spalte statt rechts.
- Einfaches `swift test` scheitert an der swiftly-Toolchain im PATH; `xcrun swift test` nutzen.
