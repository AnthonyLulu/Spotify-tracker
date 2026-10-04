-- Serialize retry/concurrent tournament progression for one tournament.
-- Applied to Supabase as migration 20261004111805.
CREATE OR REPLACE FUNCTION public.advance_world_knockout_tournament(p_tournament_id bigint, p_to_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  r public.tournament_format_rules%rowtype;
  st public.world_tournament_states%rowtype;
  v_main_start date;
  v_end date;
  v_span integer;
  v_round integer;
  v_round_code text;
  v_round_date date;
  v_match_count integer;
  v_match_no integer;
  v_a bigint;
  v_b bigint;
  v_winner bigint;
  v_loser bigint;
  v_a_name text;
  v_b_name text;
  v_winner_name text;
  v_loser_name text;
  v_match jsonb;
  v_prob numeric;
  v_a_won boolean;
  v_score text;
  v_loser_score text;
  v_loser_wins integer;
  v_loser_bye boolean;
  v_loser_method text;
  v_base_points integer;
  v_qual_points integer;
  v_best_of integer:=3;
  v_rounds_advanced integer:=0;
  v_actual_matches integer:=0;
  v_champion bigint;
  v_finalist bigint;
  v_champion_name text;
  v_finalist_name text;
  v_champion_points integer;
  v_finalist_points integer;
  v_final_prob numeric;
  v_final_components jsonb:='{}'::jsonb;
  v_weight numeric;
  v_a_forfeit boolean:=false;
  v_b_forfeit boolean:=false;
  v_substitutions jsonb:='{}'::jsonb;
  v_managed_player bigint;
  v_managed_match_date date;
begin
  -- One tournament progression transaction at a time. This makes concurrent
  -- commit retries converge on the same bracket state instead of racing.
  perform pg_advisory_xact_lock(
    hashtextextended('court_boss_world_advance:'||p_tournament_id::text,0)
  );
  select * into t from public.tournaments
  where id=p_tournament_id and singles=true and coalesce(is_active,true)=true;
  if t.id is null then
    return jsonb_build_object('skipped','tournament_not_found','tournament_id',p_tournament_id);
  end if;

  select * into st from public.world_tournament_states where tournament_id=t.id;
  if st.tournament_id is null then
    perform public.prepare_world_knockout_tournament(
      t.id,coalesce(t.qualifying_end_date,t.main_draw_start_date,t.start_date,p_to_date)
    );
    select * into st from public.world_tournament_states where tournament_id=t.id;
  end if;
  if st.tournament_id is null then
    return jsonb_build_object('skipped','draw_not_prepared','tournament_id',t.id);
  end if;
  if st.status='completed' then
    return jsonb_build_object('ok',true,'tournament_id',t.id,'status','completed','already_completed',true);
  end if;

  select * into r from public.tournament_format_rules x
  where x.rule_key=st.rule_key limit 1;
  if r.rule_key is null or r.format_type<>'knockout' then
    return jsonb_build_object('skipped','invalid_format_state','tournament_id',t.id);
  end if;

  v_substitutions:=public.apply_world_post_draw_substitutions(t.id,p_to_date);
  select * into st from public.world_tournament_states where tournament_id=t.id;

  v_main_start:=coalesce(t.main_draw_start_date,t.start_date);
  v_end:=coalesce(t.end_date,v_main_start);
  v_span:=greatest(0,v_end-v_main_start);
  v_best_of:=case when t.circuit='ATP' and t.category='Grand Chelem' then 5 else 3 end;

  if p_to_date<v_main_start then
    return jsonb_build_object(
      'ok',true,'tournament_id',t.id,'status',st.status,
      'current_round_no',st.current_round_no,'next_round_date',v_main_start
    );
  end if;

  for v_round in (st.current_round_no+1)..st.rounds_count loop
    v_round_code:=r.rounds[v_round];
    v_round_date:=v_main_start+
      case when st.rounds_count<=1 then 0
           else round((v_round-1)::numeric*v_span/greatest(1,st.rounds_count-1))::int end;
    exit when v_round_date>p_to_date;

    v_match_count:=greatest(1,st.bracket_size/(power(2,v_round)::int));

    for v_match_no in 1..v_match_count loop
      if v_round=1 then
        select player_id into v_a from public.world_tournament_entries
        where tournament_id=t.id and draw_slot=v_match_no*2-1;
        select player_id into v_b from public.world_tournament_entries
        where tournament_id=t.id and draw_slot=v_match_no*2;
      else
        select winner_id into v_a from public.world_tournament_matches
        where tournament_id=t.id and coalesce(is_qualifying,false)=false
          and round_no=v_round-1 and match_no=v_match_no*2-1;
        select winner_id into v_b from public.world_tournament_matches
        where tournament_id=t.id and coalesce(is_qualifying,false)=false
          and round_no=v_round-1 and match_no=v_match_no*2;
      end if;

      if exists(
        select 1 from public.world_tournament_matches
        where tournament_id=t.id and round_no=v_round and match_no=v_match_no
          and coalesce(is_qualifying,false)=false
      ) then
        continue;
      end if;

      if v_a is null and v_b is null then
        insert into public.world_tournament_matches(
          tournament_id,round_no,round_code,match_no,player_a_id,player_b_id,
          winner_id,loser_id,score,best_of,player_a_win_probability,court_speed,
          model_version,matchup_components,simulated_on,is_qualifying
        ) values(
          t.id,v_round,v_round_code,v_match_no,null,null,null,null,'BYE',v_best_of,null,
          coalesce(t.court_speed,case when t.surface ilike 'Terre%' then .68 when t.surface ilike 'Gazon%' then 1.15 when coalesce(t.indoor,false) then 1.18 else 1.0 end),
          'CB-MATCH-v5-PROGRESSIVE','{"bye":true,"empty":true}'::jsonb,v_round_date,false
        );
        continue;
      elsif v_a is null or v_b is null then
        v_winner:=coalesce(v_a,v_b);
        update public.world_tournament_entries
        set had_bye=true
        where tournament_id=t.id and player_id=v_winner;

        insert into public.world_tournament_matches(
          tournament_id,round_no,round_code,match_no,player_a_id,player_b_id,
          winner_id,loser_id,score,best_of,player_a_win_probability,court_speed,
          model_version,matchup_components,simulated_on,is_qualifying
        ) values(
          t.id,v_round,v_round_code,v_match_no,v_a,v_b,v_winner,null,'BYE',v_best_of,null,
          coalesce(t.court_speed,case when t.surface ilike 'Terre%' then .68 when t.surface ilike 'Gazon%' then 1.15 when coalesce(t.indoor,false) then 1.18 else 1.0 end),
          'CB-MATCH-v5-PROGRESSIVE','{"bye":true}'::jsonb,v_round_date,false
        );
        continue;
      end if;

      select name into v_a_name from public.players where id=v_a;
      select name into v_b_name from public.players where id=v_b;

      select exists(
        select 1 from public.tournament_forfeits f
        where f.tournament_id=t.id and f.player_id=v_a
      ) into v_a_forfeit;
      select exists(
        select 1 from public.tournament_forfeits f
        where f.tournament_id=t.id and f.player_id=v_b
      ) into v_b_forfeit;

      if v_a_forfeit or v_b_forfeit then
        if v_a_forfeit and v_b_forfeit then
          insert into public.world_tournament_matches(
            tournament_id,round_no,round_code,match_no,
            player_a_id,player_b_id,winner_id,loser_id,score,best_of,
            player_a_win_probability,court_speed,model_version,matchup_components,
            simulated_on,is_qualifying
          ) values(
            t.id,v_round,v_round_code,v_match_no,
            v_a,v_b,null,null,'DOUBLE W/O',v_best_of,null,
            coalesce(t.court_speed,case when t.surface ilike 'Terre%' then .68 when t.surface ilike 'Gazon%' then 1.15 when coalesce(t.indoor,false) then 1.18 else 1.0 end),
            'CB-MATCH-v6-PROGRESSIVE-WO',
            '{"walkover":true,"double_withdrawal":true}'::jsonb,
            v_round_date,false
          );

          update public.world_tournament_entries e
          set result_code=v_round_code,
              result_label=public.world_tournament_result_label(v_round_code),
              points_awarded=greatest(
                0,
                coalesce((r.points_by_result->>v_round_code)::int,0)+coalesce(e.qualifying_points,0)
              ),
              last_opponent_id=case when e.player_id=v_a then v_b else v_a end,
              last_opponent_name=case when e.player_id=v_a then v_b_name else v_a_name end,
              last_score='W/O',
              simulated_on=v_round_date
          where e.tournament_id=t.id and e.player_id in (v_a,v_b);
        else
          v_winner:=case when v_a_forfeit then v_b else v_a end;
          v_loser:=case when v_a_forfeit then v_a else v_b end;
          v_winner_name:=case when v_a_forfeit then v_b_name else v_a_name end;
          v_loser_name:=case when v_a_forfeit then v_a_name else v_b_name end;

          insert into public.world_tournament_matches(
            tournament_id,round_no,round_code,match_no,
            player_a_id,player_b_id,winner_id,loser_id,score,best_of,
            player_a_win_probability,court_speed,model_version,matchup_components,
            simulated_on,is_qualifying
          ) values(
            t.id,v_round,v_round_code,v_match_no,
            v_a,v_b,v_winner,v_loser,'W/O',v_best_of,null,
            coalesce(t.court_speed,case when t.surface ilike 'Terre%' then .68 when t.surface ilike 'Gazon%' then 1.15 when coalesce(t.indoor,false) then 1.18 else 1.0 end),
            'CB-MATCH-v6-PROGRESSIVE-WO',
            jsonb_build_object(
              'walkover',true,
              'withdrawn_player_id',v_loser,
              'advanced_player_id',v_winner
            ),
            v_round_date,false
          );

          select matches_won,had_bye,entry_method,qualifying_points
          into v_loser_wins,v_loser_bye,v_loser_method,v_qual_points
          from public.world_tournament_entries
          where tournament_id=t.id and player_id=v_loser;

          v_base_points:=coalesce((r.points_by_result->>v_round_code)::int,0);
          if coalesce(v_loser_bye,false) and coalesce(v_loser_wins,0)=0 then
            v_base_points:=coalesce((r.points_by_result->>r.rounds[1])::int,0);
          end if;
          if coalesce(v_loser_method,'') like 'wildcard%'
             and coalesce(v_loser_wins,0)=0
             and t.category in ('Grand Chelem','Masters 1000') then
            v_base_points:=0;
          end if;

          update public.world_tournament_entries
          set result_code=v_round_code,
              result_label=public.world_tournament_result_label(v_round_code),
              points_awarded=greatest(0,v_base_points+coalesce(v_qual_points,0)),
              last_opponent_id=v_winner,
              last_opponent_name=v_winner_name,
              last_score='W/O',
              simulated_on=v_round_date
          where tournament_id=t.id and player_id=v_loser;

          update public.world_tournament_entries
          set simulated_on=v_round_date
          where tournament_id=t.id and player_id=v_winner;
        end if;
        continue;
      end if;

      if exists(
        select 1
        from public.academy_roster ar
        where ar.status='active'
          and ar.player_id in (v_a,v_b)
      ) or exists(
        select 1
        from public.career_state cs
        where cs.id='demo'
          and cs.managed_player_id in (v_a,v_b)
      ) then
        select x.player_id into v_managed_player
        from (
          select ar.player_id,1 as priority
          from public.academy_roster ar
          where ar.status='active' and ar.player_id in (v_a,v_b)
          union all
          select cs.managed_player_id,0
          from public.career_state cs
          where cs.id='demo' and cs.managed_player_id in (v_a,v_b)
        ) x
        order by x.priority,x.player_id
        limit 1;

        v_managed_match_date:=coalesce(
          nullif(
            public.managed_tournament_match_date_v22(
              t.id,v_managed_player,v_round_code,'main','singles'
            )->>'match_date',''
          )::date,
          v_round_date
        );

        insert into public.world_tournament_matches(
          tournament_id,round_no,round_code,match_no,
          player_a_id,player_b_id,winner_id,loser_id,score,best_of,
          player_a_win_probability,court_speed,model_version,matchup_components,
          simulated_on,is_qualifying
        ) values(
          t.id,v_round,v_round_code,v_match_no,
          v_a,v_b,null,null,null,v_best_of,null,
          coalesce(t.court_speed,case when t.surface ilike 'Terre%' then .68 when t.surface ilike 'Gazon%' then 1.15 when coalesce(t.indoor,false) then 1.18 else 1.0 end),
          'CB-MATCH-ENGINE-v6-LIVE-PENDING',
          jsonb_build_object(
            'status','managed_live_pending',
            'managed_player_ids',(
              select coalesce(jsonb_agg(x.player_id),'[]'::jsonb)
              from (
                select distinct ar.player_id
                from public.academy_roster ar
                where ar.status='active' and ar.player_id in (v_a,v_b)
                union
                select cs.managed_player_id
                from public.career_state cs
                where cs.id='demo' and cs.managed_player_id in (v_a,v_b)
              ) x
            )
          ),
          v_managed_match_date,false
        );
        continue;
      end if;

      v_match:=public.player_matchup_probability_v4(
        v_a,v_b,t.surface,v_round_date,
        coalesce(t.court_speed,case when t.surface ilike 'Terre%' then .68 when t.surface ilike 'Gazon%' then 1.15 when coalesce(t.indoor,false) then 1.18 else 1.0 end),
        v_best_of
      );
      v_prob:=greatest(.02,least(.98,coalesce((v_match->>'player_a_probability')::numeric,.5)));
      v_a_won:=random()<v_prob;
      v_winner:=case when v_a_won then v_a else v_b end;
      v_loser:=case when v_a_won then v_b else v_a end;
      v_winner_name:=case when v_a_won then v_a_name else v_b_name end;
      v_loser_name:=case when v_a_won then v_b_name else v_a_name end;
      v_score:=public.world_tournament_score(v_prob,v_a_won,v_best_of);
      v_loser_score:=case when v_loser=v_a then v_score else public.world_invert_tennis_score(v_score) end;

      insert into public.world_tournament_matches(
        tournament_id,round_no,round_code,match_no,
        player_a_id,player_b_id,winner_id,loser_id,score,best_of,
        player_a_win_probability,court_speed,model_version,matchup_components,
        simulated_on,is_qualifying
      ) values(
        t.id,v_round,v_round_code,v_match_no,
        v_a,v_b,v_winner,v_loser,v_score,v_best_of,round(v_prob,4),
        coalesce(t.court_speed,case when t.surface ilike 'Terre%' then .68 when t.surface ilike 'Gazon%' then 1.15 when coalesce(t.indoor,false) then 1.18 else 1.0 end),
        'CB-MATCH-v5-PROGRESSIVE',
        coalesce(v_match->'components','{}'::jsonb)
          ||jsonb_build_object('extended_attributes',coalesce(v_match->'extended_attributes','{}'::jsonb)),
        v_round_date,false
      );
      v_actual_matches:=v_actual_matches+1;

      select matches_won,had_bye,entry_method,qualifying_points
      into v_loser_wins,v_loser_bye,v_loser_method,v_qual_points
      from public.world_tournament_entries
      where tournament_id=t.id and player_id=v_loser;

      v_base_points:=coalesce((r.points_by_result->>v_round_code)::int,0);
      if coalesce(v_loser_bye,false) and coalesce(v_loser_wins,0)=0 then
        v_base_points:=coalesce((r.points_by_result->>r.rounds[1])::int,0);
      end if;
      if coalesce(v_loser_method,'') like 'wildcard%'
         and coalesce(v_loser_wins,0)=0
         and t.category in ('Grand Chelem','Masters 1000') then
        v_base_points:=0;
      end if;

      update public.world_tournament_entries
      set result_code=v_round_code,
          result_label=public.world_tournament_result_label(v_round_code),
          points_awarded=greatest(0,v_base_points+coalesce(v_qual_points,0)),
          last_opponent_id=v_winner,
          last_opponent_name=v_winner_name,
          last_score=v_loser_score,
          simulated_on=v_round_date
      where tournament_id=t.id and player_id=v_loser;

      update public.world_tournament_entries
      set matches_won=matches_won+1,simulated_on=v_round_date
      where tournament_id=t.id and player_id=v_winner;

      update public.players
      set fatigue=least(100,coalesce(fatigue,20)+2),
          fitness=greatest(35,coalesce(fitness,90)-1)
      where id in (v_winner,v_loser);

      perform public.update_h2h_after_match(
        v_winner,v_loser,t.surface,v_round_date,false,
        'Court Boss progressive world draw · '||v_round_code
      );
      v_weight:=case
        when v_round_code='F' then case when t.category='Grand Chelem' then 1.20 when t.category='Masters 1000' then 1.15 else 1.10 end
        when v_round_code='SF' then 1.08
        when v_round_code='QF' then 1.04
        else 1.0 end;
      perform public.update_player_elo_after_match(v_winner,v_loser,t.surface,v_round_date,false,v_weight);

      update public.player_dynamic_ratings d
      set overall_elo=e.overall_elo,hard_elo=e.hard_elo,clay_elo=e.clay_elo,grass_elo=e.grass_elo,
          rating_confidence=greatest(d.rating_confidence,e.confidence),
          last_competitive_match=v_round_date,
          source_label='Court Boss live hybrid Elo · progressive world draw',
          updated_at=now()
      from public.player_elo_ratings e
      where e.player_id=d.player_id and d.player_id in (v_winner,v_loser);
    end loop;

    if exists(
      select 1
      from public.world_tournament_matches m
      where m.tournament_id=t.id
        and coalesce(m.is_qualifying,false)=false
        and m.round_no=v_round
        and m.winner_id is null
        and (
          exists(
            select 1 from public.academy_roster ar
            where ar.status='active'
              and ar.player_id in (m.player_a_id,m.player_b_id)
          )
          or exists(
            select 1 from public.career_state cs
            where cs.id='demo'
              and cs.managed_player_id in (m.player_a_id,m.player_b_id)
          )
        )
    ) then
      return jsonb_build_object(
        'ok',true,'tournament_id',t.id,'name',t.name,
        'status','waiting_managed','current_round_no',st.current_round_no,
        'waiting_round_no',v_round,'waiting_round_code',v_round_code,
        'scheduled_date',(
          select min(m.simulated_on)
          from public.world_tournament_matches m
          where m.tournament_id=t.id
            and coalesce(m.is_qualifying,false)=false
            and m.round_no=v_round
            and m.winner_id is null
            and (
              exists(select 1 from public.academy_roster ar where ar.status='active' and ar.player_id in (m.player_a_id,m.player_b_id))
              or exists(select 1 from public.career_state cs where cs.id='demo' and cs.managed_player_id in (m.player_a_id,m.player_b_id))
            )
        ),'matches_played',v_actual_matches,
        'model','CB-MATCH-v6-MANAGED-DAILY'
      );
    end if;

    update public.world_tournament_states
    set status='live',current_round_no=v_round,last_advanced_on=v_round_date,updated_at=now()
    where tournament_id=t.id;
    v_rounds_advanced:=v_rounds_advanced+1;

    if v_round=st.rounds_count then
      select winner_id,loser_id,player_a_win_probability,matchup_components
      into v_champion,v_finalist,v_final_prob,v_final_components
      from public.world_tournament_matches
      where tournament_id=t.id and round_no=v_round and round_code='F'
        and coalesce(is_qualifying,false)=false
      order by match_no limit 1;

      if v_champion is null or v_finalist is null then
        return jsonb_build_object('skipped','final_missing_players','tournament_id',t.id);
      end if;

      select name into v_champion_name from public.players where id=v_champion;
      select name into v_finalist_name from public.players where id=v_finalist;
      select qualifying_points into v_qual_points from public.world_tournament_entries
      where tournament_id=t.id and player_id=v_champion;
      v_champion_points:=coalesce((r.points_by_result->>'W')::int,0)+coalesce(v_qual_points,0);

      update public.world_tournament_entries
      set result_code='W',result_label='Vainqueur',
          points_awarded=greatest(0,v_champion_points),
          last_opponent_id=v_finalist,last_opponent_name=v_finalist_name,
          last_score=case
            when (select player_a_id from public.world_tournament_matches where tournament_id=t.id and round_code='F' and coalesce(is_qualifying,false)=false limit 1)=v_champion
            then (select score from public.world_tournament_matches where tournament_id=t.id and round_code='F' and coalesce(is_qualifying,false)=false limit 1)
            else public.world_invert_tennis_score((select score from public.world_tournament_matches where tournament_id=t.id and round_code='F' and coalesce(is_qualifying,false)=false limit 1))
          end,
          simulated_on=v_round_date
      where tournament_id=t.id and player_id=v_champion;

      select points_awarded into v_finalist_points from public.world_tournament_entries
      where tournament_id=t.id and player_id=v_finalist;

      update public.world_tournament_entries e
      set prize_awarded=public.tournament_prize_for_result(t.id,e.result_code,'singles'),
          prize_currency=coalesce(t.prize_currency,'USD'),
          prize_is_estimate=coalesce(t.singles_prize_is_estimate,t.prize_breakdown_is_estimate,true)
      where e.tournament_id=t.id;

      insert into public.world_ranking_points(
        player_id,tournament_id,label,earned_date,expiry_date,points,active,source_label
      )
      select e.player_id,t.id,t.name||' · '||e.result_code,
             coalesce(t.end_date,t.start_date),coalesce(t.end_date,t.start_date)+364,
             e.points_awarded,true,
             'Court Boss progressive draw · '||e.result_code||' · '||r.rule_key
      from public.world_tournament_entries e
      where e.tournament_id=t.id and e.points_awarded>0
      on conflict(player_id,tournament_id) do update set
        label=excluded.label,earned_date=excluded.earned_date,expiry_date=excluded.expiry_date,
        points=excluded.points,active=true,source_label=excluded.source_label;

      insert into public.player_tournament_history(
        player_id,season,tournament_id,tournament_name,tournament_date,level,category,surface,
        result_code,result_label,last_opponent,last_score,is_grand_slam,source,event_type
      )
      select e.player_id,extract(year from coalesce(t.end_date,t.start_date))::int,
             t.id::text,t.name,coalesce(t.end_date,t.start_date),
             coalesce(t.level,t.category,t.circuit),t.category,t.surface,
             e.result_code,e.result_label,e.last_opponent_name,e.last_score,
             t.category='Grand Chelem','Court Boss progressive world draw · '||r.rule_key,'singles'
      from public.world_tournament_entries e
      where e.tournament_id=t.id
      on conflict(player_id,event_type,tournament_id) do update set
        season=excluded.season,tournament_name=excluded.tournament_name,tournament_date=excluded.tournament_date,
        level=excluded.level,category=excluded.category,surface=excluded.surface,
        result_code=excluded.result_code,result_label=excluded.result_label,
        last_opponent=excluded.last_opponent,last_score=excluded.last_score,
        is_grand_slam=excluded.is_grand_slam,source=excluded.source;

      insert into public.player_titles(
        player_id,tournament_name,title_date,level,surface,event_type,verified,source_label,origin
      ) values(
        v_champion,t.name,coalesce(t.end_date,t.start_date),
        coalesce(t.category,t.level,t.circuit),t.surface,'singles',false,
        'Court Boss progressive world draw · '||r.rule_key,'game'
      )
      on conflict(player_id,tournament_name,title_date,event_type) do update set
        level=excluded.level,surface=excluded.surface,source_label=excluded.source_label,origin=excluded.origin;

      insert into public.player_final_results(
        player_id,tournament_name,final_date,level,surface,result,opponent_name,source,event_type
      ) values
        (v_champion,t.name,coalesce(t.end_date,t.start_date),coalesce(t.category,t.level,t.circuit),t.surface,'Champion',v_finalist_name,'Court Boss progressive world draw','singles'),
        (v_finalist,t.name,coalesce(t.end_date,t.start_date),coalesce(t.category,t.level,t.circuit),t.surface,'Finaliste',v_champion_name,'Court Boss progressive world draw','singles')
      on conflict(player_id,tournament_name,final_date,result) do update set
        level=excluded.level,surface=excluded.surface,opponent_name=excluded.opponent_name,
        source=excluded.source,event_type=excluded.event_type;

      update public.players p
      set form=greatest(35,least(100,p.form+
            case e.result_code when 'W' then 4 when 'F' then 3 when 'SF' then 2 when 'QF' then 1 else 0 end)),
          morale=greatest(30,least(100,p.morale+
            case e.result_code when 'W' then 5 when 'F' then 3 when 'SF' then 2 when 'QF' then 1 else 0 end))
      from public.world_tournament_entries e
      where e.tournament_id=t.id and p.id=e.player_id;

      insert into public.world_tournament_simulations(
        tournament_id,winner_id,finalist_id,winner_points,finalist_points,simulated_on,
        final_win_probability,court_speed,model_version,matchup_components,
        rule_key,draw_size,bracket_size,rounds_count,matches_simulated,participants_simulated,format_type
      ) values(
        t.id,v_champion,v_finalist,v_champion_points,coalesce(v_finalist_points,0),
        v_round_date,round(coalesce(
          case when (select winner_id from public.world_tournament_matches where tournament_id=t.id and round_code='F' and coalesce(is_qualifying,false)=false limit 1)
                     =(select player_a_id from public.world_tournament_matches where tournament_id=t.id and round_code='F' and coalesce(is_qualifying,false)=false limit 1)
               then v_final_prob else 1-v_final_prob end,.5),4),
        coalesce(t.court_speed,case when t.surface ilike 'Terre%' then .68 when t.surface ilike 'Gazon%' then 1.15 when coalesce(t.indoor,false) then 1.18 else 1.0 end),
        'CB-MATCH-v5-PROGRESSIVE',coalesce(v_final_components,'{}'::jsonb),
        r.rule_key,st.draw_size,st.bracket_size,st.rounds_count,
        (select count(*) from public.world_tournament_matches where tournament_id=t.id and coalesce(is_qualifying,false)=false and loser_id is not null),
        (select count(*) from public.world_tournament_entries where tournament_id=t.id),
        'knockout'
      )
      on conflict(tournament_id) do nothing;

      update public.world_tournament_states
      set status='completed',current_round_no=st.rounds_count,
          last_advanced_on=v_round_date,finalized_on=v_round_date,updated_at=now(),
          metadata=metadata||jsonb_build_object('champion_id',v_champion,'finalist_id',v_finalist)
      where tournament_id=t.id;
    end if;
  end loop;

  select * into st from public.world_tournament_states where tournament_id=t.id;
  return jsonb_build_object(
    'ok',true,'tournament_id',t.id,'name',t.name,'status',st.status,
    'current_round_no',st.current_round_no,'rounds_advanced',v_rounds_advanced,
    'matches_played',v_actual_matches,'last_advanced_on',st.last_advanced_on,
    'model','CB-MATCH-v5-PROGRESSIVE'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.advance_world_qualifying_tournament(p_tournament_id bigint, p_to_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  r public.tournament_format_rules%rowtype;
  st public.world_qualifying_states%rowtype;
  v_q_start date;
  v_q_end date;
  v_span integer;
  v_round integer;
  v_round_date date;
  v_next_round_date date;
  v_code text;
  v_match_count integer;
  v_match_no integer;
  v_a bigint;
  v_b bigint;
  v_w bigint;
  v_l bigint;
  v_a_name text;
  v_b_name text;
  v_w_name text;
  v_l_name text;
  v_entry_a text;
  v_entry_b text;
  v_match jsonb;
  v_prob numeric;
  v_awon boolean;
  v_score text;
  v_loss_points integer;
  v_loss_prize numeric;
  v_q_points integer;
  v_rounds_advanced integer:=0;
  v_matches_played integer:=0;
  v_qualifier_count integer:=0;
  v_managed_player bigint;
  v_managed_match_date date;
begin
  -- One tournament progression transaction at a time. This makes concurrent
  -- commit retries converge on the same bracket state instead of racing.
  perform pg_advisory_xact_lock(
    hashtextextended('court_boss_world_advance:'||p_tournament_id::text,0)
  );
  select * into t from public.tournaments
  where id=p_tournament_id and singles=true and coalesce(is_active,true)=true;
  if t.id is null then
    return jsonb_build_object('ok',false,'skipped','tournament_not_found');
  end if;

  select * into st from public.world_qualifying_states where tournament_id=t.id;
  if st.tournament_id is null then
    perform public.prepare_world_qualifying_tournament(
      t.id,coalesce(t.qualifying_signin_date,t.qualifying_start_date,t.start_date-1,p_to_date)
    );
    select * into st from public.world_qualifying_states where tournament_id=t.id;
  end if;

  if st.tournament_id is null then
    if exists(select 1 from public.world_tournament_qualifiers q where q.tournament_id=t.id) then
      return jsonb_build_object(
        'ok',true,'tournament_id',t.id,'status','completed','already_completed',true,
        'qualifiers',(select count(*) from public.world_tournament_qualifiers q where q.tournament_id=t.id)
      );
    end if;
    return jsonb_build_object('ok',false,'skipped','qualifying_draw_not_prepared','tournament_id',t.id);
  end if;

  if st.status='completed' then
    return jsonb_build_object(
      'ok',true,'tournament_id',t.id,'status','completed','already_completed',true,
      'qualifiers',(select count(*) from public.world_tournament_qualifiers q where q.tournament_id=t.id)
    );
  end if;

  select * into r from public.tournament_format_rules fr
  where fr.rule_key=st.rule_key limit 1;
  if r.rule_key is null then
    return jsonb_build_object('ok',false,'skipped','missing_format_rule','tournament_id',t.id);
  end if;

  v_q_start:=coalesce(t.qualifying_start_date,t.start_date-1);
  v_q_end:=coalesce(t.qualifying_end_date,v_q_start);
  v_span:=greatest(0,v_q_end-v_q_start);

  if p_to_date<v_q_start then
    return jsonb_build_object(
      'ok',true,'tournament_id',t.id,'status',st.status,
      'current_round_no',st.current_round_no,'next_round_date',v_q_start
    );
  end if;

  for v_round in (st.current_round_no+1)..st.rounds_count loop
    v_round_date:=v_q_start+
      case when st.rounds_count<=1 then 0
           else round((v_round-1)::numeric*v_span/greatest(1,st.rounds_count-1))::int end;
    exit when v_round_date>p_to_date;

    v_code:='Q'||v_round::text;
    v_match_count:=greatest(1,st.bracket_total/(power(2,v_round)::int));

    if v_round>1 then
      insert into public.world_tournament_matches(
        tournament_id,round_no,round_code,group_name,match_no,
        player_a_id,player_b_id,winner_id,loser_id,score,best_of,
        player_a_win_probability,court_speed,model_version,matchup_components,
        simulated_on,is_qualifying
      )
      select
        t.id,-v_round,v_code,
        'Q Section '||ceil((((m-1)*power(2,v_round)+1)::numeric)/greatest(1,st.section_bracket)::numeric)::int,
        m,
        a.winner_id,b.winner_id,null,null,null,3,null,
        coalesce(t.court_speed,case
          when t.surface ilike 'Terre%' then .68
          when t.surface ilike 'Gazon%' then 1.15
          when coalesce(t.indoor,false) then 1.18 else 1.0 end),
        'CB-MATCH-v6-PROGRESSIVE-Q-SCHEDULED',
        jsonb_build_object('phase','qualifying','status','scheduled'),
        v_round_date,true
      from generate_series(1,v_match_count) m
      left join public.world_tournament_matches a
        on a.tournament_id=t.id and a.is_qualifying=true
       and a.round_no=-(v_round-1) and a.match_no=m*2-1
      left join public.world_tournament_matches b
        on b.tournament_id=t.id and b.is_qualifying=true
       and b.round_no=-(v_round-1) and b.match_no=m*2
      where a.winner_id is not null or b.winner_id is not null
      on conflict(tournament_id,round_no,match_no) do nothing;
    end if;

    for v_match_no in 1..v_match_count loop
      select player_a_id,player_b_id,winner_id
      into v_a,v_b,v_w
      from public.world_tournament_matches
      where tournament_id=t.id and is_qualifying=true
        and round_no=-v_round and match_no=v_match_no;

      if not found then
        continue;
      end if;
      if v_w is not null then
        continue;
      end if;

      if v_a is null and v_b is null then
        update public.world_tournament_matches
        set score='BYE',model_version='CB-MATCH-v6-PROGRESSIVE-Q',
            matchup_components=matchup_components||jsonb_build_object('status','empty-bye'),
            simulated_on=v_round_date
        where tournament_id=t.id and is_qualifying=true
          and round_no=-v_round and match_no=v_match_no;
        continue;
      elsif v_a is null or v_b is null then
        v_w:=coalesce(v_a,v_b);
        update public.world_tournament_matches
        set winner_id=v_w,loser_id=null,score='BYE',
            model_version='CB-MATCH-v6-PROGRESSIVE-Q',
            matchup_components=matchup_components||jsonb_build_object('status','bye'),
            simulated_on=v_managed_match_date
        where tournament_id=t.id and is_qualifying=true
          and round_no=-v_round and match_no=v_match_no;
        continue;
      end if;

      select name into v_a_name from public.players where id=v_a;
      select name into v_b_name from public.players where id=v_b;
      select entry_method into v_entry_a
        from public.world_tournament_qualifying_entries
        where tournament_id=t.id and player_id=v_a;
      select entry_method into v_entry_b
        from public.world_tournament_qualifying_entries
        where tournament_id=t.id and player_id=v_b;

      if exists(
        select 1
        from public.academy_roster ar
        where ar.status='active'
          and ar.player_id in (v_a,v_b)
      ) or exists(
        select 1
        from public.career_state cs
        where cs.id='demo'
          and cs.managed_player_id in (v_a,v_b)
      ) then
        select x.player_id into v_managed_player
        from (
          select ar.player_id,1 as priority
          from public.academy_roster ar
          where ar.status='active' and ar.player_id in (v_a,v_b)
          union all
          select cs.managed_player_id,0
          from public.career_state cs
          where cs.id='demo' and cs.managed_player_id in (v_a,v_b)
        ) x
        order by x.priority,x.player_id
        limit 1;

        v_managed_match_date:=coalesce(
          nullif(
            public.managed_tournament_match_date_v22(
              t.id,v_managed_player,v_code,'qualifying','singles'
            )->>'match_date',''
          )::date,
          v_round_date
        );

        update public.world_tournament_matches
        set model_version='CB-MATCH-ENGINE-v6-LIVE-PENDING-Q',
            matchup_components=coalesce(matchup_components,'{}'::jsonb)
              ||jsonb_build_object(
                'phase','qualifying',
                'status','managed_live_pending'
              ),
            simulated_on=v_round_date
        where tournament_id=t.id and is_qualifying=true
          and round_no=-v_round and match_no=v_match_no;
        continue;
      end if;

      v_match:=public.player_matchup_probability_v4(
        v_a,v_b,t.surface,v_round_date,
        coalesce(t.court_speed,case
          when t.surface ilike 'Terre%' then .68
          when t.surface ilike 'Gazon%' then 1.15
          when coalesce(t.indoor,false) then 1.18 else 1.0 end),
        3
      );
      v_prob:=greatest(.02,least(.98,coalesce((v_match->>'player_a_probability')::numeric,.5)));
      v_awon:=random()<v_prob;
      v_w:=case when v_awon then v_a else v_b end;
      v_l:=case when v_awon then v_b else v_a end;
      v_w_name:=case when v_awon then v_a_name else v_b_name end;
      v_l_name:=case when v_awon then v_b_name else v_a_name end;
      v_score:=public.world_tournament_score(v_prob,v_awon,3);

      update public.world_tournament_matches
      set winner_id=v_w,loser_id=v_l,score=v_score,
          player_a_win_probability=round(v_prob,4),
          model_version='CB-MATCH-v6-PROGRESSIVE-Q',
          matchup_components=coalesce(v_match->'components','{}'::jsonb)
            ||jsonb_build_object(
              'phase','qualifying','status','completed',
              'entry_a',v_entry_a,'entry_b',v_entry_b
            ),
          simulated_on=v_round_date
      where tournament_id=t.id and is_qualifying=true
        and round_no=-v_round and match_no=v_match_no;

      v_matches_played:=v_matches_played+1;
      v_loss_points:=coalesce((r.qualifying_points->>v_code)::int,0);
      v_loss_prize:=public.tournament_prize_for_result(t.id,v_code,'qualifying');

      update public.world_tournament_qualifying_entries
      set result_code=v_code,
          result_label='Qualification · tour '||v_round,
          qualified=false,
          points_awarded=v_loss_points,
          prize_awarded=v_loss_prize,
          prize_currency=coalesce(t.prize_currency,'USD'),
          prize_is_estimate=coalesce(t.qualifying_prize_is_estimate,t.prize_breakdown_is_estimate,true),
          last_opponent_id=v_w,last_opponent_name=v_w_name,
          last_score=case when v_l=v_a then v_score else public.world_invert_tennis_score(v_score) end,
          simulated_on=v_round_date,
          source_label='Court Boss progressive qualifying · '||v_code
      where tournament_id=t.id and player_id=v_l;

      if v_loss_points>0 then
        insert into public.world_ranking_points(
          player_id,tournament_id,label,earned_date,expiry_date,points,active,source_label
        ) values(
          v_l,t.id,t.name||' · '||v_code,
          v_round_date,v_round_date+364,
          v_loss_points,true,'Court Boss progressive qualifying · '||v_code
        )
        on conflict(player_id,tournament_id) do update set
          label=excluded.label,earned_date=excluded.earned_date,expiry_date=excluded.expiry_date,
          points=excluded.points,active=true,source_label=excluded.source_label;
      end if;

      insert into public.player_tournament_history(
        player_id,season,tournament_id,tournament_name,tournament_date,level,category,surface,
        result_code,result_label,last_opponent,last_score,is_grand_slam,source,event_type
      ) values(
        v_l,extract(year from coalesce(t.start_date,v_round_date))::int,
        t.id::text,t.name,v_round_date,
        coalesce(t.level,t.category,t.circuit),t.category,t.surface,
        v_code,'Qualification · tour '||v_round,v_w_name,
        case when v_l=v_a then v_score else public.world_invert_tennis_score(v_score) end,
        t.category='Grand Chelem','Court Boss progressive qualifying','singles'
      )
      on conflict(player_id,event_type,tournament_id) do update set
        result_code=excluded.result_code,result_label=excluded.result_label,
        last_opponent=excluded.last_opponent,last_score=excluded.last_score,
        tournament_date=excluded.tournament_date,source=excluded.source;

      update public.players
      set fatigue=least(100,coalesce(fatigue,20)+1),
          fitness=greatest(35,coalesce(fitness,90)-1)
      where id in (v_w,v_l);

      perform public.update_h2h_after_match(
        v_w,v_l,t.surface,v_round_date,false,
        'Court Boss progressive qualifying · '||v_code
      );
      perform public.update_player_elo_after_match(
        v_w,v_l,t.surface,v_round_date,false,.92
      );
    end loop;

    if exists(
      select 1
      from public.world_tournament_matches m
      where m.tournament_id=t.id
        and m.is_qualifying=true
        and m.round_no=-v_round
        and m.winner_id is null
        and (
          exists(
            select 1 from public.academy_roster ar
            where ar.status='active'
              and ar.player_id in (m.player_a_id,m.player_b_id)
          )
          or exists(
            select 1 from public.career_state cs
            where cs.id='demo'
              and cs.managed_player_id in (m.player_a_id,m.player_b_id)
          )
        )
    ) then
      return jsonb_build_object(
        'ok',true,'tournament_id',t.id,'name',t.name,
        'status','waiting_managed','current_round_no',st.current_round_no,
        'waiting_round_no',v_round,'waiting_round_code',v_code,
        'scheduled_date',(
          select min(m.simulated_on)
          from public.world_tournament_matches m
          where m.tournament_id=t.id
            and m.is_qualifying=true
            and m.round_no=-v_round
            and m.winner_id is null
            and (
              exists(select 1 from public.academy_roster ar where ar.status='active' and ar.player_id in (m.player_a_id,m.player_b_id))
              or exists(select 1 from public.career_state cs where cs.id='demo' and cs.managed_player_id in (m.player_a_id,m.player_b_id))
            )
        ),'matches_played',v_matches_played,
        'model','CB-MATCH-v6-MANAGED-DAILY-Q'
      );
    end if;

    update public.world_qualifying_states
    set status='live',current_round_no=v_round,last_advanced_on=v_round_date,updated_at=now()
    where tournament_id=t.id;
    v_rounds_advanced:=v_rounds_advanced+1;

    if v_round<st.rounds_count then
      v_next_round_date:=v_q_start+
        case when st.rounds_count<=1 then 0
             else round(v_round::numeric*v_span/greatest(1,st.rounds_count-1))::int end;
      insert into public.world_tournament_matches(
        tournament_id,round_no,round_code,group_name,match_no,
        player_a_id,player_b_id,winner_id,loser_id,score,best_of,
        player_a_win_probability,court_speed,model_version,matchup_components,
        simulated_on,is_qualifying
      )
      select
        t.id,-(v_round+1),'Q'||(v_round+1)::text,
        'Q Section '||ceil((((m-1)*power(2,v_round+1)+1)::numeric)/greatest(1,st.section_bracket)::numeric)::int,
        m,a.winner_id,b.winner_id,null,null,null,3,null,
        coalesce(t.court_speed,case
          when t.surface ilike 'Terre%' then .68
          when t.surface ilike 'Gazon%' then 1.15
          when coalesce(t.indoor,false) then 1.18 else 1.0 end),
        'CB-MATCH-v6-PROGRESSIVE-Q-SCHEDULED',
        jsonb_build_object('phase','qualifying','status','scheduled'),
        v_next_round_date,true
      from generate_series(1,greatest(1,st.bracket_total/(power(2,v_round+1)::int))) m
      left join public.world_tournament_matches a
        on a.tournament_id=t.id and a.is_qualifying=true
       and a.round_no=-v_round and a.match_no=m*2-1
      left join public.world_tournament_matches b
        on b.tournament_id=t.id and b.is_qualifying=true
       and b.round_no=-v_round and b.match_no=m*2
      where a.winner_id is not null or b.winner_id is not null
      on conflict(tournament_id,round_no,match_no) do nothing;
    end if;

    if v_round=st.rounds_count then
      v_q_points:=coalesce((r.qualifying_points->>'Q')::int,0);

      select count(*) into v_qualifier_count
      from public.world_tournament_matches
      where tournament_id=t.id and is_qualifying=true
        and round_no=-v_round and winner_id is not null;

      if v_qualifier_count<>st.qualifier_slots then
        return jsonb_build_object(
          'ok',false,'skipped','qualifying_section_winner_count_mismatch',
          'tournament_id',t.id,'expected',st.qualifier_slots,'actual',v_qualifier_count
        );
      end if;

      insert into public.world_tournament_qualifiers(
        tournament_id,player_id,qualifier_slot,ranking_at_entry,
        qualifying_points,qualifying_prize,qualifying_start_date,qualifying_end_date,
        source_label,entry_method
      )
      select
        t.id,m.winner_id,
        row_number() over(order by m.match_no)::int,
        qe.ranking_at_entry,v_q_points,0,
        t.qualifying_start_date,t.qualifying_end_date,
        case
          when qe.entry_method='junior_accelerator_qualifying' then 'Court Boss Junior Accelerator qualifying'
          when qe.entry_method='college_accelerator_qualifying' then 'Court Boss College Accelerator qualifying'
          when qe.entry_method='nextgen_accelerator_qualifying' then 'Court Boss Next Gen Accelerator qualifying'
          when qe.entry_method='qualifying_wildcard' then 'Court Boss qualifying wild card'
          else 'Court Boss progressive qualifying'
        end,
        qe.entry_method
      from public.world_tournament_matches m
      join public.world_tournament_qualifying_entries qe
        on qe.tournament_id=t.id and qe.player_id=m.winner_id
      where m.tournament_id=t.id and m.is_qualifying=true
        and m.round_no=-v_round and m.winner_id is not null
      order by m.match_no
      on conflict(tournament_id,player_id) do update set
        qualifier_slot=excluded.qualifier_slot,
        ranking_at_entry=excluded.ranking_at_entry,
        qualifying_points=excluded.qualifying_points,
        qualifying_start_date=excluded.qualifying_start_date,
        qualifying_end_date=excluded.qualifying_end_date,
        source_label=excluded.source_label,
        entry_method=excluded.entry_method;

      update public.world_tournament_qualifying_entries qe
      set result_code='Q',result_label='Qualifié',qualified=true,
          points_awarded=v_q_points,prize_awarded=0,
          simulated_on=v_round_date,
          source_label='Court Boss progressive qualifying · qualified'
      where qe.tournament_id=t.id
        and exists(
          select 1 from public.world_tournament_matches m
          where m.tournament_id=t.id and m.is_qualifying=true
            and m.round_no=-v_round and m.winner_id=qe.player_id
        );

      perform public.refresh_world_tournament_lucky_losers(t.id,0);

      update public.world_qualifying_states
      set status='completed',current_round_no=st.rounds_count,
          last_advanced_on=v_round_date,finalized_on=v_round_date,updated_at=now(),
          metadata=metadata||jsonb_build_object(
            'qualifiers',v_qualifier_count,'completed_on',v_round_date
          )
      where tournament_id=t.id;
    end if;
  end loop;

  select * into st from public.world_qualifying_states where tournament_id=t.id;
  return jsonb_build_object(
    'ok',true,'tournament_id',t.id,'name',t.name,'status',st.status,
    'current_round_no',st.current_round_no,'rounds_advanced',v_rounds_advanced,
    'matches_played',v_matches_played,'last_advanced_on',st.last_advanced_on,
    'qualifiers',(select count(*) from public.world_tournament_qualifiers q where q.tournament_id=t.id),
    'model','CB-MATCH-v6-PROGRESSIVE-Q'
  );
end;
$function$;
