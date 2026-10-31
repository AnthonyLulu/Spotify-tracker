# Client save confirmations and player match history — 31 October 2026

The client could treat unreadable HTTP 200 responses as successful saves. It could also clear current local career state when an incomplete load response contained no payload. Save and load now require a successful receipt for the requested slot; loads also require the local payload and live-session list. Invalid confirmations leave local match state and the recovery marker intact. This does not prove that a mutation with a lost response was rejected on the server; no mutation is retried automatically.

Slot deletion now uses the existing save/load queue. Duplicate clicks and concurrent manual save/load operations are blocked while deletion is in progress, and the checkpoint currently needed for live rollback cannot be deleted.

Match Center previously rendered a filtered player history but opened details using the unfiltered list. Both now use `managedMatchHistory()`. Unowned legacy matches stay with the primary player, and losing to that primary player is correctly shown as a defeat for the selected secondary player.

Validation:

- Reproduced acceptance of an unreadable save response and opening of the wrong player's match against the original `7cf209d` client.
- Added 17 behavioral tests using the actual client functions, mocked HTTP responses and local storage. Covered bad/partial receipts, successful save/load, startup recovery, deletion concurrency, retained checkpoints, player selection and legacy history.
- `npm test`: **469 passed, 0 failed** (baseline: 452).
- `node --check court-boss/app.js` and `git diff --check`: passed.

The initial GitHub visual job stopped during browser installation: `ubuntu-latest` now selected Ubuntu 26.04, which pinned Playwright 1.55.0 does not support. The visual job now explicitly uses Ubuntu 24.04, listed in that Playwright version's native dependency manifest. This keeps the existing browser checks enabled.

No production/staging data, private saves, migrations, or server code were changed. No live browser/mobile or production save/load session was exercised. The independent staging backup and full 2050 career certification remain outstanding.
