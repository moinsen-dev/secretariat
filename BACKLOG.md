# Backlog

Ideen und Prüfaufträge für später. Noch nicht geplant; wenn einer drankommt, wird er in `PLAN.md`/`TRACKER.md` eine Aufgabe.

## Zusammenspiel mit Apples `security`-Werkzeug genauer prüfen

Eingetragen 2026-11-01 von Uli.

`/usr/bin/security` ist Apples eigenes Kommandozeilen-Werkzeug für den Schlüsselbund (gehört zu macOS, Handbuch `man security`). Es arbeitet auf denselben Grundlagen wie Secretariat, ist aber kein Konkurrent: keine Profile, keine Maskierung, kein Guard, und `-w` gibt Werte im Klartext aus. Secretariats eigene Werte (iCloud-Schlüsselbund, Zugriffsgruppe) sieht es nicht.

Zu prüfen:

- **Import:** Können Secretariat-Nutzer vorhandene Einträge aus dem Login-Schlüsselbund übernehmen (Internet- und App-Passwörter, Tokens anderer CLIs), ohne dass ein Wert sichtbar wird? Welche Einträge fragen nach, welche gibt macOS ohne Rückfrage heraus?
- **Export:** Braucht es einen Weg zurück in den Login-Schlüsselbund, etwa für Werkzeuge, die nur dort lesen (`git credential-osxkeychain`, Xcode, `notarytool --keychain-profile`)?
- **Zusammenspiel:** Welche Werkzeuge in Ulis Alltag holen Geheimnisse per `security find-*-password` (Build-Skripte, Signierung, CLIs)? Lassen die sich auf `secretariat run` umstellen, oder bleibt `security` dort richtig?
- **Altlasten:** Im Login-Schlüsselbund liegen zwei Einträge `dev.moinsen.secretariat.daemon` vom alten Daemon (vor dem 22.10.2026). Was steht darin, und dürfen sie weg?
- **Guard:** Die Lücken für `security`-Befehle (`-gw`, `security -q …`, `-i`, `dump-keychain -d`, `export`, Partitionslisten) sind seit 2026-11-01 im Code geschlossen, aber noch nicht ausgeliefert. Auf diesem Mac ist der Claude-Code-Hook gar nicht eingetragen (`secretariat guard claude install`).

## Secretariat für iPhone

Eingetragen 2026-11-11 von Uli („erst mal ins Backlog“).

Tresor unterwegs: Einträge suchen und ansehen (Face ID), Website-Logins per iOS-AutoFill (Credential-Provider-Erweiterung), Kennungen kopieren. Technisch ohne eigenen Server möglich: Die Einträge liegen synchronisiert im iCloud-Schlüsselbund mit der Zugriffsgruppe `VXX45ZYNM8.dev.moinsen.secretariat.local`, eine iPhone-App desselben Teams darf diese Gruppe lesen. Offen: App-Store-Prüfung für Passwortmanager, Preismodell (Teil der Mac-Lizenz oder eigener Preis), Pflegeaufwand, Schutz von „Only for me“ und Touch-ID-Kennzeichen auf iOS. Ausarbeitung: Ideenkompass, „Idee - Secretariat für iPhone“.
