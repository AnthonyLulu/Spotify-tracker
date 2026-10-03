-- Court Boss Hall of Fame V15 storage fix
create table if not exists public.future_hall_of_fame_v15(
  id bigint primary key references public.players(id) on delete cascade,
  name text not null,
  country text,
  birth_date date,
  career_status text,
  ranking integer,
  points integer,
  photo_url text,
  titles integer not null default 0,
  grand_slams integer not null default 0,
  masters integer not null default 0,
  tour_finals integer not null default 0,
  wins integer not null default 0,
  losses integer not null default 0,
  win_pct numeric,
  history_score integer not null default 0,
  inducted_on date,
  updated_at timestamptz not null default now()
);

alter table public.future_hall_of_fame_v15 enable row level security;
revoke all on table public.future_hall_of_fame_v15 from anon,authenticated;
grant select,insert,update,delete on table public.future_hall_of_fame_v15 to service_role;

create or replace view public.hall_of_fame_candidates as
select
  h.id,h.name,h.country,h.birth_date,h.career_status,h.ranking,h.points,h.photo_url,
  h.titles,h.grand_slams,h.masters,h.tour_finals,h.wins,h.losses,h.win_pct,h.history_score
from public.history_player_scores h
where h.grand_slams>=1 or h.titles>=25 or h.wins>=500
union all
select
  f.id,f.name,f.country,f.birth_date,f.career_status,f.ranking,f.points,f.photo_url,
  f.titles,f.grand_slams,f.masters,f.tour_finals,f.wins,f.losses,f.win_pct,f.history_score
from public.future_hall_of_fame_v15 f
where not exists(
  select 1 from public.history_player_scores h
  where h.id=f.id
    and (h.grand_slams>=1 or h.titles>=25 or h.wins>=500)
);

create or replace function public.refresh_hall_of_fame_dynamic_v15(p_date date default current_date)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_rows int:=0;
begin
  with title_stats as (
    select
      pt.player_id,
      count(*)::int as titles,
      count(*) filter(where lower(coalesce(pt.level,'')) ~ 'grand|slam')::int as slams,
      count(*) filter(where lower(coalesce(pt.level,'')) like '%1000%' or lower(coalesce(pt.level,'')) like '%masters%')::int as masters,
      count(*) filter(where lower(coalesce(pt.level,'')) like '%finals%')::int as finals
    from public.player_titles pt
    group by pt.player_id
  ),
  match_stats as (
    select player_id,sum(wins)::int as wins,sum(losses)::int as losses
    from (
      select winner_id as player_id,count(*)::int wins,0::int losses
      from public.world_tournament_matches
      where winner_id is not null group by winner_id
      union all
      select loser_id as player_id,0::int wins,count(*)::int losses
      from public.world_tournament_matches
      where loser_id is not null group by loser_id
    ) q
    group by player_id
  ),
  candidates as (
    select
      p.id,p.name,p.country,p.birth_date,p.career_status,p.ranking,p.points,p.photo_url,
      coalesce(ts.titles,0) as titles,
      coalesce(ts.slams,0) as grand_slams,
      coalesce(ts.masters,0) as masters,
      coalesce(ts.finals,0) as tour_finals,
      coalesce(ms.wins,0) as wins,
      coalesce(ms.losses,0) as losses,
      case when coalesce(ms.wins,0)+coalesce(ms.losses,0)>0
        then round(100.0*coalesce(ms.wins,0)/(coalesce(ms.wins,0)+coalesce(ms.losses,0)),1)
        else 0 end as win_pct,
      (
        coalesce(ts.slams,0)*10000
        +coalesce(ts.masters,0)*1200
        +coalesce(ts.finals,0)*1800
        +coalesce(ts.titles,0)*250
        +coalesce(p.weeks_at_no1,0)*80
        +case when coalesce(p.career_high_rank,9999)=1 then 3500
              when coalesce(p.career_high_rank,9999)<=5 then 1200
              when coalesce(p.career_high_rank,9999)<=10 then 500 else 0 end
        +coalesce(ms.wins,0)*15
      )::int as history_score
    from public.players p
    left join title_stats ts on ts.player_id=p.id
    left join match_stats ms on ms.player_id=p.id
    where lower(coalesce(p.career_status,''))='retired'
      and (
        coalesce(p.game_generated,false)=true
        or coalesce(p.retired_date,date '1900-01-01')>=date '2026-01-01'
      )
  )
  insert into public.future_hall_of_fame_v15(
    id,name,country,birth_date,career_status,ranking,points,photo_url,
    titles,grand_slams,masters,tour_finals,wins,losses,win_pct,history_score,
    inducted_on,updated_at
  )
  select
    id,name,country,birth_date,career_status,ranking,points,photo_url,
    titles,grand_slams,masters,tour_finals,wins,losses,win_pct,history_score,
    p_date,now()
  from candidates
  where grand_slams>0 or titles>=12 or history_score>=5000
  on conflict(id) do update set
    name=excluded.name,country=excluded.country,birth_date=excluded.birth_date,
    career_status=excluded.career_status,ranking=excluded.ranking,points=excluded.points,
    photo_url=coalesce(excluded.photo_url,public.future_hall_of_fame_v15.photo_url),
    titles=excluded.titles,grand_slams=excluded.grand_slams,masters=excluded.masters,
    tour_finals=excluded.tour_finals,wins=excluded.wins,losses=excluded.losses,
    win_pct=excluded.win_pct,history_score=excluded.history_score,
    updated_at=now();

  get diagnostics v_rows=row_count;

  return jsonb_build_object(
    'ok',true,'date',p_date,'refreshed',v_rows,
    'historical_total',(select count(*) from public.history_player_scores h where h.grand_slams>=1 or h.titles>=25 or h.wins>=500),
    'future_total',(select count(*) from public.future_hall_of_fame_v15),
    'total',(select count(*) from public.hall_of_fame_candidates),
    'model','CB-HALL-OF-FAME-v15'
  );
end;
$$;

revoke all on function public.refresh_hall_of_fame_dynamic_v15(date) from public,anon,authenticated;
grant execute on function public.refresh_hall_of_fame_dynamic_v15(date) to service_role;
