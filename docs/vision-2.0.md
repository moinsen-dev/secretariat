# Vision Secretariat 2.0: Schlüssel als Ressource

Stand: 2026-10-30, von Uli. Noch nicht beauftragt zu bauen; Leitbild für die Version 2.

## Leitbild

Heute ist Uli mit Secretariat passwort- und schlüssellos: Er kopiert keine Schlüssel mehr, sucht keine und verliert keine, und Agenten arbeiten mit Schlüsseln, ohne sie zu lesen. Version 2 geht einen Schritt weiter: **Niemand fasst einen Schlüssel noch an, auch nicht beim Entstehen.** Ein Programm oder Agent braucht Zugriff auf einen Dienst, Secretariat besorgt den passenden Schlüssel beim Anbieter, legt ihn ab, verteilt ihn, rotiert ihn und sperrt ihn wieder. Weder Mensch noch KI sehen je einen Wert. Schlüssel sind verfügbar wie Strom aus der Steckdose.

## Bausteine

1. **Beschaffen.** Anbieter-Adapter legen Schlüssel über die Verwaltungs-API des Anbieters an: mit Rechten, Name, Laufzeit, Zuordnung zu einem Profil. Vorbild ist der heutige TinIdeas-Weg (der eigene Server erzeugt den Token, Secretariat übernimmt ihn per `import`, niemand sieht ihn). Eigene Dienste (TinIdeas, Feedback-Café, TesterPayKit) zuerst, dann Fremdanbieter.
2. **Anfordern statt suchen.** Ein Agent sagt, was er braucht („Cloudflare: Workers deployen für Projekt X“). Secretariat prüft die Richtlinie, beschafft oder wählt den Schlüssel, bindet ihn ans Profil und meldet nur den Namen zurück.
3. **Rotieren.** Neuer Schlüssel → an alle Ziele verteilen (heute schon: `push` und Verteilstand) → mit einem harmlosen Aufruf prüfen → erst dann den alten widerrufen. Auslöser: Ablaufdatum, Alter, Zeitplan oder ein Fund.
4. **Sperren.** Findet `sweep` einen Schlüssel in einer Git-Historie oder meldet ein Anbieter ein Leck: widerrufen, ersetzen, verteilen, in einem Schritt. Mit Rückmeldung, was betroffen war.
5. **Richtlinien.** Welches Profil, welcher Agent welche Rechte bekommen darf; Touch ID für alles, was Schlüssel erzeugt oder sperrt.

## Die ehrliche Grenze

Jeder Adapter braucht einen Zugang zur Verwaltung des Anbieters (Admin-Token, Management-API-Schlüssel). Den muss ein Mensch einmal einrichten, und er ist das Kronjuwel: Touch ID bei jeder Nutzung, nie an Programme, nie im Klartext, Rotation auch für ihn. Anbieter ohne API zum Anlegen von Schlüsseln bleiben beim heutigen Weg (Zwischenablage, Screenshot, Import).

## Offene Fragen

- Welche Anbieter erlauben Anlegen, Rechte, Ablauf und Widerruf per API? (Recherche je Anbieter, gegen Primärquellen: Cloudflare, GitHub, OpenAI, Anthropic, Google Cloud, AWS, Supabase, Resend, Stripe, Apple App Store Connect, Lemon Squeezy, Hetzner …)
- Reihenfolge bei Fehlern: nie den alten widerrufen, bevor der neue überall angekommen und geprüft ist.
- Wo läuft die Rotation, wenn kein Mac wach ist? (Heute bewusst ohne Daemon; Zeitpläne brauchen Ulis ausdrückliches Ja.)
- Nachweis gegenüber dem Nutzer: Verlauf zeigt jede Beschaffung, Rotation und Sperre mit Herkunft.

## Nächster Schritt (wenn Uli ihn will)

Recherche „Schlüssel per API anlegen, rotieren, widerrufen“ je Anbieter, Ergebnis nach `docs/research/`. Danach ein erster Adapter für einen eigenen Dienst als Durchstich.
