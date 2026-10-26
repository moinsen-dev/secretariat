# Aufgaben und Nachweise

## Tasks

| ID | Status | Evidence | Reason |
|---|---|---|---|
| T001 | ERLEDIGT | E019 | Betroffene Bestandsnachweise beim Abschluss von 0.2 abgleichen und erneuern |
| T002 | ERLEDIGT | E191,E192,E193 | Signiertes 0.2-Paket normal geöffnet; künstlicher Schlüsselwert via GUI und CLI-Prozess geprüft, Verweigerungsfall und Unit-/Buildchecks bestanden |
| T003 | ERLEDIGT | E194,E195 | Schlüssel und Profil im aktuellen GUI angelegt, geändert und gelöscht; In-use-Schutz, Bindung, Neustart und Unitvalidierung geprüft |
| T004 | ERLEDIGT | E196 | Aktueller Paketdurchlauf mit acht Prozesschecks und Unitprüfungen; Fehler vor Kindstart, Signal, I/O und Datenintegrität geprüft |
| T005 | ERLEDIGT | E197 | Aktueller GUI-Neustart, schmaler Leerzustand, kopierter Aufruf und vorhandenes DailyInspirations-Projekt mit künstlichem Wert: Expo HTTP 200; Testdaten entfernt |
| T006 | ERLEDIGT | E198,E199 | 0.2-Bundle entfernt und erneut installiert, Signatur/Hash/Symlink geprüft und neu installierte GUI geöffnet; Datenpfade unberührt |
| T007 | ERLEDIGT | E200,E201 | Versionierte CLI-Auskunft, Fehlercodes und dialogfreie Profilprüfung mit aktuellem Paket und Unitprüfungen bestanden |
| T008 | ERLEDIGT | E202,E203 | Projektanweisungen in normaler GUI mit Vorschau, Abbruch, Einrichten, Idempotenz, Neustart und Konfliktschutz geprüft |
| T009 | ERLEDIGT | E204 | Codex und Claude Code mit Receipt; OpenCode real versucht, ECONNRESET ohne Receipt als Grenze dokumentiert; künstliche Fixtures bereinigt |
| T010 | ERLEDIGT | E205,E206,E207,E208 | 0.2-App signiert lokal installiert, neue GUI und alte Kernabläufe samt Realprojekt geprüft; Testdaten entfernt, kein Autostart |
| T011 | ERLEDIGT | E209,E210 | - |
| T013 | ERLEDIGT | E213,E214 | App-ID + Developer-ID-Provisioning-Profil mit keychain-access-groups fehlt; Uli: asc auth login (Key T5YN77H557) oder Anlage im Developer-Portal |
| T014 | ERLEDIGT | E215,E216,E217 | - |
| T015 | ERLEDIGT | E218,E219 | - |
| T012 | ERLEDIGT | E211,E212 | - |
| T016 | ERLEDIGT | E220,E221,E222 | - |
| T017 | ERLEDIGT | E223,E224,E225 | - |
| T018 | ERLEDIGT | E226,E227,E228,E229 | - |
| T019 | ERLEDIGT | E230,E231,E232 | - |

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

Status, Beleg und Kritik sind unterschiedliche Angaben. `Evidence` in der Aufgabenzeile referenziert die für ihren Abschluss maßgeblichen Beleg-IDs. Ältere Belege dürfen als Historie bleiben. Bei Reviews ist die letzte Zeile je Scope maßgeblich.
