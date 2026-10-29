# Kritik UC18 / T023 – Eintrag aus Screenshot

Datum: 2026-10-29 · Prüfer: unabhängig, nur lesend · Stand: Arbeitskopie auf 36c775b (ungecommittet)

Urteil: **REWORK** (Erdung an zwei Stellen zu locker, sonst solide)

## Geprüft
- `xcrun swift test --filter ScreenshotReading`: 6 Tests grün, der Modelltest wird übersprungen (nur mit `SECRETARIAT_MODEL_TEST=1`). `xcrun swift build` ohne Warnung.
- Vision im Speicher (`CGImageSourceCreateWithData`, keine Datei), `.accurate`, `usesLanguageCorrection = false`: erfüllt.
- FoundationModels hinter `#if canImport` und `@available(macOS 26.0, *)`, Paket bleibt `.macOS(.v14)`, keine neuen Entitlements, kein `print`/`Logger`/`NSLog` im neuen Code.
- Fehlertexte (ScreenshotReading.swift:51, :74, :86) enthalten nur den Grund, nie erkannten Text. `try?` um `ask` verschluckt Modellfehler ohne Ausgabe.
- Nebenläufigkeit: `defaultIsolation(MainActor)`, Entschlüsseln und Erkennen laufen in `Task.detached` (ScreenshotsView.swift:120), `ScreenshotLibrary` und `TemplateCatalog`-Werte sind Sendable; das Ergebnis wird auf dem Main Actor übernommen. Doppelklick verhindert durch Guard plus `disabled` (ScreenshotsView.swift:116, :314).

## Befunde

