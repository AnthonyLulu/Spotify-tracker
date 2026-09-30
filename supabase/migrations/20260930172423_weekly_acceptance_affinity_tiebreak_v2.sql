-- Deterministic player×tournament affinity breaks otherwise exact weekly-choice ties.
CREATE OR REPLACE FUNCTION public.world_acceptance_commitment_score(p_player_id bigint, p_tournament_id bigint, p_phase text DEFAULT 'main'::text, p_entry_method text DEFAULT NULL::text)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  p public.players%rowtype;
  t public.tournaments%rowtype;
  sp public.player_season_plans%rowtype;
  v_rank int;
  v_prob numeric;
  v_prestige numeric;
  v_score numeric;
  v_phase text:=lower(coalesce(p_phase,'main'));
  v_method text:=lower(coalesce(p_entry_method,''));
  v_ref date;
begin
  select * into p from public.players where id=p_player_id;
  select * into t from public.tournaments where id=p_tournament_id;
  if p.id is null or t.id is null then return -999999; end if;

  select * into sp
  from public.player_season_plans s
  where s.player_id=p.id and s.season=extract(year from t.start_date)::int;

  v_ref:=case
    when v_phase='qualifying' then coalesce(t.qualifying_entry_deadline,t.main_entry_deadline,t.start_date-18)
    else coalesce(t.main_entry_deadline,t.singles_entry_deadline,t.deadline,t.start_date-21)
  end;
  v_rank:=coalesce(
    public.player_rank_at_date(p.id,v_ref),
    case when p.ranking_current then p.ranking end,
    p.game_world_rank,p.ranking,999999
  );

  v_prob:=public.ai_tournament_commitment_probability(
    v_rank,
    coalesce(sp.plan_type,'tour_regular'),
    coalesce(sp.target_events,22),
    sp.preferred_surface,
    t.surface,
    t.category,
    p.country,
    t.country,
    coalesce(p.fatigue,20),
    coalesce(sp.rest_trigger_fatigue,72)
  );

  v_prestige:=case
    when t.category='Grand Chelem' then 100
    when t.category='Masters 1000' then 90
    when t.category='ATP 500' then 76
    when t.category='ATP 250' then 64
    when t.category='ATP Finals' then 98
    when t.category='Next Gen Finals' then 84
    when t.category='Challenger 175' then 56
    when t.category='Challenger 125' then 51
    when t.category='Challenger 100' then 47
    when t.category='Challenger 75' then 43
    when t.category='Challenger 50' then 39
    when t.category='M25' then 27
    when t.category='M15' then 22
    else 20
  end;

  v_score:=v_prob+v_prestige
    +case when v_phase='main' then 18 else 0 end
    +least(8,greatest(-4,coalesce(sp.prestige_bias,10)*.25))
    +case
       when v_method in (
         'junior_accelerator','college_accelerator','nextgen_accelerator',
         'junior_accelerator_qualifying','college_accelerator_qualifying',
         'nextgen_accelerator_qualifying','special_exempt','performance_bye'
       ) then 5
       else 0
     end;

  v_score:=v_score+
    (mod(abs(hashtext('weekly-choice|'||p.id::text||'|'||t.id::text)),1000)::numeric/1000.0);

  return round(v_score,3);
end;
$function$
;
