create table if not exists public.live_match_effect_commits_v23(
  session_id bigint not null references public.live_match_sessions(id) on delete cascade,
  effect text not null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  primary key(session_id,effect)
);

alter table public.live_match_effect_commits_v23 enable row level security;
revoke all on table public.live_match_effect_commits_v23 from public,anon,authenticated;

CREATE OR REPLACE FUNCTION public.ensure_live_match_history_v23(p_session_id bigint, p_managed_player_id bigint, p_tournament_name text, p_match_date date, p_surface text, p_round text, p_player_a text, p_player_b text, p_winner text, p_score text, p_match_data jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_existing jsonb;
  v_history_id bigint;
begin
  perform 1 from public.live_match_sessions where id=p_session_id for update;
  if not found then
    return jsonb_build_object('ok',false,'error','session_missing');
  end if;

  select payload into v_existing
  from public.live_match_effect_commits_v23
  where session_id=p_session_id and effect='history';

  if v_existing is not null then
    return jsonb_build_object(
      'ok',true,'already_applied',true,
      'history_id',(v_existing->>'history_id')::bigint,
      'model','CB-LIVE-COMMIT-v23'
    );
  end if;

  insert into public.match_history(
    managed_player_id,tournament_name,match_date,surface,round,
    player_a,player_b,winner,score,user_involved,match_data
  ) values(
    p_managed_player_id,p_tournament_name,p_match_date,p_surface,p_round,
    p_player_a,p_player_b,p_winner,p_score,true,coalesce(p_match_data,'{}'::jsonb)
  )
  returning id into v_history_id;

  insert into public.live_match_effect_commits_v23(session_id,effect,payload)
  values(
    p_session_id,'history',
    jsonb_build_object('history_id',v_history_id)
  );

  return jsonb_build_object(
    'ok',true,'already_applied',false,
    'history_id',v_history_id,
    'model','CB-LIVE-COMMIT-v23'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.apply_live_match_condition_once_v23(p_session_id bigint, p_player_id bigint, p_condition jsonb, p_sync_career boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_existing jsonb;
  v_payload jsonb;
begin
  perform 1 from public.live_match_sessions where id=p_session_id for update;
  if not found then
    return jsonb_build_object('ok',false,'error','session_missing');
  end if;

  select payload into v_existing
  from public.live_match_effect_commits_v23
  where session_id=p_session_id and effect='condition';

  if v_existing is not null then
    return v_existing || jsonb_build_object(
      'ok',true,'already_applied',true,'model','CB-LIVE-COMMIT-v23'
    );
  end if;

  update public.players
  set fatigue=coalesce((p_condition->>'fatigue')::int,fatigue),
      fitness=coalesce((p_condition->>'fitness')::int,fitness),
      form=coalesce((p_condition->>'form')::int,form),
      morale=coalesce((p_condition->>'morale')::int,morale),
      injury_status=coalesce(nullif(p_condition->>'injury_status',''),injury_status)
  where id=p_player_id;

  if not found then
    return jsonb_build_object('ok',false,'error','player_missing');
  end if;

  if coalesce(p_sync_career,false) then
    update public.career_state
    set fatigue=coalesce((p_condition->>'fatigue')::int,fatigue),
        fitness=coalesce((p_condition->>'fitness')::int,fitness),
        form=coalesce((p_condition->>'form')::int,form),
        morale=coalesce((p_condition->>'morale')::int,morale),
        injury_status=coalesce(nullif(p_condition->>'injury_status',''),injury_status),
        updated_at=now()
    where id='demo';
  end if;

  v_payload:=jsonb_build_object(
    'player_id',p_player_id,
    'condition',coalesce(p_condition,'{}'::jsonb),
    'career_synced',coalesce(p_sync_career,false)
  );

  insert into public.live_match_effect_commits_v23(session_id,effect,payload)
  values(p_session_id,'condition',v_payload);

  return v_payload || jsonb_build_object(
    'ok',true,'already_applied',false,'model','CB-LIVE-COMMIT-v23'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.apply_live_match_elo_once_v23(p_session_id bigint, p_winner_id bigint, p_loser_id bigint, p_surface text, p_match_date date, p_doubles boolean DEFAULT false, p_weight numeric DEFAULT 1)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_existing jsonb;
  v_result jsonb;
begin
  perform 1 from public.live_match_sessions where id=p_session_id for update;
  if not found then
    return jsonb_build_object('ok',false,'error','session_missing');
  end if;

  select payload into v_existing
  from public.live_match_effect_commits_v23
  where session_id=p_session_id and effect=case when p_doubles then 'elo_doubles' else 'elo_singles' end;

  if v_existing is not null then
    return v_existing || jsonb_build_object(
      'ok',true,'already_applied',true,'model','CB-LIVE-COMMIT-v23'
    );
  end if;

  v_result:=public.update_player_elo_after_match(
    p_winner_id,p_loser_id,p_surface,p_match_date,p_doubles,p_weight
  );

  if coalesce((v_result->>'ok')::boolean,false)=false then
    raise exception 'ELO update failed: %',coalesce(v_result->>'error','unknown');
  end if;

  insert into public.live_match_effect_commits_v23(session_id,effect,payload)
  values(
    p_session_id,
    case when p_doubles then 'elo_doubles' else 'elo_singles' end,
    coalesce(v_result,'{}'::jsonb)
  );

  return coalesce(v_result,'{}'::jsonb) || jsonb_build_object(
    'already_applied',false,'model','CB-LIVE-COMMIT-v23'
  );
end;
$function$;

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
pending as (
  select m.*
  from public.world_tournament_matches m
  where m.winner_id is null
    and coalesce(m.matchup_components->>'status','')='managed_live_pending'
),
bad_pending as (
  select p.id
  from pending p
  where not exists(
    select 1 from managed g where g.player_id in (p.player_a_id,p.player_b_id)
  )
),
session_links as (
  select
    s.id session_id,
    s.status,
    s.tournament_id,
    s.managed_player_id,
    s.opponent_id,
    nullif(s.stats->'_meta'->>'world_match_id','')::bigint world_match_id
  from public.live_match_sessions s
  where s.tournament_id is not null
    and s.status in ('active','finished','completed','committed')
),
broken_links as (
  select sl.session_id
  from session_links sl
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
committed_without_world as (
  select sl.session_id
  from session_links sl
  left join public.world_tournament_matches m on m.id=sl.world_match_id
  where sl.status='committed'
    and sl.world_match_id is not null
    and (m.id is null or m.winner_id is null)
)
select jsonb_build_object(
  'ok',
    (select count(*) from bad_pending)=0
    and (select count(*) from broken_links)=0
    and (select count(*) from committed_without_world)=0,
  'pending_managed_matches',(select count(*) from pending),
  'pending_without_managed_player',(select count(*) from bad_pending),
  'broken_session_world_links',(select count(*) from broken_links),
  'committed_sessions_without_world_result',(select count(*) from committed_without_world),
  'model','CB-LIVE-WORLD-LINK-AUDIT-v23'
);
$function$;


revoke all on function public.ensure_live_match_history_v23(bigint,bigint,text,date,text,text,text,text,text,text,jsonb) from public,anon,authenticated;
grant execute on function public.ensure_live_match_history_v23(bigint,bigint,text,date,text,text,text,text,text,text,jsonb) to service_role;
revoke all on function public.apply_live_match_condition_once_v23(bigint,bigint,jsonb,boolean) from public,anon,authenticated;
grant execute on function public.apply_live_match_condition_once_v23(bigint,bigint,jsonb,boolean) to service_role;
revoke all on function public.apply_live_match_elo_once_v23(bigint,bigint,bigint,text,date,boolean,numeric) from public,anon,authenticated;
grant execute on function public.apply_live_match_elo_once_v23(bigint,bigint,bigint,text,date,boolean,numeric) to service_role;
revoke all on function public.audit_live_world_link_v23() from public,anon,authenticated;
grant execute on function public.audit_live_world_link_v23() to service_role;
