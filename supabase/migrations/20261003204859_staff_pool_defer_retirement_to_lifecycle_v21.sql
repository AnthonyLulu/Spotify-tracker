CREATE OR REPLACE FUNCTION public.ensure_world_staff_pool(p_date date DEFAULT CURRENT_DATE, p_former_target integer DEFAULT 1500)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_date date:=coalesce(p_date,current_date);
  v_year int:=extract(year from coalesce(p_date,current_date))::int;
  v_former_target int:=greatest(300,least(coalesce(p_former_target,1500),2500));
  v_need int:=0;
  v_created_former int:=0;
  v_created_generated int:=0;
  v_existing_former int:=0;
  v_role text;
  v_target int;
  v_idx int;
  v_seed int;
  v_country text;
  v_name text;
  v_age int;
  v_rep int;
  v_max_clients int;
  v_countries text[]:=array[
    'FRA','ESP','ITA','GER','GBR','USA','AUS','CAN','ARG','BRA',
    'CZE','SRB','CRO','POL','NED','BEL','SWE','NOR','DEN','AUT',
    'SUI','POR','GRE','ROU','HUN','JPN','KOR','CHN','IND','TUR',
    'MEX','COL','CHI','RSA','MAR','TUN','EGY','NZL','FIN','SVK'
  ];
  v_roles text[]:=array[
    'Coach principal','Coach technique','Coach tactique',
    'Préparateur physique','Kinésithérapeute','Ostéopathe',
    'Analyste vidéo','Préparateur mental','Recruteur',
    'Nutritionniste','Agent'
  ];
  v_targets int[]:=array[
    900,350,350,
    1000,500,100,
    250,150,300,
    100,100
  ];
