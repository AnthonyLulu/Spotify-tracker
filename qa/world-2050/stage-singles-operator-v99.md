# Court Boss P0: safe isolated singles batch operator (v99)

This is a **real database adapter** for the existing v85 resumable controller, not a full 2050 engine. It uses the private isolated PostgreSQL stage and **cannot** target the production hostname. No credentials are committed or printed.

## How to operate (owner-operated, intentionally manual)

Requires Node 22+, PostgreSQL `psql` on PATH and an owner-provided *direct* TLS PostgreSQL connection URL to the existing isolated `court-boss-e2e-2025-2050` Supabase project. Set `CB_E2E_DB_URL` securely through the shell/secret store; do not paste it into the repository, terminal recording, issues or ChatGPT.

1. Read-only inspection, the **default**:

   `node qa/world-2050/stage-singles-operator-v99.mjs --from=2026-03-08 --to=2026-03-15`

2. Only if stage data is verified and no other writer is active, explicitly run a bounded two-event batch:

   `node qa/world-2050/stage-singles-operator-v99.mjs --from=2026-03-08 --to=2026-03-15 --max-steps=2 --execute`

The worker checks the exact target DB host, protected stage checkpoint, and **zero** user save slots/careers before any mutation. It reads the actual weekly job status; does not recreate an existing week; runs at most four database steps per invocation; checks persisted job state after every event; stops on a busy advisory lock or ambiguous database failure instead of guessing whether a match was committed. Completed weeks require the strict v80 tournament, score, points and rank receipt. No recurring schedule is installed.

**Important:** an incomplete week with 19/19 events may still need one extra finalization-only step to refresh and verify rankings. The resumable controller handles that safely. This is limited to Sunday-to-Sunday **2026 ATP/Challenger/ITF singles** and never marks unified circuits or 2050 green.

## What still blocks 2050

- 2025 historical ATP seed only 191/200 safe identifiers; remaining 9 need independently established ATP/ITA cross-circuit linkage.
- Artificial points-expiry cliff: 1,925 estimated rows / 107,152 points expire together on 2026-11-30.
- Real full-world loop and proof for doubles, juniors, NCAA, Davis/Junior Davis and managed player matches.
- Complete seeded-world 2025–2050 daily replay with retirement, newgens, fatigue, staff, awards, finances and ranking invariants. The v85 controller cannot run beyond 2026.
- Real device/API crash-save/reload and digest parity tests, not just VM mocks.
- Independent backup of the isolated stage outside that same database, then verifiable restore, before any destructive rebuild.

This operator is a **throughput and safety improvement**, not a substitute for those certification gates. PR CI uses offline mocked transport, never live database compute.
