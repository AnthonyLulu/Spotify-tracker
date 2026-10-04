CREATE OR REPLACE FUNCTION public.junior_player_commits_to_event(p_player_id bigint, p_tournament_id bigint, p_discipline text DEFAULT 'singles'::text)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  d jsonb;
  discipline text:=lower(coalesce(p_discipline,'singles'));
  v_priority numeric;
  v_week date;
  v_better boolean:=false;
  v_country text;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null or t.circuit<>'Junior' or not coalesce(t.is_active,true) then return false; end if;

  d:=public.junior_event_decision_v19(p_player_id,p_tournament_id,discipline);
  if not coalesce((d->>'eligible')::boolean,false)
     or not coalesce((d->>'raw_interest')::boolean,false) then return false; end if;

  v_priority:=coalesce((d->>'priority_score')::numeric,0);
  v_week:=date_trunc('week',coalesce(t.main_draw_start_date,t.start_date)::timestamp)::date;
  select country into v_country from public.players where id=p_player_id;

  -- ITF juniors may submit multiple entries, but after withdrawal deadlines they
  -- can remain accepted in only one event for the week. Reservations represent
  -- that final accepted choice.
  select exists(
    select 1
    from (
      select x.id
      from public.tournaments x
      where x.id<>t.id
        and x.circuit='Junior'
        and coalesce(x.is_active,true)
        and coalesce(x.main_draw_start_date,x.start_date) between v_week and v_week+6
        and (
          (
            case x.category
              when 'Junior Grand Slam' then 900
              when 'J500' then 800
              when 'J300' then 700
              when 'J200' then 600
              when 'J100' then 500
              when 'J60' then 400
              when 'J30' then 300
              else 350
            end
            +case when v_country is not null and x.country=v_country then 30 else 0 end
          )>v_priority
          or (
            (
              case x.category
                when 'Junior Grand Slam' then 900
                when 'J500' then 800
                when 'J300' then 700
                when 'J200' then 600
                when 'J100' then 500
                when 'J60' then 400
                when 'J30' then 300
                else 350
              end
              +case when v_country is not null and x.country=v_country then 30 else 0 end
            )=v_priority
            and x.id<t.id
          )
        )
    ) ot
    cross join lateral (
      select public.junior_event_decision_v19(p_player_id,ot.id,discipline) j
    ) od
    where true
      and coalesce((od.j->>'eligible')::boolean,false)
      and coalesce((od.j->>'raw_interest')::boolean,false)
      and (
        coalesce((od.j->>'priority_score')::numeric,0)>v_priority
        or (
          coalesce((od.j->>'priority_score')::numeric,0)=v_priority
          and ot.id<t.id
        )
      )
  ) into v_better;

  return not v_better;
end;
$function$;

