# Isolated world doubles stage clone v102 — 24 October 2026

**Actually installed and verified in the existing isolated Supabase E2E database**, not in production.

Source is the current production-equivalent `public.simulate_world_doubles_tournaments(date,date)`. Installation pins `md5(pg_get_functiondef(...)) = c24ae419a0cee59fffe2fc57a8c1c7ae` and applies exactly two changes to a separate private staging-only function: add `p_tournament_id bigint` and restrict the tournament loop to that ID. Security mode is downgraded from SECURITY DEFINER to SECURITY INVOKER; default public/anon/authenticated function execution grants are revoked. The original function and all game data are untouched by installation.

Validation from the stage returned `event_scoped=true`, `security_invoker=true` and `production_function_untouched=true`. **This is not a successful doubles draw yet.**

A genuine, non-persistent, 18-second rollback-only test for M15 Soltepec id 166 reached the *real* `select_itf_doubles_field_v20` selector and hit `statement_timeout` inside `ai_player_commits_to_doubles_tournament`, specifically its five-week event history lookup repeated across partnership candidates. PostgreSQL canceled the statement and rolled the entire trial back. A further trial was blocked immediately by another singles-world writer's advisory lock. No world doubles champions, points or matches were persisted. There were **zero active world doubles partnerships** before the trial, so the original engine also has to bootstrap pairs on the first event.

**Important next fix:** profile/limit tournament candidate evaluation before invoking per-player calendar/AI decisions while preserving ATP/ITF merit hierarchy; prove full 16-pair selection, final match and point awards inside one transaction. Do not simply increase DB statement timeout or declare that 2025–2050 works. The live stage is currently advancing singles into March 2026, so any writes must continue to stop while that staged job is active.

The v101 atomic event operator is separately committed, but it invokes the original native full-window function and is safe only on a date with exactly one pending ordinary doubles event. The v102 function is a new diagnostic stepping stone for a proper event-ID-specific implementation; it does not replace a multi-circuit 2050 world controller or real mobile save/load.
