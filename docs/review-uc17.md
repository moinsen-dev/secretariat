# Kritik UC17 / T022 – Verschlüsselte Screenshots mit Notiz

Stand: Commits cc0ef1a und 4e1f607, Nachweis `docs/t022-evidence.md` (untracked), 2026-10-29.
Prüfung: unabhängiger Kritiker, nur lesend. `xcrun swift test` selbst ausgeführt: 61/61 grün.
App nicht gestartet, Schlüsselbund und iCloud nicht berührt.

## Urteil

| Umfang | Urteil |
|---|---|
| 1. PLAN (R027, P17, UC17, T022) | **REWORK** |
| 2. UC17 (Nachweis und Code) | **REWORK** |

Die Kryptografie im Kern ist im Wesentlichen richtig (AES-GCM-256, zufällige 96-Bit-Nonce je Versiegelung, Authentifizierung, Schlüssel-ID im Kopf, mehrere Schlüssel lesbar). Die Rework-Gründe liegen bei Klartext über die Zwischenablage, beim Umgang mit iCloud Drive (Ort, Koordination, Konflikte), bei Speicher/Main-Thread und bei Lücken im Nachweis.

## 1. PLAN

### Befunde

- **P1 (Mangel) – Files-Liste von T022 unvollständig.** `PLAN.md:141` nennt Screenshots.swift, Storage.swift, ScreenshotsView.swift, AppModel.swift, Views.swift, Entitlements, Profil und ScreenshotTests.swift. Es fehlen geänderte Quellen: `Sources/SecretariatCore/Commands.swift` (beide Commits, neue Befehle `screenshots` und `screenshots clear`), `Sources/SecretariatCore/Launcher.swift` (Hilfetext, 4e1f607), `Sources/Secretariat/Entry.swift` (Menüeinträge, cc0ef1a). Änderungen dort lösen damit keinen STALE-Befund aus. Auch die abhängigen Teile `Resources/Info.plist` (wird sie mit dem Profil gebunden?) und `script/build.sh` (bettet das Profil ein) fehlen, ebenso `script/regression_cli.sh`, auf das sich der Nachweis stützt.
- **P2 (Mangel) – R027 widerspricht der Umsetzung.** `PLAN.md:67`: „kein Programm … erhält Bild oder Notiz“. „Copy Image“ (`ScreenshotsView.swift:99-103`), Ziehen aus der Vorschau (`ScreenshotsView.swift:226`) und Export (`:90-97`) geben das Klarbild an jedes Programm weiter. Das ist als Nutzeraktion legitim, muss aber in R027 als ausdrückliche Ausnahme stehen, einschließlich der Regeln dafür (verborgen markiert, zeitlich begrenzt). Sonst ist R027 so nicht prüfbar.
- **P3 (Mangel) – UC17 ist im letzten Teil nicht prüfbar formuliert.** „sieht, dass nur Secretariat ihn lesen kann“ (`PLAN.md:113`) nennt kein Kriterium. Gemeint ist offenbar: Dateien nur als Geheimtext mit UUID-Namen, kein Klartext in Spotlight, Quick Look, Protokollen, CLI- und MCP-Ausgaben; Schlüssel nur in der Zugriffsgruppe. Das muss in T022/Accept stehen, damit der Nachweis es abhaken kann.
- **P4 (Mangel) – Permissions und Module nicht nachgezogen.** Die Tabelle Permissions (`PLAN.md:206-210`) kennt nur den Schlüsselbund, keinen iCloud-Drive-Container (`CloudDocuments`, `ubiquity-container-identifiers`, Production). Module `sync` (`PLAN.md:149`) nennt nur den iCloud-Schlüsselbund. Es fehlt außerdem ein Abschnitt „Änderungsumfang“ für P17 wie bei 0.2 bis 1.0 (Ausgangsstand, neue CLI-Befehle, Speicherort, Verhalten ohne iCloud).
- **P5 (Mangel) – Datenintegrität nicht übertragen.** `PLAN.md:214` verlangt Vergleich der Revision und keine stillen Überschreibungen durch veraltete Formulare. Screenshots haben weder Revision noch Konfliktregel (siehe U5/U6), und der Plan sagt nicht, dass hier „der Letzte gewinnt“ gelten soll.
- **P6 (Mangel) – Tracker veraltet.** `TRACKER.md:28` steht auf BLOCKIERT („braucht Ulis Developer-Portal-Login“), obwohl 4e1f607 das Profil liefert und der Nachweis den Zwei-Mac-Lauf beschreibt. Für T022 gibt es keine Evidence-Zeile mit Fingerprint; `docs/t022-evidence.md` ist nicht versioniert.
- **P7 (Grenze) – Accept ist dicht gepackt, aber konkret.** Die Aufzählung in T022 ist prüfbar (Schlüssel-ID, mehrere Schlüssel, Größenlimit, Platzhalter, die Wege zum Hinzufügen, Export, Löschen, zweiter Mac). Gut, aber genau diese Punkte deckt der Nachweis nicht ganz ab (siehe N1/N2).

