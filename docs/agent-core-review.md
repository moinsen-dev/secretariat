# Unabhängige Quellkritik Agenten-Integration 0.2

Stand: 2026-10-23T08:59:03+02:00. Prüfer: delegierter Kritiker. Geprüft: AgentIntegration, ProjectInstructions, AgentSetupView, Änderungen an Launcher/Keychain/AppModel/Views sowie AgentIntegrationTests.
SHA-256 über die geordneten Pfad-/Quellbytes dieser acht Dateien: `37f51632ebe9fd5a083db288340502247a0d7d19d48d5e547ddb801211fa1a88`.

**Ergebnis: PASS für den geprüften Quellstand im dokumentierten lokalen Umfang.** Zwei während der Kritik gefundene Konkurrenzprobleme wurden korrigiert. Keine Implementierungsquellen durch den Kritiker geändert. Normale UI-/Paket-/Coding-Sitzungen und Buildtests bleiben separate Nachweise des durchführenden Agenten.

## Behobene Befunde und unabhängige Prüfung

1. **Änderung während des Stagings konnte überschrieben werden.** Zunächst wurde der Zielsnapshot vor Schreiben/fsync der Tempdatei geprüft; der spätere Rename ersetzte danach einen in dieser Zeit eingetroffenen Editorstand. Unabhängige Reproduktion mit ausschließlich temporärer ca. 900KiB-AGENTS.md und einem Python-Editor: nach Auftauchen der Tempdatei externes Edit, anschließend `apply-success true`, `external-write-happened true`, `external-edit-preserved false`. Keine Credentials verwendet.

   Nach Korrektur prüft `replace` den Snapshot nach Schreiben/fsync unmittelbar vor Rename erneut. Derselbe reproduzierte Ablauf ergibt jetzt `apply-error ... seit der Vorschau geändert`, `external-write-happened true`, `external-edit-preserved true`. Hilfsquelle `/tmp/secretariat-setup-race.swift`; der temporäre Datenordner wird durch die Reproduktion entfernt. Dies belegt genau diesen normalen Konkurrenzfall, keine allgemeine atomare Compare-and-swap-Garantie.

2. **Rollback durfte Fremdedit nicht als eigenen Stand aufnehmen.** Früher wurde `committed` nach Rename durch erneutes Lesen des öffentlichen Pfads gefüllt; ein dort inzwischen eingetroffenes Fremdedit hätte beim Fehler der zweiten Datei als eigener Stand zurückgerollt werden können. `replace` gibt jetzt einen Snapshot der eigenen Stage aus ihren Daten und fstat zurück. `committed` verwendet diesen Snapshot. Der bestehende Rollbackvergleich kann damit Änderungen nach dem eigenen Commit erkennen. Korrektur anhand der Quelle bestätigt; nicht als separat reproduzierter Race-Test ausgegeben.

## Weitere geprüfte Eigenschaften

- **Dialogfreies check:** AgentService verwendet KeychainStore ausdrücklich mit `allowInteraction: false`. Der aktuelle klassische Login-Keychain-Pfad setzt Security `kSecUseAuthenticationUIFail` ohne eigenen LAContext und ohne interaktiven Fallback. Die frühere kombinierte Query wurde nach konkreten Systemfehlern vereinfacht; dies ist kein Beleg für die Ursache der Systemfehler. check liest und verwirft Werte, erstellt keinen Zielprozess und schreibt keine Konfiguration. Nicht verfügbare Werte ergeben ausschließlich Status `missing`, `invalid` oder `unavailable`; Providerfehlertexte gelangen nicht in JSON.
- **Auskunft/CLI:** Listen/describe/instructions/setup lesen keine Credentialwerte. JSON besitzt schemaVersion 1, Erfolg/Fehler und stabile Codes; ungültige/doppelte Flags sowie falsche Argumentanzahl werden abgefangen. check verwendet Exitcode 0/2 für bereit/nicht bereit, strukturierte Aktionsfehler 1. run bleibt der explizite Prozessstart. Keine neue get/export-Schnittstelle.
- **Dateien:** Verzeichnisidentität und beide Vorschau-Snapshots werden vor Mutation geprüft. Normale Dateien, maximal 1MiB, kein Symlink oder weiterer Hardlink. UTF-8, eindeutige Marker und Profilzugehörigkeit werden geprüft. Nur eigene Markerbereiche werden ersetzt; sonstige Bytes bleiben im Text erhalten. Wiederholung derselben Einrichtung bleibt unverändert.
- **Fehler/Rollback:** Geänderter Zielstand wird vor jedem Commit und Rollback geprüft. Normale Fehler der zweiten Datei lösen Rücknahme der eigenen ersten Änderung aus; nach erkanntem Fremdedit wird stattdessen `rollback_failed` gemeldet. Der Unit-Test verwendet eine echte unveränderliche zweite Tempdatei und erwartet beide Originalinhalte. Diesen Projekt-Unit-Test führte der Kritiker nicht erneut aus.
- **UI:** Vorschau enthält Anleitung, Projektziel und Liste geänderter Dateien; Abbruch schreibt nicht. Erst explizites „Im Projekt einrichten“ wendet den Plan an. Ausgangsrevision ist im Draft gespeichert und wird vor Apply mit der aktuellen Konfiguration verglichen; Dateisnapshots werden unabhängig nochmals geprüft. Dies ist Quellenprüfung, kein beobachteter UI-Durchlauf.

