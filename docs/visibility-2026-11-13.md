# Sichtbarkeit von Secretariat – Befund und Plan (2026-11-13)

Frage (Uli): Bekommt die Website genug Beachtung, und wie werden wir im Thema „KI-Entwicklung und Secrets“ sichtbarer?
Regeln: Logbook „ASO, SEO und GEO – Übersicht“ (verbindlicher Ablauf), „GEO – Sichtbarkeit in KI-Antworten“, Ref `ki-sichtbarkeit-pruefen.md`.

## Befund

**Besuche (Pulse, Cloudflare Web Analytics, ohne Bots):** 26 in 7 Tagen (Woche davor 30), 90 im Monatsfenster von Pulse (davor 40).
Google-Klicks lassen sich für die Unterdomain nicht trennen (Search-Console-Eigenschaft `sc-domain:moinsen.dev`).

**Index (Google, im echten Browser, `site:secretariat.moinsen.dev`):** nur die Startseite. `/teams` und `/threat-model` fehlen.

**Technik (vor ad97d27):** kein `robots.txt`, keine Sitemap, kein Canonical, keine Open-Graph-Tags, kein strukturiertes Datum.
Jede unbekannte Adresse lieferte die Startseite mit Status 200 (Cloudflare Pages ohne `404.html` = SPA-Rückfall, also „soft 404“).

**Nachfrage (DataForSEO Labs, USA, Englisch, 12 Monate; Kosten 0,09 USD):**

| Suchbegriff | Suchen/Monat | Schwierigkeit | Bemerkung |
|---|---|---|---|
| claude code security | 2.900 | 49 | stark gestiegen (Jan 140); Google zeigt KI-Übersicht mit Anthropic, Reddit, GitHub |
| 1password cli | 1.600 | 30 | Vergleichsziel |
| claude code api key | 1.300 | 30 | plus rund 1.000 in Varianten („use/with/set/helper api key“) |
| codex api key | 1.000 | 9 | leicht; Seite 1 voller Forenfragen |
| ai agent security | 480 | 21 | Klickpreis 53 USD |
| secrets management | 480 | 29 | informational |
| api key manager | 140 | 8 | |
| mcp server authentication | 140 | 16 | |
| where to store api keys | 70 | 16 | Klickpreis 126 USD |
| „env file“-Formulierungen | ≤ 10 | – | so sucht kaum jemand |

Auf Seite 1 aller zehn geprüften Begriffe steht Secretariat nicht. Alle zehn haben eine Google-KI-Übersicht; zitiert werden
offizielle Doku, Reddit, Stack Overflow und GitHub-Issues.

**KI-Suche (Parallel-Websuche, Frage „Werkzeug, das API-Schlüssel vor Claude Code verbirgt, Mac“):** acht Treffer, alle andere
Werkzeuge, fast alle kostenlose GitHub-Projekte: akm/paperfoot (Homebrew, Launch-Video, „19.000 Aufrufe in fünf Wochen“), NoxKey
(gratis, Mac App Store, MCP), mxkey, agent-secrets, secrets-helper, claude-secrets, sealref, secret-safe-handoff. Secretariat nicht.
Das GitHub-Repo `moinsen-dev/secretariat` hat keine Topics und 0 Sterne.

## Was das heißt

1. Wir sprechen eine Sprache, die niemand sucht („.env“, „keys“). Gesucht wird „Claude Code API key“, „Codex API key“, „Claude Code security“.
2. KI-Antworten speisen sich aus GitHub-READMEs, Reddit und Doku. Dort sind die kostenlosen Werkzeuge, wir nicht.
3. Der Markt der einfachen Keychain-CLIs ist voll und kostenlos. Secretariat unterscheidet sich durch das Paket (App, Erfassen,
   Screenshots, Commit-Wächter mit echten Werten, Sweep, Fill/Save Login, Verlauf, Sicherung, Ziele mit Rotation, Team-Pakete);
   das muss jede Seite in einem Satz sagen (Regel „argue why not clone“).

## Umgesetzt (ad97d27, wartet auf Deploy)

