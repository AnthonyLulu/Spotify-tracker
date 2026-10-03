-- Court Boss V20: official 2026 doubles entry composition and AI scheduling

CREATE OR REPLACE FUNCTION public.doubles_player_entry_merit_v20(p_player_id bigint, p_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  p public.players%rowtype;
  v_singles int:=999999;
  v_doubles int:=999999;
  v_protected int:=999999;
  v_protected_type text:=null;
  v_best int:=999999;
  v_source text:='unranked';
begin
  select * into p from public.players where id=p_player_id;
  if p.id is null then
    return jsonb_build_object('rank',999999,'source','missing','atp_ranked',false);
  end if;

  v_singles:=coalesce(public.player_rank_at_date(p.id,p_date),999999);
  v_doubles:=coalesce(public.player_doubles_seed_rank_at_date(p.id,p_date),999999);

  select ep.protected_rank,
         case
           when lower(coalesce(ep.event_type,''))='singles' then 'singles_protected'
           when lower(coalesce(ep.event_type,''))='doubles' then 'doubles_protected'
           else 'protected'
         end
  into v_protected,v_protected_type
  from public.player_entry_protection ep
  where ep.player_id=p.id
    and lower(coalesce(ep.status,'active'))='active'
    and lower(coalesce(ep.event_type,'')) in ('singles','doubles','both','all')
    and (ep.active_until is null or ep.active_until>=p_date)
    and (ep.activation_deadline is null or ep.activation_deadline>=p_date)
    and coalesce(ep.uses_used,0)<coalesce(ep.max_uses,999)
  order by ep.protected_rank
  limit 1;

  v_protected:=coalesce(v_protected,999999);
  v_best:=least(v_singles,v_doubles,v_protected);

  v_source:=case
    when v_best=v_protected and v_protected<999999 then coalesce(v_protected_type,'protected')
    when v_best=v_doubles and v_doubles<999999 then 'doubles'
    when v_best=v_singles and v_singles<999999 then 'singles'
    else 'unranked'
  end;

  return jsonb_build_object(
    'rank',v_best,
    'source',v_source,
    'singles_rank',nullif(v_singles,999999),
    'doubles_rank',nullif(v_doubles,999999),
    'protected_rank',nullif(v_protected,999999),
    'itf_rank',p.itf_ranking,
    'atp_ranked',v_best<999999
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.player_doubles_entry_rank(p_player_id bigint, p_date date)
 RETURNS integer
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select coalesce((public.doubles_player_entry_merit_v20(p_player_id,p_date)->>'rank')::int,999999);
$function$
;

CREATE OR REPLACE FUNCTION public.doubles_team_entry_merit_v20(p_pair_id bigint, p_tournament_id bigint, p_mode text DEFAULT 'auto'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  w public.world_doubles_partnerships%rowtype;
  t public.tournaments%rowtype;
  a public.players%rowtype;
  b public.players%rowtype;
  ma jsonb;
  mb jsonb;
  v_date date;
  ar int:=999999; br int:=999999;
  asrc text; bsrc text;
  aitf int; bitf int;
  v_mode text:=lower(coalesce(p_mode,'auto'));
  v_tier int:=99;
  v_combined bigint:=1999998;
  v_eligible boolean:=false;
  v_doubles_count int:=0;
  v_protected_count int:=0;
begin
  select * into w from public.world_doubles_partnerships where id=p_pair_id;
  select * into t from public.tournaments where id=p_tournament_id;
  if w.id is null or t.id is null then
    return jsonb_build_object('eligible',false,'reason','missing_pair_or_tournament');
  end if;
  select * into a from public.players where id=w.player_a_id;
  select * into b from public.players where id=w.player_b_id;

  v_date:=case
    when t.circuit='ITF' then date_trunc('week',t.start_date::timestamp)::date-7
    else coalesce(t.doubles_entry_deadline,t.main_entry_deadline,t.start_date-21)
  end;

  ma:=public.doubles_player_entry_merit_v20(a.id,v_date);
  mb:=public.doubles_player_entry_merit_v20(b.id,v_date);
  ar:=coalesce((ma->>'rank')::int,999999);
  br:=coalesce((mb->>'rank')::int,999999);
  asrc:=coalesce(ma->>'source','unranked');
  bsrc:=coalesce(mb->>'source','unranked');
  aitf:=a.itf_ranking;
  bitf:=b.itf_ranking;

  v_doubles_count:=
    (case when asrc like 'doubles%' then 1 else 0 end)
    +(case when bsrc like 'doubles%' then 1 else 0 end);
  v_protected_count:=
    (case when asrc like '%protected%' then 1 else 0 end)
    +(case when bsrc like '%protected%' then 1 else 0 end);

  if v_mode='auto' then
    v_mode:=case
      when t.circuit='ITF' and t.category='M25' then 'itf_onsite'
      when t.circuit='ITF' and t.category='M15' then 'itf_onsite'
      else 'atp'
    end;
  end if;

  if v_mode='itf_advance' then
    -- M25 advance entry: both players need ATP doubles ranking / doubles PR.
    if (ma->>'doubles_rank') is not null and (mb->>'doubles_rank') is not null then
      v_eligible:=true;
      v_tier:=1;
      v_combined:=((ma->>'doubles_rank')::int+(mb->>'doubles_rank')::int);
    elsif asrc='doubles_protected' and (mb->>'doubles_rank') is not null then
      v_eligible:=true; v_tier:=1;
      v_combined:=ar+(mb->>'doubles_rank')::int;
    elsif bsrc='doubles_protected' and (ma->>'doubles_rank') is not null then
      v_eligible:=true; v_tier:=1;
      v_combined:=br+(ma->>'doubles_rank')::int;
    elsif asrc='doubles_protected' and bsrc='doubles_protected' then
      v_eligible:=true; v_tier:=1; v_combined:=ar+br;
    end if;

  elsif v_mode='itf_onsite' then
    -- ITF M15/M25 on-site hierarchy:
    -- ATP+ATP, ATP+ITF, ITF+ITF, ATP+unranked, ITF+unranked, unranked+unranked.
    if ar<999999 and br<999999 then
      v_tier:=1; v_combined:=ar+br; v_eligible:=true;
    elsif ar<999999 and bitf is not null then
      v_tier:=2; v_combined:=ar+bitf; v_eligible:=true;
    elsif br<999999 and aitf is not null then
      v_tier:=2; v_combined:=br+aitf; v_eligible:=true;
    elsif aitf is not null and bitf is not null then
      v_tier:=3; v_combined:=aitf+bitf; v_eligible:=true;
    elsif ar<999999 or br<999999 then
      v_tier:=4; v_combined:=least(ar,br); v_eligible:=true;
    elsif aitf is not null or bitf is not null then
      v_tier:=5; v_combined:=least(coalesce(aitf,999999),coalesce(bitf,999999)); v_eligible:=true;
    else
      v_tier:=6; v_combined:=999999; v_eligible:=true;
    end if;

  else
    -- ATP Tour / Challenger / Grand Slam: both players must hold an ATP singles
    -- or doubles ranking (including eligible protected ranking).
    v_eligible:=ar<999999 and br<999999;
    if v_eligible then
      v_combined:=ar+br;
      v_tier:=case when v_doubles_count=2 then 1 when v_doubles_count=1 then 2 else 3 end;
    end if;
  end if;

  return jsonb_build_object(
    'eligible',v_eligible,
    'mode',v_mode,
    'tier',v_tier,
    'combined_rank',v_combined,
    'player_a_rank',ar,'player_a_source',asrc,'player_a_itf_rank',aitf,
    'player_b_rank',br,'player_b_source',bsrc,'player_b_itf_rank',bitf,
    'doubles_sources',v_doubles_count,
    'protected_sources',v_protected_count,
    'ranking_date',v_date,
    'model','CB-DOUBLES-MERIT-v20'
  );
end;
$function$
;

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
  v_dr int:=999999;
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

  v_dr:=coalesce(public.player_doubles_seed_rank_at_date(
    p.id,coalesce(t.doubles_entry_deadline,t.start_date)
  ),999999);

  prob:=case
    when t.category='Grand Chelem' then 96
    when t.category='Masters 1000' then 90
    when t.category='ATP 500' then 82
    when t.category='ATP 250' then 72
    when t.circuit='Challenger' then
      case when v_dr<=30 then 6 when v_dr<=75 then 18 when v_dr<=150 then 42
           when v_dr<=300 then 68 else 78 end
    when t.category='M25' then
      case when v_dr<=50 then 1 when v_dr<=150 then 5 when v_dr<=300 then 20
           when v_dr<=600 then 55 else 80 end
    when t.category='M15' then
      case when v_dr<=50 then .2 when v_dr<=150 then 2 when v_dr<=300 then 10
           when v_dr<=600 then 38 else 84 end
    when t.circuit='Junior' then 82
    else 60 end;

  prob:=prob+(v_doubles_bias-10)*2.1;

  prob:=prob+case coalesce(p.career_focus,'mixed')
    when 'doubles_only' then 18
    when 'mixed' then 5
    when 'singles_priority' then -10
    else 0 end;

  if v_dr<=50 and t.category in ('Grand Chelem','Masters 1000','ATP 500') then
    prob:=prob+6;
  elsif v_dr<=150 and t.category in ('ATP 500','ATP 250') then
    prob:=prob+4;
  end if;

  if v_same_event_singles then prob:=prob+12; end if;

  -- A strong singles player may be legally eligible for low-level doubles,
  -- but autonomous scheduling should not send them there without a compelling reason.
  if not v_same_event_singles then
    if t.category='M15' then
      if coalesce(p.ranking,999999)<=100 then prob:=least(prob,.2);
      elsif coalesce(p.ranking,999999)<=200 then prob:=least(prob,1);
      elsif coalesce(p.ranking,999999)<=400 then prob:=least(prob,5);
      end if;
    elsif t.category='M25' then
      if coalesce(p.ranking,999999)<=50 then prob:=least(prob,.5);
      elsif coalesce(p.ranking,999999)<=100 then prob:=least(prob,2);
      elsif coalesce(p.ranking,999999)<=200 then prob:=least(prob,7);
      end if;
    elsif t.circuit='Challenger' then
      if coalesce(p.ranking,999999)<=20 then prob:=least(prob,3);
      elsif coalesce(p.ranking,999999)<=50 then prob:=least(prob,10);
      end if;
    end if;
  end if;

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
  roll:=(mod(abs(hashtext('ai-double-commit-v20|'||t.id::text||'|'||p.id::text)),10000)::numeric)/100.0;
  return roll<prob;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.select_itf_doubles_field_v20(p_tournament_id bigint, p_managed_player_id bigint DEFAULT NULL::bigint)
 RETURNS TABLE(pair_id bigint, entry_method text, score numeric, merit_tier integer, combined_rank bigint, source_label text)
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  v_year int;
  v_direct_target int:=13;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null or t.circuit<>'ITF' or t.category not in ('M15','M25') then
    return;
  end if;
  v_year:=extract(year from t.start_date)::int;

  if t.category='M15' then
    return query
    with base as (
      select
        w.id pair_id,
        (
          w.pair_strength*.34+w.chemistry*.17+w.compatibility*.14+w.affinity_score*.05+
          coalesce(pa.doubles,10)*.20+coalesce(pb.doubles,10)*.20+
          coalesce(public.player_psychology_modifier(a.id),0)*.30+
          coalesce(public.player_psychology_modifier(b.id),0)*.30+
          (mod(abs(hashtext('itf-dentry-v20|'||t.id||'|'||w.id)),1000)/1000.0)*3
        )::numeric quality,
        ((a.country is not distinct from t.country)::int+
         (b.country is not distinct from t.country)::int) home_count,
        public.doubles_team_entry_merit_v20(w.id,t.id,'itf_onsite') merit
      from public.world_doubles_partnerships w
      join public.players a on a.id=w.player_a_id
      join public.players b on b.id=w.player_b_id
      left join public.player_attributes pa on pa.player_id=a.id
      left join public.player_attributes pb on pb.player_id=b.id
      where w.season=v_year and w.active=true
        and a.career_status='active' and b.career_status='active'
        and a.id<>coalesce(p_managed_player_id,-1)
        and b.id<>coalesce(p_managed_player_id,-1)
        and coalesce(a.career_focus,'mixed')<>'singles_only'
        and coalesce(b.career_focus,'mixed')<>'singles_only'
        and a.injury_status='Fit' and b.injury_status='Fit'
        and coalesce(a.fitness,90)>=48 and coalesce(b.fitness,90)>=48
        and coalesce(a.fatigue,20)<=88 and coalesce(b.fatigue,20)<=88
        and not (public.player_tournament_calendar_conflict(a.id,t.id,'doubles')->>'conflict')::boolean
        and not (public.player_tournament_calendar_conflict(b.id,t.id,'doubles')->>'conflict')::boolean
        and public.ai_player_commits_to_doubles_tournament(a.id,t.id)
        and public.ai_player_commits_to_doubles_tournament(b.id,t.id)
    ),
    direct as (
      select b.*,
             row_number() over(
               order by (b.merit->>'tier')::int,
                        (b.merit->>'combined_rank')::bigint,
                        b.quality desc,b.pair_id
             ) rn
      from base b
      where coalesce((b.merit->>'eligible')::boolean,false)
    ),
    da as (
      select * from direct where rn<=13
    ),
    wc as (
      select b.*,
             row_number() over(
               order by b.home_count desc,b.quality desc,b.pair_id
             ) rn
      from base b
      where not exists(select 1 from da d where d.pair_id=b.pair_id)
    )
    select d.pair_id,'onsite'::text,d.quality,
           (d.merit->>'tier')::int,(d.merit->>'combined_rank')::bigint,
           'ITF 2026 M15 doubles · on-site system of merit'::text
    from da d
    union all
    select w.pair_id,'wildcard'::text,w.quality,
           99,999999999::bigint,
           'ITF 2026 M15 doubles · wildcard'::text
    from wc w where w.rn<=3;
    return;
  end if;

  return query
  with base as (
    select
      w.id pair_id,
      (
        w.pair_strength*.34+w.chemistry*.17+w.compatibility*.14+w.affinity_score*.05+
        coalesce(pa.doubles,10)*.20+coalesce(pb.doubles,10)*.20+
        coalesce(public.player_psychology_modifier(a.id),0)*.30+
        coalesce(public.player_psychology_modifier(b.id),0)*.30+
        (mod(abs(hashtext('itf-dentry-v20|'||t.id||'|'||w.id)),1000)/1000.0)*3
      )::numeric quality,
      ((a.country is not distinct from t.country)::int+
       (b.country is not distinct from t.country)::int) home_count,
      public.doubles_team_entry_merit_v20(w.id,t.id,'itf_advance') advance_merit,
      public.doubles_team_entry_merit_v20(w.id,t.id,'itf_onsite') onsite_merit
    from public.world_doubles_partnerships w
    join public.players a on a.id=w.player_a_id
    join public.players b on b.id=w.player_b_id
    left join public.player_attributes pa on pa.player_id=a.id
    left join public.player_attributes pb on pb.player_id=b.id
    where w.season=v_year and w.active=true
      and a.career_status='active' and b.career_status='active'
      and a.id<>coalesce(p_managed_player_id,-1)
      and b.id<>coalesce(p_managed_player_id,-1)
      and coalesce(a.career_focus,'mixed')<>'singles_only'
      and coalesce(b.career_focus,'mixed')<>'singles_only'
      and a.injury_status='Fit' and b.injury_status='Fit'
      and coalesce(a.fitness,90)>=48 and coalesce(b.fitness,90)>=48
      and coalesce(a.fatigue,20)<=88 and coalesce(b.fatigue,20)<=88
      and not (public.player_tournament_calendar_conflict(a.id,t.id,'doubles')->>'conflict')::boolean
      and not (public.player_tournament_calendar_conflict(b.id,t.id,'doubles')->>'conflict')::boolean
      and public.ai_player_commits_to_doubles_tournament(a.id,t.id)
      and public.ai_player_commits_to_doubles_tournament(b.id,t.id)
  ),
  advance_ranked as (
    select b.*,
           row_number() over(
             order by (b.advance_merit->>'combined_rank')::bigint,
                      (b.advance_merit->>'protected_sources')::int,
                      b.quality desc,b.pair_id
           ) rn
    from base b
    where coalesce((b.advance_merit->>'eligible')::boolean,false)
  ),
  advance as (
    select * from advance_ranked where rn<=7
  ),
  onsite_ranked as (
    select b.*,
           row_number() over(
             order by (b.onsite_merit->>'tier')::int,
                      (b.onsite_merit->>'combined_rank')::bigint,
                      b.quality desc,b.pair_id
           ) rn
    from base b
    where coalesce((b.onsite_merit->>'eligible')::boolean,false)
      and not exists(select 1 from advance a where a.pair_id=b.pair_id)
  ),
  onsite as (
    select *
    from onsite_ranked
    where rn<=greatest(0,13-(select count(*) from advance))
  ),
  wc_ranked as (
    select b.*,
           row_number() over(
             order by b.home_count desc,b.quality desc,b.pair_id
           ) rn
    from base b
    where not exists(select 1 from advance a where a.pair_id=b.pair_id)
      and not exists(select 1 from onsite o where o.pair_id=b.pair_id)
  )
  select a.pair_id,'advance'::text,a.quality,
         1,(a.advance_merit->>'combined_rank')::bigint,
         'ITF 2026 M25 doubles · advance entry'::text
  from advance a
  union all
  select o.pair_id,'onsite'::text,o.quality,
         (o.onsite_merit->>'tier')::int,(o.onsite_merit->>'combined_rank')::bigint,
         'ITF 2026 M25 doubles · on-site entry'::text
  from onsite o
  union all
  select w.pair_id,'wildcard'::text,w.quality,
         99,999999999::bigint,
         'ITF 2026 M25 doubles · wildcard'::text
  from wc_ranked w
  where w.rn<=3;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.doubles_m1000_auto_acceptance_v20(p_pair_id bigint, p_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  w public.world_doubles_partnerships%rowtype;
  t public.tournaments%rowtype;
  v_ordinal int:=0;
  v_rank int:=null;
  v_eligible boolean:=false;
  v_basis text:='not_applicable';
begin
  select * into w from public.world_doubles_partnerships where id=p_pair_id;
  select * into t from public.tournaments where id=p_tournament_id;
  if w.id is null or t.id is null
     or t.circuit<>'ATP' or t.category<>'Masters 1000'
     or extract(year from t.start_date)::int<>2026 then
    return jsonb_build_object('eligible',false,'basis',v_basis,'model','CB-M1000-DOUBLES-AUTO-v20');
  end if;

  select count(*)::int into v_ordinal
  from public.tournaments x
  where x.circuit='ATP' and x.category='Masters 1000'
    and extract(year from x.start_date)::int=2026
    and coalesce(x.is_active,true)
    and (x.start_date<t.start_date or (x.start_date=t.start_date and x.id<=t.id));

  if v_ordinal<=5 then
    select d.doubles_race_ranking
    into v_rank
    from public.doubles_race_2025_full d
    where d.is_team=true
      and d.doubles_race_ranking<=13
      and (
        (d.player_one_id=w.player_a_id and d.player_two_id=w.player_b_id)
        or
        (d.player_one_id=w.player_b_id and d.player_two_id=w.player_a_id)
      )
    order by d.doubles_race_ranking
    limit 1;

    v_eligible:=v_rank is not null and w.active=true;
    v_basis:='final_2025_top13_team_and_active_2026_pair';
  else
    -- For the last four Masters 1000s, the rule uses the Team Race at
    -- that event's advance-entry deadline. The living-world pair race is
    -- refreshed during the season, so the current race_rank is the game source.
    v_rank:=w.race_rank;
    v_eligible:=w.active=true
      and coalesce(w.race_points,0)>0
      and coalesce(w.race_rank,999999)<=13;
    v_basis:='2026_team_race_top13_at_entry_window';
  end if;

  return jsonb_build_object(
    'eligible',v_eligible,
    'masters_ordinal',v_ordinal,
    'team_rank',v_rank,
    'basis',v_basis,
    'continuity_required',true,
    'model','CB-M1000-DOUBLES-AUTO-v20'
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.select_pro_doubles_field_v20(p_tournament_id bigint, p_managed_player_id bigint DEFAULT NULL::bigint)
 RETURNS TABLE(pair_id bigint, entry_method text, score numeric, merit_tier integer, combined_rank bigint, source_label text)
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  v_year int;
  v_draw int;
  v_da int:=0;
  v_wc int:=0;
  v_onsite int:=0;
  v_q_da int:=0;
  v_q_wc int:=0;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null
     or coalesce(t.circuit,'') not in ('ATP','Challenger')
     or t.category in ('ATP Finals','Next Gen Finals','United Cup','Laver Cup','Davis Cup') then
    return;
  end if;

  v_year:=extract(year from t.start_date)::int;
  v_draw:=greatest(4,least(64,coalesce(t.doubles_draw_size,16)));

  if t.category='Grand Chelem' then
    v_wc:=least(7,v_draw);
    v_da:=v_draw-v_wc;
  elsif t.category='Masters 1000' then
    if v_draw=32 then v_da:=29;v_wc:=3;
    elsif v_draw=28 then v_da:=25;v_wc:=3;
    elsif v_draw=24 then v_da:=22;v_wc:=2;
    else
      v_wc:=least(3,greatest(0,v_draw/10));
      v_da:=v_draw-v_wc;
    end if;
  elsif t.category='ATP 500' then
    -- One main-draw place comes from a four-team qualifying event.
    v_wc:=2;
    v_da:=greatest(0,v_draw-v_wc-1);
    v_q_da:=3;
    v_q_wc:=1;
  elsif t.category='ATP 250' then
    v_wc:=2;
    v_da:=greatest(0,v_draw-v_wc);
  elsif t.circuit='Challenger' then
    v_da:=least(10,v_draw);
    v_onsite:=least(4,greatest(0,v_draw-v_da));
    v_wc:=greatest(0,v_draw-v_da-v_onsite);
  else
    return;
  end if;

  return query
  with base as (
    select
      w.id pair_id,
      (
        w.pair_strength*.34+w.chemistry*.17+w.compatibility*.14+w.affinity_score*.05+
        coalesce(pa.doubles,10)*.20+coalesce(pb.doubles,10)*.20+
        coalesce(public.player_psychology_modifier(a.id),0)*.30+
        coalesce(public.player_psychology_modifier(b.id),0)*.30+
        (mod(abs(hashtext('pro-dentry-v20|'||t.id||'|'||w.id)),1000)/1000.0)*3
      )::numeric quality,
      ((a.country is not distinct from t.country)::int+
       (b.country is not distinct from t.country)::int) home_count,
      public.doubles_team_entry_merit_v20(w.id,t.id,'atp') merit,
      public.doubles_m1000_auto_acceptance_v20(w.id,t.id) auto_m1000
    from public.world_doubles_partnerships w
    join public.players a on a.id=w.player_a_id
    join public.players b on b.id=w.player_b_id
    left join public.player_attributes pa on pa.player_id=a.id
    left join public.player_attributes pb on pb.player_id=b.id
    where w.season=v_year and w.active=true
      and a.career_status='active' and b.career_status='active'
      and a.id<>coalesce(p_managed_player_id,-1)
      and b.id<>coalesce(p_managed_player_id,-1)
      and coalesce(a.career_focus,'mixed')<>'singles_only'
      and coalesce(b.career_focus,'mixed')<>'singles_only'
      and a.injury_status='Fit' and b.injury_status='Fit'
      and coalesce(a.fitness,90)>=48 and coalesce(b.fitness,90)>=48
      and coalesce(a.fatigue,20)<=88 and coalesce(b.fatigue,20)<=88
      and coalesce((public.doubles_team_entry_merit_v20(w.id,t.id,'atp')->>'eligible')::boolean,false)
      and not (public.player_tournament_calendar_conflict(a.id,t.id,'doubles')->>'conflict')::boolean
      and not (public.player_tournament_calendar_conflict(b.id,t.id,'doubles')->>'conflict')::boolean
      and (
        coalesce((public.doubles_m1000_auto_acceptance_v20(w.id,t.id)->>'eligible')::boolean,false)
        or (
          public.ai_player_commits_to_doubles_tournament(a.id,t.id)
          and public.ai_player_commits_to_doubles_tournament(b.id,t.id)
        )
      )
  ),
  ranked as (
    select b.*,
           row_number() over(
             order by
               case when coalesce((b.auto_m1000->>'eligible')::boolean,false) then 0 else 1 end,
               (b.merit->>'tier')::int,
               (b.merit->>'combined_rank')::bigint,
               b.quality desc,b.pair_id
           ) rn
    from base b
  ),
  da as (
    select * from ranked where rn<=v_da
  ),
  q_direct as (
    select r.*,
           row_number() over(
             order by (r.merit->>'tier')::int,
                      (r.merit->>'combined_rank')::bigint,
                      r.quality desc,r.pair_id
           ) qrn
    from ranked r
    where t.category='ATP 500'
      and not exists(select 1 from da d where d.pair_id=r.pair_id)
    limit v_q_da
  ),
  main_wc_ranked as (
    select r.*,
           row_number() over(
             order by r.home_count desc,r.quality desc,
                      (r.merit->>'combined_rank')::bigint,r.pair_id
           ) wrn
    from ranked r
    where not exists(select 1 from da d where d.pair_id=r.pair_id)
      and not exists(select 1 from q_direct q where q.pair_id=r.pair_id)
  ),
  main_wc as (
    select * from main_wc_ranked where wrn<=v_wc
  ),
  q_wc_ranked as (
    select r.*,
           row_number() over(
             order by r.home_count desc,r.quality desc,
                      (r.merit->>'combined_rank')::bigint,r.pair_id
           ) qwrn
    from ranked r
    where t.category='ATP 500'
      and not exists(select 1 from da d where d.pair_id=r.pair_id)
      and not exists(select 1 from q_direct q where q.pair_id=r.pair_id)
      and not exists(select 1 from main_wc w where w.pair_id=r.pair_id)
  ),
  q_wc as (
    select * from q_wc_ranked where qwrn<=v_q_wc
  ),
  onsite_ranked as (
    select r.*,
           row_number() over(
             order by (r.merit->>'tier')::int,
                      (r.merit->>'combined_rank')::bigint,
                      r.quality desc,r.pair_id
           ) orn
    from ranked r
    where t.circuit='Challenger'
      and not exists(select 1 from da d where d.pair_id=r.pair_id)
      and not exists(select 1 from main_wc w where w.pair_id=r.pair_id)
  ),
  onsite as (
    select * from onsite_ranked where orn<=v_onsite
  )
  select d.pair_id,
         case when coalesce((d.auto_m1000->>'eligible')::boolean,false)
              then 'auto_direct' else 'direct' end,
         d.quality,(d.merit->>'tier')::int,(d.merit->>'combined_rank')::bigint,
         case
           when coalesce((d.auto_m1000->>'eligible')::boolean,false)
             then 'ATP 2026 Masters 1000 doubles · automatic direct acceptance'
           when t.category='Grand Chelem'
             then 'Grand Slam 2026 men''s doubles · direct acceptance'
           else 'ATP 2026 doubles · advance direct acceptance'
         end
  from da d

  union all
  select w.pair_id,'wildcard',w.quality,99,999999999::bigint,
         case when t.category='Grand Chelem'
              then 'Grand Slam 2026 men''s doubles · wildcard'
              else 'ATP 2026 doubles · main-draw wildcard' end
  from main_wc w

  union all
  select o.pair_id,'onsite',o.quality,
         (o.merit->>'tier')::int,(o.merit->>'combined_rank')::bigint,
         'ATP 2026 Challenger doubles · on-site acceptance'
  from onsite o

  union all
  select q.pair_id,'qualifying',q.quality,
         (q.merit->>'tier')::int,(q.merit->>'combined_rank')::bigint,
         'ATP 2026 ATP 500 doubles qualifying · direct acceptance'
  from q_direct q

  union all
  select q.pair_id,'qualifying_wildcard',q.quality,99,999999999::bigint,
         'ATP 2026 ATP 500 doubles qualifying · wildcard'
  from q_wc q;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.simulate_world_doubles_tournaments(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  v_year int;
  v_managed bigint;
  v_draw int;
  v_bracket int;
  v_byes int;
  v_rounds int;
  v_round int;
  v_size int;
  v_pos int;
  v_next int;
  v_a bigint;
  v_b bigint;
  v_w bigint;
  v_l bigint;
  v_match jsonb;
  v_prob numeric;
  v_awon boolean;
  v_score text;
  v_round_code text;
  v_points int;
  v_prize numeric;
  v_winner bigint;
  v_finalist bigint;
  v_matches int:=0;
  v_simulated int:=0;
  v_selected int;
  v_qdraw int:=0;
  v_qslots int:=0;
  v_wc_count int:=0;
  v_pool_needed int:=0;
  v_seed_limit int:=0;
  v_qw1 bigint;
  v_qw2 bigint;
  v_qwinner bigint;
  entry_rec record;
  match_rec record;
begin
  perform pg_advisory_xact_lock(94832021);
  if p_to_date<=date '2025-12-01' then
    return jsonb_build_object('tournaments_simulated',0,'historical_cutoff',true);
  end if;
  select managed_player_id into v_managed from public.career_state where id='demo';

  for t in
    select *
    from public.tournaments
    where doubles=true and coalesce(is_active,true)=true
      and coalesce(end_date,start_date)>greatest(p_from_date,date '2025-12-01')
      and coalesce(end_date,start_date)<=p_to_date
      and coalesce(circuit,'') not in ('NCAA','Junior','Federation')
      and coalesce(category,'') not in ('United Cup','Laver Cup','ATP Finals')
      and not exists(select 1 from public.world_doubles_tournament_simulations s where s.tournament_id=tournaments.id)
    order by
      date_trunc('week',start_date::timestamp),
      case
        when category='Grand Chelem' then 100
        when category='Masters 1000' then 90
        when category='ATP 500' then 80
        when category='ATP 250' then 70
        when category='Challenger 175' then 60
        when category='Challenger 125' then 55
        when category='Challenger 100' then 50
        when category='Challenger 75' then 45
        when category='Challenger 50' then 40
        when category='M25' then 30
        when category='M15' then 25
        else 10 end desc,
      coalesce(end_date,start_date),id
    limit 120
  loop
    v_year:=extract(year from coalesce(t.end_date,t.start_date))::int;
    if not exists(select 1 from public.world_doubles_partnerships where season=v_year and active=true) then
      perform public.refresh_world_doubles_partnerships_fast(coalesce(t.start_date,p_to_date),2000);
    end if;

    v_draw:=greatest(4,least(64,coalesce(t.doubles_draw_size,16)));
    v_bracket:=case
      when v_draw<=8 then 8 when v_draw<=16 then 16 when v_draw<=32 then 32 else 64 end;
    v_byes:=v_bracket-v_draw;
    v_rounds:=ceil(ln(v_bracket::numeric)/ln(2::numeric))::int;
    v_qdraw:=case when t.circuit='ATP' and t.category='ATP 500' then 4 else 0 end;
    v_qslots:=case when v_qdraw=4 then 1 else 0 end;
    v_pool_needed:=v_draw+greatest(0,v_qdraw-v_qslots);
    v_wc_count:=0; -- V20 selectors reserve wildcard positions before acceptance.
    v_seed_limit:=case
      when t.category='Grand Chelem' and v_draw>=64 then 16
      when v_draw<=16 then 4
      else 8
    end;

    drop table if exists pg_temp.cb_d_entries;
    drop table if exists pg_temp.cb_d_current;
    drop table if exists pg_temp.cb_d_next;

    create temporary table cb_d_entries(
      pair_id bigint primary key,
      entry_method text not null default 'direct',
      score numeric,
      seed int,
      draw_slot int,
      had_bye boolean not null default false,
      matches_won int not null default 0,
      result_code text,
      points_awarded int not null default 0,
      prize_awarded numeric not null default 0,
      qualifying_points integer not null default 0,
      last_opponent_pair_id bigint,
      last_score text
    ) on commit drop;

    if t.circuit='ITF' and t.category in ('M15','M25') then
      insert into cb_d_entries(pair_id,entry_method,score)
      select f.pair_id,f.entry_method,f.score
      from public.select_itf_doubles_field_v20(t.id,v_managed) f;

    else
      insert into cb_d_entries(pair_id,entry_method,score)
      select f.pair_id,f.entry_method,f.score
      from public.select_pro_doubles_field_v20(t.id,v_managed) f;
    end if;

    select count(*) into v_selected from cb_d_entries;
    if v_selected<>v_pool_needed then continue; end if;

    if v_qdraw=4 and exists(
      select 1
      from public.world_doubles_qualifying_entries q
      where q.tournament_id=t.id and q.qualified=true
    ) then
      select q.pair_id into v_qwinner
      from public.world_doubles_qualifying_entries q
      where q.tournament_id=t.id and q.qualified=true
      order by q.id
      limit 1;

      if not exists(select 1 from cb_d_entries where pair_id=v_qwinner) then
        insert into cb_d_entries(pair_id,score,entry_method,qualifying_points)
        values(v_qwinner,-100000,'qualifier',45)
        on conflict(pair_id) do update set
          entry_method='qualifier',
          qualifying_points=greatest(cb_d_entries.qualifying_points,45);
      end if;

      delete from cb_d_entries e
      where e.pair_id in (
        select q.pair_id
        from public.world_doubles_qualifying_entries q
        where q.tournament_id=t.id and q.qualified=false
      );

      update cb_d_entries
      set entry_method='qualifier',qualifying_points=45
      where pair_id=v_qwinner;

      select count(*) into v_selected from cb_d_entries;
      while v_selected>v_draw loop
        delete from cb_d_entries
        where pair_id=(
          select e.pair_id
          from cb_d_entries e
          where e.pair_id<>v_qwinner
          order by e.score asc,e.pair_id desc
          limit 1
        );
        v_selected:=v_selected-1;
      end loop;
    else
    delete from public.world_doubles_qualifying_entries where tournament_id=t.id;
    delete from public.world_doubles_tournament_matches
    where tournament_id=t.id and is_qualifying=true;

    if v_qdraw=4 and v_qslots=1 then
      -- ATP 500 doubles qualifying: selector already reserved 3 direct + 1 qualifying WC.
      insert into public.world_doubles_qualifying_entries(
        tournament_id,pair_id,seed,entry_method,result_code,qualified,simulated_on,source_label
      )
      select
        t.id,z.pair_id,
        case when z.seed_order<=2 then z.seed_order else null end,
        z.entry_method,null,false,
        coalesce(t.qualifying_end_date,t.start_date),
        'ATP 2026 · ATP 500 doubles qualifying · combined PIF ATP Doubles Rankings'
      from (
        select e.pair_id,e.entry_method,
               row_number() over(
                 order by
                   public.player_doubles_seed_rank_at_date(
                     w.player_a_id,coalesce(t.qualifying_start_date,t.start_date)
                   )
                   + public.player_doubles_seed_rank_at_date(
                     w.player_b_id,coalesce(t.qualifying_start_date,t.start_date)
                   ),
                   least(
                     public.player_doubles_seed_rank_at_date(w.player_a_id,coalesce(t.qualifying_start_date,t.start_date)),
                     public.player_doubles_seed_rank_at_date(w.player_b_id,coalesce(t.qualifying_start_date,t.start_date))
                   ),
                   md5('dq-seed-tie|'||t.id::text||'|'||e.pair_id::text)
               )::int seed_order
        from cb_d_entries e
        join public.world_doubles_partnerships w on w.id=e.pair_id
        where e.entry_method in ('qualifying','qualifying_wildcard')
      ) z;

      select pair_id into v_a
      from public.world_doubles_qualifying_entries
      where tournament_id=t.id and seed=1
      limit 1;

      select pair_id into v_b
      from public.world_doubles_qualifying_entries
      where tournament_id=t.id and seed is null
      order by md5('dq-unseeded-a|'||t.id::text||'|'||pair_id::text)
      limit 1;

      v_match:=public.doubles_pair_matchup_v2(v_a,v_b,t.surface,coalesce(t.qualifying_end_date,t.start_date));
      v_prob:=greatest(.02,least(.98,coalesce((v_match->>'pair_a_probability')::numeric,.5)));
      v_awon:=random()<v_prob;
      v_qw1:=case when v_awon then v_a else v_b end;
      v_l:=case when v_awon then v_b else v_a end;
      v_score:=public.world_tournament_score(v_prob,v_awon,3);

      insert into public.world_doubles_tournament_matches(
        tournament_id,round_no,round_code,match_no,pair_a_id,pair_b_id,winner_pair_id,loser_pair_id,
        score,pair_a_win_probability,model_version,matchup_components,simulated_on,is_qualifying
      ) values(
        t.id,-2,'DQ1',1,v_a,v_b,v_qw1,v_l,v_score,round(v_prob,4),
        'CB-DOUBLES-v4-QUALIFYING',coalesce(v_match->'components','{}'::jsonb),
        coalesce(t.qualifying_end_date,t.start_date),true
      );
      update public.world_doubles_qualifying_entries set result_code='DQ1'
      where tournament_id=t.id and pair_id=v_l;

      select pair_id into v_a
      from public.world_doubles_qualifying_entries
      where tournament_id=t.id and seed=2
      limit 1;

      select pair_id into v_b
      from public.world_doubles_qualifying_entries
      where tournament_id=t.id and seed is null and pair_id<>v_b
      order by md5('dq-unseeded-b|'||t.id::text||'|'||pair_id::text)
      limit 1;

      v_match:=public.doubles_pair_matchup_v2(v_a,v_b,t.surface,coalesce(t.qualifying_end_date,t.start_date));
      v_prob:=greatest(.02,least(.98,coalesce((v_match->>'pair_a_probability')::numeric,.5)));
      v_awon:=random()<v_prob;
      v_qw2:=case when v_awon then v_a else v_b end;
      v_l:=case when v_awon then v_b else v_a end;
      v_score:=public.world_tournament_score(v_prob,v_awon,3);

      insert into public.world_doubles_tournament_matches(
        tournament_id,round_no,round_code,match_no,pair_a_id,pair_b_id,winner_pair_id,loser_pair_id,
        score,pair_a_win_probability,model_version,matchup_components,simulated_on,is_qualifying
      ) values(
        t.id,-2,'DQ1',2,v_a,v_b,v_qw2,v_l,v_score,round(v_prob,4),
        'CB-DOUBLES-v4-QUALIFYING',coalesce(v_match->'components','{}'::jsonb),
        coalesce(t.qualifying_end_date,t.start_date),true
      );
      update public.world_doubles_qualifying_entries set result_code='DQ1'
      where tournament_id=t.id and pair_id=v_l;

      v_a:=v_qw1; v_b:=v_qw2;
      v_match:=public.doubles_pair_matchup_v2(v_a,v_b,t.surface,coalesce(t.qualifying_end_date,t.start_date));
      v_prob:=greatest(.02,least(.98,coalesce((v_match->>'pair_a_probability')::numeric,.5)));
      v_awon:=random()<v_prob;
      v_qwinner:=case when v_awon then v_a else v_b end;
      v_l:=case when v_awon then v_b else v_a end;
      v_score:=public.world_tournament_score(v_prob,v_awon,3);

      insert into public.world_doubles_tournament_matches(
        tournament_id,round_no,round_code,match_no,pair_a_id,pair_b_id,winner_pair_id,loser_pair_id,
        score,pair_a_win_probability,model_version,matchup_components,simulated_on,is_qualifying
      ) values(
        t.id,-1,'DQF',1,v_a,v_b,v_qwinner,v_l,v_score,round(v_prob,4),
        'CB-DOUBLES-v4-QUALIFYING',coalesce(v_match->'components','{}'::jsonb),
        coalesce(t.qualifying_end_date,t.start_date),true
      );

      update public.world_doubles_qualifying_entries
      set result_code='DQF',points_awarded=25
      where tournament_id=t.id and pair_id=v_l;

      update public.world_doubles_qualifying_entries
      set result_code='Q',qualified=true,points_awarded=45
      where tournament_id=t.id and pair_id=v_qwinner;

      -- ATP 2026: the team losing the final qualifying round earns 25 points.
      insert into public.world_doubles_ranking_points(
        player_id,tournament_id,pair_id,label,earned_date,expiry_date,points,active,source_label
      )
      select w.player_a_id,t.id,w.id,t.name||' · DQF',
             coalesce(t.qualifying_end_date,t.start_date),
             coalesce(t.qualifying_end_date,t.start_date)+364,
             25,true,'ATP 500 doubles qualifying · final round'
      from public.world_doubles_partnerships w
      where w.id=v_l
      on conflict(player_id,tournament_id) do update set
        pair_id=excluded.pair_id,label=excluded.label,earned_date=excluded.earned_date,
        expiry_date=excluded.expiry_date,points=excluded.points,active=true,source_label=excluded.source_label;

      insert into public.world_doubles_ranking_points(
        player_id,tournament_id,pair_id,label,earned_date,expiry_date,points,active,source_label
      )
      select w.player_b_id,t.id,w.id,t.name||' · DQF',
             coalesce(t.qualifying_end_date,t.start_date),
             coalesce(t.qualifying_end_date,t.start_date)+364,
             25,true,'ATP 500 doubles qualifying · final round'
      from public.world_doubles_partnerships w
      where w.id=v_l
      on conflict(player_id,tournament_id) do update set
        pair_id=excluded.pair_id,label=excluded.label,earned_date=excluded.earned_date,
        expiry_date=excluded.expiry_date,points=excluded.points,active=true,source_label=excluded.source_label;

      update public.world_doubles_partnerships
      set race_points=race_points+25,
          last_refresh_date=greatest(last_refresh_date,coalesce(t.qualifying_end_date,t.start_date))
      where id=v_l;

      delete from cb_d_entries
      where entry_method in ('qualifying','qualifying_wildcard')
        and pair_id<>v_qwinner;

      update cb_d_entries
      set entry_method='qualifier',qualifying_points=45
      where pair_id=v_qwinner;
    end if;

    end if;

    select count(*) into v_selected from cb_d_entries;
    if v_selected<>v_draw then continue; end if;

    with seed_order as (
      select
        e.pair_id,
        row_number() over(
          order by
            public.player_doubles_seed_rank_at_date(
              w.player_a_id,
              case
                when t.category='Grand Chelem' then coalesce(t.main_draw_start_date,t.start_date)-7
                when t.circuit='ITF' then date_trunc('week',t.start_date::timestamp)::date-7
                else coalesce(t.main_draw_start_date,t.start_date)
              end
            )
            + public.player_doubles_seed_rank_at_date(
              w.player_b_id,
              case
                when t.category='Grand Chelem' then coalesce(t.main_draw_start_date,t.start_date)-7
                when t.circuit='ITF' then date_trunc('week',t.start_date::timestamp)::date-7
                else coalesce(t.main_draw_start_date,t.start_date)
              end
            ) asc,
            (
              select count(*)
              from public.world_doubles_tournament_entries pe
              join public.tournaments pt on pt.id=pe.tournament_id
              where pe.pair_id=e.pair_id
                and pt.start_date<
                  case
                    when t.category='Grand Chelem' then coalesce(t.main_draw_start_date,t.start_date)-7
                    when t.circuit='ITF' then date_trunc('week',t.start_date::timestamp)::date-7
                    else coalesce(t.main_draw_start_date,t.start_date)
                  end
                and pt.start_date>=
                  case
                    when t.category='Grand Chelem' then coalesce(t.main_draw_start_date,t.start_date)-371
                    when t.circuit='ITF' then date_trunc('week',t.start_date::timestamp)::date-371
                    else coalesce(t.main_draw_start_date,t.start_date)-364
                  end
            ) asc,
            public.player_doubles_seed_points_at_date(
              w.player_a_id,
              case
                when t.category='Grand Chelem' then coalesce(t.main_draw_start_date,t.start_date)-7
                when t.circuit='ITF' then date_trunc('week',t.start_date::timestamp)::date-7
                else coalesce(t.main_draw_start_date,t.start_date)
              end
            )
            + public.player_doubles_seed_points_at_date(
              w.player_b_id,
              case
                when t.category='Grand Chelem' then coalesce(t.main_draw_start_date,t.start_date)-7
                when t.circuit='ITF' then date_trunc('week',t.start_date::timestamp)::date-7
                else coalesce(t.main_draw_start_date,t.start_date)
              end
            ) desc,
            least(
              public.player_doubles_seed_rank_at_date(
                w.player_a_id,
                case
                  when t.category='Grand Chelem' then coalesce(t.main_draw_start_date,t.start_date)-7
                  when t.circuit='ITF' then date_trunc('week',t.start_date::timestamp)::date-7
                  else coalesce(t.main_draw_start_date,t.start_date)
                end
              ),
              public.player_doubles_seed_rank_at_date(
                w.player_b_id,
                case
                  when t.category='Grand Chelem' then coalesce(t.main_draw_start_date,t.start_date)-7
                  when t.circuit='ITF' then date_trunc('week',t.start_date::timestamp)::date-7
                  else coalesce(t.main_draw_start_date,t.start_date)
                end
              )
            ) asc,
            md5('dseed-tie|'||t.id::text||'|'||e.pair_id::text)
        )::int rn
      from cb_d_entries e
      join public.world_doubles_partnerships w on w.id=e.pair_id
      where t.circuit<>'ITF'
         or (
           public.player_doubles_seed_rank_at_date(
             w.player_a_id,date_trunc('week',t.start_date::timestamp)::date-7
           )<999999
           and
           public.player_doubles_seed_rank_at_date(
             w.player_b_id,date_trunc('week',t.start_date::timestamp)::date-7
           )<999999
         )
    )
    update cb_d_entries e
    set seed=case when seed_order.rn<=v_seed_limit then seed_order.rn else null end
    from seed_order
    where e.pair_id=seed_order.pair_id;

    -- deterministic spread of seeds, with byes assigned to top seeds
    update cb_d_entries
    set draw_slot=public.world_tournament_seed_slot_for_event(t.id,v_bracket,seed)
    where seed<=least(v_seed_limit,v_draw);

    if v_byes>0 then
      update cb_d_entries
      set had_bye=true
      where seed<=least(v_byes,v_seed_limit);
    end if;

    with used as (
      select draw_slot slot from cb_d_entries where draw_slot is not null
      union all
      select case when draw_slot%2=1 then draw_slot+1 else draw_slot-1 end
      from cb_d_entries where had_bye=true and draw_slot is not null
    ),
    avail as (
      select g slot,row_number() over(order by md5('dslot|'||t.id::text||'|'||g::text)) rn
      from generate_series(1,v_bracket) g
      where not exists(select 1 from used u where u.slot=g)
    ),
    unplaced as (
      select pair_id,row_number() over(order by md5('dpair|'||t.id::text||'|'||pair_id::text)) rn
      from cb_d_entries where draw_slot is null
    )
    update cb_d_entries e set draw_slot=a.slot
    from unplaced u join avail a using(rn)
    where e.pair_id=u.pair_id;

    create temporary table cb_d_current(pos int primary key,pair_id bigint) on commit drop;
    create temporary table cb_d_next(pos int primary key,pair_id bigint) on commit drop;
    insert into cb_d_current(pos,pair_id)
    select g,e.pair_id
    from generate_series(1,v_bracket) g
    left join cb_d_entries e on e.draw_slot=g;

    delete from public.world_doubles_tournament_matches where tournament_id=t.id and is_qualifying=false;
    v_size:=v_bracket;

    for v_round in 1..v_rounds loop
      truncate cb_d_next;
      v_next:=0;
      v_round_code:=case
        when v_round=1 and v_draw<>v_bracket then 'R'||v_draw::text
        when v_size>=64 then 'R64'
        when v_size>=32 then 'R32'
        when v_size>=16 then 'R16'
        when v_size>=8 then 'QF'
        when v_size>=4 then 'SF'
        else 'F' end;

      for v_pos in 1..v_size by 2 loop
        v_next:=v_next+1;
        select pair_id into v_a from cb_d_current where pos=v_pos;
        select pair_id into v_b from cb_d_current where pos=v_pos+1;

        if v_a is null and v_b is null then
          insert into cb_d_next(pos,pair_id) values(v_next,null);
          continue;
        elsif v_a is null or v_b is null then
          v_w:=coalesce(v_a,v_b);
          insert into cb_d_next(pos,pair_id) values(v_next,v_w);
          continue;
        end if;

        v_match:=public.doubles_pair_matchup_v2(v_a,v_b,t.surface,coalesce(t.end_date,t.start_date));
        v_prob:=greatest(.02,least(.98,coalesce((v_match->>'pair_a_probability')::numeric,.5)));
        v_awon:=random()<v_prob;
        v_w:=case when v_awon then v_a else v_b end;
        v_l:=case when v_awon then v_b else v_a end;
        v_score:=public.world_tournament_score(v_prob,v_awon,3);

        insert into public.world_doubles_tournament_matches(
          tournament_id,round_no,round_code,match_no,pair_a_id,pair_b_id,winner_pair_id,loser_pair_id,
          score,pair_a_win_probability,model_version,matchup_components,simulated_on
        ) values(
          t.id,v_round,v_round_code,(v_pos+1)/2,v_a,v_b,v_w,v_l,v_score,round(v_prob,4),
          'CB-DOUBLES-v3-FULLDRAW',coalesce(v_match->'components','{}'::jsonb),
          coalesce(t.end_date,t.start_date)
        );
        v_matches:=v_matches+1;

        v_points:=public.doubles_points_for_result(t.category,v_draw,v_round_code);
        v_prize:=public.tournament_prize_for_result(t.id,v_round_code,'doubles');
        update cb_d_entries
        set result_code=v_round_code,
            points_awarded=v_points+coalesce(qualifying_points,0),
            prize_awarded=v_prize,
            last_opponent_pair_id=v_w,
            last_score=case when v_l=v_a then v_score else public.world_invert_tennis_score(v_score) end
        where pair_id=v_l;
        update cb_d_entries set matches_won=matches_won+1 where pair_id=v_w;

        insert into cb_d_next(pos,pair_id) values(v_next,v_w);
      end loop;

      truncate cb_d_current;
      insert into cb_d_current select * from cb_d_next;
      v_size:=greatest(1,v_size/2);
    end loop;

    select pair_id into v_winner from cb_d_current order by pos limit 1;
    select loser_pair_id into v_finalist
    from public.world_doubles_tournament_matches
    where tournament_id=t.id and round_code='F'
    order by id desc limit 1;

    update cb_d_entries
    set result_code='W',
        points_awarded=public.doubles_points_for_result(t.category,v_draw,'W')+coalesce(qualifying_points,0),
        prize_awarded=public.tournament_prize_for_result(t.id,'W','doubles')
    where pair_id=v_winner;

    insert into public.world_doubles_tournament_entries(
      tournament_id,pair_id,entry_method,seed,draw_slot,had_bye,matches_won,result_code,result_label,
      points_awarded,prize_awarded,last_opponent_pair_id,last_score,simulated_on,source_label
    )
    select t.id,pair_id,entry_method,seed,draw_slot,had_bye,matches_won,result_code,
      case result_code when 'W' then 'Vainqueur' when 'F' then 'Finaliste'
        when 'SF' then 'Demi-finale' when 'QF' then 'Quart de finale'
        when 'R16' then '1/8 finale' when 'R24' then '1er tour · tableau 24'
        when 'R28' then '1er tour · tableau 28'
        when 'R32' then '1/16 finale' else result_code end,
      points_awarded,prize_awarded,last_opponent_pair_id,last_score,
      coalesce(t.end_date,t.start_date),'Court Boss doubles full draw'
    from cb_d_entries;

    insert into public.world_doubles_ranking_points(
      player_id,tournament_id,pair_id,label,earned_date,expiry_date,points,active,source_label
    )
    select w.player_a_id,t.id,e.pair_id,t.name||' · '||e.result_code,
           coalesce(t.end_date,t.start_date),coalesce(t.end_date,t.start_date)+364,
           e.points_awarded,true,'Court Boss doubles full draw'
    from cb_d_entries e join public.world_doubles_partnerships w on w.id=e.pair_id
    where e.points_awarded>0
    on conflict(player_id,tournament_id) do update set
      pair_id=excluded.pair_id,label=excluded.label,earned_date=excluded.earned_date,
      expiry_date=excluded.expiry_date,points=excluded.points,active=true,source_label=excluded.source_label;

    insert into public.world_doubles_ranking_points(
      player_id,tournament_id,pair_id,label,earned_date,expiry_date,points,active,source_label
    )
    select w.player_b_id,t.id,e.pair_id,t.name||' · '||e.result_code,
           coalesce(t.end_date,t.start_date),coalesce(t.end_date,t.start_date)+364,
           e.points_awarded,true,'Court Boss doubles full draw'
    from cb_d_entries e join public.world_doubles_partnerships w on w.id=e.pair_id
    where e.points_awarded>0
    on conflict(player_id,tournament_id) do update set
      pair_id=excluded.pair_id,label=excluded.label,earned_date=excluded.earned_date,
      expiry_date=excluded.expiry_date,points=excluded.points,active=true,source_label=excluded.source_label;

    update public.world_doubles_partnerships w
    set matches=w.matches+e.matches_won+case when e.result_code<>'W' then 1 else 0 end,
        wins=w.wins+e.matches_won,
        race_points=w.race_points+e.points_awarded,
        titles=w.titles+case when e.result_code='W' then 1 else 0 end,
        last_refresh_date=greatest(w.last_refresh_date,coalesce(t.end_date,t.start_date))
    from cb_d_entries e where w.id=e.pair_id;

    for entry_rec in
      select de.*,w.player_a_id,w.player_b_id,
             a.name a_name,b.name b_name
      from cb_d_entries de
      join public.world_doubles_partnerships w on w.id=de.pair_id
      join public.players a on a.id=w.player_a_id
      join public.players b on b.id=w.player_b_id
    loop
      if entry_rec.result_code='W' then
        insert into public.player_titles(player_id,tournament_name,title_date,level,surface,event_type,partner_player_id,partner_name,verified,source_label,origin)
        values
          (entry_rec.player_a_id,t.name,coalesce(t.end_date,t.start_date),t.category,t.surface,'doubles',entry_rec.player_b_id,entry_rec.b_name,false,'Court Boss doubles full draw','game'),
          (entry_rec.player_b_id,t.name,coalesce(t.end_date,t.start_date),t.category,t.surface,'doubles',entry_rec.player_a_id,entry_rec.a_name,false,'Court Boss doubles full draw','game')
        on conflict(player_id,tournament_name,title_date,event_type) do nothing;
      end if;
    end loop;

    insert into public.world_doubles_tournament_simulations(
      tournament_id,season,winner_pair_id,finalist_pair_id,winner_points,finalist_points,
      draw_size,simulated_on,source,final_win_probability,model_version,matchup_components
    )
    select t.id,v_year,v_winner,v_finalist,
      public.doubles_points_for_result(t.category,v_draw,'W'),
      public.doubles_points_for_result(t.category,v_draw,'F'),
      v_draw,coalesce(t.end_date,t.start_date),'Court Boss doubles full draw',
      case when m.winner_pair_id=m.pair_a_id then m.pair_a_win_probability else 1-m.pair_a_win_probability end,
      'CB-DOUBLES-v3-FULLDRAW',m.matchup_components
    from public.world_doubles_tournament_matches m
    where m.tournament_id=t.id and m.round_code='F'
    limit 1;

    v_simulated:=v_simulated+1;
  end loop;

  perform public.refresh_world_doubles_player_rankings(p_to_date);

  with ranked as (
    select id,row_number() over(order by race_points desc,pair_strength desc,affinity_score desc,id)::int rr
    from public.world_doubles_partnerships
    where season=extract(year from p_to_date)::int and active=true
  )
  update public.world_doubles_partnerships w set race_rank=r.rr from ranked r where w.id=r.id;

  return jsonb_build_object(
    'tournaments_simulated',v_simulated,'matches_simulated',v_matches,
    'from',p_from_date,'to',p_to_date,'ranking_model','best-18 rolling results',
    'match_model','CB-DOUBLES-v3-FULLDRAW'
  );
end
$function$
;

CREATE OR REPLACE FUNCTION public.doubles_entry_rules_audit_v20(p_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  v_m15 bigint;
  v_m25 bigint;
  v_atp250 bigint;
  v_atp500 bigint;
  v_m1000 bigint;
  v_ch bigint;
  v_gs bigint;
  j_m15 jsonb:='{}'::jsonb;
  j_m25 jsonb:='{}'::jsonb;
  j_atp250 jsonb:='{}'::jsonb;
  j_atp500 jsonb:='{}'::jsonb;
  j_m1000 jsonb:='{}'::jsonb;
  j_ch jsonb:='{}'::jsonb;
  j_gs jsonb:='{}'::jsonb;
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

  if v_m15 is not null then
    select jsonb_build_object(
      'total',count(*),
      'onsite',count(*) filter(where entry_method='onsite'),
      'wildcards',count(*) filter(where entry_method='wildcard')
    ) into j_m15
    from public.select_itf_doubles_field_v20(v_m15,null);
  end if;

  if v_m25 is not null then
    select jsonb_build_object(
      'total',count(*),
      'advance',count(*) filter(where entry_method='advance'),
      'onsite',count(*) filter(where entry_method='onsite'),
      'wildcards',count(*) filter(where entry_method='wildcard')
    ) into j_m25
    from public.select_itf_doubles_field_v20(v_m25,null);
  end if;

  if v_atp250 is not null then
    select jsonb_build_object(
      'total',count(*),
      'direct',count(*) filter(where entry_method in ('direct','auto_direct')),
      'wildcards',count(*) filter(where entry_method='wildcard')
    ) into j_atp250
    from public.select_pro_doubles_field_v20(v_atp250,null);
  end if;

  if v_atp500 is not null then
    select jsonb_build_object(
      'total_pool',count(*),
      'direct_main',count(*) filter(where entry_method='direct'),
      'main_wildcards',count(*) filter(where entry_method='wildcard'),
      'q_direct',count(*) filter(where entry_method='qualifying'),
      'q_wildcards',count(*) filter(where entry_method='qualifying_wildcard')
    ) into j_atp500
    from public.select_pro_doubles_field_v20(v_atp500,null);
  end if;

  if v_m1000 is not null then
    select jsonb_build_object(
      'total',count(*),
      'direct',count(*) filter(where entry_method in ('direct','auto_direct')),
      'auto_direct',count(*) filter(where entry_method='auto_direct'),
      'wildcards',count(*) filter(where entry_method='wildcard')
    ) into j_m1000
    from public.select_pro_doubles_field_v20(v_m1000,null);

    select count(*)::int into v_auto_m1000
    from public.select_pro_doubles_field_v20(v_m1000,null)
    where entry_method='auto_direct';
  end if;

  if v_ch is not null then
    select jsonb_build_object(
      'total',count(*),
      'advance',count(*) filter(where entry_method='direct'),
      'onsite',count(*) filter(where entry_method='onsite'),
      'wildcards',count(*) filter(where entry_method='wildcard')
    ) into j_ch
    from public.select_pro_doubles_field_v20(v_ch,null);
  end if;

  if v_gs is not null then
    select jsonb_build_object(
      'total',count(*),
      'direct',count(*) filter(where entry_method='direct'),
      'wildcards',count(*) filter(where entry_method='wildcard')
    ) into j_gs
    from public.select_pro_doubles_field_v20(v_gs,null);
  end if;

  select count(*)::int into v_same_week_conflicts
  from (
    select z.player_id,z.week_start
    from (
      select w.player_a_id player_id,
             date_trunc('week',t.start_date::timestamp)::date week_start,
             e.tournament_id
      from public.world_doubles_tournament_entries e
      join public.world_doubles_partnerships w on w.id=e.pair_id
      join public.tournaments t on t.id=e.tournament_id
      union all
      select w.player_b_id,
             date_trunc('week',t.start_date::timestamp)::date,
             e.tournament_id
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
    coalesce((j_m15->>'total')::int,0)=16
    and coalesce((j_m15->>'onsite')::int,0)=13
    and coalesce((j_m15->>'wildcards')::int,0)=3
    and coalesce((j_m25->>'total')::int,0)=16
    and coalesce((j_m25->>'advance')::int,0)=7
    and coalesce((j_m25->>'onsite')::int,0)=6
    and coalesce((j_m25->>'wildcards')::int,0)=3
    and coalesce((j_atp250->>'total')::int,0)=16
    and coalesce((j_atp250->>'direct')::int,0)=14
    and coalesce((j_atp250->>'wildcards')::int,0)=2
    and coalesce((j_atp500->>'direct_main')::int,0)=13
    and coalesce((j_atp500->>'main_wildcards')::int,0)=2
    and coalesce((j_atp500->>'q_direct')::int,0)=3
    and coalesce((j_atp500->>'q_wildcards')::int,0)=1
    and coalesce((j_m1000->>'total')::int,0)=32
    and coalesce((j_m1000->>'direct')::int,0)=29
    and coalesce((j_m1000->>'wildcards')::int,0)=3
    and v_auto_m1000 between 1 and 13
    and coalesce((j_ch->>'total')::int,0)=16
    and coalesce((j_ch->>'advance')::int,0)=10
    and coalesce((j_ch->>'onsite')::int,0)=4
    and coalesce((j_ch->>'wildcards')::int,0)=2
    and coalesce((j_gs->>'total')::int,0)=64
    and coalesce((j_gs->>'direct')::int,0)=57
    and coalesce((j_gs->>'wildcards')::int,0)=7
    and v_same_week_conflicts=0
    and v_retired_pair_entries=0
    and v_invalid_pair_entries=0;

  return jsonb_build_object(
    'ok',v_ok,
    'date',p_date,
    'm15',j_m15,
    'm25',j_m25,
    'atp250',j_atp250,
    'atp500',j_atp500,
    'masters1000',j_m1000,
    'challenger',j_ch,
    'grand_slam',j_gs,
    'masters1000_auto_teams',v_auto_m1000,
    'same_week_player_conflicts',v_same_week_conflicts,
    'retired_pair_entries',v_retired_pair_entries,
    'invalid_pair_entries',v_invalid_pair_entries,
    'models',jsonb_build_object(
      'merit','CB-DOUBLES-MERIT-v20',
      'm1000_auto','CB-M1000-DOUBLES-AUTO-v20',
      'itf_field','CB-ITF-DOUBLES-FIELD-v20',
      'pro_field','CB-PRO-DOUBLES-FIELD-v20'
    ),
    'model','CB-DOUBLES-ENTRY-AUDIT-v20'
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.world_25y_validation_v20(p_start_year integer DEFAULT 2025, p_end_year integer DEFAULT 2050)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  v_base jsonb;
  v_doubles jsonb;
begin
  v_base:=public.world_25y_validation_v19(p_start_year,p_end_year);
  v_doubles:=public.doubles_entry_rules_audit_v20(
    case when p_start_year=2025 then date '2025-12-01' else make_date(p_start_year,1,1) end
  );
  return jsonb_build_object(
    'ok',
      coalesce((v_base->>'ok')::boolean,false)
      and coalesce((v_doubles->>'ok')::boolean,false),
    'start_year',p_start_year,'end_year',p_end_year,
    'base_v19',v_base,
    'doubles_v20',v_doubles,
    'model','CB-WORLD-25Y-VALIDATION-v20'
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.career_long_term_health_v20(p_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select jsonb_build_object(
    'ok',
      coalesce((public.world_integrity_guard_v18(p_date)->>'ok')::boolean,false)
      and coalesce((public.tournament_entry_rules_audit_v19(p_date)->>'ok')::boolean,false)
      and coalesce((public.doubles_entry_rules_audit_v20(p_date)->>'ok')::boolean,false)
      and coalesce((public.world_25y_validation_v20(
        extract(year from p_date)::int,
        extract(year from p_date)::int+25
      )->>'ok')::boolean,false),
    'date',p_date,
    'world_guard',public.world_integrity_guard_v18(p_date),
    'singles_entry_rules',public.tournament_entry_rules_audit_v19(p_date),
    'doubles_entry_rules',public.doubles_entry_rules_audit_v20(p_date),
    'horizon_25y',public.world_25y_validation_v20(
      extract(year from p_date)::int,
      extract(year from p_date)::int+25
    ),
    'economy',public.career_operating_cost_profile_v15(p_date),
    'hall_of_fame_total',(select count(*) from public.hall_of_fame_candidates),
    'active_staff_profiles',(select count(*) from public.staff_profiles where active=true),
    'active_players',(select count(*) from public.players where career_status='active'),
    'model','CB-CAREER-LONG-HORIZON-v20'
  );
$function$
;

CREATE OR REPLACE FUNCTION public.career_long_term_health_v15(p_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select public.career_long_term_health_v20(p_date);
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
      and coalesce((public.tournament_entry_rules_audit_v19(p_date)->>'ok')::boolean,false)
      and coalesce((public.doubles_entry_rules_audit_v20(p_date)->>'ok')::boolean,false),
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
    'doubles_entry_rules_v20',public.doubles_entry_rules_audit_v20(p_date),
    'model','CB-CAREER-OS-v20'
  );
$function$
;

revoke all on function public.doubles_player_entry_merit_v20(bigint,date) from public,anon,authenticated;
revoke all on function public.doubles_team_entry_merit_v20(bigint,bigint,text) from public,anon,authenticated;
revoke all on function public.select_itf_doubles_field_v20(bigint,bigint) from public,anon,authenticated;
revoke all on function public.doubles_m1000_auto_acceptance_v20(bigint,bigint) from public,anon,authenticated;
revoke all on function public.select_pro_doubles_field_v20(bigint,bigint) from public,anon,authenticated;
revoke all on function public.doubles_entry_rules_audit_v20(date) from public,anon,authenticated;
revoke all on function public.world_25y_validation_v20(integer,integer) from public,anon,authenticated;
revoke all on function public.career_long_term_health_v20(date) from public,anon,authenticated;

grant execute on function public.doubles_player_entry_merit_v20(bigint,date) to service_role;
grant execute on function public.doubles_team_entry_merit_v20(bigint,bigint,text) to service_role;
grant execute on function public.select_itf_doubles_field_v20(bigint,bigint) to service_role;
grant execute on function public.doubles_m1000_auto_acceptance_v20(bigint,bigint) to service_role;
grant execute on function public.select_pro_doubles_field_v20(bigint,bigint) to service_role;
grant execute on function public.doubles_entry_rules_audit_v20(date) to service_role;
grant execute on function public.world_25y_validation_v20(integer,integer) to service_role;
grant execute on function public.career_long_term_health_v20(date) to service_role;
