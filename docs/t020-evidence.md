# T020 – Geführter Eintrags-Dialog (Build 682215f)

- Anlass: Uli fand Pfad/Art/Herkunft/Läuft ab und freie Feldzeilen verwirrend; sein DeepSeek-Schlüssel landete unter Pfad „moinsen“ mit dem Variablennamen als Kennung, der OpenAI-Schlüssel scheiterte an „Es gibt schon einen Eintrag moinsen“.
- macos (echt, Testheim): Dialog zeigt „Was speicherst du?“ mit 8 Arten und Erklärung, darunter Anbieter (mit Auswahlliste), Zusatz, beschriftete Felder (Schlüssel *, Variablenname), Schalter „In allen Projekten und Werkzeugen nutzbar“, Ablage-Vorschau, „Erweitert“ eingeklappt, „Fehlt noch: …“ und gesperrtes Speichern (Screenshot geprüft).
- Reparatur (echt): moinsen/key_id entfernt, `field move moinsen/secret moinsen/deepseek/api_key`, env_var=DEEPSEEK_API_KEY, Profil werkzeuge bindet DEEPSEEK_API_KEY; `check werkzeuge` bereit. Wert verließ den Prozess nicht.
- build/unit: 32/32. 1.2.0 auf M4, Mini, M1, M5.

## Nachtrag 1.2.1 (Build 6598dc9)

- Doppelklick auf einen Eintrag öffnet „Eintrag bearbeiten“ (echt per Mausereignis in einer Testinstanz, Screenshot geprüft); Rechtsklick-Menü „Bearbeiten …/Löschen …“; Entf-Taste; „Löschen“ im Detailkopf und im Bearbeiten-Dialog, jeweils mit Rückfrage. 32/32, 1.2.1 auf allen Macs.
- Massenübernahme ausgeführt: 283 Werte übernommen, 13 schon vorhanden, 10 Kennungen, 146 Profile (alle `check` bereit), 209 Einträge auf allen Macs; Profil werkzeuge mit 18 Variablen bereit.

## Nachtrag 1.3.0 (Build 695e61a)

- Auf Wunsch von Uli komplett englisch: App, CLI-Ausgaben, Fehlermeldungen, Hilfe, Projektanweisungen, Prüfliste, Sitzungshinweis. Fehlercodes, JSON-Schlüssel und Statuswerte unverändert; `usedBy` nennt Ziele jetzt `target:NAME`. 32/32; Dialog „Add Item“ per Screenshot geprüft; 1.3.0 auf allen Macs, `check werkzeuge` ready.

## Nachtrag 1.3.1 (Build 0980775)

- Suche in der Werkzeugleiste (⌘F) filtert gleichzeitig Einträge (Pfad, Art, Herkunft, Feldname/-bezeichnung, Kennungswert), Profile in der Seitenleiste (Name, Ordner, Variablen, zugeordnete Einträge) und Ziele; Trefferzahl über der Liste. Echt per Tastaturereignis in einer Testinstanz geprüft: „openai“ → 1 von 2 Einträgen, 1 Profil (Screenshot). 32/32, 1.3.1 auf allen Macs.

## Nachtrag 1.4.1 (Build ee067a8)

- Neue Art „Company“ (Organisation → `<org>/company`, Standard `moinsen/company`) mit Impressumsfeldern; Secretariat schreibt daraus `~/.claude/rules/company.md` (immer geladen, ohne Werte → Hinweis „Not set up yet“). Dialog per Screenshot geprüft (Organisation vorbelegt, Ablage moinsen/company, Pflichtfelder markiert). Test companyRuleListsIdentityAndNamesWhatIsMissing; 33/33.
- Build-Skript nutzt `xcrun swift`, weil eine swiftly-Toolchain im PATH vor Xcode stand (CryptoKit fehlte).

## Nachtrag 1.5.0 (Build 0e7cacb)

- Vorlagen sind Daten: synchronisierte Schlüsselbund-Einträge (eigener Dienst), in der App unter „Templates“ bearbeitbar (anlegen, Felder mit Bezeichnung/Art/Pflicht/Platzhalter/Env-Endung, Reihenfolge, ausblenden/wiederherstellen eingebauter, zurücksetzen) und per CLI (`template list|show|create|set|field add/remove|delete|reset`). Art eines Eintrags = Vorlagen-ID (Text); unbekannte Vorlage → Eintrag mit schlichten Feldnamen. company.md über Vorlagen-Merkmal „identity“. Migrationsprogramm 0.x entfernt.
- Geprüft: Test templatesAreDataUsersCanExtendHideAndReset; 34/34; Vorlagenliste und Editor per Screenshot im Testheim mit echtem Schlüsselbund (danach aufgeräumt); echte Daten nach Installation: moinsen/company als Company erkannt, company.md unverändert, werkzeuge ready, 211 Einträge. 1.5.0 auf M4, M1, Mini.

## Nachtrag 1.6.0 Agent Guard (Build f89c452)

- Ausgabe-Maskierung: `run` ersetzt Geheimniswerte des Profils in stdout/stderr, sobald die Ausgabe nicht an ein Terminal geht (Agent/Pipe); Werte über Lesegrenzen hinweg (Test maskerReplacesValuesEvenWhenSplitAcrossReads). Echt geprüft: Ausgabe „key is [masked test/guard/api_key]“, `--no-mask` zeigt den Wert, Exit-Code 7 durchgereicht.
- Freigabe: Einträge mit Freigabe brauchen Touch ID/Passwort vor run/push/inject; Agenten können sie nur einschalten (Test approvalItemsNeedConfirmationForRunPushAndInject). Echter Touch-ID-Dialog nicht automatisiert geprüft (braucht Ulis Finger).
- Git-Sperre: `guard install/uninstall/check`; echter Commit mit bekanntem Wert blockiert (leak.env:1, nur Name), sauberer Commit läuft; Prüfung über 211 echte Einträge 0,15 s. Installation in Ulis Repos bleibt Ulis Befehl.
- Nebenbefund behoben: Test-Namensraum wechselte zwischen erstem und zweitem Schreiben (/private-Kürzung); Test testNamespaceStaysTheSameBeforeAndAfterTheFolderExists. 40/40.
