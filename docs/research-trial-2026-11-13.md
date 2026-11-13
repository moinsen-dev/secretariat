# Recherche-Probelauf Lösch-Wege (T037) – 2026-11-13

Auftrag (Uli): 20 Sites aus dem echten Tresor ohne bekannten Lösch-Weg recherchieren lassen und eintragen.

## Ablauf

- `login-sites --needs-route --limit 20` aus dem echten Tresor (signiertes `dist/`-Paket). Befund dabei: öffentliche IP-Adressen erschienen als „Sites“; behoben in 94e016e (jede IP-Adresse zählt als Gerät).
- Zwei Recherche-Agenten (je 10 Sites, nur Site-Namen, keine Benutzernamen) lasen offizielle Hilfe- und Datenschutzseiten; Ergebnis je Site: Löschseite, Kontakt, Schwierigkeit, Notiz, Quelle, Sicherheit. Dauer 3,6 und 4,3 Minuten, zusammen rund 290 000 Tokens (etwa 14 500 je Site).
- Stichprobe gegen die Quellen: 6 Seiten selbst abgerufen, 6 von 6 bestätigt. Eine Quelle ersetzt (Hilfeseite auf fremdem Host → offizielle Hilfeseite).
- Code-Anpassung: Dienste, die eingestellt sind, haben weder Löschseite noch Kontakt; „impossible“ ist jetzt mit Quelle und Notiz allein erlaubt (Unit-Test).
- Eingetragen mit `login-route` an 30 Logins.

## Ergebnis (nur Zahlen)

| Schwierigkeit | Sites |
|---|---|
| einfach | 3 |
| mit Zusatzschritten | 7 |
| über Support oder Antrag | 7 |
| nicht möglich / eingestellt | 3 |

Alle 20 Sites bekamen einen Weg; 2 mit geringer Sicherheit (eingestellte Dienste, nur Drittquelle). Inventur danach: ohne Weg 1001 statt 1036 Logins, Sites ohne Weg 551.

## Folgerung

- Qualität in der Stichprobe gut; Kosten sind der begrenzende Faktor (Hochrechnung für die übrigen 551 Sites: rund 8 Mio. Tokens).
- Hilfreich wäre, erst die Sites zu recherchieren, die Uli schließen will (Entscheidung „Close account“), statt alle.
