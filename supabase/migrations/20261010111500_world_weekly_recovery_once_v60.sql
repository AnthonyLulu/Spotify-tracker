-- P0: Prevent a failed request, double tap or checkpoint retry from
-- recovering the global AI roster twice on the same snapshot date.
-- No new table: use career_event_log (already saved/restored by the game).
-- The advisory lock serializes concurrent weekly recovery calls and
-- the marker is written in the same transaction as the player updates.
CREATE UNIQUE INDEX IF NOT EXISTS career_event_log_world_recovery_once_v60
ON public.career_event_log(event_date)
WHERE event_type='world_weekly_recovery_v60';

CREATE OR REPLACE FUNCTION public.apply_world_recovery_week(p_date date, p_week integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_count int:=0;
  v_previous_count integer:=0;
begin
  -- simulate_world_week holds the same lock, so this is re-entrant there
  -- and serializes standalone recovery retries as well.
  perform pg_advisory_xact_lock(94832021);
  if p_date is null or p_week is null then
    raise exception 'World recovery requires an exact snapshot date and week';
  end if;
  select coalesce((e.payload->>'updated_players')::integer,0)
  into v_previous_count
  from public.career_event_log e
  where e.event_type='world_weekly_recovery_v60' and e.event_date=p_date
  order by e.id desc limit 1;
  if found then
    return jsonb_build_object(
      'updated_players',0,'already_applied',true,
      'original_updated_players',v_previous_count,
      'date',p_date,'model','activity-aware recovery v60: once per world week'
    );
  end if;
  with active_ids as (
    select player_a_id player_id
    from public.world_tournament_matches
    where simulated_on between p_date-13 and p_date
    union
    select player_b_id
    from public.world_tournament_matches
    where simulated_on between p_date-13 and p_date

    union
    select wp.player_a_id
    from public.world_doubles_tournament_matches m
    join public.world_doubles_partnerships wp on wp.id=m.pair_a_id
    where m.simulated_on between p_date-13 and p_date
    union
    select wp.player_b_id
    from public.world_doubles_tournament_matches m
    join public.world_doubles_partnerships wp on wp.id=m.pair_a_id
    where m.simulated_on between p_date-13 and p_date
    union
    select wp.player_a_id
    from public.world_doubles_tournament_matches m
    join public.world_doubles_partnerships wp on wp.id=m.pair_b_id
    where m.simulated_on between p_date-13 and p_date
    union
    select wp.player_b_id
    from public.world_doubles_tournament_matches m
    join public.world_doubles_partnerships wp on wp.id=m.pair_b_id
    where m.simulated_on between p_date-13 and p_date

    union
    select e.player_a_id
    from public.world_junior_doubles_matches m
    join public.world_junior_doubles_entries e on e.id=m.pair_a_entry_id
    where m.simulated_on between p_date-13 and p_date
    union
    select e.player_b_id
    from public.world_junior_doubles_matches m
    join public.world_junior_doubles_entries e on e.id=m.pair_a_entry_id
    where m.simulated_on between p_date-13 and p_date
    union
    select e.player_a_id
    from public.world_junior_doubles_matches m
    join public.world_junior_doubles_entries e on e.id=m.pair_b_entry_id
    where m.simulated_on between p_date-13 and p_date
    union
    select e.player_b_id
    from public.world_junior_doubles_matches m
    join public.world_junior_doubles_entries e on e.id=m.pair_b_entry_id
    where m.simulated_on between p_date-13 and p_date

    union
    select unnest(coalesce(r.home_player_ids,'{}'::bigint[]))
    from public.davis_rubbers r
    join public.davis_ties t on t.id=r.tie_id
    where t.tie_date between p_date-13 and p_date
    union
    select unnest(coalesce(r.away_player_ids,'{}'::bigint[]))
    from public.davis_rubbers r
    join public.davis_ties t on t.id=r.tie_id
    where t.tie_date between p_date-13 and p_date

    union
    select unnest(r.home_player_ids)
    from public.college_dual_rubbers r
    join public.college_duals d on d.id=r.dual_id
    where d.match_date between p_date-13 and p_date and r.status='completed'
    union
    select unnest(r.away_player_ids)
    from public.college_dual_rubbers r
    join public.college_duals d on d.id=r.dual_id
    where d.match_date between p_date-13 and p_date and r.status='completed'

    union
    select unnest(m.side_a_player_ids)
    from public.ncaa_individual_matches m
    where m.played_on between p_date-13 and p_date
    union
    select unnest(m.side_b_player_ids)
    from public.ncaa_individual_matches m
    where m.played_on between p_date-13 and p_date
  ),
  candidates as (
    select
      p.id,
      coalesce(p.fatigue,20) fatigue,
      coalesce(p.fitness,90) fitness,
      coalesce(p.age,24) age,
      coalesce(pa.recovery,10) recovery,
      coalesce(pa.natural_fitness,10) natural_fitness,
      public.player_recent_match_load(p.id,p_date) recent_matches,
      p.injury_status
    from public.players p
    left join public.player_attributes pa on pa.player_id=p.id
    where p.career_status='active'
      and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
      and (
        p.ranking_current=true
        or p.doubles_ranking is not null
        or p.junior_ranking is not null
        or p.itf_ranking is not null
        or p.ncaa_current=true
      )
      and (
        coalesce(p.fatigue,20)>20
        or coalesce(p.injury_status,'Fit')<>'Fit'
        or exists(select 1 from active_ids a where a.player_id=p.id)
      )
      and not exists(
        select 1
        from public.player_training_load_profiles ail
        where ail.player_id=p.id
          and ail.source_label='Court Boss · world AI intraday V30'
          and ail.last_match_date between p_date-13 and p_date
      )
  ),
  calc as (
    select c.*,
      greatest(3,least(16,round(
        8
        +(c.recovery-10)*.45
        +(c.natural_fitness-10)*.30
        +case
          when c.recent_matches=0 then 4
          when c.recent_matches=1 then 2
          when c.recent_matches=2 then 1
          when c.recent_matches>=6 then -4
          when c.recent_matches>=4 then -2
          else 0 end
        -greatest(0,c.age-31)*.25
        +case when c.injury_status<>'Fit' then 2 else 0 end
      )::int)) recovery_points
    from candidates c
  )
  update public.players p
  set fatigue=greatest(
        8,
        coalesce(p.fatigue,20)-c.recovery_points
      ),
      fitness=case
        when coalesce(p.injury_status,'Fit')='Fit'
          then least(100,coalesce(p.fitness,90)+
            case
              when c.recent_matches=0 then 3
              when c.recent_matches<=2 then 2
              else 1 end
          )
        else coalesce(p.fitness,90)
      end
  from calc c
  where p.id=c.id;

  get diagnostics v_count=row_count;

  -- Marker and recovered player rows commit in the SAME PostgreSQL
  -- transaction. On any failed transaction both are rolled back.
  -- career_event_log is already covered by game save/load snapshots.
  insert into public.career_event_log(
    event_date,week,system,event_type,entity_type,entity_id,summary,payload
  ) values(
    p_date,p_week,'world','world_weekly_recovery_v60','world',null,
    'Récupération mondiale hebdomadaire appliquée une seule fois',
    jsonb_build_object('updated_players',v_count,'snapshot_date',p_date,'week',p_week)
  );

  return jsonb_build_object(
    'already_applied',false,
    'updated_players',v_count,
    'date',p_date,
    'model','activity-aware recovery · recent matches + recovery + natural fitness + age'
  );
end;
$function$;

REVOKE ALL ON FUNCTION public.apply_world_recovery_week(date,integer)
  FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.apply_world_recovery_week(date,integer)
  TO service_role;
