
-- Reproducible Court Boss player-depth runtime foundation.
-- Idempotent checkpoint: AI individual development focus + sparse opponent learning.

alter table public.player_development_profiles
  add column if not exists primary_training_focus text,
  add column if not exists secondary_training_focus text,
  add column if not exists training_focus_intensity integer,
  add column if not exists training_focus_score numeric,
  add column if not exists training_focus_reason text,
  add column if not exists training_focus_review_date date;

create or replace function public.player_attribute_growth_gap(
  p_caps jsonb,
  p_key text,
  p_current integer
)
returns integer
language sql
immutable
set search_path=public
as $$
  select greatest(
    0,
    coalesce(
      case
        when p_caps ? p_key and (p_caps->>p_key) ~ '^[0-9]+$'
          then (p_caps->>p_key)::integer
        else null
      end,
      coalesce(p_current,0)
    ) - coalesce(p_current,0)
  );
$$;

revoke all on function public.player_attribute_growth_gap(jsonb,text,integer)
from public,anon,authenticated;
grant execute on function public.player_attribute_growth_gap(jsonb,text,integer)
to service_role;

create or replace function public.refresh_ai_training_focus(
  p_date date default current_date,
  p_player_id bigint default null
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_date date:=coalesce(p_date,current_date);
  v_updated integer:=0;
begin
  with base as (
    select
      p.id,
      p.age,
      p.height_cm,
      coalesce(p.career_focus,'mixed') as career_focus,
      coalesce(p.style,'') as style,
      dp.development_type,
      dp.peak_age,
      dp.decline_start_age,
      dp.development_rate,
      dp.professionalism,
      dp.coachability,
      dp.discipline,
      dp.competitive_drive,
      dp.injury_proneness,
      dp.technical_environment,
      dp.tactical_environment,
      dp.physical_environment,
      dp.mental_environment,
      dp.preferred_archetype,
      pa.*,
      c.ceilings
    from public.players p
    join public.player_development_profiles dp on dp.player_id=p.id
    join public.player_attributes pa on pa.player_id=p.id
    join public.player_attribute_ceilings c on c.player_id=p.id
    where p.career_status='active'
      and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
      and (
        (p_player_id is not null and p.id=p_player_id)
        or
        (p_player_id is null and dp.last_review_date=v_date)
      )
  ),
  scored as (
    select
      b.id,
      x.focus,
      x.score,
      row_number() over(partition by b.id order by x.score desc,x.focus) as rn
    from base b
    cross join lateral (
      values
      ('Service'::text,
        public.player_attribute_growth_gap(b.ceilings,'serve_power',b.serve_power)
        +public.player_attribute_growth_gap(b.ceilings,'serve_precision',b.serve_precision)
        +public.player_attribute_growth_gap(b.ceilings,'first_serve_quality',b.first_serve_quality)
        +public.player_attribute_growth_gap(b.ceilings,'second_serve_quality',b.second_serve_quality)
        +public.player_attribute_growth_gap(b.ceilings,'serve_variety',b.serve_variety)
        +public.player_attribute_growth_gap(b.ceilings,'serve_plus_one',b.serve_plus_one)
        +case when coalesce(b.height_cm,185)>=195 then 4 when coalesce(b.height_cm,185)<=175 then -2 else 0 end
        +case when lower(b.style) like '%serve%' or lower(coalesce(b.preferred_archetype,'')) like '%serve%' then 7 else 0 end
        +coalesce(b.technical_environment,10)/5
        +case when b.career_focus='doubles_only' then 4 else 0 end
      ),
      ('Retour'::text,
        public.player_attribute_growth_gap(b.ceilings,'return_game',b.return_game)
        +public.player_attribute_growth_gap(b.ceilings,'return_aggression',b.return_aggression)
        +public.player_attribute_growth_gap(b.ceilings,'return_consistency',b.return_consistency)
        +public.player_attribute_growth_gap(b.ceilings,'reaction',b.reaction)
        +public.player_attribute_growth_gap(b.ceilings,'anticipation',b.anticipation)
        +case when lower(b.style) like '%contre%' or lower(coalesce(b.preferred_archetype,'')) like '%counter%' then 7 else 0 end
        +coalesce(b.tactical_environment,10)/5
        +case when b.career_focus='doubles_only' then 3 else 0 end
      ),
      ('Coup droit'::text,
        public.player_attribute_growth_gap(b.ceilings,'forehand',b.forehand)
        +public.player_attribute_growth_gap(b.ceilings,'forehand_power',b.forehand_power)
        +public.player_attribute_growth_gap(b.ceilings,'forehand_accuracy',b.forehand_accuracy)
        +public.player_attribute_growth_gap(b.ceilings,'serve_plus_one',b.serve_plus_one)
        +coalesce(b.technical_environment,10)/5
        +case when lower(b.style) like '%agress%' then 4 else 0 end
      ),
      ('Revers'::text,
        public.player_attribute_growth_gap(b.ceilings,'backhand',b.backhand)
        +public.player_attribute_growth_gap(b.ceilings,'backhand_power',b.backhand_power)
        +public.player_attribute_growth_gap(b.ceilings,'backhand_accuracy',b.backhand_accuracy)
        +public.player_attribute_growth_gap(b.ceilings,'slice',b.slice)
        +public.player_attribute_growth_gap(b.ceilings,'passing_shot',b.passing_shot)
        +coalesce(b.technical_environment,10)/5
      ),
      ('Déplacements'::text,
        public.player_attribute_growth_gap(b.ceilings,'movement',b.movement)
        +public.player_attribute_growth_gap(b.ceilings,'speed',b.speed)
        +public.player_attribute_growth_gap(b.ceilings,'acceleration',b.acceleration)
        +public.player_attribute_growth_gap(b.ceilings,'agility',b.agility)
        +public.player_attribute_growth_gap(b.ceilings,'court_positioning',b.court_positioning)
        +public.player_attribute_growth_gap(b.ceilings,'defense_to_attack',b.defense_to_attack)
        +coalesce(b.physical_environment,10)/5
        +case when b.age<coalesce(b.peak_age,25) then 3 when b.age>=coalesce(b.decline_start_age,30) then -6 else 0 end
      ),
      ('Physique'::text,
        public.player_attribute_growth_gap(b.ceilings,'stamina',b.stamina)
        +public.player_attribute_growth_gap(b.ceilings,'strength',b.strength)
        +public.player_attribute_growth_gap(b.ceilings,'natural_fitness',b.natural_fitness)
        +public.player_attribute_growth_gap(b.ceilings,'recovery',b.recovery)
        +public.player_attribute_growth_gap(b.ceilings,'flexibility',b.flexibility)
        +coalesce(b.physical_environment,10)/5
        +case when coalesce(b.injury_proneness,10)>=14 then 5 else 0 end
        +case when b.age>=coalesce(b.decline_start_age,30) then -5 else 0 end
      ),
      ('Tactique'::text,
        public.player_attribute_growth_gap(b.ceilings,'tactics',b.tactics)
        +public.player_attribute_growth_gap(b.ceilings,'decision_making',b.decision_making)
        +public.player_attribute_growth_gap(b.ceilings,'shot_selection',b.shot_selection)
        +public.player_attribute_growth_gap(b.ceilings,'anticipation',b.anticipation)
        +public.player_attribute_growth_gap(b.ceilings,'court_positioning',b.court_positioning)
        +coalesce(b.tactical_environment,10)/4
        +case when b.age>=coalesce(b.peak_age,25) then 4 else 0 end
      ),
      ('Mental'::text,
        public.player_attribute_growth_gap(b.ceilings,'concentration',b.concentration)
        +public.player_attribute_growth_gap(b.ceilings,'composure',b.composure)
        +public.player_attribute_growth_gap(b.ceilings,'big_points',b.big_points)
        +public.player_attribute_growth_gap(b.ceilings,'consistency',b.consistency)
        +public.player_attribute_growth_gap(b.ceilings,'confidence',b.confidence)
        +public.player_attribute_growth_gap(b.ceilings,'determination',b.determination)
        +coalesce(b.mental_environment,10)/4
        +case when b.age>=coalesce(b.peak_age,25) then 3 else 0 end
      ),
      ('Filet'::text,
        public.player_attribute_growth_gap(b.ceilings,'volley',b.volley)
        +public.player_attribute_growth_gap(b.ceilings,'touch',b.touch)
        +public.player_attribute_growth_gap(b.ceilings,'half_volley',b.half_volley)
        +public.player_attribute_growth_gap(b.ceilings,'smash',b.smash)
        +public.player_attribute_growth_gap(b.ceilings,'net_positioning',b.net_positioning)
        +public.player_attribute_growth_gap(b.ceilings,'transition_game',b.transition_game)
        +case when lower(b.style) like '%all-court%' or lower(b.style) like '%volée%' then 7 else 0 end
        +case when b.career_focus='doubles_only' then 8 else 0 end
      ),
      ('Double'::text,
        public.player_attribute_growth_gap(b.ceilings,'doubles',b.doubles)
        +public.player_attribute_growth_gap(b.ceilings,'doubles_communication',b.doubles_communication)
        +public.player_attribute_growth_gap(b.ceilings,'poaching',b.poaching)
        +public.player_attribute_growth_gap(b.ceilings,'net_positioning',b.net_positioning)
        +public.player_attribute_growth_gap(b.ceilings,'reaction',b.reaction)
        +public.player_attribute_growth_gap(b.ceilings,'volley',b.volley)
        +case when b.career_focus='doubles_only' then 20
              when b.career_focus='singles_only' then -25
              when b.career_focus='singles_priority' then -7
              else 0 end
      )
    ) as x(focus,score)
  ),
  choice as (
    select
      id,
      max(focus) filter(where rn=1) as primary_focus,
      max(score) filter(where rn=1) as primary_score,
      max(focus) filter(where rn=2) as secondary_focus
    from scored
    group by id
  ),
  payload as (
    select
      c.id,
      c.primary_focus,
      c.secondary_focus,
      c.primary_score,
      greatest(1,least(20,round(
        (
          coalesce(dp.professionalism,10)
          +coalesce(dp.discipline,10)
          +coalesce(dp.competitive_drive,10)
          +coalesce(dp.coachability,10)
        )/4.0
      )::integer)) as intensity
    from choice c
    join public.player_development_profiles dp on dp.player_id=c.id
  )
  update public.player_development_profiles dp
  set
    primary_training_focus=x.primary_focus,
    secondary_training_focus=x.secondary_focus,
    training_focus_intensity=x.intensity,
    training_focus_score=x.primary_score,
    training_focus_reason=case x.primary_focus
      when 'Service' then 'Le staff cible la qualité de mise en jeu et le premier coup après service.'
      when 'Retour' then 'Le staff cible la lecture du service adverse et la qualité du premier coup en retour.'
      when 'Coup droit' then 'Le staff cible l’arme principale côté coup droit.'
      when 'Revers' then 'Le staff cible la stabilité et la capacité d’attaque côté revers.'
      when 'Déplacements' then 'Le staff cible couverture de court, explosivité et positionnement.'
      when 'Physique' then 'Le staff cible endurance, récupération et robustesse.'
      when 'Tactique' then 'Le staff cible décision, sélection de coups et lecture du jeu.'
      when 'Mental' then 'Le staff cible constance, pression et points importants.'
      when 'Filet' then 'Le staff cible transition vers l’avant et efficacité au filet.'
      when 'Double' then 'Le staff cible automatismes, interceptions et communication de paire.'
      else 'Plan individualisé selon le profil et les marges de progression.'
    end,
    training_focus_review_date=v_date,
    updated_at=now()
  from payload x
  where dp.player_id=x.id;

  get diagnostics v_updated=row_count;
  return jsonb_build_object('date',v_date,'player_id',p_player_id,'updated',v_updated);
end;
$$;

revoke all on function public.refresh_ai_training_focus(date,bigint)
from public,anon,authenticated;
grant execute on function public.refresh_ai_training_focus(date,bigint)
to service_role;

create or replace function public.apply_ai_training_focus_development(
  p_date date default current_date
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_date date:=coalesce(p_date,current_date);
  v_changed integer:=0;
  v_rows integer:=0;
  v_managed bigint;
begin
  select managed_player_id into v_managed
  from public.career_state
  where id='demo';

  create temporary table if not exists _cb_ai_focus_gain(
    player_id bigint primary key,
    focus text,
    slot integer,
    roll integer,
    chance integer
  ) on commit drop;
  truncate _cb_ai_focus_gain;

  insert into _cb_ai_focus_gain(player_id,focus,slot,roll,chance)
  select
    p.id,
    dp.primary_training_focus,
    mod(abs(hashtext('ai-focus-slot|'||p.id::text||'|'||v_date::text)),2),
    mod(abs(hashtext('ai-focus-roll|'||p.id::text||'|'||v_date::text)),100),
    least(48,greatest(8,
      7
      +round(coalesce(dp.development_rate,10)*.65)::integer
      +round(coalesce(dp.professionalism,10)*.35)::integer
      +round(coalesce(dp.coachability,10)*.35)::integer
      +round(coalesce(dp.training_focus_intensity,10)*.25)::integer
      -round(coalesce(p.fatigue,20)*.08)::integer
    ))
  from public.players p
  join public.player_development_profiles dp on dp.player_id=p.id
  join public.player_attribute_ceilings c on c.player_id=p.id
  where p.career_status='active'
    and p.id is distinct from v_managed
    and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
    and coalesce(p.injury_status,'Fit')='Fit'
    and coalesce(p.fatigue,0)<75
    and dp.last_review_date=v_date
    and dp.training_focus_review_date=v_date
    and dp.primary_training_focus is not null;

  update public.player_attributes pa
  set
    first_serve_quality=case when g.slot=0 then pa.first_serve_quality+1 else pa.first_serve_quality end,
    second_serve_quality=case when g.slot=1 then pa.second_serve_quality+1 else pa.second_serve_quality end
  from _cb_ai_focus_gain g
  join public.player_attribute_ceilings c on c.player_id=g.player_id
  where pa.player_id=g.player_id
    and g.focus='Service'
    and g.roll<g.chance
    and (
      (g.slot=0 and public.player_attribute_growth_gap(c.ceilings,'first_serve_quality',pa.first_serve_quality)>0)
      or
      (g.slot=1 and public.player_attribute_growth_gap(c.ceilings,'second_serve_quality',pa.second_serve_quality)>0)
    );
  get diagnostics v_rows=row_count; v_changed:=v_changed+v_rows;

  update public.player_attributes pa
  set
    return_consistency=case when g.slot=0 then pa.return_consistency+1 else pa.return_consistency end,
    return_aggression=case when g.slot=1 then pa.return_aggression+1 else pa.return_aggression end
  from _cb_ai_focus_gain g
  join public.player_attribute_ceilings c on c.player_id=g.player_id
  where pa.player_id=g.player_id
    and g.focus='Retour'
    and g.roll<g.chance
    and (
      (g.slot=0 and public.player_attribute_growth_gap(c.ceilings,'return_consistency',pa.return_consistency)>0)
      or
      (g.slot=1 and public.player_attribute_growth_gap(c.ceilings,'return_aggression',pa.return_aggression)>0)
    );
  get diagnostics v_rows=row_count; v_changed:=v_changed+v_rows;

  update public.player_attributes pa
  set
    forehand_accuracy=case when g.slot=0 then pa.forehand_accuracy+1 else pa.forehand_accuracy end,
    forehand_power=case when g.slot=1 then pa.forehand_power+1 else pa.forehand_power end
  from _cb_ai_focus_gain g
  join public.player_attribute_ceilings c on c.player_id=g.player_id
  where pa.player_id=g.player_id
    and g.focus='Coup droit'
    and g.roll<g.chance
    and (
      (g.slot=0 and public.player_attribute_growth_gap(c.ceilings,'forehand_accuracy',pa.forehand_accuracy)>0)
      or
      (g.slot=1 and public.player_attribute_growth_gap(c.ceilings,'forehand_power',pa.forehand_power)>0)
    );
  get diagnostics v_rows=row_count; v_changed:=v_changed+v_rows;

  update public.player_attributes pa
  set
    backhand_accuracy=case when g.slot=0 then pa.backhand_accuracy+1 else pa.backhand_accuracy end,
    backhand_power=case when g.slot=1 then pa.backhand_power+1 else pa.backhand_power end
  from _cb_ai_focus_gain g
  join public.player_attribute_ceilings c on c.player_id=g.player_id
  where pa.player_id=g.player_id
    and g.focus='Revers'
    and g.roll<g.chance
    and (
      (g.slot=0 and public.player_attribute_growth_gap(c.ceilings,'backhand_accuracy',pa.backhand_accuracy)>0)
      or
      (g.slot=1 and public.player_attribute_growth_gap(c.ceilings,'backhand_power',pa.backhand_power)>0)
    );
  get diagnostics v_rows=row_count; v_changed:=v_changed+v_rows;

  update public.player_attributes pa
  set
    movement=case when g.slot=0 then pa.movement+1 else pa.movement end,
    acceleration=case when g.slot=1 then pa.acceleration+1 else pa.acceleration end
  from _cb_ai_focus_gain g
  join public.player_attribute_ceilings c on c.player_id=g.player_id
  where pa.player_id=g.player_id
    and g.focus='Déplacements'
    and g.roll<g.chance
    and (
      (g.slot=0 and public.player_attribute_growth_gap(c.ceilings,'movement',pa.movement)>0)
      or
      (g.slot=1 and public.player_attribute_growth_gap(c.ceilings,'acceleration',pa.acceleration)>0)
    );
  get diagnostics v_rows=row_count; v_changed:=v_changed+v_rows;

  update public.player_attributes pa
  set
    stamina=case when g.slot=0 then pa.stamina+1 else pa.stamina end,
    recovery=case when g.slot=1 then pa.recovery+1 else pa.recovery end
  from _cb_ai_focus_gain g
  join public.player_attribute_ceilings c on c.player_id=g.player_id
  where pa.player_id=g.player_id
    and g.focus='Physique'
    and g.roll<g.chance
    and (
      (g.slot=0 and public.player_attribute_growth_gap(c.ceilings,'stamina',pa.stamina)>0)
      or
      (g.slot=1 and public.player_attribute_growth_gap(c.ceilings,'recovery',pa.recovery)>0)
    );
  get diagnostics v_rows=row_count; v_changed:=v_changed+v_rows;

  update public.player_attributes pa
  set
    decision_making=case when g.slot=0 then pa.decision_making+1 else pa.decision_making end,
    shot_selection=case when g.slot=1 then pa.shot_selection+1 else pa.shot_selection end
  from _cb_ai_focus_gain g
  join public.player_attribute_ceilings c on c.player_id=g.player_id
  where pa.player_id=g.player_id
    and g.focus='Tactique'
    and g.roll<g.chance
    and (
      (g.slot=0 and public.player_attribute_growth_gap(c.ceilings,'decision_making',pa.decision_making)>0)
      or
      (g.slot=1 and public.player_attribute_growth_gap(c.ceilings,'shot_selection',pa.shot_selection)>0)
    );
  get diagnostics v_rows=row_count; v_changed:=v_changed+v_rows;

  update public.player_attributes pa
  set
    big_points=case when g.slot=0 then pa.big_points+1 else pa.big_points end,
    consistency=case when g.slot=1 then pa.consistency+1 else pa.consistency end
  from _cb_ai_focus_gain g
  join public.player_attribute_ceilings c on c.player_id=g.player_id
  where pa.player_id=g.player_id
    and g.focus='Mental'
    and g.roll<g.chance
    and (
      (g.slot=0 and public.player_attribute_growth_gap(c.ceilings,'big_points',pa.big_points)>0)
      or
      (g.slot=1 and public.player_attribute_growth_gap(c.ceilings,'consistency',pa.consistency)>0)
    );
  get diagnostics v_rows=row_count; v_changed:=v_changed+v_rows;

  update public.player_attributes pa
  set
    volley=case when g.slot=0 then pa.volley+1 else pa.volley end,
    net_positioning=case when g.slot=1 then pa.net_positioning+1 else pa.net_positioning end
  from _cb_ai_focus_gain g
  join public.player_attribute_ceilings c on c.player_id=g.player_id
  where pa.player_id=g.player_id
    and g.focus='Filet'
    and g.roll<g.chance
    and (
      (g.slot=0 and public.player_attribute_growth_gap(c.ceilings,'volley',pa.volley)>0)
      or
      (g.slot=1 and public.player_attribute_growth_gap(c.ceilings,'net_positioning',pa.net_positioning)>0)
    );
  get diagnostics v_rows=row_count; v_changed:=v_changed+v_rows;

  update public.player_attributes pa
  set
    doubles_communication=case when g.slot=0 then pa.doubles_communication+1 else pa.doubles_communication end,
    poaching=case when g.slot=1 then pa.poaching+1 else pa.poaching end
  from _cb_ai_focus_gain g
  join public.player_attribute_ceilings c on c.player_id=g.player_id
  where pa.player_id=g.player_id
    and g.focus='Double'
    and g.roll<g.chance
    and (
      (g.slot=0 and public.player_attribute_growth_gap(c.ceilings,'doubles_communication',pa.doubles_communication)>0)
      or
      (g.slot=1 and public.player_attribute_growth_gap(c.ceilings,'poaching',pa.poaching)>0)
    );
  get diagnostics v_rows=row_count; v_changed:=v_changed+v_rows;

  return jsonb_build_object(
    'date',v_date,
    'eligible',(select count(*) from _cb_ai_focus_gain),
    'attribute_improvements',v_changed,
    'model','AI individual training focus + attribute ceilings'
  );
end;
$$;

revoke all on function public.apply_ai_training_focus_development(date)
from public,anon,authenticated;
grant execute on function public.apply_ai_training_focus_development(date)
to service_role;

create table if not exists public.player_matchup_learning (
  player_a_id bigint not null,
  player_b_id bigint not null,
  matches_seen integer not null default 0,
  a_wins_snapshot integer not null default 0,
  b_wins_snapshot integer not null default 0,
  familiarity integer not null default 1,
  a_adaptation integer not null default 10,
  b_adaptation integer not null default 10,
  a_problem_solving integer not null default 10,
  b_problem_solving integer not null default 10,
  last_match_date date,
  source_label text not null default 'Court Boss opponent learning v1',
  updated_at timestamptz not null default now(),
  primary key(player_a_id,player_b_id),
  check(player_a_id<player_b_id),
  check(familiarity between 1 and 20),
  check(a_adaptation between 1 and 20),
  check(b_adaptation between 1 and 20),
  check(a_problem_solving between 1 and 20),
  check(b_problem_solving between 1 and 20)
);

alter table public.player_matchup_learning enable row level security;
revoke all on public.player_matchup_learning from public,anon,authenticated;
grant all on public.player_matchup_learning to service_role;

create or replace function public.refresh_matchup_learning_pair(
  p_player_a bigint,
  p_player_b bigint,
  p_date date default current_date
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_a bigint:=least(p_player_a,p_player_b);
  v_b bigint:=greatest(p_player_a,p_player_b);
  h public.player_h2h_records%rowtype;
  aa public.player_attributes%rowtype;
  ab public.player_attributes%rowtype;
  da public.player_development_profiles%rowtype;
  dbb public.player_development_profiles%rowtype;
  v_matches integer:=0;
  v_familiarity integer:=1;
  v_a_skill integer:=10;
  v_b_skill integer:=10;
  v_a_problem integer:=10;
  v_b_problem integer:=10;
begin
  if p_player_a is null or p_player_b is null or p_player_a=p_player_b then
    return jsonb_build_object('updated',false,'reason','invalid_pair');
  end if;

  select * into h
  from public.player_h2h_records
  where player_a_id=v_a and player_b_id=v_b;

  if h.player_a_id is null then
    return jsonb_build_object('updated',false,'reason','no_h2h');
  end if;

  v_matches:=coalesce(h.a_wins,0)+coalesce(h.b_wins,0);

  if v_matches<2 then
    delete from public.player_matchup_learning
    where player_a_id=v_a and player_b_id=v_b;
    return jsonb_build_object('updated',false,'reason','insufficient_meetings','matches',v_matches);
  end if;

  select * into aa from public.player_attributes where player_id=v_a;
  select * into ab from public.player_attributes where player_id=v_b;
  select * into da from public.player_development_profiles where player_id=v_a;
  select * into dbb from public.player_development_profiles where player_id=v_b;

  v_a_skill:=greatest(1,least(20,round((
    coalesce(aa.decision_making,10)
    +coalesce(aa.tactics,10)
    +coalesce(aa.adaptability,10)
    +coalesce(da.coachability,10)
    +coalesce(da.adaptability,10)
    +coalesce(da.tactical_environment,10)
  )/6.0)::integer));

  v_b_skill:=greatest(1,least(20,round((
    coalesce(ab.decision_making,10)
    +coalesce(ab.tactics,10)
    +coalesce(ab.adaptability,10)
    +coalesce(dbb.coachability,10)
    +coalesce(dbb.adaptability,10)
    +coalesce(dbb.tactical_environment,10)
  )/6.0)::integer));

  v_a_problem:=greatest(1,least(20,
    v_a_skill
    +case
      when coalesce(h.a_wins,0)<coalesce(h.b_wins,0)
        then least(3,coalesce(h.b_wins,0)-coalesce(h.a_wins,0))
      else 0
    end
    +case when coalesce(da.important_matches,10)>=15 then 1 else 0 end
  ));

  v_b_problem:=greatest(1,least(20,
    v_b_skill
    +case
      when coalesce(h.b_wins,0)<coalesce(h.a_wins,0)
        then least(3,coalesce(h.a_wins,0)-coalesce(h.b_wins,0))
      else 0
    end
    +case when coalesce(dbb.important_matches,10)>=15 then 1 else 0 end
  ));

  v_familiarity:=greatest(1,least(20,
    3
    +v_matches*2
    +least(3,coalesce(h.real_matches,0)/3)
  ));

  insert into public.player_matchup_learning(
    player_a_id,player_b_id,matches_seen,a_wins_snapshot,b_wins_snapshot,
    familiarity,a_adaptation,b_adaptation,a_problem_solving,b_problem_solving,
    last_match_date,updated_at
  )
  values(
    v_a,v_b,v_matches,coalesce(h.a_wins,0),coalesce(h.b_wins,0),
    v_familiarity,v_a_skill,v_b_skill,v_a_problem,v_b_problem,
    coalesce(h.last_match_date,p_date),now()
  )
  on conflict(player_a_id,player_b_id) do update set
    matches_seen=excluded.matches_seen,
    a_wins_snapshot=excluded.a_wins_snapshot,
    b_wins_snapshot=excluded.b_wins_snapshot,
    familiarity=excluded.familiarity,
    a_adaptation=excluded.a_adaptation,
    b_adaptation=excluded.b_adaptation,
    a_problem_solving=excluded.a_problem_solving,
    b_problem_solving=excluded.b_problem_solving,
    last_match_date=excluded.last_match_date,
    updated_at=now();

  return jsonb_build_object(
    'updated',true,
    'player_a_id',v_a,
    'player_b_id',v_b,
    'matches',v_matches,
    'familiarity',v_familiarity,
    'a_adaptation',v_a_skill,
    'b_adaptation',v_b_skill,
    'a_problem_solving',v_a_problem,
    'b_problem_solving',v_b_problem
  );
end;
$$;

revoke all on function public.refresh_matchup_learning_pair(bigint,bigint,date)
from public,anon,authenticated;
grant execute on function public.refresh_matchup_learning_pair(bigint,bigint,date)
to service_role;

create or replace function public.update_matchup_learning_after_h2h()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
  if coalesce(new.a_wins,0)+coalesce(new.b_wins,0)>=2 then
    perform public.refresh_matchup_learning_pair(
      new.player_a_id,new.player_b_id,coalesce(new.last_match_date,current_date)
    );
  end if;
  return new;
end;
$$;

revoke all on function public.update_matchup_learning_after_h2h()
from public,anon,authenticated;
grant execute on function public.update_matchup_learning_after_h2h()
to service_role;

drop trigger if exists trg_player_h2h_matchup_learning
on public.player_h2h_records;

create trigger trg_player_h2h_matchup_learning
after insert or update of a_wins,b_wins,recent_a_wins,recent_b_wins,last_match_date,last_winner_id
on public.player_h2h_records
for each row
execute function public.update_matchup_learning_after_h2h();

do $$
begin
  if not exists(select 1 from public.player_matchup_learning limit 1) then
    perform public.refresh_matchup_learning_pair(
      h.player_a_id,h.player_b_id,coalesce(h.last_match_date,current_date)
    )
    from public.player_h2h_records h
    where coalesce(h.a_wins,0)+coalesce(h.b_wins,0)>=2;
  end if;
end;
$$;

do $$
begin
  if to_regprocedure(
    'public.player_matchup_probability_v2_core(bigint,bigint,text,date,numeric,integer)'
  ) is null
  and to_regprocedure(
    'public.player_matchup_probability_v2(bigint,bigint,text,date,numeric,integer)'
  ) is not null
  then
    execute
      'alter function public.player_matchup_probability_v2(bigint,bigint,text,date,numeric,integer) rename to player_matchup_probability_v2_core';
  end if;
end;
$$;

create or replace function public.player_matchup_probability_v2(
  p_a bigint,
  p_b bigint,
  p_surface text default 'Hard',
  p_date date default current_date,
  p_court_speed numeric default null,
  p_best_of integer default 3
)
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  base jsonb;
  learning public.player_matchup_learning%rowtype;
  p0 numeric;
  lg numeric;
  fp numeric;
  v_matches integer:=0;
  a_adapt integer:=10;
  b_adapt integer:=10;
  a_problem integer:=10;
  b_problem integer:=10;
  a_wins integer:=0;
  b_wins integer:=0;
  familiarity integer:=1;
  learning_fit numeric:=0;
  comeback_fit numeric:=0;
  total_fit numeric:=0;
begin
  base:=public.player_matchup_probability_v2_core(
    p_a,p_b,p_surface,p_date,p_court_speed,p_best_of
  );

  if base->>'error' is not null then
    return base;
  end if;

  select * into learning
  from public.player_matchup_learning
  where player_a_id=least(p_a,p_b)
    and player_b_id=greatest(p_a,p_b);

  if learning.player_a_id is null then
    return base || jsonb_build_object(
      'opponent_learning',
      jsonb_build_object(
        'active',false,
        'matches',0,
        'familiarity',1,
        'adjustment',0
      )
    );
  end if;

  v_matches:=learning.matches_seen;
  familiarity:=learning.familiarity;

  if p_a=learning.player_a_id then
    a_adapt:=learning.a_adaptation;
    b_adapt:=learning.b_adaptation;
    a_problem:=learning.a_problem_solving;
    b_problem:=learning.b_problem_solving;
    a_wins:=learning.a_wins_snapshot;
    b_wins:=learning.b_wins_snapshot;
  else
    a_adapt:=learning.b_adaptation;
    b_adapt:=learning.a_adaptation;
    a_problem:=learning.b_problem_solving;
    b_problem:=learning.a_problem_solving;
    a_wins:=learning.b_wins_snapshot;
    b_wins:=learning.a_wins_snapshot;
  end if;

  learning_fit:=greatest(-.075,least(.075,
    ((a_adapt-b_adapt)/20.0)
    *least(.075,v_matches*.006)
    *(familiarity/20.0)
  ));

  if v_matches>0 and a_wins<b_wins then
    comeback_fit:=least(.035,
      ((b_wins-a_wins)::numeric/v_matches)
      *.035
      *(a_problem/20.0)
      *(familiarity/20.0)
    );
  elsif v_matches>0 and b_wins<a_wins then
    comeback_fit:=-least(.035,
      ((a_wins-b_wins)::numeric/v_matches)
      *.035
      *(b_problem/20.0)
      *(familiarity/20.0)
    );
  end if;

  total_fit:=greatest(-.10,least(.10,learning_fit+comeback_fit));

  p0:=coalesce((base->>'player_a_probability')::numeric,.5);
  lg:=ln(greatest(.01,least(.99,p0))/greatest(.01,1-least(.99,p0)));
  fp:=greatest(.035,least(.965,1/(1+exp(-(lg+total_fit)))));

  return base || jsonb_build_object(
    'player_a_probability',round(fp,4),
    'player_b_probability',round(1-fp,4),
    'opponent_learning',jsonb_build_object(
      'active',true,
      'matches',v_matches,
      'familiarity',familiarity,
      'player_a_adaptation',a_adapt,
      'player_b_adaptation',b_adapt,
      'player_a_problem_solving',a_problem,
      'player_b_problem_solving',b_problem,
      'learning_fit',round(learning_fit,4),
      'comeback_learning',round(comeback_fit,4),
      'adjustment',round(total_fit,4)
    )
  );
end;
$$;

revoke all on function public.player_matchup_probability_v2(
  bigint,bigint,text,date,numeric,integer
) from public,anon,authenticated;

grant execute on function public.player_matchup_probability_v2(
  bigint,bigint,text,date,numeric,integer
) to service_role;

revoke all on function public.player_matchup_probability_v2_core(
  bigint,bigint,text,date,numeric,integer
) from public,anon,authenticated;

grant execute on function public.player_matchup_probability_v2_core(
  bigint,bigint,text,date,numeric,integer
) to service_role;
