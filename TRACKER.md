# Aufgaben und Nachweise

## Tasks

| ID | Status | Evidence | Reason |
|---|---|---|---|
| T001 | ERLEDIGT | E002 | Archiv unabhängig verifiziert, aktuelles Konzept abgeglichen |
| T002 | ERLEDIGT | E005,E006,E007 | Im lokalen Minimalumfang geprüft; Grenzen in docs/acceptance.md |
| T003 | ERLEDIGT | E008,E009 | Im lokalen Minimalumfang geprüft; Grenzen in docs/acceptance.md |
| T004 | ERLEDIGT | E003 | Im lokalen Minimalumfang geprüft; Grenzen in docs/acceptance.md |
| T005 | ERLEDIGT | E004 | Im lokalen Minimalumfang geprüft; Grenzen in docs/acceptance.md |
| T006 | ERLEDIGT | E010,E011 | Im lokalen Minimalumfang geprüft; Grenzen in docs/acceptance.md |

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

## Releases

| ID | Delivery | Stage | Build | Locator | Evidence |
|---|---|---|---|---|---|
| L001 | D001 | LOCAL | e360dc03836bccdb | /Users/udi/Applications/Secretariat.app | E010,E011 |

Status, Beleg und Kritik sind unterschiedliche Angaben. `Evidence` in der Aufgabenzeile referenziert die für ihren Abschluss maßgeblichen Beleg-IDs. Ältere Belege dürfen als Historie bleiben. Bei Reviews ist die letzte Zeile je Scope maßgeblich.
