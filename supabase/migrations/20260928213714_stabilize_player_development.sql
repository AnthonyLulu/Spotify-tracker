-- One development review per calendar month, with ages at the career date.
-- Internal simulation state; never exposed to anon/authenticated Data API clients.
create table if not exists public.player_development_cycles (
  review_month date primary key,
  reviewed_on date not null,
  result jsonb not null default '{}'::jsonb
);
alter table public.player_development_cycles enable row level security;
revoke all on public.player_development_cycles from public,anon,authenticated;
grant all on public.player_development_cycles to service_role;

create or replace function public.player_age_on_date(p_birth date,p_age integer,p_snapshot date,p_date date)
returns integer language sql immutable set search_path=public as $$
  select greatest(0,case when p_birth is not null then extract(year from age(p_date,p_birth))::integer
    else coalesce(p_age,24)+extract(year from p_date)::integer-extract(year from coalesce(p_snapshot,date '2025-12-01'))::integer-case when to_char(p_date,'MMDD')<to_char(coalesce(p_snapshot,date '2025-12-01'),'MMDD') then 1 else 0 end end);
$$;
revoke all on function public.player_age_on_date(date,integer,date,date) from public,anon,authenticated;
grant execute on function public.player_age_on_date(date,integer,date,date) to service_role;

create or replace function public.refresh_player_simulation_ages(p_date date)
returns integer language plpgsql set search_path=public as $$
declare v_count integer;
begin
  update public.players p set
    age=public.player_age_on_date(p.birth_date,p.age,p.age_snapshot_date,p_date),
    age_snapshot_date=p_date
  where p.career_status='active'
    and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
    and (p.age is distinct from public.player_age_on_date(p.birth_date,p.age,p.age_snapshot_date,p_date));
  get diagnostics v_count=row_count;
  update public.career_state c set age=p.age from public.players p
    where c.id='demo' and p.id=c.managed_player_id and c.age is distinct from p.age;
  return v_count;
end;
$$;
revoke all on function public.refresh_player_simulation_ages(date) from public,anon,authenticated;
grant execute on function public.refresh_player_simulation_ages(date) to service_role;

