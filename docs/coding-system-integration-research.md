# Coding-Systeme: Claude Code und OpenCode

Stand: 2026-10-22. Hintergrundrecherche anhand offizieller Dokumentation und des vorhandenen Secretariat-CLI-Codes. Keine Konfiguration eines Coding-Systems geändert; keine echten Agentensitzungen oder Credentials getestet. Die Codex-Ergebnisse wurden durch den koordinierenden Agenten beigesteuert.

## Empfehlung

Secretariat bleibt eine lokale CLI mit `secretariat run PROFIL -- PROGRAMM ARGUMENTE`. Das Coding-System ruft sie für den jeweiligen Projektbefehl über sein Shell-Werkzeug auf. Ein kleines Projektstartskript und eine kurze Anweisung in `AGENTS.md` machen dies wiederholbar. Für Claude Code kann eine bestehende `CLAUDE.md` dieselbe Anweisung über `@AGENTS.md` importieren. Ein Skill kann die Bedienung erklären; ein eigener MCP-Server ist dafür zunächst nicht erforderlich.

Beispiel für ein freigegebenes Projektprofil, kein bereits eingerichtetes Profil:

```sh
"$HOME/bin/secretariat" run mein-projekt -- npm run dev
```

In Projektanweisungen gehören Profilname, Startskript und Prüfkommando, keine Schlüsselwerte. Die genaue PATH-/Executable-Auflösung sollte pro Arbeitsplatz geprüft werden. Bei Remote-/Cloud-Ausführung steht der lokale macOS-Schlüsselbund nicht automatisch zur Verfügung.

## Verifizierte Dokumentationsfakten

### Codex

