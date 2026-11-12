# Release 1.15.0 (2026-11-12)

Inhalt: Redesign nach macOS 26/27 Liquid Glass (T030): Seitenleiste wie Erinnerungen, Liste wie Notizen, Detail und „Neuer Eintrag“
wie Passwörter, Menü „Item“ (⌘E), echte SDK-Version im Binary. Funktionen unverändert; `Sources/SecretariatCore` seit 1.14.0 nur in
der Versionsnummer geändert. Prüfungen: `docs/redesign-2026-11-12.md`, Kritik `docs/review-redesign-2026-11-12.md`,
Neubindung `docs/rebind-redesign-2026-11-12.md`.

| Schritt | Beobachtung |
|---|---|
| Version | `Info.plist` 1.15.0 (Build 31), `Launcher.version` 1.15.0; Unit 108/108, CLI-Regression 24/24 gegen `dist/Secretariat.app` |
| Release-Build | `secretariat run werkzeuge -- script/release.sh`: Notarisierung `Accepted`, `stapler validate` ok, `spctl` accepted („Notarized Developer ID“), `codesign --verify --deep --strict` ok, `otool` `sdk 27.2`; `dist/Secretariat-1.15.0.zip` (SHA-256 5a8c0b3a3907c336…), `appcast.xml` sparkle:version 31 |
| Website | `dist/site-1.15.0`: neues Hauptbild aus dem Release-Build (Testinstanz mit Design-Tresor, hell), Bildunterschrift angepasst; alle Zips bis 1.15.0, `Secretariat-latest.zip` byte-gleich mit dem notarisierten Zip. Lokal geprüft: Bild lädt mit 1587×863 |
| Installation lokal (M4) | ausstehend (verteilt über mesh an M1/M5/Mini, Ulis Go) |
| Website live | Uli: `wrangler pages deploy dist/site-1.15.0 --project-name secretariat --branch main` (Deployment 5925fed9). Live geprüft: Feed 1.15.0; `Secretariat-latest.zip` und `Secretariat-1.15.0.zip` byte-gleich mit dem notarisierten Zip (5a8c0b3a3907c336…); 1.14.0 weiter da (01f25d8f…); neues Hauptbild 1587×863 und neue Bildunterschrift online |
| GitHub | ausstehend (Repo öffentlich, Ulis Go) |

Grenze: Das Website-Bild „Item from screenshot“ zeigt noch den alten Dialog.
