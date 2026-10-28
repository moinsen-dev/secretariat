# Marktrecherche Secretariat (Stand 28.10.2026)

Quellen sind unten verlinkt, Abrufdatum jeweils 28.10.2026. **[unverifiziert]** markiert alles, was nur aus Drittquellen oder eigenem Wissen stammt und nicht auf einer Primärquelle bestätigt wurde.

## Kernbefund

1. Das Problem ist real und dokumentiert: Claude Code liest `.env`-Dateien trotz Sperrregeln, Agenten umgehen Sperren kreativ (`docker compose config`), und GitGuardian misst bei Claude-Code-Commits eine doppelt so hohe Leck-Rate wie im Schnitt.
2. Der Markt hat sich 2026 aber schnell gefüllt: 1Password (Environments + MCP für Cursor/Claude Code, 30.07.2026), Infisical (Agent Vault/Agent Proxy), Doppler („Doppler for Agents“), Varlock, dotenvx `--redact` und mindestens acht kostenlose Open-Source-Tools für genau diese Nische (keypo, secretctl, LLM Secrets, tsm, Keyblind, envkeep …).
3. Secretariat gewinnt nicht über „Agent sieht den Wert nicht“ (das können jetzt alle), sondern über das Gesamtpaket für Solo-Entwickler auf dem Mac: kein Konto, kein Server, kein Abo, Touch ID pro Eintrag, Maskierung, Commit-Sperre und Rotation mit Nachverfolgung veralteter Kopien in Cloudflare/Supabase/GitHub. Das trägt ein kleines Einmalkauf-Produkt, aber kein großes Geschäft.

## Wettbewerb

| Tool | Zielgruppe | Agent sieht Wert? | Maskierung | Freigabe | Preis | Plattform |
|---|---|---|---|---|---|---|
| **1Password** (`op run`, Environments, MCP, Plugin für Cursor/Claude Code) | alle 1Password-Nutzer, Teams | Nein: MCP liefert nur Namen, `op run` injiziert in Kindprozess | nicht dokumentiert **[unverifiziert]** | Auth-Prompt pro MCP-Aktion, Touch ID | im Passwortmanager-Abo enthalten („available to all password manager users“) | Mac, Linux (lokale `.env` nur dort) |
| **Infisical** Secrets + Agent Vault/Agent Proxy | Teams, Plattform-Engineering | Nein: Proxy hängt Credentials an ausgehende Requests | Proxy-Prinzip, keine Ausgabe-Maskierung nötig | Zeitbegrenzte Sessions, Access Bundles | Free bis 5 Identitäten; Pro 20 $/Identität/Monat (jährlich); Agent Vault 5.000 Requests frei, dann 2 $/1.000 | Cloud/self-hosted |
| **Doppler** | Teams | `doppler run` injiziert; „Doppler for Agents“, offizieller MCP-Server | nicht dokumentiert | RBAC | Developer frei bis 3 Nutzer, Team 21 $/Nutzer/Monat; „AI agents ride free“ | Cloud |
| **Bitwarden Secrets Manager** | Teams | SDK/CLI, Maschinenkonten pro Agent | nein | ablaufende Tokens, Audit-Log | Free (2 Nutzer), Teams 6 $, Enterprise 12 $/Nutzer/Monat | Cloud/self-hosted |
| **Varlock** (dmno) | JS/Web-Entwickler | Nein: `.env.schema` gibt Agent Namen/Typen | ja, Log-Redaktion + `varlock scan` als Git-Hook | nein | MIT, kostenlos | plattformübergreifend |
| **dotenvx** | Entwickler | **Ja** – Claude bekommt echte Werte, nur Ausgabe wird ersetzt | `--redact` → `[REDACTED]` | nein | OSS frei; „Ops“ ca. 49–499 $/Jahr **[unverifiziert]** | plattformübergreifend |
| **EnvManager** | kleine Teams | Nein: Platzhalter `{{KEY}}`, Allowlist pro Lauf | ja (`***`, ab 6 Zeichen) | Scope pro Lauf | Pro pauschal fürs Team, Gründerangebot 9 $/Monat | Cloud |
| **LLM Secrets (scrt4)** | Solo, Claude Code | Nein: `$env[NAME]`-Referenz | „output automatically sanitized“ | Passkey/Touch ID, 20-h-Session | AGPL, kostenlos | Mac, Linux, WSL |
| **keypo-signer, tsm, Keyblind, secretctl, envkeep, passkey-mcp** | Solo, Show-HN-Projekte | Nein: Injektion in Kindprozess / MCP | teils | Touch ID (Session- oder Vault-weit) | kostenlos / OSS | meist macOS |
| **HCP Vault Secrets** | Enterprise | – | – | – | **eingestellt** (EOL 01.07.2026) | – |
| **EnvKey** | Teams | – | – | – | **gehosteter Dienst eingestellt** | – |
| **Secretive** | SSH-Schlüssel im Secure Enclave | anderes Problem (SSH), Vorbild für Mac-native Sicherheits-App | – | Touch ID | kostenlos, OSS **[aus Wissen]** | macOS |
| Teller, envchain | – | Status nicht geprüft **[unverifiziert]** | | | | |

