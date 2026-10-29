# Kritik UC16 / T021 – Zwischenablage-Eingang

Unabhängige Prüfung (Kritiker-Agent, nur lesend), 2026-10-29, Stand 051679f plus nicht committete PLAN/TRACKER-Änderungen.
Selbst ausgeführt: `xcrun swift test` → 56/56 grün. App nicht gestartet, Schlüsselbund nicht berührt.

## Urteil

| Umfang | Urteil |
|---|---|
| PLAN (R026, P16, UC16, T021) | **REWORK** |
| UC16 (Nachweis und Code) | **REWORK** |

## 1. PLAN

Format, IDs und Abhängigkeiten stimmen: R026 folgt R025, P16 hängt an P15, UC16 an P16 mit `required`, T021 an T020; Prüfarten `build,unit,macos` wie bei T020.

Befunde:

1. **Defekt – `Files` von T021 unvollständig** (PLAN.md:137). `git show --stat 3e5ce0a 051679f` ändert außerdem:
   - `Sources/SecretariatCore/Models.swift` (Vorlage `capture`, Feld `value` als „Nur für mich“ – trägt R026),
   - `Sources/Secretariat/Entry.swift` (Kurzbefehl-Installation, Menü „Capture Clipboard …“, Settings, Neuladen),
   - `Sources/Secretariat/Editors.swift` (Vorlage `capture` aus der Artenwahl ausgeblendet),
   - `Package.swift`, `Package.resolved` (KeyboardShortcuts 3.1.0),
   - `Tests/SecretariatCoreTests/CaptureTests.swift`.
   Ohne diese Dateien deckt der Fingerprint von E636–E638 nicht ab, was R026 tatsächlich ausmacht; eine spätere Änderung an Models.swift oder Entry.swift macht den Nachweis nicht STALE.
2. **Defekt – Kernzusage von R026 nicht im Accept.** R026 verspricht „kein Programm erhält den Wert, bis er in einen Eintrag umgewandelt ist“. Das Accept von T021 prüft nur den Positivfall (run nach dem Umwandeln). Es fehlt der Negativfall: `profile bind`/`check`/`run` auf `inbox/…/value` wird verweigert (`personal_field`).
3. Unschärfe: R026 „übernimmt den Wert unverändert“ und Accept „byte-genau“ vertragen sich nicht mit `Capture.save`, das Leerraum am Anfang und Ende entfernt (Capture.swift:30). Entweder Anforderung präzisieren („ohne umgebenden Leerraum“) oder Verhalten ändern (siehe 2.4).
4. Hinweis: P16 heißt „… und neues Hauptfenster“, aber keine Anforderung und kein Accept beschreibt das Hauptfenster. Abgedeckt ist es nur indirekt über die Regression 1.10. Vertretbar, sollte aber im Accept oder als eigener Satz in R026/UC16 genannt werden, sonst ist der Phasentitel nicht prüfbar.

Nötig für PASS: Punkte 1 und 2 nachziehen, Punkt 3 entscheiden.

## 2. UC16

Was der Nachweis trägt (docs/t021-evidence.md): Erfassen per Knopf mit Vorschau statt Wert, Pfad mit Zeitstempel, `pbpaste` 0 Bytes, Umwandeln zu `moinsen/claude-dummy` mit Eingang 0, `run` → `VALUE_MATCH`, Löschschutz, Aufräumen, Unit-Tests. Für den Normalablauf ist das überzeugend und sauber isoliert (Test-Tresor).

Code-Prüfung zu den vorgegebenen Risiken:

