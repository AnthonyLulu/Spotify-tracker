create table if not exists public.player_ai_training_cycles (
  review_month date primary key,
  trained_on date not null,
  result jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
alter table public.player_ai_training_cycles enable row level security;
revoke all on table public.player_ai_training_cycles from public, anon, authenticated;
grant select, insert, update on table public.player_ai_training_cycles to service_role;

create or replace function public.apply_player_ai_training(p_date date default current_date)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_date date:=coalesce(p_date,current_date);
  v_month date:=date_trunc('month',coalesce(p_date,current_date))::date;
  v_claimed int:=0;
  v_updated int:=0;
  v_double int:=0;
  v_serve int:=0;
  v_attack int:=0;
  v_counter int:=0;
  v_defender int:=0;
  v_allcourt int:=0;
  v_balanced int:=0;
  v_result jsonb;
begin
  if v_date<=date '2025-12-01' then
    return jsonb_build_object('date',v_date,'updated',0,'historical_cutoff',true);
  end if;

  insert into public.player_ai_training_cycles(review_month,trained_on)
  values(v_month,v_date) on conflict do nothing;
  get diagnostics v_claimed=row_count;
  if v_claimed=0 then
    select result into v_result from public.player_ai_training_cycles where review_month=v_month;
    return coalesce(v_result,'{}'::jsonb)||jsonb_build_object('date',v_date,'already_reviewed',true);
  end if;

  with candidates as (
    select
      p.id,
      case
        when p.career_focus='doubles_only' or dp.preferred_archetype='Spécialiste double' then 'double'
        when dp.preferred_archetype in ('Serveur-attaquant','Serveur-volée') then 'serve'
        when dp.preferred_archetype='Attaquant fond de court' then 'attack'
        when dp.preferred_archetype='Contreur' then 'counter'
        when dp.preferred_archetype='Défenseur de fond' then 'defender'
        when dp.preferred_archetype='All-court' then 'allcourt'
        else 'balanced'
      end axis,
      pac.ceilings
    from public.players p
    join public.player_development_profiles dp on dp.player_id=p.id
    join public.player_attribute_ceilings pac on pac.player_id=p.id
    where p.career_status='active'
      and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
      and dp.last_review_date=v_date
      and p.current_ability<p.potential
      and p.age<=dp.decline_start_age
      and coalesce(p.injury_status,'Fit')='Fit'
      and coalesce(p.fatigue,0)<75
      and mod(abs(hashtext('ai-train|'||p.id||'|'||v_month)),100)
          < least(28,6+round(dp.development_rate*.55)+round(dp.professionalism*.28)+round(dp.coachability*.25)+round(dp.coaching_environment*.18))
  ),
  changed as (
    select c.*,pa.*
    from candidates c
    join public.player_attributes pa on pa.player_id=c.id
    where
      (c.axis='double' and (
        pa.doubles<coalesce((c.ceilings->>'doubles')::int,20) or
        pa.net_positioning<coalesce((c.ceilings->>'net_positioning')::int,20) or
        pa.doubles_communication<coalesce((c.ceilings->>'doubles_communication')::int,20) or
        pa.poaching<coalesce((c.ceilings->>'poaching')::int,20)
      ))
      or (c.axis='serve' and (
        pa.serve_power<coalesce((c.ceilings->>'serve_power')::int,20) or
        pa.first_serve_quality<coalesce((c.ceilings->>'first_serve_quality')::int,20) or
        pa.serve_plus_one<coalesce((c.ceilings->>'serve_plus_one')::int,20) or
        pa.serve_variety<coalesce((c.ceilings->>'serve_variety')::int,20)
      ))
      or (c.axis='attack' and (
        pa.forehand_power<coalesce((c.ceilings->>'forehand_power')::int,20) or
        pa.aggression<coalesce((c.ceilings->>'aggression')::int,20) or
        pa.killer_instinct<coalesce((c.ceilings->>'killer_instinct')::int,20) or
        pa.serve_plus_one<coalesce((c.ceilings->>'serve_plus_one')::int,20)
      ))
      or (c.axis='counter' and (
        pa.return_game<coalesce((c.ceilings->>'return_game')::int,20) or
        pa.return_consistency<coalesce((c.ceilings->>'return_consistency')::int,20) or
        pa.reaction<coalesce((c.ceilings->>'reaction')::int,20) or
        pa.passing_shot<coalesce((c.ceilings->>'passing_shot')::int,20)
      ))
      or (c.axis='defender' and (
        pa.movement<coalesce((c.ceilings->>'movement')::int,20) or
        pa.defensive_skill<coalesce((c.ceilings->>'defensive_skill')::int,20) or
        pa.rally_tolerance<coalesce((c.ceilings->>'rally_tolerance')::int,20) or
        pa.court_positioning<coalesce((c.ceilings->>'court_positioning')::int,20)
      ))
      or (c.axis='allcourt' and (
        pa.volley<coalesce((c.ceilings->>'volley')::int,20) or
        pa.touch<coalesce((c.ceilings->>'touch')::int,20) or
        pa.transition_game<coalesce((c.ceilings->>'transition_game')::int,20) or
        pa.decision_making<coalesce((c.ceilings->>'decision_making')::int,20)
      ))
      or (c.axis='balanced' and (
        pa.shot_selection<coalesce((c.ceilings->>'shot_selection')::int,20) or
        pa.consistency<coalesce((c.ceilings->>'consistency')::int,20) or
        pa.backhand_accuracy<coalesce((c.ceilings->>'backhand_accuracy')::int,20) or
        pa.forehand_accuracy<coalesce((c.ceilings->>'forehand_accuracy')::int,20)
      ))
  ),
  upd as (
    update public.player_attributes pa
    set
      doubles=case when c.axis='double' then least(coalesce((c.ceilings->>'doubles')::int,20),pa.doubles+1) else pa.doubles end,
      net_positioning=case when c.axis='double' then least(coalesce((c.ceilings->>'net_positioning')::int,20),pa.net_positioning+1) else pa.net_positioning end,
      doubles_communication=case when c.axis='double' then least(coalesce((c.ceilings->>'doubles_communication')::int,20),pa.doubles_communication+1) else pa.doubles_communication end,
      poaching=case when c.axis='double' then least(coalesce((c.ceilings->>'poaching')::int,20),pa.poaching+1) else pa.poaching end,

      serve_power=case when c.axis='serve' then least(coalesce((c.ceilings->>'serve_power')::int,20),pa.serve_power+1) else pa.serve_power end,
      first_serve_quality=case when c.axis='serve' then least(coalesce((c.ceilings->>'first_serve_quality')::int,20),pa.first_serve_quality+1) else pa.first_serve_quality end,
      serve_plus_one=case when c.axis in ('serve','attack') then least(coalesce((c.ceilings->>'serve_plus_one')::int,20),pa.serve_plus_one+1) else pa.serve_plus_one end,
      serve_variety=case when c.axis='serve' then least(coalesce((c.ceilings->>'serve_variety')::int,20),pa.serve_variety+1) else pa.serve_variety end,

      forehand_power=case when c.axis='attack' then least(coalesce((c.ceilings->>'forehand_power')::int,20),pa.forehand_power+1) else pa.forehand_power end,
      aggression=case when c.axis='attack' then least(coalesce((c.ceilings->>'aggression')::int,20),pa.aggression+1) else pa.aggression end,
      killer_instinct=case when c.axis='attack' then least(coalesce((c.ceilings->>'killer_instinct')::int,20),pa.killer_instinct+1) else pa.killer_instinct end,

      return_game=case when c.axis='counter' then least(coalesce((c.ceilings->>'return_game')::int,20),pa.return_game+1) else pa.return_game end,
      return_consistency=case when c.axis='counter' then least(coalesce((c.ceilings->>'return_consistency')::int,20),pa.return_consistency+1) else pa.return_consistency end,
      reaction=case when c.axis='counter' then least(coalesce((c.ceilings->>'reaction')::int,20),pa.reaction+1) else pa.reaction end,
      passing_shot=case when c.axis='counter' then least(coalesce((c.ceilings->>'passing_shot')::int,20),pa.passing_shot+1) else pa.passing_shot end,

      movement=case when c.axis='defender' then least(coalesce((c.ceilings->>'movement')::int,20),pa.movement+1) else pa.movement end,
      defensive_skill=case when c.axis='defender' then least(coalesce((c.ceilings->>'defensive_skill')::int,20),pa.defensive_skill+1) else pa.defensive_skill end,
      rally_tolerance=case when c.axis='defender' then least(coalesce((c.ceilings->>'rally_tolerance')::int,20),pa.rally_tolerance+1) else pa.rally_tolerance end,
      court_positioning=case when c.axis='defender' then least(coalesce((c.ceilings->>'court_positioning')::int,20),pa.court_positioning+1) else pa.court_positioning end,

      volley=case when c.axis='allcourt' then least(coalesce((c.ceilings->>'volley')::int,20),pa.volley+1) else pa.volley end,
      touch=case when c.axis='allcourt' then least(coalesce((c.ceilings->>'touch')::int,20),pa.touch+1) else pa.touch end,
      transition_game=case when c.axis='allcourt' then least(coalesce((c.ceilings->>'transition_game')::int,20),pa.transition_game+1) else pa.transition_game end,
      decision_making=case when c.axis='allcourt' then least(coalesce((c.ceilings->>'decision_making')::int,20),pa.decision_making+1) else pa.decision_making end,

      shot_selection=case when c.axis='balanced' then least(coalesce((c.ceilings->>'shot_selection')::int,20),pa.shot_selection+1) else pa.shot_selection end,
      consistency=case when c.axis='balanced' then least(coalesce((c.ceilings->>'consistency')::int,20),pa.consistency+1) else pa.consistency end,
      backhand_accuracy=case when c.axis='balanced' then least(coalesce((c.ceilings->>'backhand_accuracy')::int,20),pa.backhand_accuracy+1) else pa.backhand_accuracy end,
      forehand_accuracy=case when c.axis='balanced' then least(coalesce((c.ceilings->>'forehand_accuracy')::int,20),pa.forehand_accuracy+1) else pa.forehand_accuracy end
    from changed c
    where pa.player_id=c.id
    returning c.axis
  )
  select count(*)::int,
         count(*) filter(where axis='double')::int,
         count(*) filter(where axis='serve')::int,
         count(*) filter(where axis='attack')::int,
         count(*) filter(where axis='counter')::int,
         count(*) filter(where axis='defender')::int,
         count(*) filter(where axis='allcourt')::int,
         count(*) filter(where axis='balanced')::int
  into v_updated,v_double,v_serve,v_attack,v_counter,v_defender,v_allcourt,v_balanced
  from upd;

  v_result:=jsonb_build_object(
    'date',v_date,'review_month',v_month,'updated',coalesce(v_updated,0),
    'double',coalesce(v_double,0),'serve',coalesce(v_serve,0),'attack',coalesce(v_attack,0),
    'counter',coalesce(v_counter,0),'defender',coalesce(v_defender,0),
    'allcourt',coalesce(v_allcourt,0),'balanced',coalesce(v_balanced,0),
    'model','archetype-ai-training-v1'
  );
  update public.player_ai_training_cycles set result=v_result where review_month=v_month;
  return v_result;
end;
$$;

revoke all on function public.apply_player_ai_training(date) from public, anon, authenticated;
grant execute on function public.apply_player_ai_training(date) to service_role;
