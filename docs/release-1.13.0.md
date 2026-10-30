# Release 1.13.0 (2026-10-30)

Inhalt: `secretariat header` als headersHelper für HTTP-MCP-Server (T025), Verlauf mit Herkunft (T024), automatische verschlüsselte Sicherung mit Wiederherstellungsschlüssel (T026), Website-Abschnitte zu MCP-Tokens, Sicherung und Verlauf (lokal, nicht veröffentlicht). Prüfungen: `docs/t024-evidence.md`, `docs/t025-evidence.md`, `docs/t026-evidence.md`, Kritik `docs/review-uc19.md`, `docs/review-uc20.md`, `docs/review-uc21.md`, Planprüfung `docs/review-plan-uc19.md`, Regression `docs/regression-1.13.md`.

| Schritt | Beobachtung |
|---|---|
| Version | `Info.plist` 1.13.0 (Build 28), `Launcher.version` 1.13.0; Unit 94/94, CLI-Regression 24/24 |
| Release-Build | `secretariat run werkzeuge -- script/release.sh`: Notarisierung `Accepted`, gestapelt, `spctl` accepted („Notarized Developer ID“); `dist/Secretariat-1.13.0.zip` (SHA-256 dd0bbc43b46c35a1…), `appcast.xml` erzeugt |
| Installation lokal (M4) | `script/install.sh`, `--version` 1.13.0, `spctl` und `codesign --verify --deep --strict` ok; echter Tresor: 226 Einträge lesbar, `history` arbeitet, `backup status` „nicht eingerichtet“ (Einrichtung macht Uli, nur er sieht den Schlüssel) |
| MCP-Tokens | tinideas, feedback-cafe, testerpaykit in `~/.claude.json` (user scope) auf `secretariat header … --bearer` umgestellt: alle „Connected“, `grep -c tid_ ~/.claude.json` → 0, Verlauf zeigt `header` mit Herkunft Claude Code |

Noch nicht: Push nach GitHub, Website-Deploy (Pages `secretariat`) samt Zip und Feed, `mesh deliver` auf M1/Mini/M5 – warten auf Ulis Go. Offen in T026: Wiederherstellen und „Schlüssel prüfen“ in der App sowie die iCloud-Ablage mit dem echten Tresor (Handgriffe von Uli).
