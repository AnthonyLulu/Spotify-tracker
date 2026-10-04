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

  -- World-rank refresh is deferred to the owning supply/newgen batch.
  -- Both callers already refresh after all pathway mutations, avoiding a duplicate full-world pass.

  return jsonb_build_object(
    'year',p_year,'to_ncaa',ncaa_count,'to_pro',pro_count,
    'to_atp_ranked',pro_ranked_count,'to_itf_only',itf_only_count,
    'total_transitioned',ncaa_count+pro_count,
    'ncaa_entry_min_age',18,'ncaa_entry_max_age',22,'world_rank_refresh_deferred',true
  );
end;
$function$
