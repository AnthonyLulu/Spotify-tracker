-- Court Boss V19 · tournament entry rules and AI scheduling
-- Synced from live Supabase after ATP/ITF/NCAA/junior validation.
-- Official 2026 sources: ATP Rulebook Chapter 7 + ITF World Tennis Tour Regulations.

CREATE OR REPLACE FUNCTION public.pro_event_age_eligibility_v19(p_player_id bigint, p_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  p public.players%rowtype;
  t public.tournaments%rowtype;
  v_age int;
  v_limit int:=null;
  v_count int:=0;
begin
  select * into p from public.players where id=p_player_id;
  select * into t from public.tournaments where id=p_tournament_id;
  if p.id is null or t.id is null then
    return jsonb_build_object('eligible',false,'reason','missing_player_or_tournament');
  end if;

  v_age:=coalesce(
    case when p.birth_date is not null
      then extract(year from age(coalesce(t.qualifying_start_date,t.start_date),p.birth_date))::int end,
    p.age,99
  );

  if t.category='Grand Chelem' then
    if v_age<14 then
      return jsonb_build_object('eligible',false,'reason','grand_slam_under14','age',v_age);
    end if;
    return jsonb_build_object('eligible',true,'reason','age_ok','age',v_age);
  end if;

  if t.circuit in ('ATP','Challenger') then
    if v_age<14 then
      return jsonb_build_object('eligible',false,'reason','atp_under14','age',v_age);
    end if;
    if v_age=14 then v_limit:=8;
    elsif v_age=15 then v_limit:=12;
    end if;

    if v_limit is not null then
      select count(distinct z.tournament_id)::int
      into v_count
      from (
        select e.tournament_id
        from public.world_tournament_entries e
        join public.tournaments et on et.id=e.tournament_id
        where e.player_id=p.id
          and et.id<>t.id
          and et.circuit in ('ATP','Challenger')
          and extract(year from et.start_date)::int=extract(year from t.start_date)::int
        union
        select e.tournament_id
        from public.world_tournament_qualifying_entries e
        join public.tournaments et on et.id=e.tournament_id
        where e.player_id=p.id
          and et.id<>t.id
          and et.circuit in ('ATP','Challenger')
          and extract(year from et.start_date)::int=extract(year from t.start_date)::int
        union
        select e.tournament_id
        from public.world_tournament_acceptance_entries e
        join public.tournaments et on et.id=e.tournament_id
        where e.player_id=p.id
          and et.id<>t.id
          and et.circuit in ('ATP','Challenger')
          and extract(year from et.start_date)::int=extract(year from t.start_date)::int
          and e.status in ('accepted','promoted')
        union
        select e.tournament_id
        from public.entries e
        join public.tournaments et on et.id=e.tournament_id
        where e.player_id=p.id
          and et.id<>t.id
          and et.circuit in ('ATP','Challenger')
          and extract(year from et.start_date)::int=extract(year from t.start_date)::int
          and lower(coalesce(e.status,'entered')) not in ('withdrawn','cancelled','rejected')
      ) z;

      if v_count>=v_limit then
        return jsonb_build_object(
          'eligible',false,'reason','atp_age_event_cap',
          'age',v_age,'season_event_limit',v_limit,'events_already_committed',v_count
        );
      end if;
    end if;

    return jsonb_build_object(
      'eligible',true,'reason','age_ok','age',v_age,
      'season_event_limit',v_limit,'events_already_committed',v_count
    );
  end if;

  if t.circuit='ITF' and v_age<14 then
    return jsonb_build_object('eligible',false,'reason','itf_under14','age',v_age);
  end if;

  return jsonb_build_object('eligible',true,'reason','age_ok','age',v_age);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.tournament_entry_eligibility(p_player_id bigint, p_tournament_id bigint, p_entry_method text DEFAULT 'direct'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  p public.players%rowtype;
  t public.tournaments%rowtype;
  r integer;
  current_r integer;
  protected jsonb;
  ranking_date date;
  method text:=lower(coalesce(p_entry_method,'direct'));
  ok boolean:=true;
  reason text:='eligible';
  rank_source text:='current';
  age_rule jsonb;
begin
  select * into p from public.players where id=p_player_id;
  select * into t from public.tournaments where id=p_tournament_id;
  if p.id is null or t.id is null then
    return jsonb_build_object('eligible',false,'reason','missing_player_or_tournament');
  end if;

  age_rule:=public.pro_event_age_eligibility_v19(p.id,t.id);
  if not coalesce((age_rule->>'eligible')::boolean,false) then
    return age_rule || jsonb_build_object('entry_method',method,'circuit',t.circuit,'category',t.category);
  end if;

  ranking_date:=
    case
      when t.category='Grand Chelem'
        then coalesce(t.main_entry_deadline,t.start_date-42)
      when t.circuit='ATP' and t.category in ('ATP 250','ATP 500','Masters 1000')
        then coalesce(
          case when method in ('qualifying','qualifying_wildcard','protected_qualifying')
               then t.qualifying_entry_deadline else t.main_entry_deadline end,
          t.start_date-21
        )
      when t.circuit='Challenger' then coalesce(t.main_entry_deadline,t.start_date-21)
      when t.circuit='ITF' then date_trunc('week',t.start_date::timestamp)::date-21
      else t.start_date
    end;

  current_r:=public.player_rank_at_date(p.id,ranking_date);
  r:=current_r;

  if method in ('protected','protected_qualifying') then
    protected:=public.player_entry_protection_status(p.id,'singles',t.id);
    if not coalesce((protected->>'available')::boolean,false) then
      ok:=false;reason:='no_active_entry_protection';
    else
      r:=coalesce((protected->>'protected_rank')::int,current_r);
      rank_source:='protected';
    end if;
  end if;

  if ok and coalesce(p.career_status,'active')<>'active' then
    ok:=false; reason:='inactive_player';
  elsif ok and coalesce(p.career_focus,'mixed')='doubles_only' then
    ok:=false; reason:='doubles_only';

  elsif ok and t.category='Grand Chelem'
    and coalesce(r,999999)>500 then
    ok:=false; reason:='grand_slam_top500_entry_required';

  elsif ok and t.circuit='ATP'
    and t.category in ('ATP 250','ATP 500','Masters 1000')
    and method in ('direct','qualifying','protected','protected_qualifying')
    and coalesce(r,999999)>500 then
    ok:=false; reason:='atp_advanced_entry_top500_required';

  elsif ok and t.circuit='Challenger'
    and t.category in ('Challenger 175','Challenger 125')
    and method in ('direct','protected')
    and coalesce(r,999999)>500 then
    ok:=false; reason:='challenger_175_125_direct_top500_required';

  elsif ok and t.circuit='Challenger' and t.category='Challenger 50' then
    if r between 1 and 50 then
      ok:=false; reason:='ch50_top50_prohibited';
    elsif r between 51 and 150 then
      if method not in ('wildcard','candidate') then
        ok:=false; reason:='ch50_top150_no_direct_or_qualifying';
      elsif r between 51 and 100 and p.country is distinct from t.country then
        ok:=false; reason:='ch50_wc_51_100_home_nation_only';
      end if;
    end if;

  elsif ok and t.circuit='Challenger' and t.category in ('Challenger 75','Challenger 100','Challenger 125') then
    if r between 1 and 10 then
      ok:=false; reason:='challenger_top10_prohibited';
    elsif r between 11 and 50 then
      if t.category='Challenger 75' then
        ok:=false; reason:='ch75_11_50_prohibited';
      elsif method not in ('wildcard','qualifying_wildcard','candidate') then
        ok:=false; reason:='challenger_11_50_wildcard_only';
      end if;
    end if;
  end if;

  return jsonb_build_object(
    'eligible',ok,'reason',reason,'ranking',r,'current_ranking',current_r,
    'ranking_source',rank_source,'protected_ranking',protected,
    'ranking_date',ranking_date,'entry_method',method,'circuit',t.circuit,'category',t.category,
    'age_rule',age_rule,'arbiter','CB-ENTRY-RULES-v19'
  );
end;
$function$
;

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
  v_age_rule jsonb;
begin
  select * into p from public.players where id=p_player_id;
  select * into t from public.tournaments where id=p_tournament_id;

  if p.id is null or t.id is null then
    return jsonb_build_object('eligible',false,'reason','missing_player_or_tournament');
  end if;

  if coalesce(p.career_status,'active')<>'active' then
    return jsonb_build_object('eligible',false,'reason','inactive_player','discipline',v_discipline);
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
      return v_base || jsonb_build_object('discipline','singles','arbiter','CB-UNIFIED-ELIGIBILITY-v19');
    end if;

  elsif v_discipline in ('doubles','pro_doubles') then
    if coalesce(p.career_focus,'mixed')='singles_only' then
      return jsonb_build_object('eligible',false,'reason','singles_only','discipline','doubles');
    end if;
    if coalesce(t.circuit,'') not in ('ATP','Challenger','ITF') then
      return jsonb_build_object('eligible',false,'reason','wrong_circuit_for_pro_doubles','circuit',t.circuit);
    end if;

    v_age_rule:=public.pro_event_age_eligibility_v19(p.id,t.id);
    if not coalesce((v_age_rule->>'eligible')::boolean,false) then
      return v_age_rule || jsonb_build_object('discipline','doubles','arbiter','CB-UNIFIED-ELIGIBILITY-v19');
    end if;
    -- ATP Challenger 7.07 play-up restrictions apply to singles draws only.
    -- ITF 2026 M15/M25 doubles accepts teams by the applicable systems of merit;
    -- there is no blanket Top-200/Top-150 play-down ban.

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
      'calendar',v_conflict,'arbiter','CB-UNIFIED-ELIGIBILITY-v19'
    );
  end if;

  return coalesce(v_base,'{}'::jsonb) || jsonb_build_object(
    'eligible',true,'reason','eligible','discipline',v_discipline,
    'entry_method',v_method,'calendar',v_conflict,
    'arbiter','CB-UNIFIED-ELIGIBILITY-v19'
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.tournament_candidate_player_ids_v19(p_tournament_id bigint, p_entry_method text DEFAULT 'candidate'::text, p_limit integer DEFAULT 256)
 RETURNS TABLE(player_id bigint, effective_rank integer, merit_tier integer, merit_value numeric)
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  v_min int:=1;
  v_max int:=30000;
  v_prefilter int;
  v_tier_limit int;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null then return; end if;

  if t.category='Grand Chelem' then v_min:=1;v_max:=500;
  elsif t.category='Masters 1000' then v_min:=1;v_max:=500;
  elsif t.category='ATP 500' then v_min:=1;v_max:=500;
  elsif t.category='ATP 250' then v_min:=1;v_max:=500;
  elsif t.category='Challenger 175' then v_min:=1;v_max:=2200;
  elsif t.category='Challenger 125' then v_min:=11;v_max:=3200;
  elsif t.category='Challenger 100' then v_min:=11;v_max:=5000;
  elsif t.category='Challenger 75' then v_min:=51;v_max:=8000;
  elsif t.category='Challenger 50' then v_min:=51;v_max:=14000;
  end if;

  v_tier_limit:=greatest(64,least(coalesce(p_limit,256),650));

  if t.circuit='ITF' then
    return query
    with tier1 as (
      select
        p.id,p.current_ability,
        p.ranking::int effective_rank,
        1::int merit_tier,
        p.ranking::numeric merit_value
      from public.players p
      where p.career_status='active'
        and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
        and p.ranking is not null
        and coalesce(p.ranking_current,true)
      order by p.ranking,p.current_ability desc,p.id
      limit v_tier_limit
    ),
    tier2 as (
      select
        p.id,p.current_ability,
        null::int effective_rank,
        2::int merit_tier,
        p.itf_ranking::numeric merit_value
      from public.players p
      where p.career_status='active'
        and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
        and p.ranking is null
        and p.itf_ranking is not null
      order by p.itf_ranking,p.current_ability desc,p.id
      limit v_tier_limit
    ),
    tier3 as (
      select
        p.id,p.current_ability,
        null::int effective_rank,
        3::int merit_tier,
        greatest(1,1000-coalesce(p.current_ability,40)*10-coalesce(p.form,50)*0.5)::numeric merit_value
      from public.players p
      where p.career_status='active'
        and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
        and p.ranking is null
        and p.itf_ranking is null
      order by p.current_ability desc,p.form desc,p.id
      limit v_tier_limit
    ),
    pre as (
      select * from tier1
      union all select * from tier2
      union all select * from tier3
    ),
    checked as (
      select pre.*,elig.j
      from pre
      cross join lateral (
        select public.player_event_eligibility(pre.id,t.id,'singles',p_entry_method) j
      ) elig
    )
    select c.id,c.effective_rank,c.merit_tier,c.merit_value
    from checked c
    where coalesce((c.j->>'eligible')::boolean,false)
    order by c.merit_tier,c.merit_value,c.current_ability desc,c.id;
    return;
  end if;

  v_prefilter:=greatest(
    300,
    least(2500,greatest(coalesce(p_limit,256)*6,coalesce(p_limit,256)+240))
  );

  return query
  with pre as (
    select
      p.id,
      p.current_ability,
      coalesce(case when p.ranking_current then p.ranking end,p.game_world_rank,p.ranking,999999)::int approx_rank
    from public.players p
    where p.career_status='active'
      and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
      and coalesce(case when p.ranking_current then p.ranking end,p.game_world_rank,p.ranking,999999)
          between greatest(1,v_min-250) and v_max+750
    order by
      coalesce(case when p.ranking_current then p.ranking end,p.game_world_rank,p.ranking,999999),
      p.current_ability desc,p.id
    limit v_prefilter
  ),
  checked as (
    select pre.id,pre.current_ability,elig.j
    from pre
    cross join lateral (
      select public.player_event_eligibility(pre.id,t.id,'singles',p_entry_method) j
    ) elig
  )
  select
    c.id,
    coalesce((c.j->>'ranking')::int,999999)::int,
    1::int,
    coalesce((c.j->>'ranking')::numeric,999999::numeric)
  from checked c
  where coalesce((c.j->>'eligible')::boolean,false)
    and coalesce((c.j->>'ranking')::int,999999) between v_min and v_max
  order by 4,c.current_ability desc,c.id
  limit greatest(16,least(coalesce(p_limit,256),2000));
end;
$function$
;

CREATE OR REPLACE FUNCTION public.tournament_candidate_player_ids(p_tournament_id bigint, p_entry_method text DEFAULT 'candidate'::text, p_limit integer DEFAULT 256)
 RETURNS TABLE(player_id bigint, effective_rank integer)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select
    c.player_id,
    case
      when t.circuit='ITF' and c.merit_tier=2 then 100000+round(c.merit_value)::int
      when t.circuit='ITF' and c.merit_tier>=3 then 200000+round(c.merit_value)::int
      else c.effective_rank
    end as effective_rank
  from public.tournament_candidate_player_ids_v19(
    p_tournament_id,p_entry_method,p_limit
  ) c
  join public.tournaments t on t.id=p_tournament_id
  order by c.merit_tier,c.merit_value,c.player_id;
$function$
;

CREATE OR REPLACE FUNCTION public.ai_tournament_entry_decision_v19(p_player_id bigint, p_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  p public.players%rowtype;
  t public.tournaments%rowtype;
  sp public.player_season_plans%rowtype;
  elig jsonb;
  v_rank int:=999999;
  v_year int;
  v_prob numeric:=0;
  v_priority numeric:=0;
  v_roll numeric:=0;
  v_auto boolean:=false;
  v_reason text:='category_fit';
  v_played int:=0;
  v_target int:=22;
  v_rest_trigger int:=72;
  v_previous_country text;
  v_commitment_rank int:=999999;
  v_rule jsonb;
  v_cutoff int:=30;
  v_min500 int:=4;
  v_min_post int:=1;
  v_500_credits int:=0;
  v_post500 int:=0;
  v_remaining500 int:=0;
  v_remaining_post int:=0;
  v_uso_end date;
  v_current_swing int;
  v_swing_played int:=0;
  v_itf_rank int;
  v_raw boolean:=false;
  v_surface_match boolean:=false;
  v_ncaa_cadence int:=null;
  v_ncaa_week int:=null;
  v_ncaa_offset int:=null;
  v_event_affinity numeric:=0;
begin
  select * into p from public.players where id=p_player_id;
  select * into t from public.tournaments where id=p_tournament_id;
  if p.id is null or t.id is null or not coalesce(t.is_active,true) then
    return jsonb_build_object('eligible',false,'raw_interest',false,'reason','missing_or_inactive');
  end if;

  elig:=public.player_event_eligibility(p.id,t.id,'singles','candidate');
  if not coalesce((elig->>'eligible')::boolean,false) then
    return elig || jsonb_build_object(
      'raw_interest',false,'probability',0,'priority_score',0,
      'auto_entry',false,'model','CB-AI-ENTRY-v19'
    );
  end if;

  v_rank:=coalesce(
    (elig->>'ranking')::int,
    case when p.ranking_current then p.ranking end,
    p.ranking,
    p.game_world_rank,
    999999
  );
  v_itf_rank:=p.itf_ranking;
  v_year:=extract(year from t.start_date)::int;

  select * into sp
  from public.player_season_plans s
  where s.player_id=p.id and s.season=v_year;

  v_target:=coalesce(sp.target_events,
    case when v_rank<=100 then 20 when v_rank<=300 then 23 when v_rank<=900 then 27 else 30 end);
  v_rest_trigger:=coalesce(sp.rest_trigger_fatigue,72);

  select count(distinct z.tournament_id)::int
  into v_played
  from (
    select e.tournament_id
    from public.world_tournament_entries e
    join public.tournaments et on et.id=e.tournament_id
    where e.player_id=p.id and extract(year from et.start_date)::int=v_year and et.start_date<t.start_date
    union
    select e.tournament_id
    from public.world_tournament_qualifying_entries e
    join public.tournaments et on et.id=e.tournament_id
    where e.player_id=p.id and extract(year from et.start_date)::int=v_year and et.start_date<t.start_date
  ) z;

  v_surface_match:=case
    when lower(coalesce(sp.preferred_surface,'')) like '%terre%'
      then lower(coalesce(t.surface,'')) like '%terre%'
    when lower(coalesce(sp.preferred_surface,'')) like '%clay%'
      then lower(coalesce(t.surface,'')) like '%terre%' or lower(coalesce(t.surface,'')) like '%clay%'
    when lower(coalesce(sp.preferred_surface,'')) like '%gazon%'
      then lower(coalesce(t.surface,'')) like '%gazon%'
    when lower(coalesce(sp.preferred_surface,'')) like '%grass%'
      then lower(coalesce(t.surface,'')) like '%gazon%' or lower(coalesce(t.surface,'')) like '%grass%'
    when lower(coalesce(sp.preferred_surface,'')) like '%dur%'
      then lower(coalesce(t.surface,'')) like '%dur%'
    when lower(coalesce(sp.preferred_surface,'')) like '%hard%'
      then lower(coalesce(t.surface,'')) like '%dur%' or lower(coalesce(t.surface,'')) like '%hard%'
    else false
  end;

  if t.category='Grand Chelem' then
    v_prob:=case when v_rank<=128 then 99.8 when v_rank<=250 then 99 when v_rank<=500 then 96 else 0 end;
    v_priority:=1000;
    v_reason:='grand_slam_priority';

  elsif t.category='Masters 1000' then
    -- ATP automatically enters players whose ranking puts them on the direct/alternate list.
    v_prob:=99.9;
    v_priority:=900;
    v_auto:=true;
    v_reason:='masters_automatic_entry';

  elsif t.category='ATP 500' then
    v_prob:=case
      when v_rank<=10 then 12
      when v_rank<=30 then 27
      when v_rank<=75 then 52
      when v_rank<=150 then 65
      when v_rank<=300 then 54
      else 34 end;
    v_priority:=700;

    if v_year>=2026 then
      v_rule:=public.atp_commitment_rule_v18(v_year);
      v_cutoff:=coalesce((v_rule->>'commitment_rank_cutoff')::int,30);
      v_min500:=coalesce((v_rule->>'minimum_500_credits')::int,4);
      v_min_post:=coalesce((v_rule->>'minimum_post_us_open_500')::int,1);
      v_commitment_rank:=coalesce(
        public.player_rank_at_date(p.id,make_date(v_year-1,11,10)),
        v_rank
      );

      if v_commitment_rank between 1 and v_cutoff then
        select max(coalesce(et.end_date,et.start_date))::date
        into v_uso_end
        from public.tournaments et
        where extract(year from et.start_date)::int=v_year
          and et.category='Grand Chelem'
          and et.name ilike '%US Open%'
          and coalesce(et.is_active,true);

        select count(distinct x.tournament_id)::int
        into v_500_credits
        from (
          select e.tournament_id
          from public.world_tournament_entries e
          join public.tournaments et on et.id=e.tournament_id
          where e.player_id=p.id and et.category='ATP 500'
            and extract(year from et.start_date)::int=v_year and et.start_date<t.start_date
          union
          select e.tournament_id
          from public.world_tournament_acceptance_entries e
          join public.tournaments et on et.id=e.tournament_id
          where e.player_id=p.id and e.status in ('accepted','promoted')
            and et.category='ATP 500'
            and extract(year from et.start_date)::int=v_year and et.start_date<t.start_date
          union
          select e.tournament_id
          from public.entries e
          join public.tournaments et on et.id=e.tournament_id
          where e.player_id=p.id and lower(coalesce(e.status,'entered')) not in ('withdrawn','cancelled','rejected')
            and et.category='ATP 500'
            and extract(year from et.start_date)::int=v_year and et.start_date<t.start_date
        ) x;

        if coalesce((v_rule->>'monte_carlo_counts_for_commitment')::boolean,true)
          and exists(
            select 1
            from public.world_tournament_entries e
            join public.tournaments et on et.id=e.tournament_id
            where e.player_id=p.id
              and et.category='Masters 1000'
              and et.name ilike '%Monte-Carlo%'
              and extract(year from et.start_date)::int=v_year
              and et.start_date<t.start_date
          ) then
          v_500_credits:=v_500_credits+1;
        end if;

        select count(distinct e.tournament_id)::int
        into v_post500
        from public.world_tournament_entries e
        join public.tournaments et on et.id=e.tournament_id
        where e.player_id=p.id and et.category='ATP 500'
          and extract(year from et.start_date)::int=v_year
          and v_uso_end is not null and et.start_date>v_uso_end and et.start_date<t.start_date;

        select count(*)::int into v_remaining500
        from public.tournaments et
        where et.category='ATP 500' and et.circuit='ATP'
          and extract(year from et.start_date)::int=v_year
          and et.start_date>=t.start_date and coalesce(et.is_active,true);

        select count(*)::int into v_remaining_post
        from public.tournaments et
        where et.category='ATP 500' and et.circuit='ATP'
          and extract(year from et.start_date)::int=v_year
          and v_uso_end is not null and et.start_date>v_uso_end
          and et.start_date>=t.start_date and coalesce(et.is_active,true);

        if v_500_credits<v_min500 then
          v_prob:=v_prob+least(30,(v_min500-v_500_credits)*7);
          v_priority:=v_priority+40;
          v_reason:='commitment_500_need';
        end if;

        if v_remaining500<=greatest(1,v_min500-v_500_credits+2) and v_500_credits<v_min500 then
          v_prob:=greatest(v_prob,86);
          v_priority:=v_priority+65;
          v_reason:='commitment_500_late_rescue';
        end if;

        if v_uso_end is not null and t.start_date>v_uso_end and v_post500<v_min_post then
          v_prob:=greatest(v_prob,72);
          v_priority:=v_priority+55;
          v_reason:='post_us_open_500_need';
        end if;

        if v_remaining_post<=greatest(1,v_min_post-v_post500)
           and v_post500<v_min_post
           and v_uso_end is not null and t.start_date>v_uso_end then
          v_prob:=greatest(v_prob,97);
          v_priority:=v_priority+90;
          v_reason:='post_us_open_500_final_chance';
        end if;

        -- Three-swing ATP 500 bonus is an incentive, not a mandatory scheduling rule.
        v_current_swing:=public.atp500_bonus_swing_v18(t.start_date,v_uso_end);
        select count(distinct e.tournament_id)::int
        into v_swing_played
        from public.world_tournament_entries e
        join public.tournaments et on et.id=e.tournament_id
        where e.player_id=p.id and et.category='ATP 500'
          and extract(year from et.start_date)::int=v_year
          and et.start_date<t.start_date
          and public.atp500_bonus_swing_v18(et.start_date,v_uso_end)=v_current_swing;
        if v_swing_played=0 then
          v_prob:=v_prob+6;
          v_priority:=v_priority+12;
        end if;
      end if;
    end if;

  elsif t.category='ATP 250' then
    v_prob:=case
      when v_rank<=10 then 7
      when v_rank<=30 then 26
      when v_rank<=75 then 58
      when v_rank<=150 then 74
      when v_rank<=300 then 68
      else 48 end;
    v_priority:=600;
    v_reason:='atp250_schedule_fit';

  elsif t.category='Challenger 175' then
    v_prob:=case when v_rank<=20 then 22 when v_rank<=50 then 48 when v_rank<=100 then 72
                 when v_rank<=175 then 78 when v_rank<=300 then 52 else 28 end;
    v_priority:=520;
    v_reason:='challenger175_fit';

  elsif t.category='Challenger 125' then
    v_prob:=case when v_rank<=50 then 20 when v_rank<=150 then 80 when v_rank<=300 then 76
                 when v_rank<=500 then 55 else 36 end;
    v_priority:=485;
    v_reason:='challenger125_fit';

  elsif t.category='Challenger 100' then
    v_prob:=case when v_rank<=50 then 18 when v_rank<=150 then 82 when v_rank<=300 then 76
                 when v_rank<=500 then 58 else 40 end;
    v_priority:=455;
    v_reason:='challenger100_fit';

  elsif t.category='Challenger 75' then
    v_prob:=case when v_rank<=150 then 72 when v_rank<=350 then 84 when v_rank<=700 then 64 else 43 end;
    v_priority:=425;
    v_reason:='challenger75_fit';

  elsif t.category='Challenger 50' then
    v_prob:=case when v_rank<=150 then 26 when v_rank<=400 then 84 when v_rank<=800 then 76 else 56 end;
    v_priority:=395;
    v_reason:='challenger50_fit';

  elsif t.category='M25' then
    v_prob:=case
      when p.ranking is not null and p.ranking<=100 then 1.5
      when p.ranking is not null and p.ranking<=200 then 7
      when p.ranking is not null and p.ranking<=350 then 32
      when p.ranking is not null and p.ranking<=650 then 72
      when p.ranking is not null and p.ranking<=1200 then 85
      when v_itf_rank is not null then 90
      else 78 end;
    v_priority:=case
      when p.ranking is not null and p.ranking<=650 then 320
      when p.ranking is not null and p.ranking<=1200 then 310
      when p.ranking is not null then 295
      when v_itf_rank is not null and v_itf_rank<=500 then 305
      when v_itf_rank is not null then 285
      else 260 end;
    v_reason:='m25_development_fit';

  elsif t.category='M15' then
    v_prob:=case
      when p.ranking is not null and p.ranking<=100 then .3
      when p.ranking is not null and p.ranking<=200 then 2.5
      when p.ranking is not null and p.ranking<=350 then 15
      when p.ranking is not null and p.ranking<=650 then 55
      when p.ranking is not null and p.ranking<=1200 then 82
      when v_itf_rank is not null then 92
      else 84 end;
    v_priority:=case
      when p.ranking is not null and p.ranking<=350 then 250
      when p.ranking is not null and p.ranking<=650 then 275
      when p.ranking is not null and p.ranking<=1200 then 300
      when p.ranking is not null then 315
      when v_itf_rank is not null and v_itf_rank<=500 then 285
      when v_itf_rank is not null then 315
      else 325 end;
    v_reason:='m15_development_fit';

  else
    v_prob:=45;
    v_priority:=350;
  end if;

  if p.country is not null and t.country is not null and p.country=t.country then
    v_prob:=v_prob+12;
    v_priority:=v_priority+28;
  end if;

  if v_surface_match then
    v_prob:=v_prob+7;
    v_priority:=v_priority+14;
  end if;

  select x.country into v_previous_country
  from (
    select et.country,coalesce(et.end_date,et.start_date) event_date
    from public.world_tournament_entries e
    join public.tournaments et on et.id=e.tournament_id
    where e.player_id=p.id and et.start_date<t.start_date
    union all
    select et.country,coalesce(et.end_date,et.start_date)
    from public.world_tournament_qualifying_entries e
    join public.tournaments et on et.id=e.tournament_id
    where e.player_id=p.id and et.start_date<t.start_date
  ) x
  order by x.event_date desc
  limit 1;

  if v_previous_country is not null and t.country is not null and v_previous_country<>t.country then
    v_prob:=v_prob-greatest(2,12-coalesce(sp.travel_tolerance,10)*.45);
    v_priority:=v_priority-greatest(2,8-coalesce(sp.travel_tolerance,10)*.3);
  end if;

  -- Fatigue is a scheduling preference, not an entry-rule prohibition.
  -- Mandatory/near-mandatory prestige events stay entered and can be withdrawn later
  -- if the medical state still overlaps the event.
  if not v_auto and t.category<>'Grand Chelem' then
    if coalesce(p.fatigue,20)>=v_rest_trigger then
      v_prob:=v_prob-10;
      v_priority:=v_priority-12;
    end if;
    if coalesce(p.fatigue,20)>=85 then
      v_prob:=v_prob-8;
      v_priority:=v_priority-10;
    end if;
  end if;

  if v_played>=v_target then
    v_prob:=v_prob-case when t.category in ('Grand Chelem','Masters 1000') then 0 else 20 end;
    v_priority:=v_priority-case when t.category in ('Grand Chelem','Masters 1000') then 0 else 22 end;
  end if;
  if v_played>=v_target+4 and t.category not in ('Grand Chelem','Masters 1000') then
    v_prob:=least(v_prob,18);
  end if;

  if coalesce(p.age,25)>=32 and t.category in ('ATP 250','Challenger 175','Challenger 125','Challenger 100','Challenger 75','Challenger 50','M25','M15') then
    v_prob:=v_prob-8;
    v_priority:=v_priority-10;
  end if;

  -- Stable personal affinity spreads players across parallel events of the same level.
  -- Category, home nation and surface remain more important than this tie-breaker.
  v_event_affinity:=(mod(abs(hashtext('event-affinity-v19|'||p.id::text||'|'||t.id::text)),2000)::numeric)/100.0;
  v_priority:=v_priority+v_event_affinity;
  v_prob:=v_prob+least(5,v_event_affinity*.25);

  -- NCAA players protect the college season. The calendar-conflict arbiter remains
  -- authoritative for actual duals/team events; this modifier handles the weeks between them.
  if coalesce(p.ncaa_current,false) or coalesce(sp.plan_type,'')='ncaa_pathway' then
    if extract(month from t.start_date) between 1 and 5 then
      v_prob:=v_prob-case
        when t.circuit='ITF' then 28
        when t.circuit='Challenger' then 45
        else 65 end;
      v_priority:=v_priority-case
        when t.circuit='ITF' then 25
        when t.circuit='Challenger' then 45
        else 70 end;

      -- Protect the actual NCAA spring season. A college player can still use
      -- selected pro windows, but not silently build a full parallel tour.
      if t.category not in ('Grand Chelem','Masters 1000') then
        v_ncaa_cadence:=case when v_rank<=250 then 3 else 4 end;
        v_ncaa_week:=floor((t.start_date-make_date(v_year,1,1))::numeric/7)::int;
        v_ncaa_offset:=mod(abs(hashtext('ncaa-pro-window-v19|'||p.id::text||'|'||v_year::text)),v_ncaa_cadence);
        if mod(v_ncaa_week,v_ncaa_cadence)<>v_ncaa_offset then
          v_prob:=least(v_prob,.2);
          v_priority:=greatest(0,v_priority-120);
        end if;
      end if;
    elsif extract(month from t.start_date) between 6 and 8 then
      v_prob:=v_prob+case when t.circuit='ITF' then 10 when t.circuit='Challenger' then 5 else 0 end;
    else
      v_prob:=v_prob-case when t.circuit='ITF' then 8 else 20 end;
    end if;
  end if;

  -- Legal does not mean sensible. Elite players may enter ITF events, but the
  -- autonomous AI treats that as an exceptional scheduling choice.
  if t.category='M15' and p.ranking is not null then
    if p.ranking<=100 then v_prob:=least(v_prob,1);
    elsif p.ranking<=200 then v_prob:=least(v_prob,4);
    elsif p.ranking<=350 then v_prob:=least(v_prob,20);
    end if;
  elsif t.category='M25' and p.ranking is not null then
    if p.ranking<=100 then v_prob:=least(v_prob,3);
    elsif p.ranking<=200 then v_prob:=least(v_prob,12);
    end if;
  end if;

  v_prob:=greatest(.2,least(99.9,v_prob));
  v_priority:=greatest(0,v_priority);
  v_roll:=(mod(abs(hashtext('ai-entry-v19|'||t.id::text||'|'||p.id::text)),10000)::numeric)/100.0;
  v_raw:=v_auto or v_roll<v_prob;

  return jsonb_build_object(
    'eligible',true,
    'raw_interest',v_raw,
    'auto_entry',v_auto,
    'probability',round(v_prob,2),
    'roll',round(v_roll,2),
    'priority_score',round(v_priority,2),
    'reason',v_reason,
    'rank',v_rank,
    'season_events_before',v_played,
    'target_events',v_target,
    'model','CB-AI-ENTRY-v19'
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.ai_player_commits_to_tournament(p_player_id bigint, p_tournament_id bigint)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  d jsonb;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null or not coalesce(t.is_active,true) then return false; end if;

  d:=public.ai_tournament_entry_decision_v19(p_player_id,p_tournament_id);
  if not coalesce((d->>'eligible')::boolean,false)
     or not coalesce((d->>'raw_interest')::boolean,false) then
    return false;
  end if;

  -- Existing played/committed events are hard conflicts. Parallel entry
  -- applications are allowed to reach their acceptance lists; the acceptance
  -- reconciler later keeps exactly one accepted event per player/week.
  if (public.player_tournament_calendar_conflict(
        p_player_id,p_tournament_id,'candidate'
      )->>'conflict')::boolean then
    return false;
  end if;

  return true;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.junior_event_decision_v19(p_player_id bigint, p_tournament_id bigint, p_discipline text DEFAULT 'singles'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  p public.players%rowtype;
  t public.tournaments%rowtype;
  discipline text:=lower(coalesce(p_discipline,'singles'));
  elig jsonb;
  r int;
  v_age int;
  v_prob numeric:=50;
  v_priority numeric:=0;
  v_roll numeric;
  v_raw boolean;
begin
  select * into p from public.players where id=p_player_id;
  select * into t from public.tournaments where id=p_tournament_id;
  if p.id is null or t.id is null or t.circuit<>'Junior' or not coalesce(t.is_active,true) then
    return jsonb_build_object('eligible',false,'raw_interest',false,'reason','missing_or_not_junior');
  end if;

  elig:=public.player_event_eligibility(
    p.id,t.id,
    case when discipline='doubles' then 'junior_doubles' else 'junior_singles' end,
    'direct'
  );
  if not coalesce((elig->>'eligible')::boolean,false) then
    return elig || jsonb_build_object('raw_interest',false,'probability',0,'priority_score',0,'model','CB-JUNIOR-ENTRY-v19');
  end if;

  v_age:=coalesce(
    case when p.birth_date is not null then extract(year from age(t.start_date,p.birth_date))::int end,
    p.age,99
  );
  r:=case when discipline='doubles'
    then coalesce(p.junior_doubles_ranking,p.junior_ranking,999999)
    else coalesce(p.junior_ranking,999999) end;

  v_prob:=case t.category
    when 'Junior Grand Slam' then case when r<=25 then 98 when r<=75 then 92 when r<=150 then 72 when r<=300 then 38 else 8 end
    when 'J500' then case when r<=20 then 96 when r<=75 then 89 when r<=175 then 64 when r<=400 then 30 else 6 end
    when 'J300' then case when r<=20 then 78 when r<=100 then 92 when r<=250 then 76 when r<=550 then 40 else 9 end
    when 'J200' then case when r<=20 then 25 when r<=100 then 68 when r<=300 then 90 when r<=650 then 58 else 16 end
    when 'J100' then case when r<=20 then 5 when r<=100 then 24 when r<=300 then 68 when r<=800 then 90 else 48 end
    when 'J60' then case when r<=20 then 1 when r<=100 then 6 when r<=300 then 30 when r<=800 then 80 else 86 end
    when 'J30' then case when r<=20 then .3 when r<=100 then 2 when r<=300 then 10 when r<=800 then 54 else 94 end
    else 50 end;

  v_priority:=case t.category
    when 'Junior Grand Slam' then 900
    when 'J500' then 800
    when 'J300' then 700
    when 'J200' then 600
    when 'J100' then 500
    when 'J60' then 400
    when 'J30' then 300
    else 350 end;

  if p.country is not null and t.country is not null and p.country=t.country then
    v_prob:=v_prob+12;
    v_priority:=v_priority+30;
  end if;

  if v_age<=14 then
    v_prob:=v_prob+case
      when t.category in ('J30','J60','J100') then 10
      when t.category in ('J500','Junior Grand Slam') then -20
      else 0 end;
  elsif v_age>=17 and r<=150 then
    v_prob:=v_prob+case
      when t.category in ('J300','J500','Junior Grand Slam') then 8
      when t.category in ('J30','J60') then -10
      else 0 end;
  end if;

  -- Strong pro juniors naturally graduate out of low-grade junior events.
  if coalesce(p.ranking,999999)<=100 then
    v_prob:=v_prob-case
      when t.category='Junior Grand Slam' then 68
      when t.category='J500' then 84
      else 97 end;
  elsif coalesce(p.ranking,999999)<=250 then
    v_prob:=v_prob-case
      when t.category='Junior Grand Slam' then 42
      when t.category='J500' then 58
      when t.category='J300' then 70
      else 90 end;
  elsif coalesce(p.ranking,999999)<=500 then
    v_prob:=v_prob-case
      when t.category='Junior Grand Slam' then 18
      when t.category='J500' then 24
      when t.category='J300' then 34
      when t.category='J200' then 54
      else 74 end;
  end if;

  if discipline='doubles' then
    v_prob:=v_prob+case
      when coalesce(p.career_focus,'mixed')='singles_only' then -100
      when coalesce(p.career_focus,'mixed')='doubles_only' then 18
      when coalesce(p.career_focus,'mixed')='mixed' then 6
      else 0 end;
  end if;

  -- Fatigue affects preference, not junior eligibility.
  if coalesce(p.fatigue,20)>=72 then v_prob:=v_prob-10; end if;
  if coalesce(p.fatigue,20)>=84 then v_prob:=v_prob-10; end if;

  v_prob:=greatest(.2,least(99,v_prob));
  v_roll:=mod(abs(hashtext('junior-entry-v19|'||t.id||'|'||p.id||'|'||discipline)),10000)/100.0;
  v_raw:=v_roll<v_prob;

  return jsonb_build_object(
    'eligible',true,'raw_interest',v_raw,'probability',round(v_prob,2),
    'roll',round(v_roll,2),'priority_score',v_priority,
    'junior_rank',r,'age',v_age,'model','CB-JUNIOR-ENTRY-v19'
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.junior_player_commits_to_event(p_player_id bigint, p_tournament_id bigint, p_discipline text DEFAULT 'singles'::text)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  d jsonb;
  discipline text:=lower(coalesce(p_discipline,'singles'));
  v_priority numeric;
  v_week date;
  v_better boolean:=false;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null or t.circuit<>'Junior' or not coalesce(t.is_active,true) then return false; end if;

  d:=public.junior_event_decision_v19(p_player_id,p_tournament_id,discipline);
  if not coalesce((d->>'eligible')::boolean,false)
     or not coalesce((d->>'raw_interest')::boolean,false) then return false; end if;

  v_priority:=coalesce((d->>'priority_score')::numeric,0);
  v_week:=date_trunc('week',coalesce(t.main_draw_start_date,t.start_date)::timestamp)::date;

  -- ITF juniors may submit multiple entries, but after withdrawal deadlines they
  -- can remain accepted in only one event for the week. Reservations represent
  -- that final accepted choice.
  select exists(
    select 1
    from (
      select x.id
      from public.tournaments x
      where x.id<>t.id
        and x.circuit='Junior'
        and coalesce(x.is_active,true)
        and coalesce(x.main_draw_start_date,x.start_date) between v_week and v_week+6
    ) ot
    cross join lateral (
      select public.junior_event_decision_v19(p_player_id,ot.id,discipline) j
    ) od
    where true
      and coalesce((od.j->>'eligible')::boolean,false)
      and coalesce((od.j->>'raw_interest')::boolean,false)
      and (
        coalesce((od.j->>'priority_score')::numeric,0)>v_priority
        or (
          coalesce((od.j->>'priority_score')::numeric,0)=v_priority
          and ot.id<t.id
        )
      )
  ) into v_better;

  return not v_better;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.tournament_entry_rules_audit_v19(p_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  v_year int:=extract(year from p_date)::int;
  v_rule_year int;
  v_itf_only int:=0;
  v_junior_conflicts int:=0;
  v_world_conflicts int:=0;
  v_retired_future int:=0;
  v_commitment_players int:=0;
  v_masters_auto_ok boolean:=true;
  v_next_masters bigint;
  v_sample_player bigint;
  v_decision jsonb;
begin
  v_rule_year:=case when v_year<2026 then 2026 else v_year end;

  select count(*)::int into v_itf_only
  from public.players p
  where p.career_status='active'
    and p.ranking is null
    and p.itf_ranking is not null
    and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %';

  select count(*)::int into v_junior_conflicts
  from (
    select r.player_id,date_trunc('week',t.start_date::timestamp),count(distinct r.tournament_id)
    from public.junior_entry_reservations r
    join public.tournaments t on t.id=r.tournament_id
    where t.start_date>=p_date
    group by r.player_id,date_trunc('week',t.start_date::timestamp)
    having count(distinct r.tournament_id)>1
  ) x;

  select
    coalesce((g->>'future_same_week_world_entry_conflicts')::int,0),
    coalesce((g->>'retired_future_entries')::int,0)
  into v_world_conflicts,v_retired_future
  from (select public.world_integrity_guard_v18(p_date) g) s;

  if v_rule_year=2026 then
    select count(*)::int into v_commitment_players
    from public.atp_commitment_players_v18(2026);
  end if;

  select t.id into v_next_masters
  from public.tournaments t
  where t.circuit='ATP' and t.category='Masters 1000'
    and extract(year from t.start_date)::int=v_rule_year
    and coalesce(t.is_active,true)
  order by t.start_date,t.id
  limit 1;

  select p.id into v_sample_player
  from public.players p
  where p.career_status='active'
    and p.ranking_current=true
    and p.ranking between 1 and 100
    and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
  order by p.ranking,p.id
  limit 1;

  if v_next_masters is not null and v_sample_player is not null then
    v_decision:=public.ai_tournament_entry_decision_v19(v_sample_player,v_next_masters);
    v_masters_auto_ok:=coalesce((v_decision->>'auto_entry')::boolean,false);
  end if;

  return jsonb_build_object(
    'ok',
      v_junior_conflicts=0
      and v_world_conflicts=0
      and v_retired_future=0
      and v_masters_auto_ok
      and (v_rule_year<>2026 or v_commitment_players=30),
    'date',p_date,
    'rule_year',v_rule_year,
    'itf_only_player_pool',v_itf_only,
    'junior_multi_accept_weeks',v_junior_conflicts,
    'world_same_week_conflicts',v_world_conflicts,
    'retired_future_entries',v_retired_future,
    'commitment_players_2026',case when v_rule_year=2026 then v_commitment_players else null end,
    'masters_auto_entry_sample_ok',v_masters_auto_ok,
    'models',jsonb_build_object(
      'eligibility','CB-ENTRY-RULES-v19',
      'pro_ai','CB-AI-ENTRY-v19',
      'junior_ai','CB-JUNIOR-ENTRY-v19'
    ),
    'model','CB-ENTRY-AUDIT-v19'
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.world_25y_validation_v19(p_start_year integer DEFAULT 2025, p_end_year integer DEFAULT 2050)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  v_stress jsonb;
  v_calendar jsonb;
  v_guard jsonb;
  v_entries jsonb;
  v_calendar_duplicate_groups int:=0;
  v_ok boolean;
  v_audit_date date;
begin
  if p_end_year<=p_start_year or p_end_year-p_start_year>80 then
    return jsonb_build_object('ok',false,'reason','invalid_horizon');
  end if;

  v_audit_date:=case when p_start_year=2025 then date '2025-12-01' else make_date(p_start_year,1,1) end;
  v_stress:=public.living_world_stress_test_v16(greatest(2026,p_start_year+1),p_end_year,250,2000);
  v_calendar:=public.living_world_horizon_test_v14(p_start_year,p_end_year);
  v_guard:=public.world_integrity_guard_v18(v_audit_date);
  v_entries:=public.tournament_entry_rules_audit_v19(v_audit_date);

  select count(*)::int into v_calendar_duplicate_groups
  from (
    select t.circuit,t.category,t.start_date,t.country,lower(t.name),count(*)
    from public.tournaments t
    where extract(year from t.start_date)::int between p_start_year and p_end_year
      and coalesce(t.is_active,true)
    group by 1,2,3,4,5
    having count(*)>1
  ) x;

  v_ok:=coalesce((v_stress->>'ok')::boolean,false)
        and coalesce((v_calendar->>'ok')::boolean,false)
        and coalesce((v_guard->>'ok')::boolean,false)
        and coalesce((v_entries->>'ok')::boolean,false)
        and v_calendar_duplicate_groups=0;

  return jsonb_build_object(
    'ok',v_ok,
    'start_year',p_start_year,
    'end_year',p_end_year,
    'seasons',p_end_year-p_start_year+1,
    'supply_and_retirement_stress',v_stress,
    'calendar_horizon',v_calendar,
    'calendar_duplicate_groups',v_calendar_duplicate_groups,
    'current_world_guard',v_guard,
    'entry_rules',v_entries,
    'model','CB-WORLD-25Y-VALIDATION-v19'
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.career_long_term_health_v19(p_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select jsonb_build_object(
    'ok',
      coalesce((public.world_integrity_guard_v18(p_date)->>'ok')::boolean,false)
      and coalesce((public.tournament_entry_rules_audit_v19(p_date)->>'ok')::boolean,false)
      and coalesce((public.world_25y_validation_v19(
        extract(year from p_date)::int,
        extract(year from p_date)::int+25
      )->>'ok')::boolean,false),
    'date',p_date,
    'world_guard',public.world_integrity_guard_v18(p_date),
    'entry_rules',public.tournament_entry_rules_audit_v19(p_date),
    'horizon_25y',public.world_25y_validation_v19(
      extract(year from p_date)::int,
      extract(year from p_date)::int+25
    ),
    'economy',public.career_operating_cost_profile_v15(p_date),
    'hall_of_fame_total',(select count(*) from public.hall_of_fame_candidates),
    'active_staff_profiles',(select count(*) from public.staff_profiles where active=true),
    'active_players',(select count(*) from public.players where career_status='active'),
    'model','CB-CAREER-LONG-HORIZON-v19'
  );
$function$
;

CREATE OR REPLACE FUNCTION public.career_long_term_health_v15(p_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select public.career_long_term_health_v19(p_date);
$function$
;

CREATE OR REPLACE FUNCTION public.career_system_health(p_date date)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select jsonb_build_object(
    'ok',
      exists(select 1 from public.career_state where id='demo')
      and exists(
        select 1 from public.players p
        join public.career_state c on c.managed_player_id=p.id
        where c.id='demo'
      )
      and coalesce((public.world_integrity_guard_v18(p_date)->>'ok')::boolean,false)
      and coalesce((public.tournament_entry_rules_audit_v19(p_date)->>'ok')::boolean,false),
    'date',p_date,
    'career_exists',exists(select 1 from public.career_state where id='demo'),
    'managed_player_exists',exists(
      select 1 from public.players p
      join public.career_state c on c.managed_player_id=p.id
      where c.id='demo'
    ),
    'academy_exists',exists(select 1 from public.academies where id='demo'),
    'academy_active_players',(select count(*) from public.academy_roster where status='active'),
    'academy_prospects',(select count(*) from public.academy_youth where status='prospect'),
    'unread_inbox',(select count(*) from public.inbox_items where not is_read),
    'active_injuries',(select count(*) from public.injuries where lower(coalesce(status,''))='active'),
    'active_scouting',(select count(*) from public.scouting_assignments where status='active'),
    'available_sponsors',(select count(*) from public.sponsor_offers where status='available'),
    'managed_staff',(select count(*) from public.staff),
    'world_staff',(select count(*) from public.staff_profiles where active=true),
    'active_contracts',(select count(*) from public.contracts where status='active'),
    'relationships',(select count(*) from public.player_relationships where active),
    'season_plans',(select count(*) from public.player_season_plans where season=extract(year from p_date)::int),
    'living_world',public.living_world_integrity_audit_v16(p_date),
    'world_guard_v18',public.world_integrity_guard_v18(p_date),
    'entry_rules_v19',public.tournament_entry_rules_audit_v19(p_date),
    'model','CB-CAREER-OS-v19'
  );
$function$
;