## 2. UC17

### Nachweis

- **N1 (Mangel) – Zweiter Mac nur über die Anzahl belegt.** `t022-evidence.md:19`: auf dem Mini `1 screenshots, 0 unreadable` per CLI. Das belegt, dass die Meta-Datei angekommen ist und der Schlüssel entschlüsselt. Es belegt nicht, dass das Bild heruntergeladen und geöffnet wurde und dass die Notiz in der App des zweiten Macs zu sehen ist. Genau das verlangt UC17 („findet ihn auf einem zweiten Mac wieder“). Es fehlt ein Lauf, bei dem die App auf dem zweiten Mac das Bild zeigt, oder mindestens eine byte-genaue Prüfsumme des entschlüsselten Bildes.
- **N2 (Mangel) – Teile aus T022/Accept nicht ausgeführt.** Ablegen, Dateiauswahl, Export und „Copy Image“ sind ausdrücklich nicht ausgelöst (`t022-evidence.md:27-28`). Export steht in Accept. „Copy Image“ ist der riskanteste Weg für Klartext (U1) und blieb ungeprüft.
- **N3 (Grenze) – „nur Secretariat“ nur über grep geprüft.** Kein Versuch, ob `mdfind`/Spotlight, Quick Look oder `log show` etwas aus dem Container liefern. Wegen der Dateinamen und der Verschlüsselung ist das wahrscheinlich sauber, aber für die Aussage in UC17 nicht belegt.
- **N4 (Grenze) – Lauf mit veraltetem Stand.** Version noch 1.10.1, Mini lief mit kopiertem Paket aus einem Testordner. Die Installation auf den Macs ist ausdrücklich verschoben, das passt aber nicht zum Status „Datei auf zweitem Mac lesbar“ im installierten Zustand.

### Code – Kryptografie

- **U0 (in Ordnung).** `Screenshots.swift:202-214`: `AES.GCM.seal` mit zufälliger Nonce, 256-Bit-Schlüssel (`:220`), Format `SCR1 | 16 Hex-ID | nonce‖ct‖tag`. Ein falscher Schlüssel und eine Manipulation werden erkannt (Test `ScreenshotTests.swift:56-73`). Die Schlüssel-ID ist ein abgeleiteter SHA-256-Präfix des Schlüssels; damit verrät sie nichts Brauchbares.
- **U1-K (Grenze, empfohlen) – Keine Bindung an Datei und Art.** `seal` verwendet keine Associated Data (`Screenshots.swift:203`). Wer in `~/Library/Mobile Documents/iCloud~dev~moinsen~secretariat/` schreiben kann (jeder Prozess des Nutzers, die App ist nicht sandboxed), kann `A.image` gegen `B.image` tauschen oder die Kopf-ID ändern, ohne dass die Prüfung anschlägt. Abhilfe: `authenticating: magic + keyID + uuid + kind`. Geringes Risiko, aber die Behauptung „authentisch“ gilt nur pro Box, nicht pro Datei.
- **U2-K (Grenze) – Kein Weg zurück bei Schlüsselverlust.** Gehen die synchronisierten Schlüssel verloren (iCloud-Schlüsselbund aus oder zurückgesetzt, andere Apple-ID), sind alle Screenshots dauerhaft unlesbar. Die App zählt sie nur als „unreadable“. Das gehört als Warnung in die App oder in den Plan.
- **U3-K (Grenze) – Test-Schlüssel synchronisieren.** `SyncedScreenshotKeyring.base()` setzt immer `kSecAttrSynchronizable = true` (`Screenshots.swift:41`), auch für Test-Tresore. Test-Schlüssel gehen in den iCloud-Schlüsselbund aller Macs und bleiben dort, falls `screenshots clear` nicht läuft.
- **U4-K (in Ordnung, Hinweis) – Wettlauf um Schlüssel zwischen zwei Macs.** Zwei Macs ohne Abgleich erzeugen je einen Schlüssel; beide bleiben lesbar, danach wählen beide den kleinsten (`:218-225`). Korrekt und getestet. Einschränkung: `currentKey()` liest den Schlüsselbund bei jedem `add`/`update` neu, ohne Zwischenspeicher; vertretbar.

