-- Court Boss unified circuit engine v1
-- DB migration version: 20260930193645
-- Central eligibility arbitration + weekly orchestration across pro singles,
-- pro doubles, juniors and NCAA. Competition-specific draw engines stay authoritative.

CREATE OR REPLACE FUNCTION public.player_event_eligibility(p_player_id bigint, p_tournament_id bigint, p_discipline text DEFAULT 'singles'::text, p_entry_method text DEFAULT 'direct'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  p public.players%rowtype;
  t public.tournaments%rowtype;
  v_discipline text:=lower(coalesce(p_discipline,'singles'));
  v_method text:=lower(coalesce(p_entry_method,'direct'));
  v_age int;
  v_base jsonb;
  v_conflict jsonb;
begin
  select * into p from public.players where id=p_player_id;
  select * into t from public.tournaments where id=p_tournament_id;

  if p.id is null or t.id is null then
    return jsonb_build_object('eligible',false,'reason','missing_player_or_tournament');
  end if;

  if coalesce(p.career_status,'active')<>'active' then
    return jsonb_build_object('eligible',false,'reason','inactive_player','discipline',v_discipline);
  end if;
  if coalesce(p.injury_status,'Fit')<>'Fit' then
    return jsonb_build_object('eligible',false,'reason','injured','discipline',v_discipline);
  end if;
  if coalesce(p.fitness,90)<45 then
    return jsonb_build_object('eligible',false,'reason','fitness_too_low','discipline',v_discipline);
  end if;
  if coalesce(p.fatigue,20)>90 then
    return jsonb_build_object('eligible',false,'reason','fatigue_too_high','discipline',v_discipline);
  end if;

  if v_discipline in ('singles','pro_singles') then
    if coalesce(p.career_focus,'mixed')='doubles_only' then
      return jsonb_build_object('eligible',false,'reason','doubles_only','discipline','singles');
    end if;
    if coalesce(t.circuit,'') not in ('ATP','Challenger','ITF') then
      return jsonb_build_object('eligible',false,'reason','wrong_circuit_for_pro_singles','circuit',t.circuit);
    end if;

    v_base:=public.tournament_entry_eligibility(p.id,t.id,v_method);
    if not coalesce((v_base->>'eligible')::boolean,false) then
      return v_base || jsonb_build_object('discipline','singles','arbiter','CB-UNIFIED-ELIGIBILITY-v1');
    end if;

  elsif v_discipline in ('doubles','pro_doubles') then
    if coalesce(p.career_focus,'mixed')='singles_only' then
      return jsonb_build_object('eligible',false,'reason','singles_only','discipline','doubles');
    end if;
    if coalesce(t.circuit,'') not in ('ATP','Challenger','ITF') then
      return jsonb_build_object('eligible',false,'reason','wrong_circuit_for_pro_doubles','circuit',t.circuit);
    end if;
    if t.circuit='ITF' and coalesce(p.ranking,999999)<=200 then
      return jsonb_build_object('eligible',false,'reason','itf_play_down_top200','discipline','doubles');
    end if;
    if t.circuit='ITF' and coalesce(p.doubles_ranking,999999)<=150 then
      return jsonb_build_object('eligible',false,'reason','itf_doubles_play_down_top150','discipline','doubles');
    end if;
    if t.circuit='Challenger' and coalesce(p.ranking,999999)<=10 then
      return jsonb_build_object('eligible',false,'reason','challenger_top10_prohibited','discipline','doubles');
    end if;
    if t.category='Challenger 50' and coalesce(p.ranking,999999)<=50 then
      return jsonb_build_object('eligible',false,'reason','ch50_top50_prohibited','discipline','doubles');
    end if;
    if t.category='Challenger 75' and coalesce(p.ranking,999999)<=30 then
      return jsonb_build_object('eligible',false,'reason','ch75_elite_play_down_guard','discipline','doubles');
    end if;

  elsif v_discipline in ('junior','junior_singles','junior_doubles') then
    if coalesce(t.circuit,'')<>'Junior' then
      return jsonb_build_object('eligible',false,'reason','wrong_circuit_for_junior','circuit',t.circuit);
    end if;
    v_age:=coalesce(
      case when p.birth_date is not null then extract(year from age(t.start_date,p.birth_date))::int end,
      p.age,99
    );
    if v_age<13 or v_age>18 then
      return jsonb_build_object('eligible',false,'reason','junior_age_ineligible','age',v_age);
    end if;
    if v_discipline='junior_doubles' and coalesce(p.career_focus,'mixed')='singles_only' then
      return jsonb_build_object('eligible',false,'reason','singles_only','discipline','junior_doubles');
    end if;
    if v_discipline in ('junior','junior_singles') and coalesce(p.career_focus,'mixed')='doubles_only' then
      return jsonb_build_object('eligible',false,'reason','doubles_only','discipline','junior_singles');
    end if;

  elsif v_discipline in ('ncaa','ncaa_singles','ncaa_doubles') then
    if coalesce(t.circuit,'')<>'NCAA' then
      return jsonb_build_object('eligible',false,'reason','wrong_circuit_for_ncaa','circuit',t.circuit);
    end if;
    if not coalesce(p.ncaa_current,false) then
      return jsonb_build_object('eligible',false,'reason','not_current_ncaa_player','discipline',v_discipline);
    end if;

  else
    return jsonb_build_object('eligible',false,'reason','unsupported_discipline','discipline',v_discipline);
  end if;

  v_conflict:=public.player_tournament_calendar_conflict(p.id,t.id,
    case
      when v_method in ('qualifying','qualifying_wildcard','protected_qualifying','doubles_qualifying')
        then v_method
      else 'direct'
    end
  );

  if coalesce((v_conflict->>'conflict')::boolean,false) then
    return jsonb_build_object(
      'eligible',false,'reason','calendar_conflict','discipline',v_discipline,
      'calendar',v_conflict,'arbiter','CB-UNIFIED-ELIGIBILITY-v1'
    );
  end if;

  return coalesce(v_base,'{}'::jsonb) || jsonb_build_object(
    'eligible',true,'reason','eligible','discipline',v_discipline,
    'entry_method',v_method,'calendar',v_conflict,
    'arbiter','CB-UNIFIED-ELIGIBILITY-v1'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.tournament_candidate_player_ids(p_tournament_id bigint, p_entry_method text DEFAULT 'candidate'::text, p_limit integer DEFAULT 256)
 RETURNS TABLE(player_id bigint, effective_rank integer)
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  v_min int:=1;
  v_max int:=30000;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null then return; end if;

  if t.category='Grand Chelem' then v_min:=1;v_max:=650;
  elsif t.category='Masters 1000' then v_min:=1;v_max:=600;
  elsif t.category='ATP 500' then v_min:=1;v_max:=900;
  elsif t.category='ATP 250' then v_min:=1;v_max:=1600;
  elsif t.category='Challenger 175' then v_min:=20;v_max:=2200;
  elsif t.category='Challenger 125' then v_min:=11;v_max:=3200;
  elsif t.category='Challenger 100' then v_min:=11;v_max:=5000;
  elsif t.category='Challenger 75' then v_min:=51;v_max:=8000;
  elsif t.category='Challenger 50' then v_min:=151;v_max:=14000;
  elsif t.category='M25' then v_min:=201;v_max:=22000;
  elsif t.category='M15' then v_min:=201;v_max:=30000;
  end if;

  return query
  select
    p.id,
    coalesce((elig.j->>'ranking')::int,
             public.player_rank_at_date(p.id,coalesce(t.main_entry_deadline,t.start_date-21)),
             999999)::int
  from public.players p
  cross join lateral (
    select public.player_event_eligibility(
      p.id,t.id,'singles',p_entry_method
    ) j
  ) elig
  where p.career_status='active'
    and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
    and coalesce((elig.j->>'eligible')::boolean,false)
    and coalesce(
      (elig.j->>'ranking')::int,
      public.player_rank_at_date(p.id,coalesce(t.main_entry_deadline,t.start_date-21)),
      999999
    ) between v_min and v_max
  order by
    coalesce(
      (elig.j->>'ranking')::int,
      public.player_rank_at_date(p.id,coalesce(t.main_entry_deadline,t.start_date-21)),
      999999
    ),
    p.current_ability desc,p.id
  limit greatest(16,least(coalesce(p_limit,256),2000));
end
$function$;

CREATE OR REPLACE FUNCTION public.audit_unified_circuit_integrity(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  v_overlaps int:=0;
  v_top200_itf int:=0;
  v_doubles_only_singles int:=0;
  v_singles_only_doubles int:=0;
  v_bad_junior_age int:=0;
  v_missing_standard_formats int:=0;
  v_missing_prize_profiles int:=0;
begin
  with raw_commitments as (
    select e.player_id,'T:'||t.id::text event_key,t.id tournament_id,
           coalesce(t.qualifying_start_date,t.main_draw_start_date,t.start_date) start_date,
           coalesce(t.end_date,t.start_date) end_date
    from public.world_tournament_entries e
    join public.tournaments t on t.id=e.tournament_id
    where coalesce(t.end_date,t.start_date)>=p_from_date and t.start_date<=p_to_date
    union all
    select e.player_id,'T:'||t.id::text,t.id,
           coalesce(t.qualifying_start_date,t.start_date),
           coalesce(t.qualifying_end_date,t.main_draw_start_date,t.end_date,t.start_date)
    from public.world_tournament_qualifying_entries e
    join public.tournaments t on t.id=e.tournament_id
    where coalesce(t.qualifying_end_date,t.end_date,t.start_date)>=p_from_date
      and coalesce(t.qualifying_start_date,t.start_date)<=p_to_date
    union all
    select wp.player_a_id,'T:'||t.id::text,t.id,
           coalesce(t.qualifying_start_date,t.main_draw_start_date,t.start_date),
           coalesce(t.end_date,t.start_date)
    from public.world_doubles_tournament_entries e
    join public.world_doubles_partnerships wp on wp.id=e.pair_id
    join public.tournaments t on t.id=e.tournament_id
    where coalesce(t.end_date,t.start_date)>=p_from_date and t.start_date<=p_to_date
    union all
    select wp.player_b_id,'T:'||t.id::text,t.id,
           coalesce(t.qualifying_start_date,t.main_draw_start_date,t.start_date),
           coalesce(t.end_date,t.start_date)
    from public.world_doubles_tournament_entries e
    join public.world_doubles_partnerships wp on wp.id=e.pair_id
    join public.tournaments t on t.id=e.tournament_id
    where coalesce(t.end_date,t.start_date)>=p_from_date and t.start_date<=p_to_date
    union all
    select e.player_id,'T:'||t.id::text,t.id,t.start_date,coalesce(t.end_date,t.start_date)
    from public.junior_tournament_entries e
    join public.tournaments t on t.id=e.tournament_id
    where t.start_date>date '2025-12-01'
      and coalesce(t.end_date,t.start_date)>=p_from_date and t.start_date<=p_to_date
    union all
    select e.player_a_id,'T:'||t.id::text,t.id,t.start_date,coalesce(t.end_date,t.start_date)
    from public.world_junior_doubles_entries e
    join public.tournaments t on t.id=e.tournament_id
    where coalesce(t.end_date,t.start_date)>=p_from_date and t.start_date<=p_to_date
    union all
    select e.player_b_id,'T:'||t.id::text,t.id,t.start_date,coalesce(t.end_date,t.start_date)
    from public.world_junior_doubles_entries e
    join public.tournaments t on t.id=e.tournament_id
    where coalesce(t.end_date,t.start_date)>=p_from_date and t.start_date<=p_to_date
    union all
    select e.player_id,'T:'||t.id::text,t.id,t.start_date,coalesce(t.end_date,t.start_date)
    from public.ncaa_individual_entries e
    join public.tournaments t on t.id=e.tournament_id
    where coalesce(t.end_date,t.start_date)>=p_from_date and t.start_date<=p_to_date
    union all
    select e.player_a_id,'T:'||t.id::text,t.id,t.start_date,coalesce(t.end_date,t.start_date)
    from public.ncaa_individual_doubles_entries e
    join public.tournaments t on t.id=e.tournament_id
    where coalesce(t.end_date,t.start_date)>=p_from_date and t.start_date<=p_to_date
    union all
    select e.player_b_id,'T:'||t.id::text,t.id,t.start_date,coalesce(t.end_date,t.start_date)
    from public.ncaa_individual_doubles_entries e
    join public.tournaments t on t.id=e.tournament_id
    where coalesce(t.end_date,t.start_date)>=p_from_date and t.start_date<=p_to_date
  ),
  commitments as (
    select player_id,event_key,tournament_id,min(start_date) start_date,max(end_date) end_date
    from raw_commitments
    group by player_id,event_key,tournament_id
  )
  select count(*) into v_overlaps
  from commitments a
  join commitments b
    on a.player_id=b.player_id
   and a.event_key<b.event_key
   and daterange(a.start_date,a.end_date,'[]') && daterange(b.start_date,b.end_date,'[]');

  select count(*) into v_top200_itf
  from (
    select e.player_id,t.id,
           public.player_rank_at_date(e.player_id,coalesce(t.main_entry_deadline,t.start_date-21)) r
    from public.world_tournament_entries e
    join public.tournaments t on t.id=e.tournament_id
    where t.circuit='ITF' and t.category in ('M15','M25')
      and t.start_date between p_from_date and p_to_date
    union all
    select e.player_id,t.id,
           public.player_rank_at_date(e.player_id,coalesce(t.qualifying_entry_deadline,t.start_date-21))
    from public.world_tournament_qualifying_entries e
    join public.tournaments t on t.id=e.tournament_id
    where t.circuit='ITF' and t.category in ('M15','M25')
      and t.start_date between p_from_date and p_to_date
  ) x
  where x.r between 1 and 200;

  select count(*) into v_doubles_only_singles
  from (
    select distinct e.player_id
    from public.world_tournament_entries e
    join public.tournaments t on t.id=e.tournament_id
    join public.players p on p.id=e.player_id
    where t.start_date between p_from_date and p_to_date and p.career_focus='doubles_only'
    union
    select distinct e.player_id
    from public.world_tournament_qualifying_entries e
    join public.tournaments t on t.id=e.tournament_id
    join public.players p on p.id=e.player_id
    where t.start_date between p_from_date and p_to_date and p.career_focus='doubles_only'
  ) x;

  select count(*) into v_singles_only_doubles
  from (
    select wp.player_a_id player_id,t.id
    from public.world_doubles_tournament_entries e
    join public.world_doubles_partnerships wp on wp.id=e.pair_id
    join public.tournaments t on t.id=e.tournament_id
    join public.players p on p.id=wp.player_a_id
    where t.start_date between p_from_date and p_to_date and p.career_focus='singles_only'
    union all
    select wp.player_b_id,t.id
    from public.world_doubles_tournament_entries e
    join public.world_doubles_partnerships wp on wp.id=e.pair_id
    join public.tournaments t on t.id=e.tournament_id
    join public.players p on p.id=wp.player_b_id
    where t.start_date between p_from_date and p_to_date and p.career_focus='singles_only'
  ) x;

  select count(*) into v_bad_junior_age
  from public.junior_tournament_entries e
  join public.tournaments t on t.id=e.tournament_id
  join public.players p on p.id=e.player_id
  where t.circuit='Junior'
    and t.start_date>date '2025-12-01'
    and t.start_date between p_from_date and p_to_date
    and coalesce(
      case when p.birth_date is not null then extract(year from age(t.start_date,p.birth_date))::int end,
      p.age,99
    ) not between 13 and 18;

  select count(*) into v_missing_standard_formats
  from public.tournaments t
  where coalesce(t.is_active,true)=true
    and t.start_date between p_from_date and p_to_date
    and (
      t.circuit in ('ATP','Challenger','ITF')
      or (t.circuit='Junior' and t.category not in ('Junior Davis Cup','Junior Finals','Junior Double Finals'))
    )
    and t.category not in ('United Cup','Laver Cup','Davis Cup')
    and not exists(
      select 1 from public.tournament_format_rules r
      where r.circuit=t.circuit and r.category=t.category
        and r.main_draw_size=coalesce(t.singles_draw_size,t.draw_size)
    );

  select count(*) into v_missing_prize_profiles
  from public.tournaments t
  where coalesce(t.is_active,true)=true
    and t.start_date between p_from_date and p_to_date
    and t.circuit in ('ATP','Challenger','ITF')
    and t.category not in ('ATP Finals','Next Gen Finals','United Cup','Laver Cup')
    and (
      coalesce(t.singles_prize_by_result,'{}'::jsonb)='{}'::jsonb
      or (coalesce(t.doubles_draw_size,0)>0 and coalesce(t.doubles_prize_by_result,'{}'::jsonb)='{}'::jsonb)
    );

  return jsonb_build_object(
    'ok',v_overlaps=0 and v_top200_itf=0 and v_doubles_only_singles=0
         and v_singles_only_doubles=0 and v_bad_junior_age=0
         and v_missing_standard_formats=0 and v_missing_prize_profiles=0,
    'calendar_overlap_pairs',v_overlaps,
    'top200_itf_playdown_violations',v_top200_itf,
    'doubles_only_in_singles',v_doubles_only_singles,
    'singles_only_in_doubles',v_singles_only_doubles,
    'junior_age_violations',v_bad_junior_age,
    'missing_standard_format_rules',v_missing_standard_formats,
    'missing_prize_profiles',v_missing_prize_profiles,
    'historical_identity_debt_excluded_through','2025-12-01',
    'from',p_from_date,'to',p_to_date,
    'model','CB-UNIFIED-INTEGRITY-v2'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.run_unified_circuit_window(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_davis jsonb;
  v_junior_davis jsonb;
  v_united jsonb;
  v_laver_prepare jsonb;
  v_laver jsonb;
  v_ncaa_team_prepare jsonb;
  v_ncaa_priority jsonb;
  v_acceptance jsonb;
  v_reconcile jsonb;
  v_qualifying jsonb;
  v_doubles_qualifying jsonb;
  v_progressive jsonb;
  v_world jsonb;
  v_atp_finals_d_prepare jsonb;
  v_atp_finals_d jsonb;
  v_ncaa_team jsonb;
  v_junior_qualifying jsonb;
  v_junior_doubles_prepare jsonb;
  v_junior_world jsonb;
  v_ncaa_individual jsonb;
  v_ncaa_duals jsonb;
  v_world_doubles jsonb;
  v_integrity jsonb;
begin
  perform pg_advisory_xact_lock(94832030);

  if p_to_date<=date '2025-12-01' then
    return jsonb_build_object(
      'ok',true,'historical_cutoff',true,'from',p_from_date,'to',p_to_date,
      'integrity',public.audit_unified_circuit_integrity(p_from_date,p_to_date)
    );
  end if;

  v_davis:=public.simulate_world_davis_ties(p_from_date,p_to_date);
  v_junior_davis:=public.simulate_junior_davis_cup(p_from_date,p_to_date);
  v_united:=public.simulate_united_cup_window(p_from_date,p_to_date);
  v_laver_prepare:=public.prepare_laver_cup_window(p_from_date,p_to_date);
  v_laver:=public.simulate_laver_cup(p_from_date,p_to_date);

  v_ncaa_team_prepare:=public.prepare_ita_team_events(p_from_date,p_to_date);
  v_ncaa_priority:=public.prepare_ncaa_priority_individual_events(p_from_date,p_to_date);

  v_acceptance:=public.refresh_world_acceptance_window(p_from_date,p_to_date);
  v_reconcile:=public.reconcile_world_acceptance_commitments(p_from_date,p_to_date);

  v_qualifying:=public.simulate_world_qualifying_window(p_from_date,p_to_date);
  v_doubles_qualifying:=public.simulate_world_doubles_qualifying_window(p_from_date,p_to_date);

  v_progressive:=public.advance_world_tournament_window(p_from_date,p_to_date);
  v_world:=public.simulate_world_tournaments(p_from_date,p_to_date);

  v_atp_finals_d_prepare:=public.prepare_atp_finals_doubles_window(p_from_date,p_to_date);
  v_atp_finals_d:=public.simulate_atp_finals_doubles(p_from_date,p_to_date);

  v_ncaa_team:=public.simulate_ita_team_event_results(p_from_date,p_to_date);

  v_junior_qualifying:=public.simulate_junior_qualifying_window(p_from_date,p_to_date);
  v_junior_doubles_prepare:=public.prepare_junior_doubles_window(p_from_date,p_to_date);
  v_junior_world:=public.simulate_junior_world_tournaments(p_from_date,p_to_date);

  v_ncaa_individual:=public.simulate_ncaa_individual_events(p_from_date,p_to_date);
  v_ncaa_duals:=public.simulate_ncaa_duals(p_from_date,p_to_date);

  v_world_doubles:=public.simulate_world_doubles_tournaments(p_from_date,p_to_date);
  v_integrity:=public.audit_unified_circuit_integrity(p_from_date,p_to_date);

  return jsonb_build_object(
    'ok',coalesce((v_integrity->>'ok')::boolean,false),
    'from',p_from_date,'to',p_to_date,
    'davis',v_davis,'junior_davis',v_junior_davis,'united_cup',v_united,
    'laver_prepare',v_laver_prepare,'laver',v_laver,
    'ncaa_team_prepare',v_ncaa_team_prepare,'ncaa_priority',v_ncaa_priority,
    'world_acceptance',v_acceptance,'world_acceptance_reconcile',v_reconcile,
    'world_qualifying',v_qualifying,'world_doubles_qualifying',v_doubles_qualifying,
    'progressive_world',v_progressive,'world_tournaments',v_world,
    'atp_finals_doubles_prepare',v_atp_finals_d_prepare,'atp_finals_doubles',v_atp_finals_d,
    'ncaa_team',v_ncaa_team,'junior_qualifying',v_junior_qualifying,
    'junior_doubles_prepare',v_junior_doubles_prepare,'junior_world',v_junior_world,
    'ncaa_individual',v_ncaa_individual,'ncaa_duals',v_ncaa_duals,
    'world_doubles',v_world_doubles,'integrity',v_integrity,
    'model','CB-UNIFIED-CIRCUIT-v1'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.ai_player_commits_to_tournament(p_player_id bigint, p_tournament_id bigint)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  p public.players%rowtype;
  t public.tournaments%rowtype;
  sp public.player_season_plans%rowtype;
  prob numeric;
  roll numeric;
  r int;
  v_week date;
  v_year int;
  v_played int:=0;
  v_consecutive int:=0;
  v_i int;
  v_max_consecutive int;
  v_rest_trigger int;
  v_target int;
  v_previous_country text;
  v_commitment_rank int;
  v_atp500_count int:=0;
  v_post_uso_500_count int:=0;
  v_major boolean:=false;
  v_unified_eligibility jsonb;
begin
  v_unified_eligibility:=public.player_event_eligibility(
    p_player_id,p_tournament_id,'singles','candidate'
  );
  if not coalesce((v_unified_eligibility->>'eligible')::boolean,false) then
    return false;
  end if;
  select * into p from public.players where id=p_player_id;
  select * into t from public.tournaments where id=p_tournament_id;
  if p.id is null or t.id is null then return false; end if;

  if (public.player_tournament_calendar_conflict(p.id,t.id,'candidate')->>'conflict')::boolean then
    return false;
  end if;

  select * into sp
  from public.player_season_plans s
  where s.player_id=p.id and s.season=extract(year from t.start_date)::int;

  r:=coalesce(case when p.ranking_current then p.ranking end,p.game_world_rank,p.ranking,999999);
  v_year:=extract(year from t.start_date)::int;
  v_week:=date_trunc('week',coalesce(t.main_draw_start_date,t.start_date)::timestamp)::date;
  v_max_consecutive:=greatest(1,coalesce(sp.max_consecutive_weeks,case when p.age>=32 then 2 else 3 end));
  v_rest_trigger:=coalesce(sp.rest_trigger_fatigue,72);
  v_target:=coalesce(sp.target_events,22);
  v_major:=coalesce(t.category,'') in ('Grand Chelem','Masters 1000','ATP Finals','Next Gen Finals');

  select count(distinct z.tournament_id)::int
  into v_played
  from (
    select e.tournament_id
    from public.world_tournament_entries e
    join public.tournaments et on et.id=e.tournament_id
    where e.player_id=p.id
      and extract(year from et.start_date)::int=v_year
      and et.start_date<t.start_date
    union
    select e.tournament_id
    from public.world_tournament_qualifying_entries e
    join public.tournaments et on et.id=e.tournament_id
    where e.player_id=p.id
      and extract(year from et.start_date)::int=v_year
      and et.start_date<t.start_date
    union
    select e.tournament_id
    from public.world_doubles_tournament_entries e
    join public.world_doubles_partnerships wp on wp.id=e.pair_id
    join public.tournaments et on et.id=e.tournament_id
    where p.id in (wp.player_a_id,wp.player_b_id)
      and extract(year from et.start_date)::int=v_year
      and et.start_date<t.start_date
    union
    select e.tournament_id
    from public.world_junior_doubles_entries e
    join public.tournaments et on et.id=e.tournament_id
    where p.id in (e.player_a_id,e.player_b_id)
      and extract(year from et.start_date)::int=v_year
      and et.start_date<t.start_date
    union
    select e.tournament_id
    from public.ncaa_individual_entries e
    join public.tournaments et on et.id=e.tournament_id
    where e.player_id=p.id
      and extract(year from et.start_date)::int=v_year
      and et.start_date<t.start_date
    union
    select 1000000000::bigint+extract(doy from cd.match_date)::bigint
    from public.college_teams ct
    join public.college_duals cd on ct.id in (cd.home_team_id,cd.away_team_id)
    where p.ncaa_current=true
      and p.ncaa_school=ct.name
      and cd.status='completed'
      and extract(year from cd.match_date)::int=v_year
      and cd.match_date<t.start_date
    union
    select 2000000000::bigint+dt.id
    from public.davis_squad ds
    join public.davis_ties dt on ds.nation in (dt.home_nation,dt.away_nation)
    where ds.player_id=p.id
      and dt.status='completed'
      and extract(year from dt.tie_date)::int=v_year
      and dt.tie_date<t.start_date
  ) z;

  for v_i in 1..5 loop
    if public.player_has_world_event_in_week(p.id,v_week-(v_i*7),null) then
      v_consecutive:=v_consecutive+1;
    else
      exit;
    end if;
  end loop;

  if v_consecutive>=v_max_consecutive and not v_major then
    return false;
  end if;

  if coalesce(p.fatigue,20)>=v_rest_trigger+10 and not v_major then
    return false;
  end if;

  prob:=public.ai_tournament_commitment_probability(
    r,coalesce(sp.plan_type,'tour_regular'),v_target,
    sp.preferred_surface,t.surface,t.category,p.country,t.country,
    coalesce(p.fatigue,20),v_rest_trigger
  );

  if v_played>=v_target then
    prob:=prob-case
      when v_major then 0
      when coalesce(sp.schedule_risk_tolerance,10)>=15 then 12
      else 28 end;
  end if;
  if v_played>=v_target+4 and not v_major then
    prob:=least(prob,18);
  end if;

  if coalesce(sp.plan_type,'')='ncaa_pathway' then
    if extract(month from t.start_date) between 1 and 5 then
      prob:=prob-case
        when t.circuit='ITF' then 24
        when t.circuit='Challenger' then 34
        else 45 end;
    elsif extract(month from t.start_date) between 6 and 8 then
      prob:=prob+case
        when t.circuit='ITF' then 14
        when t.circuit='Challenger' then 8
        else 0 end;
    else
      prob:=prob-case
        when t.circuit='ITF' then 8
        else 18 end;
    end if;
  end if;

  select x.country into v_previous_country
  from (
    select et.country,coalesce(et.end_date,et.start_date) event_date
    from public.world_tournament_entries e
    join public.tournaments et on et.id=e.tournament_id
    where e.player_id=p.id and et.start_date<t.start_date
    union all
    select et.country,coalesce(et.end_date,et.start_date)
    from public.world_doubles_tournament_entries e
    join public.world_doubles_partnerships wp on wp.id=e.pair_id
    join public.tournaments et on et.id=e.tournament_id
    where p.id in (wp.player_a_id,wp.player_b_id) and et.start_date<t.start_date
    union all
    select et.country,coalesce(et.end_date,et.start_date)
    from public.world_junior_doubles_entries e
    join public.tournaments et on et.id=e.tournament_id
    where p.id in (e.player_a_id,e.player_b_id) and et.start_date<t.start_date
  ) x
  order by x.event_date desc
  limit 1;

  if v_previous_country is not null
     and t.country is not null
     and v_previous_country is distinct from t.country then
    prob:=prob-greatest(2,14-coalesce(sp.travel_tolerance,10)*.55);
  end if;

  if t.circuit='ATP' and v_year>=2026 then
    v_commitment_rank:=public.player_rank_at_date(
      p.id,make_date(v_year-1,11,10)
    );
    v_commitment_rank:=coalesce(v_commitment_rank,r);

    if v_commitment_rank between 1 and 30 then
      if t.category in ('Grand Chelem','Masters 1000') then
        prob:=greatest(prob,97);
      elsif t.category='ATP 500' then
        select count(distinct e.tournament_id)::int
        into v_atp500_count
        from public.world_tournament_entries e
        join public.tournaments et on et.id=e.tournament_id
        where e.player_id=p.id
          and et.circuit='ATP' and et.category='ATP 500'
          and extract(year from et.start_date)::int=v_year
          and et.start_date<t.start_date;

        select count(distinct e.tournament_id)::int
        into v_post_uso_500_count
        from public.world_tournament_entries e
        join public.tournaments et on et.id=e.tournament_id
        where e.player_id=p.id
          and et.circuit='ATP' and et.category='ATP 500'
          and extract(year from et.start_date)::int=v_year
          and extract(month from et.start_date)>=9
          and et.start_date<t.start_date;

        if v_atp500_count<4 then prob:=greatest(prob,78); end if;
        if extract(month from t.start_date)>=9 and v_post_uso_500_count=0 then
          prob:=greatest(prob,91);
        end if;
      end if;
    end if;
  end if;

  prob:=greatest(2,least(99,prob));
  roll:=(mod(abs(hashtext('ai-commit-v2|'||t.id::text||'|'||p.id::text)),10000)::numeric)/100.0;
  return roll<prob;
end;
$function$;

CREATE OR REPLACE FUNCTION public.ai_player_commits_to_doubles_tournament(p_player_id bigint, p_tournament_id bigint)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  p public.players%rowtype;
  t public.tournaments%rowtype;
  sp public.player_season_plans%rowtype;
  prob numeric;
  roll numeric;
  v_week date;
  v_i int;
  v_consecutive int:=0;
  v_max_consecutive int;
  v_rest_trigger int;
  v_doubles_bias int;
  v_doubles_events int:=0;
  v_same_event_singles boolean:=false;
  v_unified_eligibility jsonb;
begin
  v_unified_eligibility:=public.player_event_eligibility(
    p_player_id,p_tournament_id,'doubles','direct'
  );
  if not coalesce((v_unified_eligibility->>'eligible')::boolean,false) then
    return false;
  end if;
  select * into p from public.players where id=p_player_id;
  select * into t from public.tournaments where id=p_tournament_id;
  if p.id is null or t.id is null then return false; end if;
  if coalesce(p.career_focus,'mixed')='singles_only' then return false; end if;

  if t.circuit='ITF' and coalesce(p.ranking,999999)<=200 then return false; end if;
  if t.circuit='ITF' and coalesce(p.doubles_ranking,999999)<=150 then return false; end if;
  if t.circuit='Challenger' and coalesce(p.ranking,999999)<=10 then return false; end if;
  if t.category='Challenger 50' and coalesce(p.ranking,999999)<=50 then return false; end if;
  if t.category='Challenger 75' and coalesce(p.ranking,999999)<=30 then return false; end if;

  if (public.player_tournament_calendar_conflict(p.id,t.id,'doubles')->>'conflict')::boolean then return false; end if;

  select * into sp
  from public.player_season_plans s
  where s.player_id=p.id and s.season=extract(year from t.start_date)::int;

  v_week:=date_trunc('week',coalesce(t.main_draw_start_date,t.start_date)::timestamp)::date;
  v_max_consecutive:=greatest(1,coalesce(sp.max_consecutive_weeks,case when p.age>=32 then 2 else 3 end));
  v_rest_trigger:=coalesce(sp.rest_trigger_fatigue,72);
  v_doubles_bias:=coalesce(sp.doubles_bias,
    case coalesce(p.career_focus,'mixed')
      when 'doubles_only' then 20
      when 'mixed' then 14
      when 'singles_priority' then 7
      else 10 end
  );

  for v_i in 1..5 loop
    if public.player_has_world_event_in_week(p.id,v_week-(v_i*7),null) then
      v_consecutive:=v_consecutive+1;
    else
      exit;
    end if;
  end loop;

  if v_consecutive>=v_max_consecutive
     and coalesce(t.category,'') not in ('Grand Chelem','Masters 1000','ATP Finals') then
    return false;
  end if;
  if coalesce(p.fatigue,20)>=v_rest_trigger+10
     and coalesce(t.category,'') not in ('Grand Chelem','Masters 1000','ATP Finals') then
    return false;
  end if;

  select count(distinct e.tournament_id)::int
  into v_doubles_events
  from public.world_doubles_tournament_entries e
  join public.world_doubles_partnerships wp on wp.id=e.pair_id
  join public.tournaments et on et.id=e.tournament_id
  where p.id in (wp.player_a_id,wp.player_b_id)
    and extract(year from et.start_date)=extract(year from t.start_date)
    and et.start_date<t.start_date;

  select exists(
    select 1 from public.world_tournament_entries e
    where e.tournament_id=t.id and e.player_id=p.id
  ) into v_same_event_singles;

  prob:=case
    when t.category='Grand Chelem' then 90
    when t.category='Masters 1000' then 84
    when t.category='ATP 500' then 76
    when t.category='ATP 250' then 74
    when t.circuit='Challenger' then 72
    when t.circuit='ITF' then 70
    when t.circuit='Junior' then 82
    else 68 end;

  prob:=prob+(v_doubles_bias-10)*2.1;

  prob:=prob+case coalesce(p.career_focus,'mixed')
    when 'doubles_only' then 18
    when 'mixed' then 5
    when 'singles_priority' then -10
    else 0 end;

  if coalesce(p.doubles_ranking,999999)<=50 then prob:=prob+10;
  elsif coalesce(p.doubles_ranking,999999)<=200 then prob:=prob+5;
  end if;

  if v_same_event_singles then prob:=prob+12; end if;

  if coalesce(sp.plan_type,'')='ncaa_pathway' then
    if extract(month from t.start_date) between 1 and 5 then
      prob:=prob-case
        when v_same_event_singles then 4
        when t.category='Grand Chelem' then 12
        when t.circuit='Challenger' then 30
        when t.circuit='ITF' then 22
        else 34 end;
    elsif extract(month from t.start_date) between 6 and 8 then
      prob:=prob+case
        when v_same_event_singles then 10
        when t.circuit='Challenger' then 8
        when t.circuit='ITF' then 12
        else 2 end;
    else
      prob:=prob-case
        when v_same_event_singles then 3
        when t.circuit='ITF' then 8
        when t.circuit='Challenger' then 14
        else 18 end;
    end if;
  end if;

  if v_doubles_events>=coalesce(sp.target_events,24)+3 then prob:=prob-22; end if;
  if coalesce(p.fatigue,20)>=v_rest_trigger then prob:=prob-20; end if;

  prob:=greatest(4,least(99,prob));
  roll:=(mod(abs(hashtext('ai-double-commit-v2|'||t.id::text||'|'||p.id::text)),10000)::numeric)/100.0;
  return roll<prob;
end;
$function$;

CREATE OR REPLACE FUNCTION public.junior_player_commits_to_event(p_player_id bigint, p_tournament_id bigint, p_discipline text DEFAULT 'singles'::text)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  p public.players%rowtype;
  t public.tournaments%rowtype;
  r int;
  prob numeric:=50;
  roll numeric;
  discipline text:=lower(coalesce(p_discipline,'singles'));
  age_on_start int;
  v_unified_eligibility jsonb;
begin
  v_unified_eligibility:=public.player_event_eligibility(
    p_player_id,p_tournament_id,
    case when lower(coalesce(p_discipline,'singles'))='doubles' then 'junior_doubles' else 'junior_singles' end,
    'direct'
  );
  if not coalesce((v_unified_eligibility->>'eligible')::boolean,false) then
    return false;
  end if;
  select * into p from public.players where id=p_player_id;
  select * into t from public.tournaments where id=p_tournament_id;
  if p.id is null or t.id is null or t.circuit<>'Junior' then return false; end if;

  if p.birth_date is not null then
    age_on_start:=extract(year from age(t.start_date,p.birth_date))::int;
  else
    age_on_start:=coalesce(p.age,99);
  end if;

  if age_on_start<13 or age_on_start>18 then return false; end if;
  if p.injury_status<>'Fit' or coalesce(p.fitness,90)<45 or coalesce(p.fatigue,20)>90 then return false; end if;

  r:=case
    when discipline='doubles' then coalesce(p.junior_doubles_ranking,p.junior_ranking,999999)
    else coalesce(p.junior_ranking,999999)
  end;

  prob:=case t.category
    when 'Junior Grand Slam' then
      case when r<=25 then 97 when r<=75 then 88 when r<=150 then 64 when r<=300 then 30 else 5 end
    when 'J500' then
      case when r<=20 then 94 when r<=75 then 86 when r<=175 then 58 when r<=400 then 22 else 4 end
    when 'J300' then
      case when r<=20 then 78 when r<=100 then 91 when r<=250 then 72 when r<=550 then 34 else 7 end
    when 'J200' then
      case when r<=20 then 26 when r<=100 then 68 when r<=300 then 88 when r<=650 then 52 else 14 end
    when 'J100' then
      case when r<=20 then 6 when r<=100 then 25 when r<=300 then 66 when r<=800 then 88 else 44 end
    when 'J60' then
      case when r<=20 then 1 when r<=100 then 7 when r<=300 then 28 when r<=800 then 78 else 82 end
    when 'J30' then
      case when r<=20 then .5 when r<=100 then 2 when r<=300 then 10 when r<=800 then 52 else 92 end
    else 55 end;

  if p.country is not null and t.country is not null and p.country=t.country then
    prob:=prob+12;
  end if;

  if age_on_start<=14 then
    prob:=prob+case
      when t.category in ('J30','J60','J100') then 10
      when t.category in ('J500','Junior Grand Slam') then -20
      else 0 end;
  elsif age_on_start>=17 and r<=150 then
    prob:=prob+case
      when t.category in ('J300','J500','Junior Grand Slam') then 7
      when t.category in ('J30','J60') then -8
      else 0 end;
  end if;

  if coalesce(p.ranking,999999)<=100 then
    prob:=prob-case
      when t.category='Junior Grand Slam' then 70
      when t.category='J500' then 85
      else 96 end;
  elsif coalesce(p.ranking,999999)<=250 then
    prob:=prob-case
      when t.category='Junior Grand Slam' then 45
      when t.category='J500' then 60
      when t.category='J300' then 72
      else 90 end;
  elsif coalesce(p.ranking,999999)<=500 then
    prob:=prob-case
      when t.category='Junior Grand Slam' then 20
      when t.category='J500' then 25
      when t.category='J300' then 35
      when t.category='J200' then 55
      else 75 end;
  end if;

  if discipline='doubles' then
    prob:=prob+case
      when coalesce(p.career_focus,'mixed')='singles_only' then -100
      when coalesce(p.career_focus,'mixed')='doubles_only' then 18
      when coalesce(p.career_focus,'mixed')='mixed' then 6
      else 0 end;
  end if;

  if coalesce(p.fatigue,20)>=72 then prob:=prob-18; end if;
  if coalesce(p.fatigue,20)>=84 then prob:=prob-22; end if;

  prob:=greatest(.2,least(99,prob));
  roll:=mod(abs(hashtext(
    'junior-commit-v1|'||t.id||'|'||p.id||'|'||discipline
  )),10000)/100.0;

  return roll<prob;
end;
$function$;

CREATE OR REPLACE FUNCTION public.ncaa_individual_player_available(p_player_id bigint, p_tournament_id bigint)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
begin
  if not coalesce((
    public.player_event_eligibility(
      p_player_id,p_tournament_id,'ncaa_singles','direct'
    )->>'eligible'
  )::boolean,false) then
    return false;
  end if;
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null then return false; end if;

  if not exists(
    select 1 from public.players p
    where p.id=p_player_id
      and p.ncaa_current=true
      and p.career_status='active'
      and p.injury_status='Fit'
      and coalesce(p.fitness,90)>=45
  ) then return false; end if;

  if exists(
    select 1
    from public.ncaa_individual_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where e.player_id=p_player_id
      and ot.id<>t.id
      and daterange(ot.start_date,coalesce(ot.end_date,ot.start_date),'[]')
          && daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
  ) then return false; end if;

  if exists(
    select 1
    from public.ncaa_individual_doubles_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where p_player_id in (e.player_a_id,e.player_b_id)
      and ot.id<>t.id
      and daterange(ot.start_date,coalesce(ot.end_date,ot.start_date),'[]')
          && daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
  ) then return false; end if;

  if exists(
    select 1
    from public.world_tournament_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where e.player_id=p_player_id
      and daterange(
            coalesce(ot.qualifying_start_date,ot.main_draw_start_date,ot.start_date),
            coalesce(ot.end_date,ot.start_date),'[]'
          ) && daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
  ) then return false; end if;

  if exists(
    select 1
    from public.world_tournament_qualifying_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where e.player_id=p_player_id
      and daterange(
            coalesce(ot.qualifying_start_date,ot.start_date),
            coalesce(ot.qualifying_end_date,ot.main_draw_start_date,ot.end_date,ot.start_date),'[]'
          ) && daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
  ) then return false; end if;

  if exists(
    select 1
    from public.world_doubles_tournament_entries e
    join public.world_doubles_partnerships wp on wp.id=e.pair_id
    join public.tournaments ot on ot.id=e.tournament_id
    where p_player_id in (wp.player_a_id,wp.player_b_id)
      and daterange(
            coalesce(ot.qualifying_start_date,ot.main_draw_start_date,ot.start_date),
            coalesce(ot.end_date,ot.start_date),'[]'
          ) && daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
  ) then return false; end if;

  if exists(
    select 1
    from public.davis_squad ds
    join public.davis_ties dt on ds.nation in (dt.home_nation,dt.away_nation)
    where ds.player_id=p_player_id
      and dt.status in ('scheduled','completed')
      and dt.tie_date between t.start_date and coalesce(t.end_date,t.start_date)
  ) then return false; end if;

  if public.player_in_ncaa_team_event(
    p_player_id,t.start_date,coalesce(t.end_date,t.start_date)
  ) then return false; end if;

  return true;
end;
$function$;

comment on function public.player_event_eligibility(bigint,bigint,text,text)
  is 'Court Boss unified player/event eligibility arbiter across ATP/Challenger/ITF, doubles, juniors and NCAA.';
comment on function public.run_unified_circuit_window(date,date)
  is 'Court Boss single weekly circuit orchestrator. Calls competition-specific adapters in deterministic priority order and finishes with integrity audit.';
comment on function public.audit_unified_circuit_integrity(date,date)
  is 'Audits calendar overlaps, play-down violations, career-focus violations, junior age, format coverage and prize profiles.';
