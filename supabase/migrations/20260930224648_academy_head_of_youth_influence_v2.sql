CREATE OR REPLACE FUNCTION public.simulate_academy_roster_week(p_week integer, p_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  r record;
  staff_avg numeric;
  facility_avg numeric;
  youth_staff numeric:=10;
  development_staff numeric:=10;
  fitness_staff numeric:=10;
  best_youth numeric:=10;
  best_development numeric:=10;
  head_youth numeric:=null;
  head_development numeric:=null;
  head_profile_id bigint:=null;
  head_name text:=null;
  progressed int:=0;
  improved_attrs int:=0;
  focus_attr text;
  should_progress boolean;
  progress_cycle int:=4;
  attr_cycle int:=3;
begin
  select coalesce(avg(
    s.skill*coalesce(public.staff_effectiveness_multiplier(sp.id),1)
  ),10)
  into staff_avg
  from public.staff s
  left join public.staff_profiles sp on sp.id=s.profile_id;

  select coalesce(avg(level),1) into facility_avg from public.facilities;

  select
    coalesce(max(sp.youth_rating*coalesce(public.staff_effectiveness_multiplier(sp.id),1)),10),
    coalesce(max(sp.development_rating*coalesce(public.staff_effectiveness_multiplier(sp.id),1)),10),
    coalesce(max(sp.fitness_rating*coalesce(public.staff_effectiveness_multiplier(sp.id),1)),10)
  into best_youth,best_development,fitness_staff
  from public.staff s
  left join public.staff_profiles sp on sp.id=s.profile_id;

  select a.head_of_youth_profile_id into head_profile_id
  from public.academies a where a.id='demo';

  if head_profile_id is not null then
    select
      sp.name,
      sp.youth_rating*coalesce(public.staff_effectiveness_multiplier(sp.id),1),
      sp.development_rating*coalesce(public.staff_effectiveness_multiplier(sp.id),1)
    into head_name,head_youth,head_development
    from public.staff s
    join public.staff_profiles sp on sp.id=s.profile_id
    where sp.id=head_profile_id
    limit 1;
  end if;

  if head_youth is not null then
    youth_staff:=best_youth*.45+head_youth*.55;
    development_staff:=best_development*.55+coalesce(head_development,best_development)*.45;
  else
    youth_staff:=best_youth;
    development_staff:=best_development;
  end if;

  progress_cycle:=greatest(2,5-floor((youth_staff+development_staff-20)/10.0)::int);
  attr_cycle:=greatest(2,4-floor((development_staff-10)/5.0)::int);

  for r in
    select ar.*,p.age,p.current_ability,p.potential,p.form,p.fitness,p.morale,p.fatigue,p.junior_ranking,p.itf_ranking
    from public.academy_roster ar
    join public.players p on p.id=ar.player_id
    where ar.status='active' and ar.source_youth_id is not null
  loop
    should_progress :=
      r.current_ability < r.potential
      and ((r.player_id + p_week + round(staff_avg) + round(facility_avg)) % progress_cycle)=0;

    if should_progress then
      update public.players
      set current_ability=least(potential,current_ability+1),
          form=least(100,form+2+case when development_staff>=17 then 1 else 0 end),
          morale=least(100,morale+2+case when youth_staff>=17 then 1 else 0 end)
      where id=r.player_id;
      progressed:=progressed+1;
    else
      update public.players
      set form=greatest(40,least(100,form+(((r.player_id+p_week)%5)-2))),
          fitness=greatest(55,least(100,fitness+
            case when fatigue>45 then 2 else 0 end+
            case when fitness_staff>=17 then 1 else 0 end)),
          fatigue=greatest(0,least(100,fatigue+(((r.player_id+p_week*3)%5)-2)-
            case when fitness_staff>=18 then 1 else 0 end))
      where id=r.player_id;
    end if;

    focus_attr := case r.development_focus
      when 'Service' then 'serve_precision'
      when 'Retour' then 'return_game'
      when 'Fond de court' then case when r.player_id%2=0 then 'forehand' else 'backhand' end
      when 'Déplacements' then 'movement'
      when 'Physique' then 'stamina'
      when 'Mental' then 'tactics'
      when 'Double' then 'doubles'
      else case (r.player_id+p_week)%6
        when 0 then 'forehand'
        when 1 then 'backhand'
        when 2 then 'serve_precision'
        when 3 then 'return_game'
        when 4 then 'movement'
        else 'tactics'
      end
    end;

    if ((r.player_id+p_week)%attr_cycle)=0 then
      execute format(
        'update public.player_attributes set %I=least(20,%I+1) where player_id=$1 and %I<20',
        focus_attr,focus_attr,focus_attr
      ) using r.player_id;
      if found then improved_attrs:=improved_attrs+1; end if;
    end if;

    update public.players
    set junior_ranking=case
          when junior_ranking is not null then greatest(1,junior_ranking-(1+((id+p_week)%9)))
          else junior_ranking
        end,
        itf_ranking=case
          when itf_ranking is not null then greatest(1,itf_ranking-(1+((id+p_week)%7)))
          else itf_ranking
        end
    where id=r.player_id;
  end loop;

  return jsonb_build_object(
    'processed',(select count(*) from public.academy_roster where status='active' and source_youth_id is not null),
    'ability_progressions',progressed,
    'attribute_improvements',improved_attrs,
    'staff_youth_rating',round(youth_staff,1),
    'staff_development_rating',round(development_staff,1),
    'staff_fitness_rating',round(fitness_staff,1),
    'head_of_youth_profile_id',head_profile_id,
    'head_of_youth_name',head_name,
    'head_youth_rating',case when head_youth is null then null else round(head_youth,1) end,
    'progress_cycle',progress_cycle,
    'attribute_cycle',attr_cycle,
    'date',p_date,
    'model','CB-ACADEMY-DEVELOPMENT-v2'
  );
end;
$function$;