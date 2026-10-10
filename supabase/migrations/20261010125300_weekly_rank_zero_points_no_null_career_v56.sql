-- Court Boss weekly P0: players with 0 ATP points must not crash
-- a NOT NULL career_state.singles_rank update.
-- Before V56 refresh_world_rankings() clears p.ranking for 0-point
-- players, then assigns singles_rank=p.ranking, aborting the entire Sunday
-- world simulation if the managed player is unranked.
-- The fix temporarily keeps the last valid managed rank as an intact,
-- non-null fallback. This is NOT a claim that the ATP rank is still live;
-- the player row's ranking is NULL and needs a dedicated "NR" UI status.
-- Verified 2026-10-10 isolated Supabase: Dec 1->11: 10 daily commits,
-- real Sunday simulate_world_week, 1,800 world recovery updates,
-- one checkpoint, retry already_applied, full rollback.
-- Do not run a production migration merely on PR merge.
CREATE OR REPLACE FUNCTION public.refresh_world_rankings(p_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_date date:=coalesce(p_date,current_date);
  v_updated int:=0;
  v_dirty int:=0;
  v_leader text;
  v_managed bigint;
  v_zero_sync jsonb;
begin
  perform pg_advisory_xact_lock(94832021);
  v_zero_sync:=public.sync_atp_zero_pointers(v_date);
  select managed_player_id into v_managed from public.career_state where id='demo';

  update public.world_ranking_points
  set active=(expiry_date>=v_date)
  where active is distinct from (expiry_date>=v_date);

  update public.user_ranking_points
  set active=(expiry_date>=v_date)
  where active is distinct from (expiry_date>=v_date);

  create temporary table if not exists cb_rank_dirty(
    player_id bigint primary key
  ) on commit drop;
  truncate cb_rank_dirty;

  insert into cb_rank_dirty(player_id)
  select p.id
  from public.players p
  left join public.atp_ranking_metrics_cache c on c.player_id=p.id
  where p.career_status='active'
    and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
    and (
      p.ranking_current=true
      or c.player_id is not null
      or exists(select 1 from public.world_ranking_points w where w.player_id=p.id and w.active=true)
      or exists(select 1 from public.user_ranking_points u where coalesce(u.player_id,v_managed)=p.id and u.active=true)
    )
    and c.player_id is null
  on conflict do nothing;

  insert into cb_rank_dirty(player_id)
  select distinct l.player_id
  from public.atp_defending_points_ledger l
  join public.atp_ranking_metrics_cache c on c.player_id=l.player_id
  where (l.event_date>c.as_of_date and l.event_date<=v_date)
     or (l.drop_date>=c.as_of_date and l.drop_date<v_date)
  on conflict do nothing;

  insert into cb_rank_dirty(player_id)
  select distinct w.player_id
  from public.world_ranking_points w
  join public.atp_ranking_metrics_cache c on c.player_id=w.player_id
  where (w.earned_date>c.as_of_date and w.earned_date<=v_date)
     or (w.expiry_date>=c.as_of_date and w.expiry_date<v_date)
  on conflict do nothing;

  insert into cb_rank_dirty(player_id)
  select distinct coalesce(u.player_id,v_managed)
  from public.user_ranking_points u
  join public.atp_ranking_metrics_cache c on c.player_id=coalesce(u.player_id,v_managed)
  where coalesce(u.player_id,v_managed) is not null
    and (
      (u.earned_date>c.as_of_date and u.earned_date<=v_date)
      or (u.expiry_date>=c.as_of_date and u.expiry_date<v_date)
    )
  on conflict do nothing;

  insert into cb_rank_dirty(player_id)
  select distinct z.player_id
  from public.atp_ranking_zero_pointers z
  join public.atp_ranking_metrics_cache c on c.player_id=z.player_id
  where (z.earned_date>c.as_of_date and z.earned_date<=v_date)
     or (z.expiry_date>=c.as_of_date and z.expiry_date<v_date)
  on conflict do nothing;

  select count(*) into v_dirty from cb_rank_dirty;

  if v_dirty>0 then
    create temporary table if not exists cb_rank_pool(
      player_id bigint not null,
      event_key text not null,
      label text,
      earned_date date not null,
      drop_date date not null,
      points integer not null,
      rank_category text not null,
      source_kind text not null,
      estimated boolean not null default false,
      src_prio integer not null,
      primary key(player_id,event_key)
    ) on commit drop;
    truncate cb_rank_pool;

    insert into cb_rank_pool(
      player_id,event_key,label,earned_date,drop_date,points,rank_category,source_kind,estimated,src_prio
    )
    select l.player_id,l.source_event_key,l.tournament_name,l.event_date,l.drop_date,l.points,l.rank_category,
           'historical',l.is_estimated,3
    from public.atp_defending_points_ledger l
    join cb_rank_dirty d on d.player_id=l.player_id
    where l.event_date<=v_date and l.drop_date>=v_date
      and (l.points>=0 or l.rank_category='Reconciliation')
    on conflict(player_id,event_key) do update set
      label=excluded.label,earned_date=excluded.earned_date,drop_date=excluded.drop_date,
      points=excluded.points,rank_category=excluded.rank_category,source_kind=excluded.source_kind,
      estimated=excluded.estimated,src_prio=excluded.src_prio
    where excluded.src_prio<cb_rank_pool.src_prio;

    insert into cb_rank_pool(
      player_id,event_key,label,earned_date,drop_date,points,rank_category,source_kind,estimated,src_prio
    )
    select w.player_id,'game:'||w.tournament_id::text,w.label,w.earned_date,w.expiry_date,w.points,
      case
        when t.category='Grand Chelem' then 'Grand Slam'
        when t.category='Masters 1000' then 'M1000'
        when t.category='ATP Finals' then 'Finals'
        when t.category='United Cup' then 'United Cup'
        when t.category='ATP 500' then 'ATP500'
        when t.category='ATP 250' then 'ATP250'
        when t.circuit='Challenger' then 'Challenger'
        when t.circuit='ITF' then 'ITF'
        else coalesce(t.category,t.circuit,'Other')
      end,
      'world',false,2
    from public.world_ranking_points w
    join cb_rank_dirty d on d.player_id=w.player_id
    left join public.tournaments t on t.id=w.tournament_id
    where w.active=true and w.earned_date<=v_date and w.expiry_date>=v_date
      and not exists(
        select 1 from public.atp_ranking_zero_pointers z
        where z.player_id=w.player_id and z.tournament_id=w.tournament_id
          and z.active=true and z.earned_date<=v_date and z.expiry_date>=v_date
      )
    on conflict(player_id,event_key) do update set
      label=excluded.label,earned_date=excluded.earned_date,drop_date=excluded.drop_date,
      points=excluded.points,rank_category=excluded.rank_category,source_kind=excluded.source_kind,
      estimated=excluded.estimated,src_prio=excluded.src_prio
    where excluded.src_prio<cb_rank_pool.src_prio;

    insert into cb_rank_pool(
      player_id,event_key,label,earned_date,drop_date,points,rank_category,source_kind,estimated,src_prio
    )
    select z.player_id,'zero:'||z.tournament_id::text,coalesce(t.name,'Tournoi')||' · zero pointer',
           z.earned_date,z.expiry_date,0,z.rank_category,'zero_pointer',false,1
    from public.atp_ranking_zero_pointers z
    join cb_rank_dirty d on d.player_id=z.player_id
    left join public.tournaments t on t.id=z.tournament_id
    where z.active=true and z.earned_date<=v_date and z.expiry_date>=v_date
    on conflict(player_id,event_key) do update set
      label=excluded.label,earned_date=excluded.earned_date,drop_date=excluded.drop_date,
      points=excluded.points,rank_category=excluded.rank_category,source_kind=excluded.source_kind,
      estimated=excluded.estimated,src_prio=excluded.src_prio
    where excluded.src_prio<cb_rank_pool.src_prio;

    insert into cb_rank_pool(
      player_id,event_key,label,earned_date,drop_date,points,rank_category,source_kind,estimated,src_prio
    )
    select coalesce(u.player_id,v_managed),
           'game:'||coalesce(u.tournament_id::text,'legacy:'||u.id::text),
           u.label,u.earned_date,u.expiry_date,u.points,
      case
        when t.category='Grand Chelem' then 'Grand Slam'
        when t.category='Masters 1000' then 'M1000'
        when t.category='ATP Finals' then 'Finals'
        when t.category='United Cup' then 'United Cup'
        when t.category='ATP 500' then 'ATP500'
        when t.category='ATP 250' then 'ATP250'
        when t.circuit='Challenger' then 'Challenger'
        when t.circuit='ITF' then 'ITF'
        else case when u.tournament_id is null then 'Legacy' else coalesce(t.category,t.circuit,'Other') end
      end,
      'managed',(u.tournament_id is null),0
    from public.user_ranking_points u
    join cb_rank_dirty d on d.player_id=coalesce(u.player_id,v_managed)
    left join public.tournaments t on t.id=u.tournament_id
    where coalesce(u.player_id,v_managed) is not null
      and u.active=true and u.earned_date<=v_date and u.expiry_date>=v_date
      and (
        u.tournament_id is not null
        or not exists(
          select 1 from public.atp_defending_points_ledger h
          where h.player_id=coalesce(u.player_id,v_managed)
        )
      )
      and not exists(
        select 1 from public.atp_ranking_zero_pointers z
        where z.player_id=coalesce(u.player_id,v_managed)
          and z.tournament_id=u.tournament_id
          and z.active=true and z.earned_date<=v_date and z.expiry_date>=v_date
      )
    on conflict(player_id,event_key) do update set
      label=excluded.label,earned_date=excluded.earned_date,drop_date=excluded.drop_date,
      points=excluded.points,rank_category=excluded.rank_category,source_kind=excluded.source_kind,
      estimated=excluded.estimated,src_prio=excluded.src_prio
    where excluded.src_prio<cb_rank_pool.src_prio;

    create index if not exists cb_rank_pool_player_cat_idx
      on cb_rank_pool(player_id,rank_category,earned_date,points);

    with counts as (
      select d.player_id,
             count(p.event_key) filter(where p.rank_category in ('Grand Slam','M1000'))::int mandatory_events,
             count(p.event_key) filter(where p.rank_category not in ('Grand Slam','M1000','Finals','Reconciliation'))::int optional_events
      from cb_rank_dirty d
      left join cb_rank_pool p on p.player_id=d.player_id
      group by d.player_id
    ),
    slot_info as (
      select player_id,mandatory_events,optional_events,
             greatest(0,18-mandatory_events)::int optional_slots,
             greatest(0,least(3,optional_events-greatest(0,18-mandatory_events)))::int replacement_capacity
      from counts
    ),
    m_candidates0 as (
      select p.*,
             row_number() over(partition by p.player_id order by p.points asc,p.earned_date asc,p.event_key) rn
      from cb_rank_pool p
      where p.rank_category='M1000'
        and exists(
          select 1 from cb_rank_pool o
          where o.player_id=p.player_id
            and o.rank_category in ('ATP500','ATP250')
            and o.earned_date>p.earned_date and o.points>p.points
        )
    ),
    replace_m as (
      select m.player_id,m.event_key,m.earned_date,m.points
      from m_candidates0 m
      join slot_info s using(player_id)
      where m.rn<=s.replacement_capacity
    ),
    replacement_candidates0 as (
      select p.player_id,p.event_key,p.earned_date,p.points,
             row_number() over(partition by p.player_id order by p.points desc,p.earned_date desc,p.event_key) rn
      from cb_rank_pool p
      where p.rank_category in ('ATP500','ATP250')
        and exists(
          select 1 from replace_m m
          where m.player_id=p.player_id
            and p.earned_date>m.earned_date and p.points>m.points
        )
    ),
    replace_count as (
      select player_id,count(*)::int n
      from replace_m
      group by player_id
    ),
    replace_o as (
      select r.player_id,r.event_key
      from replacement_candidates0 r
      join replace_count c using(player_id)
      where r.rn<=c.n
    ),
    optional_ranked as (
      select p.player_id,p.event_key,
             row_number() over(partition by p.player_id order by p.points desc,p.earned_date desc,p.event_key) rn
      from cb_rank_pool p
      where p.rank_category not in ('Grand Slam','M1000','Finals','Reconciliation')
        and not exists(
          select 1 from replace_o r
          where r.player_id=p.player_id and r.event_key=p.event_key
        )
    ),
    classified as (
      select p.*,
        case
          when p.rank_category='Reconciliation' then true
          when p.rank_category='Grand Slam' then true
          when p.rank_category='M1000'
            and not exists(
              select 1 from replace_m m
              where m.player_id=p.player_id and m.event_key=p.event_key
            ) then true
          when p.rank_category='Finals' then true
          when exists(
            select 1 from replace_o r
            where r.player_id=p.player_id and r.event_key=p.event_key
          ) then true
          when exists(
            select 1
            from optional_ranked o
            join slot_info s using(player_id)
            where o.player_id=p.player_id
              and o.event_key=p.event_key
              and o.rn<=s.optional_slots
          ) then true
          else false
        end counting
      from cb_rank_pool p
    ),
    metrics as (
      select d.player_id,
             coalesce(sum(x.points) filter(where x.counting),0)::int total_points,
             coalesce(sum(x.points) filter(where x.rank_category in ('Grand Slam','M1000','Finals')),0)::int mandatory_tiebreak_points,
             count(x.event_key) filter(where x.rank_category<>'Reconciliation')::int events_played,
             coalesce(
               array_agg(x.points order by x.points desc,x.earned_date desc)
                 filter(where x.counting and x.rank_category<>'Reconciliation'),
               array[]::integer[]
             ) result_vector,
             count(x.event_key) filter(where x.counting and x.rank_category<>'Reconciliation')::int counting_events
      from cb_rank_dirty d
      left join classified x on x.player_id=d.player_id
      group by d.player_id
    )
    insert into public.atp_ranking_metrics_cache(
      player_id,as_of_date,total_points,mandatory_tiebreak_points,events_played,result_vector,counting_events,updated_at
    )
    select player_id,v_date,total_points,mandatory_tiebreak_points,events_played,result_vector,counting_events,now()
    from metrics
    on conflict(player_id) do update set
      as_of_date=excluded.as_of_date,
      total_points=excluded.total_points,
      mandatory_tiebreak_points=excluded.mandatory_tiebreak_points,
      events_played=excluded.events_played,
      result_vector=excluded.result_vector,
      counting_events=excluded.counting_events,
      updated_at=now();
  end if;

  with baseline_unique as (
    select
      b.source_player_id,
      row_number() over(
        order by b.rank asc,b.points desc nulls last,b.source_player_id asc
      )::int as unique_rank
    from public.atp_ranking_baseline_2025_12_01 b
  ),
  candidates as (
    select p.id,p.sackmann_id,c.total_points,c.mandatory_tiebreak_points,c.events_played,c.result_vector
    from public.players p
    join public.atp_ranking_metrics_cache c on c.player_id=p.id
    where p.career_status='active'
      and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
      and (
        p.ranking_current=true
        or c.total_points>0
        or p.id=v_managed
        or exists(select 1 from public.academy_roster a where a.player_id=p.id and a.status='active')
      )
  ),
  ranked0 as (
    select c.*,
           b.unique_rank baseline_rank,
           row_number() over(
             order by c.total_points desc,
                      c.mandatory_tiebreak_points desc,
                      c.events_played asc,
                      c.result_vector desc,
                      c.id asc
           )::int simulated_rank
    from candidates c
    left join baseline_unique b on b.source_player_id=c.sackmann_id
    where c.total_points>0
  ),
  ranked as (
    select r.*,
           case
             when v_date=date '2025-12-01' and r.baseline_rank is not null then r.baseline_rank
             when v_date=date '2025-12-01' then
               coalesce((select max(b.unique_rank) from baseline_unique b),0)
               + row_number() over(
                   partition by (r.baseline_rank is null)
                   order by r.simulated_rank,r.id
                 )
             else r.simulated_rank
           end::int new_rank
    from ranked0 r
  )
  update public.players p
  set points=r.total_points,
      ranking=r.new_rank,
      game_world_rank=r.new_rank,
      ranking_current=true,
      ranking_source=case
        when v_date=date '2025-12-01' and r.baseline_rank is not null
          then 'ATP official 01/12/2025 snapshot · Court Boss event ledger calibrated'
        else 'Court Boss ATP rolling 52w · incremental metrics cache · official ties'
      end,
      ranking_snapshot_date=v_date,
      previous_ranking=coalesce(p.ranking,p.previous_ranking),
      rank_change=case when p.ranking is null then 0 else p.ranking-r.new_rank end
  from ranked r
  where p.id=r.id;

  get diagnostics v_updated=row_count;

  update public.players p
  set points=0,
      ranking=null,
      game_world_rank=null,
      ranking_snapshot_date=v_date,
      ranking_source='Court Boss ATP rolling 52w · unranked (0 points)'
  from public.atp_ranking_metrics_cache c
  where c.player_id=p.id
    and c.total_points<=0
    and p.career_status='active'
    and (
      p.ranking_current=true
      or p.id=v_managed
      or exists(select 1 from public.academy_roster a where a.player_id=p.id and a.status='active')
    );

  if v_managed is not null then
    update public.career_state c
    set points=coalesce(p.points,0),
        -- career_state.singles_rank is NOT NULL; a player can legitimately
        -- fall out of the ATP ranking when all points expire.
        -- Preserve last known rank until a dedicated unranked status exists.
        singles_rank=coalesce(p.ranking,c.singles_rank),
        career_date=v_date,updated_at=now()
    from public.players p
    where c.id='demo' and p.id=v_managed;
  end if;

  insert into public.ranking_history(player_id,snapshot_date,ranking,points)
  select id,v_date,ranking,points
  from public.players
  where ranking is not null
    and career_status='active'
    and coalesce(data_source,'') not ilike 'hidden duplicate merged into %'
  on conflict do nothing;

  select name into v_leader
  from public.players
  where ranking is not null and career_status='active'
  order by ranking,name
  limit 1;

  return jsonb_build_object(
    'date',v_date,
    'updated_players',v_updated,
    'dirty_players',v_dirty,
    'leader',v_leader,
    'zero_pointer_sync',v_zero_sync,
    'model','ATP 2026 rolling 52w · unique deterministic ranks v16'
  );
end;
$function$;
