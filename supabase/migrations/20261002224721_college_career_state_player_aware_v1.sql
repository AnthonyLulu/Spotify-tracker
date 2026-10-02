create table if not exists public.college_offer_templates (
  team_id bigint primary key references public.college_teams(id) on delete cascade,
  scholarship_pct integer not null check (scholarship_pct between 0 and 100),
  role text not null,
  academic_fit integer not null default 70 check (academic_fit between 0 and 100),
  development_fit integer not null default 70 check (development_fit between 0 and 100),
  created_at timestamptz not null default now()
);

insert into public.college_offer_templates(team_id,scholarship_pct,role,academic_fit,development_fit)
select distinct on (team_id)
  team_id,scholarship_pct,role,academic_fit,development_fit
from public.college_offers
order by team_id,id
on conflict(team_id) do update set
  scholarship_pct=excluded.scholarship_pct,
  role=excluded.role,
  academic_fit=excluded.academic_fit,
  development_fit=excluded.development_fit;

alter table public.college_career_state
  add column if not exists player_id bigint references public.players(id) on delete cascade;

alter table public.college_offers
  add column if not exists player_id bigint references public.players(id) on delete cascade;

update public.college_career_state s
set player_id=c.managed_player_id
from public.career_state c
where s.id='demo'
  and c.id='demo'
  and s.player_id is null;

update public.college_offers o
set player_id=c.managed_player_id
from public.career_state c
where c.id='demo'
  and o.player_id is null;

create unique index if not exists college_career_state_player_uidx
  on public.college_career_state(player_id)
  where player_id is not null;

create unique index if not exists college_offers_player_team_uidx
  on public.college_offers(player_id,team_id)
  where player_id is not null;

create index if not exists college_offers_player_status_idx
  on public.college_offers(player_id,status);

create or replace function public.ensure_player_college_state(p_player_id bigint)
returns jsonb
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $function$
declare
  primary_id bigint;
  state_key text;
  inserted_offers integer:=0;
begin
  select managed_player_id into primary_id
  from public.career_state
  where id='demo';

  if p_player_id is null or p_player_id<=0 then
    raise exception 'player_id_required';
  end if;

  if p_player_id<>coalesce(primary_id,0)
     and not exists(
       select 1 from public.academy_roster
       where player_id=p_player_id and status='active'
     ) then
    raise exception 'player_not_in_managed_squad';
  end if;

  state_key:=case when p_player_id=primary_id then 'demo' else 'player:'||p_player_id::text end;

  insert into public.college_career_state(
    id,player_id,chosen_team_id,scholarship_pct,eligibility_years,status,
    academic_progress,coach_trust,lineup_position
  )
  values(state_key,p_player_id,null,0,4,'exploring',72,55,null)
  on conflict(id) do update set
    player_id=excluded.player_id;

  insert into public.college_offers(
    team_id,scholarship_pct,role,academic_fit,development_fit,status,player_id
  )
  select
    t.team_id,
    greatest(35,least(100,t.scholarship_pct
      + case
          when coalesce(p.potential,70)>=90 then 8
          when coalesce(p.potential,70)>=82 then 4
          when coalesce(p.potential,70)<65 then -8
          else 0
        end)),
    t.role,
    greatest(45,least(100,t.academic_fit + mod((p_player_id+t.team_id)::int,9)-4)),
    greatest(45,least(100,t.development_fit
      + case
          when coalesce(p.current_ability,50)>=65 then 4
          when coalesce(p.potential,70)>=85 then 5
          else 0
        end)),
    'available',
    p_player_id
  from public.college_offer_templates t
  cross join lateral (
    select current_ability,potential
    from public.players
    where id=p_player_id
  ) p
  where not exists(
    select 1 from public.college_offers o
    where o.player_id=p_player_id and o.team_id=t.team_id
  );

  get diagnostics inserted_offers=row_count;

  return jsonb_build_object(
    'ok',true,
    'player_id',p_player_id,
    'state_id',state_key,
    'offers_created',inserted_offers
  );
end
$function$;

revoke all on function public.ensure_player_college_state(bigint) from public,anon,authenticated;
grant execute on function public.ensure_player_college_state(bigint) to service_role;
