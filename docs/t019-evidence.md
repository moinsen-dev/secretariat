# T019 – Effizienzpaket (Build 533ffaa)

- unit: 32/32 (neu: anywhereProfilesRunInTheCallersFolder, profileWhichFindsTheClosestProjectProfile).
- macos (echt): 1.1.0 auf M4, Mini, M1, M5 (je 17 Einträge per iCloud). Profil werkzeuge (Ordner *): Lauf aus dem Scratch-Ordner sah den aktuellen Ordner, ASC_KEY_ID T5YN77H557 und die .p8 als Datei.
- Sitzungshinweis (Hook, echt aufgerufen): für menulens-worker/src Profil erkannt; für Bucketlist .env-Geheimnisse nur mit Namen; /tmp still.
- End-to-End (echt, Testnamensraum): frische `claude -p "Führe die Tests dieses Projekts aus"` ohne Hinweis: profiles → check → run, grün in 37,8 s; mit Hinweis grün in 39,1 s; Wert nie in der Ausgabe, keine .env. Testdatei vergleicht nur eine Prüfsumme.
- Massenübernahme: Prüfliste aus ~/work, 296 Werte → Einträge, 20 Kennungen, 144 Profile; Konfiguration, öffentliche Client-Schlüssel, Platzhalter und lokale Standardwerte bleiben in den .env-Dateien. Ausführung wartet auf die Freigabe des Nutzers.
- Grenzen: Eintragen von Hook und Freigabe in settings.json ist dem Agenten verwehrt (Nutzer führt das Installationskommando aus). Zwei abgebrochene Testläufe ließen Testeinträge zurück, mit cleanup_test_items entfernt.
