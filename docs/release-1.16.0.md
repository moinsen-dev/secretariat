# Release 1.16.0 (2026-11-13)

Inhalt: Secretariat im Team (T031, T032; T033 teilweise): Teilen-Code je Person, verschlüsselte Team-Pakete, Öffnen mit
Absenderprüfung, Austritt mit Rotations-Markierung, verwaltete Teammitglieder (MDM), Website-Abschnitt „In a team“, Admin-Anleitung,
Bedrohungsmodell. Prüfungen: `docs/team-2026-11-12.md`, Abnahme `docs/review-team-2026-11-13.md`, Planprüfung
`docs/review-team-plan-2026-11-12.md`, Neubindung `docs/rebind-team-2026-11-13.md`.

| Schritt | Beobachtung |
|---|---|
| Version | `Info.plist` 1.16.0 (Build 32), `Launcher.version` 1.16.0; Unit 117/117, CLI-Regression 24/24 |
| Release-Build | `secretariat run werkzeuge -- script/release.sh`: Notarisierung `Accepted`, `stapler validate` ok, `spctl` accepted („Notarized Developer ID“), `codesign --verify --deep --strict` ok, `sdk 27.2`; `dist/Secretariat-1.16.0.zip` (SHA-256 2511b17eb52fdbed…), `appcast.xml` sparkle:version 32 |
| Installation lokal (M4) | Ulis Go: `script/install.sh`, `--version` 1.16.0, `codesign` ok, `status`: 276 Einträge, 177 Profile, „to rotate: none“; `team list`: keine Mitglieder |
| Verteilung | `mesh deliver`: m1 und mini „delivered secretariat“; Mini per SSH `--version` 1.16.0; M5 offline, folgt beim nächsten Lauf |
| Website | `dist/site-1.16.0` gebaut (alle Zips bis 1.16.0, `Secretariat-latest.zip` = 1.16.0, `teams.html`); Veröffentlichung durch Uli ausstehend |
| GitHub | Ulis Go: Push nach `main` |
| MDM-Paket | blockiert: kein „Developer ID Installer“-Zertifikat |
