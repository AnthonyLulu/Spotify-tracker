
create or replace function public.tm26_extend_attribute_ceilings(
  p_player_id bigint,
  p_ceilings jsonb
)
returns jsonb
language sql
stable
security definer
set search_path=public
as $$
  with b as (
    select
      p.id,p.age,p.current_ability,p.potential,p.career_focus,
      dp.development_type,dp.peak_age,dp.decline_start_age,
      dp.coachability,dp.competitive_drive,
      pa.*
    from public.players p
    join public.player_development_profiles dp on dp.player_id=p.id
    join public.player_attributes pa on pa.player_id=p.id
    where p.id=p_player_id
  ),
  scored as (
    select
      v.key,
      v.current_value,
      greatest(
        v.current_value,
        least(
          20,
          v.current_value+
          case
            when v.key='athleticism' and b.age>=coalesce(b.decline_start_age,30) then 0
            when v.key='footwork' and b.age>=coalesce(b.decline_start_age,30)+1 then 0
            else greatest(
              0,
              floor(greatest(0,b.potential-b.current_ability)/v.divisor)::integer
              +case
                when b.development_type='late'
                  and v.key in (
                    'serve_consistency','forehand_consistency','backhand_consistency',
                    'counter_skill','shot_control','timing','tenacity'
                  ) then 1
                when b.development_type='early'
                  and b.age<=coalesce(b.peak_age,25)
                  and v.key in (
                    'serve_spin','serve_consistency','forehand_consistency',
                    'backhand_consistency','footwork','athleticism'
                  ) then 1
                else 0
              end
              +case
                when coalesce(b.coachability,10)>=16
                  and v.key in (
                    'serve_consistency','forehand_consistency','backhand_consistency',
                    'counter_skill','shot_control','timing'
                  ) then 1
                else 0
              end
              +case
                when coalesce(b.competitive_drive,10)>=16 and v.key='tenacity' then 1
                else 0
              end
              +case
                when b.career_focus='doubles_only'
                  and v.key in ('serve_consistency','timing','footwork') then 1
                else 0
              end
              +case
                when coalesce(b.clay_affinity,10)>=15 and v.key='topspin' then 1
                else 0
              end
              +(mod(abs(hashtext('tm26-cap|'||b.id::text||'|'||v.key)),4)-1)
            )
          end
        )
      )::integer as cap_value
    from b
    cross join lateral (
      values
        ('serve_spin',b.serve_spin,6.2::numeric),
        ('serve_consistency',b.serve_consistency,5.8::numeric),
        ('forehand_consistency',b.forehand_consistency,5.8::numeric),
        ('backhand_consistency',b.backhand_consistency,5.8::numeric),
        ('counter_skill',b.counter_skill,5.5::numeric),
        ('topspin',b.topspin,6.5::numeric),
        ('shot_control',b.shot_control,5.5::numeric),
        ('timing',b.timing,5.2::numeric),
        ('footwork',b.footwork,7.8::numeric),
        ('athleticism',b.athleticism,8.5::numeric),
        ('tenacity',b.tenacity,6.0::numeric)
    ) as v(key,current_value,divisor)
    where v.current_value is not null
  )
  select coalesce(p_ceilings,'{}'::jsonb)
    ||coalesce(
      (select jsonb_object_agg(key,cap_value) from scored),
      '{}'::jsonb
    );
$$;

revoke all on function public.tm26_extend_attribute_ceilings(bigint,jsonb)
from public,anon,authenticated;
grant execute on function public.tm26_extend_attribute_ceilings(bigint,jsonb)
to service_role;

create or replace function public.extend_tm26_attribute_ceilings_trigger()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
  new.ceilings:=public.tm26_extend_attribute_ceilings(new.player_id,new.ceilings);
  return new;
end;
$$;

revoke all on function public.extend_tm26_attribute_ceilings_trigger()
from public,anon,authenticated;
grant execute on function public.extend_tm26_attribute_ceilings_trigger()
to service_role;

drop trigger if exists trg_extend_tm26_attribute_ceilings
on public.player_attribute_ceilings;

create trigger trg_extend_tm26_attribute_ceilings
before insert or update of ceilings
on public.player_attribute_ceilings
for each row
execute function public.extend_tm26_attribute_ceilings_trigger();

update public.player_attribute_ceilings c
set ceilings=public.tm26_extend_attribute_ceilings(c.player_id,c.ceilings),
    updated_at=now()
