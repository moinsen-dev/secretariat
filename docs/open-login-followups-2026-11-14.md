# Öffnen und anmelden: Nacharbeiten (T042, UC36), 2026-11-14

Anlass: BACKLOG „Öffnen und anmelden: Nacharbeiten“ (nach 1.18.0). Uli: „Ja, mach Punkt 1“.

## Änderung

- **Touch ID abgebrochen oder fehlgeschlagen:** Hinweis „Touch ID was cancelled, so nothing was typed. The page stays open: … ⌃⌥⌘P“ statt stillem Ende.
- **Anmeldung in zwei Schritten:** Zeigt die Seite nur ein Benutzernamen-Feld (erkannt an DOM-Id, Platzhalter, Beschriftung; Such- und Newsletter-Felder zählen nicht), tippt Secretariat nach Touch ID den Benutzernamen und wartet bis zu 60 Sekunden, bis der Nutzer weiterklickt und ein Passwortfeld erscheint; dann das Passwort ohne zweites Touch ID. Nie abgeschickt.
- **Ziele des Passworts** (`LoginOpen.destination`): der gespeicherte Host in jedem Fenster, mit gleichem Port und gleichem Schema oder https (kein Wechsel auf http). Jeder andere Host, auch derselben Site, nur als vorderste Seite des Browsers und nur über https (http nur zwischen lokalen Adressen auf diesem Mac), etwa nach Umleitung zu einem Anmeldedienst; Touch ID nennt ihn dann („sign in to HOST (sent there by ITEMHOST) with PATH“), und erst danach wird getippt, auch der Benutzername. Ein weiterer fremder Host fragt erneut. Im zweiten Schritt zählt nur die vorderste Seite.
- **Tresor-Bindung:** Die Anfrage von CLI/MCP nennt den Tresor; die App ignoriert Anfragen für einen anderen Tresor (eine CLI mit `SECRETARIAT_HOME` steuert nicht die echte App).

## Prüfung

| Prüfung | Beobachtung |
|---|---|
| build | `xcrun swift build` grün |
| unit | `xcrun swift test` 152 Tests; unter Systemlast 55–183 rissen zwei Tempo-Tests (Suche, Verlauf), einzeln laufen beide grün, mit dieser Änderung ohne Bezug; neu: Zielregel (gleicher Host, Site, Shared-Hosting, fremde Site nur vorne und https, localhost-Ports), Benutzernamen-Erkennung, Tresor-Bindung |
| macos, Erkennung | Prüfprogramm (Scratchpad, gleiche Quellen `LoginFill.swift`/`LoginOpen.swift`) gegen lokale Testseiten in **Safari und Chrome**: einstufig → Benutzer + Passwort; Schritt 1 → nur Benutzername (Felder „identifierId“/„Email or phone“); Schritt 1 mit Passwortpflicht → nichts; Schritt 2 → Passwort; Umleitung `localhost:8765` → `localhost:8766` → `redirect` mit Formular; Newsletter-Seite → nichts. Beide Browser gleich. |
| macos, Ablauf | Testinstanz (`dist/Secretariat.app`, künstlicher Tresor) mit Chrome als Standardbrowser, Touch ID von Uli: einstufig gefüllt (Benutzername und 17-stelliges Testpasswort im Formular); zweistufig: Benutzername eingetragen, nach Ulis „Next“ Passwort auf Seite 2, Verlauf „Sign in localhost:8765 test/twostep/password“; Umleitung: gefüllt auf `localhost:8766`, Verlauf „Sign in localhost:8766 test/sso/password“. Test-Logins danach gelöscht. |

Einschränkungen: Den Abbruch-Hinweis hat niemand live gesehen (System-Dialog von Touch ID lässt sich nicht fernsteuern; Uli brach den Testlauf ab, „zu fummelig“); im ersten Lauf störte ein von mir gesendetes Escape das Tippen des Benutzernamens. Der Dialogtext mit „sent there by“ wurde nicht abgelesen, nur die Wirkung. Safari nur für die Erkennung geprüft, nicht für das Tippen; Firefox ist auf diesem Mac nicht installiert.

## Kritik

Unabhängige Prüfung (Subagent, nur lesend): REWORK mit kleinen Punkten. Übernommen: (1) „gleiche Site“ ist kein Freibrief mehr, weil die Site-Erkennung ohne vollständige Public-Suffix-Liste und bei IP-Adressen danebenliegt; jeder andere Host braucht vorderste Seite, https und Touch ID mit Namen; (2) gleicher Host nur mit gleichem Port und ohne Wechsel auf http; (3) Prüfung des bestätigten Hosts vor dem Tippen des Benutzernamens; (4) Passwortseite im zweiten Schritt nur auf der vordersten Seite; (5) http nur, wenn auch der Eintrag lokal ist; (6) Tresorpfad über Symlinks und `/private` normalisiert. Nicht übernommen (bewusst): die Benutzernamen-Erkennung bleibt wortbasiert (Kennung, nie abgeschickt); `Thread.sleep` beim Benutzernamen und das 60-s-Warten ohne Anzeige.

Die Nachprüfung der Erkennung in Safari und Chrome nach der Überarbeitung habe ich abgebrochen, weil der Rechner unter Volllast stand (Uli). Die geänderte Regel belegen die Unit-Tests; die Live-Läufe davor betreffen Fälle, deren Einordnung gleich bleibt (gleicher Host; lokale Umleitung auf der vordersten Seite).
