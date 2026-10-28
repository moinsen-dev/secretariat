# Aufgaben und Nachweise

## Tasks

| ID | Status | Evidence | Reason |
|---|---|---|---|
| T001 | ERLEDIGT | E019 | Betroffene Bestandsnachweise beim Abschluss von 0.2 abgleichen und erneuern |
| T002 | ERLEDIGT | E503,E504,E505 | Signiertes 0.2-Paket normal geöffnet; künstlicher Schlüsselwert via GUI und CLI-Prozess geprüft, Verweigerungsfall und Unit-/Buildchecks bestanden |
| T003 | ERLEDIGT | E506,E507 | Schlüssel und Profil im aktuellen GUI angelegt, geändert und gelöscht; In-use-Schutz, Bindung, Neustart und Unitvalidierung geprüft |
| T004 | ERLEDIGT | E508 | Aktueller Paketdurchlauf mit acht Prozesschecks und Unitprüfungen; Fehler vor Kindstart, Signal, I/O und Datenintegrität geprüft |
| T005 | ERLEDIGT | E509 | Aktueller GUI-Neustart, schmaler Leerzustand, kopierter Aufruf und vorhandenes DailyInspirations-Projekt mit künstlichem Wert: Expo HTTP 200; Testdaten entfernt |
| T006 | ERLEDIGT | E510,E511 | 0.2-Bundle entfernt und erneut installiert, Signatur/Hash/Symlink geprüft und neu installierte GUI geöffnet; Datenpfade unberührt |
| T007 | ERLEDIGT | E512,E513 | Versionierte CLI-Auskunft, Fehlercodes und dialogfreie Profilprüfung mit aktuellem Paket und Unitprüfungen bestanden |
| T008 | ERLEDIGT | E514,E515 | Projektanweisungen in normaler GUI mit Vorschau, Abbruch, Einrichten, Idempotenz, Neustart und Konfliktschutz geprüft |
| T009 | ERLEDIGT | E516 | Codex und Claude Code mit Receipt; OpenCode real versucht, ECONNRESET ohne Receipt als Grenze dokumentiert; künstliche Fixtures bereinigt |
| T010 | ERLEDIGT | E517,E518,E519,E520 | 0.2-App signiert lokal installiert, neue GUI und alte Kernabläufe samt Realprojekt geprüft; Testdaten entfernt, kein Autostart |
| T011 | ERLEDIGT | E521,E522 | - |
| T013 | ERLEDIGT | E525,E526 | App-ID + Developer-ID-Provisioning-Profil mit keychain-access-groups fehlt; Uli: asc auth login (Key T5YN77H557) oder Anlage im Developer-Portal |
| T014 | ERLEDIGT | E527,E528,E529 | - |
| T015 | ERLEDIGT | E530,E531 | - |
| T012 | ERLEDIGT | E523,E524 | - |
| T016 | ERLEDIGT | E532,E533,E534 | - |
| T017 | ERLEDIGT | E535,E536,E537 | - |
| T018 | ERLEDIGT | E538,E539,E540,E541 | - |
| T019 | ERLEDIGT | E542,E543,E544 | - |
| T020 | ERLEDIGT | E545,E546,E547 | - |

## Evidence

