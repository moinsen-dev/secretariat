# Secretariat – Design

Stand 2026-11-12. Leitbild (Uli): Secretariat soll aussehen und sich anfühlen wie eine Apple-App auf macOS 26/27 mit Liquid Glass.
Vorbilder: **Erinnerungen** (Seitenleiste mit Kacheln und Listen), **Notizen** (Liste und Inhalt), **Passwörter** (Neuer Eintrag).

## Grundsätze

1. **Das System macht das Glas.** Standardbausteine (`NavigationSplitView`, Symbolleiste, Sheets, `Form(.grouped)`, Menüs) bekommen
   Liquid Glass von selbst. Keine eigenen Hintergründe in Seitenleiste, Symbolleiste oder Sheets. Glas selbst nur sparsam und nur
   für eigene schwebende Bedienelemente (Apple HIG „Materials“: *Use Liquid Glass effects sparingly*).
2. **Gebaut mit aktuellem SDK.** Das Binary muss das echte SDK melden (`LC_BUILD_VERSION sdk 27.0`), sonst zeigt macOS die App im
   Kompatibilitätsaussehen. SwiftPM trägt sonst die Mindestversion ein; deshalb setzt `script/build.sh` `-platform_version` mit der echten SDK-Version (`xcrun --show-sdk-version`).
3. **Ein Gesicht je Art.** Jede Vorlage hat Symbol und Farbe; Liste, Detail und Editor zeigen sie als abgerundetes Farbquadrat
   mit weißem Symbol (`KindIcon`), wie Ordner und Listen in Apples Apps.
4. **Wenig Text, klare Fußnoten.** Erklärungen stehen als Fußnote unter dem Abschnitt, nicht als Absatz zwischen Feldern.
   Pflichtfelder sagen „Required“ im Platzhalter.
5. **Systemknöpfe.** In Sheets Abbrechen/Sichern über `.cancellationAction`/`.confirmationAction`, Löschen über `.destructiveAction`.

## Bausteine

| Fläche | Muster |
|---|---|
| Seitenleiste | Erinnerungen: 2×2 Kacheln (Farbkreis mit Symbol, Zahl oben rechts, Titel), darunter Projekte, Konten, Bibliothek; „Neues Projekt“ unten wie „Liste hinzufügen“ |
| Liste | Notizen: `KindIcon`, fetter Titel, darunter Datum und Art; Gruppen nach Konto |
| Detail | großes `KindIcon` und Titel oben, Felder in `Form(.grouped)`, Kopieren/Zeigen als randlose Symbole |
| Neuer Eintrag | Passwörter: Kopf mit großem `KindIcon` und Name als Titelzeile, Art als Menü, Felder als gruppierte Liste, „Weitere Optionen“ eingeklappt |
| Suche | in der Symbolleiste rechts (Standardplatz unter macOS 26/27) |
| Status (Probezeit) | unten in der Seitenleiste, kein Textknopf in der Symbolleiste |
| Badges | Text in Primärfarbe auf getönter Kapsel (Kontrast), nie Weiß auf Orange/Grün |
| Bedienungshilfe | jedes Symbolknopf- und Formularelement hat einen Namen (`accessibilityLabel`) |
