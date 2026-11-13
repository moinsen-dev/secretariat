# Inventur der Website-Logins (T035, UC29) – Prüfbericht 2026-11-13

Anlass: Nach dem Import aus drei Chrome-Profilen (1270 Website-Logins) will Uli alte Konten finden und schließen und unnötige Passwörter loswerden.

## Verhalten

- Library → „Inventory“ (auch View → Inventory, ⌥⌘I). Listen: To Review (offen und mit Befund), All Logins, Local address, Reused password, Weak password, In known leaks, Domain gone, Kept, To Close, To Change. Filter „Found in“ je Browser-Profil.
- Passwörter werden beim Öffnen einmal gelesen und sofort auf Prüfsumme (SHA-256 für Mehrfachnutzung, SHA-1 für den Leck-Abgleich) und Stärke reduziert. Nichts davon wird gespeichert oder ausgegeben.
- „Check Online“ nur auf Knopfdruck: DNS je registrierbarer Domain (NXDOMAIN = „Domain gone“) und Have I Been Pwned „Pwned Passwords“ per k-Anonymität (nur die ersten 5 Zeichen des SHA-1 verlassen den Mac, Antwort mit Padding). Ergebnis nur auf diesem Mac in `login-audit.json` (0600, Zähler je Eintrag und Passwortstand, keine Prüfsummen).
- Detail: Befunde in Klartext, Found in, Entscheidung Open/Keep/Close account/Change password (Kennungsfeld `review`, kein Wert wird neu geschrieben), Knöpfe „Change Password …“ (`/.well-known/change-password`), „How to Close …“ (Websuche „<domain> delete account“), „Delete Entry …“.
- CLI `secretariat audit-logins [--from PROFIL] [--finding …]`: Zahlen und Pfade, nie Werte.

## Prüfungen

| Ziel | Ergebnis |
|---|---|
| unit | `xcrun swift test`: 132/132 grün; neu 6: lokale Adressen, schwache Passwörter, Befunde aus Fakten und Online-Stand (Leck für altes Passwort zählt nicht), HIBP-Antwort parsen, Entscheidung ändert nur `review`, Cache 0600 ohne Werte, `audit-logins` ohne Werte und mit Profilfilter |
| cli | Test-Tresor, 7 künstliche Zeilen aus zwei Profilen: `audit-logins` 6 Logins, 1 lokal, 2 mehrfach, 1 schwach, Online noch nicht geprüft. `script/regression_cli.sh` 24/24 |
| macos | Testinstanz: View → Inventory zeigt To Review (3) mit Symbolen. „Check Online“ (echte Abfragen mit künstlichen Passwörtern): `nonexistent-secretariat-check-84721.com` gone, übrige Domains ok; Router (`admin`) und `password123` in known leaks; To Review 5; Cache 0600. Eintrag gewählt: „… no longer exists; the account is likely gone“, Found in „Chrome: Work“, Entscheidung „Close account“ per Bedienungshilfen gedrückt → To Review 4, `audit-logins`: close 1. Nach Layout-Feinschliff neu gebaut und Ansicht erneut aufgenommen |

Aufräumen: Testinstanz beendet, Test-Schlüsselbund geleert (0 Einträge), Testdateien gelöscht. Echter Tresor unberührt.

## Grenzen

- Mit Ulis echtem Tresor (1270 Logins) noch nicht geöffnet; Dauer des Lesens und der Online-Prüfung dort ungemessen.
- Das geänderte Cache-Format (Schlüssel als Text) ist per Unit-Test belegt; die Online-Prüfung in der App lief vor dieser Änderung.
- „Last used“ kennt die CSV nicht; „alt“ ergibt sich nur aus Befunden und Ulis Entscheidung.
- Bedienung der Testinstanz über System Events und Bedienungshilfen; Mausklicks gingen teils verloren, weil das Fenster den Fokus verlor.