CREATE OR REPLACE FUNCTION public.prepare_junior_entry_reservations(p_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  v_main int;
  v_qslots int;
  v_wc int;
  v_rating_slots int:=0;
  v_direct int;
  v_count int:=0;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null or t.circuit<>'Junior' or not coalesce(t.singles,false) then
    return jsonb_build_object('ok',false,'reason','not_junior_singles');
  end if;

  v_main:=greatest(16,least(128,coalesce(t.singles_draw_size,t.draw_size,32)));
  v_qslots:=case
    when coalesce(t.qualifying_draw_size,0)>0 then public.junior_qualifier_slots(v_main,t.category)
    else 0 end;
  v_wc:=public.junior_main_wildcards(v_main);
  if t.category in ('J30','J60') and v_main=32 then
    v_rating_slots:=least(6,greatest(0,v_main-v_qslots-v_wc));
  end if;
  v_direct:=greatest(0,v_main-v_qslots-v_wc-v_rating_slots);

  if exists(select 1 from public.junior_entry_reservations where tournament_id=t.id) then
    return jsonb_build_object(
      'ok',true,'already',true,
      'reserved',(select count(*) from public.junior_entry_reservations where tournament_id=t.id),
      'direct_slots',v_direct,'rating_slots',v_rating_slots,'wildcards',v_wc,'qualifier_slots',v_qslots
    );
  end if;

  insert into public.junior_entry_reservations(
    tournament_id,player_id,entry_method,reserved_on
  )
  select t.id,p.id,'direct',coalesce(t.qualifying_start_date,t.start_date)
  from public.players p
  where p.career_status='active'
    and p.junior_ranking is not null
    and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
    and p.injury_status='Fit'
    and coalesce(p.fitness,90)>=45
    and (
      p.birth_date is null
      or (
        p.birth_date<=t.start_date-interval '13 years'
        and extract(year from t.start_date)::int-extract(year from p.birth_date)::int<=18
      )
    )
    and public.junior_player_commits_to_event(p.id,t.id,'singles')
  order by p.junior_ranking,p.current_ability desc,p.id
  limit v_direct
  on conflict do nothing;

  if v_rating_slots>0 then
    insert into public.junior_entry_reservations(
      tournament_id,player_id,entry_method,reserved_on
    )
    select t.id,p.id,'rating_acceptance_2026',coalesce(t.qualifying_start_date,t.start_date)
    from public.players p
    where p.career_status='active'
      and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
      and p.injury_status='Fit'
      and coalesce(p.fitness,90)>=45
      and (
        p.birth_date is null
        or (
          p.birth_date<=t.start_date-interval '13 years'
          and extract(year from t.start_date)::int-extract(year from p.birth_date)::int<=18
        )
      )
      and not exists(
        select 1 from public.junior_entry_reservations r
        where r.tournament_id=t.id and r.player_id=p.id
      )
      and public.junior_player_commits_to_event(p.id,t.id,'singles')
    order by public.junior_wtn_proxy_score(p.id,t.start_date) desc,
             coalesce(p.junior_ranking,999999),p.id
    limit v_rating_slots
    on conflict do nothing;
  end if;

  insert into public.junior_entry_reservations(
    tournament_id,player_id,entry_method,reserved_on
  )
  select t.id,p.id,'wildcard',coalesce(t.qualifying_start_date,t.start_date)
  from public.players p
  where p.career_status='active'
    and upper(coalesce(p.country,''))=upper(coalesce(t.country,''))
    and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
    and p.injury_status='Fit'
    and coalesce(p.fitness,90)>=45
    and (
      p.birth_date is null
      or (
        p.birth_date<=t.start_date-interval '13 years'
        and extract(year from t.start_date)::int-extract(year from p.birth_date)::int<=18
      )
    )
    and not exists(
      select 1 from public.junior_entry_reservations r
      where r.tournament_id=t.id and r.player_id=p.id
    )
    and public.junior_player_commits_to_event(p.id,t.id,'singles')
  order by public.junior_wtn_proxy_score(p.id,t.start_date) desc,
           coalesce(p.junior_ranking,999999),p.id
  limit v_wc
  on conflict do nothing;

  select count(*) into v_count from public.junior_entry_reservations where tournament_id=t.id;

  return jsonb_build_object(
    'ok',true,'reserved',v_count,
    'direct_slots',v_direct,'rating_slots',v_rating_slots,
    'wildcards',v_wc,'qualifier_slots',v_qslots,
    'model','ITF junior 2026 composition · internal rating proxy used only for J30/J60 rating-based slots'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.simulate_junior_qualifying_full(p_tournament_id bigint, p_simulated_on date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  v_main int;
  v_qdraw int;
  v_qslots int;
  v_qwc int;
  v_selected int;
  v_section int;
  v_section_count int;
  v_size int;
  v_bracket int;
  v_byes int;
  v_round int;
  v_pos int;
  v_next_pos int;
  v_a bigint;
  v_b bigint;
  v_w bigint;
  v_l bigint;
  v_prob numeric;
  v_roll numeric;
  v_awon boolean;
  v_match jsonb;
  v_score text;
  v_match_no int:=0;
  v_total_matches int:=0;
  v_qualifiers int:=0;
  v_played date;
  v_managed bigint;
begin
  select * into t
  from public.tournaments
  where id=p_tournament_id
    and circuit='Junior'
    and singles=true
    and coalesce(is_active,true)=true;

  if t.id is null then
    return jsonb_build_object('ok',false,'reason','tournament_not_found');
  end if;

  if t.category in ('Junior Davis Cup','Junior Finals','Junior Double Finals')
     or coalesce(t.qualifying_draw_size,0)<=0 then
    return jsonb_build_object('ok',true,'skipped','no_junior_qualifying');
  end if;

  if exists(
    select 1 from public.world_tournament_qualifying_entries
    where tournament_id=t.id
      and source_label like 'ITF Junior 2026 qualifying%'
  ) then
    return jsonb_build_object(
      'ok',true,'already_simulated',true,
      'qualifiers',(select count(*) from public.world_tournament_qualifying_entries where tournament_id=t.id and qualified=true)
    );
  end if;

  perform public.prepare_junior_entry_reservations(t.id);
  select managed_player_id into v_managed from public.career_state where id='demo';

  v_main:=greatest(16,least(128,coalesce(t.singles_draw_size,t.draw_size,32)));
  v_qdraw:=greatest(8,least(128,coalesce(t.qualifying_draw_size,32)));
  v_qslots:=public.junior_qualifier_slots(v_main,t.category);
  v_qwc:=least(v_qdraw,public.junior_qualifying_wildcards(v_qdraw));

  delete from public.world_tournament_matches
  where tournament_id=t.id and is_qualifying=true;

  delete from public.world_tournament_qualifying_entries
  where tournament_id=t.id;

  drop table if exists pg_temp.cb_jq_pool;
  create temporary table cb_jq_pool(
    player_id bigint primary key,
    rankv int,
    score numeric,
    entry_method text not null,
    rn int,
    section_no int
  ) on commit drop;

  -- Qualifying wild cards first.
  insert into cb_jq_pool(player_id,rankv,score,entry_method)
  select p.id,coalesce(p.junior_ranking,999999),
         public.junior_wtn_proxy_score(p.id,t.start_date),
         'qualifying_wildcard'
  from public.players p
  where p.id is distinct from v_managed
    and p.career_status='active'
    and upper(coalesce(p.country,''))=upper(coalesce(t.country,''))
    and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
    and p.injury_status='Fit'
    and coalesce(p.fitness,90)>=45
    and coalesce(p.fatigue,20)<=90
    and (
      p.birth_date is null
      or (
        p.birth_date<=t.start_date-interval '13 years'
        and extract(year from t.start_date)::int-extract(year from p.birth_date)::int<=18
      )
    )
    and not exists(
      select 1 from public.junior_entry_reservations r
      where r.tournament_id=t.id and r.player_id=p.id
    )
    and public.junior_player_commits_to_event(p.id,t.id,'singles')
  order by public.junior_wtn_proxy_score(p.id,t.start_date) desc,
           coalesce(p.junior_ranking,999999),p.id
  limit v_qwc;

  insert into cb_jq_pool(player_id,rankv,score,entry_method)
  select p.id,coalesce(p.junior_ranking,999999),
         (
           greatest(0,2500-coalesce(p.junior_ranking,2500))*.055+
           public.junior_wtn_proxy_score(p.id,t.start_date)*.18+
           (mod(abs(hashtext('jq-entry|'||t.id||'|'||p.id)),1000)::numeric/1000.0)*2
         ),
         case when t.category in ('J30','J60') and p.junior_ranking is null
              then 'rating_qualifying_2026' else 'qualifying' end
  from public.players p
  where p.id is distinct from v_managed
    and p.career_status='active'
    and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
    and p.injury_status='Fit'
    and coalesce(p.fitness,90)>=45
    and coalesce(p.fatigue,20)<=90
    and (
      p.birth_date is null
      or (
        p.birth_date<=t.start_date-interval '13 years'
        and extract(year from t.start_date)::int-extract(year from p.birth_date)::int<=18
      )
    )
    and (
      p.junior_ranking is not null
      or t.category in ('J30','J60')
    )
    and not exists(select 1 from cb_jq_pool q where q.player_id=p.id)
    and not exists(
      select 1 from public.junior_entry_reservations r
      where r.tournament_id=t.id and r.player_id=p.id
    )
    and public.junior_player_commits_to_event(p.id,t.id,'singles')
  order by 3 desc,p.id
  limit greatest(0,v_qdraw-(select count(*) from cb_jq_pool));

  select count(*) into v_selected from cb_jq_pool;
  if v_selected<v_qslots then
    return jsonb_build_object('ok',false,'reason','insufficient_qualifying_field','selected',v_selected,'needed',v_qdraw);
  end if;

  with ranked as (
    select player_id,row_number() over(
      order by case when entry_method='qualifying_wildcard' then 1 else 0 end,
               rankv,score desc,player_id
    )::int rn
    from cb_jq_pool
  )
  update cb_jq_pool q
  set rn=r.rn,
      section_no=((r.rn-1)%v_qslots)+1
  from ranked r where r.player_id=q.player_id;

  insert into public.world_tournament_qualifying_entries(
    tournament_id,player_id,entry_method,ranking_at_entry,result_code,result_label,
    qualified,points_awarded,prize_awarded,prize_currency,prize_is_estimate,
    simulated_on,source_label
  )
  select
    t.id,q.player_id,q.entry_method,q.rankv,
    'Q1','Qualifications junior',false,0,0,null,false,
    coalesce(t.qualifying_end_date,p_simulated_on,t.start_date-1),
    'ITF Junior 2026 qualifying · section knockout'
  from cb_jq_pool q;

  for v_section in 1..v_qslots loop
    drop table if exists pg_temp.cb_jq_current;
    drop table if exists pg_temp.cb_jq_next;
    create temporary table cb_jq_current(pos int primary key,player_id bigint) on commit drop;
    create temporary table cb_jq_next(pos int primary key,player_id bigint) on commit drop;

    insert into cb_jq_current(pos,player_id)
    select row_number() over(order by rankv,score desc,player_id)::int,player_id
    from cb_jq_pool
    where section_no=v_section
    order by rankv,score desc,player_id;

    select count(*) into v_size from cb_jq_current;
    v_round:=1;

    while v_size>1 loop
      v_bracket:=1;
      while v_bracket<v_size loop v_bracket:=v_bracket*2; end loop;
      v_byes:=v_bracket-v_size;
      truncate cb_jq_next;
      v_next_pos:=0;

      if v_byes>0 then
        for v_pos in 1..v_byes loop
          v_next_pos:=v_next_pos+1;
          insert into cb_jq_next(pos,player_id)
          select v_next_pos,player_id from cb_jq_current where pos=v_pos;
        end loop;
      end if;

      v_pos:=v_byes+1;
      while v_pos<=v_size loop
        select player_id into v_a from cb_jq_current where pos=v_pos;
        select player_id into v_b from cb_jq_current where pos=v_pos+1;
        exit when v_a is null or v_b is null;

        v_match:=public.player_matchup_probability_v4(
          v_a,v_b,t.surface,
          least(coalesce(t.qualifying_end_date,t.start_date-1),
                coalesce(t.qualifying_start_date,t.start_date-2)+(v_round-1)),
          coalesce(t.court_speed,case when t.surface ilike 'Terre%' then .68 when t.surface ilike 'Gazon%' then 1.15 else 1.0 end),
          3
        );
        v_prob:=greatest(.02,least(.98,coalesce((v_match->>'player_a_probability')::numeric,.5)));
        v_roll:=mod(abs(hashtext('junior-q|'||t.id||'|'||v_section||'|'||v_round||'|'||v_a||'|'||v_b)),10000)/10000.0;
        v_awon:=v_roll<v_prob;
        v_w:=case when v_awon then v_a else v_b end;
        v_l:=case when v_awon then v_b else v_a end;
        v_score:=public.world_tournament_score(v_prob,v_awon,3);
        v_played:=least(
          coalesce(t.qualifying_end_date,t.start_date-1),
          coalesce(t.qualifying_start_date,t.start_date-2)+(v_round-1)
        );

        v_match_no:=v_match_no+1;
        insert into public.world_tournament_matches(
          tournament_id,round_no,round_code,group_name,match_no,
          player_a_id,player_b_id,winner_id,loser_id,score,best_of,
          player_a_win_probability,court_speed,model_version,matchup_components,
          simulated_on,is_qualifying
        ) values(
          t.id,100+v_round,'Q'||v_round,'Q-Section '||v_section,v_match_no,
          v_a,v_b,v_w,v_l,v_score,3,round(v_prob,4),
          coalesce(t.court_speed,1.0),'CB-JUNIOR-Q-v1',
          coalesce(v_match->'components','{}'::jsonb),
          v_played,true
        );

        update public.world_tournament_qualifying_entries
        set result_code='Q'||v_round,
            result_label='Qualifications · tour '||v_round,
            last_opponent_id=v_w,
            last_opponent_name=(select name from public.players where id=v_w),
            last_score=case when v_l=v_a then v_score else public.world_invert_tennis_score(v_score) end
        where tournament_id=t.id and player_id=v_l;

        update public.players
        set fatigue=least(100,coalesce(fatigue,20)+2),
            fitness=greatest(35,coalesce(fitness,90)-1)
        where id in (v_a,v_b);

        v_next_pos:=v_next_pos+1;
        insert into cb_jq_next(pos,player_id) values(v_next_pos,v_w);
        v_total_matches:=v_total_matches+1;
        v_pos:=v_pos+2;
      end loop;

      truncate cb_jq_current;
      insert into cb_jq_current select * from cb_jq_next order by pos;
      select count(*) into v_size from cb_jq_current;
      v_round:=v_round+1;
    end loop;

    select player_id into v_w from cb_jq_current order by pos limit 1;
    if v_w is not null then
      update public.world_tournament_qualifying_entries
      set result_code='Q',
          result_label='Qualifié',
          qualified=true,
          last_opponent_id=null
      where tournament_id=t.id and player_id=v_w;
      v_qualifiers:=v_qualifiers+1;
    end if;
  end loop;

  return jsonb_build_object(
    'ok',true,'tournament_id',t.id,'qualifying_draw',v_selected,
    'qualifier_slots',v_qslots,'qualifiers',v_qualifiers,
    'matches_simulated',v_total_matches,
    'model','ITF Junior 2026 qualifying v1'
  );
end;
$function$;
