# Secretariat: Vorschlag für den Neustart

Stand: 22.10.2026. Von Udi zur Umsetzung freigegebener Minimalumfang. Aktueller Nachweisstand: TRACKER.md; Bedienung und lokale Installation: README.md.

## Ziel und Annahmen

**API-Schlüssel einmal auf dem Mac hinterlegen, einem Projektprofil zuordnen und einen Entwicklungsbefehl damit starten.**

Der Name bleibt Secretariat. Erste Zielgruppe ist Udi auf dem eigenen Mac. Die erste Version soll lokale Entwicklungsprojekte unterstützen. Eine plattformübergreifende oder öffentliche Veröffentlichung gehört zu einer späteren Entscheidung.

## Drei Funktionen für Version 0.1

1. **Schlüssel verwalten:** verständlicher Name und geheimer Wert; anlegen, ändern und löschen. Werte sind in der Oberfläche zunächst verdeckt. Ein Schlüssel lässt sich in mehreren Profilen wiederverwenden.
2. **Projektprofil zusammenstellen:** Ordner wählen und Umgebungsvariablen vorhandenen Schlüsseln zuordnen, beispielsweise `OPENAI_API_KEY` → „OpenAI Entwicklung“. Jedes Profil hat seine eigene Zuordnung; zwei Profile können denselben Variablennamen mit verschiedenen Werten verwenden.
3. **Befehl starten:** Ein kleiner Terminalbefehl stellt die gewählten Werte ausschließlich dem gestarteten Prozess und dessen Unterprozessen bereit. Anwendungscode und SDKs des Zielprojekts müssen dafür nicht angepasst werden.

Beispiel der gewünschten Bedienung, noch kein vorhandener Befehl:

```sh
secretariat run cooking-ai-local -- pnpm dev
```

Das Profil bestimmt Arbeitsordner und Variablenzuordnung. Das Kommando nach `--` kommt aus der aktuellen bewussten Benutzeraktion. Es wird nicht automatisch aus Projektdateien ausgeführt. Änderungen an den Schlüsselwerten gelten beim nächsten Prozessstart.

## Hauptfenster

Zweck: Schlüssel zu einem ausgewählten Profil hinzufügen und den passenden Terminalaufruf kopieren. Der kopierte Aufruf enthält ausschließlich Profilname und Befehl, keine Schlüsselwerte.

```text
Secretariat
──────────────────────────────────────────────────────────
Alle Schlüssel       Cooking AI · lokal
                     Ordner: …/cooking_ai
Projektprofile
  Cooking AI · lokal Variable          Verwendeter Schlüssel
  Stillday · lokal   OPENAI_API_KEY    OpenAI Entwicklung
                     WEATHER_API_KEY   Wetter Entwicklung
+ Profil
                     + Schlüssel zuordnen

                     Befehl: pnpm dev
                     [Terminalaufruf kopieren]
```

Unter „Alle Schlüssel“ genügt eine Liste mit Hinzufügen, Bearbeiten und Löschen. Beim ersten Start zeigt das Fenster „Ersten Schlüssel hinzufügen“. Fehlende Schlüssel und verweigerter Zugriff verhindern den Programmstart mit einer verständlichen Meldung. Ein zu löschender, noch verwendeter Schlüssel zeigt seine betroffenen Profile an; deren Zuordnungen werden nicht stillschweigend entfernt.

## Technischer Vorschlag

