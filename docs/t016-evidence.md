# T016 – secretariat import (Build f363f6e)

- Ausgangslage: 0.3.0, Werte nur über die App.
- build: `swift build` und `script/build.sh` grün, Paket signiert.
- unit: `dotenvParsingHandlesExportQuotesAndComments` (export, Kommentare, Anführungszeichen, letzte Zuweisung gewinnt) und `importStoresValuesBindsProfileAndOutputsNamesOnly` (Werte im Store, JSON ohne Werte, Profilbindung, key_exists ohne --replace, updated mit --replace, variable_missing, file_unreadable, profile_not_found) grün; gesamt 30/30.
- macos (echter Lauf, M4, installierte 0.4.0): `secretariat import adventurist/.env "CF_Access_Client_Id=Adventurist CF Access Client ID" "CF_Access_Client_Secret=Adventurist CF Access Client Secret"` → zwei Schlüssel „neu“, Ausgabe nur Namen. Profil menulens-worker per CLI angelegt, beide Variablen gebunden, `check --json` ok, beide available.
- Installation: 0.4.0 auf M4, Mini, M1, M5, Signatur geprüft.
- Grenze: Das Weiterreichen an den Cloudflare-Worker per `run` wurde von der Agent-Sicherheitsprüfung gestoppt; Uli führt den Befehl selbst aus.