1. **Mangel – abgeschnittener Schlüssel wird übernommen.** ScreenshotReading.swift:157 prüft `text.contains(value)` als Teilstring. Gibt das Modell nur einen Anfang des Schlüssels zurück (`sk-ant-api-Xq7`), steht er im Text und wird als Geheimnis übernommen. Weil das Feld dann belegt ist, setzt Zeile 167–171 den vollständigen Präfix-Treffer nicht mehr ein. Ergebnis: ein unvollständiger Schlüssel im Dialog, äußerlich plausibel. Für Geheimnisfelder verlangen, dass der Wert ein ganzes Wort aus `tokens(lines)` ist (oder die Verbindung benachbarter Wörter, für den Zeilenumbruch). Ist er nur der Anfang eines Wortes, durch das längste Wort mit diesem Anfang ersetzen. Test dazu fehlt.
2. **Mangel – Anbieter und Projektname werden über Teilstrings „bestätigt“.** Zeile 173–178: Der Anbieter gilt als genannt, wenn sein erstes Segment irgendwo im Text vorkommt. `"a"`, `"key"` oder `"api"` bestehen also immer (der Text enthält „API keys“). Dasselbe gilt für das Label in Zeile 180 (`"a"` genügt). Prompt-Injection oder Halluzination kann so den Pfad `moinsen/<anbieter>/<label>` frei wählen. R028/T023 verlangen „nur, wenn der Text sie nennt“. Vorschlag: Vergleich auf Wortgrenzen (`tokens` in Kleinbuchstaben) und Mindestlänge (z. B. ≥ 3); den Anbieter zusätzlich auf `ItemEditor.providers` ∪ Präfixtabelle beschränken oder als Wort im Text verlangen. Testfälle mit `provider: "a"` und `label: "key"` ergänzen.
3. **Grenze – kurze Nicht-Geheimnis-Werte.** Ebenfalls Zeile 157: Für normale Felder genügt jeder Teilstring, also auch einzelne Zeichen oder Wortteile (`"1"`, `"oud"`). Der Nutzer sieht sie zwar, aber die Erdung schützt hier kaum. Wortgrenze oder Mindestlänge wie in Befund 2.
4. **Grenze – Präfix-Schlüssel landet in einem fremden Geheimnisfeld.** Zeile 167–171: Wählt das Modell eine andere Vorlage (z. B. einen Login), kommt der per Präfix gefundene API-Schlüssel in deren erstes Geheimnisfeld (Passwort). Nur einsetzen, wenn die Vorlage `api` ist oder das Feld als Schlüssel gilt. Sonst gewinnt besser die Präfix-Vorlage `api`.
5. **Grenze – mehrere Schlüssel, Tippfehler-Ersatz.** Zeile 161–163 ersetzt nach den ersten 8 Zeichen. Bei Präfixen von 8 Zeichen (`sk-proj-`, `sk-ant-a`) und zwei Schlüsseln im Bild bekommt das Feld den *längsten* passenden statt des gemeinten. Ein erfundener Wert mit bekanntem Präfix wird so zu einem echten, aber womöglich falschen Schlüssel. Die Regel aus T023 ist damit wörtlich erfüllt, die Mehrdeutigkeit bleibt aber ungetestet und wird im Dialog nicht gemeldet. Vorschlag: nur ersetzen, wenn genau ein Wort passt, sonst verwerfen (dann greift der Fallback).
6. **Grenze – Ergebnis überschreibt einen offenen Dialog.** ScreenshotsView.swift:139 setzt `itemEditor` ohne Prüfung. Öffnet der Nutzer während des Lesens „New Item …“ (⌘N) und tippt los, ersetzt der fertige Vorschlag diesen Entwurf ohne Rückfrage. Abbruch gibt es nicht. Ein Wechsel des Screenshots öffnet den Dialog trotzdem später. Vorschlag: nur setzen, wenn `itemEditor == nil` (sonst eine Meldung), und beim Verlassen der Detailansicht abbrechen oder verwerfen.
7. **Grenze – Vorlagenwechsel im Dialog.** Editors.swift:132–134 setzt die Felder nur bei leerem Entwurf zurück. Weil der Entwurf jetzt vorbefüllt ist, behält ein Wechsel z. B. von „API key“ auf „Token“ das Feld `api_key`. `saveItem` speichert Felder ohne Spec mit (AppModel.swift:258–259). Der Hinweis zur Leseart bleibt stehen, obwohl die Art nicht mehr die gelesene ist. Das Verhalten gab es schon vorher, durch T023 tritt es aber regelmäßig auf. Beim Wechsel gelesene Werte auf gleichnamige Felder übertragen und den Rest verwerfen, oder warnen.
8. **Hinweis – ausgeblendete `api`-Vorlage.** Zeile 123–124: Hat der Nutzer die eingebaute Vorlage `api` ausgeblendet, liefert die Heuristik immer nil. Ohne Modell erscheint dann „found text but no key“, obwohl ein Schlüssel im Bild steht. Der Fehlertext sollte die Ursache nennen.
9. **Hinweis – Präfix `re_`/`sk-` bei ≥ 12 Zeichen** (Zeile 127). Gewöhnliche Wörter wie `re_initialize_cache` gelten als Resend-Schlüssel und gehen dem längsten echten Schlüssel vor. Eine Mindestlänge über `isKeyLike` (Buchstaben und Ziffern) auch für Präfix-Treffer verlangen.
10. **Hinweis – Klartextanzeige.** „Show read values“ (Editors.swift:164–170) zeigt die Geheimnisse ungeschützt an, ist aber ausdrücklich gewünscht (Kurzvorschau zum Prüfen), ohne Textauswahl und wird beim Wechsel der App zurückgesetzt. In Ordnung. Wird der Dialog ohne Wechsel der App gezeigt, bleibt die Anzeige offen, bis er sich schließt.
11. **Hinweis – Testabdeckung.** Es fehlen Tests für: abgeschnittenen Wert (1), kurzen Anbieter oder kurzes Label (2), zwei Präfix-Schlüssel beim Erden (5), Fallback-Schlüssel bei fremder Vorlage (4) und eine versteckte Vorlage als Modellantwort (`isKnown` filtert sie heute korrekt heraus, ungetestet). Die Zuordnung der Verfügbarkeit auf Hinweistexte (Zeile 59–69) lässt sich nicht testen. Das muss als Einschränkung im Nachweis stehen, der GUI-Lauf mit und ohne Modell ebenfalls.

## Empfehlung
Befunde 1 und 2 beheben und testen (je wenige Zeilen in `ground`), 6 absichern (`itemEditor == nil`). Danach PASS möglich. 3–5 und 7 als bewusste Grenzen im Tracker vermerken oder gleich mitnehmen.

## Nachprüfung

Datum: 2026-10-29 · Stand: 4f322af (Code), ba0b615 plus Arbeitskopie (Nachweis `docs/t023-evidence.md`) · Prüfer: unabhängig, nur lesend