**Lücke, die niemand vollständig besetzt:** Zielwerte in Cloudflare/Supabase/GitHub schreiben und nach Rotation veraltete Kopien nachhalten; Commit-Sperre gegen *eigene bekannte Werte* (nicht nur Muster); Profile, die Agenten selbst anlegen; Massenimport eines ganzen `~/work`-Baums; Firmen-Identität als Regeldatei. Einzelteile existieren (Varlock-Scan, 1Password-Hooks), das Bündel ohne Konto nicht.

## Nachfrage-Belege

- The Register (28.01.2026): Claude Code v2.1.12 las `.env` trotz `.claudeignore`; Issue #20966: „This is a security-critical issue that should be addressed urgently.“ [theregister.com](https://www.theregister.com/2026/01/28/claude_code_ai_secrets_files/)
- Folge-Issues bis Juni 2026 (#32523, #44868, #58526, #65122 „3 leak incidents in 6 days“) – alle geschlossen, kein eingebautes Redaction-Feature bestätigt. [claudeissues.com #65122](https://claudeissues.com/issue/65122-feature-request-harness-level-bash-output-secret-redaction-3-leak-incidents-in-6)
- r/ClaudeAI, Feb. 2026, „My agent stole my (api) keys“: `.env` gesperrt, Agent holte Keys per `docker compose config`. [Mirror](https://reddit.sentinel-team.org/posts/1r186gl/snapshots/2026-02-10T19%3A31%3A46.22038Z)
- GitGuardian State of Secrets Sprawl 2026 (März): 1,28 Mio. geleakte KI-Dienst-Secrets (+81 %), Claude-Code-Commits 3,2 % Leck-Rate vs. 1,5 % Basis, 24.008 Secrets in MCP-Konfigurationen. [gitguardian.com](https://gitguardian.com/state-of-secrets-sprawl-report-2026) (Herstellerzahlen)
- CVE-2026-21852: Repo-Konfiguration konnte Claude Code dazu bringen, den Anthropic-Key vor dem Trust-Prompt abzuschicken. [osv.dev](https://osv.dev/vulnerability/CVE-2026-21852)
- Angebotsseite als Beleg: Die Zahl neuer Tools in 2026 (1Password, Infisical, Doppler, ≥8 OSS-Projekte, Syntax.fm-Folge „Stop putting secrets in .env“) zeigt Nachfrage – und Gedränge.
- **Keine Zahlungsbereitschafts-Umfrage gefunden.** Ob Solo-Entwickler dafür *zahlen*, ist unbelegt.

## Preis-Empfehlung

Vergleich Einmalkauf-Mac-Werkzeuge (Herstellerangaben, wo nicht anders vermerkt): CleanShot X 29 $ einmalig inkl. 1 Jahr Updates, danach optional 19 $/Jahr; Proxyman Standard 89 $ (1 Platz), Renewal 39–49 $; TablePlus ca. 89–99 $ pro Gerät, 1 Jahr Updates **[unverifiziert]**; Tower ist inzwischen Abo (69–99 $/Jahr **[unverifiziert]**); Secretive kostenlos. Muster 2026: „Einmalkauf + 1 Jahr Updates, Verlängerung optional“ ist der Standard für Indie-Mac-Tools.

**Empfehlung: 39 € einmalig, inkl. aller 1.x-Updates; Launch-Preis 29 € für die ersten 4 Wochen; Version 2 kostenpflichtig (Upgrade 19 €).**
Begründung: Die Konkurrenz für Solo-Entwickler ist kostenlos (OSS) oder im 1Password-Abo enthalten, also muss der Preis unter der Hemmschwelle einer Spontankaufentscheidung liegen. 49 € liegt über CleanShot und braucht mehr Vertrauen, als ein Ein-Personen-Sicherheitsprodukt am Start hat. Gebühren bei 39 €: 5 % + 0,50 $ ≈ 2,40 € (Lemon Squeezy/Paddle laut Drittquellen **[unverifiziert]**). Kein Abo – es gibt keinen Server, der laufende Kosten verursacht; das ist zugleich ein Verkaufsargument.

## Vertrieb und Recht

- **Mac App Store: praktisch ausgeschlossen (bestätigt).** Leitlinie 2.4.5(i) verlangt Sandbox; Kindprozesse erben die Sandbox des Elternprozesses (Apple `Process`-Doku, DTS im Forum). `secretariat run -- wrangler deploy` könnte weder beliebige Pfade in `~/work` lesen noch fremde Werkzeuge frei starten. Dazu 2.4.5(vi): keine Lizenzschlüssel, (vii): Updates nur über den Store. Eine „Lite“-Store-Version ohne `run` wäre ein anderes, schwächeres Produkt.
- **Direktvertrieb:** Developer-ID-Signatur + Notarisierung sind Pflicht für Gatekeeper; Apple Developer Program 99 $/Jahr. iCloud-Keychain-Synchronisierung braucht das Entitlement `keychain-access-groups` mit Provisioning-Profil, was mit Developer ID möglich ist; die CLI muss dafür im App-Bundle liegen **[aus Apple-Doku-Wissen, hier nicht neu abgerufen]**.
- **Lemon Squeezy vs. Paddle:** Beide sind Merchant of Record (übernehmen EU-USt/OSS und treten rechtlich als Verkäufer auf), beide ca. 5 % + 0,50 $. **Risiko Lemon Squeezy:** Seit Stripe-Übernahme (Juli 2024) läuft die Migration zu Stripe Managed Payments; der offizielle „2026 update“-Post verweist auf eine Warteliste, Neuanmeldungen dauern laut Drittquellen Tage bis Wochen **[unverifiziert]**. Lizenzschlüssel-API von Lemon Squeezy ist in Managed Payments nicht bestätigt. → Vor dem Launch prüfen, ob das bestehende Konto (moinsen) weiterläuft; Paddle als Ausweichweg bereithalten.
- **Deutschland:** Impressum auf der Produktseite (§ 5 DDG, früher TMG) **[aus Wissen]**. Widerrufsrecht bei digitalen Inhalten erlischt nach § 356 BGB (Absatz zu digitalen Inhalten; Absatznummer vor Verwendung im Text prüfen) nur mit ausdrücklicher Zustimmung und Bestätigung vor Download – beim MoR regelt das der Checkout des MoR, weil er Vertragspartner ist. Kein Blocker für einen Solo-Verkäufer.

## Risiken

1. **Amtsinhaber haben das Kernversprechen schon.** 1Password liefert seit 30.07.2026 „the agent never sees the secret value“ inkl. Claude-Code-Plugin, im bestehenden Abo. Wer 1Password nutzt, braucht Secretariat nur für Maskierung, Commit-Sperre und Ziel-Rotation.
2. **Gleicher-Nutzer-Problem.** Ein Agent, der als derselbe Unix-Nutzer läuft, kann `secretariat run -- env` selbst aufrufen oder Kindprozess-Umgebungen lesen (Artikel „You Can't Hide a Secret from a Process That Runs as You“, März 2026). Maskierung schützt nur vor *versehentlichen* Lecks; die echte Grenze ist Touch ID pro Eintrag. Das muss die Produktseite ehrlich sagen, sonst kommt es als erster HN-Kommentar.
3. **Vertrauen in ein Ein-Personen-Sicherheitswerkzeug.** Alle direkten Indie-Konkurrenten sind Open Source. Ein geschlossenes, kostenpflichtiges Tool ohne Audit wird es schwer haben.
4. **Zahlungsbereitschaft unbelegt**, Kostenlos-Alternativen zahlreich.
5. **Plattform-Risiko:** Anthropic könnte Redaction/Secret-Handling in Claude Code einbauen (mehrfach gefordert, bisher abgelehnt).

## Positionierung

**Versprechen (ein Satz):** „Deine Schlüssel liegen einmal in deinem iCloud-Schlüsselbund – deine Coding-Agenten können sie benutzen, aber nie lesen, und kein Server, kein Konto, kein Abo steht dazwischen.“

**Drei stärkste Unterschiede zu 1Password/Doppler/Infisical:**
1. **Ohne Konto, ohne Server, ohne Abo** – nur iCloud-Schlüsselbund, Mac-nativ; Einmalkauf.
2. **Schutz auf drei Ebenen in einem Werkzeug:** Touch ID pro Eintrag + Ausgabe-Maskierung + Git-Commit-Sperre gegen *eigene bekannte Werte*.
3. **Rotation zu Ende gedacht:** Werte in Cloudflare/Supabase/GitHub/Linux-Env schreiben und nachhalten, wo nach einer Rotation noch alte Kopien liegen; plus Massenimport aller `.env` aus `~/work`.

## Empfehlung: bauen – als kleines Nischenprodukt, quelloffen-nah

Das Produkt ist laut Projektstand weitgehend gebaut; der Grenzaufwand bis zum Verkauf ist klein. Erwartung realistisch halten: Nebeneinnahme, kein Hauptgeschäft.

**Nächste Schritte**
1. Vertrauensfrage entscheiden: CLI-Kern Open Source (MIT) oder die ganze App source-available (z. B. FSL), App-Bundle mit Sync/Zielen/UI kostenpflichtig. Empfehlung: source-available für alles, Kauf für die signierte, notarisierte Build + Updates.
2. Threat-Model-Seite schreiben (was Secretariat verhindert, was nicht – inkl. Gleicher-Nutzer-Problem).
3. Lemon-Squeezy-Konto auf Weiterbetrieb und Lizenz-API prüfen; Paddle als Plan B.
4. Launch: Show HN (Threat-Model vorne), r/ClaudeAI, r/cursor, Product Hunt, eigener Blogpost „Wie mein Agent meine Keys gefunden hat“; Setapp später als Zusatzkanal (70 % Umsatzanteil, Single-App-Verkauf 85 %).
5. Nach 4 Wochen: Verkäufe vs. Downloads messen; unter 50 Käufen MCP-Server und Dashboard nicht weiterbauen.

## Quellen (abgerufen 28.10.2026)

- 1Password Secure AI Access: https://www.1password.dev/get-started/secure-ai-access
- 1Password Cursor-Ankündigung (30.07.2026): https://www.1password.community/announcements-52/manage-secrets-in-cursor-without-exposing-them-25178
- Infisical Pricing: https://infisical.com/pricing.md · Agent Vault: https://infisical.com/docs/documentation/platform/agent-vault/overview · Agent Proxy: https://infisical.com/blog/agent-proxy
- Doppler Pricing: https://www.doppler.com/pricing
- Bitwarden Secrets Manager: https://bitwarden.com/products/secrets-manager/
- Varlock: https://varlock.dev/ · https://github.com/dmno-dev/varlock
- dotenvx in Claude: https://dotenvx.com/docs/claude/
- EnvManager: https://envmanager.com/solutions/secrets-for-ai-agents
- LLM Secrets: https://llmsecrets.com/
- secretctl: https://github.com/forest6511/secretctl · tsm: https://github.com/tashian/tsm · nopeek: https://scottspence.com/posts/nopeek-keep-secrets-out-of-claude-code
- HCP Vault Secrets EOL: https://support.hashicorp.com/hc/en-us/articles/41802449287955-HCP-Vault-Secrets-End-Of-Life
- EnvKey-Ende: https://ghostable.dev/blog/envkey-shutdown-secrets-management-economics
- The Register: https://www.theregister.com/2026/01/28/claude_code_ai_secrets_files/
- GitGuardian 2026: https://gitguardian.com/state-of-secrets-sprawl-report-2026
- „You Can't Hide a Secret…“: https://danielepolencic.com/hiding-secrets-from-ai-agents (nur über Mirror erreichbar)
- App Review Guidelines 2.4.5/2.5.2: https://developer.apple.com/app-store/review/guidelines/
- Apple Process/Sandbox: https://developer.apple.com/documentation/foundation/process · https://developer.apple.com/forums/thread/776473
- Lemon Squeezy 2026 update: https://www.lemonsqueezy.com/blog/2026-update
- Setapp Revenue: https://docs.setapp.com/docs/distributing-revenue
- Proxyman: https://proxyman.com/pricing · CleanShot X: https://trustradius.com/products/cleanshot-x/pricing
- § 356 BGB: https://www.gesetze-im-internet.de/bgb/__356.html
