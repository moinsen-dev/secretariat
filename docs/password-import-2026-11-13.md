# Passwort-Import aus Browser-Exporten (T034, UC28) – Prüfbericht 2026-11-13

Anlass: Uli hat seine Passwörter aus dem Google Passwortmanager als CSV exportiert (`name,url,username,password,note`) und will sie in Secretariat übernehmen, um alte Konten danach aufzuräumen. Eine Chrome-Erweiterung scheidet aus: Chrome gibt Erweiterungen keinen Zugriff auf gespeicherte Passwörter. Der offizielle CSV-Export ist der Weg ([Google-Hilfe](https://support.google.com/chrome/answer/13068232)).

## Verhalten

- Jede Zeile mit Passwort wird zu einem Eintrag „Website login“: `web/<host>` (Android-Apps `app/<paket>`), zweiter Login derselben Seite `web/<host>/<user>`. Adresse und Benutzer sind Kennungen, Passwort und Notiz „Only for me“.
- Kopfzeilen von Google, Apple Passwörter, Firefox, Bitwarden und 1Password werden erkannt; eine Datei ohne `url`- und `password`-Spalte wird abgelehnt.
- Vorhandener Login mit gleicher Adresse, gleichem Benutzer und gleichem Passwort: übersprungen. Mit anderem Passwort: genannt, nicht überschrieben. Doppelte Zeilen und Zeilen ohne Passwort werden gezählt.
- Die CSV bleibt unangetastet; die App bietet nach dem Import „Move CSV to Trash“ an. Die CLI gibt nur Pfade und Zahlen aus.
- Ein Verlaufseintrag `import.logins` mit Dateiname und Anzahl, ohne Werte.

## Prüfungen

| Ziel | Ergebnis |
|---|---|
| unit | `xcrun swift test`: 123/123 grün, davon 6 neu (CSV mit Anführungszeichen, Komma, Zeilenumbruch, BOM; Kopfzeilen Google/Apple/Bitwarden; Plan; Import ohne Werte in der Ausgabe, kein Überschreiben, CSV bleibt; Fill Login findet importierten Eintrag; zweiter Login derselben Seite) |
| cli | Signiertes `dist/Secretariat.app`, Test-Tresor (`SECRETARIAT_HOME`, Schlüsselbund-Dienst `…items.test.<hash>`), 603 künstliche Zeilen: `--dry-run` 602 neu, nichts gespeichert; Import 602 Einträge in 3,0 s; zweiter Lauf „Already there: 602“ in 0,2 s; Ausgabe enthält keinen Wert; `item show web/q.test` zeigt url, username, password und notes „Only for me“. `script/regression_cli.sh`: 24/24 grün |
| macos | Testinstanz (`open -g -n --env SECRETARIAT_HOME=…`) mit einem vorhandenen Login `web/site5.test` mit anderem Passwort. File → „Import Passwords (CSV) …“, Datei „Google Passwords.csv“: Vorschau 603 Zeilen, 601 neu, 1 abweichend (`web/site5.test` unter „Left alone“), 1 ohne Passwort. „Import 601 Logins“: Liste zeigt 602 Einträge, Meldung „601 logins imported.“; Nachkontrolle per CLI: 601 vorhanden, 1 abweichend. „Move CSV to Trash“: Datei weg, Sheet meldet den Papierkorb |

Aufräumen: Testinstanz beendet, Testeinträge im Schlüsselbund mit `CleanupTestItems` entfernt (Test-Tresor danach 0 Einträge), künstliche CSV-Dateien gelöscht bzw. im Papierkorb. Echter Tresor unberührt.

## Mehrere Chrome-Profile (Nachtrag, gleicher Tag)

Uli: Mehrere Chrome-Profile; das System muss wissen, aus welchem Profil ein Login stammt.

Befund an Ulis echter Datei (nur Metadaten und Spaltenkopf gelesen, keine Werte): Chrome nennt jeden Export „Google Passwords.csv“; die Datei trägt nur die Quarantäne-Angabe „Chrome“, kein `kMDItemWhereFroms`, keinen Profilnamen; 1132 Zeilen. Chromes Profilliste (`Local State`) liegt in einem von macOS geschützten Ordner; sie zu lesen würde eine Systemabfrage „Zugriff auf Daten anderer Apps“ auslösen, darum nicht genutzt.

Lösung: Beim Import nennt der Nutzer das Profil („Found in“, Pflicht in der App, `--from` in der CLI). Vorschläge: früher verwendete Profilnamen und die Google-Konten, deren Anmeldung in der Datei steht. Jeder neue Login trägt das Feld `found_in` (Kennung, im Login-Template „Found in“). Ein gleicher Login mit gleichem Passwort aus einem weiteren Profil bekommt das Profil ergänzt („Chrome: Work, Chrome: Privat“), ohne dass ein Wert neu geschrieben wird; ein abweichendes Passwort bleibt unverändert und wird genannt.

| Ziel | Ergebnis |
|---|---|
| unit | 125/125 grün; neu: zweites Profil ergänzt die Herkunft ohne Wertänderung, abweichender Login unverändert, dritter Lauf ändert nichts, Verlauf nennt das Profil; Vorschläge aus früheren Importen und Google-Anmeldungen |
| cli | Test-Tresor: `--from "Chrome: Work"` 3 Logins; Probelauf ohne `--from` zeigt den Hinweis mit Vorschlägen „Chrome: Work“, „Chrome: private@example.test“. `script/regression_cli.sh` 24/24 |
| macos | Testinstanz, zweite Datei (4 Zeilen): Sheet mit Feld „Found in“ und Menü „Suggestions“, Import-Knopf ohne Profil ausgegraut; „Chrome: Privat“ eingegeben, Import: „2 logins imported“, „Chrome: Privat“ bei 1 vorhandenem Login ergänzt. CLI-Nachkontrolle: `web/shared.test` Found in „Chrome: Work, Chrome: Privat“, `web/work.test` nur „Chrome: Work“ (abweichendes Passwort unverändert), `web/shop.test` „Chrome: Privat“, zweites Google-Konto als `web/accounts.google.com/private@example.test` |

Aufräumen: Testinstanz beendet, Test-Tresore geleert (je 0 Einträge im Test-Schlüsselbund), Testdateien gelöscht.

## Grenzen

- Mit Ulis echter Google-CSV noch nicht importiert (nur Kopfzeile und Metadaten geprüft).
- Das Profil erkennt Secretariat nicht selbst; es schlägt nur vor. Ein falsch gewähltes Profil lässt sich im Eintrag (Feld „Found in“) korrigieren.
- Die Bedienung der Testinstanz lief über System Events (Menü, Tastatur, ein Klick auf den Papierkorb-Knopf); der Knopf „Move CSV to Trash“ war über die Bedienungshilfen nicht per Name auffindbar.
- Passkeys stehen nicht in der CSV und werden nicht übernommen.
