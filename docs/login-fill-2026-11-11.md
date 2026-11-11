# Login ausfüllen per Kurzbefehl (T028, UC22) – Prüfbericht 2026-11-11

Code-Stand: 04c7856 nach der ersten Kritik (erster Stand 548ff65; Build `dist/Secretariat.app`, Developer-ID-signiert, Kennung `dev.moinsen.secretariat.local`).

## Unit-Tests

`xcrun swift test`: 103 Tests grün (Stand 04c7856), davon 10 in `LoginFillTests.swift` (Host aus URL, registrierbare Domain, Feldwahl,
Rangfolge gleicher Host > gleiche Domain > Domain im Pfad, alle Einträge ohne Treffer, Suche über Pfad/Benutzer/Host,
kurze Domain-Labels ohne Treffer, nur Feld `password`, Steuerzeichen abgelehnt, geteilte Hosting-Domains wie pages.dev nie gleiche Domain).

## Machbarkeit Webadresse (Bedienungshilfen)

Lese-Probe gegen die laufende Claude-App: vier `AXWebArea` mit `AXURL`, darunter der eingebaute Browser (`https://github.com/`)
und App Store Connect in einem anderen Fenster. Felder der Testseite: Benutzerfeld `AXTextField`, Passwortfeld
`AXTextField`/`AXSecureTextField` mit `AXFocused`.

## Echter Lauf (UC22) im Test-Tresor

Aufbau: `SECRETARIAT_HOME` auf einen Test-Tresor im Scratchpad; Eintrag `test/filltest/login` (Art login, `url`
`http://localhost:8765/filltest.html`, Benutzer `tester@example.test`, künstliches Passwort per `import`); Gegenprobe
`test/github/other` ohne Passwortfeld. Testseite vorübergehend unter `site/filltest.html`, danach entfernt.

1. Ohne Freigabe der Bedienungshilfen: Fenster zeigt „Access needed“ mit Erklärung; „Allow Access …“ fragt macOS an
   und öffnet die Liste. Befund aus dem ersten Versuch: Ohne diese Anfrage erscheint Secretariat dort nicht (Uli fand es nicht);
   der Knopf öffnet jetzt die Liste direkt.
2. Uli klickt im eingebauten Claude-Browser ins Passwortfeld, ⌃⌥⌘P: Fenster nennt `localhost`, der Eintrag steht oben.
3. Erster Versuch nach Touch ID: „Nothing was typed“ – die einmalige Prüfung nach 0,3 s fand den Fokus noch nicht im Feld.
   Behoben: bis zu 2 s warten, Aktivierung an die Ziel-App abgeben, fokussiertes Passwortfeld auch innerhalb der Seite erkennen.
4. Zweiter Versuch (Uli, Touch ID): Feld gefüllt. SHA-256 (gekürzt) des Feldinhalts `4e7d1d9200f717d2` = SHA-256 des
   gespeicherten Werts über `secretariat run` (`4e7d1d9200f717d2`) → byte-genau. Hinweis: Der Testwert wurde beim
   `.env`-Import nach ` #` als Kommentar gekürzt; geprüft ist der tatsächlich gespeicherte Wert.
5. Verlauf (`secretariat history --period day`): „App: Fill Localhost test/filltest/login/password“, ohne Wert.
   Der erste, abgebrochene Versuch stand ebenfalls dort; seit 548ff65 wird der Wert erst unmittelbar vor dem Tippen gelesen
   und protokolliert.
6. Zwischenablage: im ersten Lauf nicht belegbar (Uli arbeitete weiter); im zweiten Lauf mit Markierung belegt, siehe unten.
7. Sicherheitsprobe: Ein Testprogramm sollte tippen, während der Fokus im Chatfeld von Claude lag (`claude.ai/epitaxy/…`);
   es tippte nichts. Daraus die Regel: nur in `AXSecureTextField`, vor dem Tippen erneut geprüft.

## Zweiter echter Lauf auf dem Endstand 04c7856 (nach der Kritik)

Testpasswort neu: 25 Zeichen mit Umlauten, ß und € (zwei Tipp-Stücke), per `import`; SHA-256 (gekürzt) gespeichert `964b93b2f6c3cb60`.
Vor dem Lauf eine Markierung in die Zwischenablage gelegt (Hash `feb968aac2353c18`).

1. Uli: Cursor im Feld „User“, ⌃⌥⌘P: „Fill“ gesperrt mit Hinweis (UC22 Schritt 7; beobachtet von Uli).
2. Uli: Cursor im Passwortfeld, ⌃⌥⌘P, Enter, Touch ID abgebrochen: Feld leer (beobachtet von Uli); im Verlauf keine Zeile (UC22 Schritt 5).
3. Uli: erneut, Touch ID bestätigt: Feld enthält 25 Zeichen, SHA-256 `964b93b2f6c3cb60` = gespeicherter Wert → byte-genau über mehrere Stücke (Schritt 4).
4. Zwischenablage danach: Hash `feb968aac2353c18`, unverändert (Schritt 4).
5. Verlauf: genau eine neue Zeile „App: Fill Localhost test/filltest/login/password“ nach dem Import, ohne Wert (Schritt 6).
6. Freigabe-Knopf: fragt an und öffnet die Liste (im ersten Lauf von Uli genutzt, Schritt 8).

## Grenzen

- Schritte 1, 2 und „Feld leer nach Abbruch“ sind Ulis Beobachtung, nicht automatisch gemessen.
- Die Liste geteilter Hosting-Domains ist eine Auswahl aus der Public Suffix List, nicht die ganze; eine unbekannte geteilte Domain ändert nur die Reihenfolge, nie das Siegel.
- Release-Build hat eine andere Bundle-Kennung: Die Freigabe der Bedienungshilfen ist dort einmal neu nötig.
- Chrome-Browser und Safari nicht im echten Lauf geprüft (gleicher Mechanismus über `AXWebArea`).