| ID | Task | Checks | Method | Mode | Date | Build | Fingerprint | Report | Result |
|---|---|---|---|---|---|---|---|---|---|
| E001 | T001 | inspection | inspection | normal | 2026-10-22T14:18:15+00:00 | archive-f7d31f9 | 8aedb304116fba3faf4b2a40 | docs/archive-evidence.md | PASS |
| E002 | T001 | inspection | inspection | normal | 2026-10-22T15:27:28+00:00 | archive-f7d31f9 | 0bf73bb831978319dac224c2 | docs/acceptance.md | PASS |
| E003 | T004 | unit | unit | normal | 2026-10-22T15:29:05+00:00 | e360dc03836bccdb | 0c75129276d9c7620d8d0585 | docs/acceptance.md | PASS |
| E004 | T005 | macos | ui | normal | 2026-10-22T15:29:05+00:00 | e360dc03836bccdb | b76c9cd562efd6f36f5de948 | docs/acceptance.md | PASS |
| E005 | T002 | build | build | normal | 2026-10-22T15:29:16+00:00 | e360dc03836bccdb | 300893b72d6268fc640ca36c | docs/acceptance.md | PASS |
| E006 | T002 | unit | unit | normal | 2026-10-22T15:29:16+00:00 | e360dc03836bccdb | 300893b72d6268fc640ca36c | docs/acceptance.md | PASS |
| E007 | T002 | macos | ui | normal | 2026-10-22T15:29:16+00:00 | e360dc03836bccdb | 300893b72d6268fc640ca36c | docs/acceptance.md | PASS |
| E008 | T003 | macos | ui | normal | 2026-10-22T15:29:17+00:00 | e360dc03836bccdb | dd415f1941329d183583c7a7 | docs/acceptance.md | PASS |
| E009 | T003 | unit | unit | normal | 2026-10-22T15:29:17+00:00 | e360dc03836bccdb | dd415f1941329d183583c7a7 | docs/acceptance.md | PASS |
| E010 | T006 | inspection | inspection | normal | 2026-10-22T15:29:17+00:00 | e360dc03836bccdb | ff24bdf2fc2fd9893bd5bc89 | docs/acceptance.md | PASS |
| E011 | T006 | macos | ui | normal | 2026-10-22T15:29:17+00:00 | e360dc03836bccdb | ff24bdf2fc2fd9893bd5bc89 | docs/acceptance.md | PASS |
| E012 | T007 | build | build | normal | 2026-10-23T07:06:00+00:00 | a4f33226e4a3b1f7 | 6d9c5776199045dd0b3797be | docs/agent-acceptance.md | PASS |
| E013 | T007 | unit | unit | normal | 2026-10-23T07:06:00+00:00 | a4f33226e4a3b1f7 | 6d9c5776199045dd0b3797be | docs/agent-acceptance.md | PASS |
| E014 | T008 | unit | unit | normal | 2026-10-23T07:06:00+00:00 | a4f33226e4a3b1f7 | 24e7fe351fd3b6c8a3145609 | docs/agent-acceptance.md | PASS |
| E015 | T009 | inspection | inspection | fixture | 2026-10-23T07:06:00+00:00 | a4f33226e4a3b1f7 | fe6c7d2d120d65eaa1d3b244 | docs/agent-acceptance.md | PASS |
| E016 | T010 | build | build | normal | 2026-10-23T07:06:05+00:00 | a4f33226e4a3b1f7 | e8b6129ed707d6e1f0ab2417 | docs/agent-acceptance.md | PASS |
| E017 | T010 | unit | unit | normal | 2026-10-23T07:06:05+00:00 | a4f33226e4a3b1f7 | e8b6129ed707d6e1f0ab2417 | docs/agent-acceptance.md | PASS |
| E018 | T010 | inspection | inspection | normal | 2026-10-23T07:06:05+00:00 | a4f33226e4a3b1f7 | e8b6129ed707d6e1f0ab2417 | docs/agent-acceptance.md | PASS |
| E019 | T001 | inspection | inspection | normal | 2026-10-23T07:07:01+00:00 | archive-f7d31f9 | 3d9ebcdb2d4b0f29337a5e50 | docs/agent-acceptance.md | PASS |
| E020 | T008 | macos | ui | normal | 2026-10-23T08:03:16+00:00 | a4f33226e4a3b1f7 | 24e7fe351fd3b6c8a3145609 | docs/agent-acceptance.md | PASS |
| E021 | T002 | macos | ui | normal | 2026-10-23T08:15:20+00:00 | a4f33226e4a3b1f7 | 9d0d6844ba4d941a0f75b90b | docs/agent-acceptance.md | PASS |
| E022 | T003 | macos | ui | normal | 2026-10-23T08:15:20+00:00 | a4f33226e4a3b1f7 | 881534fa9769976f62914fef | docs/agent-acceptance.md | PASS |
| E023 | T004 | unit | unit | normal | 2026-10-23T08:15:20+00:00 | a4f33226e4a3b1f7 | 0b275619e457ff0ab358f3ed | docs/agent-acceptance.md | PASS |
| E024 | T010 | macos | ui | normal | 2026-10-23T08:15:21+00:00 | a4f33226e4a3b1f7 | e8b6129ed707d6e1f0ab2417 | docs/agent-acceptance.md | PASS |
| E025 | T002 | build | build | normal | 2026-10-23T08:26:36+00:00 | a4f33226e4a3b1f7 | 9d0d6844ba4d941a0f75b90b | docs/agent-acceptance.md | PASS |
| E026 | T002 | unit | unit | normal | 2026-10-23T08:26:36+00:00 | a4f33226e4a3b1f7 | 9d0d6844ba4d941a0f75b90b | docs/agent-acceptance.md | PASS |
| E027 | T003 | unit | unit | normal | 2026-10-23T08:26:36+00:00 | a4f33226e4a3b1f7 | 881534fa9769976f62914fef | docs/agent-acceptance.md | PASS |
| E028 | T005 | macos | ui | normal | 2026-10-23T08:26:37+00:00 | a4f33226e4a3b1f7 | 303844b7e23f4685b176b476 | docs/agent-acceptance.md | PASS |
| E029 | T006 | inspection | inspection | normal | 2026-10-23T08:26:37+00:00 | a4f33226e4a3b1f7 | abbcc0a32f4c318b19bf07e2 | docs/agent-acceptance.md | PASS |
| E030 | T006 | macos | ui | normal | 2026-10-23T08:26:37+00:00 | a4f33226e4a3b1f7 | abbcc0a32f4c318b19bf07e2 | docs/agent-acceptance.md | PASS |
| E031 | T010 | inspection | inspection | normal | 2026-10-23T08:26:38+00:00 | a4f33226e4a3b1f7 | e8b6129ed707d6e1f0ab2417 | docs/agent-acceptance.md | PASS |
| E032 | T009 | inspection | inspection | normal | 2026-10-23T08:28:06+00:00 | a4f33226e4a3b1f7 | fe6c7d2d120d65eaa1d3b244 | docs/agent-acceptance.md | PASS |
| E033 | T011 | build | build | normal | 2026-10-26T11:30:47+00:00 | ce7cb30 | 6beaf44b17bf1eb40c2703af | docs/t011-evidence.md | PASS |
| E034 | T011 | unit | unit | normal | 2026-10-26T11:30:48+00:00 | ce7cb30 | 6beaf44b17bf1eb40c2703af | docs/t011-evidence.md | PASS |
| E035 | T012 | macos | ui | normal | 2026-10-26T11:30:48+00:00 | ce7cb30 | 309378aa37225e41281d1070 | docs/t012-evidence.md | PASS |
| E036 | T012 | inspection | inspection | normal | 2026-10-26T11:30:48+00:00 | ce7cb30 | 309378aa37225e41281d1070 | docs/t012-evidence.md | PASS |
| E037 | T011 | build | build | normal | 2026-10-26T11:30:57+00:00 | ce7cb30 | 93d00c9f1e0592643fc53b1a | docs/t011-evidence.md | PASS |
| E038 | T011 | unit | unit | normal | 2026-10-26T11:30:57+00:00 | ce7cb30 | 93d00c9f1e0592643fc53b1a | docs/t011-evidence.md | PASS |
| E039 | T012 | macos | ui | normal | 2026-10-26T11:30:57+00:00 | ce7cb30 | 60e95703484a8f34ee0db2d3 | docs/t012-evidence.md | PASS |
| E040 | T012 | inspection | inspection | normal | 2026-10-26T11:30:57+00:00 | ce7cb30 | 60e95703484a8f34ee0db2d3 | docs/t012-evidence.md | PASS |
| E041 | T002 | build | build | normal | 2026-10-26T11:33:53+00:00 | ce7cb30 | dda760c9dbd5d470f53a41b1 | docs/regression-0.3.md | PASS |
| E042 | T002 | macos | ui | normal | 2026-10-26T11:33:53+00:00 | ce7cb30 | dda760c9dbd5d470f53a41b1 | docs/regression-0.3.md | PASS |
| E043 | T002 | unit | unit | normal | 2026-10-26T11:33:54+00:00 | ce7cb30 | dda760c9dbd5d470f53a41b1 | docs/regression-0.3.md | PASS |
| E044 | T004 | unit | unit | normal | 2026-10-26T11:33:54+00:00 | ce7cb30 | ac474f08b0e06d0363134561 | docs/regression-0.3.md | PASS |
| E045 | T005 | macos | ui | normal | 2026-10-26T11:33:54+00:00 | ce7cb30 | 29baf21bdf107db72688a95e | docs/regression-0.3.md | PASS |
| E046 | T006 | inspection | inspection | normal | 2026-10-26T11:33:54+00:00 | ce7cb30 | 90026c4b228041c40a11a348 | docs/regression-0.3.md | PASS |
| E047 | T006 | macos | ui | normal | 2026-10-26T11:33:54+00:00 | ce7cb30 | 90026c4b228041c40a11a348 | docs/regression-0.3.md | PASS |
| E048 | T007 | build | build | normal | 2026-10-26T11:33:54+00:00 | ce7cb30 | 744fbae560be221e758dbd72 | docs/regression-0.3.md | PASS |
| E049 | T007 | unit | unit | normal | 2026-10-26T11:33:54+00:00 | ce7cb30 | 744fbae560be221e758dbd72 | docs/regression-0.3.md | PASS |
| E050 | T008 | macos | ui | normal | 2026-10-26T11:33:55+00:00 | ce7cb30 | 67e1ca81f377101a8c409397 | docs/regression-0.3.md | PASS |
| E051 | T008 | unit | unit | normal | 2026-10-26T11:33:55+00:00 | ce7cb30 | 67e1ca81f377101a8c409397 | docs/regression-0.3.md | PASS |
| E052 | T009 | inspection | inspection | normal | 2026-10-26T11:33:55+00:00 | ce7cb30 | 4af71b779eff06bd61a57182 | docs/regression-0.3.md | PASS |
| E053 | T010 | build | build | normal | 2026-10-26T11:33:55+00:00 | ce7cb30 | 7fc3ea3572a3072740937603 | docs/regression-0.3.md | PASS |
| E054 | T010 | inspection | inspection | normal | 2026-10-26T11:33:55+00:00 | ce7cb30 | 7fc3ea3572a3072740937603 | docs/regression-0.3.md | PASS |
| E055 | T010 | macos | ui | normal | 2026-10-26T11:33:55+00:00 | ce7cb30 | 7fc3ea3572a3072740937603 | docs/regression-0.3.md | PASS |
| E056 | T010 | unit | unit | normal | 2026-10-26T11:33:55+00:00 | ce7cb30 | 7fc3ea3572a3072740937603 | docs/regression-0.3.md | PASS |
| E057 | T013 | build | build | normal | 2026-10-26T12:23:45+00:00 | 9c64dac | c84ebfe9305fe25236e93ec0 | docs/t013-t015-evidence.md | PASS |
| E058 | T013 | inspection | inspection | normal | 2026-10-26T12:23:45+00:00 | 9c64dac | c84ebfe9305fe25236e93ec0 | docs/t013-t015-evidence.md | PASS |
| E059 | T014 | build | build | normal | 2026-10-26T12:23:45+00:00 | 9c64dac | e68f2e5af5a4a3b74b575284 | docs/t013-t015-evidence.md | PASS |
| E060 | T014 | unit | unit | normal | 2026-10-26T12:23:45+00:00 | 9c64dac | e68f2e5af5a4a3b74b575284 | docs/t013-t015-evidence.md | PASS |
| E061 | T014 | macos | ui | normal | 2026-10-26T12:23:45+00:00 | 9c64dac | e68f2e5af5a4a3b74b575284 | docs/t013-t015-evidence.md | PASS |
| E062 | T002 | build | build | normal | 2026-10-26T12:24:12+00:00 | 9c64dac | 1567434fcd36ca3241e9af25 | docs/regression-0.3-sync.md | PASS |
| E063 | T002 | unit | unit | normal | 2026-10-26T12:24:12+00:00 | 9c64dac | 1567434fcd36ca3241e9af25 | docs/regression-0.3-sync.md | PASS |
| E064 | T002 | macos | ui | normal | 2026-10-26T12:24:12+00:00 | 9c64dac | 1567434fcd36ca3241e9af25 | docs/regression-0.3-sync.md | PASS |
| E065 | T003 | macos | ui | normal | 2026-10-26T12:24:13+00:00 | 9c64dac | 6a61087f3a9ec62e0b337d73 | docs/regression-0.3-sync.md | PASS |
| E066 | T003 | unit | unit | normal | 2026-10-26T12:24:13+00:00 | 9c64dac | 6a61087f3a9ec62e0b337d73 | docs/regression-0.3-sync.md | PASS |
| E067 | T004 | unit | unit | normal | 2026-10-26T12:24:14+00:00 | 9c64dac | 5dd1e816bac6e794400fecde | docs/regression-0.3-sync.md | PASS |
| E068 | T005 | macos | ui | normal | 2026-10-26T12:24:14+00:00 | 9c64dac | 3985308f1780bf2e6d605331 | docs/regression-0.3-sync.md | PASS |
| E069 | T006 | inspection | inspection | normal | 2026-10-26T12:24:14+00:00 | 9c64dac | a7732a0eb20e3fcc5816031f | docs/regression-0.3-sync.md | PASS |
| E070 | T006 | macos | ui | normal | 2026-10-26T12:24:14+00:00 | 9c64dac | a7732a0eb20e3fcc5816031f | docs/regression-0.3-sync.md | PASS |
| E071 | T007 | build | build | normal | 2026-10-26T12:24:15+00:00 | 9c64dac | 6fba3ce47db154df3ddca334 | docs/regression-0.3-sync.md | PASS |
| E072 | T007 | unit | unit | normal | 2026-10-26T12:24:15+00:00 | 9c64dac | 6fba3ce47db154df3ddca334 | docs/regression-0.3-sync.md | PASS |
| E073 | T008 | unit | unit | normal | 2026-10-26T12:24:15+00:00 | 9c64dac | 9b83d8fe0b499f3dfc73108a | docs/regression-0.3-sync.md | PASS |
| E074 | T008 | macos | ui | normal | 2026-10-26T12:24:15+00:00 | 9c64dac | 9b83d8fe0b499f3dfc73108a | docs/regression-0.3-sync.md | PASS |
| E075 | T009 | inspection | inspection | normal | 2026-10-26T12:24:16+00:00 | 9c64dac | 806c431b3ff7da7623d7c926 | docs/regression-0.3-sync.md | PASS |
| E076 | T010 | build | build | normal | 2026-10-26T12:24:16+00:00 | 9c64dac | d903f23d3365799b26b7815d | docs/regression-0.3-sync.md | PASS |
| E077 | T010 | unit | unit | normal | 2026-10-26T12:24:16+00:00 | 9c64dac | d903f23d3365799b26b7815d | docs/regression-0.3-sync.md | PASS |
| E078 | T010 | macos | ui | normal | 2026-10-26T12:24:17+00:00 | 9c64dac | d903f23d3365799b26b7815d | docs/regression-0.3-sync.md | PASS |
| E079 | T010 | inspection | inspection | normal | 2026-10-26T12:24:17+00:00 | 9c64dac | d903f23d3365799b26b7815d | docs/regression-0.3-sync.md | PASS |
| E080 | T011 | build | build | normal | 2026-10-26T12:24:17+00:00 | 9c64dac | 9c6ea5d2d2af3bcb0fe8d88a | docs/t011-evidence.md | PASS |
| E081 | T011 | unit | unit | normal | 2026-10-26T12:24:18+00:00 | 9c64dac | 9c6ea5d2d2af3bcb0fe8d88a | docs/t011-evidence.md | PASS |
| E082 | T012 | macos | ui | normal | 2026-10-26T12:24:18+00:00 | 9c64dac | 59d54962f85df4e2ece70cc1 | docs/t012-evidence.md | PASS |
| E083 | T012 | inspection | inspection | normal | 2026-10-26T12:24:18+00:00 | 9c64dac | 59d54962f85df4e2ece70cc1 | docs/t012-evidence.md | PASS |
| E084 | T015 | macos | ui | normal | 2026-10-26T12:24:56+00:00 | 9c64dac | 3db68751422cee9d43fb20ab | docs/t013-t015-evidence.md | PASS |
| E085 | T015 | inspection | inspection | normal | 2026-10-26T12:24:56+00:00 | 9c64dac | 3db68751422cee9d43fb20ab | docs/t013-t015-evidence.md | PASS |
| E086 | T011 | build | build | normal | 2026-10-26T12:26:43+00:00 | 9c64dac | 9c6ea5d2d2af3bcb0fe8d88a | docs/regression-0.3-sync.md | PASS |
| E087 | T002 | build | build | normal | 2026-10-26T12:52:55+00:00 | f363f6e | 9b48beddb6317f59934fab12 | docs/regression-0.4.md | PASS |
| E088 | T002 | macos | ui | normal | 2026-10-26T12:52:55+00:00 | f363f6e | 9b48beddb6317f59934fab12 | docs/regression-0.4.md | PASS |
| E089 | T002 | unit | unit | normal | 2026-10-26T12:52:55+00:00 | f363f6e | 9b48beddb6317f59934fab12 | docs/regression-0.4.md | PASS |
| E090 | T004 | unit | unit | normal | 2026-10-26T12:52:56+00:00 | f363f6e | ae76355e34649f16d6d4305e | docs/regression-0.4.md | PASS |
| E091 | T005 | macos | ui | normal | 2026-10-26T12:52:56+00:00 | f363f6e | d552750ea35e7135cfcda2c3 | docs/regression-0.4.md | PASS |
| E092 | T006 | inspection | inspection | normal | 2026-10-26T12:52:57+00:00 | f363f6e | 998f4d370f3c023ecd7a9270 | docs/regression-0.4.md | PASS |
| E093 | T006 | macos | ui | normal | 2026-10-26T12:52:57+00:00 | f363f6e | 998f4d370f3c023ecd7a9270 | docs/regression-0.4.md | PASS |
| E094 | T007 | build | build | normal | 2026-10-26T12:52:57+00:00 | f363f6e | c323ec8426107849789dfe1f | docs/regression-0.4.md | PASS |
| E095 | T007 | unit | unit | normal | 2026-10-26T12:52:57+00:00 | f363f6e | c323ec8426107849789dfe1f | docs/regression-0.4.md | PASS |
| E096 | T008 | macos | ui | normal | 2026-10-26T12:52:58+00:00 | f363f6e | 6b9e3b3cfaf9f83ee68b6992 | docs/regression-0.4.md | PASS |
| E097 | T008 | unit | unit | normal | 2026-10-26T12:52:58+00:00 | f363f6e | 6b9e3b3cfaf9f83ee68b6992 | docs/regression-0.4.md | PASS |
| E098 | T009 | inspection | inspection | normal | 2026-10-26T12:52:58+00:00 | f363f6e | bee76cac51fe7e34787427a8 | docs/regression-0.4.md | PASS |
| E099 | T010 | build | build | normal | 2026-10-26T12:52:58+00:00 | f363f6e | 876db972c9d2dd9cb4f95e00 | docs/regression-0.4.md | PASS |
| E100 | T010 | inspection | inspection | normal | 2026-10-26T12:52:58+00:00 | f363f6e | 876db972c9d2dd9cb4f95e00 | docs/regression-0.4.md | PASS |
| E101 | T010 | macos | ui | normal | 2026-10-26T12:52:58+00:00 | f363f6e | 876db972c9d2dd9cb4f95e00 | docs/regression-0.4.md | PASS |
| E102 | T010 | unit | unit | normal | 2026-10-26T12:52:59+00:00 | f363f6e | 876db972c9d2dd9cb4f95e00 | docs/regression-0.4.md | PASS |
| E103 | T011 | build | build | normal | 2026-10-26T12:52:59+00:00 | f363f6e | c48c5158369a06bfaadfbae0 | docs/regression-0.4.md | PASS |
| E104 | T011 | unit | unit | normal | 2026-10-26T12:52:59+00:00 | f363f6e | c48c5158369a06bfaadfbae0 | docs/regression-0.4.md | PASS |
| E105 | T012 | inspection | inspection | normal | 2026-10-26T12:52:59+00:00 | f363f6e | d0f796f6da1097214e81a6cf | docs/regression-0.4.md | PASS |
| E106 | T012 | macos | ui | normal | 2026-10-26T12:53:00+00:00 | f363f6e | d0f796f6da1097214e81a6cf | docs/regression-0.4.md | PASS |
| E107 | T013 | build | build | normal | 2026-10-26T12:53:01+00:00 | f363f6e | 09e08592ec36508a3665c2c5 | docs/regression-0.4.md | PASS |
| E108 | T013 | inspection | inspection | normal | 2026-10-26T12:53:01+00:00 | f363f6e | 09e08592ec36508a3665c2c5 | docs/regression-0.4.md | PASS |
| E109 | T014 | build | build | normal | 2026-10-26T12:53:01+00:00 | f363f6e | e224f106d1e8ec673ca49706 | docs/regression-0.4.md | PASS |
| E110 | T014 | macos | ui | normal | 2026-10-26T12:53:01+00:00 | f363f6e | e224f106d1e8ec673ca49706 | docs/regression-0.4.md | PASS |
| E111 | T014 | unit | unit | normal | 2026-10-26T12:53:01+00:00 | f363f6e | e224f106d1e8ec673ca49706 | docs/regression-0.4.md | PASS |
| E112 | T015 | inspection | inspection | normal | 2026-10-26T12:53:02+00:00 | f363f6e | fcdf5623846569e70f3e4aac | docs/regression-0.4.md | PASS |
| E113 | T015 | macos | ui | normal | 2026-10-26T12:53:02+00:00 | f363f6e | fcdf5623846569e70f3e4aac | docs/regression-0.4.md | PASS |
| E114 | T016 | build | build | normal | 2026-10-26T12:53:11+00:00 | f363f6e | 1a807dfc916c7a0375d52f73 | docs/t016-evidence.md | PASS |
| E115 | T016 | unit | unit | normal | 2026-10-26T12:53:11+00:00 | f363f6e | 1a807dfc916c7a0375d52f73 | docs/t016-evidence.md | PASS |
| E116 | T016 | macos | ui | normal | 2026-10-26T12:53:11+00:00 | f363f6e | 1a807dfc916c7a0375d52f73 | docs/t016-evidence.md | PASS |
| E117 | T002 | build | build | normal | 2026-10-26T13:27:25+00:00 | 0d4aefd | f633be747344ae5f056cf8e3 | docs/regression-0.4.1.md | PASS |
| E118 | T002 | macos | ui | normal | 2026-10-26T13:27:25+00:00 | 0d4aefd | f633be747344ae5f056cf8e3 | docs/regression-0.4.1.md | PASS |
| E119 | T002 | unit | unit | normal | 2026-10-26T13:27:26+00:00 | 0d4aefd | f633be747344ae5f056cf8e3 | docs/regression-0.4.1.md | PASS |
| E120 | T003 | macos | ui | normal | 2026-10-26T13:27:26+00:00 | 0d4aefd | 0d3a8b5de01b4550824408a0 | docs/regression-0.4.1.md | PASS |
| E121 | T003 | unit | unit | normal | 2026-10-26T13:27:26+00:00 | 0d4aefd | 0d3a8b5de01b4550824408a0 | docs/regression-0.4.1.md | PASS |
| E122 | T004 | unit | unit | normal | 2026-10-26T13:27:27+00:00 | 0d4aefd | 4a74cb32e68018dbd43c6e95 | docs/regression-0.4.1.md | PASS |
| E123 | T005 | macos | ui | normal | 2026-10-26T13:27:27+00:00 | 0d4aefd | cf982848d0a450f1546bc4d1 | docs/regression-0.4.1.md | PASS |
| E124 | T006 | inspection | inspection | normal | 2026-10-26T13:27:28+00:00 | 0d4aefd | f21125efcb65f83c94501f1a | docs/regression-0.4.1.md | PASS |
| E125 | T006 | macos | ui | normal | 2026-10-26T13:27:28+00:00 | 0d4aefd | f21125efcb65f83c94501f1a | docs/regression-0.4.1.md | PASS |
| E126 | T007 | build | build | normal | 2026-10-26T13:27:29+00:00 | 0d4aefd | 36d44cac7e9de516c18de466 | docs/regression-0.4.1.md | PASS |
| E127 | T007 | unit | unit | normal | 2026-10-26T13:27:29+00:00 | 0d4aefd | 36d44cac7e9de516c18de466 | docs/regression-0.4.1.md | PASS |
| E128 | T008 | macos | ui | normal | 2026-10-26T13:27:30+00:00 | 0d4aefd | 5c1732eb6ff86da32676f626 | docs/regression-0.4.1.md | PASS |
| E129 | T008 | unit | unit | normal | 2026-10-26T13:27:30+00:00 | 0d4aefd | 5c1732eb6ff86da32676f626 | docs/regression-0.4.1.md | PASS |
| E130 | T009 | inspection | inspection | normal | 2026-10-26T13:27:30+00:00 | 0d4aefd | e3f56fed42a961d6d4c088ce | docs/regression-0.4.1.md | PASS |
| E131 | T010 | build | build | normal | 2026-10-26T13:27:31+00:00 | 0d4aefd | 21d75b0b48c3f69b4279ccc9 | docs/regression-0.4.1.md | PASS |
| E132 | T010 | inspection | inspection | normal | 2026-10-26T13:27:31+00:00 | 0d4aefd | 21d75b0b48c3f69b4279ccc9 | docs/regression-0.4.1.md | PASS |
| E133 | T010 | macos | ui | normal | 2026-10-26T13:27:31+00:00 | 0d4aefd | 21d75b0b48c3f69b4279ccc9 | docs/regression-0.4.1.md | PASS |
| E134 | T010 | unit | unit | normal | 2026-10-26T13:27:31+00:00 | 0d4aefd | 21d75b0b48c3f69b4279ccc9 | docs/regression-0.4.1.md | PASS |
| E135 | T011 | build | build | normal | 2026-10-26T13:27:32+00:00 | 0d4aefd | 9a014be280e454494a3f0bf6 | docs/regression-0.4.1.md | PASS |
| E136 | T011 | unit | unit | normal | 2026-10-26T13:27:32+00:00 | 0d4aefd | 9a014be280e454494a3f0bf6 | docs/regression-0.4.1.md | PASS |
| E137 | T012 | inspection | inspection | normal | 2026-10-26T13:27:33+00:00 | 0d4aefd | d33a7e52703acfbf5bd7271a | docs/regression-0.4.1.md | PASS |
| E138 | T012 | macos | ui | normal | 2026-10-26T13:27:33+00:00 | 0d4aefd | d33a7e52703acfbf5bd7271a | docs/regression-0.4.1.md | PASS |
| E139 | T013 | build | build | normal | 2026-10-26T13:27:34+00:00 | 0d4aefd | d5c42383324963c4fc591ea2 | docs/regression-0.4.1.md | PASS |
| E140 | T013 | inspection | inspection | normal | 2026-10-26T13:27:34+00:00 | 0d4aefd | d5c42383324963c4fc591ea2 | docs/regression-0.4.1.md | PASS |
| E141 | T014 | build | build | normal | 2026-10-26T13:27:35+00:00 | 0d4aefd | 3192c8d99146db6da1fa782c | docs/regression-0.4.1.md | PASS |
| E142 | T014 | macos | ui | normal | 2026-10-26T13:27:35+00:00 | 0d4aefd | 3192c8d99146db6da1fa782c | docs/regression-0.4.1.md | PASS |
| E143 | T014 | unit | unit | normal | 2026-10-26T13:27:35+00:00 | 0d4aefd | 3192c8d99146db6da1fa782c | docs/regression-0.4.1.md | PASS |
| E144 | T015 | inspection | inspection | normal | 2026-10-26T13:27:36+00:00 | 0d4aefd | 145f09a096a24d0048110688 | docs/regression-0.4.1.md | PASS |
| E145 | T015 | macos | ui | normal | 2026-10-26T13:27:36+00:00 | 0d4aefd | 145f09a096a24d0048110688 | docs/regression-0.4.1.md | PASS |
| E146 | T016 | build | build | normal | 2026-10-26T13:27:37+00:00 | 0d4aefd | 370ae1dd473a6e6d3e20e4e2 | docs/regression-0.4.1.md | PASS |
| E147 | T016 | macos | ui | normal | 2026-10-26T13:27:37+00:00 | 0d4aefd | 370ae1dd473a6e6d3e20e4e2 | docs/regression-0.4.1.md | PASS |
| E148 | T016 | unit | unit | normal | 2026-10-26T13:27:37+00:00 | 0d4aefd | 370ae1dd473a6e6d3e20e4e2 | docs/regression-0.4.1.md | PASS |
| E149 | T017 | build | build | normal | 2026-10-26T13:27:48+00:00 | 0d4aefd | e627b403d7af54f878161686 | docs/t017-evidence.md | PASS |
| E150 | T017 | unit | unit | normal | 2026-10-26T13:27:48+00:00 | 0d4aefd | e627b403d7af54f878161686 | docs/t017-evidence.md | PASS |
| E151 | T017 | macos | ui | normal | 2026-10-26T13:27:48+00:00 | 0d4aefd | e627b403d7af54f878161686 | docs/t017-evidence.md | PASS |
| E152 | T002 | build | build | normal | 2026-10-26T14:53:53+00:00 | 80e78e5 | 3fe23240670d155cb117ac25 | docs/regression-1.0.md | PASS |
| E153 | T002 | macos | ui | normal | 2026-10-26T14:53:53+00:00 | 80e78e5 | 3fe23240670d155cb117ac25 | docs/regression-1.0.md | PASS |
| E154 | T002 | unit | unit | normal | 2026-10-26T14:53:54+00:00 | 80e78e5 | 3fe23240670d155cb117ac25 | docs/regression-1.0.md | PASS |
| E155 | T003 | macos | ui | normal | 2026-10-26T14:53:54+00:00 | 80e78e5 | 809a33edb7e85f98d5f9e9f7 | docs/regression-1.0.md | PASS |
| E156 | T003 | unit | unit | normal | 2026-10-26T14:53:54+00:00 | 80e78e5 | 809a33edb7e85f98d5f9e9f7 | docs/regression-1.0.md | PASS |
| E157 | T004 | unit | unit | normal | 2026-10-26T14:53:55+00:00 | 80e78e5 | c4f4fbdf425dd712ef3c7597 | docs/regression-1.0.md | PASS |
| E158 | T005 | macos | ui | normal | 2026-10-26T14:53:55+00:00 | 80e78e5 | a0213c9587b47e240964efd5 | docs/regression-1.0.md | PASS |
| E159 | T006 | inspection | inspection | normal | 2026-10-26T14:53:55+00:00 | 80e78e5 | b7ccd41a7851d35661a90ff6 | docs/regression-1.0.md | PASS |
| E160 | T006 | macos | ui | normal | 2026-10-26T14:53:55+00:00 | 80e78e5 | b7ccd41a7851d35661a90ff6 | docs/regression-1.0.md | PASS |
| E161 | T007 | build | build | normal | 2026-10-26T14:53:56+00:00 | 80e78e5 | 32252a051069594901c44ef0 | docs/regression-1.0.md | PASS |
| E162 | T007 | unit | unit | normal | 2026-10-26T14:53:56+00:00 | 80e78e5 | 32252a051069594901c44ef0 | docs/regression-1.0.md | PASS |
| E163 | T008 | macos | ui | normal | 2026-10-26T14:53:56+00:00 | 80e78e5 | 97a325a1a92323224c79d63b | docs/regression-1.0.md | PASS |
| E164 | T008 | unit | unit | normal | 2026-10-26T14:53:56+00:00 | 80e78e5 | 97a325a1a92323224c79d63b | docs/regression-1.0.md | PASS |
| E165 | T009 | inspection | inspection | normal | 2026-10-26T14:53:57+00:00 | 80e78e5 | 794ec4821e9cd7884ff16a38 | docs/regression-1.0.md | PASS |
| E166 | T010 | build | build | normal | 2026-10-26T14:53:57+00:00 | 80e78e5 | 0cc469c08145d2a4e9d8c793 | docs/regression-1.0.md | PASS |
| E167 | T010 | inspection | inspection | normal | 2026-10-26T14:53:57+00:00 | 80e78e5 | 0cc469c08145d2a4e9d8c793 | docs/regression-1.0.md | PASS |
| E168 | T010 | macos | ui | normal | 2026-10-26T14:53:57+00:00 | 80e78e5 | 0cc469c08145d2a4e9d8c793 | docs/regression-1.0.md | PASS |
| E169 | T010 | unit | unit | normal | 2026-10-26T14:53:57+00:00 | 80e78e5 | 0cc469c08145d2a4e9d8c793 | docs/regression-1.0.md | PASS |
| E170 | T011 | build | build | normal | 2026-10-26T14:53:58+00:00 | 80e78e5 | 911ca02a0dc2b748db4372aa | docs/regression-1.0.md | PASS |
| E171 | T011 | unit | unit | normal | 2026-10-26T14:53:58+00:00 | 80e78e5 | 911ca02a0dc2b748db4372aa | docs/regression-1.0.md | PASS |
| E172 | T012 | inspection | inspection | normal | 2026-10-26T14:53:58+00:00 | 80e78e5 | ef3d329ec1ff6f68ee6e319e | docs/regression-1.0.md | PASS |
| E173 | T012 | macos | ui | normal | 2026-10-26T14:53:58+00:00 | 80e78e5 | ef3d329ec1ff6f68ee6e319e | docs/regression-1.0.md | PASS |
| E174 | T013 | build | build | normal | 2026-10-26T14:53:59+00:00 | 80e78e5 | 6c5223a18b4e77796d878751 | docs/regression-1.0.md | PASS |
| E175 | T013 | inspection | inspection | normal | 2026-10-26T14:53:59+00:00 | 80e78e5 | 6c5223a18b4e77796d878751 | docs/regression-1.0.md | PASS |
| E176 | T014 | build | build | normal | 2026-10-26T14:53:59+00:00 | 80e78e5 | 18d5aa19eed3c1e9d9bfbfb8 | docs/regression-1.0.md | PASS |
| E177 | T014 | macos | ui | normal | 2026-10-26T14:53:59+00:00 | 80e78e5 | 18d5aa19eed3c1e9d9bfbfb8 | docs/regression-1.0.md | PASS |
| E178 | T014 | unit | unit | normal | 2026-10-26T14:53:59+00:00 | 80e78e5 | 18d5aa19eed3c1e9d9bfbfb8 | docs/regression-1.0.md | PASS |
| E179 | T015 | inspection | inspection | normal | 2026-10-26T14:54:01+00:00 | 80e78e5 | 19176fb5aec550097ee494c3 | docs/regression-1.0.md | PASS |
| E180 | T015 | macos | ui | normal | 2026-10-26T14:54:01+00:00 | 80e78e5 | 19176fb5aec550097ee494c3 | docs/regression-1.0.md | PASS |
| E181 | T016 | build | build | normal | 2026-10-26T14:54:01+00:00 | 80e78e5 | 1a19a33d2bf6545747d8cf89 | docs/regression-1.0.md | PASS |
| E182 | T016 | macos | ui | normal | 2026-10-26T14:54:01+00:00 | 80e78e5 | 1a19a33d2bf6545747d8cf89 | docs/regression-1.0.md | PASS |
| E183 | T016 | unit | unit | normal | 2026-10-26T14:54:01+00:00 | 80e78e5 | 1a19a33d2bf6545747d8cf89 | docs/regression-1.0.md | PASS |
| E184 | T017 | build | build | normal | 2026-10-26T14:54:02+00:00 | 80e78e5 | 9a7dc920d2f9f869a968ee25 | docs/regression-1.0.md | PASS |
| E185 | T017 | macos | ui | normal | 2026-10-26T14:54:02+00:00 | 80e78e5 | 9a7dc920d2f9f869a968ee25 | docs/regression-1.0.md | PASS |
| E186 | T017 | unit | unit | normal | 2026-10-26T14:54:02+00:00 | 80e78e5 | 9a7dc920d2f9f869a968ee25 | docs/regression-1.0.md | PASS |
| E187 | T018 | build | build | normal | 2026-10-26T14:54:12+00:00 | 80e78e5 | 1774a98fb7932ad197dcee95 | docs/t018-evidence.md | PASS |
| E188 | T018 | unit | unit | normal | 2026-10-26T14:54:12+00:00 | 80e78e5 | 1774a98fb7932ad197dcee95 | docs/t018-evidence.md | PASS |
| E189 | T018 | macos | ui | normal | 2026-10-26T14:54:12+00:00 | 80e78e5 | 1774a98fb7932ad197dcee95 | docs/t018-evidence.md | PASS |
| E190 | T018 | inspection | inspection | normal | 2026-10-26T14:54:12+00:00 | 80e78e5 | 1774a98fb7932ad197dcee95 | docs/t018-evidence.md | PASS |
| E191 | T002 | build | build | normal | 2026-10-26T16:06:19+00:00 | 533ffaa | c5788aeb33af6b68e06b4e47 | docs/regression-1.0.md | PASS |
| E192 | T002 | macos | ui | normal | 2026-10-26T16:06:20+00:00 | 533ffaa | c5788aeb33af6b68e06b4e47 | docs/regression-1.0.md | PASS |
| E193 | T002 | unit | unit | normal | 2026-10-26T16:06:20+00:00 | 533ffaa | c5788aeb33af6b68e06b4e47 | docs/regression-1.0.md | PASS |
| E194 | T003 | macos | ui | normal | 2026-10-26T16:06:20+00:00 | 533ffaa | a8d75ae5acd33386cf40df49 | docs/regression-1.0.md | PASS |
| E195 | T003 | unit | unit | normal | 2026-10-26T16:06:21+00:00 | 533ffaa | a8d75ae5acd33386cf40df49 | docs/regression-1.0.md | PASS |
| E196 | T004 | unit | unit | normal | 2026-10-26T16:06:21+00:00 | 533ffaa | 3f8929f33349e6f5b9d25530 | docs/regression-1.0.md | PASS |
| E197 | T005 | macos | ui | normal | 2026-10-26T16:06:22+00:00 | 533ffaa | 16f0b8fdead3987042055172 | docs/regression-1.0.md | PASS |
| E198 | T006 | inspection | inspection | normal | 2026-10-26T16:06:22+00:00 | 533ffaa | 9913140a8404dd8a9d78b65e | docs/regression-1.0.md | PASS |
| E199 | T006 | macos | ui | normal | 2026-10-26T16:06:22+00:00 | 533ffaa | 9913140a8404dd8a9d78b65e | docs/regression-1.0.md | PASS |
| E200 | T007 | build | build | normal | 2026-10-26T16:06:23+00:00 | 533ffaa | f750ffafcb7b68d2dbc73451 | docs/regression-1.0.md | PASS |
| E201 | T007 | unit | unit | normal | 2026-10-26T16:06:23+00:00 | 533ffaa | f750ffafcb7b68d2dbc73451 | docs/regression-1.0.md | PASS |
| E202 | T008 | macos | ui | normal | 2026-10-26T16:06:23+00:00 | 533ffaa | c4e329de988069cf20a7f79b | docs/regression-1.0.md | PASS |
| E203 | T008 | unit | unit | normal | 2026-10-26T16:06:24+00:00 | 533ffaa | c4e329de988069cf20a7f79b | docs/regression-1.0.md | PASS |
| E204 | T009 | inspection | inspection | normal | 2026-10-26T16:06:24+00:00 | 533ffaa | 7e51656f1f16434ef18e73a4 | docs/regression-1.0.md | PASS |
| E205 | T010 | build | build | normal | 2026-10-26T16:06:24+00:00 | 533ffaa | bd0324609a80eb603aaeaad2 | docs/regression-1.0.md | PASS |
| E206 | T010 | inspection | inspection | normal | 2026-10-26T16:06:25+00:00 | 533ffaa | bd0324609a80eb603aaeaad2 | docs/regression-1.0.md | PASS |
| E207 | T010 | macos | ui | normal | 2026-10-26T16:06:25+00:00 | 533ffaa | bd0324609a80eb603aaeaad2 | docs/regression-1.0.md | PASS |
| E208 | T010 | unit | unit | normal | 2026-10-26T16:06:25+00:00 | 533ffaa | bd0324609a80eb603aaeaad2 | docs/regression-1.0.md | PASS |
| E209 | T011 | build | build | normal | 2026-10-26T16:06:26+00:00 | 533ffaa | 01b40e4e39a49794ea7989d8 | docs/regression-1.0.md | PASS |
| E210 | T011 | unit | unit | normal | 2026-10-26T16:06:26+00:00 | 533ffaa | 01b40e4e39a49794ea7989d8 | docs/regression-1.0.md | PASS |
| E211 | T012 | inspection | inspection | normal | 2026-10-26T16:06:26+00:00 | 533ffaa | 2f0f38b7d2f57dbc0a9856d5 | docs/regression-1.0.md | PASS |
| E212 | T012 | macos | ui | normal | 2026-10-26T16:06:26+00:00 | 533ffaa | 2f0f38b7d2f57dbc0a9856d5 | docs/regression-1.0.md | PASS |
| E213 | T013 | build | build | normal | 2026-10-26T16:06:27+00:00 | 533ffaa | 3764aee2044fb9f3dff35e51 | docs/regression-1.0.md | PASS |
| E214 | T013 | inspection | inspection | normal | 2026-10-26T16:06:27+00:00 | 533ffaa | 3764aee2044fb9f3dff35e51 | docs/regression-1.0.md | PASS |
| E215 | T014 | build | build | normal | 2026-10-26T16:06:27+00:00 | 533ffaa | d951fda307ca633e54dbd71f | docs/regression-1.0.md | PASS |
| E216 | T014 | macos | ui | normal | 2026-10-26T16:06:27+00:00 | 533ffaa | d951fda307ca633e54dbd71f | docs/regression-1.0.md | PASS |
| E217 | T014 | unit | unit | normal | 2026-10-26T16:06:27+00:00 | 533ffaa | d951fda307ca633e54dbd71f | docs/regression-1.0.md | PASS |
| E218 | T015 | inspection | inspection | normal | 2026-10-26T16:06:28+00:00 | 533ffaa | 42ae2ac2d068040dd68a9076 | docs/regression-1.0.md | PASS |
| E219 | T015 | macos | ui | normal | 2026-10-26T16:06:28+00:00 | 533ffaa | 42ae2ac2d068040dd68a9076 | docs/regression-1.0.md | PASS |
| E220 | T016 | build | build | normal | 2026-10-26T16:06:29+00:00 | 533ffaa | a2617343e3114f6bb6cabd80 | docs/regression-1.0.md | PASS |
| E221 | T016 | macos | ui | normal | 2026-10-26T16:06:29+00:00 | 533ffaa | a2617343e3114f6bb6cabd80 | docs/regression-1.0.md | PASS |
| E222 | T016 | unit | unit | normal | 2026-10-26T16:06:29+00:00 | 533ffaa | a2617343e3114f6bb6cabd80 | docs/regression-1.0.md | PASS |
| E223 | T017 | build | build | normal | 2026-10-26T16:06:30+00:00 | 533ffaa | c658cf2d3194510818fb182b | docs/regression-1.0.md | PASS |
| E224 | T017 | macos | ui | normal | 2026-10-26T16:06:30+00:00 | 533ffaa | c658cf2d3194510818fb182b | docs/regression-1.0.md | PASS |
| E225 | T017 | unit | unit | normal | 2026-10-26T16:06:30+00:00 | 533ffaa | c658cf2d3194510818fb182b | docs/regression-1.0.md | PASS |
| E226 | T018 | build | build | normal | 2026-10-26T16:06:31+00:00 | 533ffaa | 3dacb9ddc6ad1c44db7ebd80 | docs/regression-1.0.md | PASS |
| E227 | T018 | inspection | inspection | normal | 2026-10-26T16:06:31+00:00 | 533ffaa | 3dacb9ddc6ad1c44db7ebd80 | docs/regression-1.0.md | PASS |
| E228 | T018 | macos | ui | normal | 2026-10-26T16:06:31+00:00 | 533ffaa | 3dacb9ddc6ad1c44db7ebd80 | docs/regression-1.0.md | PASS |
| E229 | T018 | unit | unit | normal | 2026-10-26T16:06:31+00:00 | 533ffaa | 3dacb9ddc6ad1c44db7ebd80 | docs/regression-1.0.md | PASS |
| E230 | T019 | build | build | normal | 2026-10-26T16:06:32+00:00 | 533ffaa | 1eca1dff73befff09e1700ff | docs/t019-evidence.md | PASS |
| E231 | T019 | unit | unit | normal | 2026-10-26T16:06:32+00:00 | 533ffaa | 1eca1dff73befff09e1700ff | docs/t019-evidence.md | PASS |
| E232 | T019 | macos | ui | normal | 2026-10-26T16:06:32+00:00 | 533ffaa | 1eca1dff73befff09e1700ff | docs/t019-evidence.md | PASS |
| E233 | T002 | build | build | normal | 2026-10-26T16:12:50+00:00 | 682215f | dcbc39c45fa9879657ed17d6 | docs/regression-1.0.md | PASS |
| E234 | T002 | macos | ui | normal | 2026-10-26T16:12:50+00:00 | 682215f | dcbc39c45fa9879657ed17d6 | docs/regression-1.0.md | PASS |
| E235 | T002 | unit | unit | normal | 2026-10-26T16:12:50+00:00 | 682215f | dcbc39c45fa9879657ed17d6 | docs/regression-1.0.md | PASS |
| E236 | T003 | macos | ui | normal | 2026-10-26T16:12:51+00:00 | 682215f | abec8b698c740ff1eac2e1f9 | docs/regression-1.0.md | PASS |
| E237 | T003 | unit | unit | normal | 2026-10-26T16:12:51+00:00 | 682215f | abec8b698c740ff1eac2e1f9 | docs/regression-1.0.md | PASS |
| E238 | T004 | unit | unit | normal | 2026-10-26T16:12:52+00:00 | 682215f | fe857ef2715e79d064c72d26 | docs/regression-1.0.md | PASS |
| E239 | T005 | macos | ui | normal | 2026-10-26T16:12:52+00:00 | 682215f | 4994967c1b1e72a52c0d43ad | docs/regression-1.0.md | PASS |
| E240 | T006 | inspection | inspection | normal | 2026-10-26T16:12:53+00:00 | 682215f | 19ca4cd1535a589eda8338f1 | docs/regression-1.0.md | PASS |
| E241 | T006 | macos | ui | normal | 2026-10-26T16:12:53+00:00 | 682215f | 19ca4cd1535a589eda8338f1 | docs/regression-1.0.md | PASS |
| E242 | T007 | build | build | normal | 2026-10-26T16:12:53+00:00 | 682215f | 72908def1440873849bd268e | docs/regression-1.0.md | PASS |
| E243 | T007 | unit | unit | normal | 2026-10-26T16:12:54+00:00 | 682215f | 72908def1440873849bd268e | docs/regression-1.0.md | PASS |
| E244 | T008 | macos | ui | normal | 2026-10-26T16:12:54+00:00 | 682215f | 73aee1e7a0ec6a31181a9125 | docs/regression-1.0.md | PASS |
| E245 | T008 | unit | unit | normal | 2026-10-26T16:12:54+00:00 | 682215f | 73aee1e7a0ec6a31181a9125 | docs/regression-1.0.md | PASS |
| E246 | T009 | inspection | inspection | normal | 2026-10-26T16:12:55+00:00 | 682215f | 62627b6861c0a2f00dd1fd09 | docs/regression-1.0.md | PASS |
| E247 | T010 | build | build | normal | 2026-10-26T16:12:55+00:00 | 682215f | f2a5de51033283ad57dc0932 | docs/regression-1.0.md | PASS |
| E248 | T010 | inspection | inspection | normal | 2026-10-26T16:12:55+00:00 | 682215f | f2a5de51033283ad57dc0932 | docs/regression-1.0.md | PASS |
| E249 | T010 | macos | ui | normal | 2026-10-26T16:12:55+00:00 | 682215f | f2a5de51033283ad57dc0932 | docs/regression-1.0.md | PASS |
| E250 | T010 | unit | unit | normal | 2026-10-26T16:12:55+00:00 | 682215f | f2a5de51033283ad57dc0932 | docs/regression-1.0.md | PASS |
| E251 | T011 | build | build | normal | 2026-10-26T16:12:56+00:00 | 682215f | d03c392fc6cf49ce9fa0d354 | docs/regression-1.0.md | PASS |
| E252 | T011 | unit | unit | normal | 2026-10-26T16:12:56+00:00 | 682215f | d03c392fc6cf49ce9fa0d354 | docs/regression-1.0.md | PASS |
| E253 | T012 | inspection | inspection | normal | 2026-10-26T16:12:56+00:00 | 682215f | e78a4bb2a2b44e7abd6b354e | docs/regression-1.0.md | PASS |
| E254 | T012 | macos | ui | normal | 2026-10-26T16:12:56+00:00 | 682215f | e78a4bb2a2b44e7abd6b354e | docs/regression-1.0.md | PASS |
| E255 | T013 | build | build | normal | 2026-10-26T16:12:57+00:00 | 682215f | 0fcfdac49ae6678cdda4f6d9 | docs/regression-1.0.md | PASS |
| E256 | T013 | inspection | inspection | normal | 2026-10-26T16:12:57+00:00 | 682215f | 0fcfdac49ae6678cdda4f6d9 | docs/regression-1.0.md | PASS |
| E257 | T014 | build | build | normal | 2026-10-26T16:12:57+00:00 | 682215f | 059923019cd530d73f2f6c5c | docs/regression-1.0.md | PASS |
| E258 | T014 | macos | ui | normal | 2026-10-26T16:12:57+00:00 | 682215f | 059923019cd530d73f2f6c5c | docs/regression-1.0.md | PASS |
| E259 | T014 | unit | unit | normal | 2026-10-26T16:12:57+00:00 | 682215f | 059923019cd530d73f2f6c5c | docs/regression-1.0.md | PASS |
| E260 | T015 | inspection | inspection | normal | 2026-10-26T16:12:58+00:00 | 682215f | d5a16c9e5932568cf664e865 | docs/regression-1.0.md | PASS |
| E261 | T015 | macos | ui | normal | 2026-10-26T16:12:58+00:00 | 682215f | d5a16c9e5932568cf664e865 | docs/regression-1.0.md | PASS |
| E262 | T016 | build | build | normal | 2026-10-26T16:12:59+00:00 | 682215f | a2712456ddcdcd8e32598f30 | docs/regression-1.0.md | PASS |
| E263 | T016 | macos | ui | normal | 2026-10-26T16:12:59+00:00 | 682215f | a2712456ddcdcd8e32598f30 | docs/regression-1.0.md | PASS |
| E264 | T016 | unit | unit | normal | 2026-10-26T16:12:59+00:00 | 682215f | a2712456ddcdcd8e32598f30 | docs/regression-1.0.md | PASS |
| E265 | T017 | build | build | normal | 2026-10-26T16:13:00+00:00 | 682215f | 7b2b3ac606a7644e7b685f4b | docs/regression-1.0.md | PASS |
| E266 | T017 | macos | ui | normal | 2026-10-26T16:13:00+00:00 | 682215f | 7b2b3ac606a7644e7b685f4b | docs/regression-1.0.md | PASS |
| E267 | T017 | unit | unit | normal | 2026-10-26T16:13:01+00:00 | 682215f | 7b2b3ac606a7644e7b685f4b | docs/regression-1.0.md | PASS |
| E268 | T018 | build | build | normal | 2026-10-26T16:13:02+00:00 | 682215f | e5a3dcb0d372e3cf04b2345b | docs/regression-1.0.md | PASS |
| E269 | T018 | inspection | inspection | normal | 2026-10-26T16:13:02+00:00 | 682215f | e5a3dcb0d372e3cf04b2345b | docs/regression-1.0.md | PASS |
| E270 | T018 | macos | ui | normal | 2026-10-26T16:13:02+00:00 | 682215f | e5a3dcb0d372e3cf04b2345b | docs/regression-1.0.md | PASS |
| E271 | T018 | unit | unit | normal | 2026-10-26T16:13:02+00:00 | 682215f | e5a3dcb0d372e3cf04b2345b | docs/regression-1.0.md | PASS |
| E272 | T019 | build | build | normal | 2026-10-26T16:13:03+00:00 | 682215f | 57e9d3adf95804cbadb6f22b | docs/regression-1.0.md | PASS |
| E273 | T019 | macos | ui | normal | 2026-10-26T16:13:03+00:00 | 682215f | 57e9d3adf95804cbadb6f22b | docs/regression-1.0.md | PASS |
| E274 | T019 | unit | unit | normal | 2026-10-26T16:13:03+00:00 | 682215f | 57e9d3adf95804cbadb6f22b | docs/regression-1.0.md | PASS |
| E275 | T020 | build | build | normal | 2026-10-26T16:13:04+00:00 | 682215f | f4c07833b2cb328cd5297e90 | docs/t020-evidence.md | PASS |
| E276 | T020 | unit | unit | normal | 2026-10-26T16:13:04+00:00 | 682215f | f4c07833b2cb328cd5297e90 | docs/t020-evidence.md | PASS |
| E277 | T020 | macos | ui | normal | 2026-10-26T16:13:04+00:00 | 682215f | f4c07833b2cb328cd5297e90 | docs/t020-evidence.md | PASS |
| E278 | T002 | build | build | normal | 2026-10-26T16:28:04+00:00 | 6598dc9 | bee5449a7107d8f2d134c888 | docs/regression-1.0.md | PASS |
| E279 | T002 | macos | ui | normal | 2026-10-26T16:28:04+00:00 | 6598dc9 | bee5449a7107d8f2d134c888 | docs/regression-1.0.md | PASS |
| E280 | T002 | unit | unit | normal | 2026-10-26T16:28:04+00:00 | 6598dc9 | bee5449a7107d8f2d134c888 | docs/regression-1.0.md | PASS |
| E281 | T003 | macos | ui | normal | 2026-10-26T16:28:05+00:00 | 6598dc9 | c9f6d5664c00f11541e3a316 | docs/regression-1.0.md | PASS |
| E282 | T003 | unit | unit | normal | 2026-10-26T16:28:05+00:00 | 6598dc9 | c9f6d5664c00f11541e3a316 | docs/regression-1.0.md | PASS |
| E283 | T004 | unit | unit | normal | 2026-10-26T16:28:05+00:00 | 6598dc9 | 8d48e3c1895f0d0ca30b4c0c | docs/regression-1.0.md | PASS |
| E284 | T005 | macos | ui | normal | 2026-10-26T16:28:06+00:00 | 6598dc9 | 098a9b2f5bd5366ad47af833 | docs/regression-1.0.md | PASS |
| E285 | T006 | inspection | inspection | normal | 2026-10-26T16:28:06+00:00 | 6598dc9 | 02247078a841d73a3a7ec8dd | docs/regression-1.0.md | PASS |
| E286 | T006 | macos | ui | normal | 2026-10-26T16:28:06+00:00 | 6598dc9 | 02247078a841d73a3a7ec8dd | docs/regression-1.0.md | PASS |
| E287 | T007 | build | build | normal | 2026-10-26T16:28:07+00:00 | 6598dc9 | 436211e0fdc988e3a6bafec0 | docs/regression-1.0.md | PASS |
| E288 | T007 | unit | unit | normal | 2026-10-26T16:28:07+00:00 | 6598dc9 | 436211e0fdc988e3a6bafec0 | docs/regression-1.0.md | PASS |
| E289 | T008 | macos | ui | normal | 2026-10-26T16:28:07+00:00 | 6598dc9 | 1c7a936b491d9fdd911a643c | docs/regression-1.0.md | PASS |
| E290 | T008 | unit | unit | normal | 2026-10-26T16:28:08+00:00 | 6598dc9 | 1c7a936b491d9fdd911a643c | docs/regression-1.0.md | PASS |
| E291 | T009 | inspection | inspection | normal | 2026-10-26T16:28:08+00:00 | 6598dc9 | 09f9b9e21f19e38cae3195cf | docs/regression-1.0.md | PASS |
| E292 | T010 | build | build | normal | 2026-10-26T16:28:08+00:00 | 6598dc9 | 48f907a24bb624369d45abfa | docs/regression-1.0.md | PASS |
| E293 | T010 | inspection | inspection | normal | 2026-10-26T16:28:09+00:00 | 6598dc9 | 48f907a24bb624369d45abfa | docs/regression-1.0.md | PASS |
| E294 | T010 | macos | ui | normal | 2026-10-26T16:28:09+00:00 | 6598dc9 | 48f907a24bb624369d45abfa | docs/regression-1.0.md | PASS |
| E295 | T010 | unit | unit | normal | 2026-10-26T16:28:09+00:00 | 6598dc9 | 48f907a24bb624369d45abfa | docs/regression-1.0.md | PASS |
| E296 | T011 | build | build | normal | 2026-10-26T16:28:09+00:00 | 6598dc9 | ec0b41cd1954310dd86f4d64 | docs/regression-1.0.md | PASS |
| E297 | T011 | unit | unit | normal | 2026-10-26T16:28:10+00:00 | 6598dc9 | ec0b41cd1954310dd86f4d64 | docs/regression-1.0.md | PASS |
| E298 | T012 | inspection | inspection | normal | 2026-10-26T16:28:10+00:00 | 6598dc9 | 86190fdf16a631e155266acb | docs/regression-1.0.md | PASS |
| E299 | T012 | macos | ui | normal | 2026-10-26T16:28:10+00:00 | 6598dc9 | 86190fdf16a631e155266acb | docs/regression-1.0.md | PASS |
| E300 | T013 | build | build | normal | 2026-10-26T16:28:11+00:00 | 6598dc9 | b442beff1f54fedfe999793b | docs/regression-1.0.md | PASS |
| E301 | T013 | inspection | inspection | normal | 2026-10-26T16:28:11+00:00 | 6598dc9 | b442beff1f54fedfe999793b | docs/regression-1.0.md | PASS |
| E302 | T014 | build | build | normal | 2026-10-26T16:28:11+00:00 | 6598dc9 | 3b85686aa3577498513acb7c | docs/regression-1.0.md | PASS |
| E303 | T014 | macos | ui | normal | 2026-10-26T16:28:11+00:00 | 6598dc9 | 3b85686aa3577498513acb7c | docs/regression-1.0.md | PASS |
| E304 | T014 | unit | unit | normal | 2026-10-26T16:28:11+00:00 | 6598dc9 | 3b85686aa3577498513acb7c | docs/regression-1.0.md | PASS |
| E305 | T015 | inspection | inspection | normal | 2026-10-26T16:28:12+00:00 | 6598dc9 | 43973042680fb71104b9e7d3 | docs/regression-1.0.md | PASS |
| E306 | T015 | macos | ui | normal | 2026-10-26T16:28:12+00:00 | 6598dc9 | 43973042680fb71104b9e7d3 | docs/regression-1.0.md | PASS |
| E307 | T016 | build | build | normal | 2026-10-26T16:28:13+00:00 | 6598dc9 | ecb2444af1c4a496f609566b | docs/regression-1.0.md | PASS |
| E308 | T016 | macos | ui | normal | 2026-10-26T16:28:13+00:00 | 6598dc9 | ecb2444af1c4a496f609566b | docs/regression-1.0.md | PASS |
| E309 | T016 | unit | unit | normal | 2026-10-26T16:28:13+00:00 | 6598dc9 | ecb2444af1c4a496f609566b | docs/regression-1.0.md | PASS |
| E310 | T017 | build | build | normal | 2026-10-26T16:28:13+00:00 | 6598dc9 | ad432ed4f781b4f9f39b0d84 | docs/regression-1.0.md | PASS |
| E311 | T017 | macos | ui | normal | 2026-10-26T16:28:14+00:00 | 6598dc9 | ad432ed4f781b4f9f39b0d84 | docs/regression-1.0.md | PASS |
| E312 | T017 | unit | unit | normal | 2026-10-26T16:28:14+00:00 | 6598dc9 | ad432ed4f781b4f9f39b0d84 | docs/regression-1.0.md | PASS |
| E313 | T018 | build | build | normal | 2026-10-26T16:28:14+00:00 | 6598dc9 | 4831d6707ccef99d1e7fd958 | docs/regression-1.0.md | PASS |
| E314 | T018 | inspection | inspection | normal | 2026-10-26T16:28:14+00:00 | 6598dc9 | 4831d6707ccef99d1e7fd958 | docs/regression-1.0.md | PASS |
| E315 | T018 | macos | ui | normal | 2026-10-26T16:28:14+00:00 | 6598dc9 | 4831d6707ccef99d1e7fd958 | docs/regression-1.0.md | PASS |
| E316 | T018 | unit | unit | normal | 2026-10-26T16:28:15+00:00 | 6598dc9 | 4831d6707ccef99d1e7fd958 | docs/regression-1.0.md | PASS |
| E317 | T019 | build | build | normal | 2026-10-26T16:28:15+00:00 | 6598dc9 | e908f0f28bfee0d5583bab0c | docs/regression-1.0.md | PASS |
| E318 | T019 | macos | ui | normal | 2026-10-26T16:28:15+00:00 | 6598dc9 | e908f0f28bfee0d5583bab0c | docs/regression-1.0.md | PASS |
| E319 | T019 | unit | unit | normal | 2026-10-26T16:28:15+00:00 | 6598dc9 | e908f0f28bfee0d5583bab0c | docs/regression-1.0.md | PASS |
| E320 | T020 | build | build | normal | 2026-10-26T16:28:16+00:00 | 6598dc9 | 5229b569212564c4c0bae8fc | docs/t020-evidence.md | PASS |
| E321 | T020 | macos | ui | normal | 2026-10-26T16:28:16+00:00 | 6598dc9 | 5229b569212564c4c0bae8fc | docs/t020-evidence.md | PASS |
| E322 | T020 | unit | unit | normal | 2026-10-26T16:28:16+00:00 | 6598dc9 | 5229b569212564c4c0bae8fc | docs/t020-evidence.md | PASS |
| E323 | T002 | build | build | normal | 2026-10-26T16:47:19+00:00 | 695e61a | ef47df84428848fd44a41a21 | docs/regression-1.0.md | PASS |
| E324 | T002 | macos | ui | normal | 2026-10-26T16:47:19+00:00 | 695e61a | ef47df84428848fd44a41a21 | docs/regression-1.0.md | PASS |
| E325 | T002 | unit | unit | normal | 2026-10-26T16:47:19+00:00 | 695e61a | ef47df84428848fd44a41a21 | docs/regression-1.0.md | PASS |
| E326 | T003 | macos | ui | normal | 2026-10-26T16:47:20+00:00 | 695e61a | 5aadc81cc0fa27b008d80f5c | docs/regression-1.0.md | PASS |
| E327 | T003 | unit | unit | normal | 2026-10-26T16:47:20+00:00 | 695e61a | 5aadc81cc0fa27b008d80f5c | docs/regression-1.0.md | PASS |
| E328 | T004 | unit | unit | normal | 2026-10-26T16:47:21+00:00 | 695e61a | 32897d77337a4e156d957ceb | docs/regression-1.0.md | PASS |
| E329 | T005 | macos | ui | normal | 2026-10-26T16:47:21+00:00 | 695e61a | f0c285374ed51db49aa1f496 | docs/regression-1.0.md | PASS |
| E330 | T006 | inspection | inspection | normal | 2026-10-26T16:47:22+00:00 | 695e61a | ec2e9cca381d4a2fd6bc4e64 | docs/regression-1.0.md | PASS |
| E331 | T006 | macos | ui | normal | 2026-10-26T16:47:22+00:00 | 695e61a | ec2e9cca381d4a2fd6bc4e64 | docs/regression-1.0.md | PASS |
| E332 | T007 | build | build | normal | 2026-10-26T16:47:23+00:00 | 695e61a | a06c066abbe18f11be3c28c2 | docs/regression-1.0.md | PASS |
| E333 | T007 | unit | unit | normal | 2026-10-26T16:47:23+00:00 | 695e61a | a06c066abbe18f11be3c28c2 | docs/regression-1.0.md | PASS |
| E334 | T008 | macos | ui | normal | 2026-10-26T16:47:23+00:00 | 695e61a | 97846247cc4253473cc303a9 | docs/regression-1.0.md | PASS |
| E335 | T008 | unit | unit | normal | 2026-10-26T16:47:23+00:00 | 695e61a | 97846247cc4253473cc303a9 | docs/regression-1.0.md | PASS |
| E336 | T009 | inspection | inspection | normal | 2026-10-26T16:47:24+00:00 | 695e61a | ef628d1fe5ba4bf8455d6b14 | docs/regression-1.0.md | PASS |
| E337 | T010 | build | build | normal | 2026-10-26T16:47:24+00:00 | 695e61a | 51c46f778f601a7790e6c1d3 | docs/regression-1.0.md | PASS |
| E338 | T010 | inspection | inspection | normal | 2026-10-26T16:47:24+00:00 | 695e61a | 51c46f778f601a7790e6c1d3 | docs/regression-1.0.md | PASS |
| E339 | T010 | macos | ui | normal | 2026-10-26T16:47:24+00:00 | 695e61a | 51c46f778f601a7790e6c1d3 | docs/regression-1.0.md | PASS |
| E340 | T010 | unit | unit | normal | 2026-10-26T16:47:24+00:00 | 695e61a | 51c46f778f601a7790e6c1d3 | docs/regression-1.0.md | PASS |
| E341 | T011 | build | build | normal | 2026-10-26T16:47:25+00:00 | 695e61a | 759a87bf9a2edd45249d0082 | docs/regression-1.0.md | PASS |
| E342 | T011 | unit | unit | normal | 2026-10-26T16:47:25+00:00 | 695e61a | 759a87bf9a2edd45249d0082 | docs/regression-1.0.md | PASS |
| E343 | T012 | inspection | inspection | normal | 2026-10-26T16:47:25+00:00 | 695e61a | 60a44bf854ea01af4c01d9c4 | docs/regression-1.0.md | PASS |
| E344 | T012 | macos | ui | normal | 2026-10-26T16:47:26+00:00 | 695e61a | 60a44bf854ea01af4c01d9c4 | docs/regression-1.0.md | PASS |
| E345 | T013 | build | build | normal | 2026-10-26T16:47:27+00:00 | 695e61a | 600b5f24f45638ae5ae2538b | docs/regression-1.0.md | PASS |
| E346 | T013 | inspection | inspection | normal | 2026-10-26T16:47:27+00:00 | 695e61a | 600b5f24f45638ae5ae2538b | docs/regression-1.0.md | PASS |
| E347 | T014 | build | build | normal | 2026-10-26T16:47:27+00:00 | 695e61a | 74821c8f99147cbb9fcb6bad | docs/regression-1.0.md | PASS |
| E348 | T014 | macos | ui | normal | 2026-10-26T16:47:27+00:00 | 695e61a | 74821c8f99147cbb9fcb6bad | docs/regression-1.0.md | PASS |
| E349 | T014 | unit | unit | normal | 2026-10-26T16:47:27+00:00 | 695e61a | 74821c8f99147cbb9fcb6bad | docs/regression-1.0.md | PASS |
| E350 | T015 | inspection | inspection | normal | 2026-10-26T16:47:28+00:00 | 695e61a | 96b5d671136efbb3bd08dd6a | docs/regression-1.0.md | PASS |
| E351 | T015 | macos | ui | normal | 2026-10-26T16:47:28+00:00 | 695e61a | 96b5d671136efbb3bd08dd6a | docs/regression-1.0.md | PASS |
| E352 | T016 | build | build | normal | 2026-10-26T16:47:29+00:00 | 695e61a | 80e0836939188c9aeadb10db | docs/regression-1.0.md | PASS |
| E353 | T016 | macos | ui | normal | 2026-10-26T16:47:29+00:00 | 695e61a | 80e0836939188c9aeadb10db | docs/regression-1.0.md | PASS |
| E354 | T016 | unit | unit | normal | 2026-10-26T16:47:29+00:00 | 695e61a | 80e0836939188c9aeadb10db | docs/regression-1.0.md | PASS |
| E355 | T017 | build | build | normal | 2026-10-26T16:47:30+00:00 | 695e61a | cdbbb62e20ac75bcc432aaf1 | docs/regression-1.0.md | PASS |
| E356 | T017 | macos | ui | normal | 2026-10-26T16:47:30+00:00 | 695e61a | cdbbb62e20ac75bcc432aaf1 | docs/regression-1.0.md | PASS |
| E357 | T017 | unit | unit | normal | 2026-10-26T16:47:30+00:00 | 695e61a | cdbbb62e20ac75bcc432aaf1 | docs/regression-1.0.md | PASS |
| E358 | T018 | build | build | normal | 2026-10-26T16:47:31+00:00 | 695e61a | 35b6e7e3522e2ff1e52ab158 | docs/regression-1.0.md | PASS |
| E359 | T018 | inspection | inspection | normal | 2026-10-26T16:47:31+00:00 | 695e61a | 35b6e7e3522e2ff1e52ab158 | docs/regression-1.0.md | PASS |
| E360 | T018 | macos | ui | normal | 2026-10-26T16:47:31+00:00 | 695e61a | 35b6e7e3522e2ff1e52ab158 | docs/regression-1.0.md | PASS |
| E361 | T018 | unit | unit | normal | 2026-10-26T16:47:31+00:00 | 695e61a | 35b6e7e3522e2ff1e52ab158 | docs/regression-1.0.md | PASS |
| E362 | T019 | build | build | normal | 2026-10-26T16:47:32+00:00 | 695e61a | 59b32ee3602f15c332210878 | docs/regression-1.0.md | PASS |
| E363 | T019 | macos | ui | normal | 2026-10-26T16:47:32+00:00 | 695e61a | 59b32ee3602f15c332210878 | docs/regression-1.0.md | PASS |
| E364 | T019 | unit | unit | normal | 2026-10-26T16:47:32+00:00 | 695e61a | 59b32ee3602f15c332210878 | docs/regression-1.0.md | PASS |
| E365 | T020 | build | build | normal | 2026-10-26T16:47:33+00:00 | 695e61a | 14d82082e61a97cc5b5e74d0 | docs/t020-evidence.md | PASS |
| E366 | T020 | macos | ui | normal | 2026-10-26T16:47:33+00:00 | 695e61a | 14d82082e61a97cc5b5e74d0 | docs/t020-evidence.md | PASS |
| E367 | T020 | unit | unit | normal | 2026-10-26T16:47:33+00:00 | 695e61a | 14d82082e61a97cc5b5e74d0 | docs/t020-evidence.md | PASS |
| E368 | T002 | build | build | normal | 2026-10-26T18:27:42+00:00 | 0980775 | 5c643947cc8637ea203739bc | docs/regression-1.0.md | PASS |
| E369 | T002 | macos | ui | normal | 2026-10-26T18:27:42+00:00 | 0980775 | 5c643947cc8637ea203739bc | docs/regression-1.0.md | PASS |
| E370 | T002 | unit | unit | normal | 2026-10-26T18:27:42+00:00 | 0980775 | 5c643947cc8637ea203739bc | docs/regression-1.0.md | PASS |
| E371 | T003 | macos | ui | normal | 2026-10-26T18:27:43+00:00 | 0980775 | 92b8b2a529cbf0a86eb765d9 | docs/regression-1.0.md | PASS |
| E372 | T003 | unit | unit | normal | 2026-10-26T18:27:43+00:00 | 0980775 | 92b8b2a529cbf0a86eb765d9 | docs/regression-1.0.md | PASS |
| E373 | T004 | unit | unit | normal | 2026-10-26T18:27:44+00:00 | 0980775 | c8193fa7f8cdb654845cf5cd | docs/regression-1.0.md | PASS |
| E374 | T005 | macos | ui | normal | 2026-10-26T18:27:44+00:00 | 0980775 | a480259af1636aff3b206934 | docs/regression-1.0.md | PASS |
| E375 | T006 | inspection | inspection | normal | 2026-10-26T18:27:45+00:00 | 0980775 | 72aab44b17a03de11b7a3f1c | docs/regression-1.0.md | PASS |
| E376 | T006 | macos | ui | normal | 2026-10-26T18:27:45+00:00 | 0980775 | 72aab44b17a03de11b7a3f1c | docs/regression-1.0.md | PASS |
| E377 | T007 | build | build | normal | 2026-10-26T18:27:46+00:00 | 0980775 | 13a87c3671f8525611a600e3 | docs/regression-1.0.md | PASS |
| E378 | T007 | unit | unit | normal | 2026-10-26T18:27:46+00:00 | 0980775 | 13a87c3671f8525611a600e3 | docs/regression-1.0.md | PASS |
| E379 | T008 | macos | ui | normal | 2026-10-26T18:27:46+00:00 | 0980775 | 9b391ee3ecb057771977fa94 | docs/regression-1.0.md | PASS |
| E380 | T008 | unit | unit | normal | 2026-10-26T18:27:46+00:00 | 0980775 | 9b391ee3ecb057771977fa94 | docs/regression-1.0.md | PASS |
| E381 | T009 | inspection | inspection | normal | 2026-10-26T18:27:47+00:00 | 0980775 | e182d4e01d5dc22f7ede22f7 | docs/regression-1.0.md | PASS |
| E382 | T010 | build | build | normal | 2026-10-26T18:27:47+00:00 | 0980775 | 325d08d4d3ba1f1c6a3beb1b | docs/regression-1.0.md | PASS |
| E383 | T010 | inspection | inspection | normal | 2026-10-26T18:27:47+00:00 | 0980775 | 325d08d4d3ba1f1c6a3beb1b | docs/regression-1.0.md | PASS |
| E384 | T010 | macos | ui | normal | 2026-10-26T18:27:47+00:00 | 0980775 | 325d08d4d3ba1f1c6a3beb1b | docs/regression-1.0.md | PASS |
| E385 | T010 | unit | unit | normal | 2026-10-26T18:27:47+00:00 | 0980775 | 325d08d4d3ba1f1c6a3beb1b | docs/regression-1.0.md | PASS |
| E386 | T011 | build | build | normal | 2026-10-26T18:27:48+00:00 | 0980775 | 110858533caf320f428bf13d | docs/regression-1.0.md | PASS |
| E387 | T011 | unit | unit | normal | 2026-10-26T18:27:48+00:00 | 0980775 | 110858533caf320f428bf13d | docs/regression-1.0.md | PASS |
| E388 | T012 | inspection | inspection | normal | 2026-10-26T18:27:48+00:00 | 0980775 | e786df02403db8f951fc6070 | docs/regression-1.0.md | PASS |
| E389 | T012 | macos | ui | normal | 2026-10-26T18:27:48+00:00 | 0980775 | e786df02403db8f951fc6070 | docs/regression-1.0.md | PASS |
| E390 | T013 | build | build | normal | 2026-10-26T18:27:49+00:00 | 0980775 | cd542bc01ee72e205ec384a1 | docs/regression-1.0.md | PASS |
| E391 | T013 | inspection | inspection | normal | 2026-10-26T18:27:49+00:00 | 0980775 | cd542bc01ee72e205ec384a1 | docs/regression-1.0.md | PASS |
| E392 | T014 | build | build | normal | 2026-10-26T18:27:49+00:00 | 0980775 | 1be1150f66a4c00824c3277a | docs/regression-1.0.md | PASS |
| E393 | T014 | macos | ui | normal | 2026-10-26T18:27:49+00:00 | 0980775 | 1be1150f66a4c00824c3277a | docs/regression-1.0.md | PASS |
| E394 | T014 | unit | unit | normal | 2026-10-26T18:27:50+00:00 | 0980775 | 1be1150f66a4c00824c3277a | docs/regression-1.0.md | PASS |
| E395 | T015 | inspection | inspection | normal | 2026-10-26T18:27:50+00:00 | 0980775 | ad2369f08c3c12125f216b20 | docs/regression-1.0.md | PASS |
| E396 | T015 | macos | ui | normal | 2026-10-26T18:27:50+00:00 | 0980775 | ad2369f08c3c12125f216b20 | docs/regression-1.0.md | PASS |
| E397 | T016 | build | build | normal | 2026-10-26T18:27:51+00:00 | 0980775 | d15d39e7afe9bb42d7eac67b | docs/regression-1.0.md | PASS |
| E398 | T016 | macos | ui | normal | 2026-10-26T18:27:51+00:00 | 0980775 | d15d39e7afe9bb42d7eac67b | docs/regression-1.0.md | PASS |
| E399 | T016 | unit | unit | normal | 2026-10-26T18:27:51+00:00 | 0980775 | d15d39e7afe9bb42d7eac67b | docs/regression-1.0.md | PASS |
| E400 | T017 | build | build | normal | 2026-10-26T18:27:52+00:00 | 0980775 | 7b8abe047e4be4ca4415c03b | docs/regression-1.0.md | PASS |
| E401 | T017 | macos | ui | normal | 2026-10-26T18:27:52+00:00 | 0980775 | 7b8abe047e4be4ca4415c03b | docs/regression-1.0.md | PASS |
| E402 | T017 | unit | unit | normal | 2026-10-26T18:27:52+00:00 | 0980775 | 7b8abe047e4be4ca4415c03b | docs/regression-1.0.md | PASS |
| E403 | T018 | build | build | normal | 2026-10-26T18:27:53+00:00 | 0980775 | ab6ce42eeb5e65d2cd7b9f7f | docs/regression-1.0.md | PASS |
| E404 | T018 | inspection | inspection | normal | 2026-10-26T18:27:53+00:00 | 0980775 | ab6ce42eeb5e65d2cd7b9f7f | docs/regression-1.0.md | PASS |
| E405 | T018 | macos | ui | normal | 2026-10-26T18:27:53+00:00 | 0980775 | ab6ce42eeb5e65d2cd7b9f7f | docs/regression-1.0.md | PASS |
| E406 | T018 | unit | unit | normal | 2026-10-26T18:27:53+00:00 | 0980775 | ab6ce42eeb5e65d2cd7b9f7f | docs/regression-1.0.md | PASS |
| E407 | T019 | build | build | normal | 2026-10-26T18:27:54+00:00 | 0980775 | c0d22cd9092bc920ce8890e1 | docs/regression-1.0.md | PASS |
| E408 | T019 | macos | ui | normal | 2026-10-26T18:27:54+00:00 | 0980775 | c0d22cd9092bc920ce8890e1 | docs/regression-1.0.md | PASS |
| E409 | T019 | unit | unit | normal | 2026-10-26T18:27:54+00:00 | 0980775 | c0d22cd9092bc920ce8890e1 | docs/regression-1.0.md | PASS |
| E410 | T020 | build | build | normal | 2026-10-26T18:27:55+00:00 | 0980775 | 4781f2deebd3b92b6b890f86 | docs/t020-evidence.md | PASS |
| E411 | T020 | macos | ui | normal | 2026-10-26T18:27:55+00:00 | 0980775 | 4781f2deebd3b92b6b890f86 | docs/t020-evidence.md | PASS |
| E412 | T020 | unit | unit | normal | 2026-10-26T18:27:55+00:00 | 0980775 | 4781f2deebd3b92b6b890f86 | docs/t020-evidence.md | PASS |
| E413 | T002 | build | build | normal | 2026-10-28T07:27:08+00:00 | ee067a8 | 8d6666d83f10018a14578ed5 | docs/regression-1.0.md | PASS |
| E414 | T002 | macos | ui | normal | 2026-10-28T07:27:08+00:00 | ee067a8 | 8d6666d83f10018a14578ed5 | docs/regression-1.0.md | PASS |
| E415 | T002 | unit | unit | normal | 2026-10-28T07:27:08+00:00 | ee067a8 | 8d6666d83f10018a14578ed5 | docs/regression-1.0.md | PASS |
| E416 | T003 | macos | ui | normal | 2026-10-28T07:27:09+00:00 | ee067a8 | 844448a9345dbe022be523e2 | docs/regression-1.0.md | PASS |
| E417 | T003 | unit | unit | normal | 2026-10-28T07:27:09+00:00 | ee067a8 | 844448a9345dbe022be523e2 | docs/regression-1.0.md | PASS |
| E418 | T004 | unit | unit | normal | 2026-10-28T07:27:09+00:00 | ee067a8 | 9ced02bfd62165938021d2c4 | docs/regression-1.0.md | PASS |
| E419 | T005 | macos | ui | normal | 2026-10-28T07:27:09+00:00 | ee067a8 | 9d93b7231cc17610543df0a6 | docs/regression-1.0.md | PASS |
| E420 | T006 | inspection | inspection | normal | 2026-10-28T07:27:10+00:00 | ee067a8 | 408034f7c8ded29afde867f9 | docs/regression-1.0.md | PASS |
| E421 | T006 | macos | ui | normal | 2026-10-28T07:27:10+00:00 | ee067a8 | 408034f7c8ded29afde867f9 | docs/regression-1.0.md | PASS |
| E422 | T007 | build | build | normal | 2026-10-28T07:27:10+00:00 | ee067a8 | 1311211b5463241d608eff49 | docs/regression-1.0.md | PASS |
| E423 | T007 | unit | unit | normal | 2026-10-28T07:27:11+00:00 | ee067a8 | 1311211b5463241d608eff49 | docs/regression-1.0.md | PASS |
| E424 | T008 | macos | ui | normal | 2026-10-28T07:27:11+00:00 | ee067a8 | 3c3194b07fcf7bf17e9d7974 | docs/regression-1.0.md | PASS |
| E425 | T008 | unit | unit | normal | 2026-10-28T07:27:11+00:00 | ee067a8 | 3c3194b07fcf7bf17e9d7974 | docs/regression-1.0.md | PASS |
| E426 | T009 | inspection | inspection | normal | 2026-10-28T07:27:11+00:00 | ee067a8 | 1e4518b94ad2be7e60b93054 | docs/regression-1.0.md | PASS |
| E427 | T010 | build | build | normal | 2026-10-28T07:27:12+00:00 | ee067a8 | 2079e648adcfb6e248a0e9b1 | docs/regression-1.0.md | PASS |
| E428 | T010 | inspection | inspection | normal | 2026-10-28T07:27:12+00:00 | ee067a8 | 2079e648adcfb6e248a0e9b1 | docs/regression-1.0.md | PASS |
| E429 | T010 | macos | ui | normal | 2026-10-28T07:27:12+00:00 | ee067a8 | 2079e648adcfb6e248a0e9b1 | docs/regression-1.0.md | PASS |
| E430 | T010 | unit | unit | normal | 2026-10-28T07:27:12+00:00 | ee067a8 | 2079e648adcfb6e248a0e9b1 | docs/regression-1.0.md | PASS |
| E431 | T011 | build | build | normal | 2026-10-28T07:27:12+00:00 | ee067a8 | 0745b3626fc265f4aeeaddbc | docs/regression-1.0.md | PASS |
| E432 | T011 | unit | unit | normal | 2026-10-28T07:27:12+00:00 | ee067a8 | 0745b3626fc265f4aeeaddbc | docs/regression-1.0.md | PASS |
| E433 | T012 | inspection | inspection | normal | 2026-10-28T07:27:13+00:00 | ee067a8 | 83ec18afc52e8ce8151c1398 | docs/regression-1.0.md | PASS |
| E434 | T012 | macos | ui | normal | 2026-10-28T07:27:13+00:00 | ee067a8 | 83ec18afc52e8ce8151c1398 | docs/regression-1.0.md | PASS |
| E435 | T013 | build | build | normal | 2026-10-28T07:27:13+00:00 | ee067a8 | c2e3a2417637c99fc2ddf516 | docs/regression-1.0.md | PASS |
| E436 | T013 | inspection | inspection | normal | 2026-10-28T07:27:13+00:00 | ee067a8 | c2e3a2417637c99fc2ddf516 | docs/regression-1.0.md | PASS |
| E437 | T014 | build | build | normal | 2026-10-28T07:27:14+00:00 | ee067a8 | 53b466d0344f146cc22acd8e | docs/regression-1.0.md | PASS |
| E438 | T014 | macos | ui | normal | 2026-10-28T07:27:14+00:00 | ee067a8 | 53b466d0344f146cc22acd8e | docs/regression-1.0.md | PASS |
| E439 | T014 | unit | unit | normal | 2026-10-28T07:27:14+00:00 | ee067a8 | 53b466d0344f146cc22acd8e | docs/regression-1.0.md | PASS |
| E440 | T015 | inspection | inspection | normal | 2026-10-28T07:27:14+00:00 | ee067a8 | 097a80d3aa9873e8a9090d7f | docs/regression-1.0.md | PASS |
| E441 | T015 | macos | ui | normal | 2026-10-28T07:27:14+00:00 | ee067a8 | 097a80d3aa9873e8a9090d7f | docs/regression-1.0.md | PASS |
| E442 | T016 | build | build | normal | 2026-10-28T07:27:15+00:00 | ee067a8 | cf384745c596e34afdf8905b | docs/regression-1.0.md | PASS |
| E443 | T016 | macos | ui | normal | 2026-10-28T07:27:15+00:00 | ee067a8 | cf384745c596e34afdf8905b | docs/regression-1.0.md | PASS |
| E444 | T016 | unit | unit | normal | 2026-10-28T07:27:15+00:00 | ee067a8 | cf384745c596e34afdf8905b | docs/regression-1.0.md | PASS |
| E445 | T017 | build | build | normal | 2026-10-28T07:27:15+00:00 | ee067a8 | 58220817e68e1e12144c9f8b | docs/regression-1.0.md | PASS |
| E446 | T017 | macos | ui | normal | 2026-10-28T07:27:16+00:00 | ee067a8 | 58220817e68e1e12144c9f8b | docs/regression-1.0.md | PASS |
| E447 | T017 | unit | unit | normal | 2026-10-28T07:27:16+00:00 | ee067a8 | 58220817e68e1e12144c9f8b | docs/regression-1.0.md | PASS |
| E448 | T018 | build | build | normal | 2026-10-28T07:27:16+00:00 | ee067a8 | de923abd24c26bca7228fb84 | docs/regression-1.0.md | PASS |
| E449 | T018 | inspection | inspection | normal | 2026-10-28T07:27:16+00:00 | ee067a8 | de923abd24c26bca7228fb84 | docs/regression-1.0.md | PASS |
| E450 | T018 | macos | ui | normal | 2026-10-28T07:27:16+00:00 | ee067a8 | de923abd24c26bca7228fb84 | docs/regression-1.0.md | PASS |
| E451 | T018 | unit | unit | normal | 2026-10-28T07:27:16+00:00 | ee067a8 | de923abd24c26bca7228fb84 | docs/regression-1.0.md | PASS |
| E452 | T019 | build | build | normal | 2026-10-28T07:27:17+00:00 | ee067a8 | a68e1b5246b6619fb2c65b24 | docs/regression-1.0.md | PASS |
| E453 | T019 | macos | ui | normal | 2026-10-28T07:27:17+00:00 | ee067a8 | a68e1b5246b6619fb2c65b24 | docs/regression-1.0.md | PASS |
| E454 | T019 | unit | unit | normal | 2026-10-28T07:27:17+00:00 | ee067a8 | a68e1b5246b6619fb2c65b24 | docs/regression-1.0.md | PASS |
| E455 | T020 | build | build | normal | 2026-10-28T07:27:18+00:00 | ee067a8 | 03bfb05218489a75839bd935 | docs/t020-evidence.md | PASS |
| E456 | T020 | macos | ui | normal | 2026-10-28T07:27:18+00:00 | ee067a8 | 03bfb05218489a75839bd935 | docs/t020-evidence.md | PASS |
| E457 | T020 | unit | unit | normal | 2026-10-28T07:27:18+00:00 | ee067a8 | 03bfb05218489a75839bd935 | docs/t020-evidence.md | PASS |
| E458 | T002 | build | build | normal | 2026-10-28T08:40:28+00:00 | 0e7cacb | 159640fcff485fba1be4f643 | docs/regression-1.0.md | PASS |
| E459 | T002 | macos | ui | normal | 2026-10-28T08:40:28+00:00 | 0e7cacb | 159640fcff485fba1be4f643 | docs/regression-1.0.md | PASS |
| E460 | T002 | unit | unit | normal | 2026-10-28T08:40:28+00:00 | 0e7cacb | 159640fcff485fba1be4f643 | docs/regression-1.0.md | PASS |
| E461 | T003 | macos | ui | normal | 2026-10-28T08:40:29+00:00 | 0e7cacb | 5b0ffc13ed202622c3248dbe | docs/regression-1.0.md | PASS |
| E462 | T003 | unit | unit | normal | 2026-10-28T08:40:29+00:00 | 0e7cacb | 5b0ffc13ed202622c3248dbe | docs/regression-1.0.md | PASS |
| E463 | T004 | unit | unit | normal | 2026-10-28T08:40:29+00:00 | 0e7cacb | e0692e3f19c295106da3677b | docs/regression-1.0.md | PASS |
| E464 | T005 | macos | ui | normal | 2026-10-28T08:40:30+00:00 | 0e7cacb | 4ca2f5ec05975fa0813a17c9 | docs/regression-1.0.md | PASS |
| E465 | T006 | inspection | inspection | normal | 2026-10-28T08:40:30+00:00 | 0e7cacb | 3a9446511ecfa8ad5c068d96 | docs/regression-1.0.md | PASS |
| E466 | T006 | macos | ui | normal | 2026-10-28T08:40:30+00:00 | 0e7cacb | 3a9446511ecfa8ad5c068d96 | docs/regression-1.0.md | PASS |
| E467 | T007 | build | build | normal | 2026-10-28T08:40:31+00:00 | 0e7cacb | 780794d40626085bcf18ef38 | docs/regression-1.0.md | PASS |
| E468 | T007 | unit | unit | normal | 2026-10-28T08:40:31+00:00 | 0e7cacb | 780794d40626085bcf18ef38 | docs/regression-1.0.md | PASS |
| E469 | T008 | macos | ui | normal | 2026-10-28T08:40:31+00:00 | 0e7cacb | be79870455ad6c1e38fb2d9c | docs/regression-1.0.md | PASS |
| E470 | T008 | unit | unit | normal | 2026-10-28T08:40:31+00:00 | 0e7cacb | be79870455ad6c1e38fb2d9c | docs/regression-1.0.md | PASS |
| E471 | T009 | inspection | inspection | normal | 2026-10-28T08:40:31+00:00 | 0e7cacb | 295f0261e599d439134dc648 | docs/regression-1.0.md | PASS |
| E472 | T010 | build | build | normal | 2026-10-28T08:40:32+00:00 | 0e7cacb | 336292adb674b669feef8537 | docs/regression-1.0.md | PASS |
| E473 | T010 | inspection | inspection | normal | 2026-10-28T08:40:32+00:00 | 0e7cacb | 336292adb674b669feef8537 | docs/regression-1.0.md | PASS |
| E474 | T010 | macos | ui | normal | 2026-10-28T08:40:32+00:00 | 0e7cacb | 336292adb674b669feef8537 | docs/regression-1.0.md | PASS |
| E475 | T010 | unit | unit | normal | 2026-10-28T08:40:32+00:00 | 0e7cacb | 336292adb674b669feef8537 | docs/regression-1.0.md | PASS |
| E476 | T011 | build | build | normal | 2026-10-28T08:40:32+00:00 | 0e7cacb | 1e79a652a83a1935604b5099 | docs/regression-1.0.md | PASS |
| E477 | T011 | unit | unit | normal | 2026-10-28T08:40:33+00:00 | 0e7cacb | 1e79a652a83a1935604b5099 | docs/regression-1.0.md | PASS |
| E478 | T012 | inspection | inspection | normal | 2026-10-28T08:40:33+00:00 | 0e7cacb | bc57f9a46fc168fe93cd010c | docs/regression-1.0.md | PASS |
| E479 | T012 | macos | ui | normal | 2026-10-28T08:40:33+00:00 | 0e7cacb | bc57f9a46fc168fe93cd010c | docs/regression-1.0.md | PASS |
| E480 | T013 | build | build | normal | 2026-10-28T08:40:33+00:00 | 0e7cacb | f77ed5582d6610b3a2c95413 | docs/regression-1.0.md | PASS |
| E481 | T013 | inspection | inspection | normal | 2026-10-28T08:40:34+00:00 | 0e7cacb | f77ed5582d6610b3a2c95413 | docs/regression-1.0.md | PASS |
| E482 | T014 | build | build | normal | 2026-10-28T08:40:34+00:00 | 0e7cacb | 167c0b10e4cb98d7457fecb6 | docs/regression-1.0.md | PASS |
| E483 | T014 | macos | ui | normal | 2026-10-28T08:40:34+00:00 | 0e7cacb | 167c0b10e4cb98d7457fecb6 | docs/regression-1.0.md | PASS |
| E484 | T014 | unit | unit | normal | 2026-10-28T08:40:34+00:00 | 0e7cacb | 167c0b10e4cb98d7457fecb6 | docs/regression-1.0.md | PASS |
| E485 | T015 | inspection | inspection | normal | 2026-10-28T08:40:34+00:00 | 0e7cacb | 586d245f3fcdbea7d65407f5 | docs/regression-1.0.md | PASS |
| E486 | T015 | macos | ui | normal | 2026-10-28T08:40:35+00:00 | 0e7cacb | 586d245f3fcdbea7d65407f5 | docs/regression-1.0.md | PASS |
| E487 | T016 | build | build | normal | 2026-10-28T08:40:35+00:00 | 0e7cacb | 4ae39cb16f642055d999bb77 | docs/regression-1.0.md | PASS |
| E488 | T016 | macos | ui | normal | 2026-10-28T08:40:35+00:00 | 0e7cacb | 4ae39cb16f642055d999bb77 | docs/regression-1.0.md | PASS |
| E489 | T016 | unit | unit | normal | 2026-10-28T08:40:35+00:00 | 0e7cacb | 4ae39cb16f642055d999bb77 | docs/regression-1.0.md | PASS |
| E490 | T017 | build | build | normal | 2026-10-28T08:40:36+00:00 | 0e7cacb | 6441dc0243bb6fa8c092f651 | docs/regression-1.0.md | PASS |
| E491 | T017 | macos | ui | normal | 2026-10-28T08:40:36+00:00 | 0e7cacb | 6441dc0243bb6fa8c092f651 | docs/regression-1.0.md | PASS |
| E492 | T017 | unit | unit | normal | 2026-10-28T08:40:36+00:00 | 0e7cacb | 6441dc0243bb6fa8c092f651 | docs/regression-1.0.md | PASS |
| E493 | T018 | build | build | normal | 2026-10-28T08:40:36+00:00 | 0e7cacb | b3a4c2ee1d380b97f1c1ddb2 | docs/regression-1.0.md | PASS |
| E494 | T018 | inspection | inspection | normal | 2026-10-28T08:40:36+00:00 | 0e7cacb | b3a4c2ee1d380b97f1c1ddb2 | docs/regression-1.0.md | PASS |
| E495 | T018 | macos | ui | normal | 2026-10-28T08:40:37+00:00 | 0e7cacb | b3a4c2ee1d380b97f1c1ddb2 | docs/regression-1.0.md | PASS |
| E496 | T018 | unit | unit | normal | 2026-10-28T08:40:37+00:00 | 0e7cacb | b3a4c2ee1d380b97f1c1ddb2 | docs/regression-1.0.md | PASS |
| E497 | T019 | build | build | normal | 2026-10-28T08:40:37+00:00 | 0e7cacb | e92690c0bfdcf1f96eaef383 | docs/regression-1.0.md | PASS |
| E498 | T019 | macos | ui | normal | 2026-10-28T08:40:37+00:00 | 0e7cacb | e92690c0bfdcf1f96eaef383 | docs/regression-1.0.md | PASS |
| E499 | T019 | unit | unit | normal | 2026-10-28T08:40:37+00:00 | 0e7cacb | e92690c0bfdcf1f96eaef383 | docs/regression-1.0.md | PASS |
| E500 | T020 | build | build | normal | 2026-10-28T08:40:38+00:00 | 0e7cacb | 9729c4e432bb32f37c6db2b4 | docs/t020-evidence.md | PASS |
| E501 | T020 | macos | ui | normal | 2026-10-28T08:40:38+00:00 | 0e7cacb | 9729c4e432bb32f37c6db2b4 | docs/t020-evidence.md | PASS |
| E502 | T020 | unit | unit | normal | 2026-10-28T08:40:38+00:00 | 0e7cacb | 9729c4e432bb32f37c6db2b4 | docs/t020-evidence.md | PASS |
| E503 | T002 | build | build | normal | 2026-10-28T08:50:49+00:00 | f89c452 | 584482ea165eb18018769fd6 | docs/regression-1.0.md | PASS |
| E504 | T002 | macos | ui | normal | 2026-10-28T08:50:49+00:00 | f89c452 | 584482ea165eb18018769fd6 | docs/regression-1.0.md | PASS |
| E505 | T002 | unit | unit | normal | 2026-10-28T08:50:49+00:00 | f89c452 | 584482ea165eb18018769fd6 | docs/regression-1.0.md | PASS |
| E506 | T003 | macos | ui | normal | 2026-10-28T08:50:50+00:00 | f89c452 | 1755f36d4eaeb7bdcd24217c | docs/regression-1.0.md | PASS |
| E507 | T003 | unit | unit | normal | 2026-10-28T08:50:50+00:00 | f89c452 | 1755f36d4eaeb7bdcd24217c | docs/regression-1.0.md | PASS |
| E508 | T004 | unit | unit | normal | 2026-10-28T08:50:50+00:00 | f89c452 | ac28fb453b92edc2477c49d7 | docs/regression-1.0.md | PASS |
| E509 | T005 | macos | ui | normal | 2026-10-28T08:50:50+00:00 | f89c452 | c188cffd95a96b07ff197372 | docs/regression-1.0.md | PASS |
| E510 | T006 | inspection | inspection | normal | 2026-10-28T08:50:51+00:00 | f89c452 | 36cb2d5d3391fa25ba6fbd46 | docs/regression-1.0.md | PASS |
| E511 | T006 | macos | ui | normal | 2026-10-28T08:50:51+00:00 | f89c452 | 36cb2d5d3391fa25ba6fbd46 | docs/regression-1.0.md | PASS |
| E512 | T007 | build | build | normal | 2026-10-28T08:50:51+00:00 | f89c452 | ef516c057ab92c4e07ed01b3 | docs/regression-1.0.md | PASS |
| E513 | T007 | unit | unit | normal | 2026-10-28T08:50:52+00:00 | f89c452 | ef516c057ab92c4e07ed01b3 | docs/regression-1.0.md | PASS |
| E514 | T008 | macos | ui | normal | 2026-10-28T08:50:52+00:00 | f89c452 | 436dc71af2603fcbdbe81d0e | docs/regression-1.0.md | PASS |
| E515 | T008 | unit | unit | normal | 2026-10-28T08:50:52+00:00 | f89c452 | 436dc71af2603fcbdbe81d0e | docs/regression-1.0.md | PASS |
| E516 | T009 | inspection | inspection | normal | 2026-10-28T08:50:52+00:00 | f89c452 | 853727d4b087a82822c2a6e2 | docs/regression-1.0.md | PASS |
| E517 | T010 | build | build | normal | 2026-10-28T08:50:53+00:00 | f89c452 | cb3b5afbbf5271f4e96a0984 | docs/regression-1.0.md | PASS |
| E518 | T010 | inspection | inspection | normal | 2026-10-28T08:50:53+00:00 | f89c452 | cb3b5afbbf5271f4e96a0984 | docs/regression-1.0.md | PASS |
| E519 | T010 | macos | ui | normal | 2026-10-28T08:50:53+00:00 | f89c452 | cb3b5afbbf5271f4e96a0984 | docs/regression-1.0.md | PASS |
| E520 | T010 | unit | unit | normal | 2026-10-28T08:50:53+00:00 | f89c452 | cb3b5afbbf5271f4e96a0984 | docs/regression-1.0.md | PASS |
| E521 | T011 | build | build | normal | 2026-10-28T08:50:53+00:00 | f89c452 | 329b1e422aa16b5312f4b77d | docs/regression-1.0.md | PASS |
| E522 | T011 | unit | unit | normal | 2026-10-28T08:50:54+00:00 | f89c452 | 329b1e422aa16b5312f4b77d | docs/regression-1.0.md | PASS |
| E523 | T012 | inspection | inspection | normal | 2026-10-28T08:50:54+00:00 | f89c452 | 55539645dbe0877544b109c8 | docs/regression-1.0.md | PASS |
| E524 | T012 | macos | ui | normal | 2026-10-28T08:50:54+00:00 | f89c452 | 55539645dbe0877544b109c8 | docs/regression-1.0.md | PASS |
| E525 | T013 | build | build | normal | 2026-10-28T08:50:54+00:00 | f89c452 | 57407efa90884fdc91390919 | docs/regression-1.0.md | PASS |
| E526 | T013 | inspection | inspection | normal | 2026-10-28T08:50:54+00:00 | f89c452 | 57407efa90884fdc91390919 | docs/regression-1.0.md | PASS |
| E527 | T014 | build | build | normal | 2026-10-28T08:50:55+00:00 | f89c452 | f7ae3753f67ed0c4274241fc | docs/regression-1.0.md | PASS |
| E528 | T014 | macos | ui | normal | 2026-10-28T08:50:55+00:00 | f89c452 | f7ae3753f67ed0c4274241fc | docs/regression-1.0.md | PASS |
| E529 | T014 | unit | unit | normal | 2026-10-28T08:50:55+00:00 | f89c452 | f7ae3753f67ed0c4274241fc | docs/regression-1.0.md | PASS |
| E530 | T015 | inspection | inspection | normal | 2026-10-28T08:50:55+00:00 | f89c452 | d692723a7a7dc67c35fdb534 | docs/regression-1.0.md | PASS |
| E531 | T015 | macos | ui | normal | 2026-10-28T08:50:55+00:00 | f89c452 | d692723a7a7dc67c35fdb534 | docs/regression-1.0.md | PASS |
| E532 | T016 | build | build | normal | 2026-10-28T08:50:56+00:00 | f89c452 | ac8d721e4ae85ab4547ade2c | docs/regression-1.0.md | PASS |
| E533 | T016 | macos | ui | normal | 2026-10-28T08:50:56+00:00 | f89c452 | ac8d721e4ae85ab4547ade2c | docs/regression-1.0.md | PASS |
| E534 | T016 | unit | unit | normal | 2026-10-28T08:50:56+00:00 | f89c452 | ac8d721e4ae85ab4547ade2c | docs/regression-1.0.md | PASS |
| E535 | T017 | build | build | normal | 2026-10-28T08:50:57+00:00 | f89c452 | 495e2507b5cc5739cab41e6d | docs/regression-1.0.md | PASS |
| E536 | T017 | macos | ui | normal | 2026-10-28T08:50:57+00:00 | f89c452 | 495e2507b5cc5739cab41e6d | docs/regression-1.0.md | PASS |
| E537 | T017 | unit | unit | normal | 2026-10-28T08:50:57+00:00 | f89c452 | 495e2507b5cc5739cab41e6d | docs/regression-1.0.md | PASS |
| E538 | T018 | build | build | normal | 2026-10-28T08:50:57+00:00 | f89c452 | 14c143dcd8d64cfe5bb56be1 | docs/regression-1.0.md | PASS |
| E539 | T018 | inspection | inspection | normal | 2026-10-28T08:50:57+00:00 | f89c452 | 14c143dcd8d64cfe5bb56be1 | docs/regression-1.0.md | PASS |
| E540 | T018 | macos | ui | normal | 2026-10-28T08:50:58+00:00 | f89c452 | 14c143dcd8d64cfe5bb56be1 | docs/regression-1.0.md | PASS |
| E541 | T018 | unit | unit | normal | 2026-10-28T08:50:58+00:00 | f89c452 | 14c143dcd8d64cfe5bb56be1 | docs/regression-1.0.md | PASS |
| E542 | T019 | build | build | normal | 2026-10-28T08:50:58+00:00 | f89c452 | a9b53728ee00d5fd3ab0fdb2 | docs/regression-1.0.md | PASS |
| E543 | T019 | macos | ui | normal | 2026-10-28T08:50:58+00:00 | f89c452 | a9b53728ee00d5fd3ab0fdb2 | docs/regression-1.0.md | PASS |
| E544 | T019 | unit | unit | normal | 2026-10-28T08:50:58+00:00 | f89c452 | a9b53728ee00d5fd3ab0fdb2 | docs/regression-1.0.md | PASS |
| E545 | T020 | build | build | normal | 2026-10-28T08:50:59+00:00 | f89c452 | bd594918d74bc1d6402f27af | docs/t020-evidence.md | PASS |
| E546 | T020 | macos | ui | normal | 2026-10-28T08:50:59+00:00 | f89c452 | bd594918d74bc1d6402f27af | docs/t020-evidence.md | PASS |
| E547 | T020 | unit | unit | normal | 2026-10-28T08:50:59+00:00 | f89c452 | bd594918d74bc1d6402f27af | docs/t020-evidence.md | PASS |

