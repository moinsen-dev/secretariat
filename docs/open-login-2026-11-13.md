# Öffnen und anmelden (T038, UC32), 2026-11-13

Anlass: Uli wollte direkt aus Secretariat eine Anmeldeseite im Standardbrowser öffnen und ausfüllen lassen, statt erst die Seite aufzurufen und dann ⌃⌥⌘P zu drücken.

## Ablauf

1. Knopf „Open and Sign In“ im Eintrag, `secretariat open PATH` oder MCP `open_login`. CLI und MCP prüfen nur, ob der Eintrag eine Webadresse und ein Feld `password` hat, und übergeben den Pfad per systemweiter Mitteilung an die App (die App antwortet; läuft sie nicht, startet die CLI sie im Hintergrund). Kein Wert verlässt die App.
2. Die App öffnet die gespeicherte Adresse mit dem Standardbrowser (`NSWorkspace`) und sucht bis zu 15 Sekunden über die Bedienungshilfen ein Passwortfeld auf einer Seite **genau dieses Hosts** (gleiche Regel wie beim Ausfüllen; `ts.net` bleibt Shared-Hosting, ein anderer Rechner im Tailnet passt nicht).
3. Touch ID („sign in to HOST with PATH“), dann Browser nach vorn, Benutzername ins Textfeld davor (nur wenn er abweicht; Feld wird geleert und das Ergebnis geprüft), Passwort über denselben Tippweg wie Fill Login (`PasswordTyping`: Passwortfeld, gleiche Seite, leeren, tippen, Länge prüfen).
4. Nicht abgeschickt. Kein Formular (etwa schon angemeldet) oder keine Freigabe: Seite bleibt offen, Hinweis auf ⌃⌥⌘P.

## Nachweise

| Prüfung | Beobachtung |
|---|---|
| unit | `xcrun swift test` 142/142, neu `LoginOpenTests` (Adresse aus url/website/address, nur http(s); Prüfung ohne Passwort/Adresse; Same-Host bei `ts.net` und Ports; CLI `open` und MCP `open_login` übergeben nur den Pfad, kein Wert in der Ausgabe; Verlaufstexte behalten die Schreibweise des Hosts) |
| cli | `script/regression_cli.sh` 24/24 |
| macos, Testseite | Test-Tresor (`SECRETARIAT_HOME`), lokale Seite mit Benutzer- und Passwortfeld auf localhost: `secretariat open` öffnete Chrome (Standardbrowser), nach Touch ID standen Benutzername und Passwort im Formular, Verlauf „Opened localhost:… to sign in with …“ und „Sign in … /password“ |
| macos, echter Login | Paperless-ngx im Tailnet (Host unter `ts.net`, http mit Port), nach Abmelden in Chrome: `secretariat open` öffnete die Anmeldeseite, nach Touch ID Benutzername und Passwort eingetragen, Uli schickte das Formular ab und war angemeldet (Screenshot lokal, nicht im Repo wegen Hostname). Den Knopf in der App hat Uli selbst ausprobiert: funktioniert. |

Kritik: Selbstprüfung.
Grenzen: nur mit Chrome als Standardbrowser geprüft (Safari und Firefox nicht); Abbruch von Touch ID endet ohne Hinweis; der Lauf über MCP aus einem echten Client wurde nicht gemacht (gleicher Weg wie die CLI, im Unit-Test belegt).