Urteil: **PASS** (Restpunkte sind Grenzen oder Hinweise, kein Mangel)

`xcrun swift test`: 70/70 grün. Ein erster Lauf scheiterte einmal in `InstructionTests` mit `setup_busy`: Eine Sperre, vermutlich durch einen parallelen Lauf, nicht durch T023. Die Wiederholung war grün.

Erledigt:
- Befund 1: `groundSecret` (ScreenshotReading.swift, `ground`) verlangt ein ganzes Wort oder über einen Zeilenumbruch verbundene Wörter. Ein abgeschnittener Wert wird zum einzigen längeren Wort, bei mehreren Treffern wird er verworfen. Getestet.
- Befund 2: Anbieter-Stamm und Label nur als ganzes Wort ab 3 Zeichen (`namesWord`). Getestet mit `pi`/`rapid` und `key`/`monkey`.
- Befund 3: Identifier nur als ganzes Wort, Groß-/Kleinschreibung beachtet, ab 2 Zeichen. Getestet mit `ample` gegen `example.com`.
- Befund 4: Der Präfix-Schlüssel geht nur in die von den Präfixen gewählte Art. Getestet mit `login`.
- Befund 5: Ein mehrdeutiger Tippfehler-Ersatz wird verworfen. Getestet.
- Befund 6: Vor dem Öffnen gilt die Prüfung `itemEditor == nil && selectedScreenshot == shot.id`.
- Befund 7: Beim Vorlagenwechsel bleiben gleichnamige Werte erhalten, der Schlüssel wandert nur in ein `.secret`-Feld und nie in ein persönliches Passwort.
- Befund 9: Ein Präfix-Treffer braucht eine Ziffer.
- Zusätzlich korrekt: Vision läuft auf einer Dispatch-Queue (Begründung durch `sample` belegt) mit CPU-Rückfall (`setComputeDevice` ab macOS 14, passt zu `.v14`). Verwechselbare Zeichen werden markiert und lassen sich korrigieren.
- Nachweis: drei GUI-Läufe (mit Modell, mit Modell gespeichert plus `run` → SAME, ohne Modell gespeichert plus `run` → SAME), `log show` ohne Treffer, Aufräumen belegt. Der k/K-OCR-Fehler ist ehrlich dokumentiert.

Offen:
N1. **Grenze – Modell schlägt Präfix beim Geheimnis.** Gibt das Modell für `api_key` irgendein ganzes Wort mit mindestens 8 Zeichen an (z. B. `pulse-readonly`), gilt es als geerdet. Der echte Präfix-Schlüssel wird dann nicht eingesetzt, weil das Feld schon belegt ist (`ground`, Schleife über `fallback.fields`). Der Fehler ist im Dialog sichtbar, aber vermeidbar. Vorschlag: Für Geheimnisfelder `isKeyLike` oder ein bekanntes Präfix verlangen, oder den Präfix-Schlüssel bei gleicher Art vorziehen.
N2. **Hinweis – exakter Treffer gegen längeres Wort.** `groundSecret` bevorzugt das einzige *längere* Wort, auch wenn der Wert selbst als ganzes Wort im Text steht (zwei Schlüssel, von denen einer der Anfang des anderen ist). Das ist selten. Ein exakter Treffer sollte zuerst gewinnen.
N3. **Hinweis – stilles Verwerfen.** Ist inzwischen ein anderer Dialog offen oder ein anderer Screenshot gewählt, endet das Lesen ohne Rückmeldung (ScreenshotsView.swift, `createItem`). Eine kurze Meldung wäre freundlicher.
N4. **Hinweis – Warnung als Routine.** Die erweiterte Liste der verwechselbaren Zeichen löst die Warnung bei fast jedem Schlüssel aus. Das ist im Nachweis benannt. Die Markierung einzelner Zeichen trägt die eigentliche Information.
N5. **Hinweis – offen aus der ersten Runde:** Befund 8 (ausgeblendete `api`-Vorlage, irreführende Meldung) ist unverändert. Ebenso unverändert: Die Abbildung der Verfügbarkeit auf Hinweistexte ist nur im Code geprüft, das steht im Nachweis. Die Korrektur über das Korrekturfeld ist nicht per GUI getippt, auch das steht im Nachweis.
