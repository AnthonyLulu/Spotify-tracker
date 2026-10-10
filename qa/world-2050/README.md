## 10 October 2026, verified isolated reconstruction milestone

**The true 2025–2050 game career is NOT certified.** Production and its private saves remain untouched. Only the existing **isolated** staging Supabase project was changed under user authorization; no paid project was created.

### Current isolated world

- **296/296 tables**, **3,831/3,831 columns**, **1,036/1,036 constraints** (including the NCAA cascade), **134/134 sequences**, **722/722 expected indexes**, **10/10 views**, **40/40 triggers**.
- **650/650 routines exist. 648/650 source definitions match the captured production version; TWO sandbox-specific functions deliberately differ**: `cb_generated_player_name(text,integer)` adds deterministic compound-name fallback for future newgens; `rollover_season_daily_v22(integer)` includes 1 Jan day preservation and junior ranking refresh. Do not auto-overwrite these from the earlier production catalog or declare exact routine parity.
- Staging keeps **89 additional RLS-enabled tables** relative to the captured production catalog, so its access policies are intentionally stricter. No game Edge Function is deployed in stage. Structural object presence is NOT complete API/runtime parity.
- The original **85 fixture tables and 21,651 checkpointed rows** remain verified by `verify_original_fixture_rows_v3()`. The only approved original-row differences are tournament flags 132 and 133, intentionally inactive to remove duplicated events. The checkpoint remains **inside the same database** and is NOT an independently recoverable backup.
- The 2025 world guard is **GREEN**, with **27,325 active adult players**, 8,845 staff profiles and zero active near-duplicate tournament groups. The isolated ATP opening carryover has 2,021 explicitly estimated aggregate ranking ledger rows, not fabricated tournament results.
- 5,000 older player-attribute records were completed only in the three attributes added after the original checkpoint: `first_serve_quality`, `net_positioning` and `doubles_communication`. The original-column digest still passes.

### Actual production-engine SQL tests against isolated data (rolled back after each)

| Test | Result |
| --- | --- |
| `advance_career_day_v26`, 1→10 December 2025 | **PASS**: 9 sequential days, 1 Sunday checkpoint, 9 unique commits and idempotent replay of an earlier day |
| Real 7 December world recovery/rankings | **PASS**: 1,800 recovered players; Carlos Alcaraz preserved as ATP #1 |
| Daily-mode 2025→2026 rollover | **PASS**: 202 retirements, 1,999 additions during trial, 2,000-profile junior singles and doubles pools; Jan 1 consumed exactly once |
| Adelaide + Auckland ATP250 completed draws | **PASS**: 62 match results, 64 entrants |
| Nouméa Challenger 75 qualifying + main draw | **PASS**: 18 qualifying matches and 31 main-draw matches; all transaction effects rolled back |
| Combined 15-event week, January 2026 | **BLOCKED** by SQL statement timeout in per-player AI entry planning; no world result was committed |
| Standalone M25 ITF attempt | **NOT EXECUTED**: tool safety controls blocked the call |

The 15-event timeout is not solved by having 301 indexes installed: `player_season_plans` already has a unique `(player_id, season)` index, while tournament candidate selection invokes AI eligibility/planning functions per candidate. Further profiling and a **restartable, time-bounded tournament batch mechanism** are required before a full-year trial.

**Next hard gates:** real multi-event progressive tournament batching with no duplicate matches, independent encrypted and verified staging backup, user Match Center/save/reload/rollback integration, complete calendar/world renewal across 2025–2050, real mobile/API tests. The 9,161-day adapter-only test is not E2E certification. Detailed verified dated values are in `reconstruction-status-2026-10-10.json`.


---

# Court Boss 2025–2050: original reconstruction baseline (historical)

Historical first-inspection status. The initial parity table below records the **pre-reconstruction** database, not the latest verified state. Full 2050 E2E remains blocked.

## Verified isolated checkpoint (10 October 2026)

User authorized protecting and rebuilding **only** the existing isolated Supabase project.

- Created private internal schema `cb_e2e_checkpoint_20261010` in the isolated project. 85 data tables, **21,651** rows; every table was checked by row count plus a deterministic aggregate content digest.
- Stored 52 function definitions, 145 index definitions, 3 view definitions, columns, constraints, RLS policies, grants, extension versions and sequences as **in-database metadata**.
- Independently re-created all 85 data tables as disposable PostgreSQL temporary tables from the checkpoint and verified their digests. This validates data recoverability for this checkpoint, not a whole-project disaster recovery.
- Database occupied roughly 25 MB before and 33 MB after the checkpoint. No additional project or paid branch was created.
- **Do not DROP, RESET or overwrite the isolated project:** checkpoint is in the same database. Obtain a physically separate, tested `pg_dump` / `pg_restore` backup before any destructive rebuild or project replacement.
- Production remains untouched and has 119 private saves; stage has no private save slots and no deployed game Edge Function.

