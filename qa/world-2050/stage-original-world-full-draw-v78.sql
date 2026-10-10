CREATE OR REPLACE FUNCTION public.simulate_world_knockout_tournament_full(p_tournament_id bigint, p_simulated_on date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  r public.tournament_format_rules%rowtype;
  v_managed bigint;
  v_main integer;
  v_bracket integer;
  v_byes integer;
  v_direct integer;
  v_needed integer;
  v_seed_count integer;
  v_min_rank integer:=1;
  v_max_rank integer:=3000;
  v_best_of integer:=3;
  v_rounds integer;
  v_round integer;
  v_round_code text;
  v_current_size integer;
  v_pos integer;
  v_next_pos integer;
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
  v_champion bigint;
  v_finalist bigint;
  v_champion_name text;
  v_finalist_name text;
  v_champion_points integer;
  v_finalist_points integer;
  v_final_prob numeric;
  v_final_components jsonb:='{}'::jsonb;
  v_matches integer:=0;
  v_participants integer:=0;
  v_pb_count integer:=0;
  v_a_plus_count integer:=0;
  v_ll_vacancies integer:=0;
  v_ll_inserted integer:=0;
  m record;
begin
  select * into t
  from public.tournaments
  where id=p_tournament_id
    and singles=true
    and coalesce(is_active,true)=true;

  if t.id is null then
    return jsonb_build_object('skipped','tournament_not_found_or_not_singles','tournament_id',p_tournament_id);
  end if;

  if coalesce(t.circuit,'') in ('NCAA','Junior','Federation')
     or coalesce(t.category,'') in ('United Cup','Laver Cup','Davis Cup','Junior Davis Cup') then
    return jsonb_build_object('skipped','special_or_team_event','tournament_id',t.id,'category',t.category);
  end if;

  if exists(select 1 from public.world_tournament_simulations s where s.tournament_id=t.id) then
    return jsonb_build_object('skipped','already_simulated','tournament_id',t.id);
  end if;

  select * into r
  from public.tournament_format_rules x
  where x.circuit=t.circuit
    and x.category=t.category
    and x.main_draw_size=coalesce(t.singles_draw_size,t.draw_size)
  limit 1;

  if r.rule_key is null then
    return jsonb_build_object(
      'skipped','missing_format_rule',
      'tournament_id',t.id,'name',t.name,'circuit',t.circuit,'category',t.category,
      'draw_size',coalesce(t.singles_draw_size,t.draw_size)
    );
  end if;

  if r.format_type<>'knockout' then
    return jsonb_build_object('skipped','non_knockout_format','tournament_id',t.id,'rule_key',r.rule_key);
  end if;

  v_main:=r.main_draw_size;
  v_bracket:=r.bracket_size;
  v_byes:=greatest(0,v_bracket-v_main);
  v_seed_count:=least(r.seed_count,v_main);
  v_direct:=greatest(0,v_main-r.qualifier_count-r.wildcard_count-coalesce(r.special_exempt_slots,0)-coalesce(t.late_entry_slots,0));
  v_rounds:=coalesce(array_length(r.rounds,1),0);
  v_best_of:=case when t.circuit='ATP' and t.category='Grand Chelem' then 5 else 3 end;

  select managed_player_id into v_managed
  from public.career_state
  where id='demo';

  if t.category='Grand Chelem' then v_min_rank:=1;v_max_rank:=450;
  elsif t.category='Masters 1000' then v_min_rank:=1;v_max_rank:=380;
  elsif t.category='ATP 500' then v_min_rank:=1;v_max_rank:=500;
  elsif t.category='ATP 250' then v_min_rank:=1;v_max_rank:=700;
  elsif t.category='Challenger 175' then v_min_rank:=20;v_max_rank:=900;
  elsif t.category='Challenger 125' then v_min_rank:=30;v_max_rank:=1200;
  elsif t.category='Challenger 100' then v_min_rank:=40;v_max_rank:=1700;
  elsif t.category='Challenger 75' then v_min_rank:=60;v_max_rank:=2300;
  elsif t.category='Challenger 50' then v_min_rank:=90;v_max_rank:=3500;
  elsif t.category='M25' then v_min_rank:=150;v_max_rank:=7000;
  elsif t.category='M15' then v_min_rank:=201;v_max_rank:=12000;
  end if;

  drop table if exists pg_temp.cb_candidates;
  drop table if exists pg_temp.cb_entries_work;
  drop table if exists pg_temp.cb_pathway_entries;
  drop table if exists pg_temp.cb_performance_byes;
  drop table if exists pg_temp.cb_a_plus_wc;
  drop table if exists pg_temp.cb_bye_slots;
  drop table if exists pg_temp.cb_available_slots;
  drop table if exists pg_temp.cb_round_slots;
  drop table if exists pg_temp.cb_next_slots;

  create temporary table cb_candidates(
    player_id bigint primary key,
    name text,
    country text,
    effective_rank integer,
    selection_score numeric,
    potential integer
  ) on commit drop;

  insert into cb_candidates(player_id,name,country,effective_rank,selection_score,potential)
  select
    p.id,p.name,p.country,
    coalesce((elig.j->>'ranking')::int,999999)::int as effective_rank,
    (
      p.current_ability*.52+p.form*.08+p.fitness*.04-p.fatigue*.04+
      case
        when t.surface ilike 'Terre%' then coalesce(a.clay_affinity,10)*.42
        when t.surface ilike 'Gazon%' then coalesce(a.grass_affinity,10)*.42
        else coalesce(a.hard_affinity,10)*.42
      end+
      coalesce(a.decision_making,a.tactics,10)*.10+
      coalesce(a.consistency,a.concentration,10)*.10+
      coalesce(dp.competitive_drive,10)*.045+
      coalesce(public.player_psychology_modifier(p.id),0)*.45+
      public.ai_tournament_commitment_probability(
        coalesce(case when p.ranking_current then p.ranking end,p.game_world_rank,p.ranking,999999)::int,
        coalesce(sp.plan_type,'tour_regular'),coalesce(sp.target_events,22),
        sp.preferred_surface,t.surface,t.category,p.country,t.country,
        coalesce(p.fatigue,20),coalesce(sp.rest_trigger_fatigue,72)
      )*.06+
      (mod(abs(hashtext('world-entry|'||t.id::text||'|'||p.id::text)),1000)/1000.0)*3.5
    )::numeric as selection_score,
    p.potential
  from public.players p
  left join public.player_attributes a on a.player_id=p.id
  left join public.player_development_profiles dp on dp.player_id=p.id
  cross join lateral (select public.tournament_entry_eligibility(p.id,t.id,'candidate') j) elig
  left join public.player_season_plans sp on sp.player_id=p.id and sp.season=extract(year from t.start_date)::int
  where p.career_status='active'
    and p.id is distinct from v_managed
    and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
    and coalesce(p.career_focus,'mixed')<>'doubles_only'
    and p.injury_status='Fit'
    and coalesce(p.fitness,90)>=48
    and coalesce(p.fatigue,20)<=88
    and coalesce((elig.j->>'ranking')::int,999999) between v_min_rank and v_max_rank
    and (
      t.circuit<>'ATP'
      or p.ranking_current=true
    )
    and coalesce((elig.j->>'eligible')::boolean,false)
    and public.ai_player_commits_to_tournament(p.id,t.id)
    and not (public.player_tournament_calendar_conflict(p.id,t.id,'candidate')->>'conflict')::boolean;

  create temporary table cb_a_plus_wc(
    player_id bigint primary key
  ) on commit drop;

  if coalesce(r.conditional_wildcard_rule,'')='ATP500_A_PLUS'
     and coalesce(r.wildcard_count_max,r.wildcard_count)>r.wildcard_count then
    insert into cb_a_plus_wc(player_id)
    select x.player_id
    from public.tournament_a_plus_wildcard_candidate_ids(t.id) x
    where exists(select 1 from cb_candidates c where c.player_id=x.player_id)
    order by x.ranking_2025,x.current_rank,x.player_id
    limit 1;

    select count(*) into v_a_plus_count from cb_a_plus_wc;
  end if;

  create temporary table cb_entries_work(
    player_id bigint primary key,
    name text not null,
    country text,
    seed integer,
    draw_slot integer,
    entry_method text not null,
    ranking_at_entry integer,
    had_bye boolean not null default false,
    matches_won integer not null default 0,
    result_code text,
    result_label text,
    points_awarded integer not null default 0,
    qualifying_points integer not null default 0,
    last_opponent_id bigint,
    last_opponent_name text,
    last_score text
  ) on commit drop;

  create temporary table cb_pathway_entries(
    player_id bigint primary key,
    entry_method text not null,
    pathway_rank integer,
    priority integer not null
  ) on commit drop;

  if coalesce(r.junior_accelerator_slots,0)>0 then
    insert into cb_pathway_entries(player_id,entry_method,pathway_rank,priority)
    select x.player_id,'junior_accelerator',x.year_end_rank,1
    from public.junior_accelerator_candidate_ids(t.id,'main') x
    limit r.junior_accelerator_slots
    on conflict(player_id) do nothing;
  end if;

  if coalesce(r.college_accelerator_slots,0)>0 then
    insert into cb_pathway_entries(player_id,entry_method,pathway_rank,priority)
    select x.player_id,'college_accelerator',x.year_end_ita_rank,2
    from public.college_accelerator_candidate_ids(t.id) x
    limit r.college_accelerator_slots
    on conflict(player_id) do nothing;
  end if;

  if coalesce(r.nextgen_accelerator_main_slots,0)>0 then
    insert into cb_pathway_entries(player_id,entry_method,pathway_rank,priority)
    select x.player_id,'nextgen_accelerator',x.effective_rank,3
    from public.nextgen_accelerator_candidate_ids(t.id,'main') x
    where not exists(select 1 from cb_pathway_entries pe where pe.player_id=x.player_id)
    limit r.nextgen_accelerator_main_slots
    on conflict(player_id) do nothing;
  end if;

  if coalesce(r.junior_reserved_slots,0)>0 then
    insert into cb_pathway_entries(player_id,entry_method,pathway_rank,priority)
    select x.player_id,'junior_reserved',x.junior_rank,4
    from public.junior_reserved_candidate_ids(t.id) x
    where not exists(select 1 from cb_pathway_entries pe where pe.player_id=x.player_id)
    limit r.junior_reserved_slots
    on conflict(player_id) do nothing;
  end if;

  -- ATP 2026 Challenger 50/75 composition caps all JAS/CAS/Next Gen
  -- accelerator main-draw positions at three total, not three per pathway.
  if t.circuit='Challenger' and t.category in ('Challenger 50','Challenger 75') then
    delete from cb_pathway_entries pe
    where pe.player_id in (
      select z.player_id
      from (
        select
          p2.player_id,
          row_number() over(
            order by
              case
                when p2.entry_method='junior_accelerator' then
                  coalesce((
                    select je.year_end_rank
                    from public.junior_accelerator_entitlements je
                    where je.season=extract(year from t.start_date)::int
                      and je.player_id=p2.player_id
                  ),1)*100
                when p2.entry_method='college_accelerator' then
                  coalesce((
                    select ce.year_end_ita_rank
                    from public.atp_college_accelerator_entitlements ce
                    where ce.season=extract(year from t.start_date)::int
                      and ce.player_id=p2.player_id
                  ),1)*100
                when p2.entry_method='nextgen_accelerator' then
                  greatest(1,coalesce(p2.pathway_rank,500)-350)*7
                else 999999
              end,
              p2.player_id
          ) rn
        from cb_pathway_entries p2
        where p2.entry_method in ('junior_accelerator','college_accelerator','nextgen_accelerator')
      ) z
      where z.rn>3
    );
  end if;

  select greatest(
    0,
    v_main-r.qualifier_count-r.wildcard_count-v_a_plus_count
      -coalesce(r.special_exempt_slots,0)-coalesce(t.late_entry_slots,0)
      -(select count(*) from cb_pathway_entries)
  ) into v_direct;

  insert into cb_entries_work(player_id,name,country,entry_method,ranking_at_entry)
  select pe.player_id,p.name,p.country,pe.entry_method,
         coalesce(case when p.ranking_current then p.ranking end,p.game_world_rank,p.ranking,999999)::int
  from cb_pathway_entries pe
  join public.players p on p.id=pe.player_id
  order by pe.priority,coalesce(pe.pathway_rank,999999),pe.player_id;

  insert into cb_entries_work(player_id,name,country,entry_method,ranking_at_entry)
  select c.player_id,c.name,c.country,'direct',c.effective_rank
  from cb_candidates c
  where not exists(select 1 from cb_entries_work e where e.player_id=c.player_id)
    and not exists(select 1 from cb_a_plus_wc aw where aw.player_id=c.player_id)
    and (public.tournament_entry_eligibility(c.player_id,t.id,'direct')->>'eligible')::boolean
    and not (public.player_tournament_calendar_conflict(c.player_id,t.id,'direct')->>'conflict')::boolean
  order by c.effective_rank asc,c.selection_score desc,c.player_id
  limit v_direct;

  if coalesce(t.late_entry_slots,0)>0 then
    -- ATP 2026 Rulebook 7.04: a Late Entry may only be awarded to a player
    -- ranked better than the original acceptance-list cut.
    insert into cb_entries_work(player_id,name,country,entry_method,ranking_at_entry)
    select c.player_id,c.name,c.country,'late_entry',c.effective_rank
    from cb_candidates c
    where not exists(select 1 from cb_entries_work e where e.player_id=c.player_id)
      and c.effective_rank<coalesce(t.direct_cut,t.projected_direct_cut,0)
      and (public.tournament_entry_eligibility(c.player_id,t.id,'direct')->>'eligible')::boolean
      and not (public.player_tournament_calendar_conflict(c.player_id,t.id,'direct')->>'conflict')::boolean
    order by c.effective_rank asc,c.selection_score desc,c.player_id
    limit t.late_entry_slots;

    -- If nobody uses the LE spot by the deadline, the Rulebook sends the
    -- vacancy to the next eligible player on the original entry list.
    if (
      select count(*) from cb_entries_work where entry_method='late_entry'
    ) < coalesce(t.late_entry_slots,0) then
      insert into cb_entries_work(player_id,name,country,entry_method,ranking_at_entry)
      select c.player_id,c.name,c.country,'direct',c.effective_rank
      from cb_candidates c
      where not exists(select 1 from cb_entries_work e where e.player_id=c.player_id)
        and (public.tournament_entry_eligibility(c.player_id,t.id,'direct')->>'eligible')::boolean
        and not (public.player_tournament_calendar_conflict(c.player_id,t.id,'direct')->>'conflict')::boolean
      order by c.effective_rank asc,c.selection_score desc,c.player_id
      limit greatest(
        0,
        coalesce(t.late_entry_slots,0)
        -(select count(*) from cb_entries_work where entry_method='late_entry')
      );
    end if;
  end if;

  if coalesce(r.special_exempt_slots,0)>0 then
    insert into cb_entries_work(player_id,name,country,entry_method,ranking_at_entry)
    select c.player_id,c.name,c.country,'special_exempt',c.effective_rank
    from cb_candidates c
    where not exists(select 1 from cb_entries_work e where e.player_id=c.player_id)
      and c.effective_rank>coalesce(t.direct_cut,t.projected_direct_cut,0)
      and (public.tournament_entry_eligibility(c.player_id,t.id,'direct')->>'eligible')::boolean
      and exists(
        select 1
        from public.world_tournament_entries pe
        join public.tournaments pt on pt.id=pe.tournament_id
        where pe.player_id=c.player_id
          and pt.id<>t.id
          and pt.start_date<t.start_date
          and coalesce(pt.end_date,pt.start_date)>=coalesce(t.qualifying_start_date,t.start_date)
          and coalesce(pt.end_date,pt.start_date)<=t.start_date
          and pe.result_code in ('W','F','SF')
          and public.tournament_special_exempt_eligible(pt.id,t.id)
      )
    order by c.effective_rank asc,c.selection_score desc,c.player_id
    limit r.special_exempt_slots;
  end if;

  if v_a_plus_count>0 then
    insert into cb_entries_work(player_id,name,country,entry_method,ranking_at_entry)
    select c.player_id,c.name,c.country,'wildcard_a_plus',c.effective_rank
    from cb_candidates c
    join cb_a_plus_wc aw on aw.player_id=c.player_id
    where not exists(select 1 from cb_entries_work e where e.player_id=c.player_id)
    limit 1;
  end if;

  if r.wildcard_count>0 then
    insert into cb_entries_work(player_id,name,country,entry_method,ranking_at_entry)
    select c.player_id,c.name,c.country,'wildcard',c.effective_rank
    from cb_candidates c
    where not exists(select 1 from cb_entries_work e where e.player_id=c.player_id)
      and (public.tournament_entry_eligibility(c.player_id,t.id,'wildcard')->>'eligible')::boolean
    order by
      (c.country is not distinct from t.country) desc,
      c.potential desc,
      c.selection_score desc,
      c.effective_rank asc,
      c.player_id
    limit r.wildcard_count;
  end if;

  if r.qualifier_count>0 then
    insert into cb_entries_work(
      player_id,name,country,entry_method,ranking_at_entry,qualifying_points
    )
    select
      q.player_id,p.name,p.country,
      case
        when q.entry_method='junior_accelerator_qualifying' then 'junior_accelerator_qualifier'
        when q.entry_method='college_accelerator_qualifying' then 'college_accelerator_qualifier'
        when q.entry_method='nextgen_accelerator_qualifying' then 'nextgen_accelerator_qualifier'
        else 'qualifier'
      end,
      coalesce(q.ranking_at_entry,999999),q.qualifying_points
    from public.world_tournament_qualifiers q
    join public.players p on p.id=q.player_id
    where q.tournament_id=t.id
      and not exists(select 1 from cb_entries_work e where e.player_id=q.player_id)
    order by q.qualifier_slot
    limit r.qualifier_count;

    if (
      select count(*) from cb_entries_work
      where entry_method in (
        'qualifier',
        'junior_accelerator_qualifier',
        'college_accelerator_qualifier',
        'nextgen_accelerator_qualifier'
      )
    )<r.qualifier_count then
      insert into cb_entries_work(
        player_id,name,country,entry_method,ranking_at_entry,qualifying_points
      )
      select c.player_id,c.name,c.country,'qualifier',c.effective_rank,
             coalesce((r.qualifying_points->>'Q')::int,0)
      from cb_candidates c
      where not exists(select 1 from cb_entries_work e where e.player_id=c.player_id)
        and (public.tournament_entry_eligibility(c.player_id,t.id,'qualifying')->>'eligible')::boolean
      order by c.effective_rank asc,c.selection_score desc,c.player_id
      limit greatest(
        0,
        r.qualifier_count-(
          select count(*) from cb_entries_work
          where entry_method in (
            'qualifier',
            'junior_accelerator_qualifier',
            'college_accelerator_qualifier',
            'nextgen_accelerator_qualifier'
          )
        )
      );
    end if;
  end if;

  select greatest(0,v_main-count(*)) into v_needed from cb_entries_work;
  if v_needed>0 then
    insert into cb_entries_work(player_id,name,country,entry_method,ranking_at_entry)
    select c.player_id,c.name,c.country,'direct',c.effective_rank
    from cb_candidates c
    where not exists(select 1 from cb_entries_work e where e.player_id=c.player_id)
    order by c.effective_rank asc,c.selection_score desc,c.player_id
    limit v_needed;
  end if;

  select greatest(0,v_main-count(*)) into v_needed from cb_entries_work;
  if v_needed>0 then
    insert into cb_entries_work(player_id,name,country,entry_method,ranking_at_entry)
    select
      p.id,p.name,p.country,'alternate',
      coalesce(case when p.ranking_current then p.ranking end,p.game_world_rank,p.ranking,999999)::int
    from public.players p
    where p.career_status='active'
      and p.id is distinct from v_managed
      and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
      and coalesce(p.career_focus,'mixed')<>'doubles_only'
      and p.injury_status='Fit'
      and coalesce(p.fitness,90)>=45
      and coalesce(p.fatigue,20)<=90
      and not exists(select 1 from cb_entries_work e where e.player_id=p.id)
      and not exists(
        select 1
        from public.world_tournament_entries e
        join public.tournaments ot on ot.id=e.tournament_id
        where e.player_id=p.id
          and daterange(ot.start_date,coalesce(ot.end_date,ot.start_date),'[]')
              && daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
      )
    order by
      coalesce(case when p.ranking_current then p.ranking end,p.game_world_rank,p.ranking,999999),
      p.current_ability desc,p.id
    limit v_needed;
  end if;

  -- After qualifying has started, late main-draw vacancies are filled by Lucky Losers.
  v_ll_vacancies:=public.world_postq_direct_vacancy_count(t.id,v_direct);
  if v_ll_vacancies>0 and coalesce(r.qualifier_count,0)>0 then
    perform public.refresh_world_tournament_lucky_losers(t.id,v_ll_vacancies);

    delete from cb_entries_work e
    where e.player_id in (
      select d.player_id
      from cb_entries_work d
      where d.entry_method='direct'
      order by d.ranking_at_entry desc,d.player_id desc
      limit v_ll_vacancies
    );

    insert into cb_entries_work(
      player_id,name,country,entry_method,ranking_at_entry,qualifying_points
    )
    select
      ll.player_id,p.name,p.country,'lucky_loser',ll.ranking_at_seeding,
      coalesce((r.qualifying_points->>ll.loss_round_code)::int,0)
    from public.world_tournament_lucky_losers ll
    join public.players p on p.id=ll.player_id
    where ll.tournament_id=t.id
      and not exists(select 1 from cb_entries_work e where e.player_id=ll.player_id)
      and coalesce(p.injury_status,'Fit')='Fit'
    order by ll.ll_order
    limit v_ll_vacancies;

    get diagnostics v_ll_inserted=row_count;

    update public.world_tournament_lucky_losers ll
    set selected=true
    where ll.tournament_id=t.id
      and exists(
        select 1 from cb_entries_work e
        where e.player_id=ll.player_id and e.entry_method='lucky_loser'
      );

    if v_ll_inserted<v_ll_vacancies then
      insert into cb_entries_work(player_id,name,country,entry_method,ranking_at_entry)
      select c.player_id,c.name,c.country,'alternate',c.effective_rank
      from cb_candidates c
      where not exists(select 1 from cb_entries_work e where e.player_id=c.player_id)
      order by c.effective_rank,c.selection_score desc,c.player_id
      limit greatest(0,v_ll_vacancies-v_ll_inserted);
    end if;
  end if;

  select count(*) into v_participants from cb_entries_work;
  if v_participants<>v_main then
    return jsonb_build_object(
      'skipped','insufficient_participants','tournament_id',t.id,
      'required',v_main,'selected',v_participants,'rule_key',r.rule_key
    );
  end if;

  with ranked as (
    select player_id,row_number() over(
      order by public.player_rank_at_date(
        player_id,coalesce(t.main_draw_start_date,t.start_date)
      ) asc,player_id
    )::int rn
    from cb_entries_work
  )
  update cb_entries_work e
  set seed=ranked.rn
  from ranked
  where e.player_id=ranked.player_id
    and ranked.rn<=v_seed_count;

  create temporary table cb_performance_byes(
    player_id bigint primary key
  ) on commit drop;

  if coalesce(t.performance_bye_slots,0)>0
     and coalesce(t.performance_bye_source_event,'')<>'' then
    insert into cb_performance_byes(player_id)
    select e.player_id
    from cb_entries_work e
    where e.seed is null
      and exists(
        select 1
        from public.world_tournament_entries pe
        join public.tournaments pt on pt.id=pe.tournament_id
        where pe.player_id=e.player_id
          and pe.result_code in ('W','F')
          and pt.start_date<t.start_date
          and extract(year from pt.start_date)=extract(year from t.start_date)
          and pt.name ilike '%'||t.performance_bye_source_event||'%'
      )
    order by e.ranking_at_entry,e.player_id
    limit t.performance_bye_slots;

    select count(*) into v_pb_count from cb_performance_byes;

    if v_pb_count>0 then
      update cb_entries_work e
      set entry_method='performance_bye'
      where exists(select 1 from cb_performance_byes pb where pb.player_id=e.player_id);

      delete from cb_entries_work e
      where e.player_id in (
        select d.player_id
        from cb_entries_work d
        where d.entry_method='direct'
          and not exists(select 1 from cb_performance_byes pb where pb.player_id=d.player_id)
          and d.seed is null
        order by d.ranking_at_entry desc,d.player_id desc
        limit v_pb_count
      );
    end if;
  end if;

  select count(*) into v_participants from cb_entries_work;
  if v_participants<>v_main-v_pb_count then
    return jsonb_build_object(
      'skipped','performance_bye_composition_failed',
      'tournament_id',t.id,'required',v_main-v_pb_count,
      'selected',v_participants,'performance_byes',v_pb_count
    );
  end if;

  update cb_entries_work
  set draw_slot=public.world_tournament_seed_slot_for_event(t.id,v_bracket,seed)
  where seed is not null;

  create temporary table cb_bye_slots(slot integer primary key) on commit drop;
  if v_byes>0 then
    insert into cb_bye_slots(slot)
    select case when draw_slot%2=1 then draw_slot+1 else draw_slot-1 end
    from cb_entries_work
    where seed between 1 and least(v_byes,v_seed_count)
      and draw_slot is not null
    on conflict do nothing;

    update cb_entries_work
    set had_bye=true
    where seed between 1 and least(v_byes,v_seed_count);
  end if;

  if v_pb_count>0 then
    with pb as (
      select player_id,row_number() over(order by player_id)::int rn
      from cb_performance_byes
    ),
    open_pairs as (
      select s as slot,
             row_number() over(order by md5('pb-slot|'||t.id::text||'|'||s::text))::int rn
      from generate_series(1,v_bracket,2) s
      where not exists(select 1 from cb_entries_work e where e.draw_slot in (s,s+1))
        and not exists(select 1 from cb_bye_slots b where b.slot in (s,s+1))
    )
    update cb_entries_work e
    set draw_slot=o.slot,
        had_bye=true
    from pb
    join open_pairs o using(rn)
    where e.player_id=pb.player_id;

    insert into cb_bye_slots(slot)
    select case when e.draw_slot%2=1 then e.draw_slot+1 else e.draw_slot-1 end
    from cb_entries_work e
    where exists(select 1 from cb_performance_byes pb where pb.player_id=e.player_id)
      and e.draw_slot is not null
    on conflict do nothing;

    if exists(
      select 1 from cb_entries_work e
      where exists(select 1 from cb_performance_byes pb where pb.player_id=e.player_id)
        and e.draw_slot is null
    ) then
      return jsonb_build_object(
        'skipped','performance_bye_slot_failed',
        'tournament_id',t.id,'performance_byes',v_pb_count
      );
    end if;
  end if;

  create temporary table cb_available_slots(slot integer primary key) on commit drop;
  insert into cb_available_slots(slot)
  select s
  from generate_series(1,v_bracket) s
  where not exists(select 1 from cb_entries_work e where e.draw_slot=s)
    and not exists(select 1 from cb_bye_slots b where b.slot=s);

  with players_to_place as (
    select player_id,row_number() over(
      order by md5('draw-player|'||t.id::text||'|'||player_id::text)
    ) rn
    from cb_entries_work
    where draw_slot is null
  ),
  slots_to_fill as (
    select slot,row_number() over(
      order by md5('draw-slot|'||t.id::text||'|'||slot::text)
    ) rn
    from cb_available_slots
  )
  update cb_entries_work e
  set draw_slot=s.slot
  from players_to_place p
  join slots_to_fill s using(rn)
  where e.player_id=p.player_id;

  if exists(select 1 from cb_entries_work where draw_slot is null) then
    return jsonb_build_object('skipped','draw_slot_assignment_failed','tournament_id',t.id);
  end if;

  delete from public.world_tournament_matches where tournament_id=t.id and coalesce(is_qualifying,false)=false;
  delete from public.world_tournament_entries where tournament_id=t.id;

  create temporary table cb_round_slots(
    pos integer primary key,
    player_id bigint
  ) on commit drop;
  create temporary table cb_next_slots(
    pos integer primary key,
    player_id bigint
  ) on commit drop;

  insert into cb_round_slots(pos,player_id)
  select s,e.player_id
  from generate_series(1,v_bracket) s
  left join cb_entries_work e on e.draw_slot=s;

  v_current_size:=v_bracket;

  for v_round in 1..v_rounds loop
    v_round_code:=r.rounds[v_round];
    truncate cb_next_slots;
    v_next_pos:=0;

    for v_pos in 1..v_current_size by 2 loop
      v_next_pos:=v_next_pos+1;
      select player_id into v_a from cb_round_slots where pos=v_pos;
      select player_id into v_b from cb_round_slots where pos=v_pos+1;

      if v_a is null and v_b is null then
        insert into cb_next_slots(pos,player_id) values(v_next_pos,null);
        continue;
      elsif v_a is null or v_b is null then
        v_winner:=coalesce(v_a,v_b);
        if v_round=1 then
          update cb_entries_work set had_bye=true where player_id=v_winner;
        end if;
        insert into cb_next_slots(pos,player_id) values(v_next_pos,v_winner);
        continue;
      end if;

      select name into v_a_name from cb_entries_work where player_id=v_a;
      select name into v_b_name from cb_entries_work where player_id=v_b;

      v_match:=public.player_matchup_probability_v4(
        v_a,v_b,t.surface,coalesce(t.end_date,t.start_date),
        coalesce(t.court_speed,
          case
            when t.surface ilike 'Terre%' then .68
            when t.surface ilike 'Gazon%' then 1.15
            when coalesce(t.indoor,false) then 1.18
            else 1.0
          end
        ),
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
        player_a_win_probability,court_speed,model_version,matchup_components,simulated_on
      ) values(
        t.id,v_round,v_round_code,((v_pos+1)/2),
        v_a,v_b,v_winner,v_loser,v_score,v_best_of,
        round(v_prob,4),
        coalesce(t.court_speed,
          case
            when t.surface ilike 'Terre%' then .68
            when t.surface ilike 'Gazon%' then 1.15
            when coalesce(t.indoor,false) then 1.18
            else 1.0
          end
        ),
        'CB-MATCH-v4-FULLDRAW',
        coalesce(v_match->'components','{}'::jsonb)
          || jsonb_build_object('extended_attributes',coalesce(v_match->'extended_attributes','{}'::jsonb)),
        coalesce(p_simulated_on,t.end_date,t.start_date)
      );
      v_matches:=v_matches+1;

      select matches_won,had_bye,entry_method,qualifying_points
      into v_loser_wins,v_loser_bye,v_loser_method,v_qual_points
      from cb_entries_work where player_id=v_loser;

      v_base_points:=coalesce((r.points_by_result->>v_round_code)::int,0);

      if coalesce(v_loser_bye,false) and coalesce(v_loser_wins,0)=0 then
        v_base_points:=coalesce((r.points_by_result->>r.rounds[1])::int,0);
      end if;

      if v_loser_method='wildcard'
         and coalesce(v_loser_wins,0)=0
         and t.category in ('Grand Chelem','Masters 1000') then
        v_base_points:=0;
      end if;

      update cb_entries_work
      set result_code=v_round_code,
          result_label=public.world_tournament_result_label(v_round_code),
          points_awarded=greatest(0,v_base_points+coalesce(v_qual_points,0)),
          last_opponent_id=v_winner,
          last_opponent_name=v_winner_name,
          last_score=v_loser_score
      where player_id=v_loser;

      update cb_entries_work
      set matches_won=matches_won+1
      where player_id=v_winner;

      insert into cb_next_slots(pos,player_id) values(v_next_pos,v_winner);
    end loop;

    truncate cb_round_slots;
    insert into cb_round_slots select * from cb_next_slots;
    v_current_size:=greatest(1,v_current_size/2);
  end loop;

  select player_id into v_champion
  from cb_round_slots
  order by pos
  limit 1;

  if v_champion is null then
    raise exception 'Full draw simulation produced no champion for tournament %',t.id;
  end if;

  select name,qualifying_points into v_champion_name,v_qual_points
  from cb_entries_work where player_id=v_champion;
  v_champion_points:=coalesce((r.points_by_result->>'W')::int,0)+coalesce(v_qual_points,0);

  select loser_id into v_finalist
  from public.world_tournament_matches
  where tournament_id=t.id and round_code='F'
  order by id desc limit 1;

  select name,points_awarded into v_finalist_name,v_finalist_points
  from cb_entries_work where player_id=v_finalist;

  update cb_entries_work
  set result_code='W',
      result_label='Vainqueur',
      points_awarded=greatest(0,v_champion_points)
  where player_id=v_champion;

  update cb_entries_work e
  set last_opponent_id=wm.loser_id,
      last_opponent_name=l.name,
      last_score=case
        when wm.player_a_id=e.player_id then wm.score
        else public.world_invert_tennis_score(wm.score)
      end
  from public.world_tournament_matches wm
  join public.players l on l.id=wm.loser_id
  where e.player_id=v_champion
    and wm.tournament_id=t.id
    and wm.round_code='F'
    and wm.winner_id=v_champion;

  insert into public.world_tournament_entries(
    tournament_id,player_id,seed,draw_slot,entry_method,ranking_at_entry,had_bye,
    matches_won,result_code,result_label,points_awarded,qualifying_points,
    last_opponent_id,last_opponent_name,last_score,simulated_on,source_label
  )
  select
    t.id,player_id,seed,draw_slot,entry_method,ranking_at_entry,had_bye,
    matches_won,result_code,result_label,points_awarded,qualifying_points,
    last_opponent_id,last_opponent_name,last_score,
    coalesce(p_simulated_on,t.end_date,t.start_date),
    'Court Boss full world draw · '||r.rule_key
  from cb_entries_work;

  update public.world_tournament_entries e
  set prize_awarded=public.tournament_prize_for_result(t.id,e.result_code,'singles'),
      prize_currency=coalesce(t.prize_currency,'USD'),
      prize_is_estimate=coalesce(t.singles_prize_is_estimate,t.prize_breakdown_is_estimate,true)
  where e.tournament_id=t.id;

  insert into public.world_ranking_points(
    player_id,tournament_id,label,earned_date,expiry_date,points,active,source_label
  )
  select
    e.player_id,t.id,
    t.name||' · '||e.result_code,
    coalesce(t.end_date,t.start_date),
    coalesce(t.end_date,t.start_date)+364,
    e.points_awarded,true,
    'Court Boss full draw · '||e.result_code||' · '||r.rule_key
  from cb_entries_work e
  where e.points_awarded>0
  on conflict(player_id,tournament_id) do update set
    label=excluded.label,
    earned_date=excluded.earned_date,
    expiry_date=excluded.expiry_date,
    points=excluded.points,
    active=true,
    source_label=excluded.source_label;

  insert into public.player_tournament_history(
    player_id,season,tournament_id,tournament_name,tournament_date,level,category,surface,
    result_code,result_label,last_opponent,last_score,is_grand_slam,source,event_type
  )
  select
    e.player_id,
    extract(year from coalesce(t.end_date,t.start_date))::int,
    t.id::text,t.name,coalesce(t.end_date,t.start_date),
    coalesce(t.level,t.category,t.circuit),t.category,t.surface,
    e.result_code,e.result_label,e.last_opponent_name,e.last_score,
    t.category='Grand Chelem',
    'Court Boss full world draw · '||r.rule_key,
    'singles'
  from cb_entries_work e
  on conflict(player_id,event_type,tournament_id) do update set
    season=excluded.season,
    tournament_name=excluded.tournament_name,
    tournament_date=excluded.tournament_date,
    level=excluded.level,
    category=excluded.category,
    surface=excluded.surface,
    result_code=excluded.result_code,
    result_label=excluded.result_label,
    last_opponent=excluded.last_opponent,
    last_score=excluded.last_score,
    is_grand_slam=excluded.is_grand_slam,
    source=excluded.source;

  insert into public.player_titles(
    player_id,tournament_name,title_date,level,surface,event_type,verified,source_label,origin
  ) values(
    v_champion,t.name,coalesce(t.end_date,t.start_date),
    coalesce(t.category,t.level,t.circuit),t.surface,'singles',false,
    'Court Boss full world draw · '||r.rule_key,'game'
  )
  on conflict(player_id,tournament_name,title_date,event_type) do update set
    level=excluded.level,surface=excluded.surface,source_label=excluded.source_label,origin=excluded.origin;

  insert into public.player_final_results(
    player_id,tournament_name,final_date,level,surface,result,opponent_name,source,event_type
  ) values
    (v_champion,t.name,coalesce(t.end_date,t.start_date),coalesce(t.category,t.level,t.circuit),t.surface,'Champion',v_finalist_name,'Court Boss full world draw','singles'),
    (v_finalist,t.name,coalesce(t.end_date,t.start_date),coalesce(t.category,t.level,t.circuit),t.surface,'Finaliste',v_champion_name,'Court Boss full world draw','singles')
  on conflict(player_id,tournament_name,final_date,result) do update set
    level=excluded.level,surface=excluded.surface,opponent_name=excluded.opponent_name,source=excluded.source,event_type=excluded.event_type;

  for m in
    select *
    from public.world_tournament_matches
    where tournament_id=t.id
      and winner_id is not null
      and loser_id is not null
    order by round_no,match_no
  loop
    perform public.update_h2h_after_match(
      m.winner_id,m.loser_id,t.surface,coalesce(t.end_date,t.start_date),false,
      'Court Boss full world draw · '||coalesce(m.round_code,'')
    );
    perform public.update_player_elo_after_match(
      m.winner_id,m.loser_id,t.surface,coalesce(t.end_date,t.start_date),false,
      case
        when m.round_code='F' then case when t.category='Grand Chelem' then 1.20 when t.category='Masters 1000' then 1.15 else 1.10 end
        when m.round_code='SF' then 1.08
        when m.round_code='QF' then 1.04
        else 1.0
      end
    );
  end loop;

  with stats as (
    select
      e.player_id,
      e.matches_won,
      e.result_code,
      count(wm.id)::int as matches_played
    from cb_entries_work e
    left join public.world_tournament_matches wm
      on wm.tournament_id=t.id
     and (wm.player_a_id=e.player_id or wm.player_b_id=e.player_id)
    group by e.player_id,e.matches_won,e.result_code
  )
  update public.players p
  set form=greatest(35,least(100,p.form+
        case stats.result_code when 'W' then 4 when 'F' then 3 when 'SF' then 2 when 'QF' then 1 else 0 end
      )),
      morale=greatest(30,least(100,p.morale+
        case stats.result_code when 'W' then 5 when 'F' then 3 when 'SF' then 2 when 'QF' then 1 else 0 end
      ))
  from stats
  where p.id=stats.player_id;

  update public.player_dynamic_ratings d
  set overall_elo=e.overall_elo,
      hard_elo=e.hard_elo,
      clay_elo=e.clay_elo,
      grass_elo=e.grass_elo,
      rating_confidence=greatest(d.rating_confidence,e.confidence),
      last_competitive_match=coalesce(t.end_date,t.start_date),
      source_label='Court Boss live hybrid Elo · full world draw',
      updated_at=now()
  from public.player_elo_ratings e
  where e.player_id=d.player_id
    and d.player_id in (select player_id from cb_entries_work);

  select
    case when wm.winner_id=wm.player_a_id then wm.player_a_win_probability else 1-wm.player_a_win_probability end,
    wm.matchup_components
  into v_final_prob,v_final_components
  from public.world_tournament_matches wm
  where wm.tournament_id=t.id and wm.round_code='F'
  order by wm.id desc limit 1;

  insert into public.world_tournament_simulations(
    tournament_id,winner_id,finalist_id,winner_points,finalist_points,simulated_on,
    final_win_probability,court_speed,model_version,matchup_components,
    rule_key,draw_size,bracket_size,rounds_count,matches_simulated,participants_simulated,format_type
  ) values(
    t.id,v_champion,v_finalist,v_champion_points,coalesce(v_finalist_points,0),
    coalesce(p_simulated_on,t.end_date,t.start_date),
    round(coalesce(v_final_prob,.5),4),
    coalesce(t.court_speed,
      case
        when t.surface ilike 'Terre%' then .68
        when t.surface ilike 'Gazon%' then 1.15
        when coalesce(t.indoor,false) then 1.18
        else 1.0
      end
    ),
    'CB-MATCH-v4-FULLDRAW',coalesce(v_final_components,'{}'::jsonb),
    r.rule_key,v_main,v_bracket,v_rounds,v_matches,v_participants,'knockout'
  );

  return jsonb_build_object(
    'ok',true,
    'tournament_id',t.id,
    'name',t.name,
    'rule_key',r.rule_key,
    'draw_size',v_main,
    'bracket_size',v_bracket,
    'byes',v_byes+v_pb_count,
    'performance_byes',v_pb_count,
    'pathway_entries',(select count(*) from cb_pathway_entries),
    'junior_reserved',(select count(*) from cb_pathway_entries where entry_method='junior_reserved'),
    'junior_accelerator',(select count(*) from cb_pathway_entries where entry_method='junior_accelerator'),
    'college_accelerator',(select count(*) from cb_pathway_entries where entry_method='college_accelerator'),
    'rounds',r.rounds,
    'matches',v_matches,
    'participants',v_participants,
    'champion_id',v_champion,
    'champion',v_champion_name,
    'finalist_id',v_finalist,
    'finalist',v_finalist_name,
    'winner_points',v_champion_points,
    'finalist_points',v_finalist_points,
    'model','CB-MATCH-v4-FULLDRAW'
  );
end;
$function$
;
