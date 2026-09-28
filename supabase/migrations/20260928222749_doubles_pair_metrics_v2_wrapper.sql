alter function public.doubles_pair_metrics(bigint,bigint,date)
rename to doubles_pair_metrics_v1;

create function public.doubles_pair_metrics(
  p_a bigint,
  p_b bigint,
  p_date date default current_date
)
returns table(
  chemistry integer,
  compatibility integer,
  pair_strength integer,
  affinity_score numeric
)
language sql
stable
set search_path to ''
as $$
with b as (
  select * from public.doubles_pair_metrics_v1(p_a,p_b,p_date)
),
a as (
  select
    coalesce(x.serve_power,10) asp,
    coalesce(x.serve_variety,10) asv,
    coalesce(x.return_aggression,10) ara,
    coalesce(x.half_volley,10) ahv,
    coalesce(x.smash,10) asm,
    coalesce(x.transition_game,10) atg,
    coalesce(x.reaction,10) are,
    coalesce(y.serve_power,10) bsp,
    coalesce(y.serve_variety,10) bsv,
    coalesce(y.return_aggression,10) bra,
    coalesce(y.half_volley,10) bhv,
    coalesce(y.smash,10) bsm,
    coalesce(y.transition_game,10) btg,
    coalesce(y.reaction,10) bre
  from public.player_attributes x
  join public.player_attributes y on y.player_id=p_b
  where x.player_id=p_a
),
s as (
  select b.*,
    ((asp+asv+ara+ahv+asm+atg+are+bsp+bsv+bra+bhv+bsm+btg+bre)::numeric/280)*100 detail_score
  from b cross join a
),
r as (
  select
    chemistry,
    greatest(35,least(99,compatibility+round((detail_score-50)*.08)::int)) compatibility2,
    greatest(30,least(99,pair_strength+round((detail_score-50)*.06)::int)) strength2
  from s
)
select
  chemistry,
  compatibility2,
  strength2,
  round(chemistry*.34+compatibility2*.44+strength2*.22,2)
from r;
$$;
