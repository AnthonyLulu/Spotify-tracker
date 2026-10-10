## 10 October 2026, current reconstruction (live isolated DB, read-only checks)

The user authorized stage-only reconstruction. The production SQL catalogue was retrieved via read-only introspection, without needing a manual SQL export. Only definitions were stored in restricted staging tables, **no production rows, accounts, or saves**.

In `cb_e2e_reconstruction_20261010.blueprint`, all **1,852** catalogued production objects are available for staging reconstruction. Actual installed objects are *not* all complete: **296/296 tables**, **3,831/3,831 columns**, **1,036/1,036 named constraints** (one FK action still drifted), **648/650 matching function definitions**, **134/134 sequences**, **301 expected indexes still missing**, **7 views missing**, and **40 triggers missing**. The two absent functions depend on the junior views. No production game Edge Function is deployed in stage.

All 85 original isolated fixture tables were repeatedly verified against the saved snapshot by projecting their original column sets: no original row values were changed. This internal checkpoint **is not** a physically independent backup.

A genuine call to `public.world_integrity_guard_v18('2025-12-01')` returned **ok=false**: 2,890 active adults versus a required 24,000, 8,845 active staff, 3,725 junior-pipeline profiles and two near-calendar duplicate groups. A real 2050 daily replay is correctly blocked, not certified. Do not bypass this gate by inventing a successful result.

The read-only SQL checker `qa/world-2050/stage-parity-gate.sql` and dated `reconstruction-status-2026-10-10.json` capture the actual incomplete state; the JSON is a snapshot, not a live source of truth. Restore missing objects with reviewed staging-only migrations, seed a complete authorized/synthetic world, validate source and derived rankings, provision an authenticated isolated Edge Function, then run a complete real-engine career replay with save/load and rollback probes. No new paid project was created.

---

# Court Boss 2025–2050: reproducible world baseline gate

Status on **10 October 2026: BLOCKED. This is not an end-to-end 2050 pass.**

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
