# P0 real staged doubles event trial (v101)

**Goal:** prove one genuine world doubles tournament with the existing game's physics, proper bracket, scoring, pair titles and rolling points, not a mocked 2050 receipt.

At 24 October 2026, read-only stage query detected only **one pending ordinary doubles tournament ending 2026-01-31**: Soltepec Tennis Tour, M15, tournament id 166, draw 16. No prior staged world doubles tournament simulations; stage has zero private save slots/careers, and its original checkpoint is intact.

Existing `public.simulate_world_doubles_tournaments(date,date)` is a *full window* simulator that may advance up to 120 events and refresh rankings. **Do not call it directly with a full season**, and do not call while the singles-world writer is active. `stage-doubles-one-event-v101.mjs` selects a **single-day window** and refuses to run unless precisely one eligible unsimulated tournament exists, no active singles-world job exists and the prior singles week for that date has completed.

CLI usage (operator only, no secret in git or logs):

`CB_E2E_DB_URL=<direct-stage-TLS-DSN> node qa/world-2050/stage-doubles-one-event-v101.mjs --date=2026-01-31`

Explicitly execute only once the dry-run has one pending event and zero active world jobs:

`CB_E2E_DB_URL=<direct-stage-TLS-DSN> node qa/world-2050/stage-doubles-one-event-v101.mjs --date=2026-01-31 --execute`

Execution is one **PostgreSQL transaction** containing the actual existing engine. Final proof requires one new simulation champion, final with score and matching winning pair, several scored main-draw matches and two or more award rows. If any check fails, the whole transaction (including player changes) rolls back. The transaction refuses a concurrent world lock. No automated retry, no global scheduling, no production calls.

**Current blocker:** A 2026-03-08→03-15 singles job is running in the isolated stage. This worker must refuse to compete with it. Do not claim that doubles were simulated or 2050 certified until a live stage transaction succeeds and its results are re-read. This PR establishes a safe execution boundary, not certification.

Next order: verify doubles events in chronological order, independently certify junior singles/doubles and NCAA/Davis paths, fix frozen 2025 expiry cliff, integrate daily season/year rollovers and mobile save-load. Preserve stage checkpoint and never reset the isolated project.