CREATE OR REPLACE FUNCTION public.progress_player_development_world(p_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_date date:=coalesce(p_date,current_date);
  v_month int:=extract(month from v_date)::int;
  v_year int:=extract(year from v_date)::int;
  v_cohort int:=mod(v_month-1,3);
  v_changed int:=0;
  v_type_changes int:=0;
  v_attr_changed int:=0;
  v_hidden jsonb;
  v_result jsonb;
  v_claimed integer;
begin
  if v_date<=date '2025-12-01' then
    return jsonb_build_object('date',v_date,'processed',0,'historical_cutoff',true);
  end if;

  insert into public.player_development_cycles(review_month,reviewed_on)
    values(date_trunc('month',v_date)::date,v_date) on conflict do nothing;
  get diagnostics v_claimed=row_count;
  if v_claimed=0 then
    return jsonb_build_object('date',v_date,'processed',0,'already_reviewed',true);
  end if;
  perform public.refresh_player_simulation_ages(v_date);
  perform public.refresh_player_coaching_environment(v_date);

  create temporary table if not exists _cb_dev_changes(
    player_id bigint primary key,
    old_ca int,new_ca int,old_pa int,new_pa int,
    old_type text,new_type text,reason text
  ) on commit drop;
  truncate _cb_dev_changes;

  insert into _cb_dev_changes(player_id,old_ca,new_ca,old_pa,new_pa,old_type,new_type,reason)
  select
    p.id,p.current_ability,
    greatest(25,least(100,
      p.current_ability+
      case
        when p.age<dp.peak_age
             and coalesce(p.injury_status,'Fit')='Fit' and coalesce(p.fatigue,0)<75
             and p.current_ability<p.potential
             and mod(abs(hashtext('ca|'||p.id::text||'|'||v_year::text||'|'||v_month::text)),100)
                 < least(42,4+round(dp.development_rate*.80)+round(dp.professionalism*.35)+round(dp.coachability*.35)+round(pa.work_rate*.25)
                         +case when p.form>=82 then 4 when p.form>=75 then 2 else 0 end
                         +case when p.morale>=82 then 3 when p.morale>=74 then 1 else 0 end)
          then case
            when p.current_ability+2<=p.potential
                 and dp.development_rate>=16
                 and mod(abs(hashtext('ca2|'||p.id::text||'|'||v_year::text||'|'||v_month::text)),100)<7
              then 2 else 1 end
        when p.age between dp.peak_age and dp.decline_start_age
             and coalesce(p.injury_status,'Fit')='Fit' and coalesce(p.fatigue,0)<75
             and p.current_ability<p.potential
             and mod(abs(hashtext('peakca|'||p.id::text||'|'||v_year::text||'|'||v_month::text)),100)
                 < 2+round(dp.professionalism*.30)+round(dp.coachability*.20)
          then 1
        when p.age>dp.decline_start_age
             and mod(abs(hashtext('declca|'||p.id::text||'|'||v_year::text||'|'||v_month::text)),100)
                 < greatest(4,8+(p.age-dp.decline_start_age)*2-round(pa.natural_fitness*.30)-round(dp.resilience*.20))
          then -1
        else 0
      end
    )),
    p.potential,
    greatest(p.current_ability,least(100,
      p.potential+
      case
        when p.age<=23 and p.form>=82 and p.morale>=75 and dp.professionalism>=14
             and mod(abs(hashtext('pa-up|'||p.id::text||'|'||v_year::text||'|'||v_month::text)),100)
                 < 1+greatest(1,round(dp.potential_volatility/6.0))
          then 1
        when p.age>dp.peak_age+2 and p.potential>p.current_ability+7
             and mod(abs(hashtext('pa-down|'||p.id::text||'|'||v_year::text||'|'||v_month::text)),100)
                 < 3+greatest(0,10-dp.professionalism)/2
          then -1
        else 0
      end
    )),
    dp.development_type,
    case
      when dp.development_type='early' and p.age>=dp.peak_age
           and p.potential-p.current_ability>=9 and dp.coachability>=13 then 'standard'
      when dp.development_type='standard' and p.age>=25
           and p.potential-p.current_ability>=11 and dp.professionalism>=12 and dp.resilience>=12 then 'late'
      when dp.development_type='late' and p.age<=24
           and p.potential-p.current_ability<=3 and p.current_ability>=76 then 'standard'
      when dp.development_type='standard' and p.age<=20
           and p.potential-p.current_ability<=2 and p.current_ability>=80 then 'early'
      else dp.development_type
    end,
    case
      when p.age>dp.decline_start_age then 'Courbe physique et âge'
      when p.injury_status<>'Fit' then 'Blessure et disponibilité'
      when p.form>=82 then 'Forme et progression sportive'
      else 'Développement de cohorte'
    end
  from players p
  join player_development_profiles dp on dp.player_id=p.id
  join player_attributes pa on pa.player_id=p.id
  where p.career_status='active'
    and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
    and mod(abs(hashtext(p.id::text)),3)=v_cohort
    and (
      p.ranking_current=true
      or p.game_generated=true
      or p.itf_ranking is not null
      or p.junior_ranking is not null
      or p.ncaa_current=true
      or p.doubles_ranking is not null
    )
    and coalesce(dp.last_review_date,date '2025-12-01')<date_trunc('month',v_date)::date;

  update players p
  set current_ability=c.new_ca,
      potential=greatest(c.new_ca,c.new_pa)
  from _cb_dev_changes c
  where p.id=c.player_id
    and (p.current_ability<>c.new_ca or p.potential<>greatest(c.new_ca,c.new_pa));
  get diagnostics v_changed=row_count;

  update player_development_profiles dp
  set development_type=c.new_type,
      peak_age=case c.new_type
        when 'early' then greatest(22,least(dp.peak_age,26))
        when 'late' then greatest(dp.peak_age,27)
        else greatest(23,least(27,dp.peak_age))
      end,
      decline_start_age=case c.new_type
        when 'early' then greatest(28,dp.decline_start_age)
        when 'late' then greatest(31,dp.decline_start_age)
        else greatest(29,dp.decline_start_age)
      end,
      potential_floor=greatest(c.new_ca,least(dp.potential_floor,greatest(c.new_ca,c.new_pa))),
      potential_ceiling=greatest(greatest(c.new_ca,c.new_pa),least(100,
        dp.potential_ceiling+
        case when c.new_pa>c.old_pa then 1 when c.new_pa<c.old_pa and dp.potential_ceiling>c.new_pa+4 then -1 else 0 end
      )),
      potential_momentum=greatest(-10,least(10,
        dp.potential_momentum+
        case when c.new_ca>c.old_ca then 1 when c.new_ca<c.old_ca then -1 else 0 end+
        case when c.new_pa>c.old_pa then 1 when c.new_pa<c.old_pa then -1 else 0 end
      )),
      last_type_change=case when c.new_type<>c.old_type then v_date else dp.last_type_change end,
      last_review_date=v_date,
      updated_at=now()
  from _cb_dev_changes c
  where dp.player_id=c.player_id;

  select count(*)::int into v_type_changes
  from _cb_dev_changes where new_type<>old_type;

  insert into player_development_history(
    player_id,event_date,event_type,old_current_ability,new_current_ability,
    old_potential,new_potential,old_development_type,new_development_type,reason
  )
  select
    c.player_id,v_date,
    case when c.new_type<>c.old_type then 'development_type_change'
         when c.new_pa<>c.old_pa then 'potential_change'
         else 'ability_change' end,
    c.old_ca,c.new_ca,c.old_pa,greatest(c.new_ca,c.new_pa),c.old_type,c.new_type,c.reason
  from _cb_dev_changes c
  where c.old_ca<>c.new_ca or c.old_pa<>greatest(c.new_ca,c.new_pa) or c.old_type<>c.new_type;

  -- Young players improve technique/decision making; older players lose explosiveness first,
  -- while tactics, anticipation and serve variation can still improve with experience.
  update player_attributes pa
  set
    decision_making=greatest(1,least(20,pa.decision_making+
      case when c.new_ca>c.old_ca and mod(abs(hashtext('dec|'||pa.player_id::text||'|'||v_year::text||'|'||v_month::text)),100)<34 then 1
           when p.age between 27 and 34 and mod(abs(hashtext('dec-age|'||pa.player_id::text||'|'||v_year::text)),100)<12 then 1 else 0 end)),
    shot_selection=greatest(1,least(20,pa.shot_selection+
      case when c.new_ca>c.old_ca and mod(abs(hashtext('shot|'||pa.player_id::text||'|'||v_year::text||'|'||v_month::text)),100)<30 then 1
           when p.age between 27 and 34 and mod(abs(hashtext('shot-age|'||pa.player_id::text||'|'||v_year::text)),100)<10 then 1 else 0 end)),
    consistency=greatest(1,least(20,pa.consistency+
      case when c.new_ca>c.old_ca and mod(abs(hashtext('consdev|'||pa.player_id::text||'|'||v_year::text||'|'||v_month::text)),100)<26 then 1 else 0 end)),
    big_points=greatest(1,least(20,pa.big_points+
      case when c.new_ca>c.old_ca and dp.pressure>=14
                and mod(abs(hashtext('bigdev|'||pa.player_id::text||'|'||v_year::text||'|'||v_month::text)),100)<18 then 1 else 0 end)),
    first_serve_quality=greatest(1,least(20,pa.first_serve_quality+
      case when c.new_ca>c.old_ca and p.age<=27
                and mod(abs(hashtext('srv1dev|'||pa.player_id::text||'|'||v_year::text||'|'||v_month::text)),100)<20 then 1 else 0 end)),
    second_serve_quality=greatest(1,least(20,pa.second_serve_quality+
      case when c.new_ca>c.old_ca and mod(abs(hashtext('srv2dev|'||pa.player_id::text||'|'||v_year::text||'|'||v_month::text)),100)<18 then 1 else 0 end)),
    forehand_accuracy=greatest(1,least(20,pa.forehand_accuracy+
      case when c.new_ca>c.old_ca and p.age<=26
                and mod(abs(hashtext('fhaccdev|'||pa.player_id::text||'|'||v_year::text||'|'||v_month::text)),100)<22 then 1 else 0 end)),
    backhand_accuracy=greatest(1,least(20,pa.backhand_accuracy+
      case when c.new_ca>c.old_ca and p.age<=26
                and mod(abs(hashtext('bhaccdev|'||pa.player_id::text||'|'||v_year::text||'|'||v_month::text)),100)<22 then 1 else 0 end)),
    serve_variety=greatest(1,least(20,pa.serve_variety+
      case when p.age between 25 and 34
                and mod(abs(hashtext('srvvar|'||pa.player_id::text||'|'||v_year::text)),100)<12 then 1 else 0 end)),
    tactics=greatest(1,least(20,pa.tactics+
      case when p.age between 24 and 34
                and mod(abs(hashtext('tactage|'||pa.player_id::text||'|'||v_year::text)),100)<13 then 1
           when c.new_ca>c.old_ca and mod(abs(hashtext('tactdev|'||pa.player_id::text||'|'||v_year::text)),100)<15 then 1 else 0 end)),
    anticipation=greatest(1,least(20,pa.anticipation+
      case when p.age between 24 and 34
                and mod(abs(hashtext('antage|'||pa.player_id::text||'|'||v_year::text)),100)<12 then 1 else 0 end)),
    speed=greatest(1,least(20,pa.speed-
      case when p.age>dp.decline_start_age and mod(abs(hashtext('spddecl|'||pa.player_id::text||'|'||v_year::text||'|'||v_month::text)),100)
                < greatest(8,20+p.age-dp.decline_start_age-pa.natural_fitness/2) then 1 else 0 end)),
    acceleration=greatest(1,least(20,pa.acceleration-
      case when p.age>dp.decline_start_age and mod(abs(hashtext('accdecl|'||pa.player_id::text||'|'||v_year::text||'|'||v_month::text)),100)
                < greatest(8,22+p.age-dp.decline_start_age-pa.natural_fitness/2) then 1 else 0 end)),
    agility=greatest(1,least(20,pa.agility-
      case when p.age>dp.decline_start_age and mod(abs(hashtext('agidecl|'||pa.player_id::text||'|'||v_year::text||'|'||v_month::text)),100)
                < greatest(7,18+p.age-dp.decline_start_age-pa.flexibility/3) then 1 else 0 end)),
    stamina=greatest(1,least(20,pa.stamina-
      case when p.age>dp.decline_start_age+1 and mod(abs(hashtext('stadecl|'||pa.player_id::text||'|'||v_year::text||'|'||v_month::text)),100)
                < greatest(5,14+p.age-dp.decline_start_age-pa.recovery/3) then 1 else 0 end)),
    recovery=greatest(1,least(20,pa.recovery-
      case when p.age>dp.decline_start_age and mod(abs(hashtext('recdecl|'||pa.player_id::text||'|'||v_year::text||'|'||v_month::text)),100)
                < greatest(5,12+p.age-dp.decline_start_age) then 1 else 0 end))
  from _cb_dev_changes c
  join players p on p.id=c.player_id
  join player_development_profiles dp on dp.player_id=c.player_id
  where pa.player_id=c.player_id;

  get diagnostics v_attr_changed=row_count;

  perform public.apply_player_coaching_development(v_date);
  perform public.apply_coaching_development_effects(v_date);
  v_hidden:=public.apply_player_hidden_development_events(v_date);
  perform public.refresh_player_personality_profiles(v_date);
  perform public.refresh_player_archetypes(v_date);
  perform public.refresh_player_tactical_preferences(v_date);
  perform public.refresh_player_tactical_traits(v_date);
  perform public.refresh_player_star_ratings(v_date);

  v_result:=jsonb_build_object(
    'date',v_date,
    'cohort',v_cohort,
    'processed',(select count(*) from _cb_dev_changes),
    'ability_or_potential_changed',v_changed,
    'development_type_changes',v_type_changes,
    'attribute_profiles_updated',v_attr_changed,
    'hidden_potential',v_hidden,
    'monthly_cohort_engine',true
  );
  update public.player_development_cycles set result=v_result where review_month=date_trunc('month',v_date)::date;
  update public.career_state c set current_ability=p.current_ability,potential=p.potential,age=p.age
    from public.players p where c.id='demo' and p.id=c.managed_player_id;
  return v_result;
end;
$function$

;
CREATE OR REPLACE FUNCTION public.simulate_world_week(p_week integer, p_snapshot_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  affected_count int;
  leader_name text;
  leader_rank int;
begin
  if p_snapshot_date<=date '2025-12-01' then
    return jsonb_build_object('updated_players',0,'historical_cutoff',true);
  end if;
  perform public.refresh_player_simulation_ages(p_snapshot_date);
  update players
  set
    age = case
      when birth_date is not null then extract(year from age(p_snapshot_date,birth_date))::int
      else age
    end,
    form = greatest(35, least(99, form + (((id + p_week * 7) % 7)::int - 3))),
    fatigue = greatest(0, least(95, fatigue + (((id * 3 + p_week * 5) % 9)::int - 4))),
    morale = greatest(35, least(99, morale + (((id * 5 + p_week * 11) % 7)::int - 3))),
    points = greatest(0,
      points +
      case
        when career_focus='doubles_only' then -greatest(1,ceil(points*.012)::int)
        when ranking <= 20 then (((id * 13 + p_week * 17) % 81)::int - 35)
        when ranking <= 100 then (((id * 11 + p_week * 13) % 51)::int - 22)
        when ranking <= 500 then (((id * 7 + p_week * 11) % 25)::int - 10)
        else (((id * 5 + p_week * 7) % 11)::int - 4)
      end
    ),
    ranking_source = case
      when career_focus='doubles_only' then 'Court Boss simulation · double exclusif'
      else 'Court Boss simulation'
    end
  where ranking_current = true;

  get diagnostics affected_count = row_count;

  with ranked as (
    select id,
           row_number() over(
             order by points desc, current_ability desc, form desc, id
           )::int as new_rank
    from players
    where ranking_current = true
  )
  update players p
  set ranking = r.new_rank
  from ranked r
  where p.id = r.id;

  insert into ranking_history(player_id,snapshot_date,ranking,points)
  select id,p_snapshot_date,ranking,points
  from players
  where ranking_current = true
    and not exists (
      select 1 from ranking_history h
      where h.player_id=players.id and h.snapshot_date=p_snapshot_date
    );

  select name,ranking into leader_name,leader_rank
  from players
  where ranking_current=true
  order by ranking
  limit 1;

  return jsonb_build_object(
    'updated_players',affected_count,
    'leader',leader_name,
    'leader_rank',leader_rank,
    'snapshot_date',p_snapshot_date
  );
end;
$function$

;

revoke all on function public.progress_player_development_world(date) from public,anon,authenticated;
grant execute on function public.progress_player_development_world(date) to service_role;
revoke all on function public.simulate_world_week(integer,date) from public,anon,authenticated;
grant execute on function public.simulate_world_week(integer,date) to service_role;
-- Correct the imported age against the current career without advancing that career.
select public.refresh_player_simulation_ages((select career_date from public.career_state where id='demo'));

CREATE OR REPLACE FUNCTION public.apply_player_coaching_development(p_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_date date:=coalesce(p_date,current_date);
  v_year int:=extract(year from v_date)::int;
  v_month int:=extract(month from v_date)::int;
  v_ca_up int:=0;
  v_attr_up int:=0;
begin
  create temporary table if not exists _cb_coach_dev(
    player_id bigint primary key,
    staff_profile_id bigint,
    coach_quality numeric,
    role_fit int,
    satisfaction int,
    old_ca int,
    old_pa int,
    gain_ca int,
    specialty text
  ) on commit drop;
  truncate _cb_coach_dev;

  insert into _cb_coach_dev(
    player_id,staff_profile_id,coach_quality,role_fit,satisfaction,old_ca,old_pa,gain_ca,specialty
  )
  select
    p.id,
    x.staff_profile_id,
    x.quality,
    x.role_fit,
    x.satisfaction,
    p.current_ability,
    p.potential,
    case
      when p.current_ability>=p.potential or p.age>dp.decline_start_age then 0
      when mod(abs(hashtext('coach-break|'||p.id::text||'|'||v_year::text||'|'||v_month::text)),100)
        < least(18,greatest(0,round(
            (x.quality-10)*1.10
           +(x.role_fit-65)*.08
           +(x.satisfaction-65)*.06
           +(dp.coachability-10)*.55
           +(dp.professionalism-10)*.20
          )::int))
      then 1 else 0
    end,
    x.specialty
  from players p
  join player_development_profiles dp on dp.player_id=p.id and dp.last_review_date=v_date
  join lateral (
    select
      psa.staff_profile_id,
      greatest(1,least(20,
        (
          sp.coach_rating*.22+
          sp.technical_rating*.18+
          sp.tactical_rating*.18+
          sp.mental_rating*.12+
          sp.development_rating*.15+
          sp.communication_rating*.08+
          sp.professionalism*.07
        )*coalesce(public.staff_effectiveness_multiplier(sp.id),1)
      )) as quality,
      coalesce(psa.role_fit,70)::int as role_fit,
      coalesce(psa.satisfaction,70)::int as satisfaction,
      case
        when sp.technical_rating>=greatest(sp.tactical_rating,sp.mental_rating,sp.fitness_rating) then 'technique'
        when sp.tactical_rating>=greatest(sp.technical_rating,sp.mental_rating,sp.fitness_rating) then 'tactique'
        when sp.mental_rating>=greatest(sp.technical_rating,sp.tactical_rating,sp.fitness_rating) then 'mental'
        else 'physique'
      end as specialty
    from player_staff_assignments psa
    join staff_profiles sp on sp.id=psa.staff_profile_id
    where psa.player_id=p.id
      and psa.active=true
      and public.staff_role_group(sp.primary_role)='coach'
    order by
      (
        sp.coach_rating*.22+
        sp.technical_rating*.18+
        sp.tactical_rating*.18+
        sp.mental_rating*.12+
        sp.development_rating*.15+
        sp.communication_rating*.08+
        sp.professionalism*.07
      )*coalesce(public.staff_effectiveness_multiplier(sp.id),1) desc,
      coalesce(psa.role_fit,70) desc,
      psa.id
    limit 1
  ) x on true
  where p.career_status='active'
    and coalesce(p.injury_status,'Fit')='Fit' and coalesce(p.fatigue,0)<75
    and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %';

  update players p
  set current_ability=least(p.potential,p.current_ability+c.gain_ca)
  from _cb_coach_dev c
  where p.id=c.player_id and c.gain_ca>0;
  get diagnostics v_ca_up=row_count;

  update player_development_profiles dp
  set potential_momentum=least(10,dp.potential_momentum+
        case
          when c.gain_ca>0 then .75
          when c.coach_quality>=16 and c.role_fit>=80 then .15
          else 0
        end),
      updated_at=now()
  from _cb_coach_dev c
  where dp.player_id=c.player_id;

  -- Coach specialty can improve one detailed skill without automatically raising CA.
  update player_attributes pa
  set
    forehand_accuracy=least(20,pa.forehand_accuracy+
      case when c.specialty='technique'
                 and mod(abs(hashtext('coach-fh|'||pa.player_id::text||'|'||v_year::text||'|'||v_month::text)),100)
                     < greatest(0,round((c.coach_quality-11)*2.0)::int)
           then 1 else 0 end),
    backhand_accuracy=least(20,pa.backhand_accuracy+
      case when c.specialty='technique'
                 and mod(abs(hashtext('coach-bh|'||pa.player_id::text||'|'||v_year::text||'|'||v_month::text)),100)
                     < greatest(0,round((c.coach_quality-11)*1.7)::int)
           then 1 else 0 end),
    decision_making=least(20,pa.decision_making+
      case when c.specialty='tactique'
                 and mod(abs(hashtext('coach-dec|'||pa.player_id::text||'|'||v_year::text||'|'||v_month::text)),100)
                     < greatest(0,round((c.coach_quality-11)*2.0)::int)
           then 1 else 0 end),
    shot_selection=least(20,pa.shot_selection+
      case when c.specialty='tactique'
                 and mod(abs(hashtext('coach-shot|'||pa.player_id::text||'|'||v_year::text||'|'||v_month::text)),100)
                     < greatest(0,round((c.coach_quality-11)*1.7)::int)
           then 1 else 0 end),
    big_points=least(20,pa.big_points+
      case when c.specialty='mental'
                 and mod(abs(hashtext('coach-big|'||pa.player_id::text||'|'||v_year::text||'|'||v_month::text)),100)
                     < greatest(0,round((c.coach_quality-11)*1.8)::int)
           then 1 else 0 end),
    confidence=least(20,pa.confidence+
      case when c.specialty='mental'
                 and mod(abs(hashtext('coach-conf|'||pa.player_id::text||'|'||v_year::text||'|'||v_month::text)),100)
                     < greatest(0,round((c.coach_quality-11)*1.6)::int)
           then 1 else 0 end),
    recovery=least(20,pa.recovery+
      case when c.specialty='physique'
                 and mod(abs(hashtext('coach-rec|'||pa.player_id::text||'|'||v_year::text||'|'||v_month::text)),100)
                     < greatest(0,round((c.coach_quality-11)*1.6)::int)
           then 1 else 0 end),
    balance=least(20,pa.balance+
      case when c.specialty='physique'
                 and mod(abs(hashtext('coach-bal|'||pa.player_id::text||'|'||v_year::text||'|'||v_month::text)),100)
                     < greatest(0,round((c.coach_quality-11)*1.5)::int)
           then 1 else 0 end)
  from _cb_coach_dev c
  where pa.player_id=c.player_id
    and c.coach_quality>=13
    and c.role_fit>=65
    and c.satisfaction>=55;

  get diagnostics v_attr_up=row_count;

  insert into player_development_history(
    player_id,event_date,event_type,
    old_current_ability,new_current_ability,
    old_potential,new_potential,
    old_development_type,new_development_type,
    reason,source_label
  )
  select
    c.player_id,v_date,'coaching_breakthrough',
    c.old_ca,least(c.old_pa,c.old_ca+c.gain_ca),
    c.old_pa,c.old_pa,
    dp.development_type,dp.development_type,
    'Progression accélérée par un coach de haut niveau compatible avec le joueur.',
    'Court Boss staff-development engine'
  from _cb_coach_dev c
  join player_development_profiles dp on dp.player_id=c.player_id
  where c.gain_ca>0;

  return jsonb_build_object(
    'date',v_date,
    'players_with_active_coach',(select count(*) from _cb_coach_dev),
    'ca_breakthroughs',v_ca_up,
    'attribute_profiles_touched',v_attr_up,
    'model','coach quality + effectiveness + fit + satisfaction + coachability'
  );
end;
$function$

;
revoke all on function public.apply_player_coaching_development(date) from public,anon,authenticated;
grant execute on function public.apply_player_coaching_development(date) to service_role;

CREATE OR REPLACE FUNCTION public.apply_coaching_development_effects(p_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_date date:=coalesce(p_date,current_date);
  v_year int:=extract(year from v_date)::int;
  v_month int:=extract(month from v_date)::int;
  v_ca_boost int:=0;
  v_pa_boost int:=0;
  v_attr_rows int:=0;
begin
  create temporary table if not exists _cb_staff_boost(
    player_id bigint primary key,
    old_ca integer,
    new_ca integer,
    old_pa integer,
    new_pa integer,
    category integer
  ) on commit drop;
  truncate _cb_staff_boost;

  insert into _cb_staff_boost(player_id,old_ca,new_ca,old_pa,new_pa,category)
  select
    p.id,
    p.current_ability,
    least(p.potential,
      p.current_ability+
      case
        when p.age<dp.peak_age
         and p.current_ability<p.potential
         and dp.coaching_environment>=15
         and dp.coachability>=14
         and dp.staff_stability>=10
         and mod(abs(hashtext('staff-ca|'||p.id::text||'|'||v_year||'|'||v_month)),100)
             < least(20,(dp.coaching_environment-13)*2+(dp.coachability-12))
        then 1 else 0 end
    ),
    p.potential,
    least(100,
      p.potential+
      case
        when p.age<=22
         and dp.coaching_environment>=17
         and dp.coachability>=16
         and dp.professionalism>=14
         and p.current_ability>=p.potential-2
         and mod(abs(hashtext('staff-pa|'||p.id::text||'|'||v_year||'|'||v_month)),100)<6
        then 1 else 0 end
    ),
    mod(abs(hashtext('staff-cat|'||p.id::text||'|'||v_year||'|'||v_month)),4)
  from players p
  join player_development_profiles dp on dp.player_id=p.id
  where p.career_status='active'
    and coalesce(p.injury_status,'Fit')='Fit' and coalesce(p.fatigue,0)<75
    and dp.last_review_date=v_date
    and (
      dp.coaching_environment>=14
      or dp.technical_environment>=15
      or dp.tactical_environment>=15
      or dp.physical_environment>=15
      or dp.mental_environment>=15
    );

  update players p
  set
    current_ability=b.new_ca,
    potential=greatest(b.new_ca,b.new_pa)
  from _cb_staff_boost b
  where p.id=b.player_id
    and (b.new_ca<>b.old_ca or b.new_pa<>b.old_pa);

  select count(*) into v_ca_boost from _cb_staff_boost where new_ca>old_ca;
  select count(*) into v_pa_boost from _cb_staff_boost where new_pa>old_pa;

  insert into player_development_history(
    player_id,event_date,event_type,old_current_ability,new_current_ability,
    old_potential,new_potential,old_development_type,new_development_type,reason,source_label
  )
  select
    b.player_id,v_date,
    case when b.new_pa>b.old_pa then 'staff_unlocked_potential' else 'staff_development_boost' end,
    b.old_ca,b.new_ca,b.old_pa,greatest(b.new_ca,b.new_pa),
    dp.development_type,dp.development_type,
    case
      when b.new_pa>b.old_pa then 'Le staff et la capacité d’apprentissage ont relevé le plafond estimé.'
      else 'Progression accélérée par la qualité et la stabilité du staff.'
    end,
    'Court Boss staff development engine'
  from _cb_staff_boost b
  join player_development_profiles dp on dp.player_id=b.player_id
  where b.new_ca<>b.old_ca or b.new_pa<>b.old_pa;

  update player_attributes pa
  set
    first_serve_quality=least(20,pa.first_serve_quality+
      case when b.category=0 and dp.technical_environment>=15
        and mod(abs(hashtext('st-srv|'||pa.player_id::text||'|'||v_year||'|'||v_month)),100)<18
      then 1 else 0 end),
    forehand_accuracy=least(20,pa.forehand_accuracy+
      case when b.category=0 and dp.technical_environment>=15
        and mod(abs(hashtext('st-fh|'||pa.player_id::text||'|'||v_year||'|'||v_month)),100)<16
      then 1 else 0 end),
    backhand_accuracy=least(20,pa.backhand_accuracy+
      case when b.category=0 and dp.technical_environment>=15
        and mod(abs(hashtext('st-bh|'||pa.player_id::text||'|'||v_year||'|'||v_month)),100)<16
      then 1 else 0 end),
    decision_making=least(20,pa.decision_making+
      case when b.category=1 and dp.tactical_environment>=15
        and mod(abs(hashtext('st-dec|'||pa.player_id::text||'|'||v_year||'|'||v_month)),100)<18
      then 1 else 0 end),
    shot_selection=least(20,pa.shot_selection+
      case when b.category=1 and dp.tactical_environment>=15
        and mod(abs(hashtext('st-shot|'||pa.player_id::text||'|'||v_year||'|'||v_month)),100)<16
      then 1 else 0 end),
    recovery=least(20,pa.recovery+
      case when b.category=2 and dp.physical_environment>=15 and pa.recovery<18
        and mod(abs(hashtext('st-rec|'||pa.player_id::text||'|'||v_year||'|'||v_month)),100)<15
      then 1 else 0 end),
    stamina=least(20,pa.stamina+
      case when b.category=2 and dp.physical_environment>=15
        and mod(abs(hashtext('st-sta|'||pa.player_id::text||'|'||v_year||'|'||v_month)),100)<15
      then 1 else 0 end),
    composure=least(20,pa.composure+
      case when b.category=3 and dp.mental_environment>=15
        and mod(abs(hashtext('st-comp|'||pa.player_id::text||'|'||v_year||'|'||v_month)),100)<16
      then 1 else 0 end),
    big_points=least(20,pa.big_points+
      case when b.category=3 and dp.mental_environment>=16 and dp.pressure>=12
        and mod(abs(hashtext('st-big|'||pa.player_id::text||'|'||v_year||'|'||v_month)),100)<12
      then 1 else 0 end)
  from _cb_staff_boost b
  join player_development_profiles dp on dp.player_id=b.player_id
  where pa.player_id=b.player_id;

  get diagnostics v_attr_rows=row_count;

  return jsonb_build_object(
    'date',v_date,
    'ca_boosts',v_ca_boost,
    'potential_unlocked',v_pa_boost,
    'attribute_profiles_touched',v_attr_rows
  );
end;
$function$

;
revoke all on function public.apply_coaching_development_effects(date) from public,anon,authenticated;
grant execute on function public.apply_coaching_development_effects(date) to service_role;
