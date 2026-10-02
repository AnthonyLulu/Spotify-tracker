alter table public.tournament_runs add column if not exists managed_player_id bigint;
alter table public.doubles_runs add column if not exists managed_player_id bigint;
alter table public.user_ranking_points add column if not exists player_id bigint;
alter table public.user_doubles_points add column if not exists player_id bigint;

do $$
declare v_primary bigint;
begin
  select managed_player_id into v_primary from public.career_state where id='demo';
  if v_primary is not null then
    update public.tournament_runs set managed_player_id=v_primary where managed_player_id is null;
    update public.doubles_runs set managed_player_id=v_primary where managed_player_id is null;
    update public.user_ranking_points set player_id=v_primary where player_id is null and owner_id='demo';
    update public.user_doubles_points set player_id=v_primary where player_id is null and owner_id='demo';
  end if;
end $$;

do $$
begin
  if not exists(select 1 from pg_constraint where conname='tournament_runs_managed_player_id_fkey') then
    alter table public.tournament_runs
      add constraint tournament_runs_managed_player_id_fkey
      foreign key(managed_player_id) references public.players(id) on delete set null;
  end if;
  if not exists(select 1 from pg_constraint where conname='doubles_runs_managed_player_id_fkey') then
    alter table public.doubles_runs
      add constraint doubles_runs_managed_player_id_fkey
      foreign key(managed_player_id) references public.players(id) on delete set null;
  end if;
  if not exists(select 1 from pg_constraint where conname='user_ranking_points_player_id_fkey') then
    alter table public.user_ranking_points
      add constraint user_ranking_points_player_id_fkey
      foreign key(player_id) references public.players(id) on delete cascade;
  end if;
  if not exists(select 1 from pg_constraint where conname='user_doubles_points_player_id_fkey') then
    alter table public.user_doubles_points
      add constraint user_doubles_points_player_id_fkey
      foreign key(player_id) references public.players(id) on delete cascade;
  end if;
end $$;

create index if not exists tournament_runs_managed_player_idx
  on public.tournament_runs(managed_player_id,tournament_id);
create index if not exists doubles_runs_managed_player_idx
  on public.doubles_runs(managed_player_id,tournament_id);
create index if not exists user_ranking_points_player_idx
  on public.user_ranking_points(player_id,active,expiry_date);
create index if not exists user_doubles_points_player_idx
  on public.user_doubles_points(player_id,active,expiry_date);

create unique index if not exists tournament_runs_player_tournament_uidx
  on public.tournament_runs(tournament_id,managed_player_id)
  where managed_player_id is not null;
create unique index if not exists doubles_runs_player_tournament_uidx
  on public.doubles_runs(tournament_id,managed_player_id)
  where managed_player_id is not null;

alter table public.managed_doubles_entries
  drop constraint if exists managed_doubles_entries_owner_id_tournament_id_key;

create unique index if not exists managed_doubles_entries_owner_tournament_player_uidx
  on public.managed_doubles_entries(owner_id,tournament_id,player_id);