## Ehrliche Grenzen

Die Einrichtung verwendet optimistische Snapshotvergleiche und die kooperative Verzeichnissperre. Zwischen letztem Vergleich und Rename/Unlink bleibt ein kleines Fenster gegenüber nicht kooperierenden Editoren; keine atomare CAS-/Isolations- oder gemeinsame Zweidatei-Crash-Transaktion zugesagt. Der Plan benennt die optimistische Erkennung inzwischen ausdrücklich.

Der Compiler warnt für das bewusst verwendete ältere Security-UI-Fail-Symbol. Der aktuelle klassische Login-Keychain-Pfad erstellt keinen LAContext. Diese Quellprüfung hat weder echte Credentials gelesen/erzeugt noch Schlüsselbünde erzeugt/gesperrt oder Authentifizierungsdialoge getestet. Reale OS-Dialogfreiheit und Agentenausführung dürfen daher nicht aus dem unabhängigen Race-/Quelltest abgeleitet werden. Spätere echte Sitzungen ausschließlich mit künstlichen Fixtures und vorhandener Anmeldung getrennt berichten.

## Zusatzprüfung Fehlerstatus und Fixture-Skripte

Aktuelle Ergänzungen ebenfalls **PASS als Quellenprüfung**:

- `CredentialError.unavailable(Int32)` bewahrt ausschließlich den numerischen Security-Status. check gibt diesen optional als `keychainStatus` aus und erhält den groben Status `unavailable`; andere Providerfehler bleiben ohne Fehlertext. Kein Credentialwert oder beliebiger Providertext wird hinzugefügt. Die dialogfreie Abfragepolitik bleibt unverändert.
- `script/agent_acceptance.py` erstellt ausschließlich ein einmaliges Tempverzeichnis mit eigenem Metadatenpfad, daraus abgeleitetem Service und neuer Account-UUID. Sessionumgebung entfernt API-/Secret-/Token-Overrides; bestehende Clientanmeldung wird verwendet. Die Codex-Variante `user` liest die bestehende Policy, überschreibt sie nicht; MCP wird nur in Aufrufargumenten deaktiviert. Keine globale Toolkonfiguration wird geschrieben. Prozessgruppen werden bei Timeout beendet; Logs ersetzen den künstlichen Wert, JSON markiert tatsächlich beobachtete Wertausgabe separat.
- `script/seed_agent_fixture.swift` erstellt oder sperrt keinen Schlüsselbund. Seed benutzt SecItemAdd statt Update und trusted applications ausschließlich für vorgesehenes Apppaket und eigenen Fixturehelper. Befehle verlangen gültiges Namespacepräfix/UUID und künstliches Wertpräfix. Nach Reviewkorrektur enthält auch Delete das feste Label `Secretariat · Prüfung Agenten (temporär)`; ein gewöhnlicher Secretariat-Eintrag kann dadurch nicht nur wegen falsch übergebener Service-/Accountdaten entfernt werden. Cleanup nutzt genau die für diesen Lauf erzeugten Referenzen. Inventar liest nur Attribute und filtert dasselbe Fixturelabel.

Lesend eingesehene Sitzungsartefakte: Claude meldet Receipt `credential_verified=true`, `cwd_verified=true`, keine künstliche Wertausgabe und Cleanup erfolgreich. Codex workspace-write meldet kein Receipt/keinen erfolgreichen Start; OpenCode ebenfalls nicht verifiziert. Diese Artefakte stammen von Root, nicht von einer unabhängig wiederholten Sitzung. Ein älteres Codex-Artefakt enthält einen Fixture-check-Timeout; das ist kein E2E-Erfolg. Der noch ausstehende erneute Versuch und die wegen Native-Pipe-Problems nicht ausgeführte UI-Prüfung werden hier nicht vorweggenommen.

Das erzeugte `verify.py` enthält den künstlichen erwarteten Prüfwert. Die Tests belegen korrekte Prozessinjektion und beobachtete Ausgabehygiene, keine Isolation des Prüfwerts vor einem Agenten mit Lese-/Shellrechten. Diese Grenze entspricht dem ausdrücklich akzeptierten Produktscope. Diese Zusatzprüfung hat weiterhin keine Keychain-/Credentialaktionen ausgeführt.

## Zusatzprüfung CLI-Timeout und klassische Query

**PASS als Quellen-/Memory-Fehlerpfadprüfung.** `CheckWatchdog` wird ausschließlich im CLI-check-Zweig gestartet. Sein NSLock schützt den abgeschlossenen Zustand; sowohl erfolgreicher Abschluss als auch Fehler-Defer deaktivieren den späteren Timer. Gewinnt der Timer, schreibt er genau das vorbereitete wertfreie Fehler-JSON und beendet den CLI-Prozess mit Code 2. Normale GUI und run starten diesen Watchdog nicht.