| Risiko | Befund |
|---|---|
| Wert in Logs/Audit | Kein Leck. `vault.save` protokolliert nur Pfad und „set“ (Storage.swift:230). Fehlermeldungen von `Capture.save` enthalten keinen Wert. |
| Wert in der Oberfläche | Vorschau zeigt die ersten 4 Zeichen ab 13 Zeichen Länge (Capture.swift:48). Gewollt, bei kurzen Tokens aber ein spürbarer Anteil. Detail maskiert, Anzeigen nur auf Klick. Grenze, kein Defekt. |
| Benachrichtigungen | Keine vorhanden. |
| Zwischenablage geleert | Ja, nur nach erfolgreichem Speichern und nur, wenn `changeCount` unverändert ist (CapturePanel.swift:40). Bei Abbrechen bleibt der Wert stehen, das ist korrekt. Zwischenablage-Verläufe (Raycast, Maccy) und Universal Clipboard haben den Wert schon vorher. Grenze, gehört in die Hilfe. |
| „Nur für mich“ gegen Programme | Hält. `Vault.value` wirft `personal_field` (Storage.swift:281), `bind` verweigert (Commands.swift:118), `field move` behält die Art bei (Storage.swift:305 → `setValue` mit `kind: field.kind`; auch mit `--replace` wird das Zielfeld als `personal` angelegt), `item set --kind` ändert nur die Vorlage, nicht die Feldart. Aber: **nicht belegt**, weder als Unit-Test noch im Lauf. |
| Erfassung beim Umwandeln entfernt | Ja, nach dem Speichern (AppModel.swift:256). |
| Datenverlust/Wettlauf | **Defekt**, siehe 2.1 und 2.2. |

### Befunde

1. **Defekt – Datenverlust beim Umwandeln möglich** (AppModel.swift:256, :307). `saveItem` löscht die Erfassung, sobald `draft.replaces` gesetzt ist, ohne zu prüfen, ob der Wert im neuen Eintrag gelandet ist. Der Wert verschwindet endgültig, wenn
   - der Nutzer das vorbefüllte Geheimfeld im Editor leert oder überschreibt,
   - die eingebaute Vorlage `api` ausgeblendet (`deleteTemplate` → hidden, Storage.swift:164) oder ohne Geheimfeld überschrieben wurde. Dann wählt `newItemDraft` die erste Vorlage (AppModel.swift:182), `file()` findet kein Geheimfeld und setzt den Wert stillschweigend nicht (Zeile 307), `replaces` bleibt aber gesetzt.
   Abhilfe: Erfassung nur löschen, wenn `secrets` den erfassten Wert unverändert enthält, sonst behalten und darauf hinweisen. Dazu `file()` abbrechen, wenn kein Geheimfeld gefunden wird.
2. **Defekt (klein) – Teilzustand, wenn das Löschen der Erfassung scheitert** (AppModel.swift:256–257). Der Eintrag ist dann schon gespeichert, `makeAvailableEverywhere` läuft nicht mehr, `perform` meldet einen Fehler, der Editor bleibt offen. Ein erneutes Speichern scheitert an `path_exists`, weil `existing == nil` eine neue UUID erzeugt. Kein Wertverlust, aber Eintrag und Erfassung bleiben doppelt bestehen und „In allen Projekten“ fehlt still. Abhilfe: zuerst `makeAvailableEverywhere`, das Löschen der Erfassung zuletzt und mit `try?` plus Hinweis.
3. **Nachweislücke – Negativfall von R026 nicht geprüft.** Weder `CaptureTests.swift` noch der GUI-Lauf zeigen, dass `bind`/`check`/`run` auf eine Erfassung verweigert werden. Der Code tut es (siehe Tabelle), aber der Nachweis zur zentralen Sicherheitszusage fehlt. Ein Unit-Test in `CaptureTests.swift` reicht (bind → `personal_field`, `check` → `personal`).
4. **Grenze – „byte-genau“ nur nach dem Trimmen.** `Capture.save` entfernt Leerraum und Zeilenumbrüche an den Rändern (Capture.swift:30). Für API-Schlüssel richtig, bei mehrzeiligen PEM-Schlüsseln fehlt danach der abschließende Zeilenumbruch, was manche Parser stört. `VALUE_MATCH` belegt Gleichheit mit dem getrimmten Wert. In R026/Accept so benennen.
5. **Grenze – globaler Kurzbefehl ungeprüft.** Der eigentliche Hauptweg (⌃⌥⌘V aus einer fremden App, nicht aktivierendes Panel mit Texteingabe) ist nicht gelaufen. R026 sagt „Kurzbefehl oder Knopf“, formal reicht also der Knopf. Fokus und Tastatureingabe im `.nonactivatingPanel` aus einer fremden App sind aber genau das, was praktisch kaputtgehen kann. Ein Durchlauf von Hand durch Uli vor dem Release ist nötig.
6. **Grenze – Konvertierungslogik ohne Unit-Test.** `file()` und `replaces` liegen im App-Target, nicht im Core, und sind nur durch einen GUI-Lauf belegt. Befund 1 wäre mit einem Core-Test aufgefallen. Empfehlung: das Umwandeln (Wert übernehmen, Erfassung löschen) als Core-Funktion mit Test.
7. Kleinere Punkte, nicht blockierend: Zwei Erfassungen in derselben Minute auf zwei Macs mit gleichem Namen können vor der iCloud-Synchronisation denselben Pfad belegen (Capture.swift:35–37), dann entstehen zwei Einträge mit gleichem Pfad. Ein Nutzer, der den Schlüssel versehentlich ins Namensfeld einfügt, schreibt ihn in den Pfad und damit in Audit und Register. Die deutschen Reste und der Fenstertitel sind im Nachweis schon genannt.

