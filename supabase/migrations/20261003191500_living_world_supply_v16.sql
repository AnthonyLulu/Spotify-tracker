-- Court Boss Living World V16
-- Adult world supply guard and long-horizon retirement pressure test.

create table if not exists public.world_supply_runs_v16(
  run_month date primary key,
  run_date date not null,
  target_active integer not null,
  before_active integer not null,
  created integer not null default 0,
  after_active integer not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.world_supply_runs_v16 enable row level security;
revoke all on table public.world_supply_runs_v16 from anon,authenticated;
grant select,insert,update,delete on table public.world_supply_runs_v16 to service_role;

CREATE OR REPLACE FUNCTION public.living_world_stress_test_v16(p_start_year integer DEFAULT 2026, p_end_year integer DEFAULT 2050, p_monthly_cap integer DEFAULT 250, p_junior_target integer DEFAULT 2000)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
with checkpoints as (
  select make_date(y,m,5) as d
  from generate_series(p_start_year,p_end_year) y
  cross join (values(1),(4),(7),(10)) mm(m)
),
base as (
  select
    p.id,
    coalesce(p.career_focus,'mixed') focus,
    coalesce(p.ranking,999999) singles_rank,
    coalesce(p.doubles_ranking,999999) doubles_rank,
    coalesce(p.form,65) form,
    coalesce(p.fitness,85) fitness,
    p.birth_date,
    coalesce(p.age,24) age_now,
    coalesce(dp.ambition,10) ambition,
    coalesce(dp.competitive_drive,10) drive,
    coalesce(dp.resilience,10) resilience,
    coalesce(dp.professionalism,10) professionalism,
    coalesce(dp.injury_proneness,10) injury_proneness,
    coalesce(dp.burnout_susceptibility,10) burnout,
    coalesce(pa.natural_fitness,10) natural_fitness,
    coalesce(pa.recovery,10) recovery
  from public.players p
  left join public.player_development_profiles dp on dp.player_id=p.id
  left join public.player_attributes pa on pa.player_id=p.id
  where p.career_status='active'
    and p.id<>coalesce((select managed_player_id from public.career_state where id='demo'),-1)
    and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
),
scored as (
  select
    b.id,c.d,b.focus,b.singles_rank,b.doubles_rank,
    coalesce(
      case when b.birth_date is not null then extract(year from age(c.d,b.birth_date))::int end,
      b.age_now + (extract(year from c.d)::int-2025)
    ) player_age,
    greatest(1,least(96,round(
      (
        case
          when coalesce(case when b.birth_date is not null then extract(year from age(c.d,b.birth_date))::int end,b.age_now)<33 then 0
          when coalesce(case when b.birth_date is not null then extract(year from age(c.d,b.birth_date))::int end,b.age_now)=33 then 1
          when coalesce(case when b.birth_date is not null then extract(year from age(c.d,b.birth_date))::int end,b.age_now)=34 then 2
          when coalesce(case when b.birth_date is not null then extract(year from age(c.d,b.birth_date))::int end,b.age_now)=35 then 4
          when coalesce(case when b.birth_date is not null then extract(year from age(c.d,b.birth_date))::int end,b.age_now)=36 then 7
          when coalesce(case when b.birth_date is not null then extract(year from age(c.d,b.birth_date))::int end,b.age_now)=37 then 11
          when coalesce(case when b.birth_date is not null then extract(year from age(c.d,b.birth_date))::int end,b.age_now)=38 then 18
          when coalesce(case when b.birth_date is not null then extract(year from age(c.d,b.birth_date))::int end,b.age_now)=39 then 26
          when coalesce(case when b.birth_date is not null then extract(year from age(c.d,b.birth_date))::int end,b.age_now)=40 then 38
          when coalesce(case when b.birth_date is not null then extract(year from age(c.d,b.birth_date))::int end,b.age_now)=41 then 52
          when coalesce(case when b.birth_date is not null then extract(year from age(c.d,b.birth_date))::int end,b.age_now)=42 then 68
          else 82
        end
      )
      *
      case
        when b.focus='doubles_only' and b.doubles_rank<=100 then .18
        when b.focus='doubles_only' and b.doubles_rank<=300 then .28
        when b.focus='doubles_only' then .48
        when b.singles_rank<=20 then .30
        when b.singles_rank<=100 then .44
        when b.singles_rank<=300 then .64
        else 1
      end
      *
      greatest(.42,least(1.85,
        1
        +(b.injury_proneness-10)*.028
        +(b.burnout-10)*.020
        -(b.natural_fitness-10)*.028
        -(b.recovery-10)*.016
        -(b.resilience-10)*.020
        -(b.professionalism-10)*.014
        -(b.ambition-10)*.012
        -(b.drive-10)*.016
      ))
      *
      case when b.fitness<60 then 1.35 when b.fitness<75 then 1.15 when b.fitness>=92 then .88 else 1 end
      *
      case when b.form<50 then 1.25 when b.form<65 then 1.08 when b.form>=82 then .90 else 1 end
    )::int)) retire_chance
  from base b cross join checkpoints c
),
first_retire as (
  select id,min(d) retire_date
  from scored
  where player_age>=46
     or (player_age>=44 and singles_rank>100 and doubles_rank>100)
     or mod(abs(hashtext(
        'retire|'||id::text||'|'||
        extract(year from d)::int::text||'|'||
        extract(month from d)::int::text
      )),100) < retire_chance
  group by id
),
annual as (
  select y as season,
    count(fr.id)::int retirements_current_roster
  from generate_series(p_start_year,p_end_year) y
  left join first_retire fr on extract(year from fr.retire_date)::int=y
  group by y
),
capacity as (
  select
    greatest(50,least(coalesce(p_monthly_cap,250),500))*12 as reserve_capacity,
    greatest(500,least(coalesce(p_junior_target,2000),2500))/5 as junior_capacity
),
rows as (
  select
    a.season,
    a.retirements_current_roster,
    c.reserve_capacity,
    c.junior_capacity,
    c.reserve_capacity+c.junior_capacity as replenishment_capacity,
    c.reserve_capacity+c.junior_capacity-a.retirements_current_roster as headroom
  from annual a cross join capacity c
)
select jsonb_build_object(
  'ok',(select min(headroom)>=0 from rows),
  'start_year',p_start_year,
  'end_year',p_end_year,
  'current_adult_active',(
    select count(*) from public.players p
    where p.career_status='active'
      and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
      and coalesce(
        case when p.birth_date is not null then extract(year from age(date '2025-12-01',p.birth_date))::int end,
        p.age,99
      ) between 18 and 45
  ),
  'adult_floor',24000,
  'monthly_reserve_cap',greatest(50,least(coalesce(p_monthly_cap,250),500)),
  'junior_pool_target',greatest(500,least(coalesce(p_junior_target,2000),2500)),
  'peak_current_roster_retirements',(select max(retirements_current_roster) from rows),
  'peak_retirement_year',(select season from rows order by retirements_current_roster desc,season limit 1),
  'minimum_headroom',(select min(headroom) from rows),
  'annual',(
    select jsonb_agg(jsonb_build_object(
      'season',season,
      'retirements_current_roster',retirements_current_roster,
      'reserve_capacity',reserve_capacity,
      'junior_capacity',junior_capacity,
      'replenishment_capacity',replenishment_capacity,
      'headroom',headroom
    ) order by season)
    from rows
  ),
  'note','Projection en lecture seule avec la formule de retraite du jeu figée sur les attributs actuels. Les futures cohortes sont régulées par le plancher adulte mensuel.',
  'model','CB-LIVING-WORLD-STRESS-v16'
);
$function$;

CREATE OR REPLACE FUNCTION public.maintain_world_player_supply_v16(p_date date DEFAULT CURRENT_DATE, p_target_active integer DEFAULT 24000, p_monthly_cap integer DEFAULT 250)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_date date:=coalesce(p_date,current_date);
  v_month date:=date_trunc('month',coalesce(p_date,current_date))::date;
  v_year int:=extract(year from coalesce(p_date,current_date))::int;
  v_month_no int:=extract(month from coalesce(p_date,current_date))::int;
  v_target int:=greatest(12000,least(coalesce(p_target_active,24000),30000));
  v_cap int:=greatest(50,least(coalesce(p_monthly_cap,250),500));
  v_before int:=0;
  v_after int:=0;
  v_deficit int:=0;
  v_create int:=0;
  v_existing_generated int:=0;
  v_created int:=0;
  v_seed int;
  v_age int;
  v_ca int;
  v_pa int;
  v_country text;
  v_name text;
  v_birth date;
  v_pid bigint;
  v_base int;
  v_countries text[];
  r public.world_supply_runs_v16%rowtype;
begin
  select * into r from public.world_supply_runs_v16 where run_month=v_month;
  if found then
    return jsonb_build_object(
      'ok',true,'processed',false,'reason','already_processed',
      'run_month',r.run_month,'target_active',r.target_active,
      'before_active',r.before_active,'created',r.created,'after_active',r.after_active,
      'model','CB-WORLD-SUPPLY-v16'
    );
  end if;

  select count(*)::int into v_before
  from public.players p
  where p.career_status='active'
    and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
    and coalesce(
      case when p.birth_date is not null then extract(year from age(v_date,p.birth_date))::int end,
      p.age,99
    ) between 18 and 45;

  v_deficit:=greatest(0,v_target-v_before);
  v_create:=least(v_deficit,v_cap);

  if v_create>0 then
    select array_agg(country order by md5(country||v_year::text||v_month_no::text))
    into v_countries
    from (
      select np.country
      from public.newgen_name_parts np
      group by np.country
      having count(*) filter(where np.kind='first')>=12
         and count(*) filter(where np.kind='last')>=18
    ) s;

    if v_countries is null or array_length(v_countries,1)=0 then
      v_countries:=array['FRA','ESP','ITA','GER','USA','AUS','GBR','CAN','ARG','BRA','CZE','SRB','JPN'];
    end if;

    select count(*)::int into v_existing_generated
    from public.players where game_generated=true;

    for i in 1..v_create loop
      v_seed:=v_existing_generated + v_year*100000 + v_month_no*1000 + i;
      v_country:=v_countries[1+mod(v_seed-1,array_length(v_countries,1))];
      v_name:=public.cb_generated_player_name(v_country,v_seed);
      v_age:=18+mod(v_seed+v_year,4);
      v_ca:=38+mod(v_seed*7+v_year,24);
      v_pa:=least(99,greatest(v_ca+8,58+mod(v_seed*11+v_year,40)));
      v_birth:=make_date(v_year-v_age,1+mod(v_seed,12),1+mod(v_seed*3,28));

      insert into public.players(
        slug,name,name_norm,country,is_real,game_generated,generated_year,
        ranking,source_ranking,points,doubles_ranking,itf_ranking,
        junior_ranking,junior_points,junior_snapshot_date,junior_source,
        age,birth_date,height_cm,weight_kg,handedness,backhand,style,
        current_ability,potential,form,fitness,morale,fatigue,scouting_confidence,
        data_source,data_snapshot,ranking_current,ranking_source,injury_status,
        career_status,generated_name_version,turned_pro_year,career_focus,career_focus_source
      )
      values(
        'adult-reserve-v16-'||v_year||'-'||lpad(v_month_no::text,2,'0')||'-'||i||'-'||substr(md5(v_name||'|'||v_seed::text),1,10),
        v_name,
        lower(regexp_replace(extensions.unaccent(v_name),'[^a-zA-Z0-9]+',' ','g')),
        v_country,false,true,v_year,
        null,null,0,
        2500+mod(v_seed,2500),null,
        null,null,null,null,
        v_age,v_birth,
        170+mod(v_seed*3,29),60+mod(v_seed*5,27),
        case when mod(v_seed,7)=0 then 'Gaucher' else 'Droitier' end,
        case when mod(v_seed,19)=0 then '1 main' else '2 mains' end,
        (array['Attaquant fond de court','Contreur','All-court','Serveur-attaquant','Défenseur'])[1+mod(v_seed,5)],
        v_ca,v_pa,
        58+mod(v_seed,30),86+mod(v_seed,14),62+mod(v_seed,34),5+mod(v_seed,18),35+mod(v_seed,50),
        'Court Boss adult world reserve v16',v_date,false,
        'World reserve awaiting ITF/NCAA/ATP pathway '||v_year,'Fit','active',6,v_year,'mixed','Court Boss world supply v16'
      )
      returning id into v_pid;

      v_base:=greatest(5,least(16,round(v_ca/6.0)::int));
      insert into public.player_attributes(
        player_id,serve_power,serve_precision,forehand,backhand,return_game,volley,touch,
        movement,speed,stamina,strength,anticipation,concentration,composure,fighting_spirit,
        tactics,doubles,clay_affinity,hard_affinity,grass_affinity,natural_fitness,recovery
      )
      values(
        v_pid,
        greatest(4,least(20,v_base+mod(v_seed*3,5)-2)),
        greatest(4,least(20,v_base+mod(v_seed*5,5)-2)),
        greatest(4,least(20,v_base+mod(v_seed*7,5)-1)),
        greatest(4,least(20,v_base+mod(v_seed*11,5)-2)),
        greatest(4,least(20,v_base+mod(v_seed*13,5)-2)),
        greatest(4,least(20,v_base+mod(v_seed*17,5)-3)),
        greatest(4,least(20,v_base+mod(v_seed*19,5)-2)),
        greatest(4,least(20,v_base+mod(v_seed*23,5)-1)),
        greatest(4,least(20,v_base+mod(v_seed*29,5)-1)),
        greatest(4,least(20,v_base+mod(v_seed*31,5)-1)),
        greatest(4,least(20,v_base+mod(v_seed*37,5)-2)),
        greatest(4,least(20,v_base+mod(v_seed*41,5)-2)),
        greatest(4,least(20,v_base+mod(v_seed*43,5)-2)),
        greatest(4,least(20,v_base+mod(v_seed*47,5)-2)),
        greatest(4,least(20,v_base+mod(v_seed*53,5)-1)),
        greatest(4,least(20,v_base+mod(v_seed*59,5)-2)),
        greatest(4,least(20,v_base+mod(v_seed*61,5)-3)),
        greatest(4,least(20,v_base+mod(v_seed*67,7))),
        greatest(4,least(20,v_base+mod(v_seed*71,7))),
        greatest(4,least(20,v_base+mod(v_seed*73,7))),
        9+mod(v_seed*79,10),
        9+mod(v_seed*83,10)
      );

      v_created:=v_created+1;
    end loop;
  end if;

  v_after:=v_before+v_created;

  insert into public.world_supply_runs_v16(
    run_month,run_date,target_active,before_active,created,after_active,metadata
  ) values(
    v_month,v_date,v_target,v_before,v_created,v_after,
    jsonb_build_object(
      'monthly_cap',v_cap,
      'deficit_before',v_deficit,
      'junior_target',2000,
      'itf_target',3600,
      'ncaa_target',900,
      'reason',case when v_created>0 then 'adult_world_below_floor' else 'healthy_no_generation' end
    )
  );

  return jsonb_build_object(
    'ok',true,'processed',true,'date',v_date,'run_month',v_month,
    'target_active',v_target,'before_active',v_before,'deficit_before',v_deficit,
    'monthly_cap',v_cap,'created',v_created,'after_active',v_after,
    'model','CB-WORLD-SUPPLY-v16'
  );
end;
$function$;

revoke all on function public.maintain_world_player_supply_v16(date,integer,integer) from public,anon,authenticated;
grant execute on function public.maintain_world_player_supply_v16(date,integer,integer) to service_role;
revoke all on function public.living_world_stress_test_v16(integer,integer,integer,integer) from public,anon,authenticated;
grant execute on function public.living_world_stress_test_v16(integer,integer,integer,integer) to service_role;