### Code – Klartext außerhalb der App

- **U1 (Mangel) – „Copy Image“ legt das Klarbild unbegrenzt und unmarkiert in die allgemeine Zwischenablage.** `ScreenshotsView.swift:99-103`. Im Gegensatz zu `copySecret` (`AppModel.swift:341-349`, löscht nach 60 s) gibt es weder ein Löschen noch `org.nspasteboard.ConcealedType`/`TransientType`. Folgen: Universal Clipboard schickt das Bild an iPhone/iPad, Zwischenablage-Manager speichern es dauerhaft, jeder Agent mit `pbpaste`/Pasteboard-Zugriff liest es. Das widerspricht R027 direkt.
- **U2 (Mangel) – Übernahme aus der Zwischenablage lässt das Original dort liegen.** `screenshotFromClipboard` (`ScreenshotsView.swift:28-38`) leert die Zwischenablage nach dem Speichern nicht. Die Erfassung in T021 tut das ausdrücklich (`CapturePanel.swift:40`). Der Hinweistext empfiehlt sogar ⌃⇧⌘4; das Bild bleibt danach für jedes Programm lesbar.
- **U3 (Grenze) – Import aus einer Datei lässt die Klardatei liegen.** `screenshotFromFile` (`:40-47`) übernimmt die Datei (z. B. den Bildschirmfoto-PNG auf dem Schreibtisch, der in Spotlight indiziert ist), bietet aber nicht an, das Original in den Papierkorb zu legen, und weist nicht darauf hin.
- **U4 (Grenze) – Ziehen aus der Vorschau gleich Export.** `ScreenshotsView.swift:226` (`onDrag`) erzeugt bei jedem Ziehen eine Klardatei am Ziel, ohne die Bestätigung des Export-Dialogs. Für R027 als Nutzeraktion zulassen oder entfernen.
- **U5-L (in Ordnung).** Vorschaubilder nur im Speicher, Dateinamen nur UUIDs, `.atomic`-Zwischendateien sind Geheimtext, Dateirechte 0600. Kein Protokoll und keine CLI-/MCP-Ausgabe mit Titel oder Notiz (`Commands.swift:187-203` gibt nur Zahlen aus; MCP hat kein Screenshot-Werkzeug). Ohne `NSUbiquitousContainers` in der Info.plist ist der Container nicht im Finder sichtbar.
- **U6-L (Grenze) – CLI entschlüsselt alle Metadaten, um zu zählen.** `Commands.swift:199-201` ruft `list()` auf, das jede Meta-Datei öffnet (`Screenshots.swift:140-141`). Ein von einem Agenten gestarteter `secretariat screenshots` hat damit alle Titel und Notizen im Prozessspeicher. Es gibt keine Ausgabe, aber „kein Programm erhält“ ist in diesem strengen Sinn nicht erfüllt; zum Zählen reichen Dateinamen und ein Kopf-Check der Schlüssel-ID.

### Code – iCloud, Datenverlust, Konflikte