- Die lokal installierte CLI meldet `codex-cli 0.163.0`; ihre Hilfe bestätigt CLI- und MCP-Funktionen. Dies ist eine Bestandsprüfung, kein Ende-zu-Ende-Test mit Secretariat.
- `AGENTS.md` ist der offizielle Weg für persistente Arbeitsanweisungen. [AGENTS.md](https://developers.openai.com/codex/guides/agents-md)
- MCP unterstützt lokale stdio-Prozesse mit Kommando, Argumenten und Arbeitsverzeichnis. [MCP](https://learn.chatgpt.com/docs/extend/mcp)
- Die Umgebung gestarteter Shell-Unterprozesse kann durch `shell_environment_policy` gefiltert werden. Deshalb ist eine gestartete Coding-Sitzung mit geerbten Schlüsseln kein allgemeiner Nachweis, dass jedes Shell-Werkzeug dieselben Variablen erhält. [Shell-Umgebung](https://learn.chatgpt.com/docs/config-file/config-advanced#shell-environment-policy)

### Claude Code

- Projektanweisungen liegen normalerweise in `CLAUDE.md`. Aktuelle Versionen können `AGENTS.md` direkt lesen; laut Dokumentation setzt dies mindestens v2.1.277 voraus. Eine `CLAUDE.md` oder `CLAUDE.local.md` auf dem Projektpfad kann die automatische AGENTS-Übernahme verhindern. Der dokumentierte Import `@AGENTS.md` ist eine kompatible Möglichkeit, eine gemeinsame Quelle zu behalten. Anweisungen sind Modellkontext und keine harte Zugriffssperre. [Projektanweisungen](https://code.claude.com/docs/en/memory#agentsmd)
- Skills werden als `SKILL.md` beispielsweise in `.claude/skills/secretariat/` oder `~/.claude/skills/secretariat/` gefunden. Lokale persönliche Skills stehen Cloud-Sitzungen nicht automatisch zur Verfügung. [Skills](https://code.claude.com/docs/en/skills)
- Lokale MCP-Server werden als Prozesse über stdio gestartet, zum Beispiel mit `claude mcp add --transport stdio NAME -- PROGRAMM ARGUMENTE`. Ein stdio-Server ist daher ohne LaunchAgent oder dauerhaft laufenden Systemdienst möglich. Das bestehende `secretariat run` ist selbst kein MCP-Server. [MCP](https://code.claude.com/docs/en/mcp#option-3-add-a-local-stdio-server)
- `ANTHROPIC_API_KEY` in der Umgebung kann die Authentifizierung über ein Abonnement übersteuern und API-Abrechnung auslösen. Ein Projektprofil mit diesem Variablennamen sollte deshalb nicht beiläufig zum Start der gesamten Claude-Code-Sitzung verwendet werden. [Authentifizierungspriorität](https://support.claude.com/en/articles/12304248-manage-api-key-environment-variables-in-claude-code)

### OpenCode

- `AGENTS.md` liefert Projektanweisungen; zusätzlich werden globale Regeln unterstützt. Die V1-Dokumentation nennt `CLAUDE.md` als Fallback. [Regeln](https://docs.opencode.ai/docs/rules/)
- Skills können unter anderem in `.opencode/skills/`, `.claude/skills/` und `.agents/skills/` liegen. `name` und `description` gehören in den YAML-Kopf; der vollständige Inhalt wird bei Bedarf geladen. [Skills](https://docs.opencode.ai/docs/skills/)
- Das eingebaute Shell-Werkzeug führt Terminalbefehle aus. Seine Nutzung hängt von den gesetzten Berechtigungen ab. [Werkzeuge](https://docs.opencode.ai/docs/tools/)
- Lokale und entfernte MCP-Server werden unterstützt. Die offizielle V2-Dokumentation bezeichnet lokale Server ausdrücklich als über stdio gestartete Prozesse. [V2 MCP](https://dev.opencode.ai/v2/docs/mcp-servers/)
- Die offiziellen V1-/V2-Dokumentationen unterscheiden sich beim MCP-Schema: V1 zeigt Server direkt unter `mcp`, V2 unter `mcp.servers`; V2 verwendet `disabled` statt `enabled`. Ein späterer Konfigurationsexport muss die tatsächlich installierte Version berücksichtigen. [V1 MCP](https://docs.opencode.ai/docs/mcp-servers/), [V2 MCP](https://dev.opencode.ai/v2/docs/mcp-servers/)

## Ableitung für Secretariat

1. **Projektbefehl kapseln:** Der Agent startet beispielsweise Entwicklungsserver oder Tests durch Secretariat. Der gesamte Coding-Prozess benötigt dadurch die Projekt-Credentials nicht dauerhaft in seiner eigenen Umgebung. Das ist eine Eingrenzung der Verteilung, keine Geheimnis-Isolation.
2. **Agenten erklären, wann es nötig ist:** Kurze Projektanweisung oder optional ein gemeinsamer Skill. Kein Lesen des Schlüsselbunds per Shell, keine Schlüsselwerte in `.env`, Konfiguration, Chat oder exportierte Anweisungen schreiben.
3. **MCP nur bei zusätzlichem Nutzen:** Ein späterer lokaler Adapter könnte sichere Metadaten wie Profilnamen und Bereitschaft melden. Soll er Programme ausführen, braucht er einen eigenen Vertrag für Laufzeit, Ausgabe, Abbruch und Berechtigungen. Das wäre neue Implementierung, kein vorhandenes Feature. Als ersten Schritt reichen CLI und Projektanweisung.

Als überschaubare Version 0.2 bieten sich maschinenlesbare Profilauskunft, Prüfung ohne Ausgabe von Schlüsselwerten und erzeugte Projektanweisungen für `AGENTS.md`/`CLAUDE.md` an. Diese Funktionen sind Vorschläge und noch nicht implementiert. Eine `get`-/`export`-API für rohe Schlüsselwerte ist für diese Integration nicht erforderlich. Globale Agenten-Konfigurationen bleiben bis zu einem konkreten Einrichtungsauftrag unberührt.

## Technische Grenze

Im bestehenden `Sources/SecretariatCore/Launcher.swift` werden ausgewählte Werte in die Umgebung des Zielprozesses eingesetzt und anschließend `execve` verwendet. Der Zielprozess und seine Nachfahren können Werte lesen und ausgeben. Mit frei wählbarem Programm kann auch ein Agent eine Ausgabe der Umgebung veranlassen. Ein MCP-Wrapper, Skill oder Satz in `AGENTS.md` beseitigt diese Grenze nicht. Für die Zusage „Agent darf den Schlüssel niemals sehen“ wären stärker begrenzte Operationen und eine echte Ausführungsgrenze erforderlich.

Der bisherige reale lokale Test belegt einen Projektstart über die signierte Secretariat-App. Er belegt noch nicht die Ausführung aus Claude Code oder OpenCode unter deren jeweiliger Sandbox, Berechtigungs- und Schlüsselbundkonfiguration.
