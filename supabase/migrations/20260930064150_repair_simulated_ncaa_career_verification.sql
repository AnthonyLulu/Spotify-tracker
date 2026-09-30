
update public.ncaa_career c
set verified=false,
    last_verified_at=now()
where exists (
  select 1
  from public.ncaa_player_registry r
  where r.player_id=c.player_id
    and r.status='Active'
    and r.rank_source_kind='court_boss_projection'
)
and not exists (
  select 1
  from public.ncaa_player_registry r
  where r.player_id=c.player_id
    and r.status='Active'
    and r.ita_rank_official is not null
);
