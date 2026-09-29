-- Court Boss 2026 Junior Grand Slam data corrections.
-- Official ITF fact sheets confirm 64-player singles, 32-player qualifying
-- and 32-team doubles fields for the Australian Open and US Open juniors.
-- The 48/80 projected cuts are a Court Boss field-composition model:
-- 48 projected direct/WC positions plus a 32-player qualifying field.
-- Source AO:
-- https://www.itftennis.com/en/tournament/australian-open-junior-championships/aus/2026/j-jgs-aus-2026-001/fact-sheet/
-- Source USO:
-- https://www.itftennis.com/en/tournament/us-open-junior-tennis-championships/usa/2026/j-jgs-usa-2026-001/fact-sheet/

insert into tournament_format_rules(
  rule_key,circuit,category,main_draw_size,bracket_size,qualifying_draw_size,doubles_draw_size,
  format_type,seed_count,qualifier_count,wildcard_count,rounds,points_by_result,qualifying_points,
  source_label,source_url,updated_at,special_exempt_slots
) values (
  'JGS_64','Junior','Junior Grand Slam',64,64,32,32,
  'knockout',16,8,8,
  array['R64','R32','R16','QF','SF','F'],
  '{}'::jsonb,'{}'::jsonb,
  'Court Boss Junior Grand Slam composition · ITF 2026 draw sizes',
  'https://www.itftennis.com/en/tournament/australian-open-junior-championships/aus/2026/j-jgs-aus-2026-001/fact-sheet/',
  now(),0
)
on conflict (rule_key) do update set
  circuit=excluded.circuit,
  category=excluded.category,
  main_draw_size=excluded.main_draw_size,
  bracket_size=excluded.bracket_size,
  qualifying_draw_size=excluded.qualifying_draw_size,
  doubles_draw_size=excluded.doubles_draw_size,
  format_type=excluded.format_type,
  seed_count=excluded.seed_count,
  qualifier_count=excluded.qualifier_count,
  wildcard_count=excluded.wildcard_count,
  rounds=excluded.rounds,
  source_label=excluded.source_label,
  source_url=excluded.source_url,
  updated_at=now();

update tournaments
set doubles_draw_size=32,
    main_draw_start_date=start_date,
    projected_direct_cut=48,
    projected_qual_cut=80,
    cut_is_projection=true
where id in (3266,3267,3268,3269);

update tournaments
set main_entry_deadline='2025-12-16',
    singles_entry_deadline='2025-12-16',
    qualifying_entry_deadline='2025-12-16',
    withdrawal_deadline='2026-01-13',
    singles_withdrawal_deadline='2026-01-13',
    qualifying_signin_date='2026-01-20',
    qualifying_start_date='2026-01-21',
    qualifying_end_date='2026-01-22',
    schedule_source_label='ITF Australian Open Junior Championships 2026 fact sheet',
    source_note='ITF official 2026 Junior Grand Slam · schedule/draw corrected from official fact sheet'
where id=3266;

update tournaments
set main_entry_deadline='2026-07-28',
    singles_entry_deadline='2026-07-28',
    qualifying_entry_deadline='2026-07-28',
    withdrawal_deadline='2026-08-25',
    singles_withdrawal_deadline='2026-08-25',
    qualifying_signin_date='2026-08-31',
    qualifying_start_date='2026-09-03',
    qualifying_end_date='2026-09-04',
    schedule_source_label='ITF US Open Junior Tennis Championships 2026 fact sheet',
    source_note='ITF official 2026 Junior Grand Slam · schedule/draw corrected from official fact sheet'
where id=3269;
