# T023 – Eintrag aus Screenshot (Nachweis)

Stand: Funktion samt Korrekturen nach Kritik und GUI-Lauf in 4f322af, signiertes `dist/Secretariat.app` aus `script/build.sh`, macOS 27.0.1, Apple Intelligence verfügbar, 2026-10-29.

## Aufbau

- `ScreenshotReading` (Kern): `recognizeText` (Vision, `.accurate`, `usesLanguageCorrection = false`, en-US/de-DE ohne automatische Spracherkennung, Bild nur im Speicher; bei Neural-Engine-Fehler e5rt 13 ein zweiter Versuch auf der CPU), `heuristic` (Präfix vor längstem schlüsselartigem Wort, Präfix-Treffer braucht eine Ziffer), `ground` (Erdung der Modellantwort), `ask` (Foundation Models, `@Generable ModelGuess`, frische Sitzung, `sampling: .greedy`, nur hinter `#if canImport(FoundationModels)` und `@available(macOS 26)`), `read` (Ablauf; Verfügbarkeit → Hinweistext; `SECRETARIAT_NO_LOCAL_MODEL=1` erzwingt den Weg ohne Modell).
- Vision läuft auf einer eigenen Dispatch-Queue: aus einem Swift-Task heraus aufgerufen blockierte der Texterkenner in der App dauerhaft (Stichprobe mit `sample`: `TextRecognition` wartet auf einem Semaphor im kooperativen Pool). In Unit-Tests trat das nicht auf.
- App: „Create Item …“ in der Screenshot-Detailansicht (aus, solange das Bild nicht geladen ist oder schon gelesen wird). Danach öffnet der Eintrags-Dialog vorausgefüllt mit einem Hinweis, wie gelesen wurde, mit einer Warnung bei verwechselbaren Zeichen und mit „Show read values“: Der Wert erscheint mit markierten Zeichen und lässt sich direkt korrigieren. Beim Wechsel in eine andere App wird er wieder verdeckt. Ist inzwischen ein anderer Dialog offen oder ein anderer Screenshot gewählt, öffnet sich nichts. Bei einem Wechsel der Art behält der Dialog gleichnamige Werte, und der gelesene Schlüssel wandert in das Geheimnisfeld der neuen Art.
- Keine neuen Entitlements und keine Profiländerung: Vision und Foundation Models brauchen keine.

## Schritte und Beobachtung

