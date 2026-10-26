# T011 – CLI keys und profile (0.3)

Zeit: 2026-10-26, M4 (macOS 27.0, Apple M4 Pro). Build: Commit ce7cb30, Paket dist/Secretariat.app 0.3.0, Developer-ID-signiert (VXX45ZYNM8).

## Schritte und Beobachtung

1. `swift test`: 23 Tests grün, davon neu `keysListNamesAndUsageWithoutReadingValues`,
   `profileCreateBindUnbindDeleteRoundTrip`, `profileCommandsRejectInvalidInputWithStableCodes`,
   `profileArgumentParserHandlesValuesAndRejectsUnknownOptions`. Erwartung: keine Wertlesezugriffe bei `keys`,
   Validierung wie in der App, fehlgeschlagene Änderung lässt profiles.json byte-gleich. Beobachtet: so.
2. Paket-CLI mit Wegwerf-`SECRETARIAT_HOME` (eine Schlüsselreferenz „Prüfung Gemini“, kein Keychain-Wert):
   `keys --json` → Schema 1, Name, ID, Profile; `profile create gemini-demo --dir <tmp> --command "node index.js"` → ok;
   `profile bind gemini-demo GEMINI_API_KEY "prüfung gemini"` → ok (Groß/Klein-Fallback); `check` → `missing`, Exit 2;
   `bind … "gibt es nicht"` → `key_not_found`; erneutes `create` → `profile_exists`; `unbind … NOPE` → `variable_not_bound`;
   `profile frobnicate` → `invalid_arguments`; `keys` (Text) → „Prüfung Gemini<TAB>gemini-demo“; `profile delete` → `removed`;
   `profiles --json` → leer.

## Modus und Grenzen

Normaler CLI-Modus, Wegwerf-Konfiguration; kein echter Schlüsselbund-Eintrag beteiligt (Wertpfad belegt T012).
Kein CLI-Befehl setzt oder liest Werte (bewusst).
