# Arbeitsweise für diese App

## Einstieg und Fortsetzung

1. Diese Datei und `STATE.md` lesen; danach die dort referenzierten Abschnitte aus `PLAN.md` und `TRACKER.md`.
2. Tatsächlichen Checkout, vorhandene Änderungen, App-Modus und verfügbare Prüfwerkzeuge abgleichen.
3. Die nächste ausführbare Aufgabe des vereinbarten Ziels bearbeiten. Vorhandene Freigaben gelten weiter; reversible Details selbst entscheiden.

## Projekt

- Profil: macos
- Zielumgebungen: macos
- Verwendeter Skill: `app-workflow`, Vorlage 1.1.0.
- Werkzeug: `python3 /Users/udi/.agents/skills/app-workflow/scripts/workflow.py`

`PLAN.md` definiert Ziel, Anforderungen, Reihenfolge, Use Cases, Aufgaben und Kriterien. `TRACKER.md` ist die einzige Aufgabenstatusquelle. `STATE.md` wird daraus mit dem Werkzeug aktualisiert. Bestehende ergänzende Projektregeln haben weiterhin ihren jeweiligen Geltungsbereich.

## Umsetzung

- Wirksame persönliche Vorgaben aus PLAN/Personalization verwenden. Aktueller Auftrag und konkrete Projektentscheidungen gehen wiederverwendbaren Defaults vor. Profiländerungen benennen keine bestehenden Apps oder GitHub-Remotes um und erteilen keine neue externe Befugnis.
- Bei einer bestehenden App den dokumentierten Bestand und Änderungsumfang aus PLAN beachten. Vorhandene Funktionen anhand passender Nachweise übernehmen, offene Prüfungen einplanen und betroffene bisherige Abläufe erhalten. Ein Feature-Auftrag wird dadurch nicht zum Neuaufbau des gesamten Produkts.
- App-Identität, finale Icons/Grafikressourcen und Rechte aus App-Code sowie SDKs konkret prüfen. Auslieferungswege aus PLAN/Delivery beachten; Voraussetzungen früh einordnen und tatsächlichen Endzustand in TRACKER/Releases belegen.
- Alle Katalogpunkte und Zusatzmodule einordnen. Relevante Punkte konkreten Aufgaben zuordnen; begründete Ausnahmen und echte Unklarheiten sichtbar halten.
- Vor der Ausführung des geplanten App-Baus den Plan vollständig konkretisieren und `check --ready` ausführen. Die Planung selbst darf vorher stattfinden.
- Vollständige Nutzerabläufe umsetzen, passende Prüfung tatsächlich ausführen und beobachtete Ergebnisse festhalten. Zusätzliche Tests brauchen einen konkreten Nutzen; bestehende sinnvolle Projektprüfungen berücksichtigen.
- Der normale App-Modus und die Prüfumgebung müssen zur Aussage passen. Fixture-Durchläufe belegen ihren beschriebenen Umfang.
- Ein Kritiker prüft zunächst den Plan und später vollständige Use Cases. Bei verfügbarer und erlaubter Delegation unabhängig prüfen lassen, sonst Selbstprüfung kennzeichnen. Kritikerbefunde am Nutzerauftrag und den Kriterien ausrichten.
- Fehler korrigieren, betroffene Prüfungen wiederholen, Tracker und anschließend State aktualisieren, innerhalb des Ziels weiterarbeiten. Wiederholungen ohne neue Erkenntnis führen zur Ursachenklärung.
- Abschluss nur mit vorgesehenen Nachweisen. Blockaden mit Ursache und konkretem nächsten Handgriff festhalten und unabhängige Arbeit fortsetzen.

## Fortschritt pflegen

Nach Änderungen am Plan oder Tracker `state --task <ID> --next <konkreter Schritt>` und danach `check` ausführen. Bei Übergabe oder geplanter Unterbrechung ebenfalls aktualisieren.

Belege mit `evidence`, Kritik mit `review`, Auslieferungszustände mit `release` und Aufgabenstatus mit `task` eintragen; das Werkzeug bindet dabei den Fingerprint des geprüften Stands. Nachweise nennen Schritte, Erwartung, Beobachtung, Zeitpunkt, Code-/Buildstand und Einschränkungen. Die Aufgabe benennt in `Files` die betroffenen Quellen und relevanten Abhängigkeiten; damit erkennt der Prüfer Änderungen in diesem Umfang. Änderungen außerhalb dieses Umfangs auf Auswirkungen prüfen.

Bei Release-Zielen unterscheidet der Tracker LOCAL, READY, SUBMITTED und LIVE. Ein Upload oder eine Einreichung belegt keine Verfügbarkeit für Nutzer. Die persönliche Präferenz für einen Anbieter ersetzt keine Autorisierung zu Veröffentlichung, Kontoerstellung oder Kosten. Bestehende konkrete Freigaben gelten weiter.

Das Werkzeug läuft mit Python 3.10 oder neuer. Seine genaue Nutzung und das Markdown-Format stehen im geladenen Skill. Wenn sich dessen Installationsort ändert, den Werkzeugverweis aktualisieren.
