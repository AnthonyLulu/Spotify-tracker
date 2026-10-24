# 2025 ATP staging seed v94 (24 Oct 2026)

**Scope:** isolated Supabase `court-boss-e2e-2025-2050` only. Production and user saves must not be touched. This is a **provisional historical reference**, not certified ATP rankings or a 2050 validation.

The frozen repository snapshot `court-boss/data/atp-singles-2025-12-01.json` contains 200 entries (Alcaraz #1 12,050; Sinner #2 11,500). Live stage previously had zero rows in `public.atp_ranking_baseline_2025_12_01`. A read-only provenance check confirmed **189 unambiguous imported ATP identities** by normalized name and source label. Two more existing imported profiles have fixed, verified alias identities: rank 122 Bu Yunchaokete (id 2207352, CHN) and rank 165 Daniel Merida Aguilar (id 2210017, ESP). Their current 2026 rank/points may differ from the frozen 2025 reference, so v94 deliberately does not compare mutable current ranking values.

The remaining **nine** cannot be identified safely from the current ATP provenance: Gabriel Diallo (#41), Ethan Quinn (#70), Jacob Fearnley (#71), Eliot Spizzirri (#90), Liam Draxl (#129), Colton Smith (#146), Nishesh Basavareddy (#167), Michael Zheng (#192), Arthur Fery (#193). NCAA identities and synthetic homonyms are **not** accepted as ATP identity evidence by name alone.

The SQL aborts unless the **original isolated checkpoint exists**, no staged career exists, and exactly 191 unique imported ATP identities match the immutable 200-row reference. It writes only the historical-reference table. It is idempotent and refuses unexpected pre-existing baselines. It does **not** modify the 2026 live world rankings, points ledger, match history, source players, production database or user saves.

**Remaining blockers for full 2025 ATP certification:** verify the licensing/provenance of the historical ranking source, resolve nine player identities using persistent ATP IDs, independently reconcile the per-event 2025 ledger and estimated residuals, and verify weekly 52-week expiry with correct ATP counting rules. Full circuits (doubles, juniors, NCAA, Davis), save/load mobile E2E and 2050 simulation remain open.