- **U7 (Mangel) – Ort wird einmal beim Start festgelegt; Screenshots verschwinden aus der Ansicht.** `ScreenshotLibrary.resolve` (`Screenshots.swift:108-114`, aufgerufen nur in `AppModel.swift:187-192`). Liefert `url(forUbiquityContainerIdentifier:)` beim Start `nil` (iCloud kurz nicht bereit, abgemeldet, iCloud Drive aus), landen neue Screenshots lokal. Beim nächsten Start mit iCloud zeigt die App nur den Container: die lokalen Screenshots sind unsichtbar, ohne Übernahme und ohne Hinweis. Umgekehrt verschwindet bei Abmeldung alles aus der Ansicht. Keine Migration, kein Nachladen bei `NSUbiquityIdentityDidChange`.
- **U8 (Mangel) – Kein `NSFileCoordinator`/`NSFilePresenter` im Ubiquity-Container.** `write` (`Screenshots.swift:229-232`), `delete` (`:183-189`), `Data(contentsOf:)` (`:140`, `:154`, `:176`) arbeiten unkoordiniert. Apple verlangt Koordination für Dateien in iCloud-Containern; ohne sie kann ein gleichzeitiger Download durch `bird` mit einem lokalen Schreiben kollidieren. Konfliktversionen (`NSFileVersion.unresolvedConflictVersionsOfItem`) werden nie gelesen oder aufgelöst; bei gleichzeitiger Notizänderung auf zwei Macs geht eine Fassung still verloren und Konfliktversionen sammeln sich an.
- **U9 (Mangel) – Veraltete Detailansicht überschreibt fremde Änderungen.** `ScreenshotDetail` lädt Titel und Notiz nur in `onAppear` (`ScreenshotsView.swift:242`) und speichert in `onDisappear` (`:243`), sobald sie vom aktuellen `shot` abweichen (`:65-66`). Ändert ein anderer Mac die Notiz und `reload()` läuft (bei jeder App-Aktivierung, `Entry.swift:35`), bekommt die Ansicht den neuen `shot`, behält aber den alten Text. Verlässt der Nutzer die Ansicht, schreibt `update` den alten Text über die neue Fassung. Verstößt gegen `PLAN.md:214`.
- **U10 (Mangel, klein) – Ungespeicherte Notiz geht beim Beenden verloren; Fehler nach dem Löschen.** `onDisappear` läuft beim Beenden der App nicht zuverlässig, ungespeicherte Änderungen gehen dann verloren. Wer die Notiz ändert und dann löscht, löst `update` auf eine gelöschte Meta-Datei aus und bekommt die Meldung „That didn't work“.
- **U11 (Grenze) – Verwaiste Dateien werden nie aufgeräumt.** Scheitert `add` nach dem Bild (`:169-170`) oder `delete` nach der Meta-Datei (`:185-188`), bleibt eine unsichtbare `.image`-Datei dauerhaft im Container und in iCloud. Kein Aufräumen in `list()`.
- **U12 (Grenze) – Keine Beobachtung neuer Dateien.** Ohne `NSMetadataQuery` erscheinen Screenshots vom anderen Mac erst nach einer App-Aktivierung oder ⌘R; „pending“ zählt nur Platzhalter-Meta-Dateien. Für UC17 akzeptabel, wenn dokumentiert.

### Code – Main-Thread, Speicher

