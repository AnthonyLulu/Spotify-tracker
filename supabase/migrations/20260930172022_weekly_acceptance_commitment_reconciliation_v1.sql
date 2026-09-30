
create table if not exists public.world_acceptance_conflict_audit(
  id bigint generated always as identity primary key,
  resolved_on date not null,
  player_id bigint not null references public.players(id) on delete cascade,
  week_start date not null,
  kept_tournament_id bigint not null references public.tournaments(id) on delete cascade,
  released_tournament_id bigint not null references public.tournaments(id) on delete cascade,
  kept_phase text not null,
  released_phase text not null,
  kept_score numeric,
  released_score numeric,
  reason text not null default 'weekly_commitment_reconcile',
  created_at timestamptz not null default now()
);

create index if not exists idx_world_acceptance_conflict_audit_player_week
  on public.world_acceptance_conflict_audit(player_id,week_start,resolved_on);
create index if not exists idx_world_acceptance_conflict_audit_released
  on public.world_acceptance_conflict_audit(released_tournament_id,resolved_on);
alter table public.world_acceptance_conflict_audit enable row level security;

create or replace function public.world_acceptance_commitment_score(
  p_player_id bigint,
  p_tournament_id bigint,
  p_phase text default 'main',
  p_entry_method text default null
) returns numeric
language plpgsql
stable
set search_path to 'public'
as $function$
declare
  p public.players%rowtype;
  t public.tournaments%rowtype;
  sp public.player_season_plans%rowtype;
  v_rank int;
  v_prob numeric;
  v_prestige numeric;
  v_score numeric;
  v_phase text:=lower(coalesce(p_phase,'main'));
  v_method text:=lower(coalesce(p_entry_method,''));
  v_ref date;
begin
  select * into p from public.players where id=p_player_id;
  select * into t from public.tournaments where id=p_tournament_id;
  if p.id is null or t.id is null then return -999999; end if;

  select * into sp
  from public.player_season_plans s
  where s.player_id=p.id and s.season=extract(year from t.start_date)::int;

  v_ref:=case
    when v_phase='qualifying' then coalesce(t.qualifying_entry_deadline,t.main_entry_deadline,t.start_date-18)
    else coalesce(t.main_entry_deadline,t.singles_entry_deadline,t.deadline,t.start_date-21)
  end;
  v_rank:=coalesce(
    public.player_rank_at_date(p.id,v_ref),
    case when p.ranking_current then p.ranking end,
    p.game_world_rank,p.ranking,999999
  );

  v_prob:=public.ai_tournament_commitment_probability(
    v_rank,
    coalesce(sp.plan_type,'tour_regular'),
    coalesce(sp.target_events,22),
    sp.preferred_surface,
    t.surface,
    t.category,
    p.country,
    t.country,
    coalesce(p.fatigue,20),
    coalesce(sp.rest_trigger_fatigue,72)
  );

  v_prestige:=case
    when t.category='Grand Chelem' then 100
    when t.category='Masters 1000' then 90
    when t.category='ATP 500' then 76
    when t.category='ATP 250' then 64
    when t.category='ATP Finals' then 98
    when t.category='Next Gen Finals' then 84
    when t.category='Challenger 175' then 56
    when t.category='Challenger 125' then 51
    when t.category='Challenger 100' then 47
    when t.category='Challenger 75' then 43
    when t.category='Challenger 50' then 39
    when t.category='M25' then 27
    when t.category='M15' then 22
    else 20
  end;

  v_score:=v_prob+v_prestige
    +case when v_phase='main' then 18 else 0 end
    +least(8,greatest(-4,coalesce(sp.prestige_bias,10)*.25))
    +case
       when v_method in (
         'junior_accelerator','college_accelerator','nextgen_accelerator',
         'junior_accelerator_qualifying','college_accelerator_qualifying',
         'nextgen_accelerator_qualifying','special_exempt','performance_bye'
       ) then 5
       else 0
     end;

  return round(v_score,3);
end;
$function$;

create or replace function public.reconcile_world_acceptance_commitments(
  p_from_date date,
  p_to_date date
) returns jsonb
language plpgsql
set search_path to 'public'
as $function$
declare
  v_iter int:=0;
  v_conflicts int:=0;
  v_released int:=0;
  v_final_conflicts int:=0;
  rec record;
