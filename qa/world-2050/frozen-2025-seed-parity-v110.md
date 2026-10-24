# P0 v110: verified frozen 2025 world seed in isolated stage (24 Oct 2026)

**Read-only audit; no game saves, world matches, rankings or source player rows were changed.**

We identified four durable, potentially re-usable baseline artifacts in `cb_e2e_reconstruction_20261010`:

1. `synthetic_adult_seed_v1`: **24,435** unique generated adults, each with a stable `slot`, `slug`, identity and date **2025-12-01**. Mapping is `public.players.id=1000000+slot`, verified across the entire table.
2. `synthetic_adult_attributes_v1`: **24,435** unique rows, matched against `public.player_attributes` for the same original player IDs by all stored attributes. **0 missing, 0 drifting values** in current isolated world.
3. `world_rank_seed_plan_v1`: **26,456** unique players and **26,456** unique originally assigned rankings; **0 missing source IDs and 0 source-label drifts**. **2,050 current world ranks differ** from initial assignments. These are expected to change during simulation, not evidence of a data fault by themselves.
4. `atp_20251201_reference_v1`: **2,205** source ATP identities, with `atp_2025_ledger_bridge_v1`: **6,910** linked rows with **0 missing stage players**. The provisional separate frozen Top200 history table has 191 rows and is NOT an official per-event ATP ledger certification.

### What this proves and what it does not

This proves the 24,435 synthetic adult player identity/attribute rows in staging can be tied *exactly* back to the preserved frozen generator output, and that the initial world-ranking assignment plan was not lost. It strengthens the ability to reconstruct a clean 1 Dec 2025 baseline on a separate restorable database.

It does **not** prove full baseline reconstruction: ATP event-level history has estimated records; 2025 opening world, 30k adults, junior/NCAA, doubles, staff, all 2026 original ranks and prize/tournament states must be independently reconciled. It cannot undo contaminated title/news/ace-record/AI-physiology effects, and is not an off-database backup. Do not reset the stage.

The first invalid completed ITF event finished **2026-03-01**, and five more cancelled/postponed ITF simulations followed. The safe replay must begin before the first invalid event and rebuild/verify the whole affected world from a clean baseline. Prior v80 green checks only showed data integrity, not sports-calendar semantic correctness; v96 rejects affected weeks.

**Current safe next dependency:** run the operator-only encrypted backup script `scripts/cb-stage-independent-backup-verify.sh` with an authorized stage DB URL, offline private age key, and disposable local PostgreSQL/Supabase 17 instance. Keep the encrypted backup and key separate. Only after a successful independent restore can a clean world replay be authorized.

SQL proof: `qa/world-2050/frozen-2025-seed-parity-v110.sql`.
