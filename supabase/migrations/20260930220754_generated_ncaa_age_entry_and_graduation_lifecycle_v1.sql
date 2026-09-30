-- Generated NCAA lifecycle rules.
-- Entry: age 18-22 for Court Boss generated juniors.
-- Exit: normal graduation after 4+ college years, fifth-year extension possible,
-- age 25 strongly exits, and age 26 is an absolute cap.

CREATE OR REPLACE FUNCTION public.advance_ncaa_lifecycle(p_year integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  rec record;
  start_year integer;
  college_years integer;
  roll integer;
  exit_reason text;
  season_label text:=p_year::text||'-'||right((p_year+1)::text,2);
  max_active_rank integer:=0;
  ranked_added integer:=0;
  alumni_count integer:=0;
  normal_grad_count integer:=0;
  fifth_year_count integer:=0;
  age25_count integer:=0;
  hard_cap_count integer:=0;
  gets_atp_rank boolean;
begin
  select coalesce(max(ranking),0) into max_active_rank
  from public.players
  where ranking_current=true and ranking is not null;

  for rec in
    select p.*,c.start_season,c.school as career_school
    from public.players p
    left join public.ncaa_career c on c.player_id=p.id
    where p.game_generated=true
      and p.career_status='active'
      and p.ncaa_current=true
      and p.age is not null
    order by p.id
  loop
    begin
      start_year:=nullif(substring(coalesce(rec.start_season,'') from '([0-9]{4})'),'')::integer;
    exception when others then
      start_year:=null;
    end;

    if start_year is null then
      start_year:=greatest(2000,p_year-greatest(rec.age-18,0));
    end if;

    college_years:=greatest(0,p_year-start_year);
    roll:=mod(abs(hashtextextended(rec.id::text||'|ncaa-exit|'||p_year::text,211)),100)::integer;
    exit_reason:=null;

    if rec.age>=26 then
      exit_reason:='age_26_hard_cap';
      hard_cap_count:=hard_cap_count+1;
    elsif college_years>=6 then
      exit_reason:='sixth_year_hard_cap';
      hard_cap_count:=hard_cap_count+1;
    elsif rec.age>=25 and roll<92 then
      exit_reason:='age_25_graduation';
      age25_count:=age25_count+1;
    elsif college_years>=5 and roll<90 then
      exit_reason:='fifth_year_graduation';
      fifth_year_count:=fifth_year_count+1;
    elsif college_years>=4 and roll<72 then
      exit_reason:='standard_graduation';
      normal_grad_count:=normal_grad_count+1;
    end if;

    if exit_reason is null then
      continue;
    end if;

    gets_atp_rank:=coalesce(rec.ranking_current,false)
      or rec.current_ability>=58
      or (rec.current_ability>=54 and rec.potential>=90)
      or (rec.current_ability>=56 and rec.potential>=84);

    if gets_atp_rank and not coalesce(rec.ranking_current,false) then
      ranked_added:=ranked_added+1;
    end if;

    update public.ncaa_player_registry
    set status='Historical',
        source_label=case
          when coalesce(source_label,'') ilike '%NCAA exit%' then source_label
          else concat_ws(' · ',nullif(source_label,''),'Court Boss NCAA exit '||p_year||' ('||exit_reason||')')
        end
    where player_id=rec.id
      and status='Active';

    update public.ncaa_career
    set end_season=season_label,
        status='Alumni',
        departure_date=make_date(p_year,1,5),
        source_label=concat_ws(' · ',nullif(source_label,''),'Court Boss NCAA lifecycle '||exit_reason),
        last_verified_at=now()
    where player_id=rec.id;

    update public.players
    set ncaa_current=false,
        ncaa_status='Alumni',
        ncaa_last_school=coalesce(ncaa_last_school,ncaa_school,rec.career_school),
        ncaa_school=null,
        ncaa_team_id=null,
        ncaa_rank=null,
        turned_pro_year=coalesce(turned_pro_year,p_year),
        ranking_current=gets_atp_rank,
        ranking=case
          when coalesce(rec.ranking_current,false) and rec.ranking is not null then rec.ranking
          when gets_atp_rank then max_active_rank+ranked_added
          else null
        end,
        source_ranking=case
          when coalesce(rec.ranking_current,false) and rec.ranking is not null then rec.ranking
          when gets_atp_rank then max_active_rank+ranked_added
          else null
        end,
        points=case
          when gets_atp_rank then greatest(coalesce(points,0),5+mod((id+p_year)::bigint,36)::int)
          else 0
        end,
        itf_ranking=case
          when gets_atp_rank then itf_ranking
          else coalesce(itf_ranking,350+mod((id+p_year)::bigint,1650)::int)
        end,
        ranking_source='Court Boss NCAA-to-pro '||p_year||' · '||exit_reason,
        data_snapshot=make_date(p_year,1,5)
    where id=rec.id;

    alumni_count:=alumni_count+1;
  end loop;

  if alumni_count>0 then
    perform public.refresh_game_world_ranks();
  end if;

  return jsonb_build_object(
    'year',p_year,
    'graduated',alumni_count,
    'standard_graduation',normal_grad_count,
    'fifth_year_graduation',fifth_year_count,
    'age25_graduation',age25_count,
    'hard_cap_exit',hard_cap_count,
    'new_atp_ranked',ranked_added,
    'entry_min_age',18,
    'entry_max_age',22,
    'absolute_ncaa_age_cap',26
  );
end
$function$;

REVOKE ALL ON FUNCTION public.advance_ncaa_lifecycle(integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.advance_ncaa_lifecycle(integer) TO service_role;

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
      and p.age between 18 and 22
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
          ncaa_source='Court Boss simulated NCAA pathway v8 · age 18-22 entry',
          ranking_current=false,ranking=null,source_ranking=null,
          ranking_source='NCAA pathway '||p_year,itf_ranking=null,
          data_snapshot=make_date(p_year,8,25)
      where id=rec.id;

      insert into public.ncaa_player_registry(
        player_id,ita_rank,school,division,season,status,snapshot_date,source_url,source_label
      )
      values(
        rec.id,null,school_name,'NCAA Division I',season_label,'Active',
        make_date(p_year,8,25),null,'Court Boss simulated NCAA pathway v8 · age 18-22 entry'
      )
      on conflict(player_id,season) do update
      set school=excluded.school,division=excluded.division,status=excluded.status,
          snapshot_date=excluded.snapshot_date,source_label=excluded.source_label;

      insert into public.ncaa_career(
        player_id,school,division,start_season,status,verified,source_label
      )
      values(
        rec.id,school_name,'NCAA Division I',p_year::text,'Active',false,
        'Court Boss simulated NCAA pathway v8 · age 18-22 entry'
      )
      on conflict(player_id) do update
      set school=excluded.school,division=excluded.division,
          start_season=coalesce(public.ncaa_career.start_season,excluded.start_season),
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
    'total_transitioned',ncaa_count+pro_count,
    'ncaa_entry_min_age',18,'ncaa_entry_max_age',22
  );
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
  if coalesce(old.ncaa_current,false)=false
     and coalesce(new.ncaa_current,false)=true
     and coalesce(new.game_generated,false)=true then
    if new.age is null or new.age < 18 then
      raise exception 'Court Boss NCAA entry blocked: generated player % must be at least 18', new.id;
    end if;
    if new.age > 22 then
      raise exception 'Court Boss NCAA entry blocked: generated player % is too old to begin NCAA at age %', new.id, new.age;
    end if;
  end if;

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
      start_season=coalesce(public.ncaa_career.start_season,excluded.start_season),
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

CREATE OR REPLACE FUNCTION public.rollover_season(p_new_year integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  c career_state%rowtype;
  title_count int;
  final_count int;
  prize numeric;
  retired_count int := 0;
  processed_count int := 0;
  newgen_result jsonb;
  ncaa_result jsonb;
begin
  select * into c from career_state where id='demo';
  if not found then raise exception 'Career not found'; end if;

  select count(*) filter(where user_round='Champion'),
         count(*) filter(where user_round in ('Champion','F')),
         coalesce(sum(user_prize),0)
    into title_count,final_count,prize
  from tournament_runs
  where extract(year from played_at)=c.season_year;

  insert into season_history(season_year,final_rank,doubles_rank,titles,finals,prize_money,points)
  values(c.season_year,c.singles_rank,c.doubles_rank,title_count,final_count,prize,c.points)
  on conflict(season_year) do update set
    final_rank=excluded.final_rank,doubles_rank=excluded.doubles_rank,titles=excluded.titles,
    finals=excluded.finals,prize_money=excluded.prize_money,points=excluded.points;

  update players
  set age=case
    when birth_date is not null then extract(year from age(make_date(p_new_year,1,5),birth_date))::int
    when age is not null then age+1
    else null
  end
  where birth_date is not null or age is not null;

  select public.advance_ncaa_lifecycle(p_new_year) into ncaa_result;

  update players
  set
    current_ability=greatest(30,least(potential,
      current_ability +
      case
        when age is not null and age<=23 and potential>current_ability and ((id+p_new_year)%4)=0 then 1
        when age is not null and age>=34 and ((id+p_new_year)%3)=0 then -1
        else 0
      end
    )),
    potential=greatest(current_ability,
      potential - case when age is not null and age>=30 and ((id+p_new_year)%5)=0 then 1 else 0 end
    )
  where ranking_current=true;

  get diagnostics processed_count=row_count;

  update players
  set ranking_current=false,
      career_status='retired',
      ranking_source='Retired / inactive '||p_new_year
  where ranking_current=true
    and age is not null
    and (
      (age>=39 and ranking>250 and ((id+p_new_year)%3)=0)
      or (age>=37 and ranking>800 and ((id+p_new_year)%4)=0)
    );

  get diagnostics retired_count=row_count;

  select public.generate_newgens(p_new_year) into newgen_result;

  update career_state
  set season_year=p_new_year,age=age+1,week=1,career_date=make_date(p_new_year,1,5),
      fatigue=greatest(5,fatigue-20),fitness=least(100,fitness+10),morale=least(100,morale+5),
      injury_status='Fit',updated_at=now()
  where id='demo';

  update college_career_state
  set eligibility_years=greatest(0,eligibility_years-1),
      academic_progress=greatest(45,academic_progress-5),
      coach_trust=greatest(40,coach_trust-4)
  where id='demo' and status='committed';

  update sponsor_offers set status='available' where status='declined';

  return jsonb_build_object(
    'new_year',p_new_year,'retired_players',retired_count,'processed_players',processed_count,
    'newgens',newgen_result,'ncaa_lifecycle',ncaa_result,
    'previous_titles',title_count,'previous_prize',prize
  );
end
$function$;

