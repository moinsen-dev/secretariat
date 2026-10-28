# Preis-Leistung Secretariat (28.10.2026)

Grundlage: `2026-10-28-markt-secretariat.md` (gleicher Tag, Quellen dort). Hier nur der Abgleich mit dem gebauten Stand 1.8.0 und was 39 € tragen würde.

## Was die Kategorie heute leistet

| Fähigkeit | 1Password | Infisical / Doppler | dotenvx / Varlock | Indie-OSS (LLM Secrets, tsm, keypo …) | **Secretariat 1.8** |
|---|---|---|---|---|---|
| Agent bekommt Namen statt Werte | ja (MCP, `op run`) | ja | Varlock ja, dotenvx nein | ja | ja (`run`, MCP) |
| Ausgabe maskieren | unklar | – (Proxy) | dotenvx `--redact`, Varlock | teils | ja, automatisch bei Pipe/Agent |
| Freigabe per Touch ID | pro Aktion | Sessions/RBAC | – | Session-weit | **pro Eintrag** |
| Commit-Sperre | Hooks | – | Varlock-Muster-Scan | – | **gegen eigene bekannte Werte**, 438 Repos |
| Werte in Cloudflare/Supabase/GitHub schreiben + veraltete Kopien | – | Syncs (Team-Plan) | – | – | **ja, mit Stale-Tracking** |
| Massenimport aller `.env` | – | CLI-Import | – | – | **ja, ganzer Baum** |
| Konten, Kennungen, Firmen-Identität | Passwortmanager | – | – | – | **ja (Vorlagen, company.md)** |
| Proxy: Schlüssel verlässt den Tresor nie | – | **Infisical Agent Vault** | – | – | nein |
| Konto/Server/Abo nötig | Abo | Konto/Cloud | nein | nein | **nein** |
| Preis Solo | im Abo | frei | frei | frei | 39 € einmalig |

## Ehrliche Lage

- Das Kernversprechen („Agent sieht den Wert nicht“) ist 2026 Standard und gratis zu haben.
- Unser Vorsprung ist das **Bündel** für Solo-Entwickler mit vielen Projekten: Touch ID pro Eintrag, Maskierung, Commit-Sperre gegen echte Werte, Ziele mit Stale-Tracking, Massenimport, Identität. Einzeln baut das jeder Agent an einem Wochenende nach.
- Was nicht nachzubauen ist, sind die zähen Teile: Keychain-Sync mit Provisioning-Profil, CLI im signierten Bundle, Notarisierung, Threat Model, Pflege.

## Was den Preis tragen würde (Vorschläge, nach Aufwand/Wirkung)

1. **Leck-Suche rückwärts** (`secretariat sweep ~/work`): alle Repos samt Git-Historie gegen die *eigenen bekannten Werte* prüfen und sagen, welcher Schlüssel schon einmal committet wurde und rotiert werden muss. Kann sonst niemand ohne Konto; wir haben die Werte. Aufwand klein (GitGuard-Logik + `git log -p`).
2. **Agenten-Wache für Claude Code** (PreToolUse-Hook): blockt `cat .env`, `printenv`, `env`, `docker compose config` und Lesezugriffe auf bekannte Schlüsseldateien, bevor sie laufen. Trifft genau die dokumentierten Vorfälle (The Register, Issue #65122). Aufwand klein.
3. **`.env`-Aufräumen nach dem Import**: übernommene `.env` in den Papierkorb, `.env.example` mit Namen erzeugen, Profil binden. Schließt die offene Baustelle „alte .env liegen noch herum“. Aufwand klein.
4. **Proxy-Modus** (`secretariat proxy PROFILE`): lokaler HTTPS-Proxy hängt Authorization-Header an, der Kindprozess bekommt den Schlüssel gar nicht. Löst das Gleicher-Nutzer-Problem für HTTP-APIs teilweise. Aufwand mittel, größter Abstand zu den Indie-Tools, gleichauf mit Infisical.
5. **Ablauf-Erinnerungen** als macOS-Mitteilung (Daten haben wir schon). Aufwand sehr klein.

Bewusst nicht: Teams/Teilen, Windows, eigener Server.

## Preis-Empfehlung

- **Mit 1–3 (ein Tag Arbeit eher Stunden): 39 € halten, Launch 29 €.** Dann gibt es drei Dinge, die kein Gratis-Werkzeug ohne Konto kann, und die Seite kann sie zeigen.
- **Ohne Ergänzungen: 24 € regulär, Launch 19 €.** Das liegt unter der Spontankauf-Schwelle neben 1Password-Abo und Gratis-OSS.
- Unabhängig davon: **Quelltext offen (source-available)** stärkt das Vertrauen mehr als jede Funktion; alle Indie-Konkurrenten sind offen.
