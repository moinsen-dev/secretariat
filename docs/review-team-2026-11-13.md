# Unabhängige Abnahme Team (UC25–UC27)

Prüfer: eigener Kritiker-Agent, nur lesend, gegen PLAN, Code (342e7c8), Bericht `docs/team-2026-11-12.md`, Website.

## Runde 1 (342e7c8)
Hält: HPKE-Auth je Empfänger mit Kopf und Chiffrat-Hash, Inhaltstausch-Test, nur Version 1, Größengrenzen, Import über `Vault.save`,
Absendername validiert, Fingerabdruck 128 Bit, Teamdaten im Schlüsselbund, CLI nur lesend, Touch ID bei jedem Teilen, Protokoll erst
nach dem Schreiben, nur erzwungene CFPreferences, Fixture nur in Test-Tresoren.
Muss: (1) Dateiname enthielt den Eintragspfad, Widerspruch zum Bedrohungsmodell; (2) Test „defaults write ignoriert“ war leer;
(3) Tracker ohne Nachweise. Sollte: unbekannter Absender und „changed since“ nicht im App-Lauf; Website-Sätze zu Rotation und MDM zu stark.
Urteil: UC25 REWORK, UC26 REWORK, UC27 BLOCKED.

Umgesetzt in 2643bfc samt zweitem App-Lauf (siehe Bericht, Abschnitt „Nachbesserung“).

## Runde 2 (2643bfc)
Alle drei Muss-Punkte behoben und belegt (Dateiname ohne Pfad im App-Lauf, echter Test mit Wegwerf-Domäne, Nachweise E1351–E1359,
T033 als Fixture). Sollte umgesetzt: Satz zum Dateinamen im Bedrohungsmodell, „not yet with a real MDM“ in der Admin-Anleitung.

URTEIL UC25: PASS
URTEIL UC26: PASS
URTEIL UC27: BLOCKED (Schritt 1 per Fixture belegt; `.pkg` wartet auf das „Developer ID Installer“-Zertifikat; Admin-Anleitung online erst nach Ulis Ja)
