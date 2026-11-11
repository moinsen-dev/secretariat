# Login aufnehmen per Kurzbefehl (T029, UC23) – Prüfbericht 2026-11-11

Code-Stand: siehe Commit „Save Login“ (Build `dist/Secretariat.app`, Developer-ID-signiert, Test-Tresor über `SECRETARIAT_HOME`).

## Vorab-Probe: Kann ein Programm ein Passwortfeld lesen?

Lese-Probe gegen die Claude-App mit einer Testseite, Passwortfeld per HTML vorbelegt (16 Zeichen): `AXValue` des
`AXSecureTextField` liefert 16 Punkte, nicht den Wert; das Benutzerfeld liefert seinen Wert. Folge: Ein eingetipptes Passwort
lässt sich nicht aufnehmen; Save Login erzeugt, übernimmt aus der Zwischenablage oder lässt es einmal eintippen.

## Unit-Tests

`xcrun swift test`: 108 grün (Endstand); neu: Passwortgenerator (200 Läufe: Länge 20, jede Zeichenart, keine Verwechsler, tippbar,
alle verschieden), freie Namen und Form des Eintrags, Vorrang für gerade gespeicherte Logins (nie vor besseren Treffern).

## Echter Lauf (UC23) im eingebauten Claude-Browser, Test-Tresor, Registrierungsseite

Lauf 1 (Uli): Schritt 1 erzeugte und speicherte `web/localhost` (url `https://localhost`, Benutzer aus der Seite, Herkunft
„Saved from localhost“), Feld 20 Zeichen. Befunde: (a) im Wiederholungsfeld nahm Enter alphabetisch einen älteren Testeintrag
desselben Hosts; (b) Schritt „Clipboard“ speicherte nichts. Behoben: Vorrang für den gerade gespeicherten Login; dabei per
Unit-Test entdeckt, dass Adressen ohne Punkt (`http://localhost:8765/…`) nicht als Host erkannt wurden – behoben.

Lauf 2 (Uli, nach Umbenennen des alten Eintrags): `web/localhost` neu erzeugt und getippt; Wiederholungsfeld per Fill Login
mit `web/localhost` gefüllt: die ersten 20 Zeichen des Passwortfelds sind zeichengleich mit dem Wiederholungsfeld → erzeugter
= gespeicherter = ausgefüllter Wert. Befund: Der dritte Schritt lief als „Generate“ statt „Clipboard“ und hängte 20 Zeichen
an das gefüllte Feld an (40 Zeichen). Behoben: ⌘A vor jedem Tippen (Inhalt wird ersetzt), Umschalter statt Aufklappmenü.

Lauf 3 (Uli): Fill Login in das 40-Zeichen-Feld → danach 20 Zeichen, gleich dem Wiederholungsfeld (Ersetzen belegt);
⌃⌥⌘S mit „Clipboard“ → Eintrag `web/localhost/new-user@example.test-2` (url, Benutzer, Herkunft), Zwischenablage danach 0 Bytes
(vorher Testwert, 16 Bytes). Verlauf: „Saved web/… (values changed)“ und „Fill Localhost web/localhost/password“, keine Werte.

## Unabhängige Kritik Runde 1 (dd3ec78): PLAN PASS, UC23 REWORK – Umsetzung

Muss-Punkte: ⌘A per Tastenposition wäre auf AZERTY ⌘Q; Benutzernamen-Heuristik nahm jedes gefüllte Feld (Codes, Nummern)
als lesbare Kennung; Tippen auch ohne Passwortfeld und irreführende Meldung nach dem Speichern; Belege nicht auf dem Endstand.
Sollte: Endlosschleife bei fehlendem Zufall, localhost ohne Port. Alle umgesetzt.

## Lauf 4 auf dem Endstand (Uli)

1. ⌃⌥⌘S im Passwortfeld: `web/localhost-8765` mit `http://localhost:8765`, Benutzer, Herkunft „Saved from localhost:8765“
   gespeichert und getippt; ⌃⌥⌘P im Wiederholungsfeld: zeichengleich (20).
2. Befund: Markieren per Bedienungshilfen (`AXSelectedTextRange`) lässt Chromium im Passwortfeld nicht zu; die Prüfung brach
   mit Meldung ab (richtig, nichts angehängt). Außerdem sperrte die Meldung als modaler Dialog das Save-Fenster (Uli konnte den
   Umschalter nicht bedienen) und ein gescheiterter Versuch stand als „Fill“ im Verlauf. Behoben: Leeren per ⌘→/⌘⌫ mit Prüfung
   der Punktzahl, Längenprüfung nach dem Tippen, Meldungen in eigenem Fenster, Wert erst nach vorbereitetem Feld gelesen.
3. Mit abweichendem Probewert (21 Zeichen) im Passwortfeld: ⌃⌥⌘P mit `web/localhost-8765` → Feld 20 Zeichen, gleich dem
   Wiederholungsfeld (Ersetzen belegt).
4. ⌃⌥⌘S „Clipboard“: `web/localhost-8765/new-user@example.test` (url mit Port, Benutzer, Herkunft), Zwischenablage danach 0 Bytes.
5. Verlauf: Speichern und Ausfüllen ohne Werte.

## Unabhängige Kritik Runde 2 (6f4844b): UC23 PASS, PLAN REWORK – Umsetzung

Muss-Punkte: unbekannte Feldlänge galt als „leer“; Benutzernamen-Regel ließ alphanumerische Codes, Schlüssel und IBAN durch.
Umgesetzt: unbekannte Länge → kein Leeren, kein Tippen; Benutzername nur als E-Mail oder aus einem als Benutzer/Login/E-Mail
bezeichneten Feld (Platzhalter, Beschreibung, Titel, DOM-ID/Klasse). Sollte: Vergleich der Seite über Schema, Host und Port;
Fokus nach dem Lesen erneut geprüft; Längenprüfung akzeptiert Zeichen oder UTF-16-Einheiten. 108 Tests grün.
Kein weiterer echter Lauf: die Änderungen betreffen Randfälle (Feld ohne Längenangabe, unbezeichnete Felder) und sind per
Unit-Test bzw. Code-Prüfung belegt; der Testfall (E-Mail-Feld, Chromium mit Längenangabe) verhält sich unverändert.

## Grenzen

- Der aus der Zwischenablage gespeicherte Wert ist nicht per Prüfsumme verglichen („Nur für mich“ erreicht kein Programm,
  auch nicht `secretariat run`); belegt sind Speichern und Leeren der Zwischenablage.
- „Type“ (einmal im Fenster eintippen) nicht im echten Lauf; gleicher Speicherweg wie „Clipboard“.
- Zwischenablage-Manager (Verlaufs-Apps) können ein kopiertes Passwort behalten, bevor Secretariat die Zwischenablage leert.
- Ein Login ohne plausiblen Benutzernamen hat kein Feld `username`.
- Chrome und Safari nicht im echten Lauf; die Benutzernamen-Erkennung ist eine Heuristik (fokussiertes oder letztes gefülltes
  Textfeld vor dem ersten Passwortfeld) und im Fenster änderbar.
