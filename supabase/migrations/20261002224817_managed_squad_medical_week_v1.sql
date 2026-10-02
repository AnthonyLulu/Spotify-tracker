-- Player-scoped weekly medical processing for the managed squad.

CREATE OR REPLACE FUNCTION public.apply_managed_medical_week(p_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_player_id bigint;
begin
  select managed_player_id into v_player_id
  from public.career_state where id='demo';
  if v_player_id is null then raise exception 'Managed player missing'; end if;
  return public.apply_managed_medical_week(p_date,v_player_id);
end
$function$;

CREATE OR REPLACE FUNCTION public.apply_managed_medical_week(p_date date, p_player_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  c public.career_state%rowtype;
  mp public.player_medical_plans%rowtype;
  legacy public.medical_plan%rowtype;
  inj public.injuries%rowtype;
  p public.players%rowtype;
  primary_id bigint;
  fatigue_delta int:=0;
  fitness_delta int:=0;
  morale_delta int:=0;
  risk_delta int:=0;
  return_days int:=0;
  cost numeric:=0;
  recovered boolean:=false;
  best_medical numeric:=10;
  best_fitness numeric:=10;
  best_nutrition numeric:=10;
  medical_bonus int:=0;
  fitness_bonus int:=0;
  nutrition_bonus int:=0;
begin
  select * into c from public.career_state where id='demo';
  if not found then raise exception 'Career not found'; end if;
  primary_id:=c.managed_player_id;

  if p_player_id is null then
    p_player_id:=primary_id;
  end if;

  select * into p from public.players where id=p_player_id;
  if not found then raise exception 'Player % not found',p_player_id; end if;

  if p_player_id<>primary_id and not exists(
    select 1 from public.academy_roster
    where player_id=p_player_id and status='active'
  ) then
    raise exception 'Player % is not in managed squad',p_player_id;
  end if;

  select * into mp from public.player_medical_plans where player_id=p_player_id;
  if not found then
    if p_player_id=primary_id then
      select * into legacy from public.medical_plan where id='demo';
      insert into public.player_medical_plans(player_id,protocol,physio_hours,weekly_cost,notes)
      values(
        p_player_id,
        coalesce(legacy.protocol,'Récupération active'),
        coalesce(legacy.physio_hours,2),
        coalesce(legacy.weekly_cost,250),
        coalesce(legacy.notes,'Suivi médical du joueur géré')
      )
      on conflict(player_id) do update set updated_at=now()
      returning * into mp;
    else
      insert into public.player_medical_plans(player_id,protocol,physio_hours,weekly_cost,notes)
      values(p_player_id,'Récupération active',2,250,'Suivi médical du groupe géré')
      on conflict(player_id) do update set updated_at=now()
      returning * into mp;
    end if;
  end if;

  select
    coalesce(max(sp.medical_rating*coalesce(public.staff_effectiveness_multiplier(sp.id),1)),10),
    coalesce(max(sp.fitness_rating*coalesce(public.staff_effectiveness_multiplier(sp.id),1)),10),
    coalesce(max(
      case when sp.primary_role ilike '%Nutrition%'
        then greatest(sp.fitness_rating,sp.professionalism,sp.communication_rating)
             *coalesce(public.staff_effectiveness_multiplier(sp.id),1)
        else null end
    ),10)
  into best_medical,best_fitness,best_nutrition
  from public.staff s
  left join public.staff_profiles sp on sp.id=s.profile_id;

  medical_bonus:=greatest(0,floor((best_medical-10)/3.0)::int);
  fitness_bonus:=greatest(0,floor((best_fitness-10)/4.0)::int);
  nutrition_bonus:=greatest(0,floor((best_nutrition-10)/4.0)::int);
  cost:=coalesce(mp.weekly_cost,0);

  select * into inj
  from public.injuries
  where player_id=p_player_id and lower(coalesce(status,''))='active'
  order by started_at desc,id desc
  limit 1;

  case mp.protocol
    when 'Repos complet' then
      fatigue_delta:=-14; fitness_delta:=4; morale_delta:=-1; risk_delta:=-10; return_days:=3;
    when 'Physio intensive' then
      fatigue_delta:=-10; fitness_delta:=5; morale_delta:=1; risk_delta:=-14; return_days:=4;
    when 'Récupération active' then
      fatigue_delta:=-8; fitness_delta:=4; morale_delta:=1; risk_delta:=-7; return_days:=2;
    when 'Maintien de forme' then
      fatigue_delta:=-3; fitness_delta:=2; morale_delta:=1; risk_delta:=3; return_days:=0;
    else
      fatigue_delta:=-6; fitness_delta:=3; risk_delta:=-5; return_days:=1;
  end case;

  fatigue_delta:=fatigue_delta-nutrition_bonus;
  fitness_delta:=fitness_delta+fitness_bonus+case when nutrition_bonus>=2 then 1 else 0 end;
  morale_delta:=morale_delta+case when best_nutrition>=17 then 1 else 0 end;
  if risk_delta<0 then risk_delta:=risk_delta-medical_bonus; end if;
  if inj.id is not null then return_days:=return_days+medical_bonus; end if;

  update public.players
  set fatigue=greatest(0,least(100,coalesce(fatigue,0)+fatigue_delta)),
      fitness=greatest(0,least(100,coalesce(fitness,90)+fitness_delta)),
      morale=greatest(0,least(100,coalesce(morale,70)+morale_delta))
  where id=p_player_id;

  update public.career_state
  set budget=budget-cost,
      fatigue=case when p_player_id=primary_id then greatest(0,least(100,fatigue+fatigue_delta)) else fatigue end,
      fitness=case when p_player_id=primary_id then greatest(0,least(100,fitness+fitness_delta)) else fitness end,
      morale=case when p_player_id=primary_id then greatest(0,least(100,morale+morale_delta)) else morale end,
      updated_at=now()
  where id='demo';

  if inj.id is not null then
    update public.injuries
    set aggravation_risk=greatest(0,least(100,aggravation_risk+risk_delta)),
        expected_return=greatest(p_date,expected_return-return_days),
        treatment=mp.protocol
    where id=inj.id;

    select * into inj from public.injuries where id=inj.id;

    if inj.expected_return<=p_date then
      update public.injuries
      set status='recovered',aggravation_risk=greatest(0,aggravation_risk-10)
      where id=inj.id;
      update public.players set injury_status='Fit' where id=p_player_id;
      if p_player_id=primary_id then
        update public.career_state set injury_status='Fit',updated_at=now() where id='demo';
      end if;
      recovered:=true;
    else
      update public.players set injury_status=inj.injury_type where id=p_player_id;
      if p_player_id=primary_id then
        update public.career_state set injury_status=inj.injury_type,updated_at=now() where id='demo';
      end if;
    end if;
  end if;

  return jsonb_build_object(
    'player_id',p_player_id,
    'player_name',p.name,
    'is_primary',p_player_id=primary_id,
    'protocol',mp.protocol,
    'weekly_cost',cost,
    'fatigue_delta',fatigue_delta,
    'fitness_delta',fitness_delta,
    'morale_delta',morale_delta,
    'risk_delta',risk_delta,
    'return_days_gained',return_days,
    'staff_medical_rating',round(best_medical,1),
    'staff_fitness_rating',round(best_fitness,1),
    'staff_nutrition_rating',round(best_nutrition,1),
    'staff_medical_bonus',medical_bonus,
    'staff_nutrition_bonus',nutrition_bonus,
    'injury_id',inj.id,
    'recovered',recovered
  );
end
$function$;

