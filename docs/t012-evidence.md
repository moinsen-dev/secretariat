# T012 – Agent verdrahtet Projekt selbst (0.3)

Zeit: 2026-10-26, M4. Build: Commit ce7cb30, dist/Secretariat.app 0.3.0 (sha256 414f6baa…). Client: Claude Code (`claude -p`,
nur Read und Bash auf das Secretariat-Binary, keine MCP-Server, gespeicherte Anmeldung).

## Ablauf

`python3 script/agent_acceptance.py --binary dist/Secretariat.app/Contents/MacOS/Secretariat --clients claude --self-wire`

Wegwerf-Home mit genau einem künstlichen, per Fixture-Helfer (gleiches Team) angelegten Schlüssel „Prüfung Agenten“,
**ohne Profil**. Vorbedingung geprüft: `check agent-pruefung` → `profile_not_found`. Auftrag an Claude: Variable
`SECRETARIAT_ACCEPTANCE` selbst per CLI verdrahten (keys, profile create, bind, check) und `verify.py` über Secretariat starten.

## Beobachtung

- status passed, Exit 0, 24,7 s.
- Quittung vom gestarteten Test: `credential_verified: true`, `cwd_verified: true` (nur der Zielprozess kann sie schreiben).
- `self_wired_profile: true`: Profil `agent-pruefung` mit Ordner = Projekt und Bindung an die Fixture-ID in profiles.json.
- `env_files_created: []`, `artificial_value_in_output: false`, `fixture_credential_removed: true`.
- Projektanweisungen und README nennen `keys` und `profile bind` (Schritt 4 der generierten Anleitung).

## Grenzen

Nur Claude Code geprüft (Codex/OpenCode für 0.3 nicht erneut). Künstlicher Wert, Wegwerf-Namensraum.
