# T013–T015 – iCloud-Abgleich und Installation (0.3)

Zeit: 2026-10-26, M4 (macOS 27.0) und Mac Mini M4 (udi). Build: Commit 9c64dac, dist/Secretariat.app 0.3.0.

## T013 – App-ID und Profil

- `asc` (von Uli angemeldet, Name „moinsen“): App-ID `dev.moinsen.secretariat.local` (QV5F64Q5WH) angelegt; die Alt-ID
  `dev.moinsen.secretariat` bleibt unberührt. Profil „Secretariat Developer ID“ (K5DH7AFW73, MAC_APP_DIRECT, Zertifikat
  Developer ID G2 SYJHH4VJAC, aktiv bis 2031-05-03).
- Profil erlaubt `com.apple.application-identifier = VXX45ZYNM8.dev.moinsen.secretariat.local`,
  `keychain-access-groups = VXX45ZYNM8.*`. Build bettet es als `embedded.provisionprofile` ein und signiert mit
  Resources/Secretariat.entitlements; `codesign -d --entitlements` zeigt die drei Schlüssel; App startet (`--version`).
  Gatekeeper: „Unnotarized Developer ID“ wie bei 0.2 (Notarisierung nicht beauftragt).

## T014 – Abgleich (echter iCloud-Schlüsselbund, zwei Macs)

1. `swift test`: 28/28 (5 neue: neue Werte synchronisiert mit Namen; Altwert lesbar und verlustfrei übernommen, Wiederholung
   ohne Wirkung; Import fremder Schlüssel einmalig, Namenskonflikt → Suffix; ohne Entitlement alles lokal; Test-Homes nie im
   echten Namensraum).
2. M4, App normal bedient (Wegwerf-Home /tmp/secretariat-sync-test, isolierter Test-Namensraum): Schlüssel „Prüfung Sync“
   mit künstlichem Wert gespeichert. CLI: keys zeigt ihn, Profil per CLI, check available, run übergibt korrekten Wert.
3. Mini (Sync-Build installiert, gleicher Home-Pfad): Schlüssel nach ≤ 10 s mit gleicher ID und Namen in `keys --json`;
   Profil per CLI angelegt und gebunden; check available; run über SSH ohne Dialog → Wert stimmt.
4. Löschen auf dem M4 (Sync-Fixture, nur Test-Namensräume): Mini meldet nach ~10 s `missing`, run Exit 1, Ziel nicht gestartet.
5. Übernahme (R016): künstlicher Altwert im Login-Schlüsselbund (Fixture-Helfer, wie 0.2), App gestartet → Eintrag im
   synchronisierten Speicher, Login-Eintrag weg (security exit 44), run mit korrektem Wert; kein Dialog.
6. Regression mit diesem Build: Paket-Prozessprüfungen alle true, verweigerter Zugriff Exit 2 (0,02 s) ohne Start, Claude mit
   vorbereitetem Profil passed, Claude selbst verdrahtet passed (keine .env, kein Wert in Ausgabe).
7. Aufräumen: alle Test-Einträge in iCloud und Login-Schlüsselbund entfernt (Listen leer); echte Schlüssel unverändert (0).

## T015 – Installation

`~/Applications/Secretariat.app` und `~/bin/secretariat` auf M4 (install.sh), M1 (doedel), M5, Mac Mini (tar über SSH):
überall 0.3.0, `codesign --verify --strict` ok, `keys --json` ohne Fehler (Entitlement greift), keine neuen LaunchAgents.

## Grenzen

- Namenskonflikt nur per Unit-Test, nicht mit zwei echten Macs gleichzeitig.
- Zweit-Mac-Beleg nur mit dem Mini; M1 (Benutzer doedel) und M5 sind installiert, aber ob dort derselbe Apple-Account mit
  iCloud-Schlüsselbund aktiv ist, zeigt erst ein echter Schlüssel.
- Auf dem Mini existiert ein fremder Alt-LaunchAgent `dev.moinsen.secretariat` (10.06., Exit 1) aus dem Legacy-Projekt; unverändert.
- Selbst ausgeführt.
