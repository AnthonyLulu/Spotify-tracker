-- Post-draw vacancy engine v3.
-- Implements ATP/Challenger seed cascades (including 28/56 draw special cases),
-- ITF seed replacement, and circuit-specific LL/ALT behavior after qualifying starts.
-- Sources: ATP 2026 Rulebook 7.20; 2026 ITF WTT Regulations V.L / draw rules.

CREATE OR REPLACE FUNCTION public.apply_world_post_draw_substitutions(p_tournament_id bigint, p_on_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  r public.tournament_format_rules%rowtype;
  st public.world_tournament_states%rowtype;
  f record;
  ll record;
  alt record;

  v_vacancies integer:=0;
  v_replaced integer:=0;
  v_seed_adjustments integer:=0;

  v_replacement bigint;
  v_rank integer;
  v_method text;
  v_qpoints integer:=0;
  v_fill_slot integer;

  v_q_started boolean:=false;
  v_q_complete boolean:=false;

  v_promoted_player bigint;
  v_promoted_slot integer;
  v_promoted_rank integer;
  v_promoted_had_bye boolean;

  v_pivot_seed integer;
  v_pivot_player bigint;
  v_pivot_slot integer;
  v_pivot_had_bye boolean;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  select * into st from public.world_tournament_states where tournament_id=p_tournament_id;

  if t.id is null or st.tournament_id is null then
    return jsonb_build_object('ok',true,'replaced',0,'reason','draw_not_prepared');
  end if;
  if st.status='completed' or st.current_round_no>0 then
    return jsonb_build_object(
      'ok',true,'replaced',0,'reason',
      case when st.status='completed' then 'tournament_completed' else 'main_draw_started' end
    );
  end if;

  select * into r
  from public.tournament_format_rules x
  where x.rule_key=st.rule_key
  limit 1;

  v_q_started :=
    coalesce(r.qualifier_count,0)>0
    and (
      p_on_date>=coalesce(t.qualifying_start_date,t.start_date)
      or exists(
        select 1 from public.world_tournament_matches
        where tournament_id=t.id and is_qualifying=true
      )
    );

  v_q_complete :=
    coalesce(r.qualifier_count,0)=0
    or (
      select count(*)>=coalesce(r.qualifier_count,0)
      from public.world_tournament_qualifiers q
      where q.tournament_id=t.id
    );

  select count(*)::int into v_vacancies
  from public.world_tournament_entries e
  join public.tournament_forfeits f0
    on f0.tournament_id=e.tournament_id and f0.player_id=e.player_id
  where e.tournament_id=t.id
    and e.result_code is null
    and coalesce(e.matches_won,0)=0;

  if v_vacancies=0 then
    return jsonb_build_object('ok',true,'replaced',0,'vacancies',0);
  end if;

  if v_q_complete
     and coalesce(r.qualifier_count,0)>0
     and not exists(
       select 1 from public.world_tournament_lucky_losers
       where tournament_id=t.id
     ) then
    perform public.refresh_world_tournament_lucky_losers(t.id,0);
  end if;

  for f in
    select e.player_id,e.draw_slot,e.seed,e.ranking_at_entry,e.had_bye,
           tf.reason,tf.created_at
    from public.world_tournament_entries e
    join public.tournament_forfeits tf
      on tf.tournament_id=e.tournament_id and tf.player_id=e.player_id
    where e.tournament_id=t.id
      and e.result_code is null
      and coalesce(e.matches_won,0)=0
    order by tf.created_at,tf.id
  loop
    v_replacement:=null;
    v_rank:=null;
    v_method:=null;
    v_qpoints:=0;
    v_fill_slot:=f.draw_slot;

    v_promoted_player:=null;
    v_promoted_slot:=null;
    v_promoted_rank:=null;
    v_promoted_had_bye:=false;
    v_pivot_seed:=null;
    v_pivot_player:=null;
    v_pivot_slot:=null;
    v_pivot_had_bye:=false;

    -- Seed withdrawal before the first main-draw match:
    -- move the next seed-eligible player into the seeded position first.
    if f.seed is not null then
      if t.circuit in ('ATP','Challenger') and r.main_draw_size=28 and f.seed between 1 and 4 then
        v_pivot_seed:=5;
      elsif t.circuit in ('ATP','Challenger') and r.main_draw_size=56 and f.seed between 1 and 8 then
        v_pivot_seed:=9;
      end if;

      select e.player_id,e.draw_slot,
             coalesce(public.player_rank_at_date(
               e.player_id,
               coalesce(t.qualifying_end_date,t.main_draw_start_date,t.start_date,p_on_date)
             )::int,e.ranking_at_entry,999999),
             coalesce(e.had_bye,false)
      into v_promoted_player,v_promoted_slot,v_promoted_rank,v_promoted_had_bye
      from public.world_tournament_entries e
      join public.players p on p.id=e.player_id
      where e.tournament_id=t.id
        and e.player_id<>f.player_id
        and e.seed is null
        and coalesce(e.entry_method,'')<>'performance_bye'
        and coalesce(p.injury_status,'Fit')='Fit'
        and not exists(
          select 1 from public.tournament_forfeits tf
          where tf.tournament_id=t.id and tf.player_id=e.player_id
        )
      order by
        coalesce(public.player_rank_at_date(
          e.player_id,
          coalesce(t.qualifying_end_date,t.main_draw_start_date,t.start_date,p_on_date)
        )::int,e.ranking_at_entry,999999),
        e.ranking_at_entry,
        e.player_id
      limit 1;

      if v_pivot_seed is not null then
        select e.player_id,e.draw_slot,coalesce(e.had_bye,false)
        into v_pivot_player,v_pivot_slot,v_pivot_had_bye
        from public.world_tournament_entries e
        where e.tournament_id=t.id
          and e.seed=v_pivot_seed
          and not exists(
            select 1 from public.tournament_forfeits tf
            where tf.tournament_id=t.id and tf.player_id=e.player_id
          )
        limit 1;
      end if;

      if v_promoted_player is not null and v_pivot_seed is not null and v_pivot_player is not null then
        update public.world_tournament_entries
        set draw_slot=f.draw_slot,
            seed=f.seed,
            had_bye=coalesce(f.had_bye,false),
            source_label=coalesce(source_label,'Court Boss draw')||' · ATP seed cascade'
        where tournament_id=t.id and player_id=v_pivot_player;

        update public.world_tournament_entries
        set draw_slot=v_pivot_slot,
            seed=v_pivot_seed,
            had_bye=v_pivot_had_bye,
            source_label=coalesce(source_label,'Court Boss draw')||' · promoted seed'
        where tournament_id=t.id and player_id=v_promoted_player;

        update public.world_tournament_entries
        set draw_slot=v_promoted_slot,
            seed=null,
            had_bye=v_promoted_had_bye
        where tournament_id=t.id and player_id=f.player_id;

        v_fill_slot:=v_promoted_slot;
        v_seed_adjustments:=v_seed_adjustments+2;

      elsif v_promoted_player is not null then
        update public.world_tournament_entries
        set draw_slot=f.draw_slot,
            seed=f.seed,
            had_bye=coalesce(f.had_bye,false),
            source_label=coalesce(source_label,'Court Boss draw')||
              case when t.circuit='ITF' then ' · ITF seed replacement' else ' · promoted seed' end
        where tournament_id=t.id and player_id=v_promoted_player;

        update public.world_tournament_entries
        set draw_slot=v_promoted_slot,
            seed=null,
            had_bye=v_promoted_had_bye
        where tournament_id=t.id and player_id=f.player_id;

        v_fill_slot:=v_promoted_slot;
        v_seed_adjustments:=v_seed_adjustments+1;
      end if;
    end if;

    -- Once qualifying has started, ATP Tour and ITF main-draw vacancies are LL-only.
    -- Challenger may use an eligible alternate if no LL is available.
    if coalesce(r.qualifier_count,0)>0 and v_q_started and v_q_complete then
      select ll0.* into ll
      from public.world_tournament_lucky_losers ll0
      join public.players p on p.id=ll0.player_id
      where ll0.tournament_id=t.id
        and ll0.selected=false
        and coalesce(p.injury_status,'Fit')='Fit'
        and not exists(
          select 1 from public.world_tournament_entries e
          where e.tournament_id=t.id and e.player_id=ll0.player_id
        )
        and not exists(
          select 1 from public.tournament_forfeits tf
          where tf.tournament_id=t.id and tf.player_id=ll0.player_id
        )
      order by ll0.ll_order
      limit 1;

      if ll.player_id is not null then
        v_replacement:=ll.player_id;
        v_rank:=ll.ranking_at_seeding;
        v_method:='lucky_loser';
        select coalesce(qe.points_awarded,0)::int into v_qpoints
        from public.world_tournament_qualifying_entries qe
        where qe.tournament_id=t.id and qe.player_id=v_replacement
        limit 1;
        v_qpoints:=coalesce(v_qpoints,0);
      end if;
    end if;

    if v_replacement is null
       and (
         coalesce(r.qualifier_count,0)=0
         or not v_q_started
         or t.circuit='Challenger'
       ) then
      select c.player_id,c.effective_rank into alt
      from public.tournament_candidate_player_ids(t.id,'direct',2000) c
      join public.players p on p.id=c.player_id
      where not exists(
        select 1 from public.world_tournament_entries e
        where e.tournament_id=t.id and e.player_id=c.player_id
      )
        and not exists(
          select 1 from public.tournament_forfeits tf
          where tf.tournament_id=t.id and tf.player_id=c.player_id
        )
        and not (public.player_tournament_calendar_conflict(c.player_id,t.id,'direct')->>'conflict')::boolean
      order by c.effective_rank,p.current_ability desc,c.player_id
      limit 1;

      if alt.player_id is not null then
        v_replacement:=alt.player_id;
        v_rank:=alt.effective_rank;
        v_method:='alternate';
        v_qpoints:=0;
      end if;
    end if;

    -- Vacancy remains open until qualifying completion when LL-only rules apply.
    if v_replacement is null then
      continue;
    end if;

    update public.world_tournament_entries
    set player_id=v_replacement,
        seed=null,
        draw_slot=v_fill_slot,
        entry_method=v_method,
        ranking_at_entry=v_rank,
        had_bye=coalesce(had_bye,false),
        matches_won=0,
        result_code=null,
        result_label=null,
        points_awarded=0,
        qualifying_points=v_qpoints,
        last_opponent_id=null,
        last_opponent_name=null,
        last_score=null,
        simulated_on=p_on_date,
        source_label='Court Boss post-draw substitution · '||upper(v_method)||
          case when f.seed is not null then ' · seed vacancy cascade' else '' end
    where tournament_id=t.id and player_id=f.player_id;

    if v_method='lucky_loser' then
      update public.world_tournament_lucky_losers
      set selected=true
      where tournament_id=t.id and player_id=v_replacement;
    end if;

    insert into public.world_tournament_substitutions(
      tournament_id,withdrawn_player_id,replacement_player_id,draw_slot,
      substitution_method,substituted_on,reason,source_label
    ) values(
      t.id,f.player_id,v_replacement,v_fill_slot,
      v_method,p_on_date,f.reason,
      case
        when v_method='lucky_loser' and t.circuit='ITF'
          then 'ITF WTT · post-draw Lucky Loser substitution'
        when v_method='lucky_loser'
          then 'ATP 7.20 · post-draw Lucky Loser substitution'
        else 'Court Boss alternate list · post-draw vacancy'
      end
    )
    on conflict(tournament_id,withdrawn_player_id) do nothing;

    v_replaced:=v_replaced+1;
  end loop;

  return jsonb_build_object(
    'ok',true,
    'tournament_id',t.id,
    'vacancies',v_vacancies,
    'replaced',v_replaced,
    'seed_adjustments',v_seed_adjustments,
    'qualifying_started',v_q_started,
    'qualifying_completed',v_q_complete,
    'on_date',p_on_date
  );
end;
$function$;