- **U13 (Mangel) – Thumbnails halten das volle Bild im Speicher.** `NSImage.thumbnail` (`ScreenshotsView.swift:111-115`) baut ein `NSImage(size:flipped:drawingHandler:)`, dessen Block `self`, also das volle dekodierte Bild, festhält. `thumbnails` (`AppModel`) behält damit jedes Original. Bei vielen 25-MB-Retina-Bildern sind das Hunderte MB bis GB. Abhilfe: in eine `NSBitmapImageRep` oder ein `CGImage` der Zielgröße rendern, besser `CGImageSourceCreateThumbnailAtIndex`.
- **U14 (Mangel) – Thumbnail-Laden ohne Begrenzung und doppelt.** `loadThumbnail` (`:83-88`) prüft `thumbnails[id] == nil` vor dem `await`; mehrere `.task`-Aufrufe (Scrollen, neues Rendern) entschlüsseln dasselbe Bild parallel. Alle sichtbaren Zeilen starten gleichzeitig `Task.detached`, ohne Obergrenze. Das gibt Speicherspitzen.
- **U15 (Mangel) – Entschlüsseln des Vollbilds auf dem Main-Thread.** `ScreenshotDetail.onAppear` ruft `model.screenshotImage(shot)` synchron auf (`:242` → `:77-81` → `Screenshots.swift:148-155`): Dateilesen aus iCloud, Schlüsselbundabfrage, AES-GCM über bis zu 25 MB. Spürbares Hängen bei jedem Auswählen. Ebenso laufen `reloadScreenshots` (Schlüsselbund und alle Metas) bei jeder App-Aktivierung (`AppModel.swift:231`) sowie `screenshotFromFile` (liest beliebig große Dateien vor der 25-MB-Prüfung, `ScreenshotsView.swift:42`) auf dem Main-Thread.
- **U16 (Mangel) – Vorschau bleibt bei laufendem Download hängen.** Ist das Bild noch Platzhalter, wirft `image()` (`Screenshots.swift:150-153`), die App zeigt eine Fehlermeldung und danach einen endlosen `ProgressView` (`ScreenshotsView.swift:227`). Es gibt keinen erneuten Versuch und keine Beobachtung des Downloads; man muss die Auswahl wechseln. Auf dem zweiten Mac ist das genau der erste Eindruck in UC17. Außerdem fragt `fileExists` nur nach dem Klarnamen: Ist die Datei durch „Speicher optimieren“ ausgelagert, existiert nur `.<name>.icloud`. Das wird erkannt, aber als Fehlerdialog statt als Ladezustand gezeigt.
- **U17 (Grenze) – Zwischenablage-Weg verdoppelt die Größe.** `pngData` geht über `tiffRepresentation` (`:107-110`): unkomprimiertes TIFF im Speicher, dann PNG. Ein 5K-Screenshot kann so über 25 MB kommen und wird abgewiesen, obwohl ⌃⇧⌘4 ihn geliefert hat.

## Was vor PASS nötig ist

1. Plan: Files-Liste ergänzen (Commands.swift, Launcher.swift, Entry.swift, build.sh/Info.plist), R027 um die ausdrücklichen Ausnahmen für Kopieren, Ziehen und Export ergänzen, UC17 „nur Secretariat“ als prüfbares Kriterium, Permissions/Module/Änderungsumfang für iCloud Drive, Tracker-Status und Evidence-Zeile.
2. Code: „Copy Image“ verborgen markieren und nach 60 s leeren (wie `copySecret`); die Zwischenablage nach der Übernahme leeren; koordinierter Zugriff und Konfliktauflösung im Container; keine stillen Überschreibungen aus der Detailansicht; Ort-Wechsel lokal ↔ iCloud erkennen und übernehmen; Thumbnails ohne Vollbild-Referenz, Vollbild abseits des Main-Threads mit Ladezustand und erneutem Versuch.
3. Nachweis: auf dem zweiten Mac das Bild in der App öffnen (oder Prüfsumme) und die Notiz sehen; Export, Kopieren (mit Prüfung des Leerens) und Ablegen auslösen; Spotlight-/Quick-Look-Stichprobe im Container.

---

# Nachprüfung (Commit 3fab938, 2026-10-29)

Geprüft: Diff 3fab938 (Screenshots.swift, ScreenshotsView.swift, Views.swift, Commands.swift, ScreenshotTests.swift, PLAN.md), `docs/t022-evidence.md` Abschnitt „Nachprüfung nach Kritik“. `xcrun swift test` selbst: 62/62 grün.

## Neues Urteil

| Umfang | Urteil |
|---|---|
| 1. PLAN | **PASS** (mit Auflage: Tracker nachziehen) |
| 2. UC17 | **REWORK** (ein wahrscheinlicher neuer Mangel aus dem Fix, nicht im Lauf geprüft) |

## Stand der früheren Befunde

