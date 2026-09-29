-- Court Boss NCAA alias canonicalization + junior doubles real-bye checkpoint
-- Captured from live Supabase after validation on 2026-09-30.
-- This file is a runtime checkpoint because the Supabase CLI is unavailable here.

alter table public.ncaa_school_team_aliases
  add column if not exists match_priority integer not null default 10,
  add column if not exists is_active boolean not null default true;

create unique index if not exists ncaa_school_team_aliases_normalized_uidx
  on public.ncaa_school_team_aliases(public.ncaa_school_alias_key(school_name))
  where is_active=true;

create index if not exists ncaa_school_team_aliases_team_idx
  on public.ncaa_school_team_aliases(team_id,match_priority,school_name);

CREATE OR REPLACE FUNCTION public.maintain_development_circuit_supply(p_date date DEFAULT CURRENT_DATE, p_junior_target integer DEFAULT 1800, p_itf_target integer DEFAULT 3600, p_ncaa_target integer DEFAULT 900)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_year int := extract(year from p_date)::int;
  v_season text := extract(year from p_date)::int::text || '-' || right((extract(year from p_date)::int + 1)::text,2);
  v_junior_target int := greatest(1200,least(coalesce(p_junior_target,1800),2200));
  v_itf_target int := greatest(2500,least(coalesce(p_itf_target,3600),4500));
  v_ncaa_target int := greatest(500,least(coalesce(p_ncaa_target,900),1200));
  v_ncaa_count int := 0;
  v_ncaa_deficit int := 0;
  v_ncaa_activated int := 0;
  v_ncaa_created int := 0;
  v_itf_count int := 0;
  v_itf_deficit int := 0;
  v_itf_assigned int := 0;
  v_itf_created int := 0;
  v_max_itf int := 0;
  v_max_ncaa int := 0;
  v_aged_out_ncaa int := 0;
  v_age_updates int := 0;
  v_transition jsonb;
  v_junior jsonb;
  v_display jsonb;
  v_schools text[];
  v_team_count int := 0;
  v_countries text[] := array[
    'USA','FRA','ESP','ITA','GER','AUS','GBR','CAN','ARG','BRA',
    'CZE','SRB','JPN','KOR','CHN','IND','NED','BEL','SWE','NOR',
    'DEN','POL','AUT','SUI','POR','GRE','CRO','TUR','MEX','COL'
  ];
  i int;
  seedv int;
  pid bigint;
  ctry text;
  full_name text;
  agev int;
  ca int;
  pa int;
  school_name text;
  class_name text;
  born date;
  base int;
