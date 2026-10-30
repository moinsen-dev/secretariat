# T025 – MCP-Tokens per `secretariat header` (Nachweis)

Stand: Korrekturen nach Kritik (Commit siehe Tracker), erster Lauf auf 08ddbe7, signiertes `dist/Secretariat.app` aus `script/build.sh` (Developer ID), macOS 27.0, Claude Code 2.1.x, 2026-10-30.

## Schritte und Beobachtung

| Schritt | Erwartung | Beobachtung |
|---|---|---|
| `xcrun swift test`, 4× hintereinander | grün | 71/71 viermal (nach den Korrekturen 72/72, mit Socket-Test 73/73). Neu: `headerPrintsOneJsonHeaderForTheMcpClient` (Bearer- und `--name`-Ausgabe, Persönlich-Feld → `personal_field`, Header-Name mit CR/LF → `invalid_arguments`, unbekanntes Feld, fehlendes Argument, Protokoll mit `header` ohne Wert, Touch-ID-Eintrag verweigert → `approval_denied`); Agenten-Wache verweigert `secretariat header … --bearer` und `~/bin/secretariat header a/b \| cat` |
| Wackelnder Test | stabil | `setupPreservesExistingBytesAndIsIdempotent` schlug vorher in etwa jedem dritten Lauf mit `setup_busy` fehl: Kindprozesse anderer Tests erbten den gesperrten Ordner-Deskriptor. Mit `O_CLOEXEC` 4 von 4 Läufen grün |
| UC20 (1): `dist/…/Secretariat header moinsen/tinideas/mcp/token --bearer` in eine Pipe zu einem Formprüfer | ein Schlüssel `Authorization`, Wert beginnt mit `Bearer tid_` | `shape ok: ['Authorization'] True 54`; der Wert selbst wurde nie ausgegeben |
| UC20 (2): derselbe Aufruf mit Terminal als stdout (`script -q /dev/null …`) und mit `> datei` | Abbruch ohne Wert | Terminal: „… not for a terminal …“; Datei: Exit 1, Datei enthält nur den Hinweis, `grep -c tid_` → 0 |
| UC20 (3): `claude mcp add-json --scope user tinideas-header-probe '{"type":"http","url":"https://tinideas.app/mcp","headersHelper":"<dist>/Secretariat header moinsen/tinideas/mcp/token --bearer"}'`, dann `claude mcp get` | Connected, kein Token in `~/.claude.json` | „✔ Connected“; `grep -c tid_ ~/.claude.json` → 0; Probe-Eintrag danach entfernt |
| UC20 (4): echtes Protokoll `~/Library/Application Support/SecretariatLocal/audit.log` | Zeile `header` mit Feld, ohne Wert | `{"action":"header","at":"2026-10-30T17:42:29Z","field":"moinsen\/tinideas\/mcp\/token"}`; `grep -c tid_` im Protokoll → 0 |
| UC20 (5): Agenten-Wache | Bash-Aufruf verweigert | Unit-Test (s. o.); Grund im Text: „prints a header with a secret (only Claude Code's headersHelper may call it)“ |

## Kritik und Korrekturen

Unabhängige Kritik (REWORK) fand fünf Punkte, alle behoben und erneut gelaufen (72/72 grün, zweimal; Claude-Code-Probe wieder „Connected“, kein Token in `~/.claude.json`):

1. Das MCP-Werkzeug `run_command` hätte `secretariat header` starten können; dessen Ausgabe geht ans Modell, maskiert wird nur Gebundenes. Jetzt setzt `run_command` `SECRETARIAT_MCP_CHILD=1` in seinen Kindprozessen, und `header` verweigert dort (Test über `McpServer.call`).
2. Die Wache prüfte Groß-/Kleinschreibung; der Bundle-Pfad `…/MacOS/Secretariat header` rutschte durch. Beide Regeln (`header`, `run --no-mask`) jetzt ohne Beachtung der Schreibung, mit Test.
3. „Nur in eine Pipe“ stimmte nicht (`> datei` ging). Jetzt nur Pipe oder Socket (`fstat`), Test mit Pipe und Datei.
4. Persönlich-Feld wurde erst nach Touch ID abgelehnt; jetzt vorher (Test: keine Freigabe-Anfrage).
5. Tests für Dateifeld, Reihenfolge und Ausgabeziel ergänzt.

## Grenzen

- Im MCP-Werkzeug `run_command` bestimmt der Agent die ganze argv und kann `SECRETARIAT_MCP_CHILD` absichtlich entfernen (`env -u …`). Die Markierung fängt versehentliche Aufrufe, keine Absicht. Startet `run_command` seinerseits Claude Code, schlägt dessen headersHelper fehl (sicher: keine Ausgabe).
- Ein Agent kann den Namen absichtlich verschleiern (Anführungszeichen, Variable); die Wache ist ein Gurt gegen versehentliche Aufrufe, keine Sicherheitsgrenze.
- Die Wache greift nur bei Agenten mit installiertem Claude-Code-Hook (`secretariat guard claude install`). Ein Programm, das Secretariat ohne Hook direkt in eine Pipe aufruft, bekommt den Wert, genau wie mit `run --no-mask`. Das ist dieselbe Grenze wie bisher, nicht neu.
- Die Umstellung des bestehenden TinIdeas-Eintrags von `~/bin/mcp-bearer` auf `secretariat header` folgt nach der Installation von 1.13.0; bis dahin ist `~/bin/secretariat` noch 1.12.0.
