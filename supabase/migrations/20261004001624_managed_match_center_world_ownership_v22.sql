CREATE OR REPLACE FUNCTION public.simulate_world_tournaments(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t record;
  r public.tournament_format_rules%rowtype;
  v_result jsonb;
  v_simulated integer:=0;
  v_skipped integer:=0;
  v_knockout integer:=0;
  v_round_robin integer:=0;
  v_matches integer:=0;
  v_participants integer:=0;
  v_rank jsonb;
  v_race jsonb;
  v_nextgen jsonb;
begin
  perform pg_advisory_xact_lock(94832021);

  if p_to_date<=date '2025-12-01' then
    return jsonb_build_object('tournaments_simulated',0,'historical_cutoff',true);
  end if;

  for t in
    select x.*
    from public.tournaments x
    where x.singles=true
      and coalesce(x.is_active,true)=true
      and coalesce(x.end_date,x.start_date)>greatest(p_from_date,date '2025-12-01')
      and coalesce(x.end_date,x.start_date)<=p_to_date
      and coalesce(x.circuit,'') in ('ATP','Challenger','ITF')
      and coalesce(x.category,'') not in ('United Cup','Laver Cup','Davis Cup','Junior Davis Cup')
      and not exists(select 1 from public.world_tournament_simulations s where s.tournament_id=x.id)
      -- Progressive daily tournaments own any prepared state. Never let the
      -- legacy full-draw simulator jump over a managed_live_pending match.
      and not exists(
        select 1 from public.world_tournament_states ws
        where ws.tournament_id=x.id
      )
      and not exists(
        select 1 from public.world_qualifying_states wq
        where wq.tournament_id=x.id
      )
      and not exists(
        select 1
        from public.world_tournament_matches wm
        where wm.tournament_id=x.id
          and wm.winner_id is null
          and coalesce(wm.matchup_components->>'status','')='managed_live_pending'
      )
      -- Even before the progressive state is prepared, an entered managed
      -- player reserves the event for the Match Center / daily engine.
      and not exists(
        select 1
        from public.entries me
        where me.tournament_id=x.id
          and coalesce(me.status,'entered') not in ('withdrawn','declined','rejected')
          and me.player_id in (
            select cs.managed_player_id
            from public.career_state cs
            where cs.id='demo' and cs.managed_player_id is not null
            union
            select ar.player_id
            from public.academy_roster ar
            where ar.status='active'
              and ar.player_id is not null
              and ar.source_youth_id is null
          )
      )
      and not exists(
        select 1
        from public.tournament_runs mr
        where mr.tournament_id=x.id
          and mr.managed_player_id in (
            select cs.managed_player_id
            from public.career_state cs
            where cs.id='demo' and cs.managed_player_id is not null
            union
            select ar.player_id
            from public.academy_roster ar
            where ar.status='active'
              and ar.player_id is not null
              and ar.source_youth_id is null
          )
      )
    order by
      date_trunc('week',x.start_date::timestamp),
      case
        when x.category='Grand Chelem' then 100
        when x.category='Masters 1000' then 90
        when x.category='ATP 500' then 80
        when x.category='ATP 250' then 70
        when x.category='Challenger 175' then 60
        when x.category='Challenger 125' then 55
        when x.category='Challenger 100' then 50
        when x.category='Challenger 75' then 45
        when x.category='Challenger 50' then 40
        when x.category='M25' then 30
        when x.category='M15' then 25
        else 10 end desc,
      coalesce(x.end_date,x.start_date),x.id
    limit 160
  loop
    select * into r
    from public.tournament_format_rules fr
    where fr.circuit=t.circuit
      and fr.category=t.category
      and fr.main_draw_size=coalesce(t.singles_draw_size,t.draw_size)
    limit 1;

    if r.rule_key is null then
      v_skipped:=v_skipped+1;
      continue;
    end if;

    if t.category='ATP Finals' then
      perform public.refresh_world_race(coalesce(t.start_date,t.end_date,p_to_date));
    elsif t.category='Next Gen Finals' then
      perform public.refresh_world_nextgen_race(coalesce(t.start_date,t.end_date,p_to_date));
    end if;

    if r.format_type='knockout' then
      perform public.simulate_world_qualifying_full(
        t.id,coalesce(t.qualifying_end_date,t.start_date,p_to_date)
      );
      v_result:=public.simulate_world_knockout_tournament_full(
        t.id,coalesce(t.end_date,t.start_date,p_to_date)
      );
    elsif r.format_type='round_robin' then
      v_result:=public.simulate_world_round_robin_tournament_full(
        t.id,coalesce(t.end_date,t.start_date,p_to_date)
      );
    else
      v_result:=jsonb_build_object('skipped','unsupported_format');
    end if;

    if v_result->>'ok'='true' then
      v_simulated:=v_simulated+1;
      v_matches:=v_matches+coalesce((v_result->>'matches')::int,0);
      v_participants:=v_participants+coalesce((v_result->>'participants')::int,0);
      if r.format_type='knockout' then v_knockout:=v_knockout+1; end if;
      if r.format_type='round_robin' then v_round_robin:=v_round_robin+1; end if;
    else
      v_skipped:=v_skipped+1;
    end if;
  end loop;

  v_rank:=public.refresh_world_rankings(p_to_date);
  v_race:=public.refresh_world_race(p_to_date);
  v_nextgen:=public.refresh_world_nextgen_race(p_to_date);

  return jsonb_build_object(
    'tournaments_simulated',v_simulated,
    'knockout_simulated',v_knockout,
    'round_robin_simulated',v_round_robin,
    'skipped',v_skipped,
    'matches_simulated',v_matches,
    'participants_processed',v_participants,
    'from',p_from_date,'to',p_to_date,
    'ranking_model','52-week ledger full-draw',
    'race_model','calendar-year full-draw',
    'match_model','CB-MATCH-v4-FULLDRAW',
    'ranking_refresh',v_rank,'race_refresh',v_race,'nextgen_refresh',v_nextgen
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.simulate_world_doubles_tournaments(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  v_year int;
  v_managed bigint;
  v_draw int;
  v_bracket int;
  v_byes int;
  v_rounds int;
  v_round int;
  v_size int;
  v_pos int;
  v_next int;
  v_a bigint;
  v_b bigint;
  v_w bigint;
  v_l bigint;
  v_match jsonb;
  v_prob numeric;
  v_awon boolean;
  v_score text;
  v_round_code text;
  v_points int;
  v_prize numeric;
  v_winner bigint;
  v_finalist bigint;
  v_matches int:=0;
  v_simulated int:=0;
  v_selected int;
  v_qdraw int:=0;
  v_qslots int:=0;
  v_wc_count int:=0;
  v_pool_needed int:=0;
  v_seed_limit int:=0;
  v_qw1 bigint;
  v_qw2 bigint;
  v_qwinner bigint;
  entry_rec record;
  match_rec record;
begin
  perform pg_advisory_xact_lock(94832021);
  if p_to_date<=date '2025-12-01' then
    return jsonb_build_object('tournaments_simulated',0,'historical_cutoff',true);
  end if;
  select managed_player_id into v_managed from public.career_state where id='demo';

  for t in
    select *
    from public.tournaments
    where doubles=true and coalesce(is_active,true)=true
      and coalesce(end_date,start_date)>greatest(p_from_date,date '2025-12-01')
      and coalesce(end_date,start_date)<=p_to_date
      and coalesce(circuit,'') not in ('NCAA','Junior','Federation')
      and coalesce(category,'') not in ('United Cup','Laver Cup','ATP Finals')
      and not exists(select 1 from public.world_doubles_tournament_simulations s where s.tournament_id=tournaments.id)
      -- A tournament containing a managed pair belongs to the live Match Center,
      -- permanently for that save. The legacy full-draw must never overwrite it.
      and not exists(
        select 1
        from public.managed_doubles_entries me
        where me.tournament_id=tournaments.id
          and coalesce(me.status,'entered') not in ('withdrawn','declined','rejected')
          and me.player_id in (
            select cs.managed_player_id
            from public.career_state cs
            where cs.id='demo' and cs.managed_player_id is not null
            union
            select ar.player_id
            from public.academy_roster ar
            where ar.status='active'
              and ar.player_id is not null
              and ar.source_youth_id is null
          )
      )
      and not exists(
        select 1
        from public.world_doubles_tournament_matches wm
        where wm.tournament_id=tournaments.id
          and wm.winner_pair_id is null
          and coalesce(wm.matchup_components->>'status','')='managed_live_pending'
      )
    order by
      date_trunc('week',start_date::timestamp),
      case
        when category='Grand Chelem' then 100
        when category='Masters 1000' then 90
        when category='ATP 500' then 80
        when category='ATP 250' then 70
        when category='Challenger 175' then 60
        when category='Challenger 125' then 55
        when category='Challenger 100' then 50
        when category='Challenger 75' then 45
        when category='Challenger 50' then 40
        when category='M25' then 30
        when category='M15' then 25
        else 10 end desc,
      coalesce(end_date,start_date),id
    limit 120
  loop
    v_year:=extract(year from coalesce(t.end_date,t.start_date))::int;
    if not exists(select 1 from public.world_doubles_partnerships where season=v_year and active=true) then
      perform public.refresh_world_doubles_partnerships_fast(coalesce(t.start_date,p_to_date),2000);
    end if;

    v_draw:=greatest(4,least(64,coalesce(t.doubles_draw_size,16)));
    v_bracket:=case
      when v_draw<=8 then 8 when v_draw<=16 then 16 when v_draw<=32 then 32 else 64 end;
    v_byes:=v_bracket-v_draw;
    v_rounds:=ceil(ln(v_bracket::numeric)/ln(2::numeric))::int;
    v_qdraw:=case when t.circuit='ATP' and t.category='ATP 500' then 4 else 0 end;
    v_qslots:=case when v_qdraw=4 then 1 else 0 end;
    v_pool_needed:=v_draw+greatest(0,v_qdraw-v_qslots);
    v_wc_count:=0; -- V20 selectors reserve wildcard positions before acceptance.
    v_seed_limit:=case
      when t.category='Grand Chelem' and v_draw>=64 then 16
      when v_draw<=16 then 4
      else 8
    end;

    drop table if exists pg_temp.cb_d_entries;
    drop table if exists pg_temp.cb_d_current;
    drop table if exists pg_temp.cb_d_next;

    create temporary table cb_d_entries(
      pair_id bigint primary key,
      entry_method text not null default 'direct',
      score numeric,
      seed int,
      draw_slot int,
      had_bye boolean not null default false,
      matches_won int not null default 0,
      result_code text,
      points_awarded int not null default 0,
      prize_awarded numeric not null default 0,
      qualifying_points integer not null default 0,
      last_opponent_pair_id bigint,
      last_score text
    ) on commit drop;

    if t.circuit='ITF' and t.category in ('M15','M25') then
      insert into cb_d_entries(pair_id,entry_method,score)
      select f.pair_id,f.entry_method,f.score
      from public.select_itf_doubles_field_v20(t.id,v_managed) f;

    else
      insert into cb_d_entries(pair_id,entry_method,score)
      select f.pair_id,f.entry_method,f.score
      from public.select_pro_doubles_field_v20(t.id,v_managed) f;
    end if;

    select count(*) into v_selected from cb_d_entries;
    if v_selected<>v_pool_needed then continue; end if;

    if v_qdraw=4 and exists(
      select 1
      from public.world_doubles_qualifying_entries q
      where q.tournament_id=t.id and q.qualified=true
    ) then
      select q.pair_id into v_qwinner
      from public.world_doubles_qualifying_entries q
      where q.tournament_id=t.id and q.qualified=true
      order by q.id
      limit 1;

      if not exists(select 1 from cb_d_entries where pair_id=v_qwinner) then
        insert into cb_d_entries(pair_id,score,entry_method,qualifying_points)
        values(v_qwinner,-100000,'qualifier',45)
        on conflict(pair_id) do update set
          entry_method='qualifier',
          qualifying_points=greatest(cb_d_entries.qualifying_points,45);
      end if;

      delete from cb_d_entries e
      where e.pair_id in (
        select q.pair_id
        from public.world_doubles_qualifying_entries q
        where q.tournament_id=t.id and q.qualified=false
      );

      update cb_d_entries
      set entry_method='qualifier',qualifying_points=45
      where pair_id=v_qwinner;

      select count(*) into v_selected from cb_d_entries;
      while v_selected>v_draw loop
        delete from cb_d_entries
        where pair_id=(
          select e.pair_id
          from cb_d_entries e
          where e.pair_id<>v_qwinner
          order by e.score asc,e.pair_id desc
          limit 1
        );
        v_selected:=v_selected-1;
      end loop;
    else
    delete from public.world_doubles_qualifying_entries where tournament_id=t.id;
    delete from public.world_doubles_tournament_matches
    where tournament_id=t.id and is_qualifying=true;

    if v_qdraw=4 and v_qslots=1 then
      -- ATP 500 doubles qualifying: selector already reserved 3 direct + 1 qualifying WC.
      insert into public.world_doubles_qualifying_entries(
        tournament_id,pair_id,seed,entry_method,result_code,qualified,simulated_on,source_label
      )
      select
        t.id,z.pair_id,
        case when z.seed_order<=2 then z.seed_order else null end,
        z.entry_method,null,false,
        coalesce(t.qualifying_end_date,t.start_date),
        'ATP 2026 · ATP 500 doubles qualifying · combined PIF ATP Doubles Rankings'
      from (
        select e.pair_id,e.entry_method,
               row_number() over(
                 order by
                   public.player_doubles_seed_rank_at_date(
                     w.player_a_id,coalesce(t.qualifying_start_date,t.start_date)
                   )
                   + public.player_doubles_seed_rank_at_date(
                     w.player_b_id,coalesce(t.qualifying_start_date,t.start_date)
                   ),
                   least(
                     public.player_doubles_seed_rank_at_date(w.player_a_id,coalesce(t.qualifying_start_date,t.start_date)),
                     public.player_doubles_seed_rank_at_date(w.player_b_id,coalesce(t.qualifying_start_date,t.start_date))
                   ),
                   md5('dq-seed-tie|'||t.id::text||'|'||e.pair_id::text)
               )::int seed_order
        from cb_d_entries e
        join public.world_doubles_partnerships w on w.id=e.pair_id
        where e.entry_method in ('qualifying','qualifying_wildcard')
      ) z;

      select pair_id into v_a
      from public.world_doubles_qualifying_entries
      where tournament_id=t.id and seed=1
      limit 1;

      select pair_id into v_b
      from public.world_doubles_qualifying_entries
      where tournament_id=t.id and seed is null
      order by md5('dq-unseeded-a|'||t.id::text||'|'||pair_id::text)
      limit 1;

      v_match:=public.doubles_pair_matchup_v2(v_a,v_b,t.surface,coalesce(t.qualifying_end_date,t.start_date));
      v_prob:=greatest(.02,least(.98,coalesce((v_match->>'pair_a_probability')::numeric,.5)));
      v_awon:=random()<v_prob;
      v_qw1:=case when v_awon then v_a else v_b end;
      v_l:=case when v_awon then v_b else v_a end;
      v_score:=public.world_tournament_score(v_prob,v_awon,3);

      insert into public.world_doubles_tournament_matches(
        tournament_id,round_no,round_code,match_no,pair_a_id,pair_b_id,winner_pair_id,loser_pair_id,
        score,pair_a_win_probability,model_version,matchup_components,simulated_on,is_qualifying
      ) values(
        t.id,-2,'DQ1',1,v_a,v_b,v_qw1,v_l,v_score,round(v_prob,4),
        'CB-DOUBLES-v4-QUALIFYING',coalesce(v_match->'components','{}'::jsonb),
        coalesce(t.qualifying_end_date,t.start_date),true
      );
      update public.world_doubles_qualifying_entries set result_code='DQ1'
      where tournament_id=t.id and pair_id=v_l;

      select pair_id into v_a
      from public.world_doubles_qualifying_entries
      where tournament_id=t.id and seed=2
      limit 1;

      select pair_id into v_b
      from public.world_doubles_qualifying_entries
      where tournament_id=t.id and seed is null and pair_id<>v_b
      order by md5('dq-unseeded-b|'||t.id::text||'|'||pair_id::text)
      limit 1;

      v_match:=public.doubles_pair_matchup_v2(v_a,v_b,t.surface,coalesce(t.qualifying_end_date,t.start_date));
      v_prob:=greatest(.02,least(.98,coalesce((v_match->>'pair_a_probability')::numeric,.5)));
      v_awon:=random()<v_prob;
      v_qw2:=case when v_awon then v_a else v_b end;
      v_l:=case when v_awon then v_b else v_a end;
      v_score:=public.world_tournament_score(v_prob,v_awon,3);

      insert into public.world_doubles_tournament_matches(
        tournament_id,round_no,round_code,match_no,pair_a_id,pair_b_id,winner_pair_id,loser_pair_id,
        score,pair_a_win_probability,model_version,matchup_components,simulated_on,is_qualifying
      ) values(
        t.id,-2,'DQ1',2,v_a,v_b,v_qw2,v_l,v_score,round(v_prob,4),
        'CB-DOUBLES-v4-QUALIFYING',coalesce(v_match->'components','{}'::jsonb),
        coalesce(t.qualifying_end_date,t.start_date),true
      );
      update public.world_doubles_qualifying_entries set result_code='DQ1'
      where tournament_id=t.id and pair_id=v_l;

      v_a:=v_qw1; v_b:=v_qw2;
      v_match:=public.doubles_pair_matchup_v2(v_a,v_b,t.surface,coalesce(t.qualifying_end_date,t.start_date));
      v_prob:=greatest(.02,least(.98,coalesce((v_match->>'pair_a_probability')::numeric,.5)));
      v_awon:=random()<v_prob;
      v_qwinner:=case when v_awon then v_a else v_b end;
      v_l:=case when v_awon then v_b else v_a end;
      v_score:=public.world_tournament_score(v_prob,v_awon,3);

      insert into public.world_doubles_tournament_matches(
        tournament_id,round_no,round_code,match_no,pair_a_id,pair_b_id,winner_pair_id,loser_pair_id,
        score,pair_a_win_probability,model_version,matchup_components,simulated_on,is_qualifying
      ) values(
        t.id,-1,'DQF',1,v_a,v_b,v_qwinner,v_l,v_score,round(v_prob,4),
        'CB-DOUBLES-v4-QUALIFYING',coalesce(v_match->'components','{}'::jsonb),
        coalesce(t.qualifying_end_date,t.start_date),true
      );

      update public.world_doubles_qualifying_entries
      set result_code='DQF',points_awarded=25
      where tournament_id=t.id and pair_id=v_l;

      update public.world_doubles_qualifying_entries
      set result_code='Q',qualified=true,points_awarded=45
      where tournament_id=t.id and pair_id=v_qwinner;

      -- ATP 2026: the team losing the final qualifying round earns 25 points.
      insert into public.world_doubles_ranking_points(
        player_id,tournament_id,pair_id,label,earned_date,expiry_date,points,active,source_label
      )
      select w.player_a_id,t.id,w.id,t.name||' · DQF',
             coalesce(t.qualifying_end_date,t.start_date),
             coalesce(t.qualifying_end_date,t.start_date)+364,
             25,true,'ATP 500 doubles qualifying · final round'
      from public.world_doubles_partnerships w
      where w.id=v_l
      on conflict(player_id,tournament_id) do update set
        pair_id=excluded.pair_id,label=excluded.label,earned_date=excluded.earned_date,
        expiry_date=excluded.expiry_date,points=excluded.points,active=true,source_label=excluded.source_label;

      insert into public.world_doubles_ranking_points(
        player_id,tournament_id,pair_id,label,earned_date,expiry_date,points,active,source_label
      )
      select w.player_b_id,t.id,w.id,t.name||' · DQF',
             coalesce(t.qualifying_end_date,t.start_date),
             coalesce(t.qualifying_end_date,t.start_date)+364,
             25,true,'ATP 500 doubles qualifying · final round'
      from public.world_doubles_partnerships w
      where w.id=v_l
      on conflict(player_id,tournament_id) do update set
        pair_id=excluded.pair_id,label=excluded.label,earned_date=excluded.earned_date,
        expiry_date=excluded.expiry_date,points=excluded.points,active=true,source_label=excluded.source_label;

      update public.world_doubles_partnerships
      set race_points=race_points+25,
          last_refresh_date=greatest(last_refresh_date,coalesce(t.qualifying_end_date,t.start_date))
      where id=v_l;

      delete from cb_d_entries
      where entry_method in ('qualifying','qualifying_wildcard')
        and pair_id<>v_qwinner;

      update cb_d_entries
      set entry_method='qualifier',qualifying_points=45
      where pair_id=v_qwinner;
    end if;

    end if;

    select count(*) into v_selected from cb_d_entries;
    if v_selected<>v_draw then continue; end if;

    with seed_order as (
      select
        e.pair_id,
        row_number() over(
          order by
            public.player_doubles_seed_rank_at_date(
              w.player_a_id,
              case
                when t.category='Grand Chelem' then coalesce(t.main_draw_start_date,t.start_date)-7
                when t.circuit='ITF' then date_trunc('week',t.start_date::timestamp)::date-7
                else coalesce(t.main_draw_start_date,t.start_date)
              end
            )
            + public.player_doubles_seed_rank_at_date(
              w.player_b_id,
              case
                when t.category='Grand Chelem' then coalesce(t.main_draw_start_date,t.start_date)-7
                when t.circuit='ITF' then date_trunc('week',t.start_date::timestamp)::date-7
                else coalesce(t.main_draw_start_date,t.start_date)
              end
            ) asc,
            (
              select count(*)
              from public.world_doubles_tournament_entries pe
              join public.tournaments pt on pt.id=pe.tournament_id
              where pe.pair_id=e.pair_id
                and pt.start_date<
                  case
                    when t.category='Grand Chelem' then coalesce(t.main_draw_start_date,t.start_date)-7
                    when t.circuit='ITF' then date_trunc('week',t.start_date::timestamp)::date-7
                    else coalesce(t.main_draw_start_date,t.start_date)
                  end
                and pt.start_date>=
                  case
                    when t.category='Grand Chelem' then coalesce(t.main_draw_start_date,t.start_date)-371
                    when t.circuit='ITF' then date_trunc('week',t.start_date::timestamp)::date-371
                    else coalesce(t.main_draw_start_date,t.start_date)-364
                  end
            ) asc,
            public.player_doubles_seed_points_at_date(
              w.player_a_id,
              case
                when t.category='Grand Chelem' then coalesce(t.main_draw_start_date,t.start_date)-7
                when t.circuit='ITF' then date_trunc('week',t.start_date::timestamp)::date-7
                else coalesce(t.main_draw_start_date,t.start_date)
              end
            )
            + public.player_doubles_seed_points_at_date(
              w.player_b_id,
              case
                when t.category='Grand Chelem' then coalesce(t.main_draw_start_date,t.start_date)-7
                when t.circuit='ITF' then date_trunc('week',t.start_date::timestamp)::date-7
                else coalesce(t.main_draw_start_date,t.start_date)
              end
            ) desc,
            least(
              public.player_doubles_seed_rank_at_date(
                w.player_a_id,
                case
                  when t.category='Grand Chelem' then coalesce(t.main_draw_start_date,t.start_date)-7
                  when t.circuit='ITF' then date_trunc('week',t.start_date::timestamp)::date-7
                  else coalesce(t.main_draw_start_date,t.start_date)
                end
              ),
              public.player_doubles_seed_rank_at_date(
                w.player_b_id,
                case
                  when t.category='Grand Chelem' then coalesce(t.main_draw_start_date,t.start_date)-7
                  when t.circuit='ITF' then date_trunc('week',t.start_date::timestamp)::date-7
                  else coalesce(t.main_draw_start_date,t.start_date)
                end
              )
            ) asc,
            md5('dseed-tie|'||t.id::text||'|'||e.pair_id::text)
        )::int rn
      from cb_d_entries e
      join public.world_doubles_partnerships w on w.id=e.pair_id
      where t.circuit<>'ITF'
         or (
           public.player_doubles_seed_rank_at_date(
             w.player_a_id,date_trunc('week',t.start_date::timestamp)::date-7
           )<999999
           and
           public.player_doubles_seed_rank_at_date(
             w.player_b_id,date_trunc('week',t.start_date::timestamp)::date-7
           )<999999
         )
    )
    update cb_d_entries e
    set seed=case when seed_order.rn<=v_seed_limit then seed_order.rn else null end
    from seed_order
    where e.pair_id=seed_order.pair_id;

    -- deterministic spread of seeds, with byes assigned to top seeds
    update cb_d_entries
    set draw_slot=public.world_tournament_seed_slot_for_event(t.id,v_bracket,seed)
    where seed<=least(v_seed_limit,v_draw);

    if v_byes>0 then
      update cb_d_entries
      set had_bye=true
      where seed<=least(v_byes,v_seed_limit);
    end if;

    with used as (
      select draw_slot slot from cb_d_entries where draw_slot is not null
      union all
      select case when draw_slot%2=1 then draw_slot+1 else draw_slot-1 end
      from cb_d_entries where had_bye=true and draw_slot is not null
    ),
    avail as (
      select g slot,row_number() over(order by md5('dslot|'||t.id::text||'|'||g::text)) rn
      from generate_series(1,v_bracket) g
      where not exists(select 1 from used u where u.slot=g)
    ),
    unplaced as (
      select pair_id,row_number() over(order by md5('dpair|'||t.id::text||'|'||pair_id::text)) rn
      from cb_d_entries where draw_slot is null
    )
    update cb_d_entries e set draw_slot=a.slot
    from unplaced u join avail a using(rn)
    where e.pair_id=u.pair_id;

    create temporary table cb_d_current(pos int primary key,pair_id bigint) on commit drop;
    create temporary table cb_d_next(pos int primary key,pair_id bigint) on commit drop;
    insert into cb_d_current(pos,pair_id)
    select g,e.pair_id
    from generate_series(1,v_bracket) g
    left join cb_d_entries e on e.draw_slot=g;

    delete from public.world_doubles_tournament_matches where tournament_id=t.id and is_qualifying=false;
    v_size:=v_bracket;

    for v_round in 1..v_rounds loop
      truncate cb_d_next;
      v_next:=0;
      v_round_code:=case
        when v_round=1 and v_draw<>v_bracket then 'R'||v_draw::text
        when v_size>=64 then 'R64'
        when v_size>=32 then 'R32'
        when v_size>=16 then 'R16'
        when v_size>=8 then 'QF'
        when v_size>=4 then 'SF'
        else 'F' end;

      for v_pos in 1..v_size by 2 loop
        v_next:=v_next+1;
        select pair_id into v_a from cb_d_current where pos=v_pos;
        select pair_id into v_b from cb_d_current where pos=v_pos+1;

        if v_a is null and v_b is null then
          insert into cb_d_next(pos,pair_id) values(v_next,null);
          continue;
        elsif v_a is null or v_b is null then
          v_w:=coalesce(v_a,v_b);
          insert into cb_d_next(pos,pair_id) values(v_next,v_w);
          continue;
        end if;

        v_match:=public.doubles_pair_matchup_v2(v_a,v_b,t.surface,coalesce(t.end_date,t.start_date));
        v_prob:=greatest(.02,least(.98,coalesce((v_match->>'pair_a_probability')::numeric,.5)));
        v_awon:=random()<v_prob;
        v_w:=case when v_awon then v_a else v_b end;
        v_l:=case when v_awon then v_b else v_a end;
        v_score:=public.world_tournament_score(v_prob,v_awon,3);

        insert into public.world_doubles_tournament_matches(
          tournament_id,round_no,round_code,match_no,pair_a_id,pair_b_id,winner_pair_id,loser_pair_id,
          score,pair_a_win_probability,model_version,matchup_components,simulated_on
        ) values(
          t.id,v_round,v_round_code,(v_pos+1)/2,v_a,v_b,v_w,v_l,v_score,round(v_prob,4),
          'CB-DOUBLES-v3-FULLDRAW',coalesce(v_match->'components','{}'::jsonb),
          coalesce(t.end_date,t.start_date)
        );
        v_matches:=v_matches+1;

        v_points:=public.doubles_points_for_result(t.category,v_draw,v_round_code);
        v_prize:=public.tournament_prize_for_result(t.id,v_round_code,'doubles');
        update cb_d_entries
        set result_code=v_round_code,
            points_awarded=v_points+coalesce(qualifying_points,0),
            prize_awarded=v_prize,
            last_opponent_pair_id=v_w,
            last_score=case when v_l=v_a then v_score else public.world_invert_tennis_score(v_score) end
        where pair_id=v_l;
        update cb_d_entries set matches_won=matches_won+1 where pair_id=v_w;

        insert into cb_d_next(pos,pair_id) values(v_next,v_w);
      end loop;

      truncate cb_d_current;
      insert into cb_d_current select * from cb_d_next;
      v_size:=greatest(1,v_size/2);
    end loop;

    select pair_id into v_winner from cb_d_current order by pos limit 1;
    select loser_pair_id into v_finalist
    from public.world_doubles_tournament_matches
    where tournament_id=t.id and round_code='F'
    order by id desc limit 1;

    update cb_d_entries
    set result_code='W',
        points_awarded=public.doubles_points_for_result(t.category,v_draw,'W')+coalesce(qualifying_points,0),
        prize_awarded=public.tournament_prize_for_result(t.id,'W','doubles')
    where pair_id=v_winner;

    insert into public.world_doubles_tournament_entries(
      tournament_id,pair_id,entry_method,seed,draw_slot,had_bye,matches_won,result_code,result_label,
      points_awarded,prize_awarded,last_opponent_pair_id,last_score,simulated_on,source_label
    )
    select t.id,pair_id,entry_method,seed,draw_slot,had_bye,matches_won,result_code,
      case result_code when 'W' then 'Vainqueur' when 'F' then 'Finaliste'
        when 'SF' then 'Demi-finale' when 'QF' then 'Quart de finale'
        when 'R16' then '1/8 finale' when 'R24' then '1er tour · tableau 24'
        when 'R28' then '1er tour · tableau 28'
        when 'R32' then '1/16 finale' else result_code end,
      points_awarded,prize_awarded,last_opponent_pair_id,last_score,
      coalesce(t.end_date,t.start_date),'Court Boss doubles full draw'
    from cb_d_entries;

    insert into public.world_doubles_ranking_points(
      player_id,tournament_id,pair_id,label,earned_date,expiry_date,points,active,source_label
    )
    select w.player_a_id,t.id,e.pair_id,t.name||' · '||e.result_code,
           coalesce(t.end_date,t.start_date),coalesce(t.end_date,t.start_date)+364,
           e.points_awarded,true,'Court Boss doubles full draw'
    from cb_d_entries e join public.world_doubles_partnerships w on w.id=e.pair_id
    where e.points_awarded>0
    on conflict(player_id,tournament_id) do update set
      pair_id=excluded.pair_id,label=excluded.label,earned_date=excluded.earned_date,
      expiry_date=excluded.expiry_date,points=excluded.points,active=true,source_label=excluded.source_label;

    insert into public.world_doubles_ranking_points(
      player_id,tournament_id,pair_id,label,earned_date,expiry_date,points,active,source_label
    )
    select w.player_b_id,t.id,e.pair_id,t.name||' · '||e.result_code,
           coalesce(t.end_date,t.start_date),coalesce(t.end_date,t.start_date)+364,
           e.points_awarded,true,'Court Boss doubles full draw'
    from cb_d_entries e join public.world_doubles_partnerships w on w.id=e.pair_id
    where e.points_awarded>0
    on conflict(player_id,tournament_id) do update set
      pair_id=excluded.pair_id,label=excluded.label,earned_date=excluded.earned_date,
      expiry_date=excluded.expiry_date,points=excluded.points,active=true,source_label=excluded.source_label;

    update public.world_doubles_partnerships w
    set matches=w.matches+e.matches_won+case when e.result_code<>'W' then 1 else 0 end,
        wins=w.wins+e.matches_won,
        race_points=w.race_points+e.points_awarded,
        titles=w.titles+case when e.result_code='W' then 1 else 0 end,
        last_refresh_date=greatest(w.last_refresh_date,coalesce(t.end_date,t.start_date))
    from cb_d_entries e where w.id=e.pair_id;

    for entry_rec in
      select de.*,w.player_a_id,w.player_b_id,
             a.name a_name,b.name b_name
      from cb_d_entries de
      join public.world_doubles_partnerships w on w.id=de.pair_id
      join public.players a on a.id=w.player_a_id
      join public.players b on b.id=w.player_b_id
    loop
      if entry_rec.result_code='W' then
        insert into public.player_titles(player_id,tournament_name,title_date,level,surface,event_type,partner_player_id,partner_name,verified,source_label,origin)
        values
          (entry_rec.player_a_id,t.name,coalesce(t.end_date,t.start_date),t.category,t.surface,'doubles',entry_rec.player_b_id,entry_rec.b_name,false,'Court Boss doubles full draw','game'),
          (entry_rec.player_b_id,t.name,coalesce(t.end_date,t.start_date),t.category,t.surface,'doubles',entry_rec.player_a_id,entry_rec.a_name,false,'Court Boss doubles full draw','game')
        on conflict(player_id,tournament_name,title_date,event_type) do nothing;
      end if;
    end loop;

    insert into public.world_doubles_tournament_simulations(
      tournament_id,season,winner_pair_id,finalist_pair_id,winner_points,finalist_points,
      draw_size,simulated_on,source,final_win_probability,model_version,matchup_components
    )
    select t.id,v_year,v_winner,v_finalist,
      public.doubles_points_for_result(t.category,v_draw,'W'),
      public.doubles_points_for_result(t.category,v_draw,'F'),
      v_draw,coalesce(t.end_date,t.start_date),'Court Boss doubles full draw',
      case when m.winner_pair_id=m.pair_a_id then m.pair_a_win_probability else 1-m.pair_a_win_probability end,
      'CB-DOUBLES-v3-FULLDRAW',m.matchup_components
    from public.world_doubles_tournament_matches m
    where m.tournament_id=t.id and m.round_code='F'
    limit 1;

    v_simulated:=v_simulated+1;
  end loop;

  perform public.refresh_world_doubles_player_rankings(p_to_date);

  with ranked as (
    select id,row_number() over(order by race_points desc,pair_strength desc,affinity_score desc,id)::int rr
    from public.world_doubles_partnerships
    where season=extract(year from p_to_date)::int and active=true
  )
  update public.world_doubles_partnerships w set race_rank=r.rr from ranked r where w.id=r.id;

  return jsonb_build_object(
    'tournaments_simulated',v_simulated,'matches_simulated',v_matches,
    'from',p_from_date,'to',p_to_date,'ranking_model','best-18 rolling results',
    'match_model','CB-DOUBLES-v3-FULLDRAW'
  );
end
$function$;


CREATE OR REPLACE FUNCTION public.reserve_managed_doubles_live_matches_v22(p_date date)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
declare
  r record;
  t public.tournaments%rowtype;
  v_season int;
  v_user_pair bigint;
  v_opp_pair bigint;
  v_wins int;
  v_loss boolean;
  v_draw int;
  v_bracket int;
  v_rounds int;
  v_idx int;
  v_round_code text;
  v_match_date date;
  v_schedule jsonb;
  v_match_no int;
  v_existing bigint;
  v_reserved int:=0;
  v_rows jsonb:='[]'::jsonb;
begin
  for r in
    select distinct
      e.id,e.tournament_id,e.player_id,e.partner_id,e.entry_method,e.status,
      t.name,t.circuit,t.category,t.start_date,t.main_draw_start_date,t.end_date,t.doubles_draw_size
    from public.managed_doubles_entries e
    join public.tournaments t on t.id=e.tournament_id
    where e.owner_id='demo'
      and coalesce(e.status,'entered') not in ('withdrawn','declined','rejected','completed','played')
      and e.player_id in (
        select cs.managed_player_id
        from public.career_state cs
        where cs.id='demo' and cs.managed_player_id is not null
        union
        select ar.player_id
        from public.academy_roster ar
        where ar.status='active' and ar.player_id is not null and ar.source_youth_id is null
      )
      and p_date between coalesce(t.main_draw_start_date,t.start_date) and t.end_date
  loop
    select * into t from public.tournaments where id=r.tournament_id;
    v_season:=extract(year from coalesce(t.start_date,p_date))::int;

    v_user_pair:=public.ensure_world_doubles_partnership_team(
      v_season,r.player_id,r.partner_id,p_date,0,null
    );
    if coalesce(v_user_pair,0)=0 then
      continue;
    end if;

    select exists(
      select 1
      from public.live_match_sessions s
      where s.tournament_id=r.tournament_id
        and s.managed_player_id=r.player_id
        and s.status='committed'
        and coalesce(s.stats->'_meta'->>'match_type','')='doubles'
        and s.user_sets<s.opponent_sets
    ) into v_loss;
    if v_loss then
      continue;
    end if;

    select count(*)::int
    into v_wins
    from public.live_match_sessions s
    where s.tournament_id=r.tournament_id
      and s.managed_player_id=r.player_id
      and s.status='committed'
      and coalesce(s.stats->'_meta'->>'match_type','')='doubles'
      and s.user_sets>s.opponent_sets;

    v_draw:=greatest(4,coalesce(t.doubles_draw_size,16));
    v_bracket:=case when v_draw<=4 then 4 when v_draw<=8 then 8 when v_draw<=16 then 16
                    when v_draw<=32 then 32 else 64 end;
    v_rounds:=case v_bracket when 4 then 2 when 8 then 3 when 16 then 4 when 32 then 5 else 6 end;
    if v_wins>=v_rounds then
      continue;
    end if;

    v_idx:=v_wins+1;
    v_round_code:=case
      when v_idx=v_rounds then 'F'
      when v_idx=v_rounds-1 then 'SF'
      when v_idx=v_rounds-2 then 'QF'
      when v_idx=v_rounds-3 then 'R16'
      when v_idx=v_rounds-4 then 'R32'
      else 'R64'
    end;

    v_schedule:=public.managed_tournament_match_date_v22(
      r.tournament_id,r.player_id,v_round_code,'main','doubles'
    );
    v_match_date:=nullif(v_schedule->>'match_date','')::date;
    if v_match_date is null or v_match_date>p_date then
      continue;
    end if;

    select m.id into v_existing
    from public.world_doubles_tournament_matches m
    where m.tournament_id=r.tournament_id
      and m.winner_pair_id is null
      and (m.pair_a_id=v_user_pair or m.pair_b_id=v_user_pair)
    order by m.round_no,m.match_no
    limit 1;

    if v_existing is not null then
      update public.world_doubles_tournament_matches
      set matchup_components=coalesce(matchup_components,'{}'::jsonb)
            ||jsonb_build_object(
              'status','managed_live_pending',
              'managed_player_id',r.player_id,
              'partner_id',r.partner_id,
              'scheduled_date',v_match_date,
              'source','managed_daily_v22'
            ),
          model_version='CB-LIVE-DOUBLES-v22-PENDING',
          simulated_on=coalesce(simulated_on,v_match_date)
      where id=v_existing;

      v_rows:=v_rows||jsonb_build_array(jsonb_build_object(
        'tournament_id',r.tournament_id,'player_id',r.player_id,
        'world_match_id',v_existing,'existing',true,'round',v_round_code,
        'match_date',v_match_date
      ));
      continue;
    end if;

    if t.circuit='ITF' and t.category in ('M15','M25') then
      select f.pair_id into v_opp_pair
      from public.select_itf_doubles_field_v20(t.id,r.player_id) f
      join public.world_doubles_partnerships w on w.id=f.pair_id
      where f.pair_id<>v_user_pair
        and w.active=true
        and r.player_id not in (w.player_a_id,w.player_b_id)
        and r.partner_id not in (w.player_a_id,w.player_b_id)
        and not exists(
          select 1 from public.world_doubles_tournament_matches old
          where old.tournament_id=r.tournament_id
            and (
              (old.pair_a_id=v_user_pair and old.pair_b_id=f.pair_id)
              or (old.pair_b_id=v_user_pair and old.pair_a_id=f.pair_id)
            )
        )
        and not exists(
          select 1
          from public.academy_roster ar
          where ar.status='active'
            and ar.source_youth_id is null
            and ar.player_id in (w.player_a_id,w.player_b_id)
        )
        and not exists(
          select 1 from public.career_state cs
          where cs.id='demo'
            and cs.managed_player_id in (w.player_a_id,w.player_b_id)
        )
      order by md5(
        'managed-doubles-live-v22|'||r.tournament_id::text||'|'||
        v_user_pair::text||'|'||v_wins::text||'|'||f.pair_id::text
      )
      limit 1;
    else
      select f.pair_id into v_opp_pair
      from public.select_pro_doubles_field_v20(t.id,r.player_id) f
      join public.world_doubles_partnerships w on w.id=f.pair_id
      where f.pair_id<>v_user_pair
        and w.active=true
        and r.player_id not in (w.player_a_id,w.player_b_id)
        and r.partner_id not in (w.player_a_id,w.player_b_id)
        and not exists(
          select 1 from public.world_doubles_tournament_matches old
          where old.tournament_id=r.tournament_id
            and (
              (old.pair_a_id=v_user_pair and old.pair_b_id=f.pair_id)
              or (old.pair_b_id=v_user_pair and old.pair_a_id=f.pair_id)
            )
        )
        and not exists(
          select 1
          from public.academy_roster ar
          where ar.status='active'
            and ar.source_youth_id is null
            and ar.player_id in (w.player_a_id,w.player_b_id)
        )
        and not exists(
          select 1 from public.career_state cs
          where cs.id='demo'
            and cs.managed_player_id in (w.player_a_id,w.player_b_id)
        )
      order by md5(
        'managed-doubles-live-v22|'||r.tournament_id::text||'|'||
        v_user_pair::text||'|'||v_wins::text||'|'||f.pair_id::text
      )
      limit 1;
    end if;

    if coalesce(v_opp_pair,0)=0 then
      select w.id into v_opp_pair
      from public.world_doubles_partnerships w
      where w.season=v_season
        and w.active=true
        and w.id<>v_user_pair
        and r.player_id not in (w.player_a_id,w.player_b_id)
        and r.partner_id not in (w.player_a_id,w.player_b_id)
        and not exists(
          select 1 from public.world_doubles_tournament_matches old
          where old.tournament_id=r.tournament_id
            and (
              (old.pair_a_id=v_user_pair and old.pair_b_id=w.id)
              or (old.pair_b_id=v_user_pair and old.pair_a_id=w.id)
            )
        )
      order by abs(coalesce(w.race_rank,999999)-coalesce((
        select race_rank from public.world_doubles_partnerships where id=v_user_pair
      ),999999)),
      md5('managed-doubles-fallback-v22|'||r.tournament_id::text||'|'||w.id::text)
      limit 1;
    end if;

    if coalesce(v_opp_pair,0)=0 then
      continue;
    end if;

    select coalesce(min(g),1) into v_match_no
    from generate_series(1,greatest(1,v_bracket/(2^v_idx)::int)) g
    where not exists(
      select 1 from public.world_doubles_tournament_matches m
      where m.tournament_id=r.tournament_id
        and m.round_no=v_idx
        and m.match_no=g
        and coalesce(m.is_qualifying,false)=false
    );

    if v_match_no is null then
      select coalesce(max(match_no),0)+1 into v_match_no
      from public.world_doubles_tournament_matches
      where tournament_id=r.tournament_id and round_no=v_idx;
    end if;

    insert into public.world_doubles_tournament_matches(
      tournament_id,round_no,round_code,match_no,pair_a_id,pair_b_id,
      winner_pair_id,loser_pair_id,score,pair_a_win_probability,
      model_version,matchup_components,simulated_on,is_qualifying
    ) values(
      r.tournament_id,v_idx,v_round_code,v_match_no,v_user_pair,v_opp_pair,
      null,null,null,null,
      'CB-LIVE-DOUBLES-v22-PENDING',
      jsonb_build_object(
        'status','managed_live_pending',
        'managed_player_id',r.player_id,
        'partner_id',r.partner_id,
        'user_pair_id',v_user_pair,
        'opponent_pair_id',v_opp_pair,
        'scheduled_date',v_match_date,
        'source','managed_daily_v22'
      ),
      v_match_date,false
    )
    returning id into v_existing;

    v_reserved:=v_reserved+1;
    v_rows:=v_rows||jsonb_build_array(jsonb_build_object(
      'tournament_id',r.tournament_id,'player_id',r.player_id,
      'world_match_id',v_existing,'existing',false,'round',v_round_code,
      'match_date',v_match_date,'user_pair_id',v_user_pair,'opponent_pair_id',v_opp_pair
    ));
  end loop;

  return jsonb_build_object(
    'ok',true,'date',p_date,'reserved',v_reserved,'matches',v_rows,
    'model','CB-MANAGED-DOUBLES-LIVE-PENDING-v22'
  );
end;
$function$;

revoke all on function public.reserve_managed_doubles_live_matches_v22(date) from public,anon,authenticated;
grant execute on function public.reserve_managed_doubles_live_matches_v22(date) to service_role;


CREATE OR REPLACE FUNCTION public.advance_managed_tournament_world_day_v22(p_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  r record;
  v_q jsonb;
  v_main jsonb;
  v_doubles jsonb:='{}'::jsonb;
  v_rows jsonb:='[]'::jsonb;
begin
  for r in
    select distinct e.tournament_id,t.name,t.qualifying_start_date,t.qualifying_end_date,
           t.main_draw_start_date,t.start_date,t.end_date
    from public.entries e
    join public.tournaments t on t.id=e.tournament_id
    where e.player_id in (
      select cs.managed_player_id from public.career_state cs where cs.id='demo'
      union
      select ar.player_id from public.academy_roster ar
      where ar.status='active' and ar.player_id is not null and ar.source_youth_id is null
    )
      and coalesce(e.status,'entered') not in ('withdrawn','declined','rejected','completed')
      and p_date between coalesce(t.qualifying_start_date,t.main_draw_start_date,t.start_date) and t.end_date
  loop
    v_q:=null; v_main:=null;
    if r.qualifying_start_date is not null
       and p_date between r.qualifying_start_date and coalesce(r.qualifying_end_date,r.qualifying_start_date)
    then
      v_q:=public.advance_world_qualifying_tournament(r.tournament_id,p_date);
    end if;
    if p_date>=coalesce(r.main_draw_start_date,r.start_date) then
      v_main:=public.advance_world_knockout_tournament(r.tournament_id,p_date);
    end if;
    v_rows:=v_rows||jsonb_build_array(jsonb_build_object(
      'tournament_id',r.tournament_id,'name',r.name,
      'qualifying',v_q,'main',v_main
    ));
  end loop;

  v_doubles:=public.reserve_managed_doubles_live_matches_v22(p_date);

  return jsonb_build_object(
    'ok',true,'date',p_date,'events',v_rows,
    'count',jsonb_array_length(v_rows),
    'doubles',v_doubles,
    'model','CB-MANAGED-TOURNAMENT-WORLD-DAY-v22'
  );
end;
$function$;
