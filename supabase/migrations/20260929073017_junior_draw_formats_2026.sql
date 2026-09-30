-- ITF World Tennis Tour Juniors 2026 draw structure
-- Source: https://www.itftennis.com/media/15745/2026-itf-world-tennis-tour-juniors-regulations.pdf
-- Regulation 45 (seeds), Regulation 47 (draw composition), Appendix A (J500/JGS minimum fields).

insert into public.tournament_format_rules
(rule_key,circuit,category,main_draw_size,bracket_size,qualifying_draw_size,doubles_draw_size,format_type,seed_count,qualifier_count,wildcard_count,rounds,points_by_result,qualifying_points,source_label,source_url,updated_at)
values
('J30_32','Junior','J30',32,32,32,16,'knockout',8,4,4,array['R32','R16','QF','SF','F'], '{}'::jsonb,'{}'::jsonb,'ITF Juniors 2026 · Regulations 45/47','https://www.itftennis.com/media/15745/2026-itf-world-tennis-tour-juniors-regulations.pdf',now()),
('J60_32','Junior','J60',32,32,32,16,'knockout',8,4,4,array['R32','R16','QF','SF','F'], '{}'::jsonb,'{}'::jsonb,'ITF Juniors 2026 · Regulations 45/47','https://www.itftennis.com/media/15745/2026-itf-world-tennis-tour-juniors-regulations.pdf',now()),
('J100_32','Junior','J100',32,32,32,16,'knockout',8,4,4,array['R32','R16','QF','SF','F'], '{}'::jsonb,'{}'::jsonb,'ITF Juniors 2026 · Regulations 45/47','https://www.itftennis.com/media/15745/2026-itf-world-tennis-tour-juniors-regulations.pdf',now()),
('J200_48','Junior','J200',48,64,32,16,'knockout',16,6,6,array['R48','R32','R16','QF','SF','F'], '{}'::jsonb,'{}'::jsonb,'ITF Juniors 2026 · Regulations 45/47','https://www.itftennis.com/media/15745/2026-itf-world-tennis-tour-juniors-regulations.pdf',now()),
('J300_32','Junior','J300',32,32,32,16,'knockout',8,4,4,array['R32','R16','QF','SF','F'], '{}'::jsonb,'{}'::jsonb,'ITF Juniors 2026 · Regulations 45/47','https://www.itftennis.com/media/15745/2026-itf-world-tennis-tour-juniors-regulations.pdf',now()),
('J300_48','Junior','J300',48,64,32,16,'knockout',16,6,6,array['R48','R32','R16','QF','SF','F'], '{}'::jsonb,'{}'::jsonb,'ITF Juniors 2026 · Regulations 45/47','https://www.itftennis.com/media/15745/2026-itf-world-tennis-tour-juniors-regulations.pdf',now()),
('J500_48','Junior','J500',48,64,32,24,'knockout',16,6,6,array['R48','R32','R16','QF','SF','F'], '{}'::jsonb,'{}'::jsonb,'ITF Juniors 2026 · Regulations 45/47 + Appendix A','https://www.itftennis.com/media/15745/2026-itf-world-tennis-tour-juniors-regulations.pdf',now()),
('J500_64','Junior','J500',64,64,32,24,'knockout',16,8,8,array['R64','R32','R16','QF','SF','F'], '{}'::jsonb,'{}'::jsonb,'ITF Juniors 2026 · Regulations 45/47 + Appendix A','https://www.itftennis.com/media/15745/2026-itf-world-tennis-tour-juniors-regulations.pdf',now()),
('JGS_64','Junior','Junior Grand Slam',64,64,32,32,'knockout',16,8,8,array['R64','R32','R16','QF','SF','F'], '{}'::jsonb,'{}'::jsonb,'ITF Juniors 2026 · Regulations 45/47 + Appendix A','https://www.itftennis.com/media/15745/2026-itf-world-tennis-tour-juniors-regulations.pdf',now())
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

-- 2026 J500s must provide at least 24 doubles teams under Appendix A.
update public.tournaments
set doubles_draw_size=greatest(coalesce(doubles_draw_size,0),24)
where circuit='Junior'
  and category='J500'
  and is_active=true
  and start_date>='2026-01-01';

-- Orange Bowl 2025 is a 64/64/32 event and is immediately relevant to the 01/12/2025 career start.
update public.tournaments
set draw_size=64,
    singles_draw_size=64,
    qualifying_draw_size=64,
    doubles_draw_size=32,
    main_draw_start_date='2025-12-08',
    qualifying_start_date='2025-12-06',
    qualifying_end_date='2025-12-07',
    schedule_source_label='USTA Orange Bowl 2025 tournament information'
where id=2036
  and circuit='Junior'
  and category='J500';

-- Official 2026 Orange Bowl fact sheet: 64 singles qualifying / 64 main / 32 doubles.
update public.tournaments
set draw_size=64,
    singles_draw_size=64,
    qualifying_draw_size=64,
    doubles_draw_size=32,
    main_draw_start_date='2026-12-07',
    qualifying_start_date='2026-12-05',
    qualifying_end_date='2026-12-06',
    schedule_source_label='ITF J500 Fort Lauderdale 2026 official fact sheet'
where id=3395
  and circuit='Junior'
  and category='J500';
