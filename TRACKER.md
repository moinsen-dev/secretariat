# Aufgaben und Nachweise

## Tasks

| ID | Status | Evidence | Reason |
|---|---|---|---|
| T001 | ERLEDIGT | E019 | Betroffene Bestandsnachweise beim Abschluss von 0.2 abgleichen und erneuern |
| T002 | BLOCKIERT | - | Aktueller Build/Keychain-Paketlauf geprüft, normaler UI-Start wegen Sky Computer Use native pipe startup failed nicht beobachtet |
| T003 | BLOCKIERT | - | 0.1-UI-Belege historisch; aktuelle native Steuerung nicht verfügbar |
| T004 | BLOCKIERT | - | Paket-Prozesschecks aktuell bestanden; vorausgesetzte erneute UI-Abnahme T003 offen |
| T005 | BLOCKIERT | - | Aktueller kompletter UI-Ablauf und Neustart wegen defekter nativer Steuerung nicht beobachtbar |
| T006 | BLOCKIERT | - | App 0.2 installiert und signiert; normales erneutes Öffnen/Bedienen mangels nativer Steuerung offen |
| T007 | BLOCKIERT | E012,E013 | CLI-/Unit-Nachweise aktuell; erneute alte UI-Abnahme T006 wegen defekter Mac-Steuerung offen |
| T008 | BLOCKIERT | E014 | Unit geprüft; Native Mac-Steuerung meldet Sky Computer Use native pipe startup failed, UI-Einrichtung nicht beobachtbar |
| T009 | BLOCKIERT | E015 | Codex/Claude mit Receipt; OpenCode-Transport ECONNRESET ohne Receipt, zudem Phase P06 offen |
| T010 | BLOCKIERT | E016,E017,E018 | Installierter Build/Tests aktuell; GUI mangels nativer Steuerung offen; ein altes Test-Keychain-Objekt zu entfernen |

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

## Releases

| ID | Delivery | Stage | Build | Locator | Evidence |
|---|---|---|---|---|---|
| L001 | D001 | LOCAL | e360dc03836bccdb | /Users/udi/Applications/Secretariat.app | E010,E011 |

Status, Beleg und Kritik sind unterschiedliche Angaben. `Evidence` in der Aufgabenzeile referenziert die für ihren Abschluss maßgeblichen Beleg-IDs. Ältere Belege dürfen als Historie bleiben. Bei Reviews ist die letzte Zeile je Scope maßgeblich.