| Schritt | Erwartung | Beobachtung |
|---|---|---|
| `xcrun swift test`, 3× hintereinander | grün | 70/70, 70/70, 70/70. Davor einmal ohne CPU-Rückfall: e5rt-Fehler 13 in den beiden Vision-Tests, behoben durch den CPU-Rückfall |
| Unit-Regeln | Erdung | Wert muss als ganzes Wort (oder über einen Zeilenumbruch zusammengesetzt) im Text stehen; ein abgeschnittener Wert wird zum vollen Wort; ein vertippter Wert zum einzigen Wort mit denselben ersten 8 Zeichen; sind beide mehrdeutig, wird er verworfen; unbekannte, Erfassungs- und fremde Felder werden verworfen; Anbieter und Projektname nur als ganzes Wort ab 3 Zeichen; der Präfix-Schlüssel geht nur in die Art, die die Präfixe gewählt haben |
| Texterkennung im Test | exakt | Schlüssel `sk-ant-api-…` in Menlo exakt gelesen. Gemessen: `O0l1` kommt als `0011` zurück (gleiche Länge, wird markiert) |
| Echtes Modell, Unit-Test (`SECRETARIAT_MODEL_TEST=1`) | api, anthropic, Schlüssel exakt | grün, 6,2 s |
| GUI Lauf A, Test-Tresor, mit Modell | vorausgefüllt | Künstlicher Screenshot „Anthropic Console … Name: pulse-readonly … sk-ant-api-Xq7_zR4-fakeKEY9tesT8Zz“ über die Zwischenablage gespeichert, „Create Item …“ geklickt: Dialog mit „Read on this Mac with Apple’s on-device model“, Art API key, Anbieter anthropic, Projekt pulse-readonly, Schlüssel gefüllt (`docs/t023/model-dialog.jpg`). **Ein Zeichen falsch:** Vision liest in SF Mono das große K als kleines k, bei jeder Skalierung (0,5× bis 3×). Der Dialog warnt und markiert k/K; abgebrochen |
| GUI Lauf B, mit Modell | korrekt vorausgefüllt, `run` liefert Wert | Zweiter künstlicher Screenshot mit `sk-ant-api-Hq7_dR4-demoBEY9teaT8Nm` (vorher per Vision-Skript bei allen Skalierungen exakt gelesen): Dialog wie oben (`docs/t023/model-run-b.jpg`), gespeichert als `moinsen/anthropic/pulse-readonly`, Quelle „Screenshot · 2026-10-29 18:19“; `run` mit gebundenem Feld → `SAME` (byte-genau) |
| GUI Lauf C, App gestartet mit `SECRETARIAT_HOME=<test> SECRETARIAT_NO_LOCAL_MODEL=1 dist/Secretariat.app/Contents/MacOS/Secretariat` (Läufe A/B ohne die zweite Variable) | als Texterkennung beschriftet | Hinweis „Read on this Mac with text recognition only (local model turned off): kind and provider are guessed from the key’s prefix“, Art API key, Anbieter anthropic, kein Projekt, Schlüssel gefüllt (`docs/t023/text-only-run-c.jpg`); gespeichert als `moinsen/anthropic`; `run` → `SAME` |
| Verdecken | beim App-Wechsel | Nach Bildschirmsperre war „Show read values“ wieder aus |
| Klartext | nirgends | `log show --last 25m --info --debug` (3,0 Mio. Zeilen, alle drei Läufe und Modelltests): 0 Treffer für beide Fake-Schlüssel. `items`, `item show`, `screenshots`, App-Ausgabe: 0 Treffer. Test-Tresor-Ordner: kein Klartext. Neuer Code ohne `print`/`Logger`/`NSLog`. Fehlertexte nennen nur den Grund, nie erkannten Text |
| Aufräumen | | Testeinträge per `CleanupTestItems` entfernt (3), Zwischenablage gesichert und wiederhergestellt (`cmp` gleich) |

## Einschränkungen

- Die Texterkennung verwechselt in Monospace-Schriften Zeichen, deren kleine und große Form sich nur in der Größe unterscheiden (k/K, gemessen), und 0/O, 1/l. Die Erdung kann das nicht erkennen, weil der falsche Wert im erkannten Text steht. Abhilfe in der App: Warnung, markierte Zeichen und Korrekturfeld. Lauf A zeigt den Fall; die Korrektur selbst wurde nicht per GUI getippt: Das Korrekturfeld nimmt im Hintergrund keinen Text per Bedienungshilfe an, und die Vollbild-Freigabe kam nicht rechtzeitig.
- Die Warnung erscheint bei fast jedem Schlüssel (`sk-` enthält schon s und k). Das ist gewollt, macht sie aber zur Routine.
- Das echte Modell ist nicht deterministisch über OS-Versionen. Belegt sind ein Unit-Lauf und zwei GUI-Läufe; die Abbildung „Apple Intelligence aus / Modell lädt noch“ auf Hinweistexte ist nur im Code geprüft, nicht ausgelöst.
- Kein Release, keine Installation, nichts gepusht. Ulis echte Secretariat-Instanz wurde für den Lauf beendet (gleiche Bundle-ID wie die Test-Instanz) und danach neu gestartet.
- Beobachtung außerhalb von Secretariat: Die Bildschirmaufzeichnung der ChatGPT-App (`…/com.openai.sky.CUAService/…/Skysight/segments/…/events.jsonl`) hat den Fake-Schlüssel mitgeschrieben, weil er sichtbar war. Was „Show read values“ zeigt, landet bei solchen Werkzeugen genauso wie jeder andere sichtbare Text.
