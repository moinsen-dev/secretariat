# Kaufen in Safari (2026-11-14)

Anlass: Polars gehosteter Checkout zeigt Apple Pay nur in Safari auf einem Apple-Gerät mit eingerichtetem Apple Pay (Polar-Doku „Payment Methods“; bei Polar ist nichts einzustellen). Kajuto öffnet seinen Checkout seit 2026-11-14 in Safari, der erste echte Kauf mit Apple Pay lief. Uli: „Ja, Secretariat auch“.

## Änderung

- `Checkout.open(_:)` (`Sources/Secretariat/Checkout.swift`): sucht Safari über die Bundle-ID `com.apple.Safari`, öffnet die Adresse dort mit `NSWorkspace.open(_:withApplicationAt:configuration:)`; der Completion-Handler ist `@Sendable` und fällt bei einem Fehler über `Task { @MainActor in … }` auf den Standardbrowser zurück. Ohne Safari öffnet sofort der Standardbrowser. Vorlage: Kajuto `Checkout`.
- Einziger Kaufknopf der App („Buy License“ im Lizenzfenster) ruft `Checkout.open(Licensing.buyURL)` statt `openURL`. Die CLI gibt die Kaufadresse nur als Text aus, öffnet keinen Browser.
- Website: Kleingedrucktes unter dem Kaufknopf nennt „Apple Pay is available in Safari“.

## Prüfung

- `xcrun swift build`: grün, keine Warnung in den geänderten Dateien.
- `xcrun swift test`: 149 Tests grün (Regression; der Helfer liegt im App-Target und hat keinen eigenen Unit-Test).
- Lauf des Helfers (identischer Code, eigenständig mit `swiftc -swift-version 6` gebaut) mit `https://secretariat.moinsen.dev/buy`: Safari öffnete einen Tab; `osascript` las als Adresse des vorderen Tabs `https://polar.sh/checkout/polar_c_…` (die Kaufadresse leitet per 302 zu `buy.polar.sh` weiter). Tab danach geschlossen, nichts gekauft.

Einschränkungen: Der Knopf im Lizenzfenster erscheint nur ohne gültige Lizenz; den Klick in der echten Oberfläche habe ich nicht ausgelöst, er ruft nur `Checkout.open` auf. Ob Apple Pay im Checkout erscheint, hängt von Ulis Gerät ab (Apple Pay eingerichtet) und wurde hier nicht angesehen. Der Fallback-Zweig (Safari fehlt) ist nicht ausgeführt, nur gelesen.

## Kritik

Unabhängige Prüfung (Subagent, nur lesend): PASS. Keine weitere Stelle im App-Target öffnet die Kaufadresse; `@Sendable`-Handler und Rücksprung auf den MainActor korrekt; entferntes `openURL` war ungenutzt; PLAN-Zeilen passen zum Format. Übernommen: Website-Text vorsichtiger („is available in Safari“), PLAN nennt die Unit-Tests als Regression statt als eigenen Test.

Ältere Aufgaben, deren Dateien sich nur durch `Views.swift` (ein Aufruf im Lizenzfenster, ein entferntes ungenutztes `openURL`) änderten, wurden über diese Prüfungen neu gebunden.
