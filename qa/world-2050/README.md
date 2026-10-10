# Court Boss 2025–2050: reproducible world baseline gate

Status on **10 October 2026: BLOCKED. This is not an end-to-end 2050 pass.**

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
