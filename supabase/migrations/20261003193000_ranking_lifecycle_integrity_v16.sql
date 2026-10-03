-- Court Boss Ranking & Lifecycle Integrity V16
-- Retired players cannot regain world ranks; ATP ranks are deterministic and unique in-game.

CREATE OR REPLACE FUNCTION public.career_long_term_health_v15(p_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select jsonb_build_object(
    'ok',true,
    'date',p_date,
    'living_world',public.living_world_integrity_audit_v16(p_date),
    'horizon_2050',public.living_world_horizon_test_v14(2025,2050),
    'economy',public.career_operating_cost_profile_v15(p_date),
    'hall_of_fame_total',(select count(*) from public.hall_of_fame_candidates),
    'active_staff_profiles',(select count(*) from public.staff_profiles where active=true),
    'active_players',(select count(*) from public.players where career_status='active'),
    'retired_ranked',(select count(*) from public.players where career_status='retired' and ranking_current=true),
    'future_retired_entries',(
      select count(*)
      from public.entries e
      join public.players p on p.id=e.player_id
      join public.tournaments t on t.id=e.tournament_id
      where p.career_status='retired' and coalesce(e.status,'')='entered' and t.start_date>=p_date
    ),
    'model','CB-CAREER-LONG-HORIZON-v16'
  );
$function$;

CREATE OR REPLACE FUNCTION public.career_system_health(p_date date)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select jsonb_build_object(
    'ok',true,
    'date',p_date,
    'career_exists',exists(select 1 from public.career_state where id='demo'),
    'managed_player_exists',exists(
      select 1 from public.players p join public.career_state c on c.managed_player_id=p.id where c.id='demo'
    ),
    'academy_exists',exists(select 1 from public.academies where id='demo'),
    'academy_active_players',(select count(*) from public.academy_roster where status='active'),
    'academy_prospects',(select count(*) from public.academy_youth where status='prospect'),
    'unread_inbox',(select count(*) from public.inbox_items where not is_read),
    'active_injuries',(select count(*) from public.injuries where lower(coalesce(status,''))='active'),
    'active_scouting',(select count(*) from public.scouting_assignments where status='active'),
    'available_sponsors',(select count(*) from public.sponsor_offers where status='available'),
    'managed_staff',(select count(*) from public.staff),
    'world_staff',(select count(*) from public.staff_profiles where active=true),
    'active_contracts',(select count(*) from public.contracts where status='active'),
    'relationships',(select count(*) from public.player_relationships where active),
    'season_plans',(select count(*) from public.player_season_plans where season=extract(year from p_date)::int),
    'living_world',public.living_world_integrity_audit_v16(p_date),
    'model','CB-CAREER-OS-v16'
  )
$function$;

CREATE OR REPLACE FUNCTION public.living_world_integrity_audit_v16(p_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  base jsonb;
  v_retired_world_rank int:=0;
  v_active_world_rank int:=0;
  v_world_rank_dupes int:=0;
  v_ok boolean;
  v_issues jsonb;
begin
  base:=public.living_world_integrity_audit_v14(p_date);

  select count(*) into v_retired_world_rank
  from public.players
  where career_status='retired' and game_world_rank is not null;

  select count(*) into v_active_world_rank
  from public.players
  where career_status='active' and game_world_rank is not null
    and coalesce(data_source,'') not ilike 'hidden duplicate merged into %';

  select coalesce(sum(n-1),0)::int into v_world_rank_dupes
  from (
    select game_world_rank,count(*)::int n
    from public.players
    where career_status='active' and game_world_rank is not null
      and coalesce(data_source,'') not ilike 'hidden duplicate merged into %'
    group by game_world_rank
    having count(*)>1
  ) d;

  v_issues:=coalesce(base->'issues','[]'::jsonb);
  if v_retired_world_rank>0 then
    v_issues:=v_issues||jsonb_build_array(jsonb_build_object('code','retired_world_rank','count',v_retired_world_rank));
  end if;
  if v_world_rank_dupes>0 then
    v_issues:=v_issues||jsonb_build_array(jsonb_build_object('code','duplicate_active_world_rank','count',v_world_rank_dupes));
  end if;

  v_ok:=coalesce((base->>'ok')::boolean,false) and v_retired_world_rank=0 and v_world_rank_dupes=0;

  return base || jsonb_build_object(
    'ok',v_ok,
    'status',case when v_ok then 'healthy' else 'warning' end,
    'issues',v_issues,
    'active_world_ranked',v_active_world_rank,
    'retired_world_ranked',v_retired_world_rank,
    'duplicate_active_world_ranks',v_world_rank_dupes,
    'model','CB-LIVING-WORLD-INTEGRITY-v16'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.refresh_game_world_ranks()
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
declare
  total_n int:=0;
  newgen_first int;
  newgen_last int;
  v_max int:=0;
  v_official_updates int:=0;
  v_depth_assigned int:=0;
  v_collision_repaired int:=0;
  v_official_max int:=0;
begin
  perform pg_advisory_xact_lock(94830000);

  update public.players
  set game_world_rank=null
  where career_status<>'active'
    and game_world_rank is not null;

  -- Official ATP-ranked players mirror their real simulated ATP rank.
  update public.players p
  set game_world_rank=p.ranking
  where coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
    and p.career_status='active'
    and p.ranking_current=true
    and p.ranking is not null
    and p.game_world_rank is distinct from p.ranking;
  get diagnostics v_official_updates=row_count;

  select coalesce(max(ranking),0)
  into v_official_max
  from public.players
  where career_status='active'
    and ranking_current=true
    and ranking is not null
    and coalesce(data_source,'') not ilike 'hidden duplicate merged into %';

  select coalesce(max(game_world_rank),0)
  into v_max
  from public.players
  where game_world_rank is not null
    and career_status='active'
    and coalesce(data_source,'') not ilike 'hidden duplicate merged into %';

  with depth_rows as (
    select
      p.id,p.game_world_rank,
      row_number() over(partition by p.game_world_rank order by p.id)::int as depth_rn,
      exists(
        select 1
        from public.players o
        where o.career_status='active'
          and o.ranking_current=true
          and o.ranking is not null
          and o.game_world_rank=p.game_world_rank
          and o.id<>p.id
      ) as collides_official
    from public.players p
    where p.career_status='active'
      and p.game_world_rank is not null
      and not (p.ranking_current=true and p.ranking is not null and p.game_world_rank=p.ranking)
      and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
  ),
  bad as (
    select id,row_number() over(order by game_world_rank,id)::int as rn
    from depth_rows
    where collides_official
       or depth_rn>1
       or game_world_rank<=v_official_max
  )
  update public.players p
  set game_world_rank=v_max+b.rn
  from bad b
  where p.id=b.id;
  get diagnostics v_collision_repaired=row_count;

  select coalesce(max(game_world_rank),0)
  into v_max
  from public.players
  where game_world_rank is not null
    and career_status='active'
    and coalesce(data_source,'') not ilike 'hidden duplicate merged into %';

  -- Depth-only players keep their existing position. Only previously-unranked
  -- records receive a new tail position; no global 38k-player rewrite.
  with pending as (
    select p.id,
           row_number() over(
             order by
               case when p.career_status='active' then 0 else 1 end,
               p.source_ranking asc nulls last,
               p.itf_ranking asc nulls last,
               p.junior_ranking asc nulls last,
               p.ncaa_rank asc nulls last,
               p.id
           )::int rn
    from public.players p
    where p.game_world_rank is null
      and p.career_status='active'
      and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
  )
  update public.players p
  set game_world_rank=v_max+x.rn
  from pending x
  where p.id=x.id;
  get diagnostics v_depth_assigned=row_count;

  select count(*)
  into total_n
  from public.players
  where game_world_rank is not null
    and career_status='active';

  select min(game_world_rank),max(game_world_rank)
  into newgen_first,newgen_last
  from public.players
  where game_generated=true
    and career_status='active'
    and game_world_rank is not null;

  return jsonb_build_object(
    'ranked',total_n,
    'official_rank_updates',v_official_updates,
    'depth_assigned',v_depth_assigned,
    'collision_repaired',v_collision_repaired,
    'newgen_first_rank',newgen_first,
    'newgen_last_rank',newgen_last,
    'model','official ATP rank + active-only append depth v16'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.refresh_player_career_lifecycle(p_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_date date := coalesce(p_date,current_date);
  v_managed bigint;
  v_switched int := 0;
  v_retired int := 0;
begin
  if v_date<=date '2025-12-01' then
    return jsonb_build_object('date',v_date,'switched_to_doubles',0,'retired',0,'historical_cutoff',true);
  end if;

  if not (extract(month from v_date)::int in (1,4,7,10)) then
    return jsonb_build_object('date',v_date,'switched_to_doubles',0,'retired',0,'quarterly_checkpoint',false);
  end if;

  select managed_player_id into v_managed from career_state where id='demo';

  with pivot_candidates as (
    select
      p.id,
      coalesce(p.career_focus,'mixed') as old_focus,
      dp.ambition,dp.competitive_drive,dp.resilience,dp.injury_proneness
    from players p
    left join player_attributes pa on pa.player_id=p.id
    left join player_development_profiles dp on dp.player_id=p.id
    where p.career_status='active'
      and p.id<>coalesce(v_managed,-1)
      and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
      and coalesce(p.career_focus,'mixed') not in ('doubles_only','singles_only')
      and coalesce(
        case when p.birth_date is not null then extract(year from age(v_date,p.birth_date))::int end,
        p.age,24
      ) between 30 and 38
      and coalesce(p.ranking,999999)>450
      and coalesce(p.doubles_ranking,999999)<=500
      and (
        coalesce(pa.doubles,10)>=12
        or coalesce(pa.volley,10)>=13
        or coalesce(pa.return_game,10)>=14
        or coalesce(pa.net_positioning,10)>=13
      )
      and mod(abs(hashtext(
          'pivot|'||p.id::text||'|'||
          extract(year from v_date)::int::text||'|'||
          extract(month from v_date)::int::text
        )),100)
      <
      least(72,
        case
          when coalesce(p.age,24)>=36 then 40
          when coalesce(p.age,24)>=34 then 30
          when coalesce(p.age,24)>=32 then 22
          else 14
        end
        +greatest(0,coalesce(dp.competitive_drive,10)-10)
        +greatest(0,coalesce(dp.ambition,10)-12)
        +greatest(0,coalesce(dp.injury_proneness,10)-12)/2
        +greatest(0,coalesce(pa.doubles,10)-12)*2
      )
  )
  insert into player_career_focus_history(
    player_id,changed_at,from_focus,to_focus,reason,source
  )
  select
    id,v_date,old_focus,'doubles_only',
    'Le simple recule mais le profil, la motivation et le niveau double rendent une spécialisation crédible.',
    'Court Boss AI'
  from pivot_candidates;

  get diagnostics v_switched = row_count;

  update players p
  set career_focus='doubles_only',
      career_focus_changed_at=v_date,
      career_focus_reason='Le simple recule mais le profil, la motivation et le niveau double rendent une spécialisation crédible.',
      career_focus_source='Court Boss AI'
  where exists(
    select 1 from player_career_focus_history h
    where h.player_id=p.id
      and h.changed_at=v_date
      and h.to_focus='doubles_only'
      and h.source='Court Boss AI'
  );

  with retirement_candidates as (
    select
      p.id,
      coalesce(p.career_focus,'mixed') as focus,
      coalesce(p.ranking,999999) as singles_rank,
      coalesce(p.doubles_ranking,999999) as doubles_rank,
      coalesce(p.form,65) as form,
      coalesce(p.fitness,85) as fitness,
      coalesce(
        case when p.birth_date is not null then extract(year from age(v_date,p.birth_date))::int end,
        p.age,24
      ) as player_age,
      coalesce(dp.ambition,10) as ambition,
      coalesce(dp.competitive_drive,10) as drive,
      coalesce(dp.resilience,10) as resilience,
      coalesce(dp.professionalism,10) as professionalism,
      coalesce(dp.injury_proneness,10) as injury_proneness,
      coalesce(dp.burnout_susceptibility,10) as burnout,
      coalesce(pa.natural_fitness,10) as natural_fitness,
      coalesce(pa.recovery,10) as recovery
    from players p
    left join player_development_profiles dp on dp.player_id=p.id
    left join player_attributes pa on pa.player_id=p.id
    where p.career_status='active'
      and p.id<>coalesce(v_managed,-1)
      and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
  ),
  retirement_scored as (
    select
      r.*,
      greatest(1,least(96,round(
        (
          case
            when player_age<33 then 0
            when player_age=33 then 1
            when player_age=34 then 2
            when player_age=35 then 4
            when player_age=36 then 7
            when player_age=37 then 11
            when player_age=38 then 18
            when player_age=39 then 26
            when player_age=40 then 38
            when player_age=41 then 52
            when player_age=42 then 68
            else 82
          end
        )
        *
        case
          when focus='doubles_only' and doubles_rank<=100 then .18
          when focus='doubles_only' and doubles_rank<=300 then .28
          when focus='doubles_only' then .48
          when singles_rank<=20 then .30
          when singles_rank<=100 then .44
          when singles_rank<=300 then .64
          else 1
        end
        *
        greatest(.42,least(1.85,
          1
          +(injury_proneness-10)*.028
          +(burnout-10)*.020
          -(natural_fitness-10)*.028
          -(recovery-10)*.016
          -(resilience-10)*.020
          -(professionalism-10)*.014
          -(ambition-10)*.012
          -(drive-10)*.016
        ))
        *
        case
          when fitness<60 then 1.35
          when fitness<75 then 1.15
          when fitness>=92 then .88
          else 1
        end
        *
        case
          when form<50 then 1.25
          when form<65 then 1.08
          when form>=82 then .90
          else 1
        end
      )::int)) as retire_chance
    from retirement_candidates r
    where player_age>=33
  ),
  retiring as (
    select id
    from retirement_scored
    where player_age>=46
       or (player_age>=44 and singles_rank>100 and doubles_rank>100)
       or mod(abs(hashtext(
      'retire|'||id::text||'|'||
      extract(year from v_date)::int::text||'|'||
      extract(month from v_date)::int::text
    )),100) < retire_chance
  )
  update players p
  set career_status='retired',
      previous_ranking=coalesce(p.ranking,p.previous_ranking),
      ranking_current=false,
      ranking=null,
      game_world_rank=null,
      points=0,
      retired_date=v_date,
      retirement_reason=case
        when p.career_focus='doubles_only'
          then 'Fin de carrière après une dernière phase dédiée au double.'
        when p.career_focus='singles_only'
          then 'Fin de carrière après un parcours resté centré sur le simple.'
        when p.injury_status<>'Fit'
          then 'Fin de carrière influencée par l’usure physique et les blessures.'
        else 'Fin de carrière professionnelle simulée selon âge, niveau, forme et motivation.'
      end,
      ranking_source='Court Boss simulation · retraite dynamique'
  where p.id in (select id from retiring);

  get diagnostics v_retired = row_count;

  update player_staff_assignments psa
  set active=false,end_date=v_date,ended_reason='Retraite du joueur'
  where psa.active=true
    and exists(
      select 1 from players p
      where p.id=psa.player_id
        and p.career_status='retired'
        and p.retired_date=v_date
    );

  update world_doubles_partnerships w
  set active=false,dissolved_date=v_date,race_rank=null
  where w.active=true
    and exists(
      select 1 from players p
      where p.career_status='retired'
        and p.retired_date=v_date
        and (p.id=w.player_a_id or p.id=w.player_b_id)
    );

  return jsonb_build_object(
    'date',v_date,
    'switched_to_doubles',v_switched,
    'retired',v_retired,
    'active_doubles_only',(select count(*) from players where career_status='active' and career_focus='doubles_only'),
    'model','age + ranking + focus + physical longevity + injuries + ambition + resilience + professionalism'
  );
end;
$function$;

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
    set points=coalesce(p.points,0),singles_rank=p.ranking,career_date=v_date,updated_at=now()
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

update public.players
set game_world_rank=null
where career_status='retired' and game_world_rank is not null;

revoke all on function public.refresh_world_rankings(date) from public,anon,authenticated;
grant execute on function public.refresh_world_rankings(date) to service_role;
revoke all on function public.refresh_player_career_lifecycle(date) from public,anon,authenticated;
grant execute on function public.refresh_player_career_lifecycle(date) to service_role;
revoke all on function public.living_world_integrity_audit_v16(date) from public,anon,authenticated;
grant execute on function public.living_world_integrity_audit_v16(date) to service_role;
revoke all on function public.career_system_health(date) from public,anon,authenticated;
grant execute on function public.career_system_health(date) to service_role;
revoke all on function public.career_long_term_health_v15(date) from public,anon,authenticated;
grant execute on function public.career_long_term_health_v15(date) to service_role;
