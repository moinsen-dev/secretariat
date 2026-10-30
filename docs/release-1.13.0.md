# Release 1.13.0 (2026-10-30)

Inhalt: `secretariat header` als headersHelper für HTTP-MCP-Server (T025), Verlauf mit Herkunft (T024), automatische verschlüsselte Sicherung mit Wiederherstellungsschlüssel (T026), Website-Abschnitte zu MCP-Tokens, Sicherung und Verlauf (lokal, nicht veröffentlicht). Prüfungen: `docs/t024-evidence.md`, `docs/t025-evidence.md`, `docs/t026-evidence.md`, Kritik `docs/review-uc19.md`, `docs/review-uc20.md`, `docs/review-uc21.md`, Planprüfung `docs/review-plan-uc19.md`, Regression `docs/regression-1.13.md`.

| Schritt | Beobachtung |
|---|---|
| Version | `Info.plist` 1.13.0 (Build 28), `Launcher.version` 1.13.0; Unit 94/94, CLI-Regression 24/24 |
| Release-Build | `secretariat run werkzeuge -- script/release.sh`: Notarisierung `Accepted`, gestapelt, `spctl` accepted („Notarized Developer ID“); `dist/Secretariat-1.13.0.zip` (SHA-256 dd0bbc43b46c35a1…), `appcast.xml` erzeugt |
| Installation lokal (M4) | `script/install.sh`, `--version` 1.13.0, `spctl` und `codesign --verify --deep --strict` ok; echter Tresor: 226 Einträge lesbar, `history` arbeitet, `backup status` „nicht eingerichtet“ (Einrichtung macht Uli, nur er sieht den Schlüssel) |
| MCP-Tokens | tinideas, feedback-cafe, testerpaykit in `~/.claude.json` (user scope) auf `secretariat header … --bearer` umgestellt: alle „Connected“, `grep -c tid_ ~/.claude.json` → 0, Verlauf zeigt `header` mit Herkunft Claude Code |

| GitHub | `git push origin main`: `6d78e82..2d58044` (nach Ulis Go, 2026-10-30) |
| Website | Pages `secretariat`, Deployment 0faf047d (Production, main): `site/` + `Secretariat-1.13.0.zip` + `Secretariat-1.12.0.zip` + `Secretariat-latest.zip` (= 1.13.0) + `appcast.xml` (sparkle:version 28, 1.13.0). Live per URLSession (curl bekommt die Cloudflare-Abfrage, 403): Feed 1.13.0, `Secretariat-latest.zip` und `Secretariat-1.13.0.zip` byte-gleich mit dem notarisierten Zip (dd0bbc43…), Startseite mit „Connect an MCP server“, „Encrypted backup, your key“, „History: who used what“, Bedrohungsmodell mit „Backups and the recovery key“ |
| Verteilung | Der mesh-Job (launchd, alle 15 Min.) hat 1.13.0 schon um 19:42 an M1, M5 und Mini ausgeliefert, wenige Minuten nach der lokalen Installation; `mesh deliver` um 20:27: alle „up to date“, Zustand je Mac „1.13.0 (28)“. Per SSH auf M1: `--version` 1.13.0, `codesign --verify --strict` ok, 226 Einträge |

Offen in T026: Sicherung im echten Tresor einrichten, Wiederherstellen und „Schlüssel prüfen“ in der App, eine in iCloud ausgelagerte Datei öffnen (Handgriffe von Uli; den Schlüssel sieht nur er). Hinweis: Eine lokale Installation auf dem M4 erreicht über mesh binnen 15 Minuten alle Macs.