| Befund | Stand |
|---|---|
| P1 Files-Liste | behoben: Commands.swift, Launcher.swift und Entry.swift jetzt drin (`PLAN.md:141`). build.sh und Info.plist fehlen weiter; vertretbar, sie wurden nicht geändert |
| P2 R027 vs. Herausgabe | behoben: ausdrückliche Nutzeraktionen benannt (vertrauliches Kopieren mit 60 s, Export, Ziehen) |
| P3 „nur Secretariat“ prüfbar | behoben: konkret als Chiffrat, an ID und Art gebunden, zufällige Namen, CLI nur Anzahlen |
| P4 Permissions/Module | behoben: Zeile iCloud Drive, Module sync/files ergänzt. Ein eigener Abschnitt „Änderungsumfang“ fehlt weiter (kosmetisch) |
| P5 Datenintegrität | behoben: eigener Absatz (Koordination, Stand-Vergleich, Konfliktregel, AAD) |
| P6 Tracker | **offen**: `TRACKER.md:28` steht weiter auf BLOCKIERT ohne Evidence-ID; `docs/t022-evidence.md` ist nicht committet (`git status`: M) |
| N1 zweiter Mac | behoben im Rahmen der Aussage: `imagesReadable: 1` auf dem Mini heißt, das Bild wurde dort entschlüsselt (AAD und GCM-Tag geprüft). Die Notiz in der App des zweiten Macs wurde nicht angesehen; T022/Accept ist entsprechend auf „per `screenshots` bestätigt“ zugeschnitten, das ist ehrlich |
| N2 Export/Kopieren/Ablegen | teilweise: Kopieren (Concealed-Typ, nach 62 s leer) belegt; Export, Ablegen und Dateidialog weiter nicht ausgelöst (als Grenze dokumentiert) |
| U1-K AAD | behoben (`Screenshots.swift` `seal`/`open` mit `context(id, kind)`), getestet mit vertauschter Meta-Datei |
| U1 Copy Image | behoben: `org.nspasteboard.ConcealedType` und Leeren nach 60 s. Grenze bleibt: Universal Clipboard (Handoff) überträgt trotzdem auf iPhone/iPad; dagegen hilft nur `prepareForNewContents(with: .currentHostOnly)` |
| U2 Zwischenablage nach Übernahme | behoben (`saveScreenshot`, nur wenn `changeCount` unverändert) |
| U7 Ort lokal → iCloud | behoben in eine Richtung (`adopt`). Umgekehrt (iCloud später aus) bleibt die Liste leer; die Fußzeile sagt dann „Only on this Mac“. Grenze |
| U8 Koordination/Konflikte | behoben: `NSFileCoordinator` für Lesen, Schreiben, Löschen; Konfliktversionen werden aufgelöst. Siehe N-K2 |
| U9 veraltete Ansicht überschreibt | behoben im Kern (`update(basedOn:)` → `changedElsewhere`, Test vorhanden). Der Fix in der Ansicht erzeugt aber N-K1 |
| U13 Thumbnail hält Vollbild | behoben (gerenderte `NSBitmapImageRep`) |
| U15 Vollbild auf dem Main-Thread | teilweise: Detail entschlüsselt abseits (`loadImage`). Weiter auf dem Main-Thread: `NSImage(data:)` und das Rendern in `loadThumbnail` (nach dem `await`), `copyScreenshot`/`exportScreenshot` (synchrones `screenshotImage`/`image`), `reloadScreenshots` bei jeder Aktivierung, jetzt mit koordiniertem Lesen |
| U16 endloser Spinner | behoben: Fehlertext statt Spinner. Es gibt keinen automatischen neuen Versuch; man muss neu auswählen. Grenze |
| U14, U3, U4, U10, U11, U12, U17, U2-K, U3-K, U6-L | unverändert, wie zuvor als Grenze oder kleiner Mangel eingestuft |

## Neue Befunde aus den Fixes

