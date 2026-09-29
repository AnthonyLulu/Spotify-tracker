-- Court Boss junior entry realism + Nitto ATP Finals doubles
-- Captured from live Supabase on 2026-09-30.
-- Career baseline remains 2025-12-01.

create table if not exists public.junior_entry_reservations(
  tournament_id bigint not null references public.tournaments(id) on delete cascade,
  player_id bigint not null references public.players(id) on delete cascade,
  entry_method text not null,
  reserved_on date not null,
  model_version text not null default 'CB-JUNIOR-ENTRY-v1',
  primary key(tournament_id,player_id)
);
alter table public.junior_entry_reservations enable row level security;
create index if not exists junior_entry_reservations_player_idx
  on public.junior_entry_reservations(player_id,tournament_id);

create table if not exists public.junior_doubles_reservations(
  tournament_id bigint not null references public.tournaments(id) on delete cascade,
  player_a_id bigint not null references public.players(id) on delete cascade,
  player_b_id bigint not null references public.players(id) on delete cascade,
  entry_method text not null default 'direct',
  acceptance_group integer not null default 6,
  combined_rank integer not null default 1999998,
  pair_strength integer not null default 0,
  seed integer,
  draw_slot integer,
  reserved_on date not null,
  model_version text not null default 'CB-JUNIOR-DOUBLES-ENTRY-v1',
  primary key(tournament_id,player_a_id,player_b_id),
  check(player_a_id<player_b_id)
);
alter table public.junior_doubles_reservations enable row level security;
create index if not exists junior_doubles_reservations_player_a_idx
  on public.junior_doubles_reservations(player_a_id,tournament_id);
create index if not exists junior_doubles_reservations_player_b_idx
  on public.junior_doubles_reservations(player_b_id,tournament_id);

create table if not exists public.atp_finals_doubles_selection(
  tournament_id bigint not null references public.tournaments(id) on delete cascade,
  pair_id bigint not null references public.world_doubles_partnerships(id) on delete cascade,
  seed integer not null,
  selection_position integer not null,
  race_rank integer,
  race_points integer not null default 0,
  entry_reason text not null,
  group_name text not null,
  selected_on date not null,
  primary key(tournament_id,pair_id),
  unique(tournament_id,seed)
);
alter table public.atp_finals_doubles_selection enable row level security;
create index if not exists atp_finals_doubles_selection_tournament_group_idx
  on public.atp_finals_doubles_selection(tournament_id,group_name,seed);

create table if not exists public.atp_finals_doubles_match_stats(
  match_id bigint primary key references public.world_doubles_tournament_matches(id) on delete cascade,
  pair_a_sets integer not null,
  pair_b_sets integer not null,
  pair_a_games integer not null,
  pair_b_games integer not null,
  match_tiebreak boolean not null default false
);
alter table public.atp_finals_doubles_match_stats enable row level security;

CREATE OR REPLACE FUNCTION public.junior_qualifier_slots(p_main_draw integer, p_category text)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  select case
    when p_category in ('J30','J60','J100') and p_main_draw=32 then 8
    when p_main_draw<=16 then 2
    when p_main_draw<=24 then 2
    when p_main_draw<=32 then 4
    when p_main_draw<=48 then 6
    else 8
  end;
$function$;

CREATE OR REPLACE FUNCTION public.junior_main_wildcards(p_main_draw integer)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  select case
    when p_main_draw<=16 then 2
    when p_main_draw<=24 then 2
    when p_main_draw<=32 then 4
    when p_main_draw<=48 then 6
    else 8
  end;
$function$;

CREATE OR REPLACE FUNCTION public.junior_qualifying_wildcards(p_qdraw integer)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  select case
    when p_qdraw<=16 then 2
    when p_qdraw<=24 then 4
    when p_qdraw<=32 then 6
    when p_qdraw<=48 then 7
    else 8
  end;
$function$;

CREATE OR REPLACE FUNCTION public.junior_wtn_proxy_score(p_player_id bigint, p_date date)
 RETURNS numeric
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select (
    coalesce(p.current_ability,50)*2.00+
    coalesce(p.potential,70)*.38+
    coalesce(p.form,70)*.18+
    coalesce(p.fitness,85)*.08-
    coalesce(p.fatigue,20)*.10+
    greatest(0,18-coalesce(
      extract(year from age(p_date,p.birth_date))::int,
      p.age,18
    ))*.45+
    (mod(abs(hashtext('junior-rating-proxy|'||p_player_id||'|'||p_date)),1000)::numeric/1000.0)*2
  )
  from public.players p
  where p.id=p_player_id;
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
    and coalesce(p.fatigue,20)<=90
    and (
      p.birth_date is null
      or (
        p.birth_date<=t.start_date-interval '13 years'
        and extract(year from t.start_date)::int-extract(year from p.birth_date)::int<=18
      )
    )
    and not (public.player_tournament_calendar_conflict(p.id,t.id,'direct')->>'conflict')::boolean
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
      and not (public.player_tournament_calendar_conflict(p.id,t.id,'direct')->>'conflict')::boolean
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
    and not (public.player_tournament_calendar_conflict(p.id,t.id,'wildcard')->>'conflict')::boolean
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
    and not (public.player_tournament_calendar_conflict(p.id,t.id,'qualifying_wildcard')->>'conflict')::boolean
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
    and not (public.player_tournament_calendar_conflict(p.id,t.id,'qualifying')->>'conflict')::boolean
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