begin
  if p_to_date<=date '2025-12-01' then
    return jsonb_build_object('ok',true,'released',0,'historical_cutoff',true);
  end if;

  drop table if exists pg_temp.cb_reconcile_weeks;
  drop table if exists pg_temp.cb_reconcile_ranked;
  drop table if exists pg_temp.cb_reconcile_affected;

  create temporary table cb_reconcile_weeks(
    week_start date primary key
  ) on commit drop;

  insert into cb_reconcile_weeks(week_start)
  select distinct date_trunc('week',coalesce(t.main_draw_start_date,t.start_date)::timestamp)::date
  from public.world_tournament_acceptance_states s
  join public.tournaments t on t.id=s.tournament_id
  where coalesce(s.last_refreshed_on,s.frozen_on) between p_from_date and p_to_date
  union
  select distinct date_trunc('week',coalesce(t.main_draw_start_date,t.start_date)::timestamp)::date
  from public.world_qualifying_acceptance_states s
  join public.tournaments t on t.id=s.tournament_id
  where coalesce(s.last_refreshed_on,s.created_on) between p_from_date and p_to_date
  on conflict do nothing;

  if not exists(select 1 from cb_reconcile_weeks) then
    return jsonb_build_object('ok',true,'released',0,'weeks',0,'iterations',0);
  end if;

  create temporary table cb_reconcile_affected(
    tournament_id bigint primary key
  ) on commit drop;

  loop
    v_iter:=v_iter+1;
    truncate cb_reconcile_affected;
    drop table if exists pg_temp.cb_reconcile_ranked;

    create temporary table cb_reconcile_ranked on commit drop as
    with commitments as (
      select
        e.player_id,e.tournament_id,'main'::text phase,e.entry_method,
        date_trunc('week',coalesce(t.main_draw_start_date,t.start_date)::timestamp)::date week_start,
        public.world_acceptance_commitment_score(e.player_id,e.tournament_id,'main',e.entry_method) score
      from public.world_tournament_acceptance_entries e
      join public.tournaments t on t.id=e.tournament_id
      join cb_reconcile_weeks w
        on w.week_start=date_trunc('week',coalesce(t.main_draw_start_date,t.start_date)::timestamp)::date
      where e.status in ('accepted','promoted')

      union all

      select
        e.player_id,e.tournament_id,'qualifying'::text phase,e.entry_method,
        date_trunc('week',coalesce(t.main_draw_start_date,t.start_date)::timestamp)::date week_start,
        public.world_acceptance_commitment_score(e.player_id,e.tournament_id,'qualifying',e.entry_method) score
      from public.world_qualifying_acceptance_entries e
      join public.tournaments t on t.id=e.tournament_id
      join cb_reconcile_weeks w
        on w.week_start=date_trunc('week',coalesce(t.main_draw_start_date,t.start_date)::timestamp)::date
      where e.status in ('accepted','promoted')
    ),
    ranked as (
      select c.*,
             row_number() over(
               partition by c.player_id,c.week_start
               order by c.score desc,
                        case when c.phase='main' then 0 else 1 end,
                        c.tournament_id
             )::int rn
      from commitments c
    )
    select * from ranked;

    select count(*) into v_conflicts
    from cb_reconcile_ranked
    where rn>1;

    exit when v_conflicts=0;

    insert into public.world_acceptance_conflict_audit(
      resolved_on,player_id,week_start,kept_tournament_id,released_tournament_id,
      kept_phase,released_phase,kept_score,released_score,reason
    )
    select
      p_to_date,l.player_id,l.week_start,w.tournament_id,l.tournament_id,
      w.phase,l.phase,w.score,l.score,'weekly_commitment_score'
    from cb_reconcile_ranked l
    join cb_reconcile_ranked w
      on w.player_id=l.player_id and w.week_start=l.week_start and w.rn=1
    where l.rn>1;

    insert into cb_reconcile_affected(tournament_id)
    select distinct tournament_id
    from cb_reconcile_ranked
    where rn>1
    on conflict do nothing;

    update public.world_tournament_acceptance_entries e
    set status='withdrawn',
        withdrawn_on=p_to_date,
        withdrawal_phase='schedule_reconcile',
        withdrawal_reason='accepted_other_event',
        updated_at=now()
    from cb_reconcile_ranked l
    where l.rn>1 and l.phase='main'
      and e.tournament_id=l.tournament_id and e.player_id=l.player_id
      and e.status in ('accepted','promoted');

    update public.world_qualifying_acceptance_entries e
    set status='withdrawn',
        withdrawn_on=p_to_date,
        withdrawal_phase='schedule_reconcile',
        withdrawal_reason='accepted_other_event',
        updated_at=now()
    from cb_reconcile_ranked l
    where l.rn>1 and l.phase='qualifying'
      and e.tournament_id=l.tournament_id and e.player_id=l.player_id
      and e.status in ('accepted','promoted');

    v_released:=v_released+v_conflicts;

    for rec in select tournament_id from cb_reconcile_affected order by tournament_id loop
      if exists(select 1 from public.world_tournament_acceptance_states s where s.tournament_id=rec.tournament_id) then
        perform public.refresh_world_tournament_acceptance_list(rec.tournament_id,p_to_date);
      end if;
      if exists(select 1 from public.world_qualifying_acceptance_states s where s.tournament_id=rec.tournament_id) then
        perform public.refresh_world_qualifying_acceptance_list(rec.tournament_id,p_to_date);
      end if;
    end loop;

    exit when v_iter>=5;
  end loop;

  select count(*) into v_final_conflicts
  from (
    select x.player_id,x.week_start
    from (
      select e.player_id,
             date_trunc('week',coalesce(t.main_draw_start_date,t.start_date)::timestamp)::date week_start
      from public.world_tournament_acceptance_entries e
      join public.tournaments t on t.id=e.tournament_id
      join cb_reconcile_weeks w
        on w.week_start=date_trunc('week',coalesce(t.main_draw_start_date,t.start_date)::timestamp)::date
      where e.status in ('accepted','promoted')
      union all
      select e.player_id,
             date_trunc('week',coalesce(t.main_draw_start_date,t.start_date)::timestamp)::date
      from public.world_qualifying_acceptance_entries e
      join public.tournaments t on t.id=e.tournament_id
      join cb_reconcile_weeks w
        on w.week_start=date_trunc('week',coalesce(t.main_draw_start_date,t.start_date)::timestamp)::date
      where e.status in ('accepted','promoted')
    ) x
    group by x.player_id,x.week_start
    having count(*)>1
  ) d;

  return jsonb_build_object(
    'ok',v_final_conflicts=0,
    'released',v_released,
    'remaining_conflicts',v_final_conflicts,
    'weeks',(select count(*) from cb_reconcile_weeks),
    'iterations',v_iter,
    'model','CB-WEEK-COMMIT-v1'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.simulate_world_qualifying_window(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t record;
  v_prepare jsonb;
  v_advance jsonb;
  v_prepared integer:=0;
  v_advanced integer:=0;
  v_completed integer:=0;
  v_matches integer:=0;
  v_skipped integer:=0;
  v_draw_date date;
begin
  if p_to_date<=date '2025-12-01' then
    return jsonb_build_object('qualifying_prepared',0,'historical_cutoff',true);
  end if;

  perform public.refresh_world_qualifying_acceptance_window(p_from_date,p_to_date);
  perform public.reconcile_world_acceptance_commitments(p_from_date,p_to_date);

  for t in
    select x.*
    from public.tournaments x
    where x.singles=true
      and coalesce(x.is_active,true)=true
      and coalesce(x.circuit,'') in ('ATP','Challenger','ITF')
      and coalesce(x.qualifying_draw_size,0)>0
      and coalesce(x.qualifying_end_date,x.start_date-1)>=greatest(p_from_date,date '2025-12-01')
      and coalesce(x.qualifying_signin_date,x.qualifying_start_date,x.start_date-1)<=p_to_date
    order by coalesce(x.qualifying_start_date,x.start_date-1),x.id
    limit 240
  loop
    v_draw_date:=coalesce(t.qualifying_signin_date,t.qualifying_start_date,t.start_date-1);

    if not exists(select 1 from public.world_qualifying_states s where s.tournament_id=t.id)
       and not exists(select 1 from public.world_tournament_qualifiers q where q.tournament_id=t.id)
       and v_draw_date<=p_to_date then
      v_prepare:=public.prepare_world_qualifying_tournament(t.id,v_draw_date);
      if coalesce((v_prepare->>'ok')::boolean,false) then
        v_prepared:=v_prepared+1;
      else
        v_skipped:=v_skipped+1;
        continue;
      end if;
    end if;

    if exists(select 1 from public.world_qualifying_states s where s.tournament_id=t.id) then
      v_advance:=public.advance_world_qualifying_tournament(t.id,p_to_date);
      if coalesce((v_advance->>'ok')::boolean,false) then
        if coalesce((v_advance->>'rounds_advanced')::int,0)>0 then v_advanced:=v_advanced+1; end if;
        v_matches:=v_matches+coalesce((v_advance->>'matches_played')::int,0);
        if v_advance->>'status'='completed' then v_completed:=v_completed+1; end if;
      else
        v_skipped:=v_skipped+1;
      end if;
    end if;
  end loop;

  return jsonb_build_object(
    'qualifying_prepared',v_prepared,
    'qualifying_advanced',v_advanced,
    'qualifying_completed',v_completed,
    'matches_played',v_matches,
    'skipped',v_skipped,
    'from',p_from_date,'to',p_to_date,
    'model','CB-MATCH-v6-PROGRESSIVE-Q'
  );
end;
$function$
;