### Real replay controller

`replay-controller.mjs` implements a fail-closed state machine for 2025-12-01 to 2050-12-31. It requires the exact stage-only environment, structural parity, a sanitized seed, real server adapters for daily ticks, managed matches, weekly checkpoints, season rollover, save/reload probes, and quarterly world invariants. It cannot run until those components exist. Unit tests with *mocked* adapters confirm the controller's 9,161 transitions and error handling; these are **not** a 2050 gameplay certification.

## What is actually deployed

The isolated free Supabase project `court-boss-e2e-2025-2050` already holds component-test fixtures and prior sandbox tests. It is **not empty** and must not be reset or overwritten just to produce a green run. Production is `court-boss`. Never copy actual saves, authentication data, private keys, browsers' access codes, player careers or user-financial records to a sandbox.

Read-only PostgreSQL catalog verification found:

| Object kind | Production | Isolated | Missing | Shared definitions changed | Extra isolated |
| --- | ---: | ---: | ---: | ---: | ---: |
| Tables | 296 | 85 | 211 | 51 | 0 |
| Views | 10 | 3 | 7 | 3 | 0 |
| Functions | 650 | 52 | 599 | 18 | 1 |
| Indexes | 722 | 145 | 585 | 0 | 8 |
| User-defined triggers | 40 | 0 | 40 | 0 | 0 |

Only **33 of the 51 shared function signatures** have the same definition hash. The 18 changed definitions include `simulate_world_week`, `simulate_world_tournaments`, `generate_newgens`, season rollover, rankings and injury simulation. The sandbox's 9,161-day day-transition test is therefore a **component integration test with simplified dependencies**, not a real FM/TM world replay. The separate environment has reference player/tournament fixtures but not the full production world.

## Read-only schema parity gate

The files `schema-inventory.sql` and `scripts/cb-schema-audit.mjs` compare names and definition fingerprints for tables (columns, constraints, RLS), views, functions, indexes and triggers. A missing object, changed definition or unexpected extra fails the gate. The inventory query does not read table rows or reveal full function source. This parity gate is necessary, not sufficient: it does not assert extensions, all privileges, fixture parity or gameplay results.

For a **trusted database owner or operator only**, with local PostgreSQL client tools `psql` and `pg_dump` and Node 22+ installed:

```bash
# Set these via a secure local secret manager; never paste URLs into commits or logs.
export CB_PROD_DB_URL='<secure production owner connection>'
export CB_E2E_DB_URL='<secure isolated test connection>'
bash scripts/cb-export-schema-baseline.sh
```

The command runs SELECT-only inventories against both databases, creates a schema-only dump **from production only**, and compares manifests. No restoration or migration is performed. The output is private under `.private-artifacts/` and ignored by git. The schema dump includes function definitions and should be reviewed for hardcoded tokens or secrets before any sharing. Missing connection credentials cannot be manufactured by the app connector.

## To earn a real 2050 green badge

1. Generate and review a canonical production schema-only baseline with extension versions, role grants, RLS, triggers, function security and dependency ordering. No private user rows.
2. Provision a **fresh, explicitly approved isolated database** or restore a checkpoint before replacing the existing sandbox. Do not destroy prior component-test data. Apply baseline + subsequent repository migrations on that clean instance, fixing ordering and idempotency. Re-run the schema parity gate.
3. Build a deterministic, sanitized world seed for the frozen **1 December 2025** state. Verify 30k-scale playable adult/ITF pool, junior/NCAA, doubles partnerships, staff, calendars, titleholders, ranking points and tournament entries. Use only licensed/authorized non-private source data or synthetic identities.
4. Replay actual production functions day by day from **2025-12-01 to 2050-12-31** on the reconstructed world. Every simulated day must commit normally, with no stubbed downstream effects. Record quarterly population, retirees, newgens, singles/doubles ranks, draws, injuries, finances, staff, titles/records, Hall of Fame and academy transitions.
5. Inject crash/retry/save-load probes, check no double-match/day/debt effects, verify transaction rollback equality, and retain failure day, deterministic seed and before/after snapshots. Compare gameplay distributions against credible ranges before signing off.

**Stop/go rule:** no publication of “2050 validated” until the schema gate, clean seed rebuild and genuine E2E 2050 replay are all green. Track with [P0 issue #18](https://github.com/AnthonyLulu/Spotify-tracker/issues/18) and game certification issue #10.
