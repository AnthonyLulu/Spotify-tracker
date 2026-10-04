-- Court Boss V23.1: keep long-career doubles health audits fast and season-scoped

CREATE INDEX IF NOT EXISTS idx_tournaments_entry_audit_v23
ON public.tournaments (circuit, category, start_date, doubles_draw_size, id)
WHERE coalesce(is_active,true);

CREATE INDEX IF NOT EXISTS idx_tournaments_category_date_v23
ON public.tournaments (category, start_date, id)
WHERE coalesce(is_active,true);

CREATE OR REPLACE FUNCTION public.doubles_entry_rules_audit_v20(p_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  v_year int:=extract(year from coalesce(p_date,current_date))::int;
  v_start date:=make_date(v_year,1,1);
  v_end date:=make_date(v_year+1,1,1);
  v_m15 bigint; v_m25 bigint; v_atp250 bigint; v_atp500 bigint;
  v_m1000 bigint; v_ch bigint; v_gs bigint;
  j_m15 jsonb:='{}'::jsonb; j_m25 jsonb:='{}'::jsonb;
  j_atp250 jsonb:='{}'::jsonb; j_atp500 jsonb:='{}'::jsonb;
  j_m1000 jsonb:='{}'::jsonb; j_ch jsonb:='{}'::jsonb; j_gs jsonb:='{}'::jsonb;
  v_auto_m1000 int:=0;
  v_same_week_conflicts int:=0;
  v_retired_pair_entries int:=0;
  v_invalid_pair_entries int:=0;
  v_ok boolean:=false;
begin
  select id into v_m15 from public.tournaments
   where circuit='ITF' and category='M15'
     and start_date>=v_start and start_date<v_end and coalesce(is_active,true)
   order by start_date,id limit 1;

  select id into v_m25 from public.tournaments
   where circuit='ITF' and category='M25'
     and start_date>=v_start and start_date<v_end and coalesce(is_active,true)
   order by start_date,id limit 1;

  select id into v_atp250 from public.tournaments
   where circuit='ATP' and category='ATP 250'
     and start_date>=v_start and start_date<v_end and coalesce(is_active,true)
   order by start_date,id limit 1;

  select id into v_atp500 from public.tournaments
   where circuit='ATP' and category='ATP 500'
     and start_date>=v_start and start_date<v_end and coalesce(is_active,true)
   order by start_date,id limit 1;

  select id into v_m1000 from public.tournaments
   where circuit='ATP' and category='Masters 1000'
     and start_date>=v_start and start_date<v_end and coalesce(is_active,true)
   order by start_date,id limit 1;

  select id into v_ch from public.tournaments
   where circuit='Challenger'
     and start_date>=v_start and start_date<v_end and coalesce(is_active,true)
     and coalesce(doubles_draw_size,16)=16
   order by start_date,id limit 1;

  select id into v_gs from public.tournaments
   where category='Grand Chelem'
     and start_date>=v_start and start_date<v_end and coalesce(is_active,true)
   order by start_date,id limit 1;

  j_m15:=public.doubles_draw_composition_v20(v_m15);
  j_m25:=public.doubles_draw_composition_v20(v_m25);
  j_atp250:=public.doubles_draw_composition_v20(v_atp250);
  j_atp500:=public.doubles_draw_composition_v20(v_atp500);
  j_m1000:=public.doubles_draw_composition_v20(v_m1000);
  j_ch:=public.doubles_draw_composition_v20(v_ch);
  j_gs:=public.doubles_draw_composition_v20(v_gs);

  select count(*)::int into v_auto_m1000
  from public.doubles_race_2025_full d
  where d.is_team=true and d.doubles_race_ranking<=13
    and exists(
      select 1
      from public.world_doubles_partnerships w
      where w.season=v_year and w.active=true
        and (
          (w.player_a_id=d.player_one_id and w.player_b_id=d.player_two_id)
          or (w.player_a_id=d.player_two_id and w.player_b_id=d.player_one_id)
        )
    );

  select count(*)::int into v_same_week_conflicts
  from (
    select q.player_id,q.week_start
    from (
      select p.player_id,
             date_trunc('week',t.start_date::timestamp)::date week_start,
             e.tournament_id
      from public.world_doubles_tournament_entries e
      join public.world_doubles_partnerships w on w.id=e.pair_id
      join public.tournaments t on t.id=e.tournament_id
      cross join lateral (values (w.player_a_id),(w.player_b_id)) p(player_id)
      where t.start_date>=v_start and t.start_date<v_end
    ) q
    group by q.player_id,q.week_start
    having count(distinct q.tournament_id)>1
  ) x;

  select count(*)::int into v_retired_pair_entries
  from public.world_doubles_tournament_entries e
  join public.world_doubles_partnerships w on w.id=e.pair_id
  join public.players a on a.id=w.player_a_id
  join public.players b on b.id=w.player_b_id
  join public.tournaments t on t.id=e.tournament_id
  where t.start_date>=v_start and t.start_date<v_end
    and (a.career_status<>'active' or b.career_status<>'active');

  select count(*)::int into v_invalid_pair_entries
  from public.world_doubles_tournament_entries e
  join public.tournaments t on t.id=e.tournament_id
  left join public.world_doubles_partnerships w on w.id=e.pair_id
  where t.start_date>=v_start and t.start_date<v_end
    and (w.id is null or w.player_a_id=w.player_b_id);

  v_ok:=
    (j_m15->>'draw')::int=16 and (j_m15->>'advance_or_direct')::int=0
      and (j_m15->>'onsite')::int=13 and (j_m15->>'wildcards')::int=3
    and (j_m25->>'draw')::int=16 and (j_m25->>'advance_or_direct')::int=7
      and (j_m25->>'onsite')::int=6 and (j_m25->>'wildcards')::int=3
    and (j_atp250->>'draw')::int=16 and (j_atp250->>'advance_or_direct')::int=14
      and (j_atp250->>'wildcards')::int=2
    and (j_atp500->>'draw')::int=16 and (j_atp500->>'advance_or_direct')::int=13
      and (j_atp500->>'wildcards')::int=2
      and (j_atp500->>'qualifying_direct')::int=3
      and (j_atp500->>'qualifying_wildcards')::int=1
      and (j_atp500->>'qualifier_slots')::int=1
    and (j_m1000->>'draw')::int=32 and (j_m1000->>'advance_or_direct')::int=29
      and (j_m1000->>'wildcards')::int=3
    and v_auto_m1000 between 1 and 13
    and (j_ch->>'draw')::int=16 and (j_ch->>'advance_or_direct')::int=10
      and (j_ch->>'onsite')::int=4 and (j_ch->>'wildcards')::int=2
    and (j_gs->>'draw')::int=64 and (j_gs->>'advance_or_direct')::int=57
      and (j_gs->>'wildcards')::int=7
    and v_same_week_conflicts=0
    and v_retired_pair_entries=0
    and v_invalid_pair_entries=0;

  return jsonb_build_object(
    'ok',v_ok,'date',p_date,'season',v_year,
    'm15',j_m15,'m25',j_m25,'atp250',j_atp250,'atp500',j_atp500,
    'masters1000',j_m1000,'challenger',j_ch,'grand_slam',j_gs,
    'masters1000_auto_teams',v_auto_m1000,
    'same_week_player_conflicts',v_same_week_conflicts,
    'retired_pair_entries',v_retired_pair_entries,
    'invalid_pair_entries',v_invalid_pair_entries,
    'model','CB-DOUBLES-ENTRY-AUDIT-v23.1'
  );
end;
$function$;

revoke all on function public.doubles_entry_rules_audit_v20(date) from public,anon,authenticated;
grant execute on function public.doubles_entry_rules_audit_v20(date) to service_role;
