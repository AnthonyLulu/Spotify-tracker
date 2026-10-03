
update public.staff_profiles sp
set staff_birth_date=p.birth_date,
    updated_at=now()
from public.players p
where sp.active=true
  and sp.former_player_id=p.id
  and sp.staff_birth_date is null
  and p.birth_date is not null;

with seeded as (
  select
    sp.id,
    coalesce(sp.generation_year,2025) as base_year,
    28+mod(abs(hashtext('staff-age-v21|'||sp.id::text)),29) as age_seed,
    1+mod(abs(hashtext('staff-month-v21|'||sp.id::text)),12) as month_seed,
    1+mod(abs(hashtext('staff-day-v21|'||sp.id::text)),28) as day_seed
  from public.staff_profiles sp
  where sp.active=true
    and sp.retirement_year is null
    and sp.staff_birth_date is null
    and sp.world_generated=true
)
update public.staff_profiles sp
set staff_birth_date=make_date(s.base_year-s.age_seed,s.month_seed,s.day_seed),
    updated_at=now()
from seeded s
where sp.id=s.id;

update public.staff_profiles sp
set retirement_year=greatest(
      2028,
      extract(year from sp.staff_birth_date)::int
        +64+mod(abs(hashtext('staff-retire-v21|'||sp.id::text)),8)
    ),
    updated_at=now()
where sp.active=true
  and sp.retirement_year is null
  and sp.staff_birth_date is not null;

update public.staff_profiles sp
set retirement_year=2033+mod(abs(hashtext('staff-retire-legacy-v21|'||sp.id::text)),18),
    updated_at=now()
where sp.active=true
  and sp.retirement_year is null;

CREATE OR REPLACE FUNCTION public.ensure_doubles_coach_pool(p_date date DEFAULT CURRENT_DATE, p_target integer DEFAULT 1200)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_date date:=coalesce(p_date,current_date);
  v_year int:=extract(year from v_date)::int;
  v_need int;
  i int;
  v_country text;
  v_name text;
  v_created int:=0;
  v_age int;
  countries text[]:=array['FRA','ESP','ITA','GER','GBR','USA','AUS','CAN','ARG','BRA','CZE','SRB','CRO','POL','NED','BEL','SWE','DEN','AUT','SUI','IND','JPN','KOR','CHN','POR','GRE'];
