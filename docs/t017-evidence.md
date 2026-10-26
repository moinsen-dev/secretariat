# T017 – key rename (Build 0d4aefd)

- unit: renameRewritesTheSyncedLabelAndOtherMacsTakeItOver, keyRenameKeepsBindingsAndRejectsUnknownOrDuplicateNames grün; 32/32.
- macos (echt): auf dem M4 `key rename "Adventurist CF Access Client ID" moinsen/cloudflare/access-routing-client-id` und dasselbe für das Secret. `keys` zeigt die neuen Namen mit Profil menulens-worker, `check` ok. Nach ≤ 30 s zeigen Mini und M1 per `keys` die neuen Namen (iCloud-Abgleich; damit ist der Abgleich auch für den M1 belegt).
- Grenze: M5 offline, dort 0.4.0 und Abgleich nicht beobachtet.