begin
  perform pg_advisory_xact_lock(94832011);

  update public.players p
  set age=extract(year from age(p_date,p.birth_date))::int,
      age_snapshot_date=p_date
  where p.game_generated=true
    and p.is_real=false
    and p.career_status='active'
    and p.birth_date is not null
    and p.age between 12 and 30
    and p.age is distinct from extract(year from age(p_date,p.birth_date))::int;
  get diagnostics v_age_updates=row_count;

  update public.players
  set ncaa_current=false,
      ncaa_status='Alumni',
      ncaa_team_id=null,
      ncaa_last_school=coalesce(ncaa_last_school,ncaa_school),
      ncaa_snapshot_date=p_date
  where ncaa_current=true
    and (career_status<>'active' or coalesce(age,99)>23 or turned_pro_year is not null);
  get diagnostics v_aged_out_ncaa=row_count;

  v_transition:=public.transition_junior_pathways(v_year);
  v_junior:=public.ensure_junior_world_pool(v_year,v_junior_target);
  v_display:=public.refresh_junior_display_pool_v3(v_junior_target);
  perform public.refresh_junior_doubles_ranking(p_date);

  select array_agg(ct.name order by ct.ita_rank nulls last,ct.id)
  into v_schools
  from public.college_teams ct;

  v_team_count:=coalesce(array_length(v_schools,1),0);

  select count(*)::int,coalesce(max(p.ncaa_rank),0)::int
  into v_ncaa_count,v_max_ncaa
  from public.players p
  where p.career_status='active'
    and p.ncaa_current=true
    and p.age between 18 and 23;

  v_ncaa_deficit:=greatest(0,v_ncaa_target-v_ncaa_count);

  if v_ncaa_deficit>0 and v_team_count>0 then
    with candidates as (
      select p.id,
             row_number() over(
               order by p.potential desc,p.current_ability desc,p.id
             )::int as rn
      from public.players p
      where p.game_generated=true
        and p.is_real=false
        and p.career_status='active'
        and p.age between 18 and 23
        and coalesce(p.ncaa_current,false)=false
        and p.turned_pro_year is null
        and p.ranking_current=false
        and p.itf_ranking is null
        and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
      order by p.potential desc,p.current_ability desc,p.id
      limit v_ncaa_deficit
    ),
    mapped as (
      select c.id,c.rn,
             v_schools[1+mod(c.rn-1,v_team_count)] as school_name
      from candidates c
    )
    update public.players p
    set ncaa_current=true,
        ncaa_status='Active',
        ncaa_school=m.school_name,
        ncaa_team_id=public.resolve_ncaa_team_id(m.school_name),
        ncaa_last_school=m.school_name,
        ncaa_division='NCAA Division I',
        ncaa_rank=v_max_ncaa+m.rn,
        ncaa_snapshot_date=p_date,
        ncaa_source='Court Boss dynamic NCAA supply v1',
        ncaa_verified=false,
        ncaa_class_year=case
          when p.age<=18 then 'Freshman'
          when p.age=19 then 'Sophomore'
          when p.age=20 then 'Junior'
          when p.age=21 then 'Senior'
          else 'Graduate'
        end,
        ncaa_utr_rating=least(16.0,greatest(7.0,round((6.2+p.current_ability*0.105+p.potential*0.010)::numeric,2))),
        ncaa_utr_verified=false,
        ncaa_utr_source='Court Boss simulated UTR',
        junior_ranking=null,
        junior_points=null,
        junior_source=null,
        ranking_current=false,
        ranking=null,
        source_ranking=null,
        data_snapshot=p_date
    from mapped m
    where p.id=m.id;

    get diagnostics v_ncaa_activated=row_count;

    insert into public.ncaa_player_registry(
      player_id,ita_rank,school,division,season,status,snapshot_date,
      source_url,source_label,utr_rating,utr_source,utr_snapshot_date,utr_verified,class_year
    )
    select
      p.id,p.ncaa_rank,p.ncaa_school,coalesce(p.ncaa_division,'NCAA Division I'),
      v_season,'Active',p_date,null,'Court Boss dynamic NCAA supply v1',
      p.ncaa_utr_rating,'Court Boss simulated UTR',p_date,false,p.ncaa_class_year
    from public.players p
    where p.ncaa_current=true
      and p.ncaa_source='Court Boss dynamic NCAA supply v1'
      and p.ncaa_snapshot_date=p_date
    on conflict(player_id,season) do update set
      ita_rank=excluded.ita_rank,
      school=excluded.school,
      division=excluded.division,
      status='Active',
      snapshot_date=excluded.snapshot_date,
      source_label=excluded.source_label,
      utr_rating=excluded.utr_rating,
      utr_source=excluded.utr_source,
      utr_snapshot_date=excluded.utr_snapshot_date,
      utr_verified=false,
      class_year=excluded.class_year;
  end if;

  select count(*)::int,coalesce(max(p.ncaa_rank),0)::int
  into v_ncaa_count,v_max_ncaa
  from public.players p
  where p.career_status='active'
    and p.ncaa_current=true
    and p.age between 18 and 23;

  v_ncaa_deficit:=greatest(0,v_ncaa_target-v_ncaa_count);

  if v_ncaa_deficit>0 and v_team_count>0 then
    for i in 1..v_ncaa_deficit loop
      seedv:=100000+v_year*1000+i;
      ctry:=v_countries[1+mod(seedv-1,array_length(v_countries,1))];
      full_name:=public.cb_generated_player_name(ctry,seedv);
      agev:=18+mod(seedv,6);
      ca:=42+mod(seedv*7,20);
      pa:=least(96,greatest(ca+8,68+mod(seedv*11,27)));
      born:=make_date(v_year-agev,1+mod(seedv*3,12),1+mod(seedv*7,28));
      school_name:=v_schools[1+mod(v_ncaa_count+i-1,v_team_count)];
      class_name:=case
        when agev<=18 then 'Freshman'
        when agev=19 then 'Sophomore'
        when agev=20 then 'Junior'
        when agev=21 then 'Senior'
        else 'Graduate'
      end;

      insert into public.players(
        slug,name,name_norm,country,is_real,game_generated,generated_year,
        ranking,points,doubles_ranking,itf_ranking,junior_ranking,
        age,birth_date,height_cm,weight_kg,handedness,backhand,style,
        current_ability,potential,form,fitness,morale,fatigue,scouting_confidence,
        data_source,data_snapshot,ranking_current,ranking_source,injury_status,
        career_status,generated_name_version,ncaa_current
      )
      values(
        'ncaa-newgen-'||v_year||'-'||seedv||'-'||substr(md5(full_name||'|'||seedv::text),1,8),
        full_name,
        lower(regexp_replace(extensions.unaccent(full_name),'[^a-zA-Z0-9]+',' ','g')),
        ctry,false,true,v_year,
        null,0,null,null,null,
        agev,born,170+mod(seedv*3,28),60+mod(seedv*5,28),
        case when seedv%8=0 then 'Gaucher' else 'Droitier' end,
        case when seedv%19=0 then '1 main' else '2 mains' end,
        (array['Attaquant fond de court','Contreur','All-court','Serveur-attaquant','Défenseur'])[1+mod(seedv,5)],
        ca,pa,60+mod(seedv,28),88+mod(seedv,12),65+mod(seedv,30),5+mod(seedv,18),45+mod(seedv,45),
        'Court Boss generated NCAA reserve v1',p_date,false,'NCAA pathway '||v_year,'Fit',
        'active',6,false
      )
      returning id into pid;

      update public.players
      set ncaa_current=true,
          ncaa_status='Active',
          ncaa_school=school_name,
          ncaa_team_id=public.resolve_ncaa_team_id(school_name),
          ncaa_last_school=school_name,
          ncaa_division='NCAA Division I',
          ncaa_rank=v_max_ncaa+i,
          ncaa_snapshot_date=p_date,
          ncaa_source='Court Boss generated NCAA reserve v1',
          ncaa_verified=false,
          ncaa_class_year=class_name,
          ncaa_utr_rating=least(16.0,greatest(7.0,round((6.2+ca*0.105+pa*0.010)::numeric,2))),
          ncaa_utr_verified=false,
          ncaa_utr_source='Court Boss simulated UTR'
      where id=pid;

      insert into public.ncaa_player_registry(
        player_id,ita_rank,school,division,season,status,snapshot_date,
        source_url,source_label,utr_rating,utr_source,utr_snapshot_date,utr_verified,class_year
      )
      select
        p.id,p.ncaa_rank,p.ncaa_school,p.ncaa_division,v_season,'Active',p_date,
        null,'Court Boss generated NCAA reserve v1',p.ncaa_utr_rating,
        'Court Boss simulated UTR',p_date,false,p.ncaa_class_year
      from public.players p where p.id=pid
      on conflict(player_id,season) do update set
        ita_rank=excluded.ita_rank,school=excluded.school,division=excluded.division,
        status='Active',snapshot_date=excluded.snapshot_date,source_label=excluded.source_label,
        utr_rating=excluded.utr_rating,utr_source=excluded.utr_source,
        utr_snapshot_date=excluded.utr_snapshot_date,utr_verified=false,class_year=excluded.class_year;

      base:=greatest(6,least(16,round(ca/5.0)::int));
      insert into public.player_attributes(
        player_id,serve_power,serve_precision,forehand,backhand,return_game,volley,touch,
        movement,speed,stamina,strength,anticipation,concentration,composure,fighting_spirit,
        tactics,doubles,clay_affinity,hard_affinity,grass_affinity
      ) values(
        pid,
        greatest(4,least(20,base+mod(seedv*3,5)-2)),
        greatest(4,least(20,base+mod(seedv*5,5)-2)),
        greatest(4,least(20,base+mod(seedv*7,5)-1)),
        greatest(4,least(20,base+mod(seedv*11,5)-2)),
        greatest(4,least(20,base+mod(seedv*13,5)-2)),
        greatest(4,least(20,base+mod(seedv*17,5)-2)),
        greatest(4,least(20,base+mod(seedv*19,5)-2)),
        greatest(4,least(20,base+mod(seedv*23,5)-1)),
        greatest(4,least(20,base+mod(seedv*29,5)-1)),
        greatest(4,least(20,base+mod(seedv*31,5)-1)),
        greatest(4,least(20,base+mod(seedv*37,5)-2)),
        greatest(4,least(20,base+mod(seedv*41,5)-2)),
        greatest(4,least(20,base+mod(seedv*43,5)-2)),
        greatest(4,least(20,base+mod(seedv*47,5)-2)),
        greatest(4,least(20,base+mod(seedv*53,5)-1)),
        greatest(4,least(20,base+mod(seedv*59,5)-2)),
        greatest(4,least(20,base+mod(seedv*61,5)-1)),
        greatest(4,least(20,base+mod(seedv*67,6))),
        greatest(4,least(20,base+mod(seedv*71,6))),
        greatest(4,least(20,base+mod(seedv*73,6)))
      );
      v_ncaa_created:=v_ncaa_created+1;
    end loop;
  end if;

  select count(*)::int,coalesce(max(p.itf_ranking),0)::int
  into v_itf_count,v_max_itf
  from public.players p
  where p.career_status='active'
    and p.itf_ranking is not null
    and coalesce(p.ncaa_current,false)=false;

  v_itf_deficit:=greatest(0,v_itf_target-v_itf_count);

  if v_itf_deficit>0 then
    with candidates as (
      select p.id,
             row_number() over(
               order by p.current_ability desc,p.potential desc,p.id
             )::int as rn
      from public.players p
      where p.game_generated=true
        and p.is_real=false
        and p.career_status='active'
        and p.age between 18 and 28
        and p.itf_ranking is null
        and coalesce(p.ncaa_current,false)=false
        and p.ranking_current=false
        and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
      order by p.current_ability desc,p.potential desc,p.id
      limit v_itf_deficit
    )
    update public.players p
    set itf_ranking=v_max_itf+c.rn,
        turned_pro_year=coalesce(p.turned_pro_year,v_year),
        ranking_source='Court Boss dynamic ITF supply v1',
        data_snapshot=p_date
    from candidates c
    where p.id=c.id;

    get diagnostics v_itf_assigned=row_count;
  end if;

  v_itf_count:=v_itf_count+v_itf_assigned;
  v_itf_deficit:=greatest(0,v_itf_target-v_itf_count);

  if v_itf_deficit>0 then
    for i in 1..v_itf_deficit loop
      seedv:=200000+v_year*1000+i;
      ctry:=v_countries[1+mod(seedv-1,array_length(v_countries,1))];
      full_name:=public.cb_generated_player_name(ctry,seedv);
      agev:=18+mod(seedv,11);
      ca:=36+mod(seedv*7,23);
      pa:=least(94,greatest(ca+7,58+mod(seedv*11,32)));
      born:=make_date(v_year-agev,1+mod(seedv*3,12),1+mod(seedv*7,28));

      insert into public.players(
        slug,name,name_norm,country,is_real,game_generated,generated_year,
        ranking,points,doubles_ranking,itf_ranking,junior_ranking,
        age,birth_date,height_cm,weight_kg,handedness,backhand,style,
        current_ability,potential,form,fitness,morale,fatigue,scouting_confidence,
        data_source,data_snapshot,ranking_current,ranking_source,injury_status,
        career_status,generated_name_version,turned_pro_year,ncaa_current
      )
      values(
        'itf-newgen-'||v_year||'-'||seedv||'-'||substr(md5(full_name||'|'||seedv::text),1,8),
        full_name,
        lower(regexp_replace(extensions.unaccent(full_name),'[^a-zA-Z0-9]+',' ','g')),
        ctry,false,true,v_year,
        null,0,null,v_max_itf+v_itf_assigned+i,null,
        agev,born,168+mod(seedv*3,31),58+mod(seedv*5,31),
        case when seedv%8=0 then 'Gaucher' else 'Droitier' end,
        case when seedv%21=0 then '1 main' else '2 mains' end,
        (array['Attaquant fond de court','Contreur','All-court','Serveur-attaquant','Défenseur'])[1+mod(seedv,5)],
        ca,pa,55+mod(seedv,33),86+mod(seedv,14),60+mod(seedv,36),5+mod(seedv,20),35+mod(seedv,51),
        'Court Boss generated ITF reserve v1',p_date,false,'Court Boss generated ITF supply '||v_year,'Fit',
        'active',6,v_year,false
      )
      returning id into pid;

      base:=greatest(5,least(15,round(ca/5.0)::int));
      insert into public.player_attributes(
        player_id,serve_power,serve_precision,forehand,backhand,return_game,volley,touch,
        movement,speed,stamina,strength,anticipation,concentration,composure,fighting_spirit,
        tactics,doubles,clay_affinity,hard_affinity,grass_affinity
      ) values(
        pid,
        greatest(3,least(20,base+mod(seedv*3,5)-2)),
        greatest(3,least(20,base+mod(seedv*5,5)-2)),
        greatest(3,least(20,base+mod(seedv*7,5)-1)),
        greatest(3,least(20,base+mod(seedv*11,5)-2)),
        greatest(3,least(20,base+mod(seedv*13,5)-2)),
        greatest(3,least(20,base+mod(seedv*17,5)-3)),
        greatest(3,least(20,base+mod(seedv*19,5)-2)),
        greatest(3,least(20,base+mod(seedv*23,5)-1)),
        greatest(3,least(20,base+mod(seedv*29,5)-1)),
        greatest(3,least(20,base+mod(seedv*31,5)-1)),
        greatest(3,least(20,base+mod(seedv*37,5)-2)),
        greatest(3,least(20,base+mod(seedv*41,5)-2)),
        greatest(3,least(20,base+mod(seedv*43,5)-2)),
        greatest(3,least(20,base+mod(seedv*47,5)-2)),
        greatest(3,least(20,base+mod(seedv*53,5)-1)),
        greatest(3,least(20,base+mod(seedv*59,5)-2)),
        greatest(3,least(20,base+mod(seedv*61,5)-2)),
        greatest(3,least(20,base+mod(seedv*67,7))),
        greatest(3,least(20,base+mod(seedv*71,7))),
        greatest(3,least(20,base+mod(seedv*73,7)))
      );
      v_itf_created:=v_itf_created+1;
    end loop;
  end if;

  perform public.refresh_game_world_ranks();

  return jsonb_build_object(
    'date',p_date,
    'targets',jsonb_build_object('junior',v_junior_target,'itf',v_itf_target,'ncaa',v_ncaa_target),
    'age_updates',v_age_updates,
    'junior_transition',v_transition,
    'junior_pool',v_junior,
    'junior_display',v_display,
    'ncaa',jsonb_build_object(
      'before',v_ncaa_count-v_ncaa_activated,
      'activated_existing',v_ncaa_activated,
      'created',v_ncaa_created,
      'after',(select count(*) from public.players p where p.career_status='active' and p.ncaa_current=true and p.age between 18 and 23),
      'aged_out',v_aged_out_ncaa,
      'schools',v_team_count
    ),
    'itf',jsonb_build_object(
      'before',v_itf_count-v_itf_assigned,
      'assigned_existing',v_itf_assigned,
      'created',v_itf_created,
      'after',(select count(*) from public.players p where p.career_status='active' and p.itf_ranking is not null and coalesce(p.ncaa_current,false)=false)
    )
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.ncaa_prepare_individual_event(p_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  v_singles_draw int;
  v_doubles_draw int;
  v_singles_count int:=0;
  v_doubles_count int:=0;
  v_school_cap int;
  v_season int;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null or t.circuit<>'NCAA' or not coalesce(t.is_active,true) then
    return jsonb_build_object('ok',false,'reason','not_active_ncaa_event');
  end if;

  if t.category in ('ITA Kickoff Weekend','ITA National Team Indoor Championship','NCAA DI Team Championship') then
    return jsonb_build_object('ok',false,'reason','team_event');
  end if;

  v_season:=extract(year from t.start_date)::int;
  v_singles_draw:=greatest(0,coalesce(t.singles_draw_size,t.draw_size,case when t.singles then 64 else 0 end));
  v_doubles_draw:=greatest(0,coalesce(t.doubles_draw_size,case when t.doubles then 16 else 0 end));

  if t.category='NCAA DI Individual Championship' then
    v_school_cap:=99;
  elsif t.registration_mode in ('school_nomination','conference_selection') then
    v_school_cap:=4;
  else
    v_school_cap:=3;
  end if;

  if coalesce(t.singles,false) and v_singles_draw>0
     and not exists(select 1 from public.ncaa_individual_entries where tournament_id=t.id and discipline='singles') then

    with base as (
      select p.id,p.ncaa_team_id,p.ncaa_school,p.ncaa_rank,
             coalesce(us.current_rating,10) utr,
             coalesce(ip.points,0) season_points,
             coalesce(p.current_ability,50) ca,
             row_number() over(
               partition by coalesce(p.ncaa_team_id,-p.id)
               order by
                 case when t.category='NCAA UTR' then coalesce(us.current_rating,10) else coalesce(ip.points,0) end desc,
                 coalesce(p.ncaa_rank,9999),
                 p.id
             ) school_rn
      from public.players p
      left join public.player_utr_state us on us.player_id=p.id
      left join public.ncaa_individual_points ip on ip.player_id=p.id and ip.season=v_season
      where p.ncaa_current=true
        and p.career_status='active'
        and p.injury_status='Fit'
        and coalesce(p.fitness,90)>=45
        and public.ncaa_individual_player_available(p.id,t.id)
    ),
    championship_auto as (
      select distinct q.player_ids[1] player_id
      from public.ncaa_individual_qualifiers q
      where q.season=v_season and q.discipline='singles'
        and array_length(q.player_ids,1)=1
    ),
    ranked as (
      select b.*,
        case
          when ca.player_id is not null then -1000000
          else 0 end auto_bias,
        (
          case
            when t.category='NCAA UTR' then b.utr*95+b.ca*.4+b.season_points*.02
            when t.category='NCAA DI Individual Championship' then b.season_points*1.4+b.utr*24+b.ca*.25
            when t.category like 'ITA %' then b.season_points*.8+b.utr*42+b.ca*.30
            else b.season_points*.35+b.utr*62+b.ca*.25
          end
          + (mod(abs(hashtext('ncaa-field|'||t.id||'|'||b.id)),1000)::numeric/1000.0)*6
        ) field_score
      from base b
      left join championship_auto ca on ca.player_id=b.id
      where b.school_rn<=v_school_cap or ca.player_id is not null
    ),
    chosen as (
      select id,
             row_number() over(order by auto_bias asc,field_score desc,coalesce(ncaa_rank,9999),id)::int pos
      from ranked
      order by auto_bias asc,field_score desc,coalesce(ncaa_rank,9999),id
      limit v_singles_draw
    )
    insert into public.ncaa_individual_entries(
      tournament_id,player_id,discipline,initial_phase,seed,draw_position,entry_type
    )
    select t.id,c.id,'singles','main',
           case when c.pos<=16 then c.pos else null end,
           c.pos,
           case when exists(
             select 1 from public.ncaa_individual_qualifiers q
             where q.season=v_season and q.discipline='singles'
               and q.player_ids=array[c.id]::bigint[]
           ) then 'automatic_qualifier'
           when t.registration_mode='conference_selection' then 'conference_selection'
           when t.registration_mode='school_nomination' then 'school_nomination'
           else 'individual_selection' end
    from chosen c
    on conflict do nothing;

    get diagnostics v_singles_count=row_count;
  else
    select count(*) into v_singles_count
    from public.ncaa_individual_entries where tournament_id=t.id and discipline='singles';
  end if;

  if coalesce(t.doubles,false) and v_doubles_draw>0
     and not exists(select 1 from public.ncaa_individual_doubles_entries where tournament_id=t.id) then

    with eligible as (
      select p.id,p.ncaa_team_id,p.ncaa_school,
             coalesce(pa.doubles,10) doubles_skill,
             coalesce(us.current_rating,10) utr,
             coalesce(p.current_ability,50) ca,
             row_number() over(
               partition by p.ncaa_team_id
               order by coalesce(pa.doubles,10) desc,coalesce(us.current_rating,10) desc,p.id
             ) rn
      from public.players p
      left join public.player_attributes pa on pa.player_id=p.id
      left join public.player_utr_state us on us.player_id=p.id
      where p.ncaa_current=true
        and p.ncaa_team_id is not null
        and p.career_status='active'
        and p.injury_status='Fit'
        and coalesce(p.fitness,90)>=45
        and coalesce(p.career_focus,'mixed')<>'singles_only'
        and public.ncaa_individual_player_available(p.id,t.id)
    ),
    pairs as (
      select a.ncaa_team_id,
             least(a.id,b.id) player_a_id,
             greatest(a.id,b.id) player_b_id,
             a.doubles_skill+b.doubles_skill+(a.utr+b.utr)*.7+(a.ca+b.ca)*.10 pair_score,
             ((a.rn+1)/2)::int pair_no
      from eligible a
      join eligible b
        on b.ncaa_team_id=a.ncaa_team_id
       and b.rn=a.rn+1
       and mod(a.rn,2)=1
      where a.rn<=6
    ),
    ranked as (
      select *,
        row_number() over(order by pair_score desc,
          mod(abs(hashtext('ncaa-double-field|'||t.id||'|'||player_a_id||'|'||player_b_id)),1000),
          player_a_id,player_b_id)::int pos
      from pairs
      where pair_no<=3
      order by pair_score desc,pos
      limit v_doubles_draw
    )
    insert into public.ncaa_individual_doubles_entries(
      tournament_id,player_a_id,player_b_id,initial_phase,seed
    )
    select t.id,player_a_id,player_b_id,'main',
           case when pos<=8 then pos else null end
    from ranked
    on conflict do nothing;

    get diagnostics v_doubles_count=row_count;
  else
    select count(*) into v_doubles_count
    from public.ncaa_individual_doubles_entries where tournament_id=t.id;
  end if;

  return jsonb_build_object(
    'ok',true,'tournament_id',t.id,'name',t.name,
    'singles_entries',v_singles_count,'doubles_entries',v_doubles_count,
    'singles_draw',v_singles_draw,'doubles_draw',v_doubles_draw
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.ncaa_school_alias_key(p_school text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  select regexp_replace(lower(trim(coalesce(p_school,''))),'[^a-z0-9]+','','g');
$function$;

CREATE OR REPLACE FUNCTION public.player_in_ncaa_team_event(p_player_id bigint, p_start date, p_end date)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select exists(
    select 1
    from public.players p
    join public.college_team_event_entries ce on ce.team_id=p.ncaa_team_id
    join public.tournaments t on t.id=ce.tournament_id
    where p.id=p_player_id
      and p.ncaa_current=true
      and daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
          && daterange(p_start,p_end,'[]')
  );
$function$;

CREATE OR REPLACE FUNCTION public.refresh_ncaa_doubles_rankings(p_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_season int:=extract(year from p_date)::int;
  v_count int;
begin
  delete from public.ncaa_doubles_rankings where snapshot_date=p_date;

  with ranked as (
    select dpp.player_a_id,dpp.player_b_id,dpp.points,dpp.wins,dpp.losses,
           row_number() over(order by dpp.points desc,dpp.wins desc,dpp.losses asc,dpp.player_a_id,dpp.player_b_id)::int rk
    from public.ncaa_doubles_pair_points dpp
    where dpp.season=v_season
  )
  insert into public.ncaa_doubles_rankings(
    season,snapshot_date,ita_rank,player_one_id,player_two_id,
    player_one_name,player_two_name,school,conference,source_label
  )
  select
    v_season::text,p_date,r.rk,r.player_a_id,r.player_b_id,
    p1.name,p2.name,
    case
      when p1.ncaa_team_id is not null and p1.ncaa_team_id=p2.ncaa_team_id then ct1.name
      else coalesce(ct1.name,ct2.name,p1.ncaa_school,p2.ncaa_school)
    end,
    null,
    'Court Boss dynamic NCAA doubles ranking v1'
  from ranked r
  join public.players p1 on p1.id=r.player_a_id
  join public.players p2 on p2.id=r.player_b_id
  left join public.college_teams ct1 on ct1.id=p1.ncaa_team_id
  left join public.college_teams ct2 on ct2.id=p2.ncaa_team_id
  order by r.rk
  limit 2000;

  get diagnostics v_count=row_count;
  return jsonb_build_object('rows',v_count,'snapshot_date',p_date,'season',v_season);
end;
$function$;

CREATE OR REPLACE FUNCTION public.refresh_ncaa_team_rankings(p_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_count int;
begin
  with records as (
    select t.id,
      count(d.id) filter(where d.status='completed') played,
      count(d.id) filter(where d.status='completed' and d.winner_team_id=t.id) wins,
      count(d.id) filter(where d.status='completed' and d.winner_team_id is distinct from t.id) losses
    from public.college_teams t
    left join public.college_duals d
      on t.id in (d.home_team_id,d.away_team_id)
      and d.match_date<=p_date
      and d.status='completed'
      and coalesce(d.competition,'')<>'NCAA Fall Showcase'
    group by t.id
  ),
  scored as (
    select t.id,
      coalesce(r.wins,0) wins,coalesce(r.losses,0) losses,
      (
        coalesce(r.wins,0)*100
        -coalesce(r.losses,0)*35
        -coalesce(t.preseason_rank,t.ita_rank,64)*1.8
      ) score
    from public.college_teams t
    left join records r on r.id=t.id
  ),
  ranked as (
    select id,wins,losses,
      row_number() over(order by score desc,wins desc,losses asc,id)::int new_rank
    from scored
  )
  update public.college_teams t
  set ita_rank=r.new_rank,
      record=r.wins||'-'||r.losses
  from ranked r
  where t.id=r.id;

  get diagnostics v_count=row_count;

  with pr as (
    select p.id,
      row_number() over(order by
        (
          coalesce(ip.points,0)*.11+
          coalesce(us.current_rating,10)*3.0+
          coalesce(p.current_ability,50)*1.0+
          coalesce(p.form,70)*.12+
          greatest(0,65-coalesce(ct.ita_rank,64))*.16
        ) desc,
        p.id
      )::int new_rank
    from public.players p
    left join public.player_utr_state us on us.player_id=p.id
    left join public.college_teams ct on ct.id=p.ncaa_team_id
    left join public.ncaa_individual_points ip
      on ip.player_id=p.id and ip.season=extract(year from p_date)::int
    where p.ncaa_current=true and p.career_status='active'
  )
  update public.players p
  set ncaa_rank=pr.new_rank
  from pr where p.id=pr.id;

  return jsonb_build_object('teams_ranked',v_count,'date',p_date);
end;
$function$;

CREATE OR REPLACE FUNCTION public.resolve_ncaa_team_id(p_school text)
 RETURNS bigint
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  with candidates as (
    select a.team_id,
           0 as tier,
           a.match_priority,
           a.school_name as matched_label
    from public.ncaa_school_team_aliases a
    where a.is_active=true
      and public.ncaa_school_alias_key(a.school_name)=public.ncaa_school_alias_key(p_school)

    union all

    select t.id,
           1 as tier,
           0 as match_priority,
           t.name as matched_label
    from public.college_teams t
    where public.ncaa_school_alias_key(t.name)=public.ncaa_school_alias_key(p_school)
  )
  select team_id
  from candidates
  order by tier,match_priority,matched_label,team_id
  limit 1;
$function$;

CREATE OR REPLACE FUNCTION public.simulate_junior_world_doubles_full(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  v_managed bigint;
  v_draw int;
  v_pair_count int;
  v_p1 bigint;
  v_best_partner bigint;
  v_pair_strength int;
  v_best_strength int;
  v_size int;
  v_bracket int;
  v_byes int;
  v_round int;
  v_pos int;
  v_next int;
  v_match_no int;
  v_round_entries bigint[];
  v_a bigint;
  v_b bigint;
  v_w bigint;
  v_l bigint;
  v_sa int;
  v_sb int;
  v_prob numeric;
  v_awon boolean;
  v_score text;
  v_code text;
  v_winner bigint;
  v_count int:=0;
  v_matches int:=0;
  rr record;
begin
  select managed_player_id into v_managed from public.career_state where id='demo';

  for t in
    select *
    from public.tournaments
    where circuit='Junior'
      and doubles=true
      and coalesce(is_active,true)=true
      and coalesce(end_date,start_date)>p_from_date
      and coalesce(end_date,start_date)<=p_to_date
      and category not in ('Junior Davis Cup','Junior Finals','Junior Double Finals')
      and coalesce(doubles_draw_size,0)>=8
      and not exists(select 1 from public.world_junior_doubles_entries e where e.tournament_id=tournaments.id)
    order by
      date_trunc('week',start_date::timestamp),
      case
        when category='Junior Grand Slam' then 100
        when category='J500' then 90
        when category='J300' then 80
        when category='J200' then 70
        when category='J100' then 60
        when category='J60' then 50
        when category='J30' then 40
        else 10 end desc,
      coalesce(end_date,start_date),id
    limit 100
  loop
    v_draw:=least(32,coalesce(t.doubles_draw_size,16));

    drop table if exists pg_temp.cb_jd_pool;
    drop table if exists pg_temp.cb_jd;
    create temporary table cb_jd_pool(
      player_id bigint primary key,
      rankv int
    ) on commit drop;
    create temporary table cb_jd(
      entry_no int generated always as identity primary key,
      player_a_id bigint not null,
      player_b_id bigint not null,
      strength int not null,
      combined_rank int not null default 1999998,
      seed int,
      draw_slot int
    ) on commit drop;

    perform public.prepare_junior_doubles_reservations(t.id);

    insert into cb_jd(
      player_a_id,player_b_id,strength,combined_rank,seed,draw_slot
    )
    select
      r.player_a_id,r.player_b_id,r.pair_strength,r.combined_rank,r.seed,r.draw_slot
    from public.junior_doubles_reservations r
    where r.tournament_id=t.id
    order by r.draw_slot,r.player_a_id,r.player_b_id;

    select count(*) into v_pair_count from cb_jd;
    if v_pair_count<>v_draw then
      continue;
    end if;

    with s as (
      select entry_no,
             row_number() over(
               order by combined_rank asc,strength desc,entry_no
             )::int rn
      from cb_jd
    )
    update cb_jd e
    set seed=s.rn,draw_slot=s.rn
    from s
    where e.entry_no=s.entry_no;

    delete from public.world_junior_doubles_matches where tournament_id=t.id;
    delete from public.world_junior_doubles_entries where tournament_id=t.id;

    insert into public.world_junior_doubles_entries(
      tournament_id,player_a_id,player_b_id,seed,draw_slot,simulated_on
    )
    select t.id,player_a_id,player_b_id,seed,draw_slot,t.end_date
    from cb_jd
    order by seed;

    drop table if exists pg_temp.cb_jd_current;
    drop table if exists pg_temp.cb_jd_next;
    create temporary table cb_jd_current(pos int primary key,entry_id bigint) on commit drop;
    create temporary table cb_jd_next(pos int primary key,entry_id bigint) on commit drop;

    insert into cb_jd_current(pos,entry_id)
    select draw_slot,id
    from public.world_junior_doubles_entries
    where tournament_id=t.id;

    v_round:=1;

    while (select count(*) from cb_jd_current)>1 loop
      select count(*) into v_size from cb_jd_current;

      v_bracket:=1;
      while v_bracket<v_size loop
        v_bracket:=v_bracket*2;
      end loop;
      v_byes:=v_bracket-v_size;

      truncate cb_jd_next;
      v_next:=0;
      v_match_no:=0;

      v_code:=case
        when v_bracket>=64 then 'R64'
        when v_bracket>=32 then 'R32'
        when v_bracket>=16 then 'R16'
        when v_bracket>=8 then 'QF'
        when v_bracket>=4 then 'SF'
        else 'F' end;

      -- Highest seeds receive the byes needed to reduce the field to a
      -- power-of-two bracket. Byes are not stored as fake matches.
      if v_byes>0 then
        for rr in
          select c.entry_id
          from cb_jd_current c
          join public.world_junior_doubles_entries e on e.id=c.entry_id
          order by coalesce(e.seed,9999),c.pos
          limit v_byes
        loop
          v_next:=v_next+1;
          insert into cb_jd_next(pos,entry_id) values(v_next,rr.entry_id);
        end loop;
      end if;

      select array_agg(c.entry_id order by coalesce(e.seed,9999),c.pos)
      into v_round_entries
      from cb_jd_current c
      join public.world_junior_doubles_entries e on e.id=c.entry_id
      where not exists(
        select 1 from cb_jd_next n where n.entry_id=c.entry_id
      );

      if coalesce(array_length(v_round_entries,1),0)>0 then
        for v_pos in 1..array_length(v_round_entries,1) by 2 loop
          v_a:=v_round_entries[v_pos];
          v_b:=v_round_entries[v_pos+1];

          if v_a is null or v_b is null then
            raise exception 'Invalid junior doubles bracket at tournament %, round %, field %',t.id,v_round,v_size;
          end if;

          select d.strength into v_sa
          from public.world_junior_doubles_entries e
          join cb_jd d on d.player_a_id=e.player_a_id and d.player_b_id=e.player_b_id
          where e.id=v_a;

          select d.strength into v_sb
          from public.world_junior_doubles_entries e
          join cb_jd d on d.player_a_id=e.player_a_id and d.player_b_id=e.player_b_id
          where e.id=v_b;

          v_prob:=greatest(.08,least(.92,1/(1+exp(-(coalesce(v_sa,50)-coalesce(v_sb,50))/8.0))));
          v_awon:=random()<v_prob;
          v_w:=case when v_awon then v_a else v_b end;
          v_l:=case when v_awon then v_b else v_a end;
          v_score:=public.world_tournament_score(v_prob,v_awon,3);

          v_match_no:=v_match_no+1;
          insert into public.world_junior_doubles_matches(
            tournament_id,round_no,round_code,match_no,
            pair_a_entry_id,pair_b_entry_id,winner_entry_id,loser_entry_id,
            score,win_probability,simulated_on,model_version
          ) values(
            t.id,v_round,v_code,v_match_no,v_a,v_b,v_w,v_l,
            v_score,round(v_prob,4),t.end_date,'CB-JUNIOR-DOUBLES-v4-BYES'
          );
          v_matches:=v_matches+1;

          update public.world_junior_doubles_entries
          set result_code=v_code,
              points_awarded=public.junior_points_for('doubles',t.category,v_code),
              last_opponent=(
                select pa.name||' / '||pb.name
                from public.world_junior_doubles_entries oe
                join public.players pa on pa.id=oe.player_a_id
                join public.players pb on pb.id=oe.player_b_id
                where oe.id=v_w
              ),
              last_score=case when v_l=v_a then v_score else public.world_invert_tennis_score(v_score) end
          where id=v_l;

          update public.world_junior_doubles_entries
          set matches_won=matches_won+1
          where id=v_w;

          v_next:=v_next+1;
          insert into cb_jd_next(pos,entry_id) values(v_next,v_w);
        end loop;
      end if;

      truncate cb_jd_current;
      insert into cb_jd_current
      select row_number() over(order by pos)::int,entry_id
      from cb_jd_next
      order by pos;

      v_round:=v_round+1;
    end loop;

    select entry_id into v_winner from cb_jd_current limit 1;

    update public.world_junior_doubles_entries
    set result_code='W',
        points_awarded=public.junior_points_for('doubles',t.category,'W')
    where id=v_winner;

    update public.players p
    set junior_doubles_game_points=coalesce(p.junior_doubles_game_points,0)+e.points_awarded
    from public.world_junior_doubles_entries e
    where e.tournament_id=t.id
      and p.id in (e.player_a_id,e.player_b_id);

    for rr in
      select e.*,a.name a_name,b.name b_name
      from public.world_junior_doubles_entries e
      join public.players a on a.id=e.player_a_id
      join public.players b on b.id=e.player_b_id
      where e.id=v_winner
    loop
      insert into public.player_titles(
        player_id,tournament_name,title_date,level,surface,event_type,
        partner_player_id,partner_name,verified,source_label,origin
      )
      values
        (rr.player_a_id,t.name,t.end_date,t.category,t.surface,'junior_doubles',rr.player_b_id,rr.b_name,false,'Court Boss junior doubles full draw','game'),
        (rr.player_b_id,t.name,t.end_date,t.category,t.surface,'junior_doubles',rr.player_a_id,rr.a_name,false,'Court Boss junior doubles full draw','game')
      on conflict(player_id,tournament_name,title_date,event_type) do nothing;
    end loop;

    v_count:=v_count+1;
  end loop;

  return jsonb_build_object(
    'doubles_simulated',v_count,'matches_simulated',v_matches,
    'from',p_from_date,'to',p_to_date,'model','CB-JUNIOR-DOUBLES-v4 power-of-two bracket with real byes'
  );
end
$function$;

CREATE OR REPLACE FUNCTION public.sync_ncaa_career_row()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  mapped_status text;
  is_all_american boolean;
begin
  is_all_american := new.status ilike '%All-American%';
  mapped_status := case
    when new.status='Active' then 'Active'
    when new.status='Historical' then 'Alumni'
    else 'Recorded'
  end;

  insert into public.ncaa_career(
    player_id,school,division,start_season,end_season,status,departure_date,verified,
    source_url,source_label,all_american,last_verified_at
  )
  values(
    new.player_id,new.school,new.division,new.season,new.season,mapped_status,
    case when mapped_status='Alumni' then new.snapshot_date else null end,
    true,new.source_url,new.source_label,is_all_american,now()
  )
  on conflict(player_id) do update set
    school=excluded.school,
    division=excluded.division,
    start_season=coalesce(public.ncaa_career.start_season,excluded.start_season),
    end_season=case
      when public.ncaa_career.end_season is null then excluded.end_season
      when excluded.end_season is null then public.ncaa_career.end_season
      else greatest(public.ncaa_career.end_season,excluded.end_season)
    end,
    status=case
      when excluded.status='Active' then 'Active'
      when excluded.status='Alumni' then 'Alumni'
      else public.ncaa_career.status
    end,
    departure_date=case
      when excluded.status='Alumni' then coalesce(public.ncaa_career.departure_date,excluded.departure_date)
      else public.ncaa_career.departure_date
    end,
    verified=true,
    source_url=coalesce(excluded.source_url,public.ncaa_career.source_url),
    source_label=coalesce(excluded.source_label,public.ncaa_career.source_label),
    all_american=public.ncaa_career.all_american or excluded.all_american,
    last_verified_at=now();

  if mapped_status='Active' then
    update public.players
    set ncaa_current=true,
        ncaa_status='Active',
        ncaa_school=new.school,
        ncaa_team_id=public.resolve_ncaa_team_id(new.school),
        ncaa_last_school=new.school,
        ncaa_division=new.division,
        ncaa_rank=new.ita_rank,
        ncaa_verified=true
    where id=new.player_id;
  elsif mapped_status='Alumni' then
    update public.players
    set ncaa_current=false,
        ncaa_status='Alumni',
        ncaa_last_school=coalesce(new.school,ncaa_last_school),
        ncaa_school=null,
        ncaa_team_id=null,
        ncaa_rank=null,
        ncaa_verified=true
    where id=new.player_id;
  elsif is_all_american then
    update public.players
    set ncaa_verified=true,
        ncaa_last_school=coalesce(ncaa_last_school,new.school)
    where id=new.player_id;
  end if;

  return new;
end
$function$;

CREATE OR REPLACE FUNCTION public.sync_ncaa_registry_identity()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  active_row public.ncaa_player_registry%rowtype;
  has_active boolean:=false;
  first_season text;
  last_school text;
  last_division text;
  is_all_american boolean:=false;
begin
  select *
    into active_row
  from public.ncaa_player_registry
  where player_id=new.player_id
    and status='Active'
  order by snapshot_date desc nulls last, season desc, id desc
  limit 1;

  has_active := found;
  is_all_american := coalesce(new.status,'') ilike '%All-American%';

  select season
    into first_season
  from public.ncaa_player_registry
  where player_id=new.player_id
  order by snapshot_date asc nulls last, id asc
  limit 1;

  if has_active then
    insert into public.ncaa_career(
      player_id,school,division,start_season,end_season,status,verified,
      source_url,source_label,last_verified_at
    )
    values(
      new.player_id,
      active_row.school,
      active_row.division,
      coalesce(first_season,active_row.season),
      null,
      'Active',
      true,
      active_row.source_url,
      coalesce(active_row.source_label,'NCAA / ITA registry'),
      now()
    )
    on conflict(player_id) do update set
      school=excluded.school,
      division=excluded.division,
      start_season=coalesce(public.ncaa_career.start_season,excluded.start_season),
      end_season=null,
      status='Active',
      departure_date=null,
      verified=true,
      source_url=coalesce(excluded.source_url,public.ncaa_career.source_url),
      source_label=coalesce(excluded.source_label,public.ncaa_career.source_label),
      last_verified_at=now();

    update public.players
    set ncaa_current=true,
        ncaa_school=active_row.school,
        ncaa_team_id=public.resolve_ncaa_team_id(active_row.school),
        ncaa_division=active_row.division,
        ncaa_rank=active_row.ita_rank,
        ncaa_snapshot_date=active_row.snapshot_date,
        ncaa_status='Active',
        ncaa_last_school=coalesce(active_row.school,ncaa_last_school),
        ncaa_verified=true
    where id=new.player_id;

    return new;
  end if;

  select school,division
    into last_school,last_division
  from public.ncaa_player_registry
  where player_id=new.player_id
  order by snapshot_date desc nulls last, season desc, id desc
  limit 1;

  if old is not null and old.status='Active' and new.status<>'Active' then
    insert into public.ncaa_career(
      player_id,school,division,start_season,end_season,status,departure_date,
      verified,source_url,source_label,last_verified_at
    )
    values(
      new.player_id,
      coalesce(last_school,new.school),
      coalesce(last_division,new.division),
      coalesce(first_season,new.season),
      new.season,
      'Alumni',
      new.snapshot_date,
      true,
      new.source_url,
      coalesce(new.source_label,'NCAA / ITA registry · departure'),
      now()
    )
    on conflict(player_id) do update set
      school=coalesce(excluded.school,public.ncaa_career.school),
      division=coalesce(excluded.division,public.ncaa_career.division),
      end_season=excluded.end_season,
      status='Alumni',
      departure_date=excluded.departure_date,
      verified=true,
      source_url=coalesce(excluded.source_url,public.ncaa_career.source_url),
      source_label=coalesce(excluded.source_label,public.ncaa_career.source_label),
      last_verified_at=now();

    update public.players
    set ncaa_current=false,
        ncaa_school=null,
        ncaa_team_id=null,
        ncaa_division=null,
        ncaa_rank=null,
        ncaa_status='Alumni',
        ncaa_last_school=coalesce(last_school,new.school,ncaa_last_school),
        ncaa_verified=true
    where id=new.player_id;

    return new;
  end if;

  insert into public.ncaa_career(
    player_id,school,division,start_season,end_season,status,verified,
    source_url,source_label,last_verified_at
  )
  values(
    new.player_id,new.school,new.division,coalesce(first_season,new.season),new.season,
    'Recorded',true,new.source_url,coalesce(new.source_label,'NCAA / ITA historical record'),now()
  )
  on conflict(player_id) do update set
    school=coalesce(public.ncaa_career.school,excluded.school),
    division=coalesce(public.ncaa_career.division,excluded.division),
    start_season=coalesce(public.ncaa_career.start_season,excluded.start_season),
    verified=true,
    source_url=coalesce(public.ncaa_career.source_url,excluded.source_url),
    source_label=coalesce(public.ncaa_career.source_label,excluded.source_label),
    all_american=public.ncaa_career.all_american or is_all_american,
    last_verified_at=now();

  if is_all_american then
    update public.players
    set ncaa_verified=true,
        ncaa_last_school=coalesce(ncaa_last_school,new.school)
    where id=new.player_id;
  end if;

  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.sync_player_ncaa_lifecycle()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  school_name text;
  last_season text;
  explicit_exit_status boolean;
begin
  school_name := coalesce(new.ncaa_school, old.ncaa_school, new.ncaa_last_school, old.ncaa_last_school);

  select r.school, r.season
    into school_name, last_season
  from public.ncaa_player_registry r
  where r.player_id = new.id
  order by r.snapshot_date desc nulls last, r.season desc
  limit 1;

  school_name := coalesce(new.ncaa_school, old.ncaa_school, new.ncaa_last_school, old.ncaa_last_school, school_name);

  if coalesce(old.ncaa_current,false)=false and coalesce(new.ncaa_current,false)=true then
    new.ncaa_status := 'Active';
    new.ncaa_last_school := school_name;
    new.ncaa_team_id := public.resolve_ncaa_team_id(school_name);
    new.ncaa_verified := coalesce(new.ncaa_verified,false) or exists(
      select 1 from public.ncaa_player_registry r where r.player_id=new.id
    );

    insert into public.ncaa_career(player_id,school,division,start_season,status,verified,source_label,last_verified_at)
    values(
      new.id,
      coalesce(school_name,'NCAA'),
      coalesce(new.ncaa_division,'NCAA Division I'),
      last_season,
      'Active',
      new.ncaa_verified,
      'Court Boss NCAA lifecycle',
      now()
    )
    on conflict(player_id) do update set
      school=excluded.school,
      division=excluded.division,
      status='Active',
      verified=public.ncaa_career.verified or excluded.verified,
      last_verified_at=now();

  elsif coalesce(old.ncaa_current,false)=true and coalesce(new.ncaa_current,false)=false then
    explicit_exit_status :=
      new.ncaa_status is distinct from old.ncaa_status
      and coalesce(new.ncaa_status,'') not in ('','Active');

    new.ncaa_last_school := school_name;
    new.ncaa_team_id := null;
    new.ncaa_verified := coalesce(old.ncaa_verified,false) or exists(
      select 1 from public.ncaa_player_registry r where r.player_id=new.id
    );

    if not explicit_exit_status then
      new.ncaa_status := 'Alumni';

      insert into public.ncaa_career(player_id,school,division,end_season,status,departure_date,verified,source_label,last_verified_at)
      values(
        new.id,
        coalesce(school_name,'NCAA'),
        coalesce(old.ncaa_division,new.ncaa_division,'NCAA Division I'),
        last_season,
        'Alumni',
        coalesce(new.data_snapshot,current_date),
        new.ncaa_verified,
        'Court Boss NCAA lifecycle',
        now()
      )
      on conflict(player_id) do update set
        school=excluded.school,
        division=excluded.division,
        end_season=coalesce(public.ncaa_career.end_season,excluded.end_season),
        status='Alumni',
        departure_date=coalesce(public.ncaa_career.departure_date,excluded.departure_date),
        verified=public.ncaa_career.verified or excluded.verified,
        last_verified_at=now();
    end if;

  elsif coalesce(new.ncaa_current,false)=true then
    new.ncaa_status := 'Active';
    new.ncaa_last_school := school_name;
    new.ncaa_team_id := public.resolve_ncaa_team_id(school_name);
  end if;

  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.transition_junior_pathways(p_year integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  rec record;
  pro_count int:=0;
  pro_ranked_count int:=0;
  itf_only_count int:=0;
  ncaa_count int:=0;
  max_active_rank int:=0;
  team_count int:=0;
  school_name text;
  school_offset int;
  threshold int;
  roll int;
  gets_atp_rank boolean;
  season_label text:=p_year::text||'-'||right((p_year+1)::text,2);
begin
  select coalesce(max(p.ranking),0) into max_active_rank
  from public.players p
  where p.ranking_current=true and p.ranking is not null;

  select count(*) into team_count from public.college_teams;

  for rec in
    select p.*
    from public.players p
    where p.game_generated=true
      and p.career_status='active'
      and p.age is not null
      and p.age>=18
      and coalesce(p.ncaa_current,false)=false
      and p.turned_pro_year is null
      and p.ranking_current=false
      and (
        p.junior_source ilike 'Court Boss simulated junior%'
        or p.data_source in ('Court Boss youth reserve v7','Court Boss generated junior pathway v7')
      )
    order by p.potential desc,p.current_ability desc,p.id
  loop
    threshold:=case
      when rec.country='USA' then 62
      when rec.country in ('CAN','GBR','AUS') then 46
      when rec.potential>=90 then 34
      when rec.potential>=82 then 30
      when rec.potential>=75 then 24
      else 16
    end;
    roll:=mod(abs(hashtextextended(rec.id::text||'|'||p_year::text,97)),100)::int;

    if team_count>0 and roll<threshold then
      school_offset:=mod(rec.id::int,team_count);
      select ct.name into school_name
      from public.college_teams ct
      order by ct.ita_rank nulls last,ct.id
      limit 1 offset school_offset;

      update public.players
      set junior_ranking=null,junior_points=null,junior_snapshot_date=null,junior_source=null,
          ncaa_current=true,ncaa_status='Active',ncaa_school=school_name,
          ncaa_team_id=public.resolve_ncaa_team_id(school_name),ncaa_division='NCAA Division I',
          ncaa_rank=null,ncaa_snapshot_date=make_date(p_year,8,25),
          ncaa_source='Court Boss simulated NCAA pathway v7',
          ranking_current=false,ranking=null,source_ranking=null,
          ranking_source='NCAA pathway '||p_year,itf_ranking=null,
          data_snapshot=make_date(p_year,8,25)
      where id=rec.id;

      insert into public.ncaa_player_registry(
        player_id,ita_rank,school,division,season,status,snapshot_date,source_url,source_label
      )
      values(
        rec.id,null,school_name,'NCAA Division I',season_label,'Active',
        make_date(p_year,8,25),null,'Court Boss simulated NCAA pathway v7'
      )
      on conflict(player_id,season) do update
      set school=excluded.school,division=excluded.division,status=excluded.status,
          snapshot_date=excluded.snapshot_date,source_label=excluded.source_label;

      insert into public.ncaa_career(
        player_id,school,division,start_season,status,verified,source_label
      )
      values(
        rec.id,school_name,'NCAA Division I',p_year::text,'Active',false,
        'Court Boss simulated NCAA pathway v7'
      )
      on conflict(player_id) do update
      set school=excluded.school,division=excluded.division,start_season=excluded.start_season,
          status='Active',verified=false,source_label=excluded.source_label;

      ncaa_count:=ncaa_count+1;
    else
      pro_count:=pro_count+1;
      gets_atp_rank := rec.current_ability>=58
        or (rec.current_ability>=54 and rec.potential>=90)
        or (rec.current_ability>=56 and rec.potential>=84);

      if gets_atp_rank then pro_ranked_count:=pro_ranked_count+1;
      else itf_only_count:=itf_only_count+1;
      end if;

      update public.players
      set junior_ranking=null,junior_points=null,junior_snapshot_date=null,junior_source=null,
          ncaa_current=false,ncaa_status=null,ncaa_school=null,ncaa_team_id=null,
          ranking_current=gets_atp_rank,
          ranking=case when gets_atp_rank then max_active_rank+pro_ranked_count else null end,
          source_ranking=case when gets_atp_rank then max_active_rank+pro_ranked_count else null end,
          points=case when gets_atp_rank then greatest(coalesce(points,0),5+mod((id+p_year)::bigint,36)::int) else 0 end,
          itf_ranking=350+mod((id+p_year)::bigint,1650)::int,
          ranking_source=case when gets_atp_rank
            then 'Court Boss junior-to-pro ATP pathway '||p_year
            else 'Court Boss junior-to-ITF pathway '||p_year end,
          data_snapshot=make_date(p_year,1,5),
          turned_pro_year=coalesce(turned_pro_year,p_year)
      where id=rec.id;
    end if;
  end loop;

  perform public.refresh_game_world_ranks();

  return jsonb_build_object(
    'year',p_year,'to_ncaa',ncaa_count,'to_pro',pro_count,
    'to_atp_ranked',pro_ranked_count,'to_itf_only',itf_only_count,
    'total_transitioned',ncaa_count+pro_count
  );
end;
$function$;


-- Keep current player-facing school labels canonical while preserving the raw
-- source label in ncaa_player_registry / historical records.
update public.players p
set ncaa_team_id=public.resolve_ncaa_team_id(p.ncaa_school)
where p.ncaa_current=true
  and p.ncaa_school is not null
  and p.ncaa_team_id is distinct from public.resolve_ncaa_team_id(p.ncaa_school);

update public.players p
set ncaa_school=t.name,
    ncaa_last_school=case when p.ncaa_current=true then t.name else p.ncaa_last_school end
from public.college_teams t
where p.ncaa_current=true
  and p.ncaa_team_id=t.id
  and p.ncaa_school is distinct from t.name;
