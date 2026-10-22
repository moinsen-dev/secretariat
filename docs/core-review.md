# Unabhängige Core- und UI-Quellprüfung

Stand: 2026-10-22T17:08:25+02:00. Prüfer: delegierter Kritiker. Umfang: `Sources/SecretariatCore`, `Sources/Secretariat`, `Tests/SecretariatCoreTests/CoreTests.swift`, `script/build.sh`, `script/install.py` und `script/integration_check.py`. Keine Implementierungsdateien geändert.

Ergebnis: **PASS für die geprüften Quellen**. Kein weiterer blockierender Quellbefund im vereinbarten Minimalumfang. Dies ist keine vollständige normale UI-Abnahme und kein unabhängig ausgeführter Paket-Test.

## Erledigte Befunde

- **Keychain/JSON-Speicherfehler:** Update und Delete sichern den alten Wert und stellen ihn bei gescheitertem Konfigurationscommit wieder her. Rollbackfehler melden einen konkreten Fehler. Der zuvor unabhängig reproduzierte Fehler ist damit im Quellcode behoben; der Read-only-Regressionstest deckt beide Mutationen ab.
- **Fehlender Keychain-Eintrag:** `CredentialError.notFound` wird gezielt behandelt. Update kann einen neuen Wert anlegen, Delete eine verwaiste Referenz entfernen. Verweigerte Zugriffe werden nicht als fehlender Eintrag behandelt. War der Wert vorher nicht vorhanden, entfernt Update-Rollback den neu angelegten Wert. Reparatur und Entfernen sind im Test abgedeckt.
- **Veraltetes Formular:** Secret-/Profile-Drafts erhalten in allen geprüften Öffnungspfaden die Ausgangsrevision. Speichern verwendet genau diese Revision; ein späterer Model-Reload legitimiert kein altes Formular mehr.
- **Terminalaufruf:** Der kopierte Aufruf enthält einen absoluten Launcherpfad und ist damit unabhängig von `~/bin` im PATH. Shellargumente werden korrekt einzeln gequotet.
- **Profilansicht:** Der Detailinhalt ist scrollbar; viele Zuordnungen verdrängen Aktionen nicht strukturell in einen unzugänglichen Bereich. Darstellung und normale Bedienung sind separat zu beobachten.

## Weitere Quellprüfung

- Keine Klartext-Credentials in der Konfiguration oder im automatisch generierten Aufruf erkennbar. Fehlertexte enthalten Status/Metadaten und keine Schlüsselwerte. Die Liste zeigt Platzhalter, der Editor verwendet SecureField.
- Neuer Keychain-Service ist an den lokalen Datenpfad gebunden, Synchronisierung ausgeschaltet; Legacy-Services werden nicht angesprochen. Die Namespaces sind keine Sicherheitsgrenze gegenüber demselben Mac-Nutzer.
- Konfigurationsvalidierung, atomarer Dateitausch, Schreibsperre und Revisionsvergleich passen zur lokalen Anwendung. Fehlende/verweigerte Werte verhindern die Vorbereitung und damit den Zielprozessstart. Referenzierte Schlüssel sind gegen Löschen geschützt.
- CLI ersetzt sich per `execve`, statt einen zusätzlichen dauerhaften Prozess zu halten. Der Integrationstest beschreibt konkrete Prüfungen für cwd, Environment, stdin/stdout/Exitcode, gemeinsam verwendete Schlüssel, wörtliche Argumente, fehlende Programme/Profile/Werte, echtes PTY-Ctrl-C und Erhalt beschädigter JSON-Daten. Der Prüfer hat diesen Test nicht selbst wiederholt.
- Installation prüft App-ID und exakten CLI-Verweis vor Änderungen; unbekannte/fremde App- oder Terminalpfade werden abgelehnt. Die App wird erst nach gültiger gestagter Kopie ersetzt. Entfernung erhält Metadaten und Credentials und verschiebt das Paket in den Papierkorb. Die Identitätsprüfung schützt vor üblichen Namenskollisionen; sie behauptet keinen Schutz gegen absichtlich gefälschte Pakete desselben Benutzers.

## Prüfgrenzen und Systemdialoge

**Ein tatsächlich gesperrter Schlüsselbund ist kein erfolgreich abgenommener Fall.** Ein früherer Versuch mit einem gesperrten separaten Testschlüsselbund führte trotz `LAContext.interactionNotAllowed` zu einem Passwortdialog. Der Versuch wurde beendet und seine Testartefakte entfernt. Der aktuelle Quellstand enthält keine Schlüsselbund-Erstellungs-/Sperrtests und keinen eigenen Keychain-Parameter mehr. Der vorhandene echte ungesperrte Roundtrip ist ausdrücklich opt-in; Standardtests verwenden künstliche CredentialStores für Verweigerung/Fehlen. Ein Mock belegt das Abbruchverhalten der Anwendung, nicht das tatsächliche Dialogverhalten eines gesperrten macOS-Schlüsselbunds. Normale macOS-Zugriffsabfragen bleiben möglich und werden nicht umgangen.

Für den Abschluss sind die dokumentierten tatsächlichen Paket-/UI-/Installationsnachweise maßgeblich. Das Zielprogramm erhält echte Werte und kann diese ausgeben; dieser bewusst akzeptierte Umfang bietet keine Agent-Isolation.

## Historischer unabhängiger Fehlersimulationsnachweis

Beim ersten Review wurde Core mit `/tmp/secretariat-review-transaction.swift` kompiliert, ausschließlich temporärer Ordner und Memory-CredentialStore verwendet. Nach Credential-Mutation wurde der Konfigurationsordner schreibgeschützt. Vor der Korrektur meldeten Update und Delete Fehler, JSON blieb alt, Credential war trotzdem verändert/gelöscht. Temporärer Datenordner wurde entfernt. Dieser Befund erklärt die jetzt vorhandene Regression; er ist kein aktueller Fehlernachweis und verwendete keinen echten Keychain-Eintrag.
