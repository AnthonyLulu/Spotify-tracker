-- ITF junior tournament realism pass.
-- 2026 ITF WTT Juniors Regulations + official J500 fact sheets.
-- 2025 J500 Fort Lauderdale uses the official 2025 event and Junior cut-off report.

update public.tournaments
set singles_draw_size = 64,
    qualifying_draw_size = 64,
    doubles_draw_size = 32,
    main_draw_start_date = date '2025-12-08',
    main_entry_deadline = date '2025-11-17',
    singles_entry_deadline = date '2025-11-17',
    qualifying_entry_deadline = date '2025-11-17',
    direct_cut = 139,
    qual_cut = 564,
    projected_direct_cut = 139,
    projected_qual_cut = 564,
    cut_is_projection = false,
    source_url = 'https://www.itftennis.com/en/tournament/j500-fort-lauderdale/usa/2025/j-j500-usa-2025-001/draws-and-results/',
    source_note = 'ITF official J500 Fort Lauderdale 2025; boys cut-offs MD #139 / Q #564 from the ITF 2025 Junior Tournament Cut-Off Report',
    schedule_source_label = 'ITF J500 Fort Lauderdale 2025 official event + 2025 Junior Regulations'
where id = 2036;

update public.tournaments
set qualifying_draw_size = 48,
    doubles_draw_size = 24,
    main_draw_start_date = date '2026-09-21',
    main_entry_deadline = date '2026-09-01',
    singles_entry_deadline = date '2026-09-01',
    qualifying_entry_deadline = date '2026-09-01',
    withdrawal_deadline = date '2026-09-08',
    singles_withdrawal_deadline = date '2026-09-08',
    qualifying_signin_date = date '2026-09-18',
    schedule_source_label = 'ITF J500 Osaka 2026 official fact sheet'
where id = 3393;

update public.tournaments
set qualifying_draw_size = 48,
    doubles_draw_size = 24,
    main_draw_start_date = date '2026-11-23',
    main_entry_deadline = date '2026-10-13',
    singles_entry_deadline = date '2026-10-13',
    qualifying_entry_deadline = date '2026-10-13',
    withdrawal_deadline = date '2026-11-10',
    singles_withdrawal_deadline = date '2026-11-10',
    qualifying_signin_date = date '2026-11-20',
    schedule_source_label = 'ITF J500 Merida 2026 official fact sheet'
where id = 3394;

update public.tournaments
set qualifying_draw_size = 64,
    doubles_draw_size = 32,
    main_draw_start_date = date '2026-12-07',
    main_entry_deadline = date '2026-11-17',
    singles_entry_deadline = date '2026-11-17',
    qualifying_entry_deadline = date '2026-11-17',
    withdrawal_deadline = date '2026-11-24',
    singles_withdrawal_deadline = date '2026-11-24',
    qualifying_signin_date = date '2026-12-04',
    schedule_source_label = 'ITF J500 Fort Lauderdale 2026 official fact sheet'
where id = 3395;

update public.tournaments
set main_entry_deadline = coalesce(main_entry_deadline, singles_entry_deadline),
    qualifying_entry_deadline = singles_entry_deadline,
    main_draw_start_date = coalesce(main_draw_start_date, start_date)
where circuit = 'Junior'
  and is_active = true
  and start_date >= date '2025-12-01'
  and singles_entry_deadline is not null;

update public.tournaments
set doubles_draw_size = greatest(coalesce(doubles_draw_size, 0), ceil(singles_draw_size / 2.0)::int)
where circuit = 'Junior'
  and category = 'J500'
  and is_active = true
  and singles_draw_size is not null
  and start_date >= date '2025-12-01';
