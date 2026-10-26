# T018 – Secretariat 1.0 (Build 80e78e5)

- build/unit: siehe docs/regression-1.0.md (30/30).
- Migration (echt, M4): migrate-v1 übernahm moinsen/cloudflare/access-routing-client-id → …/access-routing/client_id (Kennung) und -client-secret → …/client_secret (Geheimnis); profiles.json → Version 2 mit Sicherung; menulens-worker danach bereit. Mini und M1: Profile-Datei umgestellt, Einträge per iCloud vorhanden. `--delete-old` entfernte die 2 alten 0.x-Einträge.
- Register: 15 Einträge aus dem kuratierten Register per CLI angelegt (Apple, App Store Connect, Cloudflare, Expo, GitHub, Flotte, Dienste, Secretariat); beide .p8 per import-file als Dateifelder. accounts.toml wird von Secretariat erzeugt; `registry.py get moinsen/apple-developer/team_id` = VXX45ZYNM8.
- run mit Datei (echt): Profil mit ASC_KEY_PATH → api-key/private_key und ASC_KEY_ID: Programm sah id=T5YN77H557, Datei AuthKey_T5YN77H557.p8, Rechte 600, SHA-256-Präfix gleich dem Original (86b9e1b9f9af); Temp-Datei danach entfernt. Protokoll nennt nur Variablennamen.
- Ziele: menulens-api (wrangler secret put, absoluter Ordner) mit zwei Zuordnungen, Status „never“, `push --dry-run` nennt nur Namen. Echtes push nicht ausgeführt (Produktivschreiben bleibt beim Nutzer).
- Agenten (echt, Testnamensraum): Claude verdrahtet selbst (items → profile create/bind → check → run) in 22,9 s, Wert nie in der Ausgabe, keine .env; Claude über Projektanweisungen 14,0 s bestanden. Codex: Sandbox ohne Schlüsselbundzugriff (-25291), korrekt als nicht verfügbar gemeldet.
- Echtes Löschen per CLI verweigert (app_only); nur Testheime dürfen Einträge per CLI entfernen.
