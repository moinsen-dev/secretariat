# Planprüfung P25 (Team): unabhängige Kritik, 2026-11-12

Prüfer: eigener Kritiker-Agent, nur lesend, gegen PLAN (R035–R037, UC25–UC27, T031–T033), Business Case, Recherche, Bedrohungsmodell, Backup- und Speicher-Code.

## Runde 1: REWORK
Muss: (1) Teamliste in `profiles.json` fälschbar → in den synchronisierten Schlüsselbund; (2) Mitempfänger kann Inhalt austauschen → Umschlag authentisiert Kopf ‖ SHA-256(Chiffrat), Kopf als AAD, eigener Info-String, nur Version 1; (3) MDM-Werte per `defaults write` überschreibbar, falsche Domäne → nur erzwungene CFPreferences, Domäne = Bundle-ID, Fixture nur in Test-Tresoren; (4) Lizenz per MDM passt nicht zu personengebundener Lizenz → gestrichen.
Sollte: Touch ID bei jedem Teilen; Namen nur aus eigener Liste; Größengrenzen; Code erneuern; UC ehrlich (manuelle Touch ID, Doppelklick getrennt, Veröffentlichung mit Ulis Ja); Ulis Freigabe im Plan. Alles übernommen.

## Runde 2: PASS (Plan)
Code-Muss-Punkte vor der Abnahme, umgesetzt: Import über `Vault.save` (alle Prüfungen) und Absendername per `validName`; Fingerabdruck 128 Bit. Sollte umgesetzt: Weitergabe erst nach dem Schreiben der Datei protokollieren (`recordShared`), Namen verwalteter Mitglieder prüfen. Offen als Grenze: Verschwindet ein Mitglied aus der MDM-Liste, öffnet sich kein Austritts-Sheet; eigene Vorlagen reisen nicht mit (Empfänger zeigt die Standardvorlage).

URTEIL PLAN: PASS
