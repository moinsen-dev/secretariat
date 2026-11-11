# Unabhängige Kritik: Login aufnehmen (R033, P23, UC23, T029) und gemeinsamer Tippweg – 2026-11-11

Kritiker: separater Agent mit frischem Kontext, nur lesend (Code, PLAN, Prüfbericht `docs/save-login-2026-11-11.md`,
`xcrun swift test --filter LoginFill`).

- **Runde 1 (dd3ec78): PLAN PASS, UC23 REWORK.** Muss: ⌘A über Tastencode 0 (AZERTY ⌘Q); Benutzernamen-Heuristik nahm
  jedes gefüllte Feld; Tippen auch ohne Passwortfeld und irreführende Meldung; Belege nicht auf dem Endstand.
- **Runde 2 (6f4844b): UC23 PASS, PLAN REWORK.** ⌘→/⌘⌫ an die Ziel-App mit Prüfung als sicher beurteilt. Muss: unbekannte
  Feldlänge galt als leer; Zusage „Codes und Nummern nie“ hielt nicht.
- **Runde 3 (68f6950): PLAN PASS, UC23 PASS, keine Muss-Punkte.** Sollte (umgesetzt im Folge-Commit): Stichwörter „account“/
  „konto“ und CSS-Klassen zu breit, Ausschlusswörter (code, key, token, secret, iban, recovery, otp, pin); Verlaufszeile erst
  nach dem Tippen; klare Meldung, wenn ein Browser keine Feldlänge liefert.