Nötig für PASS: Befund 1 beheben, Befund 3 belegen (Unit-Test), Befund 2 beheben oder als Grenze begründen. Danach Unit-Tests und einen kurzen Umwandeln-Lauf wiederholen.

## Nachprüfung 30cbcd5

Geprüft: `git show 30cbcd5`, PLAN.md:137 (T021), docs/t021-evidence.md „Nachprüfung nach Kritik“; `xcrun swift test` selbst ausgeführt → 57/57 grün.

| Urteil | |
|---|---|
| PLAN | **PASS** |
| UC16 | **PASS** |

### Abgleich der Befunde

| Befund | Stand |
|---|---|
| PLAN 1: Dateiliste unvollständig | Behoben. Models.swift, Entry.swift, Editors.swift, Package.swift und CaptureTests.swift stehen jetzt drin. Rest: `Package.resolved` fehlt noch (Pin von KeyboardShortcuts), Kleinigkeit. |
| PLAN 2: Negativfall fehlt im Accept | Behoben („kein Programm erhält die Erfassung vor dem Umwandeln (Unit-Test)“). |
| PLAN 3: „unverändert“ gegen Trimmen | Im Accept behoben („getrimmten“). R026 (PLAN.md:66) sagt weiter „unverändert“. Gemeint ist das Umwandeln, und das stimmt. Kein Defekt, nur unscharf. |
| UC16 1: Datenverlust beim Umwandeln | Behoben. `removeCapture` (AppModel.swift, nach `saveItem`) löscht nur, wenn der erfasste Wert unter den gespeicherten Werten liegt, sonst bleibt die Erfassung im Eingang und es gibt einen Hinweis. Das deckt auch den stillen Fall in `file()` ab (kein Geheimfeld in der Startvorlage). |
| UC16 2: Teilzustand bei Löschfehler | Behoben. `makeAvailableEverywhere` läuft vor dem Entfernen, ein Löschfehler wird gemeldet, ohne dass das Speichern als gescheitert gilt (`perform` liefert true, der Editor schließt). Wirft `makeAvailableEverywhere`, bleibt die Erfassung erhalten, also kein Verlust. Das Problem „erneutes Speichern → `path_exists`“ besteht dann für diesen Altfall weiter, ist aber nicht capture-spezifisch. |
| UC16 3: Negativfall nicht belegt | Behoben für den Wertzugriff. `noProgramGetsACaptureBeforeItIsFiled` prüft, dass `Vault.value` verweigert, also den gemeinsamen Weg für run, inject und push. Nicht getestet ist die Verweigerung von `profile bind` (Commands.swift:118). Empfehlung, nicht blockierend. |

### Neue Defekte durch den Fix

Keine gefunden. Der Hinweis wird innerhalb von `perform` gesetzt, und `reload()` überschreibt `errorMessage` nur bei eigenen Fehlern. Er erreicht den Nutzer also. Der Vergleich `secrets.values.contains(captured)` ist streng (Gleichheit). Ein im Editor bewusst geänderter Wert lässt die Erfassung stehen. Das ist das gewünschte, sichere Verhalten.

### Verbleibende Grenzen

- Der Pfad mit geleertem Geheimfeld ist nur per Code-Review belegt, nicht in der GUI (Passwortfeld für die Hintergrundsteuerung gesperrt). Die Bedingung ist einfach und eindeutig, das ist akzeptiert.
- Den globalen Kurzbefehl aus einer fremden App sollte Uli vor dem Release einmal von Hand auslösen.
- Die Konvertierungslogik liegt weiter im App-Target ohne Unit-Test.
