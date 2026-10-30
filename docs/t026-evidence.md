# T026 – Automatische verschlüsselte Sicherung (Nachweis)

Stand: e816552 (nach der ersten Kritikrunde), signiertes `dist/Secretariat.app` aus `script/build.sh`, App gestartet mit `SECRETARIAT_HOME=/private/tmp/claude-501/backup-test2/home` (Test-Tresor, Sicherungen lokal), macOS 27.0, 2026-10-30. Alle Werte künstlich.

## Aufbau

- Wiederherstellungsschlüssel: 32 Zufallsbytes + 2 Prüfbytes (SHA-256), 11 Blöcke à 5 Zeichen Crockford-Base32; Groß-/Kleinschreibung, Leerzeichen, O/I/L egal; Tippfehler fällt an den Prüfbytes auf.
- Schlüsselpaar per HKDF-SHA256 aus dem Schlüssel (Curve25519); auf dem Mac nur der öffentliche Schlüssel (synchronisierter Schlüsselbund, eigener Dienst je Tresor-Namensraum). Der Mac kann sichern, aber keine Sicherung lesen.
- Datei: Zeile 1 JSON-Kopf (Zeit, Mac-Name, zufällige Mac-Kennung, Schlüssel-Kennung, Anzahl, gekapselter Schlüssel) als AAD; Zeile 2 HPKE-versiegelter Inhalt (Curve25519_SHA256_ChachaPoly). Rechte 0600, Temp-Datei außerhalb des iCloud-Containers, koordiniert verschoben.
- Automatisch: App bei jedem Laden/Zurückkehren und nach Änderungen; CLI einmal am Tag. Neu gesichert wird, wenn ein HMAC (lokaler Zufallsschlüssel) über den ganzen Inhalt samt Werten sich geändert hat oder heute noch keine Sicherung da ist.
- Wiederherstellen: Vorschau der hinzukommenden Teile, nur Fehlendes, Pfade ohne Groß-/Kleinschreibung verglichen, Teilfehler gesammelt, Datum der Wertänderung bleibt; ohne eingerichtete Sicherung wird der eingegebene Schlüssel übernommen.

## Schritte und Beobachtung (UC21)

| Schritt | Erwartung | Beobachtung |
|---|---|---|
| (1) Test-Tresor per CLI: Eintrag `acme/demo/api` mit Geheimnis und Datei, Profil `demo`, Ziel `demo-target`, Vorlage `demo-kind`; Backup öffnen | „nicht eingerichtet“ | „Backup isn't set up“, Seitenleiste „Backup · Off“, CLI „Backup isn't set up …“ |
| (2) Einrichten | Schlüssel in Blöcken, Bestätigung zweier zufälliger Blöcke, danach automatisch eine Sicherung | Blatt zeigt 11 Blöcke, verlangt z. B. Block 4 und 10; mit falschem Block 10 bleibt „Turn On Backup“ gesperrt; „Cancel“ speichert keinen Schlüssel (danach weiter „not set up“); neues Blatt, Block 3 und 11 (11 klein geschrieben) → „Backup is on“, Datei `2026-10-30-udi-m4-9494fa9e.secretariat-backup` ohne weiteren Klick, Liste rechts mit Datum und Mac |
| Kein Klartext | keine Werte, keine Eintragsnamen | `grep -c` in der Datei: Wert 0, `acme` 0, `demo` 0, `DEMO_API_KEY` 0, Zertifikatstext 0, `demo-target` 0, `Demo kind` 0. Kopf: nur Zeit, `udi-m4`, Mac-Kennung, Schlüssel-Kennung, Anzahl 1 |
| (3) Wert per CLI ändern (`import --replace`), Backup erneut anzeigen | Tagesdatei ersetzt | 1 Sekunde nach dem Import `backup` im Protokoll (Herkunft App), Datei-Hash geändert (d565…→4143…), weiterhin eine Datei |
| (3) CLI | Stand, `backup now`, nie Schlüssel | „Backup on (key 2c44d59b3c3f), on this Mac only: 1 files, last from this Mac …“; „Backup written: …“; `backup setup` → Hinweis, das passiert in der App; JSON ohne Schlüsselmaterial |
| (4) Öffnen der echten Datei mit dem in der App angezeigten Schlüssel | Inhalt vollständig | Probe (nicht eingecheckt): Kopf `udi-m4 / 9494fa9e / 1 / 2c44d59b3c3f`, geänderter Wert byte-genau gleich, Zertifikat da, Profil `demo`, Ziel `demo-target`, Vorlage `demo-kind`; anderer Schlüssel → `AgentError` |
| Unit-Tests `xcrun swift test` | grün | 93/93 (dreimal). Darin: Schlüssel lesbar, Tippfehler/fehlendes Zeichen/Unsinn abgelehnt; versiegelte Datei ohne Klartext, 0600; falscher Schlüssel `backup_wrong_key`; geänderter Kopf oder Inhalt `backup_damaged`; je Mac-Kennung 30 Dateien auch bei ähnlichen und gleichen Mac-Namen, iCloud-Platzhalter mitgezählt; automatisch nur bei Änderung, auch wenn sich nur ein Wert ändert; Warnungen (nicht gesichert, älter als 2 Tage, letzter Versuch gescheitert); gesperrter Schlüsselbund bricht ab und lässt die gute Datei stehen; Wiederherstellen mit Vorschau, nur Fehlendes, Datum bleibt, Pfad in anderer Schreibweise übersprungen, Rest kommt zurück; Schlüssel prüfen; Sicherungen mit altem Schlüssel löschen; CLI ohne Schlüssel |

## Nicht in der App durchgespielt

- **„Schlüssel prüfen“ und „Wiederherstellen …“**: beide nehmen den Schlüssel in einem verdeckten Feld entgegen; dort tippt das Prüfwerkzeug aus Sicherheitsgründen nicht. Die Logik dahinter (`Backup.matches`, `Backup.open`, `Backup.additions`, `Backup.restore`) ist per Unit-Test und an der echten Datei belegt; der Klickweg in der App braucht einen Menschen.
- **Notfallblatt sichern** (Sicherungsdialog von macOS) nicht geklickt.
- **iCloud-Ablage**: Der Test-Tresor sichert immer lokal. Der echte Tresor nutzt den Container `iCloud.dev.moinsen.secretariat/Backups`; geprüft wird das mit der installierten App.
- Screenshot-Schlüssel nur per Unit-Test (Test-Tresor hat keine Screenshots).