Unabhängig ausgeführt: `/tmp/secretariat-watchdog-review.swift` mit echten aktuellen Corequellen kompiliert, aber mit ausschließlich `SleepingCredentials` (Memory-CredentialStore, read schläft 20 Sekunden). Ein temporäres Metadatenverzeichnis wurde vom äußeren Pythonprozess angelegt und entfernt. Beobachtung nach 10.7 Sekunden: Exitcode 2, genau ein parsebares JSON-Objekt mit schemaVersion 1, ok=false und error.code=keychain_timeout; stderr leer. Keine echte Credentialabfrage, kein Schlüsselbundzugriff, keine UI. Damit ist die begrenzte Fehlerantwort unabhängig bestätigt; das Security-Systemproblem selbst wurde nicht geprüft oder gelöst erklärt.

Zur Queryvereinfachung wurde das lokale Apple-SDK `Security.framework/Headers/SecItem.h` lesend geprüft. Es beschreibt für `kSecUseAuthenticationUIFail` ausdrücklich errSecInteractionNotAllowed, wenn ein Eintrag UI-Authentifizierung benötigt. Eine zusätzliche LAContext-Instanz ist dort keine Pflicht dieser Policy. Für die vorhandene klassische Login-Keychain ist UI-Fail ohne LAContext damit eine fachlich vertretbare gezielte Query. Die Meldung -50 aus der vorherigen Sandboxsitzung passt zu einem Parameterfehler, beweist aber nicht LAContext als Ursache. UI-/run-Interaktionsverhalten bleibt unverändert; kein interaktiver Fallback eingeführt.

Die später von Root beobachteten Lookup-Timeouts bleiben reale Grenzen der betreffenden Testläufe. Ein `keychain_timeout`-Ergebnis ist ein sauber begrenzter Fehler, kein bestandener Credentialverfügbarkeits- oder Agenten-E2E-Test. Frühere erfolgreiche Receipts gelten für ihren dokumentierten damaligen Paketstand und dürfen bei neuem Build nicht ungeprüft als aktuell übertragen werden.

## Aktueller Nachtrag zum erneut beobachteten Systemdialog

**Die frühere Quellfreigabe ist für das Nichtinteraktivitätskriterium vorläufig überholt.** Der erneut vom Nutzer beobachtete Dialog zeigt, dass UI-Fail/LAContext bei der eingesetzten file-based-Keychain das Produktversprechen nicht zuverlässig erfüllt. Der Watchdog-Memorytest bleibt gültig für seinen engen Umfang, ersetzt aber keine Korrektur dieses Fehlers. Die Primärquellenprüfung und empfohlene scoped Legacy-Unterdrückung stehen in `docs/keychain-policy-review.md`. Vor Abschluss dieses Kriteriums ist der neue Guard gesondert zu prüfen; hier wird kein noch nicht bewerteter Guard als bereits implementiert/funktionierend ausgegeben.

## Abschließender Guard-Nachtrag

**Aktuelle Quellbewertung wieder PASS einschließlich des neuen Legacy-Guards.** Dies ersetzt die vorläufig offene Bewertung des zuvor erneut beobachteten Dialogs hinsichtlich der jetzt implementierten Quelle; es ersetzt keine tatsächliche UI-Abnahme.

KeychainStore serialisiert jede Operation mit NSRecursiveLock. Nichtinteraktiver Store prüft Get und Set(false), führt nur dann die eigentliche Operation aus und stellt im defer den exakten vorherigen Prozesszustand wieder her. Auch interaktive Storeoperationen nehmen denselben Lock; normale GUI-Vaults bleiben interaktiv. CLI-Default-Vault und AgentService sind ausdrücklich nichtinteraktiv, jetzt auch CLI-run. Ein Rechtefehler entsteht vor dem Zielprozessstart. Die begrenzende CLI-check-Timeoutantwort bleibt vorhanden.

Der Fixturehelper verwendet den .app-Trustpfad und wird mit der Developer-ID-Identität des Appartefakts signiert. Zusätzlich gefundene ungeschützte Testpfade wurden korrigiert: inventory liegt jetzt im Legacy-Scope, direkter security-Find-Fallback entfällt, Cleanup nutzt den scopedHelper mit Fixturelabel/Service/Account. Die aktuelle Quelle enthält diese Korrekturen. Technische Primärquellen und Scopebegründung stehen in `docs/keychain-policy-review.md`.

Root berichtet für den korrigierten Build drei schnelle negative check-Aufrufe, abgebrochenen run ohne Zielmarker, erfolgreiche Fixturebereinigung sowie acht positive Paket-Prozesschecks. Der unabhängige Prüfer hat keine dieser Credentialaktionen wiederholt. Frühere Buildreceipts sind weiter historisch; neue Coding-Sitzungen und wegen CUA-Native-Pipe-Problemen ausstehende normale UI-Prüfung werden nicht als bereits bestanden ausgegeben. Version 0.2 ist durch diesen Quellen-PASS allein nicht vollständig abgenommen.
