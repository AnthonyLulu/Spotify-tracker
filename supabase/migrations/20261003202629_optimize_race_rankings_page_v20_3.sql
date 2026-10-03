
create or replace function public.race_rankings_page_v20(
  p_date date,
  p_offset integer default 0,
  p_limit integer default 100,
  p_q text default null,
  p_country text default null
)
returns jsonb
language sql
stable
set search_path to 'public'
as $function$
with filtered as (
  select
    p.id,p.name,p.country,p.is_real,p.game_generated,p.career_status,
    p.ranking,p.ranking_current,p.game_world_rank,p.points,
    p.race_ranking,p.race_points,p.race_snapshot_date,p.race_source,
    p.age,p.age_source,p.age_snapshot_date,p.birth_date,
    p.current_ability,p.potential,p.form,p.fitness,p.morale,p.fatigue,p.style,
    p.data_source,p.photo_url,
    p.ncaa_current,p.ncaa_school,p.ncaa_status,p.ncaa_last_school,
    count(*) over() as total_count
  from public.players p
  where p.is_real=true
    and p.race_ranking is not null
    and p.race_source is not null
    and (p.race_snapshot_date is null or p.race_snapshot_date<=p_date)
    and (p.data_source is null or p.data_source not ilike 'hidden duplicate merged into %')
    and (
      nullif(btrim(coalesce(p_q,'')),'') is null
      or p.name_norm ilike '%'||p_q||'%'
    )
    and (
      nullif(btrim(coalesce(p_country,'')),'') is null
      or p.country=upper(p_country)
    )
  order by p.race_ranking,p.id
  offset greatest(0,coalesce(p_offset,0))
  limit greatest(1,least(200,coalesce(p_limit,100)))
),
packed as (
  select
    coalesce(max(total_count),0)::bigint as total_count,
    coalesce(
      jsonb_agg(
        to_jsonb(filtered) - 'total_count'
        order by race_ranking,id
      ),
      '[]'::jsonb
    ) as rows
  from filtered
)
select jsonb_build_object(
  'count',total_count,
  'rows',rows,
  'rankingDate',p_date,
  'source','ATP Race · Court Boss optimized page v20.3'
)
from packed;
$function$;

revoke all on function public.race_rankings_page_v20(date,integer,integer,text,text)
from public,anon,authenticated;

grant execute on function public.race_rankings_page_v20(date,integer,integer,text,text)
to service_role;
