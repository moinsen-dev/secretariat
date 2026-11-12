# Secretariat für Teams und Firmen – Business Case (2026-11-12)

Frage (Uli, 2026-11-12): Taugt Secretariat für Firmen mit mehreren Mitarbeitern und vielen Macs, und gibt es dafür einen Business Case?
Grundlage: `docs/research/2026-11-12-team-use.md` (Quellen und Kennzeichnung dort), Code-Stand 1.15.0, Logbook „Fokus – Portfolio 2026-11-10“.

## Kurzfassung

- **Heute schon tauglich** als Werkzeug *je Entwickler*: eigene Schlüssel, Agenten sehen keine Werte, Commit-Wächter, Verlauf. Eine Lizenz je Person deckt alle ihre Macs.
- **Nicht tauglich** als Team-Tresor: kein gemeinsames Teilen, keine Rollen, kein zentrales Audit, kein Offboarding, kein SSO. Ursache ist die Architektur: Werte liegen im iCloud-Schlüsselbund *je Apple Account*; Apples Passwort-Gruppen haben keine API für Dritte.
- **Markt:** Team-Secret-Manager gibt es günstig und reif (Bitwarden 6 $, 1Password 8,99 $, Phase 10 $ je Nutzer und Monat). Gegen sie einen eigenen Team-Tresor zu bauen, lohnt sich nicht.
- **Die Lücke, die bleibt:** Was passiert *auf dem Mac jedes Entwicklers*, wenn Coding-Agenten mitarbeiten. Dort ist Secretariat stark (Agent-Wächter, Maskierung, Werte-genauer Commit-Wächter, Sweep, Erfassen per Kurzbefehl/Screenshot, Login ausfüllen). Diese Schicht fehlt den Team-Tresoren weitgehend: `op run`/`bws run` liefern die Injektion (`op run` maskiert nach unserem Kenntnisstand auch die Ausgabe, nicht nachgeprüft), aber keinen Agent-Wächter, keinen Commit-Wächter mit echten Werten, keinen Sweep und kein Erfassen.
- **Empfehlung:** Kein Team-Tresor. Positionierung „Agenten-Leitplanke auf jedem Entwickler-Mac, neben eurem Team-Tresor“. Jetzt nur Billiges (Website-Antwort, Mengenlizenz auf Anfrage); Bauen erst nach echter Nachfrage.

## Was eine Firma heute bekommt

| Bedarf | Stand 1.15.0 |
|---|---|
| Persönliche Schlüssel je Entwickler, Agenten blind | Ja, Kern des Produkts |
| Verteilung auf viele Macs | Ja, notarisierte App; per MDM installierbar (Zip heute, `.pkg` wäre für MDM sauberer) |
| Voreinstellungen per MDM | Möglich über verwaltete Einstellungen; Secretariat liest sie heute nicht |
| Geteilte Schlüssel (Staging-DB, Stripe-Test) | Nein |
| Onboarding neuer Kollegen | Nur von Hand: jeder legt seine Schlüssel selbst an |
| Offboarding, Widerruf | Nein; Austritt heißt Rotation, Secretariat hilft nur mit `targets` (wo liegen Kopien) |
| Zentrales Audit | Nein; Verlauf liegt je Mac |
| SSO, SCIM, Rollen | Nein |
| Datenschutz | Stark: kein Server, keine Telemetrie, keine Firmendaten bei moinsen |

## Wo es passt und wo nicht

**Passt:** Mac-Agenturen und Freelancer-Kollektive mit 2–10 Entwicklern, die jeweils mit eigenen Schlüsseln arbeiten und Claude Code oder Codex einsetzen; Firmen, die einen Team-Tresor haben und für die Agenten-Arbeit eine lokale Leitplanke wollen; datenschutzsensible Kunden, die keine Schlüssel in fremde Clouds geben.

**Passt nicht:** gemischte Plattformen (Windows/Linux-Arbeitsplätze), SSO/SCIM-Pflicht, Audit- und Compliance-Vorgaben, zentral geteilte Produktionsschlüssel. Dort gewinnen 1Password, Bitwarden, Doppler, Infisical.

## Wege zu echtem Teilen (Bewertung)

| Weg | Urteil |
|---|---|
| A. Verschlüsselte Bundles je Empfänger (Datei) | Billigster Test, ob Teilen überhaupt gewünscht ist; ohne Widerruf und Audit |
| B. CloudKit-Freigabe (CKShare) | Riskant: Ende-zu-Ende nur mit Advanced Data Protection zugesagt, Besitzer als Engpass, kein Audit, verwaltete Accounts ungeklärt |
| C. Eigener verschlüsselter Sync-Server | Nein: laufende Kosten und Haftung, widerspricht „lokal, einmal zahlen“, direkte Konkurrenz zu Bitwarden |
| D. Team-Tresor als Quelle (`bws`/`op`/Infisical), Secretariat behält Wächter, Maskierung, Profile | Bester Weg, falls Nachfrage kommt: Rollen, Audit, Offboarding liefert der Anbieter; Secretariat bleibt die Agenten-Schicht |

## Zahlen

- Einzellizenz 39 € einmalig. Ein Team mit 10 Entwicklern zahlt 390 € einmal, Bitwarden Teams kostet dasselbe Team ca. 720 $ *pro Jahr*, 1Password ca. 1.079 $ pro Jahr.
- Ein Mengenpreis (Beispiel: ab 5 Lizenzen 29 € je Person) bringt je Team 145–290 €. Für 20.000 € Umsatz im Jahr wären das rund 70–140 Teams. Das ist bei einem kleinen, besetzten Markt viel.
- Ein Team-Abo (z. B. 3–4 € je Person und Monat für Weg D und zentrale Richtlinien) würde je 10er-Team 360–480 € im Jahr bringen, bricht aber mit dem Versprechen „Pay once“. Nur sinnvoll, wenn Firmen ausdrücklich danach fragen.
- **Belegte Nachfrage heute: keine.** Laut Fokus vom 10.11. hat noch kein Mensch „würde zahlen: ja“ gesagt, auch nicht für die Einzelversion; der Live-Verkauf wartet auf Lemon Squeezy.

## Empfehlung

1. **Jetzt (erledigt, reversibel):** Website beantwortet „Can my team use it?“ ehrlich: je Entwickler ja, Team-Tresor nein, neben 1Password/Bitwarden; ab 5 Lizenzen Anfrage per Mail.
2. **In den geplanten Gesprächen** (Fokus bis 22.11.) zusätzlich fragen: Arbeitest du im Team? Wo liegen geteilte Schlüssel heute? Würde dein Team Secretariat neben dem Team-Tresor einsetzen, und wer zahlt?
3. **Erst bauen, wenn mindestens drei Teams fragen:** Mengenlizenz im Shop, `.pkg` und MDM-Anleitung, dann Weg D mit dem meistgenannten Tresor.
4. **Abbruch:** Fragt bis Ende Q1 2027 kein Team nach, bleibt Secretariat ein Werkzeug für einzelne Entwickler; die Website-Antwort bleibt.

Offene Punkte (ungeprüft): CloudKit mit verwalteten Apple Accounts; Preis von 1Password Service Accounts.