begin
  perform pg_advisory_xact_lock(94832013);

  select count(*)::int into v_existing_former
  from public.staff_profiles
  where active=true
    and former_player_status='yes'
    and former_player_id is not null;

  v_need:=greatest(0,v_former_target-v_existing_former);

  if v_need>0 then
    with eligible as (
      select
        p.id,p.name,p.country,p.is_real,p.birth_date,p.career_high_rank,
        coalesce(p.current_ability,50) as ca,
        coalesce(p.potential,55) as pot,
        coalesce(pa.tactics,10) as tactics,
        coalesce(pa.anticipation,10) as anticipation,
        coalesce(pa.concentration,10) as concentration,
        row_number() over(
          order by
            case when p.is_real then 0 else 1 end,
            coalesce(p.career_high_rank,99999),
            coalesce(p.current_ability,50) desc,
            p.id
        ) as rn
      from public.players p
      left join public.player_attributes pa on pa.player_id=p.id
      where p.career_status='retired'
        and p.birth_date is not null
        and p.birth_date>(v_date-interval '67 years')::date
        and p.birth_date<=(v_date-interval '30 years')::date
        and (
          p.retired_date is null
          or p.retired_date<=v_date-(90+mod(abs(hashtext('staff-cooldown-v17|'||p.id::text)),640))
        )
        and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
        and not exists(
          select 1 from public.staff_profiles sp where sp.former_player_id=p.id
        )
      order by
        case when p.is_real then 0 else 1 end,
        coalesce(p.career_high_rank,99999),
        p.id
      limit v_need
    )
    insert into public.staff_profiles(
      name,nationality,primary_role,secondary_roles,is_real,
      former_player_status,former_player_id,
      coach_rating,technical_rating,tactical_rating,mental_rating,
      fitness_rating,medical_rating,scouting_rating,youth_rating,
      motivation_rating,communication_rating,adaptability_rating,reputation,
      specialty,notes,source_label,source_cutoff_date,verified,active,
      world_generated,generation_year,market_status,available_from,
      staff_birth_date,retirement_year,asking_weekly_cost,max_clients
    )
    select
      e.name,e.country,
      case mod(abs(hashtext(e.id::text||'|'||v_year::text)),6)
        when 0 then 'Coach principal'
        when 1 then 'Coach technique'
        when 2 then 'Coach tactique'
        when 3 then 'Coach jeunes'
        when 4 then 'Recruteur'
        else 'Coach'
      end,
      case mod(abs(hashtext('secondary|'||e.id::text)),5)
        when 0 then array['Consultant']
        when 1 then array['Scout']
        when 2 then array['Sparring coach']
        when 3 then array['Développement jeunes']
        else array['Analyse tactique']
      end,
      e.is_real,'yes',e.id,
      greatest(8,least(20,round(
        9
        + case when coalesce(e.career_high_rank,99999)<=10 then 6
               when coalesce(e.career_high_rank,99999)<=50 then 5
               when coalesce(e.career_high_rank,99999)<=200 then 3
               else 1 end
        + e.tactics*.20
      )::int)),
      greatest(7,least(20,round(8+e.ca*.08+e.anticipation*.22)::int)),
      greatest(7,least(20,round(8+e.tactics*.42+e.anticipation*.20)::int)),
      greatest(7,least(20,round(8+e.concentration*.35+e.tactics*.15)::int)),
      greatest(6,least(18,round(7+e.ca*.07)::int)),
      6+mod(abs(hashtext('med|'||e.id::text)),8),
      greatest(7,least(20,round(8+e.anticipation*.28+e.tactics*.18)::int)),
      greatest(8,least(20,round(9+e.pot*.07+e.tactics*.15)::int)),
      10+mod(abs(hashtext('mot|'||e.id::text)),9),
      10+mod(abs(hashtext('com|'||e.id::text)),9),
      10+mod(abs(hashtext('adapt|'||e.id::text)),9),
      greatest(9,least(20,
        10+case when coalesce(e.career_high_rank,99999)<=10 then 9
                when coalesce(e.career_high_rank,99999)<=50 then 7
                when coalesce(e.career_high_rank,99999)<=200 then 5
                else 2 end
      )),
      'Reconversion après carrière professionnelle',
      'Ancien joueur reconverti dans le staff. Les attributs 1–20 sont des évaluations Court Boss.',
      'Court Boss · reconversion dynamique ancien joueur',
      v_date,false,true,
      true,v_year,'available',v_date,
      e.birth_date,
      v_year+greatest(3,68-extract(year from age(v_date,e.birth_date))::int),
      350 + (
        greatest(9,least(20,
          10+case when coalesce(e.career_high_rank,99999)<=10 then 9
                  when coalesce(e.career_high_rank,99999)<=50 then 7
                  when coalesce(e.career_high_rank,99999)<=200 then 5
                  else 2 end
        ))
      )*75,
      case when mod(abs(hashtext(e.id::text)),7)=0 then 2 else 1 end
    from eligible e
    on conflict(name) do nothing;

    get diagnostics v_created_former=row_count;
  end if;

  for v_idx in 1..array_length(v_roles,1) loop
    v_role:=v_roles[v_idx];
    v_target:=v_targets[v_idx];

    select greatest(0,v_target-count(*))::int
    into v_need
    from public.staff_profiles
    where world_generated=true
      and former_player_id is null
      and primary_role=v_role
      and active=true;

    if v_need>0 then
      for v_seed in 1..v_need loop
        v_country:=v_countries[
          1+mod(
            abs(hashtext(v_role||'|'||v_year::text||'|'||v_seed::text)),
            array_length(v_countries,1)
          )
        ];
        v_name:=public.cb_generated_staff_name(
          v_country,
          9000000+v_idx*100000+v_year*1000+v_seed
        );
        v_age:=28+mod(abs(hashtext('age|'||v_name)),29);
        v_rep:=8+mod(abs(hashtext('rep|'||v_name)),9);
        v_max_clients:=case
          when public.staff_role_group(v_role)='coach' then 1
          when public.staff_role_group(v_role) in ('fitness','medical') then 3
          when public.staff_role_group(v_role)='analysis' then 3
          when public.staff_role_group(v_role)='mental' then 2
          when public.staff_role_group(v_role)='scout' then 4
          else 3
        end;

        insert into public.staff_profiles(
          name,nationality,primary_role,secondary_roles,is_real,
          former_player_status,former_player_id,
          coach_rating,technical_rating,tactical_rating,mental_rating,
          fitness_rating,medical_rating,scouting_rating,youth_rating,
          motivation_rating,communication_rating,adaptability_rating,reputation,
          specialty,notes,source_label,source_cutoff_date,verified,active,
          world_generated,generation_year,market_status,available_from,
          staff_birth_date,retirement_year,asking_weekly_cost,max_clients
        )
        values(
          v_name,v_country,v_role,
          case public.staff_role_group(v_role)
            when 'coach' then array['Développement','Match']
            when 'fitness' then array['Prévention','Condition physique']
            when 'medical' then array['Récupération','Réathlétisation']
            when 'analysis' then array['Data','Analyse adversaire']
            when 'mental' then array['Confiance','Pression']
            when 'scout' then array['Détection','Réseau international']
            else array['Performance']
          end,
          false,'no',null,
          case when public.staff_role_group(v_role)='coach' then 11+mod(abs(hashtext('coach|'||v_name)),9) else 5+mod(abs(hashtext('coach|'||v_name)),7) end,
          case when public.staff_role_group(v_role)='coach' then 10+mod(abs(hashtext('tech|'||v_name)),10) else 5+mod(abs(hashtext('tech|'||v_name)),8) end,
          case when public.staff_role_group(v_role) in ('coach','analysis') then 10+mod(abs(hashtext('tact|'||v_name)),10) else 5+mod(abs(hashtext('tact|'||v_name)),8) end,
          case when public.staff_role_group(v_role)='mental' then 13+mod(abs(hashtext('ment|'||v_name)),8) else 7+mod(abs(hashtext('ment|'||v_name)),11) end,
          case when public.staff_role_group(v_role)='fitness' then 13+mod(abs(hashtext('fit|'||v_name)),8) else 6+mod(abs(hashtext('fit|'||v_name)),11) end,
          case when public.staff_role_group(v_role)='medical' then 13+mod(abs(hashtext('med|'||v_name)),8) else 5+mod(abs(hashtext('med|'||v_name)),10) end,
          case when public.staff_role_group(v_role)='scout' then 13+mod(abs(hashtext('scout|'||v_name)),8)
               when public.staff_role_group(v_role)='analysis' then 11+mod(abs(hashtext('scout|'||v_name)),9)
               else 6+mod(abs(hashtext('scout|'||v_name)),10) end,
          8+mod(abs(hashtext('youth|'||v_name)),12),
          9+mod(abs(hashtext('mot|'||v_name)),11),
          9+mod(abs(hashtext('com|'||v_name)),11),
          9+mod(abs(hashtext('adapt|'||v_name)),11),
          v_rep,
          case public.staff_role_group(v_role)
            when 'coach' then 'Coaching haute performance'
            when 'fitness' then 'Préparation physique & prévention'
            when 'medical' then 'Récupération & prévention des blessures'
            when 'analysis' then 'Analyse vidéo & data'
            when 'mental' then 'Préparation mentale & pression'
            when 'scout' then 'Scouting international'
            else 'Performance'
          end,
          'Profil staff généré de manière persistante par Court Boss.',
          'Court Boss · staff mondial généré',
          v_date,false,true,
          true,v_year,'available',v_date,
          make_date(v_year-v_age,1+mod(abs(hashtext('m|'||v_name)),12),1+mod(abs(hashtext('d|'||v_name)),28)),
          v_year+(64-v_age)+mod(abs(hashtext('retire|'||v_name)),8),
          250+v_rep*70+
            case public.staff_role_group(v_role)
              when 'coach' then 220
              when 'medical' then 180
              when 'fitness' then 170
              when 'analysis' then 150
              when 'mental' then 140
              when 'scout' then 130
              else 100
            end,
          v_max_clients
        )
        on conflict(name) do nothing;

        if found then
          v_created_generated:=v_created_generated+1;
        end if;
      end loop;
    end if;
  end loop;

  -- Retirement is owned by refresh_staff_lifecycle_v14 so user staff receive
  -- their notice season and all contracts/assignments close consistently.
  return jsonb_build_object(
    'date',v_date,
    'former_created',v_created_former,
    'generated_created',v_created_generated,
    'total_profiles',(select count(*) from public.staff_profiles),
    'active_profiles',(select count(*) from public.staff_profiles where active=true),
    'former_players',(select count(*) from public.staff_profiles where active=true and former_player_status='yes' and former_player_id is not null)
  );
end;
$function$;