where not (c.ceilings ? 'serve_spin')
   or not (c.ceilings ? 'serve_consistency')
   or not (c.ceilings ? 'forehand_consistency')
   or not (c.ceilings ? 'backhand_consistency')
   or not (c.ceilings ? 'counter_skill')
   or not (c.ceilings ? 'topspin')
   or not (c.ceilings ? 'shot_control')
   or not (c.ceilings ? 'timing')
   or not (c.ceilings ? 'footwork')
   or not (c.ceilings ? 'athleticism')
   or not (c.ceilings ? 'tenacity');

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
  v_managed bigint;
begin
  select managed_player_id into v_managed
  from public.career_state
  where id='demo';

  create temporary table if not exists _cb_ai_focus_gain(
    player_id bigint primary key,
    focus text,
    attribute_key text,
    current_value integer,
    roll integer,
    chance integer
  ) on commit drop;
  truncate _cb_ai_focus_gain;

  insert into _cb_ai_focus_gain(
    player_id,focus,attribute_key,current_value,roll,chance
  )
  with candidates as (
    select
      p.id as player_id,
      dp.primary_training_focus as focus,
      x.attribute_key,
      x.current_value,
      row_number() over(partition by p.id order by x.attribute_key) as rn,
      count(*) over(partition by p.id) as candidate_count,
      mod(abs(hashtext('ai-focus-roll|'||p.id::text||'|'||v_date::text)),100) as roll,
      least(48,greatest(8,
        7
        +round(coalesce(dp.development_rate,10)*.65)::integer
        +round(coalesce(dp.professionalism,10)*.35)::integer
        +round(coalesce(dp.coachability,10)*.35)::integer
        +round(coalesce(dp.training_focus_intensity,10)*.25)::integer
        -round(coalesce(p.fatigue,20)*.08)::integer
      )) as chance
    from public.players p
    join public.player_development_profiles dp on dp.player_id=p.id
    join public.player_attributes pa on pa.player_id=p.id
    join public.player_attribute_ceilings c on c.player_id=p.id
    cross join lateral (
      values
        ('Service','first_serve_quality',pa.first_serve_quality),
        ('Service','second_serve_quality',pa.second_serve_quality),
        ('Service','serve_spin',pa.serve_spin),
        ('Service','serve_consistency',pa.serve_consistency),
        ('Service','timing',pa.timing),

        ('Retour','return_consistency',pa.return_consistency),
        ('Retour','return_aggression',pa.return_aggression),
        ('Retour','counter_skill',pa.counter_skill),
        ('Retour','timing',pa.timing),
        ('Retour','shot_control',pa.shot_control),

        ('Coup droit','forehand_accuracy',pa.forehand_accuracy),
        ('Coup droit','forehand_power',pa.forehand_power),
        ('Coup droit','forehand_consistency',pa.forehand_consistency),
        ('Coup droit','topspin',pa.topspin),
        ('Coup droit','shot_control',pa.shot_control),
        ('Coup droit','timing',pa.timing),

        ('Revers','backhand_accuracy',pa.backhand_accuracy),
        ('Revers','backhand_power',pa.backhand_power),
        ('Revers','backhand_consistency',pa.backhand_consistency),
        ('Revers','shot_control',pa.shot_control),
        ('Revers','timing',pa.timing),

        ('Déplacements','movement',pa.movement),
        ('Déplacements','acceleration',pa.acceleration),
        ('Déplacements','footwork',pa.footwork),
        ('Déplacements','athleticism',pa.athleticism),

        ('Physique','stamina',pa.stamina),
        ('Physique','recovery',pa.recovery),
        ('Physique','athleticism',pa.athleticism),
        ('Physique','tenacity',pa.tenacity),

        ('Tactique','decision_making',pa.decision_making),
        ('Tactique','shot_selection',pa.shot_selection),
        ('Tactique','shot_control',pa.shot_control),
        ('Tactique','timing',pa.timing),
        ('Tactique','counter_skill',pa.counter_skill),

        ('Mental','big_points',pa.big_points),
        ('Mental','consistency',pa.consistency),
        ('Mental','tenacity',pa.tenacity),

        ('Filet','volley',pa.volley),
        ('Filet','net_positioning',pa.net_positioning),
        ('Filet','timing',pa.timing),
        ('Filet','footwork',pa.footwork),

        ('Double','doubles_communication',pa.doubles_communication),
        ('Double','poaching',pa.poaching),
        ('Double','footwork',pa.footwork),
        ('Double','serve_consistency',pa.serve_consistency),
        ('Double','timing',pa.timing)
    ) as x(focus,attribute_key,current_value)
    where p.career_status='active'
      and p.id is distinct from v_managed
      and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
      and coalesce(p.injury_status,'Fit')='Fit'
      and coalesce(p.fatigue,0)<75
      and dp.last_review_date=v_date
      and dp.training_focus_review_date=v_date
      and dp.primary_training_focus=x.focus
      and x.current_value is not null
  ),
  chosen as (
    select *
    from candidates
    where rn=1+mod(
      abs(hashtext('ai-focus-slot|'||player_id::text||'|'||v_date::text)),
      candidate_count::integer
    )
  )
  select player_id,focus,attribute_key,current_value,roll,chance
  from chosen;

  update public.player_attributes pa
  set
    first_serve_quality=case when g.attribute_key='first_serve_quality' then pa.first_serve_quality+1 else pa.first_serve_quality end,
    second_serve_quality=case when g.attribute_key='second_serve_quality' then pa.second_serve_quality+1 else pa.second_serve_quality end,
    serve_spin=case when g.attribute_key='serve_spin' then pa.serve_spin+1 else pa.serve_spin end,
    serve_consistency=case when g.attribute_key='serve_consistency' then pa.serve_consistency+1 else pa.serve_consistency end,
    return_consistency=case when g.attribute_key='return_consistency' then pa.return_consistency+1 else pa.return_consistency end,
    return_aggression=case when g.attribute_key='return_aggression' then pa.return_aggression+1 else pa.return_aggression end,
    counter_skill=case when g.attribute_key='counter_skill' then pa.counter_skill+1 else pa.counter_skill end,
    forehand_accuracy=case when g.attribute_key='forehand_accuracy' then pa.forehand_accuracy+1 else pa.forehand_accuracy end,
    forehand_power=case when g.attribute_key='forehand_power' then pa.forehand_power+1 else pa.forehand_power end,
    forehand_consistency=case when g.attribute_key='forehand_consistency' then pa.forehand_consistency+1 else pa.forehand_consistency end,
    topspin=case when g.attribute_key='topspin' then pa.topspin+1 else pa.topspin end,
    backhand_accuracy=case when g.attribute_key='backhand_accuracy' then pa.backhand_accuracy+1 else pa.backhand_accuracy end,
    backhand_power=case when g.attribute_key='backhand_power' then pa.backhand_power+1 else pa.backhand_power end,
    backhand_consistency=case when g.attribute_key='backhand_consistency' then pa.backhand_consistency+1 else pa.backhand_consistency end,
    movement=case when g.attribute_key='movement' then pa.movement+1 else pa.movement end,
    acceleration=case when g.attribute_key='acceleration' then pa.acceleration+1 else pa.acceleration end,
    footwork=case when g.attribute_key='footwork' then pa.footwork+1 else pa.footwork end,
    athleticism=case when g.attribute_key='athleticism' then pa.athleticism+1 else pa.athleticism end,
    stamina=case when g.attribute_key='stamina' then pa.stamina+1 else pa.stamina end,
    recovery=case when g.attribute_key='recovery' then pa.recovery+1 else pa.recovery end,
    tenacity=case when g.attribute_key='tenacity' then pa.tenacity+1 else pa.tenacity end,
    decision_making=case when g.attribute_key='decision_making' then pa.decision_making+1 else pa.decision_making end,
    shot_selection=case when g.attribute_key='shot_selection' then pa.shot_selection+1 else pa.shot_selection end,
    shot_control=case when g.attribute_key='shot_control' then pa.shot_control+1 else pa.shot_control end,
    timing=case when g.attribute_key='timing' then pa.timing+1 else pa.timing end,
    big_points=case when g.attribute_key='big_points' then pa.big_points+1 else pa.big_points end,
    consistency=case when g.attribute_key='consistency' then pa.consistency+1 else pa.consistency end,
    volley=case when g.attribute_key='volley' then pa.volley+1 else pa.volley end,
    net_positioning=case when g.attribute_key='net_positioning' then pa.net_positioning+1 else pa.net_positioning end,
    doubles_communication=case when g.attribute_key='doubles_communication' then pa.doubles_communication+1 else pa.doubles_communication end,
    poaching=case when g.attribute_key='poaching' then pa.poaching+1 else pa.poaching end
  from _cb_ai_focus_gain g
  join public.player_attribute_ceilings c on c.player_id=g.player_id
  where pa.player_id=g.player_id
    and g.roll<g.chance
    and public.player_attribute_growth_gap(
      c.ceilings,g.attribute_key,g.current_value
    )>0;

  get diagnostics v_changed=row_count;

  return jsonb_build_object(
    'date',v_date,
    'eligible',(select count(*) from _cb_ai_focus_gain),
    'attribute_improvements',v_changed,
    'model','AI individual training focus + 74-attribute ceilings'
  );
end;
$$;

revoke all on function public.apply_ai_training_focus_development(date)
from public,anon,authenticated;
grant execute on function public.apply_ai_training_focus_development(date)
to service_role;
