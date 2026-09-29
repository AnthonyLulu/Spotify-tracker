-- Court Boss 2026 qualifying-calendar repair.
-- Safe/idempotent guards: only fixes active rows whose qualifying start is
-- incorrectly on or after the main-draw start. It does not touch already
-- sourced events such as Winston-Salem when their dates are coherent.

update public.tournaments
set qualifying_start_date = (coalesce(main_draw_start_date,start_date) - 2),
    qualifying_end_date   = (coalesce(main_draw_start_date,start_date) - 1)
where is_active=true
  and circuit='ATP'
  and coalesce(qualifying_draw_size,0)>0
  and qualifying_start_date is not null
  and qualifying_start_date >= coalesce(main_draw_start_date,start_date);

update public.tournaments
set qualifying_start_date = (coalesce(main_draw_start_date,start_date) - 1),
    qualifying_end_date   = coalesce(main_draw_start_date,start_date)
where is_active=true
  and circuit='Challenger'
  and coalesce(qualifying_draw_size,0)>0
  and qualifying_start_date is not null
  and qualifying_start_date >= coalesce(main_draw_start_date,start_date);