begin
  select greatest(0,p_target-count(*))::int into v_need
  from public.staff_profiles
  where active=true and primary_role='Coach double';

  for i in 1..v_need loop
    v_country:=countries[1+mod(abs(hashtext('dbl|'||v_year::text||'|'||i::text)),array_length(countries,1))];
    v_name:=public.cb_generated_staff_name(v_country,17000000+v_year*10000+i);
    v_age:=28+mod(abs(hashtext('age|'||v_name)),29);

    insert into public.staff_profiles(
      name,nationality,primary_role,secondary_roles,is_real,former_player_status,
      coach_rating,technical_rating,tactical_rating,mental_rating,fitness_rating,medical_rating,
      scouting_rating,youth_rating,motivation_rating,communication_rating,adaptability_rating,reputation,
      doubles_coaching_rating,serve_coaching_rating,return_coaching_rating,
      specialty,notes,source_label,source_cutoff_date,verified,active,
      world_generated,generation_year,market_status,available_from,
      staff_birth_date,retirement_year,
      asking_weekly_cost,max_clients,staff_personality,coaching_style,preferred_surface,
      ambition,loyalty,discipline,pressure_handling,negotiation_rating,professionalism,development_rating
    )
    values(
      v_name,v_country,'Coach double',array['Volée','Service','Retour'],false,'no',
      10+mod(abs(hashtext('c|'||v_name)),9),
      11+mod(abs(hashtext('t|'||v_name)),9),
      12+mod(abs(hashtext('ta|'||v_name)),9),
      9+mod(abs(hashtext('m|'||v_name)),9),
      8+mod(abs(hashtext('f|'||v_name)),8),
      5+mod(abs(hashtext('med|'||v_name)),7),
      8+mod(abs(hashtext('sc|'||v_name)),8),
      8+mod(abs(hashtext('y|'||v_name)),8),
      10+mod(abs(hashtext('mo|'||v_name)),9),
      10+mod(abs(hashtext('co|'||v_name)),9),
      10+mod(abs(hashtext('ad|'||v_name)),9),
      8+mod(abs(hashtext('r|'||v_name)),10),
      14+mod(abs(hashtext('dblskill|'||v_name)),7),
      12+mod(abs(hashtext('srv|'||v_name)),9),
      12+mod(abs(hashtext('ret|'||v_name)),9),
      'Double · communication · schémas service/retour',
      'Spécialiste double généré de manière persistante par Court Boss.',
      'Court Boss · réseau coachs double',
      v_date,false,true,true,v_year,'available',v_date,
      make_date(v_year-v_age,1+mod(abs(hashtext('m|'||v_name)),12),1+mod(abs(hashtext('d|'||v_name)),28)),
      v_year+(64-v_age)+mod(abs(hashtext('retire|'||v_name)),8),
      420+mod(abs(hashtext('w|'||v_name)),800),
      3,
      (array['Analytique','Pédagogue','Exigeant','Calme'])[1+mod(abs(hashtext('p|'||v_name)),4)],
      'Double',
      (array['Dur','Indoor','Toutes'])[1+mod(abs(hashtext('s|'||v_name)),3)],
      10+mod(abs(hashtext('a|'||v_name)),9),
      8+mod(abs(hashtext('l|'||v_name)),10),
      10+mod(abs(hashtext('d|'||v_name)),9),
      11+mod(abs(hashtext('pr|'||v_name)),9),
      8+mod(abs(hashtext('n|'||v_name)),8),
      11+mod(abs(hashtext('pro|'||v_name)),9),
      10+mod(abs(hashtext('dev|'||v_name)),9)
    )
    on conflict(name) do nothing;

    if found then v_created:=v_created+1; end if;
  end loop;

  return jsonb_build_object(
    'date',v_date,
    'created',v_created,
    'active_doubles_coaches',(select count(*) from public.staff_profiles where active=true and primary_role='Coach double')
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.refresh_staff_lifecycle_v14(p_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_date date:=coalesce(p_date,current_date);
  v_year int:=extract(year from coalesce(p_date,current_date))::int;
  v_month int:=extract(month from coalesce(p_date,current_date))::int;
  v_announced int:=0;
  v_retired_user int:=0;
  v_retired_world int:=0;
  v_pool jsonb;
begin
  -- Any active staff profile must have a finite lifecycle. This normalizes legacy
  -- creators while preserving factual birth dates when they exist.
  update public.staff_profiles sp
  set staff_birth_date=p.birth_date,
      updated_at=now()
  from public.players p
  where sp.active=true
    and sp.former_player_id=p.id
    and sp.staff_birth_date is null
    and p.birth_date is not null;

  with seeded as (
    select
      sp.id,
      coalesce(sp.generation_year,v_year) as base_year,
      28+mod(abs(hashtext('staff-age-v21|'||sp.id::text)),29) as age_seed,
      1+mod(abs(hashtext('staff-month-v21|'||sp.id::text)),12) as month_seed,
      1+mod(abs(hashtext('staff-day-v21|'||sp.id::text)),28) as day_seed
    from public.staff_profiles sp
    where sp.active=true
      and sp.retirement_year is null
      and sp.staff_birth_date is null
      and sp.world_generated=true
  )
  update public.staff_profiles sp
  set staff_birth_date=make_date(s.base_year-s.age_seed,s.month_seed,s.day_seed),
      updated_at=now()
  from seeded s
  where sp.id=s.id;

  update public.staff_profiles sp
  set retirement_year=greatest(
        v_year+3,
        extract(year from sp.staff_birth_date)::int
          +64+mod(abs(hashtext('staff-retire-v21|'||sp.id::text)),8)
      ),
      updated_at=now()
  where sp.active=true
    and sp.retirement_year is null
    and sp.staff_birth_date is not null;

  update public.staff_profiles sp
  set retirement_year=v_year+8+mod(abs(hashtext('staff-retire-legacy-v21|'||sp.id::text)),18),
      updated_at=now()
  where sp.active=true
    and sp.retirement_year is null;

  -- User staff get one full season of notice before retirement.
  with due as (
    select sp.id,sp.name,sp.primary_role,sp.retirement_year
    from public.staff_profiles sp
    join public.staff s on s.profile_id=sp.id
    where sp.active=true
      and sp.retirement_year is not null
      and sp.retirement_year<=v_year
      and coalesce(sp.operational_status,'active')<>'retiring'
  ), upd as (
    update public.staff_profiles sp
    set operational_status='retiring',
        retirement_year=v_year+1,
        updated_at=now()
    from due d
    where sp.id=d.id
    returning sp.id,sp.name,sp.primary_role
  )
  insert into public.inbox_items(
    kind,title,body,action_route,is_read,game_date,priority,
    action_type,action_label,action_payload,decision_status,
    related_entity_type,related_entity_id
  )
  select
    'staff',
    'Retraite annoncée · '||u.name,
    u.name||' a annoncé qu’il quittera le circuit à la fin de la saison prochaine. Anticipe son remplacement.',
    'staff',false,v_date,'high',
    'open_route','Préparer la succession',jsonb_build_object('route','staff'),
    'info','staff_profile',u.id
  from upd u;
  get diagnostics v_announced=row_count;

  -- When the notice season is over, retirement is final.
  with retiring as (
    select sp.id,sp.name
    from public.staff_profiles sp
    join public.staff s on s.profile_id=sp.id
    where sp.active=true
      and sp.operational_status='retiring'
      and sp.retirement_year is not null
      and sp.retirement_year<=v_year
  )
  update public.staff_profiles sp
  set active=false,market_status='retired',operational_status='retired',updated_at=now()
  from retiring r
  where sp.id=r.id;
  get diagnostics v_retired_user=row_count;

  delete from public.staff s
  using public.staff_profiles sp
  where s.profile_id=sp.id
    and sp.active=false
    and sp.operational_status='retired';

  update public.contracts c
  set status='retired',end_date=least(coalesce(c.end_date,v_date),v_date)
  where c.subject_type='staff'
    and c.status='active'
    and exists(
      select 1 from public.staff_profiles sp
      where sp.name=c.subject_name
        and sp.active=false
        and sp.operational_status='retired'
    );

  update public.player_staff_assignments psa
  set active=false,end_date=v_date,ended_reason='Retraite du staff'
  where psa.active=true
    and exists(
      select 1 from public.staff_profiles sp
      where sp.id=psa.staff_profile_id
        and sp.active=false
        and sp.operational_status='retired'
    );

  -- World staff retire normally once their planned retirement year arrives.
  update public.staff_profiles sp
  set active=false,market_status='retired',operational_status='retired',updated_at=now()
  where sp.active=true
    and sp.retirement_year is not null
    and sp.retirement_year<=v_year
    and not exists(select 1 from public.staff s where s.profile_id=sp.id);
  get diagnostics v_retired_world=row_count;

  update public.player_staff_assignments psa
  set active=false,end_date=v_date,ended_reason='Retraite du staff'
  where psa.active=true
    and exists(
      select 1 from public.staff_profiles sp
      where sp.id=psa.staff_profile_id and sp.active=false
    );

  -- Refill former-player coaches and specialist staff once per quarter / January.
  if v_month in (1,4,7,10) then
    v_pool:=public.ensure_world_staff_pool(v_date,1500);
  else
    v_pool:=jsonb_build_object('skipped',true);
  end if;

  return jsonb_build_object(
    'date',v_date,'year',v_year,
    'retirement_notices',v_announced,
    'user_staff_retired',v_retired_user,
    'world_staff_retired',v_retired_world,
    'pool',v_pool,
    'active_staff_profiles',(select count(*) from public.staff_profiles where active=true),
    'former_player_staff',(select count(*) from public.staff_profiles where active=true and former_player_id is not null),
    'model','CB-STAFF-LIFECYCLE-v14'
  );
end;
$function$;