## Reviews

| ID | Scope | Kind | Result | Fingerprint | Report |
|---|---|---|---|---|---|
| RV001 | PLAN | independent | PASS | 868cd541ebea7834cd9fa4fb | docs/plan-review.md |
| RV002 | UC01 | independent | PASS | f5c1ae38d1621ad592ae2706 | docs/plan-review.md |
| RV003 | PLAN | independent | PASS | 3e63722008838f721dc8f973 | docs/plan-review.md |
| RV004 | UC01 | independent | PASS | f5c1ae38d1621ad592ae2706 | docs/plan-review.md |
| RV005 | PLAN | independent | PASS | 6581de0901b78cf09c1d76d6 | docs/final-review.md |
| RV006 | UC01 | independent | PASS | ac5bfc22d0d40b781b1278d7 | docs/final-review.md |
| RV007 | UC02 | independent | PASS | 73091ab88b4aa40d34c5e3d4 | docs/final-review.md |
| RV008 | UC03 | independent | PASS | acd3c1dbc1a71330a4328483 | docs/final-review.md |
| RV009 | UC04 | independent | PASS | 4d3de6b2de93179bba59bc9e | docs/final-review.md |
| RV010 | UC05 | independent | PASS | 1ca50f789bc6eff20c09e441 | docs/final-review.md |
| RV011 | PLAN | independent | PASS | 932783d293a6a9db349e6b03 | docs/agent-plan-review.md |
| RV012 | PLAN | independent | PASS | d7680e1d2e351baaf8f9eab5 | docs/agent-plan-review.md |
| RV013 | UC06 | independent | BLOCKED | e45554fc4b4b5c5accf61d5c | docs/agent-final-review.md |
| RV014 | UC07 | independent | BLOCKED | fc3736b463b74c1ed18a52b4 | docs/agent-final-review.md |
| RV015 | UC01 | independent | PASS | 05af9742702e85507d796de8 | docs/agent-final-review.md |
| RV016 | UC02 | independent | PASS | 0dec82db5bc88e04255fb59f | docs/agent-final-review.md |
| RV017 | UC03 | independent | PASS | e97dbb88b13e91d105e1bd98 | docs/agent-final-review.md |
| RV018 | UC04 | independent | PASS | 85f299fe28bb92062d59c9f8 | docs/agent-final-review.md |
| RV019 | UC05 | independent | PASS | 0008248ff88575c281bab4fc | docs/agent-final-review.md |
| RV020 | UC06 | independent | PASS | a4d14d10966a13387553c3aa | docs/agent-final-review.md |
| RV021 | UC07 | independent | PASS | f51be46e924c6c2cc65e106f | docs/agent-final-review.md |
| RV022 | UC01 | independent | PASS | aaf097d26715c8cd60c4c946 | docs/agent-final-review.md |
| RV023 | UC02 | independent | PASS | 16416adcefa9413ba304e758 | docs/agent-final-review.md |
| RV024 | UC03 | independent | PASS | c80733a846b8c5877fb4de61 | docs/agent-final-review.md |
| RV025 | UC04 | independent | PASS | 91787f85bf7c3e12ce3d8885 | docs/agent-final-review.md |
| RV026 | UC05 | independent | PASS | 37613c07b9e5f667b2531838 | docs/agent-final-review.md |
| RV027 | UC06 | independent | PASS | 721266b39b4261a309cda8e4 | docs/agent-final-review.md |
| RV028 | UC07 | independent | PASS | 41ee6825e8057bf5273d9f0e | docs/agent-final-review.md |
| RV029 | PLAN | self | PASS | 049c4cafe7b9d228716a8843 | docs/plan-0.3-review.md |
| RV030 | UC02 | self | PASS | 31da26645901fd2f4fd74d2d | docs/uc-regression-0.3-review.md |
| RV031 | UC03 | self | PASS | c80733a846b8c5877fb4de61 | docs/uc-regression-0.3-review.md |
| RV032 | UC04 | self | PASS | 245d73648e25ce24680b5d88 | docs/uc-regression-0.3-review.md |
| RV033 | UC05 | self | PASS | d0129b5107bb44f8e742d765 | docs/uc-regression-0.3-review.md |
| RV034 | UC06 | self | PASS | 5f6e326103b45f41ee1255af | docs/uc-regression-0.3-review.md |
| RV035 | UC07 | self | PASS | acd8b7d4d0ad3835e831b178 | docs/uc-regression-0.3-review.md |
| RV036 | UC08 | self | PASS | 6fff026792a3f62d90f97d99 | docs/uc-regression-0.3-review.md |
| RV037 | UC05 | self | PASS | 5a88ccc2b824d1bbec9bc896 | docs/uc-regression-0.3-review.md |
| RV038 | UC06 | self | PASS | b547c185a4048a493bf62d7d | docs/uc-regression-0.3-review.md |
| RV039 | UC07 | self | PASS | 5d06fb7c79b3f22154171efc | docs/uc-regression-0.3-review.md |
| RV040 | UC08 | self | PASS | 8a8a496280e6fb63fcf1d30e | docs/uc-regression-0.3-review.md |
| RV041 | UC02 | self | PASS | 4c2e8b387d3d54a3922035c1 | docs/uc-regression-0.3-review.md |
| RV042 | UC03 | self | PASS | 7e00b484e4919e25bfa3afe4 | docs/uc-regression-0.3-review.md |
| RV043 | UC04 | self | PASS | 25300001fc7c33a90b0c0453 | docs/uc-regression-0.3-review.md |
| RV044 | UC05 | self | PASS | e707592ee2ad4a5d9ff14d61 | docs/uc-regression-0.3-review.md |
| RV045 | UC06 | self | PASS | d7329a2c7ffbb1f713978949 | docs/uc-regression-0.3-review.md |
| RV046 | UC07 | self | PASS | 25a7338f04a0145ab9678bed | docs/uc-regression-0.3-review.md |
| RV047 | UC08 | self | PASS | c99515c89c97308eaeefa8f4 | docs/uc-regression-0.3-review.md |
| RV048 | UC08 | self | PASS | c99515c89c97308eaeefa8f4 | docs/uc-regression-0.3-review.md |
| RV049 | UC09 | self | PASS | bd6a9d005d22af32daa46258 | docs/uc-regression-0.3-review.md |
| RV050 | UC10 | self | PASS | e04c80c19f6cbbe621282764 | docs/uc-regression-0.3-review.md |
| RV051 | UC05 | self | PASS | c105d51bf78dba7812b27d9d | docs/uc-regression-0.3-review.md |
| RV052 | UC07 | self | PASS | 83bfd2379c0402b7fcb2b014 | docs/uc-regression-0.3-review.md |
| RV053 | PLAN | self | PASS | 879afd0b8b732b9131d45127 | docs/plan-0.3-review.md |
| RV054 | UC02 | self | PASS | b6c4e225253757ee998d4015 | docs/regression-0.4.md |
| RV055 | UC04 | self | PASS | bdcb8f3b456680717f33d51c | docs/regression-0.4.md |
| RV056 | UC05 | self | PASS | 35d6220f2d59db688e323e89 | docs/regression-0.4.md |
| RV057 | UC06 | self | PASS | b11b2eac5dd51150d0ab855f | docs/regression-0.4.md |
| RV058 | UC07 | self | PASS | ab24c71a26b4dd1eb8825e20 | docs/regression-0.4.md |
| RV059 | UC08 | self | PASS | 301cf2a60e1f4429e2f99be7 | docs/regression-0.4.md |
| RV060 | UC09 | self | PASS | 13bdf1ed0f275224a927bc89 | docs/regression-0.4.md |
| RV061 | UC10 | self | PASS | 54927cc1e8da886fda37700c | docs/regression-0.4.md |
| RV062 | UC11 | self | PASS | 06b0ddaa56e490e28df3bef5 | docs/t016-evidence.md |
| RV063 | UC05 | self | PASS | 8b13ce80358fce213bf91df6 | docs/regression-0.4.md |
| RV064 | UC07 | self | PASS | 75be503219e4f4a4ef6a55b3 | docs/regression-0.4.md |
| RV065 | PLAN | self | PASS | 13c3738aed287fbb740a48c2 | docs/plan-0.3-review.md |
| RV066 | UC02 | self | PASS | 40bfb83ff425c824f979f825 | docs/regression-0.4.1.md |
| RV067 | UC03 | self | PASS | c8c7484f19eaba2219308d43 | docs/regression-0.4.1.md |
| RV068 | UC04 | self | PASS | d3262d72e84796110e5eb9cc | docs/regression-0.4.1.md |
| RV069 | UC05 | self | PASS | dab3b0b6fb282bb326b70199 | docs/regression-0.4.1.md |
| RV070 | UC06 | self | PASS | 5ecc31c13373fcd08c0187ab | docs/regression-0.4.1.md |
| RV071 | UC07 | self | PASS | 25fd65420be475e40499b4a1 | docs/regression-0.4.1.md |
| RV072 | UC08 | self | PASS | 6185a4446b8c0abc590abc5c | docs/regression-0.4.1.md |
| RV073 | UC09 | self | PASS | 1252bae201069e06e44264e4 | docs/regression-0.4.1.md |
| RV074 | UC10 | self | PASS | ae57598331eb5a7704506f66 | docs/regression-0.4.1.md |
| RV075 | UC11 | self | PASS | e10763b27e9d9bd00c141ef5 | docs/regression-0.4.1.md |
| RV076 | UC12 | self | PASS | 79a761ca72a2f4166432529a | docs/t017-evidence.md |
| RV077 | UC05 | self | PASS | 804c8ba76fec17057b0f85d9 | docs/regression-0.4.1.md |
| RV078 | UC07 | self | PASS | 4b8c64f13a02b7bbee9e941d | docs/regression-0.4.1.md |
| RV079 | PLAN | self | PASS | 6c21bf6135039e9785ed5727 | docs/plan-0.3-review.md |
| RV080 | UC02 | self | PASS | aefd13ba8780a336ba497a56 | docs/regression-1.0.md |
| RV081 | UC03 | self | PASS | edbb291c7b50e5a0907c8484 | docs/regression-1.0.md |
| RV082 | UC04 | self | PASS | 3804b38a418449e290f51911 | docs/regression-1.0.md |
| RV083 | UC05 | self | PASS | 5713fd86b797c67ca38242ca | docs/regression-1.0.md |
| RV084 | UC06 | self | PASS | 07055fdf45afe3966c071cdc | docs/regression-1.0.md |
| RV085 | UC07 | self | PASS | e9cc416b0318d175d2adab3e | docs/regression-1.0.md |
| RV086 | UC08 | self | PASS | 09602cc8f9af8104cf9e6369 | docs/regression-1.0.md |
| RV087 | UC09 | self | PASS | 15b04fb473420d4b8b60b261 | docs/regression-1.0.md |
| RV088 | UC10 | self | PASS | a3bb2150af459f754f9e4d34 | docs/regression-1.0.md |
| RV089 | UC11 | self | PASS | 3cdaeffb59a0461101256b56 | docs/regression-1.0.md |
| RV090 | UC12 | self | PASS | b0d442e4346560fae6394f75 | docs/regression-1.0.md |
| RV091 | UC13 | self | PASS | cef1cea13a790efee7f7e960 | docs/t018-evidence.md |
| RV092 | UC05 | self | PASS | 666c57fa41a8792c94565e35 | docs/regression-1.0.md |
| RV093 | UC07 | self | PASS | 4bc3fd7101e23c2eb5965528 | docs/regression-1.0.md |
| RV094 | PLAN | self | PASS | f3c4dc68fb0837037e337598 | docs/plan-0.3-review.md |
| RV095 | UC02 | self | PASS | 6fac08f9fd2cdf813d81896f | docs/regression-1.0.md |
| RV096 | UC03 | self | PASS | 5b05af87423978227959c972 | docs/regression-1.0.md |
| RV097 | UC04 | self | PASS | f3aeef8cb44483aeac7c5d6a | docs/regression-1.0.md |
| RV098 | UC05 | self | PASS | 7f87f26846312f7fc8ea66b0 | docs/regression-1.0.md |
| RV099 | UC06 | self | PASS | ced0cc17ae3fb3637881e636 | docs/regression-1.0.md |
| RV100 | UC07 | self | PASS | c3c36133514721b8e7206d5b | docs/regression-1.0.md |
| RV101 | UC08 | self | PASS | 9cdd0afc6e1bbf5331e43a5a | docs/regression-1.0.md |
| RV102 | UC09 | self | PASS | f98342576af34641011e8a2d | docs/regression-1.0.md |
| RV103 | UC10 | self | PASS | e99b86b2d0cee719cd2ddb27 | docs/regression-1.0.md |
| RV104 | UC11 | self | PASS | 4fd11fde842ce52c63f857fa | docs/regression-1.0.md |
| RV105 | UC12 | self | PASS | db95378438ae00e5debad357 | docs/regression-1.0.md |
| RV106 | UC13 | self | PASS | 53f16ecea00366036842710e | docs/regression-1.0.md |
| RV107 | UC14 | self | PASS | 8d7274c4d1a1c337bc93fece | docs/t019-evidence.md |
| RV108 | UC05 | self | PASS | 8eacd077c8eb485737cbe4ff | docs/regression-1.0.md |
| RV109 | UC07 | self | PASS | 73bbe5b077d29ebf1356324b | docs/regression-1.0.md |
| RV110 | PLAN | self | PASS | 814e02a8d8c35484cc7e5835 | docs/plan-0.3-review.md |
| RV111 | UC02 | self | PASS | 2bb5f9a3d5ca111a25795927 | docs/regression-1.0.md |
| RV112 | UC03 | self | PASS | e0b0e33969bbb26ef8f94029 | docs/regression-1.0.md |
| RV113 | UC04 | self | PASS | 357ccf1dddda99e5ec42e2e0 | docs/regression-1.0.md |
| RV114 | UC05 | self | PASS | f1e37cabbf03a45574f82e42 | docs/regression-1.0.md |
| RV115 | UC06 | self | PASS | fc3a9ec8f2b26e0e16238a22 | docs/regression-1.0.md |
| RV116 | UC07 | self | PASS | c15135e016cac859c2831ea9 | docs/regression-1.0.md |
| RV117 | UC08 | self | PASS | e8c1ae1a6f5f7e9cd874ebcd | docs/regression-1.0.md |
| RV118 | UC09 | self | PASS | 651567c4214ae2961c00cd28 | docs/regression-1.0.md |
| RV119 | UC10 | self | PASS | 385716c0b84362febeae8fe8 | docs/regression-1.0.md |
| RV120 | UC11 | self | PASS | 901720ad6d19eceff088fade | docs/regression-1.0.md |
| RV121 | UC12 | self | PASS | 711d8e5f0acf330980739e7f | docs/regression-1.0.md |
| RV122 | UC13 | self | PASS | cf2565c522a518db854b1607 | docs/regression-1.0.md |
| RV123 | UC14 | self | PASS | aa7c34cb8ae0ad48a6409943 | docs/regression-1.0.md |
| RV124 | UC15 | self | PASS | ff2a50dbb6fb5dc8d721c225 | docs/t020-evidence.md |
| RV125 | UC05 | self | PASS | 3e96a99796b929aaacd77aee | docs/regression-1.0.md |
| RV126 | UC07 | self | PASS | c554684c455fa54955e0b41b | docs/regression-1.0.md |
| RV127 | UC02 | self | PASS | e6520c43de2363764d991c43 | docs/regression-1.0.md |
| RV128 | UC03 | self | PASS | cc0665499147e761252b3524 | docs/regression-1.0.md |
| RV129 | UC04 | self | PASS | 48cddb89a8714943cb0ae3ce | docs/regression-1.0.md |
| RV130 | UC05 | self | PASS | a663bd544df1c95fe45750ff | docs/regression-1.0.md |
| RV131 | UC06 | self | PASS | 252a0b2c8d3cbfb543b4e473 | docs/regression-1.0.md |
| RV132 | UC07 | self | PASS | a633488b1e3d94dea6aad08c | docs/regression-1.0.md |
| RV133 | UC08 | self | PASS | f50ece4e7f91b902f6c5d91f | docs/regression-1.0.md |
| RV134 | UC09 | self | PASS | 2aaa59be732760a5b7dae2e5 | docs/regression-1.0.md |
| RV135 | UC10 | self | PASS | c27373a5a8e40dc85b74960d | docs/regression-1.0.md |
| RV136 | UC11 | self | PASS | 0fc84015b5aef717e7054ac8 | docs/regression-1.0.md |
| RV137 | UC12 | self | PASS | 4d55706d3db01a3eac9e2a5f | docs/regression-1.0.md |
| RV138 | UC13 | self | PASS | a4bc85c95f010a5f505d3f01 | docs/regression-1.0.md |
| RV139 | UC14 | self | PASS | d826b9df2dc7a5293c2bcd8e | docs/regression-1.0.md |
| RV140 | UC15 | self | PASS | 2ea0b6f86548ba9f856845b7 | docs/t020-evidence.md |
| RV141 | UC05 | self | PASS | a6e4c39f6dee48aa420a9ac5 | docs/regression-1.0.md |
| RV142 | UC07 | self | PASS | 6723b8f1b9173313c20f1204 | docs/regression-1.0.md |
| RV143 | UC02 | self | PASS | 0b9fbc85f1f739a5468ca707 | docs/regression-1.0.md |
| RV144 | UC03 | self | PASS | edf969fd0fe8d9a715043695 | docs/regression-1.0.md |
| RV145 | UC04 | self | PASS | 350b0a2567aa312c6b26bdee | docs/regression-1.0.md |
| RV146 | UC05 | self | PASS | e314549a5f360376e9ecb647 | docs/regression-1.0.md |
| RV147 | UC06 | self | PASS | 9150f8facec309af2102fa52 | docs/regression-1.0.md |
| RV148 | UC07 | self | PASS | 8cea6e714f82e96dbd7ba625 | docs/regression-1.0.md |
| RV149 | UC08 | self | PASS | 9dd475463e1134c27590d4bc | docs/regression-1.0.md |
| RV150 | UC09 | self | PASS | 4cb83cab55c4e27bab75282a | docs/regression-1.0.md |
| RV151 | UC10 | self | PASS | 123bfd77438f6e154e04a7a8 | docs/regression-1.0.md |
| RV152 | UC11 | self | PASS | fb8c2436660cc685282ba74e | docs/regression-1.0.md |
| RV153 | UC12 | self | PASS | f589285da94f52c50b8c3855 | docs/regression-1.0.md |
| RV154 | UC13 | self | PASS | 11fe1a7c23c7b481613decea | docs/regression-1.0.md |
| RV155 | UC14 | self | PASS | 73161da8a014845840547134 | docs/regression-1.0.md |
| RV156 | UC15 | self | PASS | 207e58ed392ed8201779cae8 | docs/t020-evidence.md |
| RV157 | UC05 | self | PASS | b6054dddfadc362d2630880c | docs/regression-1.0.md |
| RV158 | UC07 | self | PASS | f1f5ef15a5b3717bf29cb5c8 | docs/regression-1.0.md |
| RV159 | UC02 | self | PASS | 48a8c28af294e2ba99168c72 | docs/regression-1.0.md |
| RV160 | UC03 | self | PASS | 89d7c9ddda06622532073716 | docs/regression-1.0.md |
| RV161 | UC04 | self | PASS | ca1b37095423616333b0752d | docs/regression-1.0.md |
| RV162 | UC05 | self | PASS | fadc99482ababbcfa81e5df4 | docs/regression-1.0.md |
| RV163 | UC06 | self | PASS | f59af3455f197d8c6e522703 | docs/regression-1.0.md |
| RV164 | UC07 | self | PASS | 72b4639babaaae92ecf30835 | docs/regression-1.0.md |
| RV165 | UC08 | self | PASS | 023add27a5c5f7fdf89dc44c | docs/regression-1.0.md |
| RV166 | UC09 | self | PASS | 4c4240f08d01432801f53f90 | docs/regression-1.0.md |
| RV167 | UC10 | self | PASS | 3715acea02454da0a6feddbc | docs/regression-1.0.md |
| RV168 | UC11 | self | PASS | f29015bfc4afe2860d9cb59b | docs/regression-1.0.md |
| RV169 | UC12 | self | PASS | 46257b244a9169ad67a894ec | docs/regression-1.0.md |
| RV170 | UC13 | self | PASS | 2e78f95a0d997a120e0b70d4 | docs/regression-1.0.md |
| RV171 | UC14 | self | PASS | df4590013b7692e0e7522752 | docs/regression-1.0.md |
| RV172 | UC15 | self | PASS | f8f263228abadbdded9debfb | docs/t020-evidence.md |
| RV173 | UC05 | self | PASS | d251919f719e681761a26e7e | docs/regression-1.0.md |
| RV174 | UC07 | self | PASS | 0750c9310cc2b13d93306d14 | docs/regression-1.0.md |
| RV175 | UC02 | self | PASS | 8511257b2b6c19be2567ca2e | docs/regression-1.0.md |
| RV176 | UC03 | self | PASS | 501df0c80eb490e925251ef3 | docs/regression-1.0.md |
| RV177 | UC04 | self | PASS | 4700650bdda1eb211ba58ceb | docs/regression-1.0.md |
| RV178 | UC05 | self | PASS | 218eac718994c7754d74a769 | docs/regression-1.0.md |
| RV179 | UC06 | self | PASS | 756f3c69c512333e5bbec613 | docs/regression-1.0.md |
| RV180 | UC07 | self | PASS | 6ae0b30985e98714c90110df | docs/regression-1.0.md |
| RV181 | UC08 | self | PASS | 6a63b23de9384a6f5f7a8a94 | docs/regression-1.0.md |
| RV182 | UC09 | self | PASS | f1d57ce548dacb2fde324446 | docs/regression-1.0.md |
| RV183 | UC10 | self | PASS | 80731cd430b68628059028d0 | docs/regression-1.0.md |
| RV184 | UC11 | self | PASS | f6f8572760247b0197399f01 | docs/regression-1.0.md |
| RV185 | UC12 | self | PASS | 1fe1dd4250995e5088802c6f | docs/regression-1.0.md |
| RV186 | UC13 | self | PASS | 9a11000316e9920a532ea68d | docs/regression-1.0.md |
| RV187 | UC14 | self | PASS | 8edb8670a82bd9aa992c2091 | docs/regression-1.0.md |
| RV188 | UC15 | self | PASS | f3b93ad3bd6c3309919edd4a | docs/t020-evidence.md |
| RV189 | UC05 | self | PASS | a2f32149d57bdd2a973acd4c | docs/regression-1.0.md |
| RV190 | UC07 | self | PASS | 32b991ded290cd30da735726 | docs/regression-1.0.md |
| RV191 | UC02 | self | PASS | bf250ea013d3d3611776b7d5 | docs/regression-1.0.md |
| RV192 | UC03 | self | PASS | e804a29e5220e2c7768427e0 | docs/regression-1.0.md |
| RV193 | UC04 | self | PASS | abfac5ccf34d28fc12129ddb | docs/regression-1.0.md |
| RV194 | UC05 | self | PASS | 7b6be0c6c35b856e88ee63cf | docs/regression-1.0.md |
| RV195 | UC06 | self | PASS | a53b6afec95744c02da1ff62 | docs/regression-1.0.md |
| RV196 | UC07 | self | PASS | ba8088c0386bc83f0535d57a | docs/regression-1.0.md |
| RV197 | UC08 | self | PASS | d9525d368f19c1350c0e5f2f | docs/regression-1.0.md |
| RV198 | UC09 | self | PASS | 8c4c0a7f1b6d5adcb4220312 | docs/regression-1.0.md |
| RV199 | UC10 | self | PASS | 6f7f757db3d87d65d476a70a | docs/regression-1.0.md |
| RV200 | UC11 | self | PASS | 1b1726763ab2a8ef8b40e4c1 | docs/regression-1.0.md |
| RV201 | UC12 | self | PASS | 879fd54b44106e1923c7e40b | docs/regression-1.0.md |
| RV202 | UC13 | self | PASS | 0c213d873c12d64b89ff0987 | docs/regression-1.0.md |
| RV203 | UC14 | self | PASS | d259e92caee1210a305fc72f | docs/regression-1.0.md |
| RV204 | UC15 | self | PASS | afac02fdd2e6360f2d10f577 | docs/t020-evidence.md |
| RV205 | UC05 | self | PASS | 8e63dfa0d2de9d74f5bd4de6 | docs/regression-1.0.md |
| RV206 | UC07 | self | PASS | 20d2d9191a4b1c451ba57f3f | docs/regression-1.0.md |
| RV207 | UC02 | self | PASS | 162f84a03f28b5a2bb29b17a | docs/regression-1.0.md |
| RV208 | UC03 | self | PASS | edae3ae6a3e846b589bbde6e | docs/regression-1.0.md |
| RV209 | UC04 | self | PASS | af77be697cc2983050e0a0cc | docs/regression-1.0.md |
| RV210 | UC05 | self | PASS | 846d49556bf579513126fd3b | docs/regression-1.0.md |
| RV211 | UC06 | self | PASS | 6133b63e154b35e72cd980c7 | docs/regression-1.0.md |
| RV212 | UC07 | self | PASS | 0c2a75b1e068723c299d582b | docs/regression-1.0.md |
| RV213 | UC08 | self | PASS | 393e5b9c8094fd799f76816c | docs/regression-1.0.md |
| RV214 | UC09 | self | PASS | d71bc07c9749f5ba539f62ae | docs/regression-1.0.md |
| RV215 | UC10 | self | PASS | b9b53d79fde75e4f356fa482 | docs/regression-1.0.md |
| RV216 | UC11 | self | PASS | eefed67ba81c51dc89ed8e5c | docs/regression-1.0.md |
| RV217 | UC12 | self | PASS | 811ced7552808877d26d7014 | docs/regression-1.0.md |
| RV218 | UC13 | self | PASS | 427ebb4f5e00429defc9ddb0 | docs/regression-1.0.md |
| RV219 | UC14 | self | PASS | b744f6bb0ac4a60b83c0927b | docs/regression-1.0.md |
| RV220 | UC15 | self | PASS | 73ae09c94e9dd595026ae571 | docs/t020-evidence.md |
| RV221 | UC05 | self | PASS | 383da75b6b6899131176acc2 | docs/regression-1.0.md |
| RV222 | UC07 | self | PASS | e6387710d45f1a48fad7fe4b | docs/regression-1.0.md |

