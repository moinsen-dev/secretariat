# Unabhängige Planprüfung Secretariat 0.2

Datum: 2026-10-23T08:58:28+02:00. Prüfer: delegierter Kritiker. Umfang: PLAN, STATE, TRACKER, vorhandene Recherche und bisherige Review-Erkenntnisse. Keine Implementierung und keine Credential-/Agentenaktionen.
Geprüfter PLAN-SHA-256: `05e211a3897bdf141394a203be50edefc5edd545db78bdb5b14d37192e91b705`.

Ergebnis: **PASS**. Der fachliche Plan ist machbar, im autorisierten Umfang und sinnvoll geordnet. Die formalen Files-Ergänzungen wurden bei der zweiten Prüfung bestätigt. Vor dem ersten Bau weiterhin `check --ready` ausführen; keine neue Produktentscheidung nötig.

## Behobener formaler Befund

Die neuen Tasks erfassen jetzt auch die folgenden vorhandenen Quellen und Prüfabängigkeiten, die für ihre tatsächliche Paket-/UI-/Regressionsaussage maßgeblich sind:

- T007–T009: `Sources/Secretariat/Editors.swift`, `script/build.sh`, `Assets/AppIcon.icns` sind ergänzt. Die geplante App baut und öffnet weiterhin die bestehenden Editoren; Paket-/Signaturaufbau und Icon gehören zu den neuen lokalen Paketnachweisen.
- T007 und T010: `Tests/SecretariatCoreTests/CoreTests.swift` sind ergänzt, damit Änderungen an den weiter geltenden Basistests ihre Belege sichtbar altern lassen.
- T010: `Tests/SecretariatCoreTests/AgentIntegrationTests.swift` und `script/agent_acceptance.py` sind ergänzt; deren Resultate begründen die neue Gesamt-/Regressionsabnahme.

Geplante, noch nicht existierende Quellen sind zulässig und werden nicht als bereits implementiert betrachtet. Die erwähnten neuen Dateien sind ausreichend konkret benannt. Das alte 0.1 bleibt als Historie erhalten; ein nach Änderung veralteter früherer Fingerprint ist kein Grund, historische Belege umzuschreiben.

## Fachliche Bewertung

- R008–R011 und UC06/UC07 treffen die angenommene Lösung: universelle lokale CLI-Auskunft, Prüfung und projektspezifische Anleitung statt toolabhängiger Integrationen. Keine get/export-API, MCP-/Global-Konfiguration oder neue Isolation zugesagt.
- T007–T010 haben eine ausführbare Reihenfolge: CLI-Vertrag, sichere Einrichtung und normale UI, tatsächlich versuchte Coding-Sitzungen, anschließend Paket-/Basiserhalt und Installation.
- Die Einrichtung schützt bestehende Bytes, andere Profile, Symlinks/Hardlinks, fehlerhafte Marker/UTF-8 und zwischenzeitliche Änderungen. Vorschau/Abbruch/Idempotenz und normaler Zweidatei-Fehlerrollback sind angemessen; eine Crash-Transaktion wird ausdrücklich nicht behauptet.
- Agentenversuche sind ausdrücklich Versuche mit künstlichem Testwert und vorhandener Anmeldung. Auth-/Sandbox-/Toolrechte dürfen einen Toolversuch begrenzen, aber nicht als ausgeführter E2E-Erfolg gelten. Ein Ausführungsreceipt ist ein geeigneter Nachweis.
- Versionierung, App-ID und Speicherung bleiben kompatibel; betroffene bisherige Abläufe werden in T010 erneut geprüft. Zusatzmodule/Katalog werden im Abschnitt 0.2 auf die neuen Aufgaben angewandt.

## Umsetzungskriterien für die spätere Quellenkritik

`check` verspricht strikt keine Systemdialoge und keinen Zielprozess. Nach dem belegten 0.1-Vorfall genügt `LAContext.interactionNotAllowed` allein nicht als Begründung. Der Implementierungspfad muss wirksame UI-Unterdrückung ausdrücklich herstellen und einen nicht interaktiv prüfbaren Eintrag strukturiert melden, ohne zu entsperren oder fallback-interaktiv zu lesen. Das ist Umsetzung des vorhandenen R009, keine zusätzliche Anforderung. Neue Testschlüsselbünde oder Sperrversuche sind dafür nicht Teil der geplanten Prüfungen.

Die Abnahme muss später Quell-/Mock-Nachweis der Dialogunterdrückung, echten normalen Paketlauf, UI-Einrichtung und jede tatsächlich ausgeführte Coding-Sitzung getrennt benennen. Ein schreibgeschützter oder nicht verfügbarer Agentenprozess kann eine Grenze belegen; Textkompatibilität allein belegt keine Befehlsausführung. Es werden keine neuen Accounts, Abrechnungseinstellungen oder globalen Toolkonfigurationen benötigt.

STATE ist noch der abgeschlossene 0.1-Stand; nach der Planregistrierung wie vorgesehen auf T007 aktualisieren. Dies ist ein erwarteter Übergang, kein Produktbefund.

## Planabgleich nach Quellenkritik

Die präzisierte optimistische Snapshotgrenze ist für diesen lokalen Umfang angemessen: Vergleich nach Staging unmittelbar vor Rename, keine atomare CAS-Garantie gegenüber beliebigen fremden Editoren. Die Fixture-Helferabhängigkeit `script/seed_agent_fixture.swift` ist in T009/T010 enthalten. Die Planbewertung bleibt **PASS**. Nicht verfügbare UI-Automation, konkrete Sandboxfehler oder fehlgeschlagene Anbieteranmeldung müssen weiterhin als Grenzen einzelner Nachweise erscheinen; sie ergeben keinen automatisch bestandenen UI-/E2E-Use-Case.

## Aktueller Abgleich R012

Plan weiterhin **PASS**. R012 konkretisiert die ausdrückliche Nutzerkorrektur zu wiederholten OS-Dialogen: CLI-run und check müssen bei fehlender Freigabe geschlossen abbrechen. R012 ist UC06/UC07 sowie T007/T010 zugeordnet. Der prozesslokale serialisierte Get/Set-Scope, exakte Wiederherstellung, unverändert benutzergeführte GUI und korrekter .app-Trustpfad sind fachlich konsistent. Ein Testhelper mit derselben Developer-ID-Identität macht den positiven Pakettest aussagekräftiger für die beabsichtigte Signierpartition; daraus folgt keine zusätzliche Produktisolation. Ausstehende UI-Nachweise bleiben ausstehend; PLAN-PASS ist keine vollständige 0.2-Abnahme.
