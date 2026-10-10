# Court Boss: genuine unified world-match E2E (staging)

The old 90-day / 12-week SQL test ran `advance_career_day_v26` and
`simulate_world_week`. The latter handles recovery, ages, ranking and
entry protection, but **does not call the unified ATP/Challenger/ITF
tournament engine**.

The real weekly game API `POST /api/simulate`, when invoked in
checkpoint mode, calls `run_unified_circuit_window(from,to)`. That SQL
orchestrates ATP, Challenger, ITF, qualifying, Davis Cup, doubles,
juniors and NCAA, and returns an integrated circuit-integrity audit.

This new *isolated QA-only* probe calls that exact function, rather
than substituting `simulate_world_week`, and counts the actual
`world_tournament_matches` rows, completed scorelines, winners and
losers. It rejects zero completed/scored matches rather than giving a
false positive on an empty week. **The probe always forces rollback.**
It uses nonblocking exclusive locks and refuses if a career or save is
present. It must never run in production.

Default test window 2026-01-04 through 2026-01-06, bounded to at most
eight days during the first fortnight of January. Full weekly
2026-01-04→2026-01-11 is an optional follow-up after a passing,
lightweight first probe.

**Release criterion:** this test may confirm individual real world
match records, but does not alone prove all schedules, authoritative
match-result commits, managed Match Center or transactional
idempotence. The 25-year controller's weekly receipt remains red
until a genuine authenticated stage adapter returns a stable durable
run ID and database-based match counts, not a guessed number.

### Additional blockers to 2025–2050 acceptance

- Frozen Top200 2025 still has 191 identities confirmed, 8 ITA/NCAA
  name-only matches and 1 generated homonym that must not be merged.
- Per-event 2025 licensed result provenance and proper ATP rank
  reset are absent. Existing 2,021 synthetic reconciliation entries
  all expire 2026-11-30 and are not historically accurate.
- Isolated Edge function and independent external backup are not yet
  ready. Real saved career → quit → reload → failure rollback
  validation must occur on stage, not user's live saves.

Related #10, #18, #54, #69, #70 and #71.
