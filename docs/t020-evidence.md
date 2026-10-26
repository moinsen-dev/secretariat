# T020 – Geführter Eintrags-Dialog (Build 682215f)

- Anlass: Uli fand Pfad/Art/Herkunft/Läuft ab und freie Feldzeilen verwirrend; sein DeepSeek-Schlüssel landete unter Pfad „moinsen“ mit dem Variablennamen als Kennung, der OpenAI-Schlüssel scheiterte an „Es gibt schon einen Eintrag moinsen“.
- macos (echt, Testheim): Dialog zeigt „Was speicherst du?“ mit 8 Arten und Erklärung, darunter Anbieter (mit Auswahlliste), Zusatz, beschriftete Felder (Schlüssel *, Variablenname), Schalter „In allen Projekten und Werkzeugen nutzbar“, Ablage-Vorschau, „Erweitert“ eingeklappt, „Fehlt noch: …“ und gesperrtes Speichern (Screenshot geprüft).
- Reparatur (echt): moinsen/key_id entfernt, `field move moinsen/secret moinsen/deepseek/api_key`, env_var=DEEPSEEK_API_KEY, Profil werkzeuge bindet DEEPSEEK_API_KEY; `check werkzeuge` bereit. Wert verließ den Prozess nicht.
- build/unit: 32/32. 1.2.0 auf M4, Mini, M1, M5.
