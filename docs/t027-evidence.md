# T027 – „Needs a Value“ (Nachweis)

Anlass: Uli fragte nach verlorenen Schlüsseln. Prüfung des echten Tresors am 2026-10-30: 226 Einträge, 412 Zuordnungen in 150 Profilen alle verfügbar, alle Werte lesbar, keine Löschung seit 29.10. Dabei 24 Einträge aus dem Massenimport vom 26.10., deren Wert ein `.env`-Kommentar (22) oder ein Platzhalter (2) ist. Wunsch: anzeigen, nichts löschen.

| Schritt | Erwartung | Beobachtung |
|---|---|---|
| Test-Tresor: `ELEVEN_KEY="# get it at elevenlabs.io"` per `import` als `acme/elevenlabs/api_key`; `secretariat lint` | 1 Fund | „1 stored value(s) are not real values: acme/elevenlabs/api_key – is a comment from the .env file, not a value“ |
| App (signiertes `dist/`-Paket, Test-Tresor) | Liste mit Anzahl, nur betroffene Einträge, Hinweis am Feld | Bibliothek „Needs a Value · 1“; Liste zeigt nur `acme/elevenlabs`, nicht `acme/demo/api`; am Feld „Key“: „The stored value is a comment from the .env file, not a value. Enter the real key with Edit, or remove the field.“ |
| Unit-Tests | grün | 94/94 (Prüfung `Placeholder.scan` unverändert und schon durch Tests der CLI abgedeckt) |
