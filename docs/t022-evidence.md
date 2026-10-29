# T022 – Verschlüsselte Screenshots mit Notiz (Nachweis)

Stand: Commit 4e1f607 (Funktion cc0ef1a, iCloud 4e1f607), signiertes `dist/Secretariat.app` (Version noch 1.10.1), 2026-10-29.

## Aufbau

- `ScreenshotLibrary` (Kern): je Screenshot `<uuid>.meta` (Titel, Notiz, Daten) und `<uuid>.image`, beide als `SCR1` + 16-stellige Schlüssel-ID + AES-GCM-Box. Schlüssel (256 Bit) im synchronisierten Data-Protection-Schlüsselbund, Dienst `dev.moinsen.secretariat.screenshots.v1`, Zugriffsgruppe `VXX45ZYNM8.dev.moinsen.secretariat.local`. Neue Dateien nehmen den Schlüssel mit der kleinsten ID, ältere Schlüssel bleiben lesbar.
- Ort: echter Tresor → iCloud-Drive-Container `iCloud.dev.moinsen.secretariat/Screenshots` (nicht öffentlich, nicht im Finder unter iCloud Drive sichtbar); ohne Container lokal mit Hinweis; Test-Tresore immer lokal mit eigenem Schlüssel-Namensraum.
- Portal: Container gab es schon im Team; App-ID `dev.moinsen.secretariat.local` (QV5F64Q5WH) bekam iCloud (CloudKit-Unterstützung) mit diesem Container. Neues Profil „Secretariat Developer ID iCloud“ (3K78A53XK8, MAC_APP_DIRECT, Zertifikat SYJHH4VJAC, bis 2031-05-03) mit `icloud-container-identifiers`, `ubiquity-container-identifiers`, `icloud-container-environment = Production`, weiterhin `keychain-access-groups`. Das alte Profil K5DH7AFW73 ist damit ungültig; installierte Apps tragen ihre eingebettete Kopie.

## Schritte und Beobachtung

| Schritt | Erwartung | Beobachtung |
|---|---|---|
| `xcrun swift test` | grün | 61/61, darunter 4 neue: Rundlauf ohne Klartext auf der Platte; Dateien eines zweiten Macs mit dessen Schlüssel lesbar, ohne ihn als „unreadable“ gezählt; falscher Schlüssel, Manipulation, leeres und >25-MB-Bild abgewiesen; iCloud-Platzhalter als „pending“, Test-Tresore lokal |
| Test-Tresor, GUI | Hinzufügen, Vorschau, Notiz, Neustart, Löschen | File › New Screenshot from Clipboard … (künstliches Bild), Titel und Notiz, gespeichert; Platte: nur `SCR1…` mit UUID-Namen, `grep` findet weder Titel, Notiz noch „PNG“; Notiz ergänzt und gespeichert; nach Neustart Bild und geänderte Notiz da; Löschen (damals ohne Rückfrage, jetzt mit „Delete screenshot?“) |
| CLI | nichts außer Zahlen | `items`/`status` enthalten keine Screenshot-Daten; `screenshots` nennt nur Anzahl, Ort, unterwegs, unlesbar; `screenshots clear` nur im Test-Tresor, im echten Tresor `app_only` |
| Signierter Build mit iCloud | App startet, Container erreichbar | `codesign` zeigt die iCloud-Entitlements; `screenshots` → „0 screenshots (icloud)“; `~/Library/Mobile Documents/iCloud~dev~moinsen~secretariat` vorhanden |
| Zwei Macs | Screenshot vom M4 auf dem Mini lesbar | M4 (echter Tresor): künstliches Testbild „Sync-Test Claude“ gespeichert → M4 `1 screenshots (icloud)`. Gleiches Paket in einen Testordner auf dem Mini kopiert (Signatur ok): `1 screenshots (icloud), 0 downloading, 0 unreadable`, Dateien im Container des Minis vorhanden – Datei per iCloud Drive und Schlüssel per iCloud-Schlüsselbund angekommen |
| Löschen synchronisiert | Mini sieht nichts mehr | Löschen mit Rückfrage auf dem M4 → nach ~8 s M4 und Mini `0 screenshots`; Testordner auf dem Mini in den Papierkorb |
| Regression | unverändert grün | `script/regression_cli.sh` 24/24 |

Zwischenablage: vor jedem Test gesichert und danach wiederhergestellt (`cmp` gleich).

## Nachprüfung nach Kritik (`docs/review-uc17.md`, REWORK)

Behoben: AES-GCM bindet jede Datei an „<uuid>.<meta|image>“ (AAD); Lesen/Schreiben/Löschen über NSFileCoordinator, iCloud-Konfliktversionen zugunsten der aktuellen aufgelöst; Änderungen nennen den bearbeiteten Stand und werden bei neuerer Änderung eines anderen Macs abgewiesen (`ScreenshotError.changedElsewhere`), die Detailansicht baut sich bei jeder Änderung neu auf; lokal gespeicherte Screenshots ziehen in den iCloud-Container um, sobald er verfügbar ist; Vollbild wird abseits des Hauptthreads entschlüsselt, „lädt noch aus iCloud“ statt endlosem Spinner; Vorschaubilder sind gerenderte Kopien statt Verweise aufs Vollbild; „Copy Image“ markiert `org.nspasteboard.ConcealedType` und leert nach 60 s; nach dem Speichern aus der Zwischenablage wird diese geleert; `screenshots` zählt jetzt auch entschlüsselbare Bilder.

Erneut geprüft (Build mit diesen Änderungen, 2026-10-29 ~16:25):

| Schritt | Beobachtung |
|---|---|
| `xcrun swift test` | 62/62, dreimal hintereinander grün (neuer Test: veraltete Bearbeitung abgewiesen, vertauschte Datei unlesbar, `verify`, Umzug lokal → Container). Ein einzelner Lauf davor zeigte `setup_busy` im bestehenden Setup-Test (paralleler Testlauf), danach nicht mehr |
| Test-Tresor | Speichern aus der Zwischenablage → Zwischenablage danach 0 Bytes; Bild lädt; „Copy Image“ → Typen `public.tiff, org.nspasteboard.ConcealedType` |
| Echter Tresor, zwei Macs | M4: Testbild gespeichert → `1 screenshots (icloud), 1 images readable`; Mini (Paket in Testordner): `imagesReadable: 1, unreadable: 0` – Bild selbst auf dem zweiten Mac entschlüsselt |
| Leeren und Löschen | „Copy Image“, nach 62 s keine Typen mehr in der Zwischenablage; Löschen mit Rückfrage → M4 und Mini `0 screenshots`; Testordner auf dem Mini in den Papierkorb, Zwischenablage wiederhergestellt |
| Regression | `script/regression_cli.sh` 24/24 |

## Grenzen

- Ablegen einer Bilddatei und „Choose File …“ (Dateidialog) nicht über die Hintergrundsteuerung ausgelöst; der Weg über die Zwischenablage nutzt dieselbe Speicherung.
- Export und „Copy Image“ nicht ausgelöst.
- iCloud Drive muss auf dem Mac eingeschaltet sein; sonst zeigt die App „Only on this Mac“.
- Die Installation auf M1/Mini/M5 erfolgt erst mit dem nächsten Release.
