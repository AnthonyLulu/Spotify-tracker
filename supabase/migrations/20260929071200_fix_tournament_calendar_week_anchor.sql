create or replace function public.player_tournament_calendar_conflict(
  p_player_id bigint,
  p_tournament_id bigint,
  p_entry_method text default 'direct'::text
)
returns jsonb
language plpgsql
stable
set search_path to 'public'
as $function$
declare
  t public.tournaments%rowtype;
  method text:=lower(coalesce(p_entry_method,'direct'));
  commit_start date;
  commit_end date;
  week_monday date;
  managed_id bigint;
  c record;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null then
    return jsonb_build_object('conflict',true,'reason','tournament_not_found');
  end if;

  select managed_player_id into managed_id from public.career_state where id='demo';

  week_monday:=date_trunc('week',coalesce(t.main_draw_start_date,t.start_date)::timestamp)::date;
  commit_start:=case
    when method in ('qualifying','qualifying_wildcard')
      then coalesce(t.qualifying_start_date,t.main_draw_start_date,t.start_date)
    else coalesce(t.main_draw_start_date,t.start_date)
  end;
  commit_end:=coalesce(t.end_date,t.start_date);

  select ot.id tournament_id,ot.name tournament_name,ot.start_date,ot.end_date,e.result_code
  into c
  from public.world_tournament_entries e
  join public.tournaments ot on ot.id=e.tournament_id
  where e.player_id=p_player_id
    and ot.id<>t.id
    and ot.circuit in ('ATP','Challenger','ITF')
    and date_trunc('week',coalesce(ot.main_draw_start_date,ot.start_date)::timestamp)::date=week_monday
  order by coalesce(ot.main_draw_start_date,ot.start_date)
  limit 1;

  if c.tournament_id is not null then
    return jsonb_build_object('conflict',true,'reason','one_tournament_per_week',
      'other_tournament_id',c.tournament_id,'other_tournament',c.tournament_name);
  end if;

  if managed_id is not null and p_player_id=managed_id then
    select x.tournament_id,x.tournament_name,x.start_date,x.end_date,x.result_code
    into c
    from (
      select tr.tournament_id,ot.name tournament_name,ot.start_date,ot.end_date,tr.user_round result_code,
             coalesce(ot.main_draw_start_date,ot.start_date) main_start
      from public.tournament_runs tr
      join public.tournaments ot on ot.id=tr.tournament_id
      where tr.tournament_id<>t.id
      union all
      select dr.tournament_id,ot.name,ot.start_date,ot.end_date,dr.user_round,
             coalesce(ot.main_draw_start_date,ot.start_date) main_start
      from public.doubles_runs dr
      join public.tournaments ot on ot.id=dr.tournament_id
      where dr.tournament_id<>t.id
    ) x
    where date_trunc('week',x.main_start::timestamp)::date=week_monday
    order by x.main_start
    limit 1;

    if c.tournament_id is not null then
      return jsonb_build_object('conflict',true,'reason','one_tournament_per_week',
        'other_tournament_id',c.tournament_id,'other_tournament',c.tournament_name);
    end if;
  end if;

  if method in ('qualifying','qualifying_wildcard') then
    select ot.id tournament_id,ot.name tournament_name,ot.start_date,ot.end_date,e.result_code
    into c
    from public.world_tournament_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where e.player_id=p_player_id
      and ot.id<>t.id
      and coalesce(ot.end_date,ot.start_date)>=commit_start
      and coalesce(ot.main_draw_start_date,ot.start_date)<week_monday
      and coalesce(e.result_code,'') in ('W','F','SF')
    order by coalesce(ot.end_date,ot.start_date) desc
    limit 1;

    if c.tournament_id is not null then
      return jsonb_build_object('conflict',true,'reason','still_competing_before_qualifying',
        'other_tournament_id',c.tournament_id,'other_tournament',c.tournament_name,
        'other_result',c.result_code,'qualifying_start',commit_start);
    end if;

    if managed_id is not null and p_player_id=managed_id then
      select tr.tournament_id,ot.name tournament_name,ot.start_date,ot.end_date,tr.user_round result_code
      into c
      from public.tournament_runs tr
      join public.tournaments ot on ot.id=tr.tournament_id
      where tr.tournament_id<>t.id
        and coalesce(ot.end_date,ot.start_date)>=commit_start
        and coalesce(ot.main_draw_start_date,ot.start_date)<week_monday
        and coalesce(tr.user_round,'') in ('Champion','W','F','SF')
      order by coalesce(ot.end_date,ot.start_date) desc
      limit 1;

      if c.tournament_id is not null then
        return jsonb_build_object('conflict',true,'reason','still_competing_before_qualifying',
          'other_tournament_id',c.tournament_id,'other_tournament',c.tournament_name,
          'other_result',c.result_code,'qualifying_start',commit_start);
      end if;
    end if;
  end if;

  return jsonb_build_object('conflict',false,'reason','available',
    'commitment_start',commit_start,'commitment_end',commit_end,'week_monday',week_monday);
end;
$function$;
