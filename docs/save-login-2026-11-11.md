# Login aufnehmen per Kurzbefehl (T029, UC23) – Prüfbericht 2026-11-11

Code-Stand: siehe Commit „Save Login“ (Build `dist/Secretariat.app`, Developer-ID-signiert, Test-Tresor über `SECRETARIAT_HOME`).

## Vorab-Probe: Kann ein Programm ein Passwortfeld lesen?

Lese-Probe gegen die Claude-App mit einer Testseite, Passwortfeld per HTML vorbelegt (16 Zeichen): `AXValue` des
`AXSecureTextField` liefert 16 Punkte, nicht den Wert; das Benutzerfeld liefert seinen Wert. Folge: Ein eingetipptes Passwort
lässt sich nicht aufnehmen; Save Login erzeugt, übernimmt aus der Zwischenablage oder lässt es einmal eintippen.

## Unit-Tests

`xcrun swift test`: 106 grün; neu: Passwortgenerator (200 Läufe: Länge 20, jede Zeichenart, keine Verwechsler, tippbar,
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

## Grenzen

- Der aus der Zwischenablage gespeicherte Wert ist nicht per Prüfsumme verglichen („Nur für mich“ erreicht kein Programm,
  auch nicht `secretariat run`); belegt sind Speichern und Leeren der Zwischenablage.
- „Type“ (einmal im Fenster eintippen) nicht im echten Lauf; gleicher Speicherweg wie „Clipboard“.
- Chrome und Safari nicht im echten Lauf; die Benutzernamen-Erkennung ist eine Heuristik (fokussiertes oder letztes gefülltes
  Textfeld vor dem ersten Passwortfeld) und im Fenster änderbar.