## Releases

| ID | Delivery | Stage | Build | Locator | Evidence |
|---|---|---|---|---|---|
| L001 | D001 | LOCAL | e360dc03836bccdb | /Users/udi/Applications/Secretariat.app | E010,E011 |
| L002 | D001 | LOCAL | a4f33226e4a3b1f7 | /Users/udi/Applications/Secretariat.app | E029,E030,E024,E031 |
| L003 | D001 | LOCAL | 9c64dac | /Users/udi/Applications/Secretariat.app | E069,E070,E076,E077,E078,E079 |
| L004 | D001 | LOCAL | f363f6e | /Users/udi/Applications/Secretariat.app | E092,E093,E099,E100,E101,E102 |
| L005 | D001 | LOCAL | 0d4aefd | /Users/udi/Applications/Secretariat.app | E124,E125,E131,E132,E133,E134 |
| L006 | D001 | LOCAL | 80e78e5 | /Users/udi/Applications/Secretariat.app | E159,E160,E166,E167,E168,E169 |
| L007 | D001 | LOCAL | 533ffaa | /Users/udi/Applications/Secretariat.app | E198,E199,E205,E206,E207,E208 |
| L008 | D001 | LOCAL | 682215f | /Users/udi/Applications/Secretariat.app | E240,E241,E247,E248,E249,E250 |
| L009 | D001 | LOCAL | 6598dc9 | /Users/udi/Applications/Secretariat.app | E285,E286,E292,E293,E294,E295 |
| L010 | D001 | LOCAL | 695e61a | /Users/udi/Applications/Secretariat.app | E330,E331,E337,E338,E339,E340 |
| L011 | D001 | LOCAL | 0980775 | /Users/udi/Applications/Secretariat.app | E375,E376,E382,E383,E384,E385 |
| L012 | D001 | LOCAL | ee067a8 | /Users/udi/Applications/Secretariat.app | E420,E421,E427,E428,E429,E430 |
| L013 | D001 | LOCAL | 0e7cacb | /Users/udi/Applications/Secretariat.app | E465,E466,E472,E473,E474,E475 |
| L014 | D001 | LOCAL | f89c452 | /Users/udi/Applications/Secretariat.app | E510,E511,E517,E518,E519,E520 |

Status, Beleg und Kritik sind unterschiedliche Angaben. `Evidence` in der Aufgabenzeile referenziert die für ihren Abschluss maßgeblichen Beleg-IDs. Ältere Belege dürfen als Historie bleiben. Bei Reviews ist die letzte Zeile je Scope maßgeblich.