- **Swift und SwiftUI** für eine native macOS-Anwendung in einem Swift-Projekt. Apple dokumentiert SwiftUI als Framework für native Oberflächen: [SwiftUI](https://developer.apple.com/documentation/swiftui).
- **macOS-Schlüsselbund** als Speicher für die geheimen Werte. Apple stellt dort verschlüsselte Ablage sowie Lesen, Ändern und Löschen bereit: [Keychain Services](https://developer.apple.com/documentation/security/using-the-keychain-to-manage-user-secrets). Eigene Tresorverschlüsselung und ein zusätzliches Master-Passwort werden dadurch für diesen Entwurf unnötig.
- **Eine kleine lokale Konfigurationsdatei** für Profile, Ordner, Variablennamen und Schlüsselreferenzen. Sie enthält keine geheimen Werte.
- **Terminalzugang aus demselben App-Paket**, möglichst über dasselbe signierte Programm mit einem CLI-Modus. Dadurch muss kein dauerhaft laufender Dienst zwischen Oberfläche und Terminal vermitteln. Der Name des Befehls lautet `secretariat`.

Ein Programm kann mit Foundation `Process` ein Unterprogramm mit vorbereiteten Umgebungsvariablen starten. Apple weist auch auf die geerbten Sandbox-Beschränkungen hin: [Process](https://developer.apple.com/documentation/foundation/process). Der erste Nachweis muss deshalb mit dem tatsächlich vorgesehenen App-Paket und seiner Signierung erfolgen; ein isolierter Swift-Test belegt noch keinen funktionierenden Terminalzugriff oder Entwicklungsserver.

## Bewusste Grenze

Secretariat selbst speichert oder protokolliert keine Klartextwerte in Projektdateien oder Aufrufen. Das gestartete Programm erhält die echten Werte und kann diese seinerseits ausgeben oder weitergeben. Ein Profilname ist keine authentifizierte Prozessidentität. Dieser Entwurf verspricht daher keine Isolation vor einem frei handelnden Agenten mit Shell-Zugriff.

Die erste Version kommt ohne Daemon, LaunchAgent, automatischen Start bei Anmeldung, MCP, Sprach-SDKs, Cloud-Synchronisation, Teams oder automatische Anbieter-Rotation aus. Zugriffsschutz im Schlüsselbund und gegebenenfalls macOS-Benutzerfreigaben müssen tatsächlich geprüft werden; das Vorhandensein eines Schlüsselbund-Eintrags allein belegt keine verpflichtende Touch-ID-Abfrage.

## Archivierung und Reihenfolge

1. **Alten Stand einfrieren:** Den vollständigen bestehenden Arbeitsordner samt `.git`, Dokumentation und noch nicht eingecheckten Dateien als datiertes Legacy-Archiv erhalten. Lose Dateien werden nicht pauschal zu einem Commit hinzugefügt. Eine lokale Archivierung löst keine GitHub-Archivierung oder Änderung des bestehenden Remotes aus.
2. **Frischen Arbeitsordner anlegen:** Name `Secretariat`, eigener sauberer lokaler Git-Start. Aus dem Altprojekt werden nur Problemdefinition, Erkenntnisse und dieser begrenzte Zielumfang übernommen. Alte Schlüsselbund- und iCloud-Daten werden nicht automatisch migriert; der Neustart erhält einen eigenen Speicher-Namespace.
3. **Zuerst einen senkrechten Funktionsnachweis bauen:** Einen künstlichen Wert im Schlüsselbund speichern und aus dem geplanten Terminalzugang an einen Testprozess übergeben. Den Nachweis mit geschlossener Oberfläche, nach erneutem Start und bei verweigertem Zugriff wiederholen. Abbruch, Exitcode, Ein-/Ausgabe und Beenden eines Entwicklungsprozesses müssen funktionieren.
4. **Kleine Oberfläche ergänzen:** Schlüsselverwaltung, Profile und Kopieren des Aufrufs. Ein echtes Entwicklungsprojekt durchgehend damit starten.
5. **Version 0.1 abschließen:** Installation und Entfernung prüfen, Profilkonfiguration nach Neustart wiederfinden und das Ändern eines wiederverwendeten Schlüssels in zwei Profilen beim nächsten Start nachweisen. Erst bei einem konkreten Alltagsproblem den Umfang erweitern.

Ein `.env`-Import bleibt eine mögliche kleine Folgefunktion, sobald wiederholtes manuelles Übertragen im ersten echten Projekt zu aufwendig wird.

## Compact PAD/PRD for implementation agents

### Problem and context

Udi maintains API credentials across multiple local development projects on macOS. The prior Rust/Flutter platform has been removed from active system installation. A clean restart should deliver one small, reliable development workflow under the name Secretariat.

### Actors and value

- Local Mac owner: maintain reusable credentials and choose which values a project launch receives.
- Child development process: receive selected environment variables without application-specific SDK changes.

### Core behavior and main screen

- Store secret values in macOS Keychain; keep only references and profile metadata in local configuration.
- Each profile binds an explicit working directory and environment variable names to stored secret references.
- Provide masked secret CRUD, profile editing, and copying a value-free terminal invocation.
- Launch an explicitly requested command with the selected profile; fail before launch when required credentials cannot be retrieved.
- Preserve terminal input/output, exit status and expected interruption behavior.
- Updating a shared secret affects subsequent launches of every profile referencing it.

### Constraints and outputs

- Native macOS scope; proposed Swift/SwiftUI app package with a terminal entry point and shared behavior.
- No persistent service, login item or automatic execution of repository-defined commands.
- Use a fresh storage namespace; preserve legacy vaults and credentials.
- No secret values in Secretariat configuration, command arguments, copied commands or application logging.
- Child processes receive real credentials. Profile selection does not enforce isolation against hostile local code or agents.
- Deliver a working packaged app, a tested launch command and a verifiable removal path.
- Test packaged Keychain access, signing/access denial, restart behavior, profile separation and child-process lifecycle before calling the version complete.

### Out of scope

Cloud sync, production credential orchestration, MCP, language SDKs, teams, background daemon, provider automation and automated legacy migration.

### Remaining validation

The proposed defaults are not confirmed product requirements. The first packaged technical proof must establish usable Keychain access from the chosen terminal entry point and the intended authentication behavior. Broader agent isolation would require a separate product and security decision.
