# Unabhängige Design-Kritik: Redesign 2026-11-12

Prüfer: eigener Kritiker-Agent (Opus) gegen Apple HIG (Liquid Glass, Materials, Sidebars, Sheets, Accessibility), mit Code und Aufnahmen aus `docs/design/`.

## Runde 1 (Commit 5c484b6): REWORK

Muss: VoiceOver-Namen für Zeigen/Kopieren und Formularelemente; Kontrast der Badges (Weiß auf Orange/Grün); Fokus, ⏎ und Esc im Sheet; Backticks in Fußnoten.
Sollte: Organisation in Zeilen, Menü „Item“ mit ⌘E, echte SDK-Version statt fester Zahl, Fehler oben, Probezeit nicht als Textknopf in der Symbolleiste, Lizenz- und Vorlagenfenster mit Systemknöpfen.
Alles umgesetzt in 0b9024a und 733acb1.

## Runde 2 (0b9024a, 733acb1): PASS

Alle Muss-Punkte behoben. Neu als Sollte: ⌘⌫ im Menü „Item“ überstimmt Textfelder (Zeilenlöschen); behoben in 8715d4a (Kurzbefehl entfernt, ⌫ in der fokussierten Liste löscht weiter). Offen als Beobachtung: Seitenleiste im aktiven Fenster neben Notizen vergleichen; „web“ als Organisation bei Website-Logins wirkt technisch.

URTEIL UC24: PASS

## Planprüfung (R034, P24, UC24, T030)

Runde 1 REWORK: T030 nannte den Vorlagen-Editor als `Form(.grouped)` und Fokus für alle Editoren; R034/UC24 versprachen VoiceOver-Namen für alle Bedienelemente und Fokus als geprüften Schritt. Formulierungen auf das Gebaute und Geprüfte begrenzt.
Runde 2 PASS (Plan und UC24). Hinweis umgesetzt: R034 nennt, dass Löschen ins „…“-Menü wanderte und die Liste keine Abschnitte je Konto mehr hat.

URTEIL PLAN: PASS
URTEIL UC24: PASS