- `robots.txt` mit Sitemap, `sitemap.xml` (Start, Teams, Bedrohungsmodell), echte `404.html` (noindex) statt soft 404.
- Canonical und Open Graph/Twitter auf allen drei Seiten (Bild: App-Screenshot).
- JSON-LD `SoftwareApplication` (Name, Kategorie, macOS 14+, Version, Download, Preis 39 EUR, Autor).
- Titel: „Secretariat – API keys for Claude Code & Codex agents on Mac“.
- Vergleich: kostenlose Keychain-Werkzeuge (akm, NoxKey, mxkey) namentlich, Stand November 2026, mit klarem „Choose Secretariat if“.
- Bewusst nicht: `llms.txt` (für Google wirkungslos, Nutzung anderswo nicht belegt), FAQ-JSON-LD (Google-Ergebnisform eingestellt).

## Plan (nach Hebel geordnet)

| # | Maßnahme | Ziel / Begriff | Aufwand | Wer |
|---|---|---|---|---|
| 1 | Deploy, Sitemap in Search Console (`sc-domain:moinsen.dev`) und Bing einreichen, `/teams` und `/threat-model` zur Indexierung anmelden | Index | 5 Min | Uli |
| 2 | GitHub-Topics setzen: `claude-code`, `codex`, `ai-agents`, `api-keys`, `secrets-management`, `macos`, `keychain`, `mcp`, `developer-tools`, `swift`; README um „Quick start“ und Vergleich ergänzen | GEO über GitHub | 10 Min | Freigabe Uli (öffentlich) |
| 3 | Anleitungsseiten, je eine Frage, ehrlich mit Grenzen: „Use an API key with Claude Code without pasting it“, „Codex CLI with an API key, safely“, „Keep secrets away from Claude Code“ (Sicherheit), „1Password CLI or Secretariat for coding agents“ | claude code api key, codex api key, claude code security, 1password cli | je 20–30 Min | Claude, Prüfung gegen offizielle Doku |
| 4 | Produktlücke als Suchanker: Claude-Code-`apiKeyHelper` direkt aus Secretariat (wie `header` für MCP: nur in eine Pipe) | claude code api key helper | 30 Min | Claude, Ulis Ja (neue Funktion) |
| 5 | Verteilung, wo KI-Antworten herkommen: Show HN, r/ClaudeAI/r/ClaudeCode (eigener Beitrag mit den echten Nutzungszahlen), hilfreiche Antworten in passenden GitHub-Issues (z. B. `.claudeignore`), MCP-Verzeichnisse, „awesome-claude-code“-Listen | Erwähnungen, Backlinks | laufend | Uli postet (Entwürfe von Claude) |
| 6 | Homebrew-Tap `moinsen-dev/tap` (`brew install --cask secretariat`) | Entwickler-Weg, „brew“-Suchen | 20 Min | Claude, Ulis Ja (öffentliches Repo) |
| 7 | Messen: Secretariat-Begriffe in Pulse (braucht Standort USA/Englisch je Website), monatliche Antwortstichprobe in ChatGPT/Perplexity nach Logbook-Protokoll (ohne Marke, Vergleich, mit Marke) | Wirkung | 15 Min + monatlich | Claude |

**Abbruch-/Erfolgskriterium (Vorschlag):** nach 8 Wochen Startseite und mindestens zwei Anleitungen im Index; mindestens ein
Begriff aus Tabelle 1 in den Top 20; Secretariat in mindestens 1 von 10 Antworten der Stichprobe „ohne Marke“. Sonst Kanal überdenken.

## Stand 2026-11-13 (Nachtrag)

- SEO-Grundlagen live (Deployment 08b66139), Sitemap-Einreichung bei Google/Bing durch Uli offen.
- Anleitungen `/claude-code-api-key` und `/codex-api-key` geschrieben, gegen offizielle Doku geprüft (unabhängiger Faktencheck: 5 Fehler gefunden und behoben, u. a. Codex-Speicherarten, gekürzte Schlüsselanzeige von `codex login`, Touch ID als harte Grenze statt „nur ein Programm“), in Sitemap und FAQ verlinkt; Commits aac2878, 485e9ee; Deploy durch Uli offen.