CREATE OR REPLACE FUNCTION public.simulate_junior_qualifying_window(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t record;
  r jsonb;
  simulated int:=0;
  already int:=0;
  skipped int:=0;
  qualifiers int:=0;
begin
  for t in
    select *
    from public.tournaments
    where circuit='Junior'
      and singles=true
      and coalesce(is_active,true)=true
      and category not in ('Junior Davis Cup','Junior Finals','Junior Double Finals')
      and coalesce(qualifying_draw_size,0)>0
      and coalesce(qualifying_end_date,start_date-1)>greatest(p_from_date,date '2025-12-01')
      and coalesce(qualifying_end_date,start_date-1)<=p_to_date
    order by coalesce(qualifying_end_date,start_date-1),id
    limit 120
  loop
    r:=public.simulate_junior_qualifying_full(
      t.id,coalesce(t.qualifying_end_date,t.start_date-1,p_to_date)
    );

    if coalesce((r->>'ok')::boolean,false)=false then
      skipped:=skipped+1;
    elsif coalesce((r->>'already_simulated')::boolean,false) then
      already:=already+1;
      qualifiers:=qualifiers+coalesce((r->>'qualifiers')::int,0);
    elsif r ? 'skipped' then
      skipped:=skipped+1;
    else
      simulated:=simulated+1;
      qualifiers:=qualifiers+coalesce((r->>'qualifiers')::int,0);
    end if;
  end loop;

  return jsonb_build_object(
    'qualifying_simulated',simulated,
    'already_simulated',already,
    'skipped',skipped,
    'qualifiers_created',qualifiers,
    'from',p_from_date,'to',p_to_date,
    'model','ITF Junior 2026 qualifying window v1'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.simulate_junior_world_singles_full(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  v_managed bigint;
  v_draw int;
  v_bracket int;
  v_rounds int;
  v_size int;
  v_round int;
  v_pos int;
  v_next int;
  v_a bigint;
  v_b bigint;
  v_w bigint;
  v_l bigint;
  v_a_name text;
  v_b_name text;
  v_w_name text;
  v_l_name text;
  v_match jsonb;
  v_prob numeric;
  v_awon boolean;
  v_score text;
  v_code text;
  v_winner bigint;
  v_finalist bigint;
  v_singles int:=0;
  v_matches int:=0;
  v_selected int;
  rr record;
begin
  select managed_player_id into v_managed from public.career_state where id='demo';

  for t in
    select *
    from public.tournaments
    where circuit='Junior'
      and singles=true
      and coalesce(is_active,true)=true
      and coalesce(end_date,start_date)>p_from_date
      and coalesce(end_date,start_date)<=p_to_date
      and category not in ('Junior Davis Cup','Junior Finals','Junior Double Finals')
      and not exists(select 1 from public.world_tournament_simulations s where s.tournament_id=tournaments.id)
    order by
      date_trunc('week',start_date::timestamp),
      case
        when category='Junior Grand Slam' then 100
        when category='J500' then 90
        when category='J300' then 80
        when category='J200' then 70
        when category='J100' then 60
        when category='J60' then 50
        when category='J30' then 40
        else 10 end desc,
      coalesce(end_date,start_date),id
    limit 100
  loop
    v_draw:=greatest(16,least(64,coalesce(t.singles_draw_size,t.draw_size,32)));

    drop table if exists pg_temp.cb_j_entries;
    create temporary table cb_j_entries(
      player_id bigint primary key,
      name text not null,
      rank_at_entry int,
      seed int,
      draw_slot int,
      entry_method text not null default 'direct',
      qualifying_points int not null default 0,
      group_name text,
      wins int not null default 0,
      losses int not null default 0,
      result_code text,
      result_label text,
      points_awarded int not null default 0,
      last_opponent_id bigint,
      last_opponent_name text,
      last_score text
    ) on commit drop;

    perform public.prepare_junior_entry_reservations(t.id);

    -- Qualifiers earned their place in the qualifying window.
    insert into cb_j_entries(
      player_id,name,rank_at_entry,entry_method,qualifying_points
    )
    select p.id,p.name,coalesce(p.junior_ranking,999999)::int,
           'qualifier',coalesce(q.points_awarded,0)
    from public.world_tournament_qualifying_entries q
    join public.players p on p.id=q.player_id
    where q.tournament_id=t.id
      and q.qualified=true
      and p.career_status='active'
      and p.injury_status='Fit'
      and coalesce(p.fitness,90)>=40
    order by coalesce(p.junior_ranking,999999),p.current_ability desc,p.id
    limit public.junior_qualifier_slots(v_draw,t.category)
    on conflict(player_id) do nothing;

    -- Direct acceptances, 2026 rating-based slots and host wild cards were
    -- reserved before qualifying, so they cannot leak into the qualifying draw.
    insert into cb_j_entries(
      player_id,name,rank_at_entry,entry_method,qualifying_points
    )
    select p.id,p.name,coalesce(p.junior_ranking,999999)::int,
           r.entry_method,0
    from public.junior_entry_reservations r
    join public.players p on p.id=r.player_id
    where r.tournament_id=t.id
      and p.career_status='active'
      and p.injury_status='Fit'
      and coalesce(p.fitness,90)>=40
      and not (public.player_tournament_calendar_conflict(p.id,t.id,'direct')->>'conflict')::boolean
    order by
      case r.entry_method
        when 'direct' then 1
        when 'rating_acceptance_2026' then 2
        when 'wildcard' then 3
        else 4 end,
      coalesce(p.junior_ranking,999999),p.current_ability desc,p.id
    on conflict(player_id) do nothing;

    -- Fill any late vacancy with an alternate, never with a player who already
    -- lost in this event's qualifying draw.
    insert into cb_j_entries(
      player_id,name,rank_at_entry,entry_method,qualifying_points
    )
    select p.id,p.name,coalesce(p.junior_ranking,999999)::int,
           'alternate',0
    from public.players p
    where p.career_status='active'
      and p.id is distinct from v_managed
      and p.junior_ranking is not null
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
      and not exists(select 1 from cb_j_entries e where e.player_id=p.id)
      and not exists(
        select 1 from public.world_tournament_qualifying_entries q
        where q.tournament_id=t.id and q.player_id=p.id
      )
      and not (public.player_tournament_calendar_conflict(p.id,t.id,'direct')->>'conflict')::boolean
      and public.ai_player_commits_to_tournament(p.id,t.id)
      and public.junior_player_commits_to_event(p.id,t.id,'singles')
    order by coalesce(p.junior_ranking,999999),p.current_ability desc,p.id
    limit greatest(0,v_draw-(select count(*) from cb_j_entries))
    on conflict(player_id) do nothing;

    with seeded as (
      select player_id,
             row_number() over(
               order by coalesce(rank_at_entry,999999),
                        (select current_ability from public.players p where p.id=cb_j_entries.player_id) desc,
                        player_id
             )::int rn
      from cb_j_entries
    )
    update cb_j_entries e
    set seed=s.rn
    from seeded s
    where s.player_id=e.player_id;

    select count(*) into v_selected from cb_j_entries;
    if v_selected<>v_draw then
      continue;
    end if;

    delete from public.world_tournament_matches where tournament_id=t.id and is_qualifying=false;
    delete from public.world_tournament_entries where tournament_id=t.id;

    if t.junior_draw_format='round_robin_to_elimination'
       and t.category in ('J30','J60') and v_draw=32 then

      update cb_j_entries
      set group_name=chr(65+((seed-1)%8))
      where seed<=8;

      with rem as (
        select player_id,row_number() over(order by md5('jrr|'||t.id::text||'|'||player_id::text)) rn
        from cb_j_entries where group_name is null
      )
      update cb_j_entries e
      set group_name=chr(65+(((r.rn-1)%8)::int))
      from rem r where e.player_id=r.player_id;

      for rr in
        select a.player_id a_id,b.player_id b_id,a.name a_name,b.name b_name,a.group_name,
               row_number() over(order by a.group_name,a.seed,b.seed)::int match_no
        from cb_j_entries a
        join cb_j_entries b on b.group_name=a.group_name and b.seed>a.seed
        order by a.group_name,a.seed,b.seed
      loop
        v_a:=rr.a_id;v_b:=rr.b_id;v_a_name:=rr.a_name;v_b_name:=rr.b_name;
        v_match:=public.player_matchup_probability_v4(
          v_a,v_b,t.surface,t.start_date,
          coalesce(t.court_speed,case when t.surface ilike 'Terre%' then .68 when t.surface ilike 'Gazon%' then 1.15 else 1.0 end),3
        );
        v_prob:=greatest(.02,least(.98,coalesce((v_match->>'player_a_probability')::numeric,.5)));
        v_awon:=random()<v_prob;
        v_w:=case when v_awon then v_a else v_b end;
        v_l:=case when v_awon then v_b else v_a end;
        v_w_name:=case when v_awon then v_a_name else v_b_name end;
        v_l_name:=case when v_awon then v_b_name else v_a_name end;
        v_score:=public.world_tournament_score(v_prob,v_awon,3);

        insert into public.world_tournament_matches(
          tournament_id,round_no,round_code,group_name,match_no,
          player_a_id,player_b_id,winner_id,loser_id,score,best_of,
          player_a_win_probability,court_speed,model_version,matchup_components,simulated_on
        ) values(
          t.id,1,'RR',rr.group_name,rr.match_no,v_a,v_b,v_w,v_l,v_score,3,round(v_prob,4),
          coalesce(t.court_speed,1.0),'CB-JUNIOR-v4-ROUNDROBIN',
          coalesce(v_match->'components','{}'::jsonb),t.start_date
        );
        v_matches:=v_matches+1;

        update cb_j_entries
        set wins=wins+1,last_opponent_id=v_l,last_opponent_name=v_l_name,
            last_score=case when v_w=v_a then v_score else public.world_invert_tennis_score(v_score) end
        where player_id=v_w;
        update cb_j_entries
        set losses=losses+1,last_opponent_id=v_w,last_opponent_name=v_w_name,
            last_score=case when v_l=v_a then v_score else public.world_invert_tennis_score(v_score) end
        where player_id=v_l;
      end loop;

      drop table if exists pg_temp.cb_j_rr_rank;
      create temporary table cb_j_rr_rank on commit drop as
      select player_id,group_name,wins,
             row_number() over(partition by group_name order by wins desc,seed asc)::int group_pos
      from cb_j_entries;

      update cb_j_entries e
      set result_code='RR'||r.group_pos::text,
          result_label='Groupe · position '||r.group_pos::text,
          points_awarded=case
            when r.group_pos=2 then case when t.category='J60' then 5 else 2 end
            when r.group_pos in (3,4) and e.wins>0 then case when t.category='J60' then 2 else 1 end
            else 0 end
      from cb_j_rr_rank r
      where e.player_id=r.player_id and r.group_pos>1;

      drop table if exists pg_temp.cb_j_current;
      drop table if exists pg_temp.cb_j_next;
      create temporary table cb_j_current(pos int primary key,player_id bigint) on commit drop;
      create temporary table cb_j_next(pos int primary key,player_id bigint) on commit drop;

      insert into cb_j_current(pos,player_id)
      select row_number() over(order by group_name)::int,player_id
      from cb_j_rr_rank where group_pos=1 order by group_name;

      v_size:=8;
      v_round:=2;
      while v_size>1 loop
        truncate cb_j_next;
        v_next:=0;
        v_code:=case when v_size=8 then 'QF' when v_size=4 then 'SF' else 'F' end;

        for v_pos in 1..v_size by 2 loop
          v_next:=v_next+1;
          select player_id into v_a from cb_j_current where pos=v_pos;
          select player_id into v_b from cb_j_current where pos=v_pos+1;
          select name into v_a_name from cb_j_entries where player_id=v_a;
          select name into v_b_name from cb_j_entries where player_id=v_b;

          v_match:=public.player_matchup_probability_v4(v_a,v_b,t.surface,t.end_date,coalesce(t.court_speed,1.0),3);
          v_prob:=greatest(.02,least(.98,coalesce((v_match->>'player_a_probability')::numeric,.5)));
          v_awon:=random()<v_prob;
          v_w:=case when v_awon then v_a else v_b end;
          v_l:=case when v_awon then v_b else v_a end;
          v_w_name:=case when v_awon then v_a_name else v_b_name end;
          v_l_name:=case when v_awon then v_b_name else v_a_name end;
          v_score:=public.world_tournament_score(v_prob,v_awon,3);

          insert into public.world_tournament_matches(
            tournament_id,round_no,round_code,match_no,player_a_id,player_b_id,winner_id,loser_id,
            score,best_of,player_a_win_probability,court_speed,model_version,matchup_components,simulated_on
          ) values(
            t.id,v_round,v_code,v_next,v_a,v_b,v_w,v_l,v_score,3,round(v_prob,4),
            coalesce(t.court_speed,1.0),'CB-JUNIOR-v4-ROUNDROBIN',
            coalesce(v_match->'components','{}'::jsonb),t.end_date
          );
          v_matches:=v_matches+1;

          update cb_j_entries
          set result_code=v_code,
              result_label=case v_code when 'QF' then 'Quart de finale' when 'SF' then 'Demi-finale' else 'Finaliste' end,
              points_awarded=public.junior_points_for('singles',t.category,v_code),
              last_opponent_id=v_w,last_opponent_name=v_w_name,
              last_score=case when v_l=v_a then v_score else public.world_invert_tennis_score(v_score) end
          where player_id=v_l;
          update cb_j_entries set wins=wins+1 where player_id=v_w;
          insert into cb_j_next values(v_next,v_w);
        end loop;

        truncate cb_j_current;
        insert into cb_j_current select * from cb_j_next;
        v_size:=v_size/2;
        v_round:=v_round+1;
      end loop;

      select player_id into v_winner from cb_j_current limit 1;
      update cb_j_entries
      set result_code='W',result_label='Vainqueur',
          points_awarded=public.junior_points_for('singles',t.category,'W')
      where player_id=v_winner;

    else
      v_bracket:=case when v_draw<=16 then 16 when v_draw<=32 then 32 else 64 end;
      v_rounds:=ceil(ln(v_bracket::numeric)/ln(2::numeric))::int;

      update cb_j_entries
      set draw_slot=public.world_tournament_seed_slot(v_bracket,seed)
      where seed<=least(case when v_bracket>=64 then 16 else 8 end,v_draw);

      with bye_slots as (
        select case when draw_slot%2=1 then draw_slot+1 else draw_slot-1 end slot
        from cb_j_entries
        where v_bracket>v_draw and seed<=least(v_bracket-v_draw,v_draw) and draw_slot is not null
      ),
      used as (
        select draw_slot slot from cb_j_entries where draw_slot is not null
        union all select slot from bye_slots
      ),
      avail as (
        select g slot,row_number() over(order by md5('jslot|'||t.id::text||'|'||g::text)) rn
        from generate_series(1,v_bracket) g
        where not exists(select 1 from used u where u.slot=g)
      ),
      unplaced as (
        select player_id,row_number() over(order by md5('jplayer|'||t.id::text||'|'||player_id::text)) rn
        from cb_j_entries where draw_slot is null
      )
      update cb_j_entries e
      set draw_slot=a.slot
      from unplaced u join avail a using(rn)
      where e.player_id=u.player_id;

      drop table if exists pg_temp.cb_j_current;
      drop table if exists pg_temp.cb_j_next;
      create temporary table cb_j_current(pos int primary key,player_id bigint) on commit drop;
      create temporary table cb_j_next(pos int primary key,player_id bigint) on commit drop;

      insert into cb_j_current(pos,player_id)
      select g,e.player_id
      from generate_series(1,v_bracket) g
      left join cb_j_entries e on e.draw_slot=g;

      v_size:=v_bracket;
      for v_round in 1..v_rounds loop
        truncate cb_j_next;
        v_next:=0;
        v_code:=case when v_size>=64 then 'R64' when v_size>=32 then 'R32' when v_size>=16 then 'R16'
                     when v_size>=8 then 'QF' when v_size>=4 then 'SF' else 'F' end;

        for v_pos in 1..v_size by 2 loop
          v_next:=v_next+1;
          select player_id into v_a from cb_j_current where pos=v_pos;
          select player_id into v_b from cb_j_current where pos=v_pos+1;

          if v_a is null and v_b is null then
            insert into cb_j_next(pos,player_id) values(v_next,null);
            continue;
          elsif v_a is null or v_b is null then
            insert into cb_j_next(pos,player_id) values(v_next,coalesce(v_a,v_b));
            continue;
          end if;

          select name into v_a_name from cb_j_entries where player_id=v_a;
          select name into v_b_name from cb_j_entries where player_id=v_b;
          v_match:=public.player_matchup_probability_v4(v_a,v_b,t.surface,t.end_date,coalesce(t.court_speed,1.0),3);
          v_prob:=greatest(.02,least(.98,coalesce((v_match->>'player_a_probability')::numeric,.5)));
          v_awon:=random()<v_prob;
          v_w:=case when v_awon then v_a else v_b end;
          v_l:=case when v_awon then v_b else v_a end;
          v_w_name:=case when v_awon then v_a_name else v_b_name end;
          v_l_name:=case when v_awon then v_b_name else v_a_name end;
          v_score:=public.world_tournament_score(v_prob,v_awon,3);

          insert into public.world_tournament_matches(
            tournament_id,round_no,round_code,match_no,player_a_id,player_b_id,winner_id,loser_id,
            score,best_of,player_a_win_probability,court_speed,model_version,matchup_components,simulated_on
          ) values(
            t.id,v_round,v_code,v_next,v_a,v_b,v_w,v_l,v_score,3,round(v_prob,4),
            coalesce(t.court_speed,1.0),'CB-JUNIOR-v4-FULLDRAW',
            coalesce(v_match->'components','{}'::jsonb),t.end_date
          );
          v_matches:=v_matches+1;

          update cb_j_entries
          set result_code=v_code,
              result_label=public.world_tournament_result_label(v_code),
              points_awarded=public.junior_points_for('singles',t.category,v_code),
              last_opponent_id=v_w,last_opponent_name=v_w_name,
              last_score=case when v_l=v_a then v_score else public.world_invert_tennis_score(v_score) end
          where player_id=v_l;
          update cb_j_entries set wins=wins+1 where player_id=v_w;
          insert into cb_j_next values(v_next,v_w);
        end loop;

        truncate cb_j_current;
        insert into cb_j_current select * from cb_j_next;
        v_size:=greatest(1,v_size/2);
      end loop;

      select player_id into v_winner from cb_j_current order by pos limit 1;
      update cb_j_entries
      set result_code='W',result_label='Vainqueur',
          points_awarded=public.junior_points_for('singles',t.category,'W')
      where player_id=v_winner;
    end if;

    select loser_id into v_finalist
    from public.world_tournament_matches
    where tournament_id=t.id and round_code='F'
    order by id desc limit 1;

    insert into public.world_tournament_entries(
      tournament_id,player_id,seed,draw_slot,entry_method,ranking_at_entry,had_bye,matches_won,
      result_code,result_label,points_awarded,qualifying_points,last_opponent_id,last_opponent_name,
      last_score,simulated_on,source_label
    )
    select t.id,player_id,seed,coalesce(draw_slot,seed),entry_method,rank_at_entry,false,wins,
           result_code,result_label,points_awarded,qualifying_points,last_opponent_id,last_opponent_name,last_score,
           t.end_date,'Court Boss junior full draw + 2026 entry composition · '||t.junior_draw_format
    from cb_j_entries;

    update public.players p
    set junior_game_points=coalesce(p.junior_game_points,0)+e.points_awarded,
        form=greatest(35,least(100,p.form+case e.result_code when 'W' then 4 when 'F' then 3 when 'SF' then 2 else 0 end)),
        morale=greatest(30,least(100,p.morale+case e.result_code when 'W' then 4 when 'F' then 2 else 0 end))
    from cb_j_entries e
    where p.id=e.player_id;

    insert into public.player_tournament_history(
      player_id,season,tournament_id,tournament_name,tournament_date,level,category,surface,
      result_code,result_label,last_opponent,last_score,is_grand_slam,source,event_type
    )
    select player_id,extract(year from t.end_date)::int,t.id::text,t.name,t.end_date,t.category,t.category,t.surface,
           result_code,result_label,last_opponent_name,last_score,t.category='Junior Grand Slam',
           'Court Boss junior full draw','junior_singles'
    from cb_j_entries
    on conflict(player_id,event_type,tournament_id) do update set
      result_code=excluded.result_code,result_label=excluded.result_label,last_opponent=excluded.last_opponent,
      last_score=excluded.last_score,source=excluded.source;

    select name into v_w_name from public.players where id=v_winner;
    select name into v_l_name from public.players where id=v_finalist;

    insert into public.player_titles(
      player_id,tournament_name,title_date,level,surface,event_type,verified,source_label,origin
    )
    values(v_winner,t.name,t.end_date,t.category,t.surface,'junior_singles',false,'Court Boss junior full draw','game')
    on conflict(player_id,tournament_name,title_date,event_type) do nothing;

    insert into public.player_final_results(
      player_id,tournament_name,final_date,level,surface,result,opponent_name,source,event_type
    )
    values
      (v_winner,t.name,t.end_date,t.category,t.surface,'Champion',v_l_name,'Court Boss junior full draw','junior_singles'),
      (v_finalist,t.name,t.end_date,t.category,t.surface,'Finaliste',v_w_name,'Court Boss junior full draw','junior_singles')
    on conflict(player_id,tournament_name,final_date,result) do nothing;

    insert into public.world_tournament_simulations(
      tournament_id,winner_id,finalist_id,winner_points,finalist_points,simulated_on,
      model_version,rule_key,draw_size,bracket_size,rounds_count,matches_simulated,participants_simulated,format_type
    ) values(
      t.id,v_winner,v_finalist,
      public.junior_points_for('singles',t.category,'W'),
      public.junior_points_for('singles',t.category,'F'),t.end_date,
      case when t.junior_draw_format='round_robin_to_elimination' then 'CB-JUNIOR-v4-RR' else 'CB-JUNIOR-v4-FULLDRAW' end,
      'JUNIOR_'||replace(t.category,' ','_')||'_'||v_draw,
      v_draw,
      case when v_draw<=16 then 16 when v_draw<=32 then 32 else 64 end,
      case when t.junior_draw_format='round_robin_to_elimination' then 4
           else ceil(ln((case when v_draw<=16 then 16 when v_draw<=32 then 32 else 64 end)::numeric)/ln(2::numeric))::int end,
      (select count(*) from public.world_tournament_matches where tournament_id=t.id and is_qualifying=false),
      v_draw,t.junior_draw_format
    );

    v_singles:=v_singles+1;
  end loop;

  return jsonb_build_object(
    'singles_simulated',v_singles,'matches_simulated',v_matches,
    'from',p_from_date,'to',p_to_date,'model','CB-JUNIOR-v4 full draw / RR hybrid'
  );
end
$function$;

CREATE OR REPLACE FUNCTION public.junior_doubles_wildcards(p_draw integer)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  select case
    when p_draw<=8 then 1
    when p_draw<=16 then 2
    when p_draw<=24 then 2
    when p_draw<=32 then 4
    when p_draw<=48 then 6
    else 8
  end;
$function$;

CREATE OR REPLACE FUNCTION public.junior_doubles_player_acceptance_status(p_player_id bigint, p_tournament_id bigint)
 RETURNS integer
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
begin
  -- 1 = singles main draw participant (excluding singles main-draw wild cards).
  if exists(
    select 1
    from public.junior_entry_reservations r
    where r.tournament_id=p_tournament_id
      and r.player_id=p_player_id
      and r.entry_method in ('direct','rating_acceptance_2026','alternate')
  )
  or exists(
    select 1
    from public.world_tournament_qualifying_entries q
    where q.tournament_id=p_tournament_id
      and q.player_id=p_player_id
      and q.qualified=true
  )
  or exists(
    select 1
    from public.world_tournament_entries e
    where e.tournament_id=p_tournament_id
      and e.player_id=p_player_id
      and e.entry_method<>'wildcard'
  ) then
    return 1;
  end if;

  -- 2 = singles qualifying participant OR singles main-draw wild card.
  if exists(
    select 1
    from public.world_tournament_qualifying_entries q
    where q.tournament_id=p_tournament_id
      and q.player_id=p_player_id
  )
  or exists(
    select 1
    from public.junior_entry_reservations r
    where r.tournament_id=p_tournament_id
      and r.player_id=p_player_id
      and r.entry_method='wildcard'
  )
  or exists(
    select 1
    from public.world_tournament_entries e
    where e.tournament_id=p_tournament_id
      and e.player_id=p_player_id
      and e.entry_method='wildcard'
  ) then
    return 2;
  end if;

  return 3;
end;
$function$;

CREATE OR REPLACE FUNCTION public.junior_doubles_team_acceptance_group(p_a bigint, p_b bigint, p_tournament_id bigint)
 RETURNS integer
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  sa int:=public.junior_doubles_player_acceptance_status(p_a,p_tournament_id);
  sb int:=public.junior_doubles_player_acceptance_status(p_b,p_tournament_id);
begin
  if sa=1 and sb=1 then return 1; end if;
  if least(sa,sb)=1 and greatest(sa,sb)=2 then return 2; end if;
  if least(sa,sb)=1 and greatest(sa,sb)=3 then return 3; end if;
  if sa=2 and sb=2 then return 4; end if;
  if least(sa,sb)=2 and greatest(sa,sb)=3 then return 5; end if;
  return 6;
end;
$function$;

CREATE OR REPLACE FUNCTION public.prepare_junior_doubles_reservations(p_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  v_draw int;
  v_wc int;
  v_direct int;
  v_pair_count int:=0;
  v_direct_count int:=0;
  v_wc_count int:=0;
  v_p1 bigint;
  v_partner bigint;
  v_group int;
  v_best_group int;
  v_combined int;
  v_best_combined int;
  v_strength int;
  v_best_strength int;
  v_host_pool boolean;
  rr record;
begin
  select * into t
  from public.tournaments
  where id=p_tournament_id
    and circuit='Junior'
    and doubles=true
    and coalesce(is_active,true)=true;

  if t.id is null then
    return jsonb_build_object('ok',false,'reason','not_active_junior_doubles');
  end if;

  if t.category in ('Junior Davis Cup','Junior Finals','Junior Double Finals') then
    return jsonb_build_object('ok',false,'reason','special_event');
  end if;

  v_draw:=greatest(8,least(64,coalesce(t.doubles_draw_size,16)));
  v_wc:=least(v_draw,public.junior_doubles_wildcards(v_draw));
  v_direct:=v_draw-v_wc;

  if exists(
    select 1 from public.junior_doubles_reservations
    where tournament_id=t.id
  ) then
    return jsonb_build_object(
      'ok',true,'already',true,
      'pairs',(select count(*) from public.junior_doubles_reservations where tournament_id=t.id),
      'direct_pairs',(select count(*) from public.junior_doubles_reservations where tournament_id=t.id and entry_method='direct'),
      'wildcard_pairs',(select count(*) from public.junior_doubles_reservations where tournament_id=t.id and entry_method='wildcard')
    );
  end if;

  drop table if exists pg_temp.cb_jdr_pool;
  create temporary table cb_jdr_pool(
    player_id bigint primary key,
    status_class int not null,
    rankv int not null,
    country text,
    pair_priority numeric not null
  ) on commit drop;

  insert into cb_jdr_pool(player_id,status_class,rankv,country,pair_priority)
  select p.id,
         public.junior_doubles_player_acceptance_status(p.id,t.id),
         coalesce(p.junior_ranking,999999),
         p.country,
         (
           greatest(0,2500-coalesce(p.junior_ranking,2500))*.08+
           coalesce(p.current_ability,50)*.70+
           coalesce(p.form,70)*.08+
           coalesce(pa.doubles,10)*.65+
           (mod(abs(hashtext('jdr-pool|'||t.id||'|'||p.id)),1000)::numeric/1000.0)*2
         )
  from public.players p
  left join public.player_attributes pa on pa.player_id=p.id
  where p.career_status='active'
    and p.injury_status='Fit'
    and coalesce(p.fitness,90)>=45
    and coalesce(p.fatigue,20)<=90
    and coalesce(p.career_focus,'mixed')<>'singles_only'
    and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
    and (
      p.birth_date is null
      or (
        p.birth_date<=t.start_date-interval '13 years'
        and extract(year from t.start_date)::int-extract(year from p.birth_date)::int<=18
      )
    )
    and (
      p.junior_ranking is not null
      or public.junior_doubles_player_acceptance_status(p.id,t.id)<=2
    )
    and not (public.player_tournament_calendar_conflict(p.id,t.id,'doubles')->>'conflict')::boolean
    and public.junior_player_commits_to_event(p.id,t.id,'doubles')
  order by 2,3,5 desc,p.id
  limit v_draw*8;

  -- Direct acceptances: acceptance groups 1-6 first, then combined ranking, then pair chemistry.
  while v_direct_count<v_direct and (select count(*) from cb_jdr_pool)>=2 loop
    select player_id into v_p1
    from cb_jdr_pool
    order by status_class,rankv,pair_priority desc,player_id
    limit 1;

    v_partner:=null;
    v_best_group:=999;
    v_best_combined:=99999999;
    v_best_strength:=-999999;

    for rr in
      select player_id,rankv
      from cb_jdr_pool
      where player_id<>v_p1
      order by status_class,rankv,pair_priority desc,player_id
      limit 50
    loop
      v_group:=public.junior_doubles_team_acceptance_group(v_p1,rr.player_id,t.id);
      select
        coalesce(a.junior_ranking,999999)+coalesce(b.junior_ranking,999999),
        coalesce(m.pair_strength,0)::int
      into v_combined,v_strength
      from public.players a
      join public.players b on b.id=rr.player_id
      left join lateral public.doubles_pair_metrics(v_p1,rr.player_id,t.start_date) m on true
      where a.id=v_p1
      limit 1;

      if v_group<v_best_group
         or (v_group=v_best_group and v_combined<v_best_combined)
         or (v_group=v_best_group and v_combined=v_best_combined and v_strength>v_best_strength) then
        v_partner:=rr.player_id;
        v_best_group:=v_group;
        v_best_combined:=v_combined;
        v_best_strength:=v_strength;
      end if;
    end loop;

    if v_partner is null then exit; end if;

    insert into public.junior_doubles_reservations(
      tournament_id,player_a_id,player_b_id,entry_method,acceptance_group,
      combined_rank,pair_strength,reserved_on
    ) values(
      t.id,least(v_p1,v_partner),greatest(v_p1,v_partner),'direct',
      v_best_group,v_best_combined,v_best_strength,
      coalesce(t.main_draw_start_date,t.start_date)
    )
    on conflict do nothing;

    delete from cb_jdr_pool where player_id in (v_p1,v_partner);
    v_direct_count:=v_direct_count+1;
  end loop;

  -- Doubles wild cards are extra to direct acceptances. Prefer host-nation pairs.
  while v_wc_count<v_wc and (select count(*) from cb_jdr_pool)>=2 loop
    select player_id into v_p1
    from cb_jdr_pool
    order by
      case when upper(coalesce(country,''))=upper(coalesce(t.country,'')) then 0 else 1 end,
      pair_priority desc,rankv,player_id
    limit 1;

    v_partner:=null;
    v_best_strength:=-999999;

    for rr in
      select player_id,country
      from cb_jdr_pool
      where player_id<>v_p1
      order by
        case when upper(coalesce(country,''))=upper(coalesce(t.country,'')) then 0 else 1 end,
        pair_priority desc,rankv,player_id
      limit 40
    loop
      select coalesce(m.pair_strength,0)::int
      into v_strength
      from public.doubles_pair_metrics(v_p1,rr.player_id,t.start_date) m
      limit 1;

      if v_partner is null or v_strength>v_best_strength then
        v_partner:=rr.player_id;
        v_best_strength:=v_strength;
      end if;
    end loop;

    if v_partner is null then exit; end if;

    select coalesce(a.junior_ranking,999999)+coalesce(b.junior_ranking,999999)
    into v_combined
    from public.players a,public.players b
    where a.id=v_p1 and b.id=v_partner;

    insert into public.junior_doubles_reservations(
      tournament_id,player_a_id,player_b_id,entry_method,acceptance_group,
      combined_rank,pair_strength,reserved_on
    ) values(
      t.id,least(v_p1,v_partner),greatest(v_p1,v_partner),'wildcard',
      99,v_combined,v_best_strength,
      coalesce(t.main_draw_start_date,t.start_date)
    )
    on conflict do nothing;

    delete from cb_jdr_pool where player_id in (v_p1,v_partner);
    v_wc_count:=v_wc_count+1;
  end loop;

  select count(*) into v_pair_count
  from public.junior_doubles_reservations
  where tournament_id=t.id;

  if v_pair_count<>v_draw then
    delete from public.junior_doubles_reservations where tournament_id=t.id;
    return jsonb_build_object(
      'ok',false,'reason','insufficient_pair_field',
      'pairs_built',v_pair_count,'draw',v_draw
    );
  end if;

  with seeded as (
    select tournament_id,player_a_id,player_b_id,
           row_number() over(
             order by
               case when entry_method='wildcard' then 1 else 0 end,
               combined_rank asc,
               pair_strength desc,
               player_a_id,player_b_id
           )::int rn
    from public.junior_doubles_reservations
    where tournament_id=t.id
  )
  update public.junior_doubles_reservations r
  set seed=s.rn,
      draw_slot=s.rn
  from seeded s
  where r.tournament_id=s.tournament_id
    and r.player_a_id=s.player_a_id
    and r.player_b_id=s.player_b_id;

  return jsonb_build_object(
    'ok',true,'pairs',v_pair_count,
    'direct_pairs',v_direct_count,'wildcard_pairs',v_wc_count,
    'draw',v_draw,
    'model','ITF Junior 2026 doubles acceptance groups + fixed sign-in partnerships'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.prepare_junior_doubles_window(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  rec record;
  r jsonb;
  prepared int:=0;
  skipped int:=0;
begin
  for rec in
    select t.*
    from public.tournaments t
    where t.circuit='Junior'
      and t.doubles=true
      and coalesce(t.is_active,true)=true
      and t.category not in ('Junior Davis Cup','Junior Finals','Junior Double Finals')
      and coalesce(t.doubles_draw_size,0)>=8
      and coalesce(t.main_draw_start_date,t.start_date)>p_from_date
      and coalesce(t.main_draw_start_date,t.start_date)<=p_to_date
    order by coalesce(t.main_draw_start_date,t.start_date),t.id
  loop
    r:=public.prepare_junior_doubles_reservations(rec.id);
    if coalesce((r->>'ok')::boolean,false) then prepared:=prepared+1;
    else skipped:=skipped+1;
    end if;
  end loop;

  return jsonb_build_object(
    'events_prepared',prepared,'events_skipped',skipped,
    'from',p_from_date,'to',p_to_date,
    'model','ITF Junior doubles sign-in reservation window v1'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.simulate_junior_world_doubles_full(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  v_managed bigint;
  v_draw int;
  v_pair_count int;
  v_p1 bigint;
  v_best_partner bigint;
  v_pair_strength int;
  v_best_strength int;
  v_size int;
  v_round int;
  v_pos int;
  v_next int;
  v_a bigint;
  v_b bigint;
  v_w bigint;
  v_l bigint;
  v_sa int;
  v_sb int;
  v_prob numeric;
  v_awon boolean;
  v_score text;
  v_code text;
  v_winner bigint;
  v_count int:=0;
  v_matches int:=0;
  rr record;
begin
  select managed_player_id into v_managed from public.career_state where id='demo';

  for t in
    select *
    from public.tournaments
    where circuit='Junior'
      and doubles=true
      and coalesce(is_active,true)=true
      and coalesce(end_date,start_date)>p_from_date
      and coalesce(end_date,start_date)<=p_to_date
      and category not in ('Junior Davis Cup','Junior Finals','Junior Double Finals')
      and coalesce(doubles_draw_size,0)>=8
      and not exists(select 1 from public.world_junior_doubles_entries e where e.tournament_id=tournaments.id)
    order by
      date_trunc('week',start_date::timestamp),
      case
        when category='Junior Grand Slam' then 100
        when category='J500' then 90
        when category='J300' then 80
        when category='J200' then 70
        when category='J100' then 60
        when category='J60' then 50
        when category='J30' then 40
        else 10 end desc,
      coalesce(end_date,start_date),id
    limit 100
  loop
    v_draw:=least(32,coalesce(t.doubles_draw_size,16));

    drop table if exists pg_temp.cb_jd_pool;
    drop table if exists pg_temp.cb_jd;
    create temporary table cb_jd_pool(
      player_id bigint primary key,
      rankv int
    ) on commit drop;
    create temporary table cb_jd(
      entry_no int generated always as identity primary key,
      player_a_id bigint not null,
      player_b_id bigint not null,
      strength int not null,
      combined_rank int not null default 1999998,
      seed int,
      draw_slot int
    ) on commit drop;

    perform public.prepare_junior_doubles_reservations(t.id);

    insert into cb_jd(
      player_a_id,player_b_id,strength,combined_rank,seed,draw_slot
    )
    select
      r.player_a_id,r.player_b_id,r.pair_strength,r.combined_rank,r.seed,r.draw_slot
    from public.junior_doubles_reservations r
    where r.tournament_id=t.id
    order by r.draw_slot,r.player_a_id,r.player_b_id;

    select count(*) into v_pair_count from cb_jd;
    if v_pair_count<>v_draw then
      continue;
    end if;

    with s as (
      select entry_no,
             row_number() over(
               order by combined_rank asc,strength desc,entry_no
             )::int rn
      from cb_jd
    )
    update cb_jd e
    set seed=s.rn,draw_slot=s.rn
    from s
    where e.entry_no=s.entry_no;

    delete from public.world_junior_doubles_matches where tournament_id=t.id;
    delete from public.world_junior_doubles_entries where tournament_id=t.id;

    insert into public.world_junior_doubles_entries(
      tournament_id,player_a_id,player_b_id,seed,draw_slot,simulated_on
    )
    select t.id,player_a_id,player_b_id,seed,draw_slot,t.end_date
    from cb_jd
    order by seed;

    drop table if exists pg_temp.cb_jd_current;
    drop table if exists pg_temp.cb_jd_next;
    create temporary table cb_jd_current(pos int primary key,entry_id bigint) on commit drop;
    create temporary table cb_jd_next(pos int primary key,entry_id bigint) on commit drop;

    insert into cb_jd_current(pos,entry_id)
    select draw_slot,id
    from public.world_junior_doubles_entries
    where tournament_id=t.id;

    v_size:=v_draw;
    v_round:=1;

    while v_size>1 loop
      truncate cb_jd_next;
      v_next:=0;
      v_code:=case
        when v_size>=32 then 'R32'
        when v_size>=16 then 'R16'
        when v_size>=8 then 'QF'
        when v_size>=4 then 'SF'
        else 'F' end;

      for v_pos in 1..v_size by 2 loop
        v_next:=v_next+1;
        select entry_id into v_a from cb_jd_current where pos=v_pos;
        select entry_id into v_b from cb_jd_current where pos=v_pos+1;

        select d.strength into v_sa
        from public.world_junior_doubles_entries e
        join cb_jd d on d.player_a_id=e.player_a_id and d.player_b_id=e.player_b_id
        where e.id=v_a;

        select d.strength into v_sb
        from public.world_junior_doubles_entries e
        join cb_jd d on d.player_a_id=e.player_a_id and d.player_b_id=e.player_b_id
        where e.id=v_b;

        v_prob:=greatest(.08,least(.92,1/(1+exp(-(coalesce(v_sa,50)-coalesce(v_sb,50))/8.0))));
        v_awon:=random()<v_prob;
        v_w:=case when v_awon then v_a else v_b end;
        v_l:=case when v_awon then v_b else v_a end;
        v_score:=public.world_tournament_score(v_prob,v_awon,3);

        insert into public.world_junior_doubles_matches(
          tournament_id,round_no,round_code,match_no,
          pair_a_entry_id,pair_b_entry_id,winner_entry_id,loser_entry_id,
          score,win_probability,simulated_on
        ) values(
          t.id,v_round,v_code,v_next,v_a,v_b,v_w,v_l,
          v_score,round(v_prob,4),t.end_date
        );
        v_matches:=v_matches+1;

        update public.world_junior_doubles_entries
        set result_code=v_code,
            points_awarded=public.junior_points_for('doubles',t.category,v_code),
            last_opponent=(
              select pa.name||' / '||pb.name
              from public.world_junior_doubles_entries oe
              join public.players pa on pa.id=oe.player_a_id
              join public.players pb on pb.id=oe.player_b_id
              where oe.id=v_w
            ),
            last_score=case when v_l=v_a then v_score else public.world_invert_tennis_score(v_score) end
        where id=v_l;

        update public.world_junior_doubles_entries
        set matches_won=matches_won+1
        where id=v_w;

        insert into cb_jd_next values(v_next,v_w);
      end loop;

      truncate cb_jd_current;
      insert into cb_jd_current select * from cb_jd_next;
      v_size:=v_size/2;
      v_round:=v_round+1;
    end loop;

    select entry_id into v_winner from cb_jd_current limit 1;

    update public.world_junior_doubles_entries
    set result_code='W',
        points_awarded=public.junior_points_for('doubles',t.category,'W')
    where id=v_winner;

    update public.players p
    set junior_doubles_game_points=coalesce(p.junior_doubles_game_points,0)+e.points_awarded
    from public.world_junior_doubles_entries e
    where e.tournament_id=t.id
      and p.id in (e.player_a_id,e.player_b_id);

    for rr in
      select e.*,a.name a_name,b.name b_name
      from public.world_junior_doubles_entries e
      join public.players a on a.id=e.player_a_id
      join public.players b on b.id=e.player_b_id
      where e.id=v_winner
    loop
      insert into public.player_titles(
        player_id,tournament_name,title_date,level,surface,event_type,
        partner_player_id,partner_name,verified,source_label,origin
      )
      values
        (rr.player_a_id,t.name,t.end_date,t.category,t.surface,'junior_doubles',rr.player_b_id,rr.b_name,false,'Court Boss junior doubles full draw','game'),
        (rr.player_b_id,t.name,t.end_date,t.category,t.surface,'junior_doubles',rr.player_a_id,rr.a_name,false,'Court Boss junior doubles full draw','game')
      on conflict(player_id,tournament_name,title_date,event_type) do nothing;
    end loop;

    v_count:=v_count+1;
  end loop;

  return jsonb_build_object(
    'doubles_simulated',v_count,'matches_simulated',v_matches,
    'from',p_from_date,'to',p_to_date,'model','CB-JUNIOR-DOUBLES-v3 fixed ITF-2026 sign-in partnerships'
  );
end
$function$;

CREATE OR REPLACE FUNCTION public.simulate_junior_world_tournaments(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  eligibility_before jsonb;
  s jsonb;
  d jsonb;
  jf jsonb;
  jdf jsonb;
  r1 jsonb;
  eligibility_after jsonb;
  r2 jsonb;
begin
  eligibility_before:=public.refresh_junior_current_eligibility(p_to_date);

  s:=public.simulate_junior_world_singles_full(p_from_date,p_to_date);
  d:=public.simulate_junior_world_doubles_full(p_from_date,p_to_date);
  jf:=public.simulate_junior_finals(p_from_date,p_to_date);
  jdf:=public.simulate_junior_doubles_finals(p_from_date,p_to_date);

  r1:=public.refresh_junior_display_pool_v3(2000);
  eligibility_after:=public.refresh_junior_current_eligibility(p_to_date);
  r2:=public.refresh_junior_doubles_ranking(p_to_date);

  return jsonb_build_object(
    'singles_simulated',coalesce((s->>'singles_simulated')::int,0),
    'doubles_simulated',coalesce((d->>'doubles_simulated')::int,0),
    'junior_finals_simulated',coalesce((jf->>'finals_simulated')::int,0),
    'junior_doubles_finals_simulated',coalesce((jdf->>'finals_simulated')::int,0),
    'matches_simulated',
      coalesce((s->>'matches_simulated')::int,0)
      +coalesce((d->>'matches_simulated')::int,0)
      +coalesce((jf->>'matches_simulated')::int,0)
      +coalesce((jdf->>'matches_simulated')::int,0),
    'singles',s,
    'doubles',d,
    'junior_finals',jf,
    'junior_doubles_finals',jdf,
    'eligibility_before',eligibility_before,
    'ranking_refresh',r1,
    'eligibility_after',eligibility_after,
    'doubles_ranking_refresh',r2,
    'from',p_from_date,
    'to',p_to_date
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.ncaa_individual_player_available(p_player_id bigint, p_tournament_id bigint)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null then return false; end if;

  if not exists(
    select 1 from public.players p
    where p.id=p_player_id
      and p.ncaa_current=true
      and p.career_status='active'
      and p.injury_status='Fit'
      and coalesce(p.fitness,90)>=45
  ) then return false; end if;

  if exists(
    select 1
    from public.players p
    join public.ncaa_team_event_entries te on te.team_id=p.ncaa_team_id
    join public.tournaments et on et.id=te.tournament_id
    where p.id=p_player_id
      and et.id<>t.id
      and daterange(et.start_date,coalesce(et.end_date,et.start_date),'[]')
          && daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
  ) then return false; end if;

  if exists(
    select 1
    from public.junior_entry_reservations jr
    join public.tournaments jt on jt.id=jr.tournament_id
    where jr.player_id=p_player_id
      and jt.id<>t.id
      and daterange(jt.start_date,coalesce(jt.end_date,jt.start_date),'[]')
          && daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
  ) then return false; end if;

  if exists(
    select 1
    from public.junior_doubles_reservations dr
    join public.tournaments dt on dt.id=dr.tournament_id
    where p_player_id in (dr.player_a_id,dr.player_b_id)
      and dt.id<>t.id
      and daterange(dt.start_date,coalesce(dt.end_date,dt.start_date),'[]')
          && daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
  ) then return false; end if;

  if exists(
    select 1
    from public.ncaa_individual_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where e.player_id=p_player_id
      and ot.id<>t.id
      and daterange(ot.start_date,coalesce(ot.end_date,ot.start_date),'[]')
          && daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
  ) then return false; end if;

  if exists(
    select 1
    from public.ncaa_individual_doubles_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where p_player_id in (e.player_a_id,e.player_b_id)
      and ot.id<>t.id
      and daterange(ot.start_date,coalesce(ot.end_date,ot.start_date),'[]')
          && daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
  ) then return false; end if;

  if exists(
    select 1
    from public.world_tournament_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where e.player_id=p_player_id
      and daterange(
            coalesce(ot.qualifying_start_date,ot.main_draw_start_date,ot.start_date),
            coalesce(ot.end_date,ot.start_date),'[]'
          ) && daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
  ) then return false; end if;

  if exists(
    select 1
    from public.world_tournament_qualifying_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where e.player_id=p_player_id
      and daterange(
            coalesce(ot.qualifying_start_date,ot.start_date),
            coalesce(ot.qualifying_end_date,ot.main_draw_start_date,ot.end_date,ot.start_date),'[]'
          ) && daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
  ) then return false; end if;

  if exists(
    select 1
    from public.world_doubles_tournament_entries e
    join public.world_doubles_partnerships wp on wp.id=e.pair_id
    join public.tournaments ot on ot.id=e.tournament_id
    where p_player_id in (wp.player_a_id,wp.player_b_id)
      and daterange(
            coalesce(ot.qualifying_start_date,ot.main_draw_start_date,ot.start_date),
            coalesce(ot.end_date,ot.start_date),'[]'
          ) && daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
  ) then return false; end if;

  if exists(
    select 1
    from public.davis_squad ds
    join public.davis_ties dt on ds.nation in (dt.home_nation,dt.away_nation)
    where ds.player_id=p_player_id
      and dt.status in ('scheduled','completed')
      and dt.tie_date between t.start_date and coalesce(t.end_date,t.start_date)
  ) then return false; end if;

  return true;
end;
$function$;

CREATE OR REPLACE FUNCTION public.ncaa_team_lineup(p_team_id bigint, p_date date)
 RETURNS bigint[]
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select coalesce(array_agg(id order by score desc,id),'{}'::bigint[])
  from (
    select p.id,
      coalesce(p.current_ability,50)
      +coalesce(p.form,70)*.11
      +coalesce(p.fitness,85)*.05
      -coalesce(p.fatigue,20)*.07
      +coalesce(us.current_rating,10)*1.8
      -coalesce(p.ncaa_rank,500)*.004 as score
    from public.players p
    left join public.player_utr_state us on us.player_id=p.id
    where p.ncaa_current=true
      and p.ncaa_team_id=p_team_id
      and p.career_status='active'
      and p.injury_status='Fit'
      and coalesce(p.fitness,90)>=45

      and not exists(
        select 1
        from public.davis_squad ds
        join public.davis_ties dt on ds.nation in (dt.home_nation,dt.away_nation)
        where ds.player_id=p.id
          and dt.status in ('scheduled','completed')
          and dt.tie_date=p_date
      )

      and not exists(
        select 1
        from public.world_tournament_entries we
        join public.tournaments et on et.id=we.tournament_id
        where we.player_id=p.id
          and daterange(
                coalesce(et.qualifying_start_date,et.main_draw_start_date,et.start_date),
                coalesce(et.end_date,et.start_date),'[]'
              ) && daterange(p_date,p_date,'[]')
      )

      and not exists(
        select 1
        from public.world_tournament_qualifying_entries qe
        join public.tournaments et on et.id=qe.tournament_id
        where qe.player_id=p.id
          and daterange(
                coalesce(et.qualifying_start_date,et.start_date),
                coalesce(et.qualifying_end_date,et.main_draw_start_date,et.end_date,et.start_date),'[]'
              ) && daterange(p_date,p_date,'[]')
      )

      and not exists(
        select 1
        from public.world_doubles_tournament_entries de
        join public.world_doubles_partnerships wp on wp.id=de.pair_id
        join public.tournaments et on et.id=de.tournament_id
        where p.id in (wp.player_a_id,wp.player_b_id)
          and daterange(
                coalesce(et.qualifying_start_date,et.main_draw_start_date,et.start_date),
                coalesce(et.end_date,et.start_date),'[]'
              ) && daterange(p_date,p_date,'[]')
      )

      and not exists(
        select 1
        from public.junior_entry_reservations jr
        join public.tournaments et on et.id=jr.tournament_id
        where jr.player_id=p.id
          and daterange(et.start_date,coalesce(et.end_date,et.start_date),'[]')
              && daterange(p_date,p_date,'[]')
      )

      and not exists(
        select 1
        from public.junior_doubles_reservations dr
        join public.tournaments et on et.id=dr.tournament_id
        where p.id in (dr.player_a_id,dr.player_b_id)
          and daterange(et.start_date,coalesce(et.end_date,et.start_date),'[]')
              && daterange(p_date,p_date,'[]')
      )

      and not exists(
        select 1
        from public.ncaa_individual_entries ie
        join public.tournaments et on et.id=ie.tournament_id
        where ie.player_id=p.id
          and daterange(et.start_date,coalesce(et.end_date,et.start_date),'[]')
              && daterange(p_date,p_date,'[]')
      )

      and not exists(
        select 1
        from public.ncaa_individual_doubles_entries ide
        join public.tournaments et on et.id=ide.tournament_id
        where p.id in (ide.player_a_id,ide.player_b_id)
          and daterange(et.start_date,coalesce(et.end_date,et.start_date),'[]')
              && daterange(p_date,p_date,'[]')
      )
    order by score desc,p.id
    limit 6
  ) x;
$function$;

CREATE OR REPLACE FUNCTION public.ncaa_team_doubles_lineup(p_team_id bigint, p_date date)
 RETURNS bigint[]
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select coalesce(array_agg(id order by score desc,id),'{}'::bigint[])
  from (
    select p.id,
      coalesce(p.current_ability,50)*.55
      +coalesce(pa.doubles,10)*1.65
      +coalesce(p.form,70)*.08
      +coalesce(p.fitness,85)*.04
      -coalesce(p.fatigue,20)*.06
      +coalesce(us.current_rating,10)*.8 as score
    from public.players p
    left join public.player_attributes pa on pa.player_id=p.id
    left join public.player_utr_state us on us.player_id=p.id
    where p.ncaa_current=true
      and p.ncaa_team_id=p_team_id
      and p.career_status='active'
      and p.injury_status='Fit'
      and coalesce(p.fitness,90)>=45
      and coalesce(p.career_focus,'mixed')<>'singles_only'

      and not exists(
        select 1
        from public.davis_squad ds
        join public.davis_ties dt on ds.nation in (dt.home_nation,dt.away_nation)
        where ds.player_id=p.id
          and dt.status in ('scheduled','completed')
          and dt.tie_date=p_date
      )

      and not exists(
        select 1
        from public.world_tournament_entries we
        join public.tournaments et on et.id=we.tournament_id
        where we.player_id=p.id
          and daterange(
                coalesce(et.qualifying_start_date,et.main_draw_start_date,et.start_date),
                coalesce(et.end_date,et.start_date),'[]'
              ) && daterange(p_date,p_date,'[]')
      )

      and not exists(
        select 1
        from public.world_tournament_qualifying_entries qe
        join public.tournaments et on et.id=qe.tournament_id
        where qe.player_id=p.id
          and daterange(
                coalesce(et.qualifying_start_date,et.start_date),
                coalesce(et.qualifying_end_date,et.main_draw_start_date,et.end_date,et.start_date),'[]'
              ) && daterange(p_date,p_date,'[]')
      )

      and not exists(
        select 1
        from public.world_doubles_tournament_entries de
        join public.world_doubles_partnerships wp on wp.id=de.pair_id
        join public.tournaments et on et.id=de.tournament_id
        where p.id in (wp.player_a_id,wp.player_b_id)
          and daterange(
                coalesce(et.qualifying_start_date,et.main_draw_start_date,et.start_date),
                coalesce(et.end_date,et.start_date),'[]'
              ) && daterange(p_date,p_date,'[]')
      )

      and not exists(
        select 1
        from public.junior_entry_reservations jr
        join public.tournaments et on et.id=jr.tournament_id
        where jr.player_id=p.id
          and daterange(et.start_date,coalesce(et.end_date,et.start_date),'[]')
              && daterange(p_date,p_date,'[]')
      )

      and not exists(
        select 1
        from public.junior_doubles_reservations dr
        join public.tournaments et on et.id=dr.tournament_id
        where p.id in (dr.player_a_id,dr.player_b_id)
          and daterange(et.start_date,coalesce(et.end_date,et.start_date),'[]')
              && daterange(p_date,p_date,'[]')
      )

      and not exists(
        select 1
        from public.ncaa_individual_entries ie
        join public.tournaments et on et.id=ie.tournament_id
        where ie.player_id=p.id
          and daterange(et.start_date,coalesce(et.end_date,et.start_date),'[]')
              && daterange(p_date,p_date,'[]')
      )

      and not exists(
        select 1
        from public.ncaa_individual_doubles_entries ide
        join public.tournaments et on et.id=ide.tournament_id
        where p.id in (ide.player_a_id,ide.player_b_id)
          and daterange(et.start_date,coalesce(et.end_date,et.start_date),'[]')
              && daterange(p_date,p_date,'[]')
      )
    order by score desc,p.id
    limit 6
  ) x;
$function$;

CREATE OR REPLACE FUNCTION public.player_has_world_event_in_week(p_player_id bigint, p_week_start date, p_exclude_tournament_id bigint DEFAULT NULL::bigint)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select exists(
    select 1
    from public.world_tournament_entries e
    join public.tournaments t on t.id=e.tournament_id
    where e.player_id=p_player_id
      and t.id is distinct from p_exclude_tournament_id
      and daterange(coalesce(t.qualifying_start_date,t.main_draw_start_date,t.start_date),coalesce(t.end_date,t.start_date),'[]')
          && daterange(p_week_start,p_week_start+6,'[]')
    union all
    select 1
    from public.world_tournament_qualifying_entries e
    join public.tournaments t on t.id=e.tournament_id
    where e.player_id=p_player_id
      and t.id is distinct from p_exclude_tournament_id
      and daterange(coalesce(t.qualifying_start_date,t.start_date),coalesce(t.qualifying_end_date,t.main_draw_start_date,t.end_date,t.start_date),'[]')
          && daterange(p_week_start,p_week_start+6,'[]')
    union all
    select 1
    from public.world_doubles_tournament_entries e
    join public.world_doubles_partnerships p on p.id=e.pair_id
    join public.tournaments t on t.id=e.tournament_id
    where p_player_id in (p.player_a_id,p.player_b_id)
      and t.id is distinct from p_exclude_tournament_id
      and daterange(coalesce(t.qualifying_start_date,t.main_draw_start_date,t.start_date),coalesce(t.end_date,t.start_date),'[]')
          && daterange(p_week_start,p_week_start+6,'[]')
    union all
    select 1
    from public.world_junior_doubles_entries e
    join public.tournaments t on t.id=e.tournament_id
    where p_player_id in (e.player_a_id,e.player_b_id)
      and t.id is distinct from p_exclude_tournament_id
      and daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
          && daterange(p_week_start,p_week_start+6,'[]')
    union all
    select 1
    from public.junior_entry_reservations jr
    join public.tournaments t on t.id=jr.tournament_id
    where jr.player_id=p_player_id
      and t.id is distinct from p_exclude_tournament_id
      and daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
          && daterange(p_week_start,p_week_start+6,'[]')
    union all
    select 1
    from public.junior_doubles_reservations dr
    join public.tournaments t on t.id=dr.tournament_id
    where p_player_id in (dr.player_a_id,dr.player_b_id)
      and t.id is distinct from p_exclude_tournament_id
      and daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
          && daterange(p_week_start,p_week_start+6,'[]')
    union all
    select 1
    from public.ncaa_individual_entries e
    join public.tournaments t on t.id=e.tournament_id
    where e.player_id=p_player_id
      and t.id is distinct from p_exclude_tournament_id
      and daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
          && daterange(p_week_start,p_week_start+6,'[]')
    union all
    select 1
    from public.ncaa_individual_doubles_entries e
    join public.tournaments t on t.id=e.tournament_id
    where p_player_id in (e.player_a_id,e.player_b_id)
      and t.id is distinct from p_exclude_tournament_id
      and daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
          && daterange(p_week_start,p_week_start+6,'[]')
    union all
    select 1
    from public.players pl
    join public.ncaa_team_event_entries te on te.team_id=pl.ncaa_team_id
    join public.tournaments t on t.id=te.tournament_id
    where pl.id=p_player_id
      and t.id is distinct from p_exclude_tournament_id
      and daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
          && daterange(p_week_start,p_week_start+6,'[]')
    union all
    select 1
    from public.junior_davis_squads s
    join public.tournaments t on t.id=s.tournament_id
    where s.player_id=p_player_id
      and t.id is distinct from p_exclude_tournament_id
      and daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
          && daterange(p_week_start,p_week_start+6,'[]')

    union all
    select 1
    from public.davis_squad ds
    join public.davis_ties dt on ds.nation in (dt.home_nation,dt.away_nation)
    where ds.player_id=p_player_id
      and dt.status in ('scheduled','completed')
      and dt.tie_date between p_week_start and p_week_start+6
    union all
    select 1
    from public.players pl
    join public.college_duals cd on pl.ncaa_team_id in (cd.home_team_id,cd.away_team_id)
    where pl.id=p_player_id
      and pl.ncaa_current=true
      and cd.status in ('scheduled','completed')
      and cd.match_date between p_week_start and p_week_start+6
  );
$function$;

CREATE OR REPLACE FUNCTION public.player_tournament_calendar_conflict(p_player_id bigint, p_tournament_id bigint, p_entry_method text DEFAULT 'direct'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  method text:=lower(coalesce(p_entry_method,'direct'));
  commit_start date;
  commit_end date;
  week_monday date;
  managed_id bigint;
  c record;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null then
    return jsonb_build_object('conflict',true,'reason','tournament_not_found');
  end if;

  select managed_player_id into managed_id from public.career_state where id='demo';

  week_monday:=date_trunc('week',coalesce(t.main_draw_start_date,t.start_date)::timestamp)::date;
  commit_start:=case
    when method in ('qualifying','qualifying_wildcard','protected_qualifying','doubles_qualifying')
      then coalesce(t.qualifying_start_date,t.main_draw_start_date,t.start_date)
    else coalesce(t.main_draw_start_date,t.start_date)
  end;
  commit_end:=coalesce(t.end_date,t.start_date);

  select et.id tournament_id,
         'Junior Davis Cup · '||s.nation tournament_name,
         et.start_date start_date,coalesce(et.end_date,et.start_date) end_date,
         'junior_national_team'::text discipline
  into c
  from public.junior_davis_squads s
  join public.tournaments et on et.id=s.tournament_id
  where s.player_id=p_player_id
    and et.id<>t.id
    and daterange(et.start_date,coalesce(et.end_date,et.start_date),'[]')
        && daterange(commit_start,commit_end,'[]')
  order by et.start_date,et.id
  limit 1;

  if c.tournament_id is not null then
    return jsonb_build_object(
      'conflict',true,'reason','junior_national_team_commitment',
      'other_tournament_id',c.tournament_id,'other_event',c.tournament_name,
      'other_discipline','junior_national_team'
    );
  end if;

  c:=null;
  select dt.id tournament_id,
         'Davis Cup · '||dt.home_nation||' v '||dt.away_nation tournament_name,
         dt.tie_date start_date,dt.tie_date end_date,'davis'::text discipline
  into c
  from public.davis_squad ds
  join public.davis_ties dt on ds.nation in (dt.home_nation,dt.away_nation)
  where ds.player_id=p_player_id
    and dt.status in ('scheduled','completed')
    and dt.tie_date between commit_start and commit_end
  order by dt.tie_date,dt.id
  limit 1;

  if c.tournament_id is not null then
    return jsonb_build_object(
      'conflict',true,'reason','national_team_commitment',
      'other_davis_tie_id',c.tournament_id,'other_event',c.tournament_name,
      'other_discipline','davis'
    );
  end if;

  c:=null;
  select cd.id tournament_id,
         'NCAA · '||h.name||' v '||a.name tournament_name,
         cd.match_date start_date,cd.match_date end_date,
         coalesce(cd.competition,'NCAA Division I')::text discipline
  into c
  from public.players pl
  join public.college_duals cd
    on cd.home_team_id=pl.ncaa_team_id or cd.away_team_id=pl.ncaa_team_id
  join public.college_teams h on h.id=cd.home_team_id
  join public.college_teams a on a.id=cd.away_team_id
  where pl.id=p_player_id
    and pl.ncaa_current=true
    and cd.status in ('scheduled','completed')
    and cd.match_date between commit_start and commit_end
    and (
      (
        coalesce(cd.competition,'NCAA Division I')<>'NCAA Division I'
        and not (t.circuit='ATP' and t.category='Grand Chelem')
      )
      or t.circuit not in ('ATP','Challenger','ITF','Junior')
    )
  order by cd.match_date,cd.id
  limit 1;

  if c.tournament_id is not null then
    return jsonb_build_object(
      'conflict',true,'reason','college_priority_commitment',
      'other_college_dual_id',c.tournament_id,'other_event',c.tournament_name,
      'other_discipline',c.discipline
    );
  end if;

  c:=null;
  select x.tournament_id,x.tournament_name,x.start_date,x.end_date,x.discipline
  into c
  from (
    select ot.id tournament_id,ot.name tournament_name,ot.start_date,ot.end_date,'singles'::text discipline
    from public.world_tournament_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where e.player_id=p_player_id and ot.id<>t.id
      and daterange(
            coalesce(ot.qualifying_start_date,ot.main_draw_start_date,ot.start_date),
            coalesce(ot.end_date,ot.start_date),'[]'
          ) && daterange(commit_start,commit_end,'[]')

    union all
    select ot.id,ot.name,ot.start_date,ot.end_date,'qualifying'
    from public.world_tournament_qualifying_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where e.player_id=p_player_id and ot.id<>t.id
      and daterange(
            coalesce(ot.qualifying_start_date,ot.start_date),
            coalesce(ot.qualifying_end_date,ot.main_draw_start_date,ot.end_date,ot.start_date),'[]'
          ) && daterange(commit_start,commit_end,'[]')

    union all
    select ot.id,ot.name,ot.start_date,ot.end_date,'doubles'
    from public.world_doubles_tournament_entries e
    join public.world_doubles_partnerships p on p.id=e.pair_id
    join public.tournaments ot on ot.id=e.tournament_id
    where p_player_id in (p.player_a_id,p.player_b_id) and ot.id<>t.id
      and daterange(
            coalesce(ot.qualifying_start_date,ot.main_draw_start_date,ot.start_date),
            coalesce(ot.end_date,ot.start_date),'[]'
          ) && daterange(commit_start,commit_end,'[]')

    union all
    select ot.id,ot.name,ot.start_date,ot.end_date,'junior_doubles'
    from public.world_junior_doubles_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where p_player_id in (e.player_a_id,e.player_b_id) and ot.id<>t.id
      and daterange(ot.start_date,coalesce(ot.end_date,ot.start_date),'[]')
          && daterange(commit_start,commit_end,'[]')

    union all
    select ot.id,ot.name,ot.start_date,ot.end_date,'junior_reserved'
    from public.junior_entry_reservations jr
    join public.tournaments ot on ot.id=jr.tournament_id
    where jr.player_id=p_player_id and ot.id<>t.id
      and daterange(ot.start_date,coalesce(ot.end_date,ot.start_date),'[]')
          && daterange(commit_start,commit_end,'[]')

    union all
    select ot.id,ot.name,ot.start_date,ot.end_date,'junior_doubles_reserved'
    from public.junior_doubles_reservations dr
    join public.tournaments ot on ot.id=dr.tournament_id
    where p_player_id in (dr.player_a_id,dr.player_b_id)
      and ot.id<>t.id
      and daterange(ot.start_date,coalesce(ot.end_date,ot.start_date),'[]')
          && daterange(commit_start,commit_end,'[]')

    union all
    select ot.id,ot.name,ot.start_date,ot.end_date,'ncaa_individual'
    from public.ncaa_individual_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where e.player_id=p_player_id and ot.id<>t.id
      and daterange(ot.start_date,coalesce(ot.end_date,ot.start_date),'[]')
          && daterange(commit_start,commit_end,'[]')

    union all
    select ot.id,ot.name,ot.start_date,ot.end_date,'ncaa_doubles'
    from public.ncaa_individual_doubles_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where p_player_id in (e.player_a_id,e.player_b_id) and ot.id<>t.id
      and daterange(ot.start_date,coalesce(ot.end_date,ot.start_date),'[]')
          && daterange(commit_start,commit_end,'[]')
  ) x
  order by x.start_date,x.tournament_id
  limit 1;

  if c.tournament_id is not null then
    return jsonb_build_object(
      'conflict',true,'reason','calendar_overlap',
      'other_tournament_id',c.tournament_id,'other_tournament',c.tournament_name,
      'other_discipline',c.discipline
    );
  end if;

  if managed_id is not null and p_player_id=managed_id then
    c:=null;
    select x.tournament_id,x.tournament_name,x.start_date,x.end_date,x.discipline
    into c
    from (
      select tr.tournament_id,ot.name tournament_name,ot.start_date,ot.end_date,'singles'::text discipline,
             coalesce(ot.qualifying_start_date,ot.main_draw_start_date,ot.start_date) event_start
      from public.tournament_runs tr
      join public.tournaments ot on ot.id=tr.tournament_id
      where tr.tournament_id<>t.id
      union all
      select dr.tournament_id,ot.name,ot.start_date,ot.end_date,'doubles',
             coalesce(ot.qualifying_start_date,ot.main_draw_start_date,ot.start_date)
      from public.doubles_runs dr
      join public.tournaments ot on ot.id=dr.tournament_id
      where dr.tournament_id<>t.id
    ) x
    where daterange(x.event_start,coalesce(x.end_date,x.start_date),'[]')
          && daterange(commit_start,commit_end,'[]')
    order by x.event_start
    limit 1;

    if c.tournament_id is not null then
      return jsonb_build_object(
        'conflict',true,'reason','calendar_overlap',
        'other_tournament_id',c.tournament_id,'other_tournament',c.tournament_name,
        'other_discipline',c.discipline
      );
    end if;
  end if;

  if method in ('qualifying','qualifying_wildcard','protected_qualifying','doubles_qualifying') then
    c:=null;
    select x.tournament_id,x.tournament_name,x.result_code,x.discipline
    into c
    from (
      select ot.id tournament_id,ot.name tournament_name,e.result_code,'singles'::text discipline,
             coalesce(ot.end_date,ot.start_date) event_end,
             coalesce(ot.main_draw_start_date,ot.start_date) main_start
      from public.world_tournament_entries e
      join public.tournaments ot on ot.id=e.tournament_id
      where e.player_id=p_player_id and ot.id<>t.id

      union all
      select ot.id,ot.name,e.result_code,'doubles',
             coalesce(ot.end_date,ot.start_date),
             coalesce(ot.main_draw_start_date,ot.start_date)
      from public.world_doubles_tournament_entries e
      join public.world_doubles_partnerships p on p.id=e.pair_id
      join public.tournaments ot on ot.id=e.tournament_id
      where p_player_id in (p.player_a_id,p.player_b_id) and ot.id<>t.id

      union all
      select ot.id,ot.name,e.result_code,'junior_doubles',
             coalesce(ot.end_date,ot.start_date),
             coalesce(ot.main_draw_start_date,ot.start_date)
      from public.world_junior_doubles_entries e
      join public.tournaments ot on ot.id=e.tournament_id
      where p_player_id in (e.player_a_id,e.player_b_id) and ot.id<>t.id
    ) x
    where x.event_end>=commit_start
      and x.main_start<week_monday
      and coalesce(x.result_code,'') in ('W','F','SF')
    order by x.event_end desc
    limit 1;

    if c.tournament_id is not null then
      return jsonb_build_object(
        'conflict',true,'reason','still_competing_before_qualifying',
        'other_tournament_id',c.tournament_id,'other_tournament',c.tournament_name,
        'other_result',c.result_code,'other_discipline',c.discipline,
        'qualifying_start',commit_start
      );
    end if;
  end if;

  return jsonb_build_object(
    'conflict',false,'reason','available',
    'commitment_start',commit_start,'commitment_end',commit_end,'week_monday',week_monday
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.ensure_world_doubles_partnership_team(p_season integer, p_player_one bigint, p_player_two bigint, p_date date, p_race_points integer DEFAULT 0, p_race_rank integer DEFAULT NULL::integer)
 RETURNS bigint
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  a bigint:=least(p_player_one,p_player_two);
  b bigint:=greatest(p_player_one,p_player_two);
  v_id bigint;
  m record;
begin
  if a is null or b is null or a=b then return null; end if;

  select id into v_id
  from public.world_doubles_partnerships
  where season=p_season and player_a_id=a and player_b_id=b;

  select * into m from public.doubles_pair_metrics(a,b,p_date) limit 1;

  if v_id is null then
    insert into public.world_doubles_partnerships(
      season,player_a_id,player_b_id,formed_date,last_refresh_date,
      active,chemistry,compatibility,pair_strength,affinity_score,
      race_points,race_rank,source,generation,matches,wins,titles
    ) values(
      p_season,a,b,p_date,p_date,true,
      coalesce(m.chemistry,60),coalesce(m.compatibility,60),
      coalesce(m.pair_strength,60),coalesce(m.affinity_score,60),
      greatest(0,coalesce(p_race_points,0)),p_race_rank,
      'ATP team race materialization',1,0,0,0
    )
    returning id into v_id;
  else
    update public.world_doubles_partnerships
    set active=true,
        last_refresh_date=p_date,
        chemistry=coalesce(m.chemistry,chemistry),
        compatibility=coalesce(m.compatibility,compatibility),
        pair_strength=coalesce(m.pair_strength,pair_strength),
        affinity_score=coalesce(m.affinity_score,affinity_score),
        race_points=greatest(coalesce(race_points,0),greatest(0,coalesce(p_race_points,0))),
        race_rank=coalesce(p_race_rank,race_rank)
    where id=v_id;
  end if;

  return v_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.prepare_atp_finals_doubles(p_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  v_year int;
  v_selection_date date;
  rec record;
  v_pair bigint;
  v_seed int:=0;
  v_selection_pos int:=0;
  v_gs_selected int:=0;
  v_used_players bigint[]:='{}'::bigint[];
  v_group text;
  v_roll int;
begin
  select * into t
  from public.tournaments
  where id=p_tournament_id and circuit='ATP' and category='ATP Finals' and doubles=true;

  if t.id is null then return jsonb_build_object('ok',false,'reason','not_atp_finals_doubles'); end if;

  if exists(select 1 from public.atp_finals_doubles_selection where tournament_id=t.id) then
    return jsonb_build_object(
      'ok',true,'already',true,
      'teams',(select count(*) from public.atp_finals_doubles_selection where tournament_id=t.id)
    );
  end if;

  v_year:=extract(year from t.start_date)::int;
  -- Monday after Paris; for a Sunday-start Finals this is six days before.
  v_selection_date:=t.start_date-6;

  drop table if exists pg_temp.cb_atp_finals_race;
  create temporary table cb_atp_finals_race(
    race_rank int,
    race_points int,
    p1 bigint,
    p2 bigint,
    gs_winner boolean,
    selection_tier int
  ) on commit drop;

  insert into cb_atp_finals_race(race_rank,race_points,p1,p2,gs_winner,selection_tier)
  select
    r.doubles_race_ranking,
    r.doubles_race_points,
    r.player_one_id,
    r.player_two_id,
    exists(
      select 1
      from public.world_doubles_tournament_simulations s
      join public.tournaments gs on gs.id=s.tournament_id
      join public.world_doubles_partnerships gp on gp.id=s.winner_pair_id
      where gs.category='Grand Chelem'
        and extract(year from gs.end_date)::int=v_year
        and least(gp.player_a_id,gp.player_b_id)=least(r.player_one_id,r.player_two_id)
        and greatest(gp.player_a_id,gp.player_b_id)=greatest(r.player_one_id,r.player_two_id)
    ),
    case
      when r.doubles_race_ranking<=7 then 1
      when r.doubles_race_ranking between 8 and 20
           and exists(
             select 1
             from public.world_doubles_tournament_simulations s
             join public.tournaments gs on gs.id=s.tournament_id
             join public.world_doubles_partnerships gp on gp.id=s.winner_pair_id
             where gs.category='Grand Chelem'
               and extract(year from gs.end_date)::int=v_year
               and least(gp.player_a_id,gp.player_b_id)=least(r.player_one_id,r.player_two_id)
               and greatest(gp.player_a_id,gp.player_b_id)=greatest(r.player_one_id,r.player_two_id)
           ) then 2
      else 3
    end
  from public.doubles_race_for_date(v_selection_date) r
  where r.player_one_id is not null and r.player_two_id is not null
  order by r.doubles_race_ranking
  limit 60;

  for rec in
    select *
    from cb_atp_finals_race
    order by selection_tier,race_rank
  loop
    exit when v_seed>=8;

    if rec.selection_tier=2 and v_gs_selected>=2 then continue; end if;

    -- One player cannot be a direct acceptance on two teams in the game world.
    if rec.p1=any(v_used_players) or rec.p2=any(v_used_players) then continue; end if;

    -- Treat an unavailable player at selection time as a withdrawal and move down list.
    if not exists(
      select 1 from public.players p
      where p.id=rec.p1 and p.career_status='active' and p.injury_status='Fit'
        and coalesce(p.fitness,90)>=35
    ) or not exists(
      select 1 from public.players p
      where p.id=rec.p2 and p.career_status='active' and p.injury_status='Fit'
        and coalesce(p.fitness,90)>=35
    ) then continue; end if;

    v_pair:=public.ensure_world_doubles_partnership_team(
      v_year,rec.p1,rec.p2,v_selection_date,rec.race_points,rec.race_rank
    );
    if v_pair is null then continue; end if;

    v_seed:=v_seed+1;
    v_selection_pos:=v_selection_pos+1;
    if rec.selection_tier=2 then v_gs_selected:=v_gs_selected+1; end if;

    if v_seed=1 then
      v_group:='A';
    elsif v_seed=2 then
      v_group:='B';
    else
      -- Seeds 3/4, 5/6 and 7/8 are drawn in pairs, one to each group.
      v_roll:=mod(abs(hashtext('atp-finals-group|'||t.id||'|'||((v_seed-3)/2)::int)),2);
      if mod(v_seed,2)=1 then
        v_group:=case when v_roll=0 then 'A' else 'B' end;
      else
        v_group:=case when v_roll=0 then 'B' else 'A' end;
      end if;
    end if;

    insert into public.atp_finals_doubles_selection(
      tournament_id,pair_id,seed,selection_position,race_rank,race_points,
      entry_reason,group_name,selected_on
    ) values(
      t.id,v_pair,v_seed,v_selection_pos,rec.race_rank,rec.race_points,
      case rec.selection_tier
        when 1 then 'top_7_team_race'
        when 2 then 'grand_slam_winner_rank_8_20'
        else 'next_team_on_selection_list' end,
      v_group,v_selection_date
    );

    v_used_players:=array_append(v_used_players,rec.p1);
    v_used_players:=array_append(v_used_players,rec.p2);
  end loop;

  if v_seed<>8 then
    delete from public.atp_finals_doubles_selection where tournament_id=t.id;
    return jsonb_build_object('ok',false,'reason','field_incomplete','teams',v_seed);
  end if;

  delete from public.world_doubles_tournament_entries where tournament_id=t.id;

  insert into public.world_doubles_tournament_entries(
    tournament_id,pair_id,seed,draw_slot,had_bye,matches_won,
    result_code,result_label,points_awarded,prize_awarded,
    simulated_on,source_label,entry_method
  )
  select
    tournament_id,pair_id,seed,seed,false,0,
    null,'ATP Finals · '||group_name,0,0,
    selected_on,
    'ATP 2026 selection list · top 7 + GS winner rule + next teams',
    'direct'
  from public.atp_finals_doubles_selection
  where tournament_id=t.id
  order by seed;

  return jsonb_build_object(
    'ok',true,'teams',8,'selection_date',v_selection_date,
    'grand_slam_rule_teams',v_gs_selected,
    'group_a',(select count(*) from public.atp_finals_doubles_selection where tournament_id=t.id and group_name='A'),
    'group_b',(select count(*) from public.atp_finals_doubles_selection where tournament_id=t.id and group_name='B')
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.atp_finals_doubles_play_match(p_tournament_id bigint, p_round_no integer, p_round_code text, p_group_name text, p_match_no integer, p_pair_a bigint, p_pair_b bigint, p_played_on date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  m jsonb;
  prob numeric;
  roll numeric;
  pattern_roll numeric;
  a_win boolean;
  w bigint;
  l bigint;
  score text;
  a_sets int;
  b_sets int;
  a_games int;
  b_games int;
  mtb boolean:=false;
  mid bigint;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null then return jsonb_build_object('ok',false,'reason','tournament_not_found'); end if;

  m:=public.doubles_pair_matchup_v2(p_pair_a,p_pair_b,t.surface,p_played_on);
  prob:=greatest(.05,least(.95,coalesce((m->>'pair_a_probability')::numeric,.5)));
  roll:=mod(abs(hashtext(
    'atp-finals-doubles-result|'||p_tournament_id||'|'||p_round_code||'|'||
    coalesce(p_group_name,'')||'|'||p_match_no||'|'||p_pair_a||'|'||p_pair_b
  )),10000)/10000.0;
  pattern_roll:=mod(abs(hashtext(
    'atp-finals-doubles-score|'||p_tournament_id||'|'||p_round_code||'|'||
    coalesce(p_group_name,'')||'|'||p_match_no||'|'||p_pair_a||'|'||p_pair_b
  )),10000)/10000.0;

  a_win:=roll<prob;
  w:=case when a_win then p_pair_a else p_pair_b end;
  l:=case when a_win then p_pair_b else p_pair_a end;

  if abs(prob-.5)<.16 or pattern_roll<.38 then
    mtb:=true;
    if a_win then
      if pattern_roll<.50 then
        score:='6-4 3-6 [10-7]'; a_sets:=2;b_sets:=1;a_games:=10;b_games:=10;
      else
        score:='4-6 7-6 [10-8]'; a_sets:=2;b_sets:=1;a_games:=12;b_games:=12;
      end if;
      -- ATP standings: winning Match Tie-Break counts as one game won.
      a_games:=a_games+1;
    else
      if pattern_roll<.50 then
        score:='4-6 6-3 [7-10]'; a_sets:=1;b_sets:=2;a_games:=10;b_games:=10;
      else
        score:='6-7 6-4 [8-10]'; a_sets:=1;b_sets:=2;a_games:=12;b_games:=12;
      end if;
      b_games:=b_games+1;
    end if;
  else
    if a_win then
      if prob>.70 then score:='6-3 6-4';a_games:=12;b_games:=7;
      else score:='7-6 6-4';a_games:=13;b_games:=10; end if;
      a_sets:=2;b_sets:=0;
    else
      if prob<.30 then score:='3-6 4-6';a_games:=7;b_games:=12;
      else score:='6-7 4-6';a_games:=10;b_games:=13; end if;
      a_sets:=0;b_sets:=2;
    end if;
  end if;

  insert into public.world_doubles_tournament_matches(
    tournament_id,round_no,round_code,group_name,match_no,
    pair_a_id,pair_b_id,winner_pair_id,loser_pair_id,score,
    pair_a_win_probability,model_version,matchup_components,simulated_on,is_qualifying
  ) values(
    t.id,p_round_no,p_round_code,p_group_name,p_match_no,
    p_pair_a,p_pair_b,w,l,score,round(prob,4),
    'CB-ATP-FINALS-DOUBLES-v1',
    coalesce(m->'components','{}'::jsonb),
    p_played_on,false
  )
  returning id into mid;

  insert into public.atp_finals_doubles_match_stats(
    match_id,pair_a_sets,pair_b_sets,pair_a_games,pair_b_games,match_tiebreak
  ) values(mid,a_sets,b_sets,a_games,b_games,mtb);

  update public.world_doubles_partnerships
  set matches=matches+1,
      wins=wins+case when id=w then 1 else 0 end,
      last_refresh_date=p_played_on
  where id in (p_pair_a,p_pair_b);

  update public.players p
  set fatigue=least(100,coalesce(p.fatigue,20)+3),
      fitness=greatest(35,coalesce(p.fitness,90)-1),
      form=greatest(1,least(100,coalesce(p.form,70)+
        case when p.id in (
          select player_a_id from public.world_doubles_partnerships where id=w
          union
          select player_b_id from public.world_doubles_partnerships where id=w
        ) then 1 else -1 end))
  where p.id in (
    select player_a_id from public.world_doubles_partnerships where id in (p_pair_a,p_pair_b)
    union
    select player_b_id from public.world_doubles_partnerships where id in (p_pair_a,p_pair_b)
  );

  return jsonb_build_object(
    'ok',true,'match_id',mid,'winner_pair_id',w,'loser_pair_id',l,
    'pair_a_probability',round(prob,4),'score',score,
    'pair_a_sets',a_sets,'pair_b_sets',b_sets,
    'pair_a_games',a_games,'pair_b_games',b_games,'match_tiebreak',mtb
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.atp_finals_doubles_group_standings(p_tournament_id bigint, p_group_name text)
 RETURNS TABLE(pair_id bigint, group_position integer, wins integer, matches_played integer, set_pct numeric, game_pct numeric, seed integer)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
with field as (
  select s.pair_id,s.seed
  from public.atp_finals_doubles_selection s
  where s.tournament_id=p_tournament_id and s.group_name=p_group_name
),
base as (
  select
    f.pair_id,f.seed,
    count(m.id)::int matches_played,
    count(m.id) filter(where m.winner_pair_id=f.pair_id)::int wins,
    coalesce(sum(
      case when m.pair_a_id=f.pair_id then st.pair_a_sets
           when m.pair_b_id=f.pair_id then st.pair_b_sets else 0 end
    ),0)::int sets_won,
    coalesce(sum(
      case when m.pair_a_id=f.pair_id then st.pair_b_sets
           when m.pair_b_id=f.pair_id then st.pair_a_sets else 0 end
    ),0)::int sets_lost,
    coalesce(sum(
      case when m.pair_a_id=f.pair_id then st.pair_a_games
           when m.pair_b_id=f.pair_id then st.pair_b_games else 0 end
    ),0)::int games_won,
    coalesce(sum(
      case when m.pair_a_id=f.pair_id then st.pair_b_games
           when m.pair_b_id=f.pair_id then st.pair_a_games else 0 end
    ),0)::int games_lost
  from field f
  left join public.world_doubles_tournament_matches m
    on m.tournament_id=p_tournament_id
   and m.round_code='RR'
   and m.group_name=p_group_name
   and f.pair_id in (m.pair_a_id,m.pair_b_id)
  left join public.atp_finals_doubles_match_stats st on st.match_id=m.id
  group by f.pair_id,f.seed
),
pct as (
  select b.*,
    case when b.sets_won+b.sets_lost>0
         then b.sets_won::numeric/(b.sets_won+b.sets_lost) else 0 end set_pct,
    case when b.games_won+b.games_lost>0
         then b.games_won::numeric/(b.games_won+b.games_lost) else 0 end game_pct,
    count(*) over(partition by b.wins,b.matches_played)::int primary_tie_count
  from base b
),
with_h2h as (
  select p.*,
    coalesce((
      select case when m.winner_pair_id=p.pair_id then 1 else 0 end
      from public.world_doubles_tournament_matches m
      join pct o on o.pair_id<>p.pair_id
        and o.wins=p.wins
        and o.matches_played=p.matches_played
      where m.tournament_id=p_tournament_id
        and m.round_code='RR'
        and m.group_name=p_group_name
        and p.pair_id in (m.pair_a_id,m.pair_b_id)
        and o.pair_id in (m.pair_a_id,m.pair_b_id)
      limit 1
    ),0)::int h2h_primary
  from pct p
),
metric_ties as (
  select h.*,
    count(*) over(
      partition by h.wins,h.matches_played,
                   round(h.set_pct,8),round(h.game_pct,8)
    )::int metric_tie_count
  from with_h2h h
),
ranked as (
  select m.*,
    coalesce((
      select case when x.winner_pair_id=m.pair_id then 1 else 0 end
      from public.world_doubles_tournament_matches x
      join metric_ties o on o.pair_id<>m.pair_id
        and o.wins=m.wins
        and o.matches_played=m.matches_played
        and round(o.set_pct,8)=round(m.set_pct,8)
        and round(o.game_pct,8)=round(m.game_pct,8)
      where x.tournament_id=p_tournament_id
        and x.round_code='RR'
        and x.group_name=p_group_name
        and m.pair_id in (x.pair_a_id,x.pair_b_id)
        and o.pair_id in (x.pair_a_id,x.pair_b_id)
      limit 1
    ),0)::int h2h_metric
  from metric_ties m
),
ordered as (
  select r.*,
    row_number() over(
      order by
        wins desc,
        matches_played desc,
        case when primary_tie_count=2 then h2h_primary else 0 end desc,
        case when primary_tie_count>=3 then set_pct else 0 end desc,
        case when primary_tie_count>=3 then game_pct else 0 end desc,
        case when metric_tie_count=2 then h2h_metric else 0 end desc,
        seed asc
    )::int group_position
  from ranked r
)
select pair_id,group_position,wins,matches_played,
       round(set_pct,6),round(game_pct,6),seed
from ordered
order by group_position;
$function$;

CREATE OR REPLACE FUNCTION public.simulate_atp_finals_doubles(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  prep jsonb;
  g text;
  pairs bigint[];
  i int;
  a_idx int[]:=array[1,2,1,4,1,3];
  b_idx int[]:=array[4,3,3,2,2,4];
  round_idx int;
  day_offset int;
  match_no int:=0;
  m jsonb;
  w bigint;
  l bigint;
  a1 bigint;a2 bigint;b1 bigint;b2 bigint;
  sf1w bigint;sf1l bigint;sf2w bigint;sf2l bigint;
  champion bigint;
  finalist bigint;
  final_match jsonb;
  v_year int;
  v_winner_points int;
  v_finalist_points int;
  rec record;
begin
  select * into t
  from public.tournaments
  where circuit='ATP'
    and category='ATP Finals'
    and doubles=true
    and coalesce(is_active,true)=true
    and coalesce(end_date,start_date)>p_from_date
    and coalesce(end_date,start_date)<=p_to_date
  order by start_date
  limit 1;

  if t.id is null then
    return jsonb_build_object('events_simulated',0,'active_event',false);
  end if;

  if exists(
    select 1 from public.world_doubles_tournament_simulations s
    where s.tournament_id=t.id
  ) then
    return jsonb_build_object(
      'events_simulated',0,'already_simulated',true,'tournament_id',t.id
    );
  end if;

  prep:=public.prepare_atp_finals_doubles(t.id);
  if coalesce((prep->>'ok')::boolean,false)=false then
    return jsonb_build_object('events_simulated',0,'tournament_id',t.id,'preparation',prep);
  end if;

  v_year:=extract(year from t.start_date)::int;

  delete from public.world_doubles_tournament_matches
  where tournament_id=t.id and is_qualifying=false;

  update public.world_doubles_tournament_entries
  set matches_won=0,result_code=null,
      result_label='ATP Finals · phase de groupes',
      points_awarded=0,prize_awarded=0,
      last_opponent_pair_id=null,last_score=null,
      simulated_on=t.start_date
  where tournament_id=t.id;

  -- Two groups of four. Group A plays days 0/2/4, Group B days 1/3/5.
  foreach g in array array['A','B'] loop
    select array_agg(pair_id order by seed)
    into pairs
    from public.atp_finals_doubles_selection
    where tournament_id=t.id and group_name=g;

    if coalesce(array_length(pairs,1),0)<>4 then
      return jsonb_build_object('events_simulated',0,'reason','invalid_group','group',g);
    end if;

    for i in 1..6 loop
      round_idx:=((i-1)/2)+1;
      day_offset:=case when g='A' then (round_idx-1)*2 else (round_idx-1)*2+1 end;
      match_no:=match_no+1;

      m:=public.atp_finals_doubles_play_match(
        t.id,round_idx,'RR',g,match_no,
        pairs[a_idx[i]],pairs[b_idx[i]],
        least(coalesce(t.end_date,t.start_date+7),t.start_date+day_offset)
      );
      w:=(m->>'winner_pair_id')::bigint;
      l:=(m->>'loser_pair_id')::bigint;

      update public.world_doubles_tournament_entries
      set matches_won=matches_won+1,
          points_awarded=points_awarded+200,
          last_opponent_pair_id=l,
          last_score=m->>'score'
      where tournament_id=t.id and pair_id=w;

      update public.world_doubles_tournament_entries
      set last_opponent_pair_id=w,
          last_score=m->>'score'
      where tournament_id=t.id and pair_id=l;
    end loop;
  end loop;

  -- Store group finishing position for teams that do not advance.
  for rec in
    select s.pair_id,s.group_name,s.group_position
    from (
      select 'A'::text group_name,x.*
      from public.atp_finals_doubles_group_standings(t.id,'A') x
      union all
      select 'B'::text group_name,x.*
      from public.atp_finals_doubles_group_standings(t.id,'B') x
    ) s
  loop
    if rec.group_position>2 then
      update public.world_doubles_tournament_entries
      set result_code='RR',
          result_label='Phase de groupes · '||rec.group_position||'e groupe '||rec.group_name
      where tournament_id=t.id and pair_id=rec.pair_id;
    end if;
  end loop;

  select pair_id into a1
  from public.atp_finals_doubles_group_standings(t.id,'A')
  where group_position=1;
  select pair_id into a2
  from public.atp_finals_doubles_group_standings(t.id,'A')
  where group_position=2;
  select pair_id into b1
  from public.atp_finals_doubles_group_standings(t.id,'B')
  where group_position=1;
  select pair_id into b2
  from public.atp_finals_doubles_group_standings(t.id,'B')
  where group_position=2;

  -- Semifinal: group winner vs opposite-group runner-up.
  match_no:=match_no+1;
  m:=public.atp_finals_doubles_play_match(
    t.id,4,'SF',null,match_no,a1,b2,
    least(coalesce(t.end_date,t.start_date+7),t.start_date+6)
  );
  sf1w:=(m->>'winner_pair_id')::bigint;
  sf1l:=(m->>'loser_pair_id')::bigint;

  update public.world_doubles_tournament_entries
  set matches_won=matches_won+1,
      points_awarded=points_awarded+400,
      last_opponent_pair_id=sf1l,last_score=m->>'score'
  where tournament_id=t.id and pair_id=sf1w;
  update public.world_doubles_tournament_entries
  set result_code='SF',result_label='Demi-finale',
      last_opponent_pair_id=sf1w,last_score=m->>'score'
  where tournament_id=t.id and pair_id=sf1l;

  match_no:=match_no+1;
  m:=public.atp_finals_doubles_play_match(
    t.id,4,'SF',null,match_no,b1,a2,
    least(coalesce(t.end_date,t.start_date+7),t.start_date+6)
  );
  sf2w:=(m->>'winner_pair_id')::bigint;
  sf2l:=(m->>'loser_pair_id')::bigint;

  update public.world_doubles_tournament_entries
  set matches_won=matches_won+1,
      points_awarded=points_awarded+400,
      last_opponent_pair_id=sf2l,last_score=m->>'score'
  where tournament_id=t.id and pair_id=sf2w;
  update public.world_doubles_tournament_entries
  set result_code='SF',result_label='Demi-finale',
      last_opponent_pair_id=sf2w,last_score=m->>'score'
  where tournament_id=t.id and pair_id=sf2l;

  -- Final.
  match_no:=match_no+1;
  final_match:=public.atp_finals_doubles_play_match(
    t.id,5,'F',null,match_no,sf1w,sf2w,
    coalesce(t.end_date,t.start_date+7)
  );
  champion:=(final_match->>'winner_pair_id')::bigint;
  finalist:=(final_match->>'loser_pair_id')::bigint;

  update public.world_doubles_tournament_entries
  set matches_won=matches_won+1,
      points_awarded=points_awarded+500,
      result_code='W',result_label='Vainqueur',
      last_opponent_pair_id=finalist,last_score=final_match->>'score',
      simulated_on=coalesce(t.end_date,t.start_date+7)
  where tournament_id=t.id and pair_id=champion;

  update public.world_doubles_tournament_entries
  set result_code='F',result_label='Finaliste',
      last_opponent_pair_id=champion,last_score=final_match->>'score',
      simulated_on=coalesce(t.end_date,t.start_date+7)
  where tournament_id=t.id and pair_id=finalist;

  update public.world_doubles_tournament_entries
  set simulated_on=coalesce(t.end_date,t.start_date+7)
  where tournament_id=t.id;

  -- Ranking points are awarded to both players on each team.
  insert into public.world_doubles_ranking_points(
    player_id,tournament_id,pair_id,label,earned_date,expiry_date,
    points,active,source_label
  )
  select w.player_a_id,t.id,e.pair_id,t.name||' · '||coalesce(e.result_code,'RR'),
         coalesce(t.end_date,t.start_date),coalesce(t.end_date,t.start_date)+364,
         e.points_awarded,true,'ATP Finals doubles · RR 200 / SF 400 / F 500'
  from public.world_doubles_tournament_entries e
  join public.world_doubles_partnerships w on w.id=e.pair_id
  where e.tournament_id=t.id and e.points_awarded>0
  on conflict(player_id,tournament_id) do update set
    pair_id=excluded.pair_id,label=excluded.label,earned_date=excluded.earned_date,
    expiry_date=excluded.expiry_date,points=excluded.points,
    active=true,source_label=excluded.source_label;

  insert into public.world_doubles_ranking_points(
    player_id,tournament_id,pair_id,label,earned_date,expiry_date,
    points,active,source_label
  )
  select w.player_b_id,t.id,e.pair_id,t.name||' · '||coalesce(e.result_code,'RR'),
         coalesce(t.end_date,t.start_date),coalesce(t.end_date,t.start_date)+364,
         e.points_awarded,true,'ATP Finals doubles · RR 200 / SF 400 / F 500'
  from public.world_doubles_tournament_entries e
  join public.world_doubles_partnerships w on w.id=e.pair_id
  where e.tournament_id=t.id and e.points_awarded>0
  on conflict(player_id,tournament_id) do update set
    pair_id=excluded.pair_id,label=excluded.label,earned_date=excluded.earned_date,
    expiry_date=excluded.expiry_date,points=excluded.points,
    active=true,source_label=excluded.source_label;

  update public.world_doubles_partnerships w
  set race_points=w.race_points+e.points_awarded,
      titles=w.titles+case when e.pair_id=champion then 1 else 0 end,
      last_refresh_date=greatest(w.last_refresh_date,coalesce(t.end_date,t.start_date))
  from public.world_doubles_tournament_entries e
  where e.tournament_id=t.id and w.id=e.pair_id;

  -- Champion title for both players.
  for rec in
    select w.player_a_id,w.player_b_id,a.name a_name,b.name b_name
    from public.world_doubles_partnerships w
    join public.players a on a.id=w.player_a_id
    join public.players b on b.id=w.player_b_id
    where w.id=champion
  loop
    insert into public.player_titles(
      player_id,tournament_name,title_date,level,surface,event_type,
      partner_player_id,partner_name,verified,source_label,origin
    ) values
      (rec.player_a_id,t.name,coalesce(t.end_date,t.start_date),t.category,t.surface,
       'doubles',rec.player_b_id,rec.b_name,false,'Court Boss ATP Finals doubles','game'),
      (rec.player_b_id,t.name,coalesce(t.end_date,t.start_date),t.category,t.surface,
       'doubles',rec.player_a_id,rec.a_name,false,'Court Boss ATP Finals doubles','game')
    on conflict(player_id,tournament_name,title_date,event_type) do nothing;
  end loop;

  select points_awarded into v_winner_points
  from public.world_doubles_tournament_entries
  where tournament_id=t.id and pair_id=champion;
  select points_awarded into v_finalist_points
  from public.world_doubles_tournament_entries
  where tournament_id=t.id and pair_id=finalist;

  insert into public.world_doubles_tournament_simulations(
    tournament_id,season,winner_pair_id,finalist_pair_id,
    winner_points,finalist_points,draw_size,simulated_on,source,
    final_win_probability,model_version,matchup_components
  )
  select
    t.id,v_year,champion,finalist,
    v_winner_points,v_finalist_points,8,coalesce(t.end_date,t.start_date),
    'ATP 2026 Nitto Finals doubles · official 8-team RR + SF/F format',
    case when m.winner_pair_id=m.pair_a_id
         then m.pair_a_win_probability else 1-m.pair_a_win_probability end,
    'CB-ATP-FINALS-DOUBLES-v1',
    m.matchup_components
  from public.world_doubles_tournament_matches m
  where m.tournament_id=t.id and m.round_code='F'
  order by m.id desc limit 1;

  perform public.refresh_world_doubles_player_rankings(p_to_date);

  return jsonb_build_object(
    'events_simulated',1,
    'tournament_id',t.id,
    'teams',8,
    'round_robin_matches',12,
    'semifinals',2,
    'finals',1,
    'matches_simulated',15,
    'winner_pair_id',champion,
    'finalist_pair_id',finalist,
    'winner_points',v_winner_points,
    'finalist_points',v_finalist_points,
    'preparation',prep,
    'model','ATP Finals doubles v1 · official 2026 selection + RR tiebreaks + SF/F'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.prepare_atp_finals_doubles_window(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  selection_date date;
  r jsonb;
begin
  select * into t
  from public.tournaments
  where circuit='ATP'
    and category='ATP Finals'
    and doubles=true
    and coalesce(is_active,true)=true
    and extract(year from start_date)::int=extract(year from p_to_date)::int
  order by start_date
  limit 1;

  if t.id is null then
    return jsonb_build_object('events_prepared',0,'active_event',false);
  end if;

  selection_date:=t.start_date-6;

  if selection_date>p_from_date and selection_date<=p_to_date then
    r:=public.prepare_atp_finals_doubles(t.id);
    return jsonb_build_object(
      'events_prepared',case when coalesce((r->>'ok')::boolean,false) then 1 else 0 end,
      'tournament_id',t.id,'selection_date',selection_date,'preparation',r
    );
  end if;

  -- Recovery path for a save advanced past selection Monday.
  if p_to_date>=selection_date
     and not exists(select 1 from public.atp_finals_doubles_selection where tournament_id=t.id) then
    r:=public.prepare_atp_finals_doubles(t.id);
    return jsonb_build_object(
      'events_prepared',case when coalesce((r->>'ok')::boolean,false) then 1 else 0 end,
      'tournament_id',t.id,'selection_date',selection_date,'recovered',true,'preparation',r
    );
  end if;

  return jsonb_build_object(
    'events_prepared',0,'tournament_id',t.id,'selection_date',selection_date
  );
end;
$function$;

