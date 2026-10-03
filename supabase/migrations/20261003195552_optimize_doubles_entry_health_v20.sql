-- Court Boss V20.1: cheap doubles entry health audit

CREATE OR REPLACE FUNCTION public.doubles_draw_composition_v20(p_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  d int;
  da int:=0;
  wc int:=0;
  onsite int:=0;
  qdraw int:=0;
  qda int:=0;
  qwc int:=0;
  qslots int:=0;
  model text:='unsupported';
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null then return jsonb_build_object('ok',false,'reason','tournament_missing'); end if;
  d:=greatest(4,least(64,coalesce(t.doubles_draw_size,16)));

  if t.category='Grand Chelem' then
    wc:=least(7,d);da:=d-wc;model:='grand_slam_2026';
  elsif t.circuit='ATP' and t.category='Masters 1000' then
    if d=32 then da:=29;wc:=3;
    elsif d=28 then da:=25;wc:=3;
    elsif d=24 then da:=22;wc:=2;
    else wc:=least(3,greatest(0,d/10));da:=d-wc;
    end if;
    model:='masters_1000_2026';
  elsif t.circuit='ATP' and t.category='ATP 500' then
    wc:=2;qdraw:=4;qda:=3;qwc:=1;qslots:=1;da:=greatest(0,d-wc-qslots);model:='atp_500_2026';
  elsif t.circuit='ATP' and t.category='ATP 250' then
    wc:=2;da:=greatest(0,d-wc);model:='atp_250_2026';
  elsif t.circuit='Challenger' then
    da:=least(10,d);onsite:=least(4,greatest(0,d-da));wc:=greatest(0,d-da-onsite);model:='challenger_2026';
  elsif t.circuit='ITF' and t.category='M25' then
    da:=least(7,greatest(0,d-3));onsite:=greatest(0,d-3-da);wc:=least(3,d);model:='itf_m25_2026';
  elsif t.circuit='ITF' and t.category='M15' then
    da:=0;onsite:=greatest(0,d-3);wc:=least(3,d);model:='itf_m15_2026';
  else
    da:=d;model:='generic';
  end if;

  return jsonb_build_object(
    'ok',true,'draw',d,'advance_or_direct',da,'onsite',onsite,'wildcards',wc,
    'qualifying_draw',qdraw,'qualifying_direct',qda,'qualifying_wildcards',qwc,
    'qualifier_slots',qslots,'model',model
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.doubles_entry_rules_audit_v20(p_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
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
   where circuit='ITF' and category='M15' and extract(year from start_date)=2026 and coalesce(is_active,true)
   order by start_date,id limit 1;
  select id into v_m25 from public.tournaments
   where circuit='ITF' and category='M25' and extract(year from start_date)=2026 and coalesce(is_active,true)
   order by start_date,id limit 1;
  select id into v_atp250 from public.tournaments
   where circuit='ATP' and category='ATP 250' and extract(year from start_date)=2026 and coalesce(is_active,true)
   order by start_date,id limit 1;
  select id into v_atp500 from public.tournaments
   where circuit='ATP' and category='ATP 500' and extract(year from start_date)=2026 and coalesce(is_active,true)
   order by start_date,id limit 1;
  select id into v_m1000 from public.tournaments
   where circuit='ATP' and category='Masters 1000' and extract(year from start_date)=2026 and coalesce(is_active,true)
   order by start_date,id limit 1;
  select id into v_ch from public.tournaments
   where circuit='Challenger' and extract(year from start_date)=2026 and coalesce(is_active,true)
     and coalesce(doubles_draw_size,16)=16
   order by start_date,id limit 1;
  select id into v_gs from public.tournaments
   where category='Grand Chelem' and extract(year from start_date)=2026 and coalesce(is_active,true)
   order by start_date,id limit 1;

  j_m15:=public.doubles_draw_composition_v20(v_m15);
  j_m25:=public.doubles_draw_composition_v20(v_m25);
  j_atp250:=public.doubles_draw_composition_v20(v_atp250);
  j_atp500:=public.doubles_draw_composition_v20(v_atp500);
  j_m1000:=public.doubles_draw_composition_v20(v_m1000);
  j_ch:=public.doubles_draw_composition_v20(v_ch);
  j_gs:=public.doubles_draw_composition_v20(v_gs);

  -- First-five M1000 automatic rule: count canonical 2025 Top-13 teams
  -- that still exist as an active 2026 pair. No expensive field rebuild.
  select count(*)::int into v_auto_m1000
  from public.doubles_race_2025_full d
  where d.is_team=true and d.doubles_race_ranking<=13
    and exists(
      select 1 from public.world_doubles_partnerships w
      where w.season=2026 and w.active=true
        and (
          (w.player_a_id=d.player_one_id and w.player_b_id=d.player_two_id)
          or (w.player_a_id=d.player_two_id and w.player_b_id=d.player_one_id)
        )
    );

  select count(*)::int into v_same_week_conflicts
  from (
    select z.player_id,z.week_start
    from (
      select w.player_a_id player_id,date_trunc('week',t.start_date::timestamp)::date week_start,e.tournament_id
      from public.world_doubles_tournament_entries e
      join public.world_doubles_partnerships w on w.id=e.pair_id
      join public.tournaments t on t.id=e.tournament_id
      union all
      select w.player_b_id,date_trunc('week',t.start_date::timestamp)::date,e.tournament_id
      from public.world_doubles_tournament_entries e
      join public.world_doubles_partnerships w on w.id=e.pair_id
      join public.tournaments t on t.id=e.tournament_id
    ) z
    group by z.player_id,z.week_start
    having count(distinct z.tournament_id)>1
  ) x;

  select count(*)::int into v_retired_pair_entries
  from public.world_doubles_tournament_entries e
  join public.world_doubles_partnerships w on w.id=e.pair_id
  join public.players a on a.id=w.player_a_id
  join public.players b on b.id=w.player_b_id
  where a.career_status<>'active' or b.career_status<>'active';

  select count(*)::int into v_invalid_pair_entries
  from public.world_doubles_tournament_entries e
  left join public.world_doubles_partnerships w on w.id=e.pair_id
  where w.id is null or w.player_a_id=w.player_b_id;

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
    'ok',v_ok,'date',p_date,
    'm15',j_m15,'m25',j_m25,'atp250',j_atp250,'atp500',j_atp500,
    'masters1000',j_m1000,'challenger',j_ch,'grand_slam',j_gs,
    'masters1000_auto_teams',v_auto_m1000,
    'same_week_player_conflicts',v_same_week_conflicts,
    'retired_pair_entries',v_retired_pair_entries,
    'invalid_pair_entries',v_invalid_pair_entries,
    'model','CB-DOUBLES-ENTRY-AUDIT-v20.1'
  );
end;
$function$
;

revoke all on function public.doubles_draw_composition_v20(bigint) from public,anon,authenticated;
revoke all on function public.doubles_entry_rules_audit_v20(date) from public,anon,authenticated;
grant execute on function public.doubles_draw_composition_v20(bigint) to service_role;
grant execute on function public.doubles_entry_rules_audit_v20(date) to service_role;
