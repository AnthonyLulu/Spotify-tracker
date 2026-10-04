create index if not exists idx_players_active_nextgen_birth_v22
on public.players (birth_date,id)
include (race_points,race_ranking,ranking)
where career_status='active' and birth_date is not null;

CREATE OR REPLACE FUNCTION public.refresh_world_nextgen_race(p_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_date date:=coalesce(p_date,current_date);
  v_year int:=extract(year from v_date)::int;
  v_race jsonb;
  v_count int:=0;
  v_cleared int:=0;
begin
  v_race:=public.refresh_world_race(v_date);

  update public.players p
  set nextgen_points=null,
      nextgen_ranking=null,
      nextgen_snapshot_date=v_date,
      nextgen_source='Ineligible for PIF ATP Race to Next Gen Finals · ATP age rule'
  where (p.nextgen_ranking is not null or p.nextgen_points is not null)
    and not (
      p.career_status='active'
      and p.birth_date is not null
      and p.birth_date>=make_date(v_year-20,1,1)
      and p.birth_date<=make_date(v_year-13,12,31)
      and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
    );
  get diagnostics v_cleared=row_count;

  with eligible as (
    select
      p.id,
      coalesce(p.race_points,0)::int as race_points,
      coalesce(p.race_ranking,999999)::int as race_rank,
      coalesce(p.ranking,999999)::int as atp_rank
    from public.players p
    where p.career_status='active'
      and p.birth_date is not null
      and p.birth_date>=make_date(v_year-20,1,1)
      and p.birth_date<=make_date(v_year-13,12,31)
      and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
  ),
  ranked as (
    select
      e.id,
      e.race_points,
      row_number() over(
        order by e.race_points desc,e.race_rank asc,e.atp_rank asc,e.id
      )::int as nextgen_rank
    from eligible e
  )
  update public.players p
  set nextgen_points=r.race_points,
      nextgen_ranking=r.nextgen_rank,
      nextgen_snapshot_date=v_date,
      nextgen_source='PIF ATP Race to Next Gen Finals · same season points as ATP Race'
  from ranked r
  where p.id=r.id;

  get diagnostics v_count=row_count;

  return jsonb_build_object(
    'date',v_date,
    'season',v_year,
    'ranked',v_count,
    'cleared_ineligible',v_cleared,
    'age_rule','20 or under throughout calendar year',
    'points_engine','same ATP Race season points',
    'race_refresh',v_race
  );
end;
$function$;
