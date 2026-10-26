# Aufgaben und Nachweise

## Tasks

| ID | Status | Evidence | Reason |
|---|---|---|---|
| T001 | ERLEDIGT | E019 | Betroffene Bestandsnachweise beim Abschluss von 0.2 abgleichen und erneuern |
| T002 | ERLEDIGT | E062,E063,E064 | Signiertes 0.2-Paket normal geöffnet; künstlicher Schlüsselwert via GUI und CLI-Prozess geprüft, Verweigerungsfall und Unit-/Buildchecks bestanden |
| T003 | ERLEDIGT | E065,E066 | Schlüssel und Profil im aktuellen GUI angelegt, geändert und gelöscht; In-use-Schutz, Bindung, Neustart und Unitvalidierung geprüft |
| T004 | ERLEDIGT | E067 | Aktueller Paketdurchlauf mit acht Prozesschecks und Unitprüfungen; Fehler vor Kindstart, Signal, I/O und Datenintegrität geprüft |
| T005 | ERLEDIGT | E068 | Aktueller GUI-Neustart, schmaler Leerzustand, kopierter Aufruf und vorhandenes DailyInspirations-Projekt mit künstlichem Wert: Expo HTTP 200; Testdaten entfernt |
| T006 | ERLEDIGT | E069,E070 | 0.2-Bundle entfernt und erneut installiert, Signatur/Hash/Symlink geprüft und neu installierte GUI geöffnet; Datenpfade unberührt |
| T007 | ERLEDIGT | E071,E072 | Versionierte CLI-Auskunft, Fehlercodes und dialogfreie Profilprüfung mit aktuellem Paket und Unitprüfungen bestanden |
| T008 | ERLEDIGT | E073,E074 | Projektanweisungen in normaler GUI mit Vorschau, Abbruch, Einrichten, Idempotenz, Neustart und Konfliktschutz geprüft |
| T009 | ERLEDIGT | E075 | Codex und Claude Code mit Receipt; OpenCode real versucht, ECONNRESET ohne Receipt als Grenze dokumentiert; künstliche Fixtures bereinigt |
| T010 | ERLEDIGT | E076,E077,E078,E079 | 0.2-App signiert lokal installiert, neue GUI und alte Kernabläufe samt Realprojekt geprüft; Testdaten entfernt, kein Autostart |
| T011 | ERLEDIGT | E080,E081 | - |
| T013 | ERLEDIGT | E057,E058 | App-ID + Developer-ID-Provisioning-Profil mit keychain-access-groups fehlt; Uli: asc auth login (Key T5YN77H557) oder Anlage im Developer-Portal |
| T014 | ERLEDIGT | E059,E060,E061 | - |
| T015 | ERLEDIGT | E084,E085 | - |
| T012 | ERLEDIGT | E082,E083 | - |

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

## Releases

| ID | Delivery | Stage | Build | Locator | Evidence |
|---|---|---|---|---|---|
| L001 | D001 | LOCAL | e360dc03836bccdb | /Users/udi/Applications/Secretariat.app | E010,E011 |
| L002 | D001 | LOCAL | a4f33226e4a3b1f7 | /Users/udi/Applications/Secretariat.app | E029,E030,E024,E031 |
| L003 | D001 | LOCAL | 9c64dac | /Users/udi/Applications/Secretariat.app | E069,E070,E076,E077,E078,E079 |

Status, Beleg und Kritik sind unterschiedliche Angaben. `Evidence` in der Aufgabenzeile referenziert die für ihren Abschluss maßgeblichen Beleg-IDs. Ältere Belege dürfen als Historie bleiben. Bei Reviews ist die letzte Zeile je Scope maßgeblich.
