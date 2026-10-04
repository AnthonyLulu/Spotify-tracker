CREATE OR REPLACE FUNCTION public.audit_live_world_link_v23()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
with managed as (
  select cs.managed_player_id player_id
  from public.career_state cs
  where cs.id='demo' and cs.managed_player_id is not null
  union
  select ar.player_id
  from public.academy_roster ar
  where ar.status='active' and ar.player_id is not null and ar.source_youth_id is null
),
singles_pending as (
  select m.*
  from public.world_tournament_matches m
  where m.winner_id is null
    and coalesce(m.matchup_components->>'status','')='managed_live_pending'
),
singles_bad_pending as (
  select p.id
  from singles_pending p
  where not exists(
    select 1 from managed g where g.player_id in (p.player_a_id,p.player_b_id)
  )
),
singles_sessions as (
  select
    s.id session_id,s.status,s.tournament_id,s.managed_player_id,s.opponent_id,
    nullif(s.stats->'_meta'->>'world_match_id','')::bigint world_match_id
  from public.live_match_sessions s
  where s.tournament_id is not null
    and coalesce(s.stats->'_meta'->>'match_type','singles')<>'doubles'
    and s.status in ('active','finished','completed','committed')
),
singles_broken as (
  select sl.session_id
  from singles_sessions sl
  left join public.world_tournament_matches m on m.id=sl.world_match_id
  where sl.world_match_id is not null
    and (
      m.id is null
      or m.tournament_id<>sl.tournament_id
      or not (
        (m.player_a_id=sl.managed_player_id and m.player_b_id=sl.opponent_id)
        or
        (m.player_b_id=sl.managed_player_id and m.player_a_id=sl.opponent_id)
      )
    )
),
singles_committed_without_world as (
  select sl.session_id
  from singles_sessions sl
  left join public.world_tournament_matches m on m.id=sl.world_match_id
  where sl.status='committed'
    and sl.world_match_id is not null
    and (m.id is null or m.winner_id is null)
),
doubles_pending as (
  select m.*,a.player_a_id a1,a.player_b_id a2,b.player_a_id b1,b.player_b_id b2
  from public.world_doubles_tournament_matches m
  left join public.world_doubles_partnerships a on a.id=m.pair_a_id
  left join public.world_doubles_partnerships b on b.id=m.pair_b_id
  where m.winner_pair_id is null
    and coalesce(m.matchup_components->>'status','')='managed_live_pending'
),
doubles_bad_pending as (
  select p.id
  from doubles_pending p
  where not exists(
    select 1 from managed g
    where g.player_id in (p.a1,p.a2,p.b1,p.b2)
  )
),
doubles_sessions as (
  select
    s.id session_id,s.status,s.tournament_id,s.managed_player_id,
    nullif(s.stats->'_meta'->'doubles'->>'world_match_id','')::bigint world_match_id,
    nullif(s.stats->'_meta'->'doubles'->>'user_pair_id','')::bigint user_pair_id,
    nullif(s.stats->'_meta'->'doubles'->>'opponent_pair_id','')::bigint opponent_pair_id
  from public.live_match_sessions s
  where s.tournament_id is not null
    and s.stats->'_meta'->>'match_type'='doubles'
    and s.status in ('active','finished','completed','committed')
),
doubles_broken as (
  select ds.session_id
  from doubles_sessions ds
  left join public.world_doubles_tournament_matches m on m.id=ds.world_match_id
  where ds.world_match_id is not null
    and (
      m.id is null
      or m.tournament_id<>ds.tournament_id
      or ds.user_pair_id is null
      or ds.opponent_pair_id is null
      or not (
        (m.pair_a_id=ds.user_pair_id and m.pair_b_id=ds.opponent_pair_id)
        or
        (m.pair_b_id=ds.user_pair_id and m.pair_a_id=ds.opponent_pair_id)
      )
    )
),
doubles_committed_without_world as (
  select ds.session_id
  from doubles_sessions ds
  left join public.world_doubles_tournament_matches m on m.id=ds.world_match_id
  where ds.status='committed'
    and ds.world_match_id is not null
    and (m.id is null or m.winner_pair_id is null)
)
select jsonb_build_object(
  'ok',
    (select count(*) from singles_bad_pending)=0
    and (select count(*) from singles_broken)=0
    and (select count(*) from singles_committed_without_world)=0
    and (select count(*) from doubles_bad_pending)=0
    and (select count(*) from doubles_broken)=0
    and (select count(*) from doubles_committed_without_world)=0,
  'singles',jsonb_build_object(
    'pending_managed_matches',(select count(*) from singles_pending),
    'pending_without_managed_player',(select count(*) from singles_bad_pending),
    'broken_session_world_links',(select count(*) from singles_broken),
    'committed_sessions_without_world_result',(select count(*) from singles_committed_without_world)
  ),
  'doubles',jsonb_build_object(
    'pending_managed_matches',(select count(*) from doubles_pending),
    'pending_without_managed_player',(select count(*) from doubles_bad_pending),
    'broken_session_world_links',(select count(*) from doubles_broken),
    'committed_sessions_without_world_result',(select count(*) from doubles_committed_without_world)
  ),
  'model','CB-LIVE-WORLD-LINK-AUDIT-v23.1'
);
$function$;
revoke all on function public.audit_live_world_link_v23() from public,anon,authenticated;
grant execute on function public.audit_live_world_link_v23() to service_role;
