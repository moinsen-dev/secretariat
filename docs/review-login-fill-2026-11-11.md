# Unabhängige Kritik: Login ausfüllen (PLAN-Änderung R032/P22/UC22/T028, UC22) – 2026-11-11

Kritiker: separater Agent mit frischem Kontext, nur lesend (Code, PLAN, Prüfbericht, `xcrun swift test --filter LoginFill`).

## Runde 1 (Stand 548ff65): PLAN REWORK, UC22 REWORK

Muss-Punkte: (1) Ersatzprüfung „Passwortfeld mit AXFocused auf der Seite“ auch bei fokussiertem sichtbarem Feld; (2) keine
Public Suffix List, Siegel für gleiche Domain/Name hilft Phishing (evil.pages.dev); (3) Feldwahl nimmt Notizen/Geheimnisse,
Steuerzeichen könnten abschicken oder ins nächste Feld wechseln; (4) `.cghidEventTap` statt Ziel-App; PLAN: Wortlaut Touch ID
uneinheitlich, „Passwortfeld“ vs. Code, T028-Abhängigkeit T025 statt T024, Dateiliste falsch; Bericht: Zwischenablage,
Abbruch und Wert über 16 Zeichen nicht belegt.

## Umsetzung (04c7856, 7d2635b, 169888c)

Ersatzprüfung nur bei fokussierter `AXWebArea`; geteilte Hosting-Domains aus dem privaten PSL-Teil nie gleiche Domain, Siegel
nur bei exakt gleichem Host; nur Feld `password`, Steuerzeichen abgelehnt; `postToPid` an die Ziel-App; PLAN angeglichen;
zweiter echter Lauf mit 25 Zeichen, Zwischenablage-Markierung, Abbruch.

## Runde 2 (Stand 7d2635b): PLAN PASS, UC22 PASS

Keine Muss-Punkte. Teil-PSL ist ein vertretbarer, ehrlich dokumentierter Kompromiss, weil das Siegel nur noch beim exakten
Host erscheint. Sollte-Punkte (in 169888c erledigt): Testanzahl im Bericht 9 statt 10; R032-Zusage „Abbruch, sobald eine
andere App vorn ist“ abschwächen (Front-Prüfung wirkt wegen schlafendem Hauptthread kaum, Sicherheit trägt `postToPid`);
weitere geteilte Domains aus dem Umfeld (r2.dev, trycloudflare.com, ts.net, cloudflareaccess.com).
