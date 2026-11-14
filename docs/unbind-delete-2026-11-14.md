# Löschen mit Entkoppeln (2026-11-14)

Anlass: Uli wollte einen ungültigen Schlüssel löschen und bekam „This item is still in use: …. Please remove the bindings first.“ Statt ihn zum Projekt zu schicken, bietet der Löschdialog jetzt das Entkoppeln gleich an.

## Änderung

- `Configuration.uses(of:)`: Projekte und Ziele, die einen Eintrag binden, mit Variablen („web-app (API_KEY)“, „target box (TOKEN)“). Auch die Fehlermeldung nennt jetzt die Variablen.
- `Vault.delete(id:unbinding:)`: mit `unbinding` werden die Bindungen in einer Konfigurationsänderung entfernt (mit erwarteter Revision; bei Zielen auch der gemerkte Push-Fingerabdruck), Verlaufseintrag „Unbound PATH from …“, danach das Löschen wie bisher.
- App: Der Dialog „Delete item?“ nennt bei gebundenen Einträgen die Nutzer und hat den Knopf „Unbind and Delete“; sonst unverändert.

## Prüfung

- `xcrun swift test`: 149 Tests grün; neu `deletingWithUnbindRemovesTheBindingsFirst` (Projekt- und Zielbindung, ohne Freigabe weiterhin Fehler, danach nur fremde Bindungen übrig, Push-Stand leer, Verlauf „Unbound … target box (TOKEN)“).
- Testinstanz mit künstlichem Tresor (Projekt `edge-worker` bindet `CF_FIX_TOKEN` an `acme/cloudflare/fix-session`): Suche `CF_FI`, Zeile gewählt, Menü Item › Delete Item …: Dialog zeigt „‘acme/cloudflare/fix-session’ is still used by edge-worker (CF_FIX_TOKEN). These bindings will be removed first …“ mit Knopf „Unbind and Delete“ (Bildschirmfoto im Scratchpad).

Einschränkung: Den Klick auf „Unbind and Delete“ konnte ich in der Testinstanz nicht auslösen, weil ihr Fenster während des Laufs auf einen anderen Schreibtisch kam (für Bedienungshilfen unsichtbar). Der Knopf ruft nur `deleteItem(item, unbinding: true)` auf; dessen Wirkung belegt der Unit-Test.