- **N-K1 (wahrscheinlicher Mangel, nicht ausgeführt) – Falsche Meldung „changed on another Mac“ nach jedem Speichern in der Detailansicht.** `Views.swift:425` setzt `.id("\(shot.id)-\(shot.changed…)")`. Ablauf bei „Save Note“, ⌘S oder Enter im Titel:
  1. `save()` → `updateScreenshot` (`ScreenshotsView.swift:68-73`) speichert erfolgreich, `changed` steigt.
  2. `reloadScreenshots()` liefert den neuen `shot`, die Ansicht bekommt eine neue Identität.
  3. Die alte Instanz läuft durch `.onDisappear(perform: save)`. Ihr `shot` ist noch der alte Stand, ihr `@State` enthält den bearbeiteten Text. Die Bedingung `title != shot.title || note != shot.note` ist also wahr.
  4. Es folgt `update(basedOn: altes changed)`, darauf `ScreenshotError.changedElsewhere` und der Dialog „That didn't work: This screenshot was changed on another Mac …“.

  Die Daten bleiben richtig (der erste Schreibvorgang hat gegriffen), aber der Nutzer bekommt bei jedem Speichern eine falsche Fehlermeldung. Der Nachweis enthält nach dem Fix keinen GUI-Lauf „Notiz bearbeiten und speichern“, daher nicht beobachtet. Abhilfe: Nach erfolgreichem Speichern den lokalen Ausgangsstand in `@State` mitführen (z. B. `@State var base: Screenshot`), mit diesem vergleichen und `basedOn` daraus nehmen; oder `onDisappear` nur speichern lassen, wenn noch ungespeicherte Änderungen gegenüber dem zuletzt gespeicherten Stand bestehen.
- **N-K2 (kleiner Mangel) – Konfliktauflösung in einer lesenden Koordination und im CLI-Zählbefehl.** `read()` setzt `isResolved` und ruft `NSFileVersion.removeOtherVersionsOfItem` innerhalb von `coordinate(readingItemAt:)` auf. Apple verlangt dafür eine schreibende Koordination. Außerdem verwirft so ein `secretariat screenshots`, den ein Agent startet, still die Notizfassung des anderen Macs. „Der Letzte gewinnt“ steht jetzt im Plan, also ist das als Regel gewollt. Die Konfliktfassung sollte aber nur die App auflösen, und zwar mit Schreib-Koordination.
- **N-K3 (Grenze) – `screenshots` entschlüsselt jetzt auch alle Vollbilder.** `verify()` (`Screenshots.swift`, aufgerufen in `Commands.swift:203`) öffnet jedes Bild im CLI-Prozess. Das ist der Preis für den Nachweis auf dem zweiten Mac: Ausgegeben werden nur Zahlen, aber ein von einem Agenten gestarteter Prozess hält bis zu 25 MB Klarbild je Screenshot im Speicher und braucht bei vielen Bildern lange. Ebenso verschiebt `resolve()` → `adopt()` Dateien schon beim CLI-Zählbefehl. Vorschlag: `--verify` als ausdrücklichen Schalter, ohne ihn nur Meta zählen.
- **N-K4 (Grenze, unbelegt) – Dataless-Dateien unter macOS 14+.** Seit iCloud Drive auf FileProvider läuft, tragen ausgelagerte Dateien meist ihren echten Namen statt `.<name>.icloud`. Dann greift weder `pending` noch die Prüfung mit `fileExists`. Ein koordiniertes Lesen lädt die Datei synchron herunter, in `reloadScreenshots` also auf dem Main-Thread. Mit „Speicher optimieren“ an einem Mac mit wenig Platz prüfen.
- **N-K5 (Grenze) – Format ohne Versionswechsel.** Dateien vor 3fab938 (ohne AAD) tragen weiter `SCR1` und sind jetzt „unreadable“. Laut Nachweis existieren keine mehr (beide Testbilder gelöscht), daher nur ein Hinweis.
- **N-K6 (in Ordnung).** `adopt` nutzt `moveItem` statt `setUbiquitous(_:itemAt:destinationURL:)` und läuft unkoordiniert. Unter macOS funktioniert das in der Praxis; nur zur Kenntnis.

## Was vor PASS für UC17 nötig ist

1. N-K1 beheben und im Test-Tresor per GUI belegen: Notiz ändern, „Save Note“, Auswahl wechseln, kein Fehlerdialog, Notiz bleibt.
2. Tracker T022 auf den tatsächlichen Stand setzen und den Nachweis mit Evidence/Fingerprint eintragen (`workflow.py evidence`/`task`); `docs/t022-evidence.md` committen.
3. Empfohlen, nicht blockierend: Konflikte nur in der App mit Schreib-Koordination auflösen (N-K2); `verify` hinter einen Schalter legen (N-K3).
