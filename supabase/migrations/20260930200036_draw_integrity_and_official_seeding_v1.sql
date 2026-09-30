-- Court Boss draw integrity v1
-- DB migration version: 20260930200036
-- Official-style seed placement and draw coherence across pro doubles, junior doubles and NCAA.

alter table public.ncaa_individual_doubles_entries
  add column if not exists draw_position integer;

create unique index if not exists ux_ncaa_individual_singles_draw_position
on public.ncaa_individual_entries(tournament_id,draw_position)
where discipline='singles' and draw_position is not null;

create unique index if not exists ux_ncaa_individual_doubles_draw_position
on public.ncaa_individual_doubles_entries(tournament_id,draw_position)
where draw_position is not null;

CREATE OR REPLACE FUNCTION public.player_doubles_seed_rank_at_date(p_player_id bigint, p_date date)
 RETURNS integer
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select coalesce(
    (
      select h.ranking
      from public.doubles_ranking_history h
      where h.player_id=p_player_id
        and h.snapshot_date<=coalesce(p_date,current_date)
        and h.ranking is not null
      order by h.snapshot_date desc
      limit 1
    ),
    (
      select p.doubles_ranking
      from public.players p
      where p.id=p_player_id
    ),
    999999
  )::integer
$function$;

CREATE OR REPLACE FUNCTION public.player_doubles_seed_points_at_date(p_player_id bigint, p_date date)
 RETURNS integer
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select coalesce(
    (
      select h.points
      from public.doubles_ranking_history h
      where h.player_id=p_player_id
        and h.snapshot_date<=coalesce(p_date,current_date)
      order by h.snapshot_date desc
      limit 1
    ),
    0
  )::integer
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
    v_wc_count:=case
      when t.circuit='ATP' and t.category in ('ATP 250','ATP 500') then 2
      when t.circuit='ATP' and t.category='Masters 1000' then
        case when v_draw in (28,32) then 3 when v_draw=24 then 2 else 0 end
      when t.circuit='Challenger' then 2
      else 0 end;
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

    insert into cb_d_entries(pair_id,score)
    select w.id,
      (
        w.pair_strength*.34+w.chemistry*.17+w.compatibility*.14+w.affinity_score*.05+
        greatest(0,2200-coalesce(a.doubles_ranking,2200))*.005+
        greatest(0,2200-coalesce(b.doubles_ranking,2200))*.005+
        coalesce(pa.doubles,10)*.20+coalesce(pb.doubles,10)*.20+
        coalesce(public.player_psychology_modifier(a.id),0)*.30+
        coalesce(public.player_psychology_modifier(b.id),0)*.30+
        (mod(abs(hashtext('dentry|'||t.id::text||'|'||w.id::text)),1000)/1000.0)*3
      )::numeric
    from public.world_doubles_partnerships w
    join public.players a on a.id=w.player_a_id
    join public.players b on b.id=w.player_b_id
    left join public.player_attributes pa on pa.player_id=a.id
    left join public.player_attributes pb on pb.player_id=b.id
    where w.season=v_year and w.active=true
      and a.career_status='active' and b.career_status='active'
      and a.id<>coalesce(v_managed,-1) and b.id<>coalesce(v_managed,-1)
      and coalesce(a.career_focus,'mixed')<>'singles_only'
      and coalesce(b.career_focus,'mixed')<>'singles_only'
      and a.injury_status='Fit' and b.injury_status='Fit'
      and coalesce(a.fitness,90)>=48 and coalesce(b.fitness,90)>=48
      and coalesce(a.fatigue,20)<=88 and coalesce(b.fatigue,20)<=88
      and not (public.player_tournament_calendar_conflict(a.id,t.id,'doubles')->>'conflict')::boolean
      and not (public.player_tournament_calendar_conflict(b.id,t.id,'doubles')->>'conflict')::boolean
      and public.ai_player_commits_to_doubles_tournament(a.id,t.id)
      and public.ai_player_commits_to_doubles_tournament(b.id,t.id)
    order by
      case
        when t.circuit in ('ATP','Challenger') then
          public.player_doubles_entry_rank(a.id,coalesce(t.doubles_entry_deadline,t.start_date))
          +public.player_doubles_entry_rank(b.id,coalesce(t.doubles_entry_deadline,t.start_date))
        else 0
      end asc,
      case
        when t.circuit in ('ATP','Challenger') then
          (
            (case when a.doubles_ranking is not null
                        and a.doubles_ranking<=coalesce(a.ranking,999999) then 1 else 0 end)
            +(case when b.doubles_ranking is not null
                        and b.doubles_ranking<=coalesce(b.ranking,999999) then 1 else 0 end)
          )
        else 0
      end desc,
      2 desc,w.id
    limit v_pool_needed;

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
      -- ATP 500 doubles qualifying: 4 teams, 3 direct + 1 WC, one team qualifies.
      with ranked as (
        select pair_id,score,
               row_number() over(order by score desc,pair_id)::int rn
        from cb_d_entries
      )
      update cb_d_entries e
      set entry_method='qualifying'
      from ranked rnk
      where e.pair_id=rnk.pair_id
        and rnk.rn>v_draw-1;

      -- The qualifying WC favours a home team, then pair quality.
      update cb_d_entries e
      set entry_method='qualifying_wildcard'
      where e.pair_id=(
        select q.pair_id
        from cb_d_entries q
        join public.world_doubles_partnerships w on w.id=q.pair_id
        join public.players a on a.id=w.player_a_id
        join public.players b on b.id=w.player_b_id
        where q.entry_method='qualifying'
        order by
          ((a.country is not distinct from t.country)::int+
           (b.country is not distinct from t.country)::int) desc,
          q.score desc,q.pair_id
        limit 1
      );

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

    if v_wc_count>0 then
      update cb_d_entries e
      set entry_method='wildcard'
      where e.pair_id in (
        select q.pair_id
        from cb_d_entries q
        join public.world_doubles_partnerships w on w.id=q.pair_id
        join public.players a on a.id=w.player_a_id
        join public.players b on b.id=w.player_b_id
        where q.entry_method='direct'
        order by
          ((a.country is not distinct from t.country)::int+
           (b.country is not distinct from t.country)::int) desc,
          q.score desc,q.pair_id
        limit v_wc_count
      );
    end if;

    if t.circuit='Challenger' then
      update cb_d_entries e
      set entry_method='onsite'
      where e.pair_id in (
        select q.pair_id from cb_d_entries q
        where q.entry_method='direct'
        order by q.score asc,q.pair_id
        limit 4
      );
    end if;

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

CREATE OR REPLACE FUNCTION public.ncaa_assign_individual_draw_positions(p_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  v_singles_count int:=0;
  v_doubles_count int:=0;
  v_singles_bracket int:=2;
  v_doubles_bracket int:=2;
  v_singles_byes int:=0;
  v_doubles_byes int:=0;
  v_singles_seed_limit int:=0;
  v_doubles_seed_limit int:=0;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null then
    return jsonb_build_object('ok',false,'reason','tournament_not_found');
  end if;

  select count(*) into v_singles_count
  from public.ncaa_individual_entries
  where tournament_id=t.id and discipline='singles';

  if v_singles_count>0 then
    while v_singles_bracket<v_singles_count loop
      v_singles_bracket:=v_singles_bracket*2;
    end loop;
    v_singles_byes:=v_singles_bracket-v_singles_count;
    v_singles_seed_limit:=least(
      v_singles_count,
      case when v_singles_bracket<=16 then 4
           when v_singles_bracket<=32 then 8
           else 16 end
    );

    update public.ncaa_individual_entries
    set seed=null
    where tournament_id=t.id and discipline='singles'
      and seed>v_singles_seed_limit;

    update public.ncaa_individual_entries
    set draw_position=null
    where tournament_id=t.id and discipline='singles';

    update public.ncaa_individual_entries e
    set draw_position=public.world_tournament_seed_slot_for_event(
      t.id,v_singles_bracket,e.seed
    )
    where e.tournament_id=t.id and e.discipline='singles'
      and e.seed is not null;

    with bye_slots as (
      select case when e.draw_position%2=1 then e.draw_position+1 else e.draw_position-1 end slot
      from public.ncaa_individual_entries e
      where e.tournament_id=t.id and e.discipline='singles'
        and e.seed between 1 and least(v_singles_byes,v_singles_seed_limit)
        and e.draw_position is not null
    ),
    used as (
      select draw_position slot
      from public.ncaa_individual_entries
      where tournament_id=t.id and discipline='singles' and draw_position is not null
      union
      select slot from bye_slots
    ),
    free_slots as (
      select g slot,
             row_number() over(order by md5('ncaa-s-slot|'||t.id::text||'|'||g::text)) rn
      from generate_series(1,v_singles_bracket) g
      where not exists(select 1 from used u where u.slot=g)
    ),
    unseeded as (
      select player_id,
             row_number() over(order by md5('ncaa-s-player|'||t.id::text||'|'||player_id::text)) rn
      from public.ncaa_individual_entries
      where tournament_id=t.id and discipline='singles' and draw_position is null
    )
    update public.ncaa_individual_entries e
    set draw_position=f.slot
    from unseeded u join free_slots f using(rn)
    where e.tournament_id=t.id and e.discipline='singles'
      and e.player_id=u.player_id;
  end if;

  select count(*) into v_doubles_count
  from public.ncaa_individual_doubles_entries
  where tournament_id=t.id;

  if v_doubles_count>0 then
    while v_doubles_bracket<v_doubles_count loop
      v_doubles_bracket:=v_doubles_bracket*2;
    end loop;
    v_doubles_byes:=v_doubles_bracket-v_doubles_count;
    v_doubles_seed_limit:=least(
      v_doubles_count,
      case when v_doubles_bracket<=8 then 2
           when v_doubles_bracket<=16 then 4
           else 8 end
    );

    update public.ncaa_individual_doubles_entries
    set seed=null
    where tournament_id=t.id and seed>v_doubles_seed_limit;

    update public.ncaa_individual_doubles_entries
    set draw_position=null
    where tournament_id=t.id;

    update public.ncaa_individual_doubles_entries e
    set draw_position=public.world_tournament_seed_slot_for_event(
      t.id,v_doubles_bracket,e.seed
    )
    where e.tournament_id=t.id and e.seed is not null;

    with bye_slots as (
      select case when e.draw_position%2=1 then e.draw_position+1 else e.draw_position-1 end slot
      from public.ncaa_individual_doubles_entries e
      where e.tournament_id=t.id
        and e.seed between 1 and least(v_doubles_byes,v_doubles_seed_limit)
        and e.draw_position is not null
    ),
    used as (
      select draw_position slot
      from public.ncaa_individual_doubles_entries
      where tournament_id=t.id and draw_position is not null
      union
      select slot from bye_slots
    ),
    free_slots as (
      select g slot,
             row_number() over(order by md5('ncaa-d-slot|'||t.id::text||'|'||g::text)) rn
      from generate_series(1,v_doubles_bracket) g
      where not exists(select 1 from used u where u.slot=g)
    ),
    unseeded as (
      select id,
             row_number() over(order by md5('ncaa-d-pair|'||t.id::text||'|'||id::text)) rn
      from public.ncaa_individual_doubles_entries
      where tournament_id=t.id and draw_position is null
    )
    update public.ncaa_individual_doubles_entries e
    set draw_position=f.slot
    from unseeded u join free_slots f using(rn)
    where e.id=u.id;
  end if;

  return jsonb_build_object(
    'ok',true,'tournament_id',t.id,
    'singles_entries',v_singles_count,'singles_bracket',case when v_singles_count>0 then v_singles_bracket else 0 end,
    'singles_byes',case when v_singles_count>0 then v_singles_byes else 0 end,
    'singles_seeds',case when v_singles_count>0 then v_singles_seed_limit else 0 end,
    'doubles_entries',v_doubles_count,'doubles_bracket',case when v_doubles_count>0 then v_doubles_bracket else 0 end,
    'doubles_byes',case when v_doubles_count>0 then v_doubles_byes else 0 end,
    'doubles_seeds',case when v_doubles_count>0 then v_doubles_seed_limit else 0 end,
    'model','CB-NCAA-DRAW-v2'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.ncaa_prepare_individual_event(p_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  v_singles_draw int;
  v_doubles_draw int;
  v_singles_count int:=0;
  v_doubles_count int:=0;
  v_school_cap int;
  v_season int;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null or t.circuit<>'NCAA' or not coalesce(t.is_active,true) then
    return jsonb_build_object('ok',false,'reason','not_active_ncaa_event');
  end if;

  if t.category in ('ITA Kickoff Weekend','ITA National Team Indoor Championship','NCAA DI Team Championship') then
    return jsonb_build_object('ok',false,'reason','team_event');
  end if;

  v_season:=extract(year from t.start_date)::int;
  v_singles_draw:=greatest(0,coalesce(t.singles_draw_size,t.draw_size,case when t.singles then 64 else 0 end));
  v_doubles_draw:=greatest(0,coalesce(t.doubles_draw_size,case when t.doubles then 16 else 0 end));

  if t.category='NCAA DI Individual Championship' then
    v_school_cap:=99;
  elsif t.registration_mode in ('school_nomination','conference_selection') then
    v_school_cap:=4;
  else
    v_school_cap:=3;
  end if;

  if coalesce(t.singles,false) and v_singles_draw>0
     and not exists(select 1 from public.ncaa_individual_entries where tournament_id=t.id and discipline='singles') then

    with base as (
      select p.id,p.ncaa_team_id,p.ncaa_school,p.ncaa_rank,
             coalesce(us.current_rating,10) utr,
             coalesce(ip.points,0) season_points,
             coalesce(p.current_ability,50) ca,
             row_number() over(
               partition by coalesce(p.ncaa_team_id,-p.id)
               order by
                 case when t.category='NCAA UTR' then coalesce(us.current_rating,10) else coalesce(ip.points,0) end desc,
                 coalesce(p.ncaa_rank,9999),
                 p.id
             ) school_rn
      from public.players p
      left join public.player_utr_state us on us.player_id=p.id
      left join public.ncaa_individual_points ip on ip.player_id=p.id and ip.season=v_season
      where p.ncaa_current=true
        and p.career_status='active'
        and p.injury_status='Fit'
        and coalesce(p.fitness,90)>=45
        and public.ncaa_individual_player_available(p.id,t.id)
    ),
    championship_auto as (
      select distinct q.player_ids[1] player_id
      from public.ncaa_individual_qualifiers q
      where q.season=v_season and q.discipline='singles'
        and array_length(q.player_ids,1)=1
    ),
    ranked as (
      select b.*,
        case
          when ca.player_id is not null then -1000000
          else 0 end auto_bias,
        (
          case
            when t.category='NCAA UTR' then b.utr*95+b.ca*.4+b.season_points*.02
            when t.category='NCAA DI Individual Championship' then b.season_points*1.4+b.utr*24+b.ca*.25
            when t.category like 'ITA %' then b.season_points*.8+b.utr*42+b.ca*.30
            else b.season_points*.35+b.utr*62+b.ca*.25
          end
          + (mod(abs(hashtext('ncaa-field|'||t.id||'|'||b.id)),1000)::numeric/1000.0)*6
        ) field_score
      from base b
      left join championship_auto ca on ca.player_id=b.id
      where b.school_rn<=v_school_cap or ca.player_id is not null
    ),
    chosen as (
      select id,
             row_number() over(order by auto_bias asc,field_score desc,coalesce(ncaa_rank,9999),id)::int pos
      from ranked
      order by auto_bias asc,field_score desc,coalesce(ncaa_rank,9999),id
      limit v_singles_draw
    )
    insert into public.ncaa_individual_entries(
      tournament_id,player_id,discipline,initial_phase,seed,draw_position,entry_type
    )
    select t.id,c.id,'singles','main',
           case when c.pos<=16 then c.pos else null end,
           c.pos,
           case when exists(
             select 1 from public.ncaa_individual_qualifiers q
             where q.season=v_season and q.discipline='singles'
               and q.player_ids=array[c.id]::bigint[]
           ) then 'automatic_qualifier'
           when t.registration_mode='conference_selection' then 'conference_selection'
           when t.registration_mode='school_nomination' then 'school_nomination'
           else 'individual_selection' end
    from chosen c
    on conflict do nothing;

    get diagnostics v_singles_count=row_count;
  else
    select count(*) into v_singles_count
    from public.ncaa_individual_entries where tournament_id=t.id and discipline='singles';
  end if;

  if coalesce(t.doubles,false) and v_doubles_draw>0
     and not exists(select 1 from public.ncaa_individual_doubles_entries where tournament_id=t.id) then

    with eligible as (
      select p.id,p.ncaa_team_id,p.ncaa_school,
             coalesce(pa.doubles,10) doubles_skill,
             coalesce(us.current_rating,10) utr,
             coalesce(p.current_ability,50) ca,
             row_number() over(
               partition by p.ncaa_team_id
               order by coalesce(pa.doubles,10) desc,coalesce(us.current_rating,10) desc,p.id
             ) rn
      from public.players p
      left join public.player_attributes pa on pa.player_id=p.id
      left join public.player_utr_state us on us.player_id=p.id
      where p.ncaa_current=true
        and p.ncaa_team_id is not null
        and p.career_status='active'
        and p.injury_status='Fit'
        and coalesce(p.fitness,90)>=45
        and coalesce(p.career_focus,'mixed')<>'singles_only'
        and public.ncaa_individual_player_available(p.id,t.id)
    ),
    pairs as (
      select a.ncaa_team_id,
             least(a.id,b.id) player_a_id,
             greatest(a.id,b.id) player_b_id,
             a.doubles_skill+b.doubles_skill+(a.utr+b.utr)*.7+(a.ca+b.ca)*.10 pair_score,
             ((a.rn+1)/2)::int pair_no
      from eligible a
      join eligible b
        on b.ncaa_team_id=a.ncaa_team_id
       and b.rn=a.rn+1
       and mod(a.rn,2)=1
      where a.rn<=6
    ),
    ranked as (
      select *,
        row_number() over(order by pair_score desc,
          mod(abs(hashtext('ncaa-double-field|'||t.id||'|'||player_a_id||'|'||player_b_id)),1000),
          player_a_id,player_b_id)::int pos
      from pairs
      where pair_no<=3
      order by pair_score desc,pos
      limit v_doubles_draw
    )
    insert into public.ncaa_individual_doubles_entries(
      tournament_id,player_a_id,player_b_id,initial_phase,seed
    )
    select t.id,player_a_id,player_b_id,'main',
           case when pos<=8 then pos else null end
    from ranked
    on conflict do nothing;

    get diagnostics v_doubles_count=row_count;
  else
    select count(*) into v_doubles_count
    from public.ncaa_individual_doubles_entries where tournament_id=t.id;
  end if;

  perform public.ncaa_assign_individual_draw_positions(t.id);

  return jsonb_build_object(
    'ok',true,'tournament_id',t.id,'name',t.name,
    'singles_entries',v_singles_count,'doubles_entries',v_doubles_count,
    'singles_draw',v_singles_draw,'doubles_draw',v_doubles_draw
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.simulate_ncaa_individual_singles(p_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  v_players bigint[];
  v_next bigint[];
  v_n int;
  v_bracket int:=2;
  v_byes int;
  v_round_index int:=1;
  v_round_code text;
  v_match_no int;
  i int;
  a bigint;
  b bigint;
  w bigint;
  l bigint;
  r jsonb;
  pts int;
  played date;
  v_season int;
  v_title bigint;
  v_matches int:=0;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null then return jsonb_build_object('ok',false,'reason','not_found'); end if;

  select count(*) into v_n
  from public.ncaa_individual_entries
  where tournament_id=t.id and discipline='singles';

  if v_n<2 then return jsonb_build_object('ok',false,'reason','insufficient_field','entries',v_n); end if;

  while v_bracket<v_n loop v_bracket:=v_bracket*2; end loop;
  perform public.ncaa_assign_individual_draw_positions(t.id);

  select array_agg(e.player_id order by g)
  into v_players
  from generate_series(1,v_bracket) g
  left join public.ncaa_individual_entries e
    on e.tournament_id=t.id
   and e.discipline='singles'
   and e.draw_position=g;

  v_n:=v_bracket;

  delete from public.ncaa_individual_matches
  where tournament_id=t.id and discipline='singles';

  v_byes:=0;
  v_round_code:=public.ncaa_round_code(v_bracket);
  played:=least(coalesce(t.end_date,t.start_date),t.start_date);
  v_next:='{}'::bigint[];

  if v_byes>0 then
    for i in 1..v_byes loop
      v_next:=array_append(v_next,v_players[i]);
    end loop;
  end if;

  v_match_no:=0;
  i:=v_byes+1;
  while i<=v_n loop
    a:=v_players[i];
    b:=v_players[i+1];

    if a is null and b is null then
      v_next:=array_append(v_next,null::bigint);
      i:=i+2;
      continue;
    elsif a is null or b is null then
      v_next:=array_append(v_next,coalesce(a,b));
      i:=i+2;
      continue;
    end if;

    v_match_no:=v_match_no+1;
    r:=public.ncaa_individual_match_result(a,b,t.surface,played,t.id||'|'||v_round_code||'|'||v_match_no);
    w:=(r->>'winner_id')::bigint;
    l:=(r->>'loser_id')::bigint;
    pts:=public.ncaa_round_win_points(t.category,v_round_code);

    insert into public.ncaa_individual_matches(
      tournament_id,discipline,phase,round_index,round_code,match_no,
      side_a_player_ids,side_b_player_ids,winner_player_ids,loser_player_ids,
      score,home_win_probability,played_on
    ) values(
      t.id,'singles','main',v_round_index,v_round_code,v_match_no,
      array[a],array[b],array[w],array[l],r->>'score',(r->>'a_probability')::numeric,played
    );

    update public.ncaa_individual_entries
    set wins=wins+1,points_earned=points_earned+pts
    where tournament_id=t.id and discipline='singles' and player_id=w;
    update public.ncaa_individual_entries
    set losses=losses+1,result_code=v_round_code
    where tournament_id=t.id and discipline='singles' and player_id=l;

    v_season:=extract(year from t.start_date)::int;
    insert into public.ncaa_individual_points(player_id,season,points,wins,losses,titles)
    values(w,v_season,pts,1,0,0)
    on conflict(player_id,season) do update
      set points=public.ncaa_individual_points.points+excluded.points,
          wins=public.ncaa_individual_points.wins+1,
          updated_at=now();

    insert into public.ncaa_individual_points(player_id,season,points,wins,losses,titles)
    values(l,v_season,0,0,1,0)
    on conflict(player_id,season) do update
      set losses=public.ncaa_individual_points.losses+1,
          updated_at=now();

    perform public.ncaa_apply_utr_result(
      w,l,played,t.id,null,public.ncaa_individual_event_weight(t.category)
    );

    update public.players
    set fatigue=least(100,coalesce(fatigue,20)+3),
        fitness=greatest(35,coalesce(fitness,90)-1),
        form=greatest(1,least(100,coalesce(form,70)+case when id=w then 1 else -1 end))
    where id in (w,l);

    v_next:=array_append(v_next,w);
    v_matches:=v_matches+1;
    i:=i+2;
  end loop;

  v_players:=v_next;

  while coalesce(array_length(v_players,1),0)>1 loop
    v_n:=array_length(v_players,1);
    v_round_index:=v_round_index+1;
    v_round_code:=public.ncaa_round_code(v_n);
    played:=least(coalesce(t.end_date,t.start_date),t.start_date+(v_round_index-1));
    v_next:='{}'::bigint[];
    v_match_no:=0;

    i:=1;
    while i<=v_n loop
      a:=v_players[i];
      b:=v_players[i+1];

      if a is null and b is null then
        v_next:=array_append(v_next,null::bigint);
        i:=i+2;
        continue;
      elsif a is null or b is null then
        v_next:=array_append(v_next,coalesce(a,b));
        i:=i+2;
        continue;
      end if;

      v_match_no:=v_match_no+1;
      r:=public.ncaa_individual_match_result(a,b,t.surface,played,t.id||'|'||v_round_code||'|'||v_match_no);
      w:=(r->>'winner_id')::bigint;
      l:=(r->>'loser_id')::bigint;
      pts:=public.ncaa_round_win_points(t.category,v_round_code);

      insert into public.ncaa_individual_matches(
        tournament_id,discipline,phase,round_index,round_code,match_no,
        side_a_player_ids,side_b_player_ids,winner_player_ids,loser_player_ids,
        score,home_win_probability,played_on
      ) values(
        t.id,'singles','main',v_round_index,v_round_code,v_match_no,
        array[a],array[b],array[w],array[l],r->>'score',(r->>'a_probability')::numeric,played
      );

      update public.ncaa_individual_entries
      set wins=wins+1,points_earned=points_earned+pts
      where tournament_id=t.id and discipline='singles' and player_id=w;
      update public.ncaa_individual_entries
      set losses=losses+1,result_code=v_round_code
      where tournament_id=t.id and discipline='singles' and player_id=l;

      insert into public.ncaa_individual_points(player_id,season,points,wins,losses,titles)
      values(w,v_season,pts,1,0,0)
      on conflict(player_id,season) do update
        set points=public.ncaa_individual_points.points+excluded.points,
            wins=public.ncaa_individual_points.wins+1,
            updated_at=now();

      insert into public.ncaa_individual_points(player_id,season,points,wins,losses,titles)
      values(l,v_season,0,0,1,0)
      on conflict(player_id,season) do update
        set losses=public.ncaa_individual_points.losses+1,
            updated_at=now();

      perform public.ncaa_apply_utr_result(
        w,l,played,t.id,null,public.ncaa_individual_event_weight(t.category)
      );

      update public.players
      set fatigue=least(100,coalesce(fatigue,20)+3),
          fitness=greatest(35,coalesce(fitness,90)-1),
          form=greatest(1,least(100,coalesce(form,70)+case when id=w then 1 else -1 end))
      where id in (w,l);

      v_next:=array_append(v_next,w);
      v_matches:=v_matches+1;
      i:=i+2;
    end loop;

    v_players:=v_next;
  end loop;

  v_title:=v_players[1];
  update public.ncaa_individual_entries
  set result_code='W'
  where tournament_id=t.id and discipline='singles' and player_id=v_title;

  update public.ncaa_individual_points
  set titles=titles+1,updated_at=now()
  where player_id=v_title and season=v_season;

  return jsonb_build_object(
    'ok',true,'tournament_id',t.id,'entries',
    (select count(*) from public.ncaa_individual_entries where tournament_id=t.id and discipline='singles'),
    'matches',v_matches,'winner_id',v_title
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.simulate_ncaa_individual_doubles(p_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  v_pairs bigint[];
  v_next bigint[];
  v_n int;
  v_bracket int:=2;
  v_byes int;
  v_round_index int:=1;
  v_round_code text;
  v_match_no int;
  i int;
  ea bigint;
  eb bigint;
  wa bigint;
  la bigint;
  a1 bigint;a2 bigint;b1 bigint;b2 bigint;
  w1 bigint;w2 bigint;l1 bigint;l2 bigint;
  r jsonb;
  pts int;
  played date;
  v_season int;
  v_title bigint;
  v_matches int:=0;
  a_win boolean;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null then return jsonb_build_object('ok',false,'reason','not_found'); end if;

  select count(*) into v_n
  from public.ncaa_individual_doubles_entries
  where tournament_id=t.id;

  if v_n<2 then return jsonb_build_object('ok',false,'reason','insufficient_field','entries',v_n); end if;

  while v_bracket<v_n loop v_bracket:=v_bracket*2; end loop;
  perform public.ncaa_assign_individual_draw_positions(t.id);

  select array_agg(e.id order by g)
  into v_pairs
  from generate_series(1,v_bracket) g
  left join public.ncaa_individual_doubles_entries e
    on e.tournament_id=t.id
   and e.draw_position=g;

  v_n:=v_bracket;

  delete from public.ncaa_individual_matches
  where tournament_id=t.id and discipline='doubles';

  v_byes:=0;
  v_round_code:=public.ncaa_round_code(v_bracket);
  played:=least(coalesce(t.end_date,t.start_date),t.start_date);
  v_next:='{}'::bigint[];

  if v_byes>0 then
    for i in 1..v_byes loop
      v_next:=array_append(v_next,v_pairs[i]);
    end loop;
  end if;

  v_match_no:=0;
  i:=v_byes+1;
  while i<=v_n loop
    ea:=v_pairs[i]; eb:=v_pairs[i+1];

    if ea is null and eb is null then
      v_next:=array_append(v_next,null::bigint);
      i:=i+2;
      continue;
    elsif ea is null or eb is null then
      v_next:=array_append(v_next,coalesce(ea,eb));
      i:=i+2;
      continue;
    end if;

    select player_a_id,player_b_id into a1,a2 from public.ncaa_individual_doubles_entries where id=ea;
    select player_a_id,player_b_id into b1,b2 from public.ncaa_individual_doubles_entries where id=eb;

    v_match_no:=v_match_no+1;
    r:=public.ncaa_individual_doubles_match_result(a1,a2,b1,b2,t.surface,played,t.id||'|'||v_round_code||'|'||v_match_no);
    a_win:=coalesce((r->>'a_win')::boolean,false);
    wa:=case when a_win then ea else eb end;
    la:=case when a_win then eb else ea end;
    w1:=case when a_win then a1 else b1 end;
    w2:=case when a_win then a2 else b2 end;
    l1:=case when a_win then b1 else a1 end;
    l2:=case when a_win then b2 else a2 end;
    pts:=round(public.ncaa_round_win_points(t.category,v_round_code)*.80)::int;

    insert into public.ncaa_individual_matches(
      tournament_id,discipline,phase,round_index,round_code,match_no,
      side_a_player_ids,side_b_player_ids,winner_player_ids,loser_player_ids,
      score,home_win_probability,played_on
    ) values(
      t.id,'doubles','main',v_round_index,v_round_code,v_match_no,
      array[a1,a2],array[b1,b2],array[w1,w2],array[l1,l2],
      r->>'score',(r->>'a_probability')::numeric,played
    );

    update public.ncaa_individual_doubles_entries
    set wins=wins+1,points_earned=points_earned+pts
    where id=wa;
    update public.ncaa_individual_doubles_entries
    set losses=losses+1,result_code=v_round_code
    where id=la;

    v_season:=extract(year from t.start_date)::int;
    insert into public.ncaa_doubles_pair_points(player_a_id,player_b_id,season,points,wins,losses,titles)
    values(least(w1,w2),greatest(w1,w2),v_season,pts,1,0,0)
    on conflict(player_a_id,player_b_id,season) do update
      set points=public.ncaa_doubles_pair_points.points+excluded.points,
          wins=public.ncaa_doubles_pair_points.wins+1,
          updated_at=now();

    insert into public.ncaa_doubles_pair_points(player_a_id,player_b_id,season,points,wins,losses,titles)
    values(least(l1,l2),greatest(l1,l2),v_season,0,0,1,0)
    on conflict(player_a_id,player_b_id,season) do update
      set losses=public.ncaa_doubles_pair_points.losses+1,
          updated_at=now();

    update public.players
    set fatigue=least(100,coalesce(fatigue,20)+2),
        form=greatest(1,least(100,coalesce(form,70)+case when id in (w1,w2) then 1 else -1 end))
    where id in (w1,w2,l1,l2);

    v_next:=array_append(v_next,wa);
    v_matches:=v_matches+1;
    i:=i+2;
  end loop;

  v_pairs:=v_next;

  while coalesce(array_length(v_pairs,1),0)>1 loop
    v_n:=array_length(v_pairs,1);
    v_round_index:=v_round_index+1;
    v_round_code:=public.ncaa_round_code(v_n);
    played:=least(coalesce(t.end_date,t.start_date),t.start_date+(v_round_index-1));
    v_next:='{}'::bigint[];
    v_match_no:=0;

    i:=1;
    while i<=v_n loop
      ea:=v_pairs[i]; eb:=v_pairs[i+1];

      if ea is null and eb is null then
        v_next:=array_append(v_next,null::bigint);
        i:=i+2;
        continue;
      elsif ea is null or eb is null then
        v_next:=array_append(v_next,coalesce(ea,eb));
        i:=i+2;
        continue;
      end if;

      select player_a_id,player_b_id into a1,a2 from public.ncaa_individual_doubles_entries where id=ea;
      select player_a_id,player_b_id into b1,b2 from public.ncaa_individual_doubles_entries where id=eb;

      v_match_no:=v_match_no+1;
      r:=public.ncaa_individual_doubles_match_result(a1,a2,b1,b2,t.surface,played,t.id||'|'||v_round_code||'|'||v_match_no);
      a_win:=coalesce((r->>'a_win')::boolean,false);
      wa:=case when a_win then ea else eb end;
      la:=case when a_win then eb else ea end;
      w1:=case when a_win then a1 else b1 end;
      w2:=case when a_win then a2 else b2 end;
      l1:=case when a_win then b1 else a1 end;
      l2:=case when a_win then b2 else a2 end;
      pts:=round(public.ncaa_round_win_points(t.category,v_round_code)*.80)::int;

      insert into public.ncaa_individual_matches(
        tournament_id,discipline,phase,round_index,round_code,match_no,
        side_a_player_ids,side_b_player_ids,winner_player_ids,loser_player_ids,
        score,home_win_probability,played_on
      ) values(
        t.id,'doubles','main',v_round_index,v_round_code,v_match_no,
        array[a1,a2],array[b1,b2],array[w1,w2],array[l1,l2],
        r->>'score',(r->>'a_probability')::numeric,played
      );

      update public.ncaa_individual_doubles_entries
      set wins=wins+1,points_earned=points_earned+pts
      where id=wa;
      update public.ncaa_individual_doubles_entries
      set losses=losses+1,result_code=v_round_code
      where id=la;

      insert into public.ncaa_doubles_pair_points(player_a_id,player_b_id,season,points,wins,losses,titles)
      values(least(w1,w2),greatest(w1,w2),v_season,pts,1,0,0)
      on conflict(player_a_id,player_b_id,season) do update
        set points=public.ncaa_doubles_pair_points.points+excluded.points,
            wins=public.ncaa_doubles_pair_points.wins+1,
            updated_at=now();

      insert into public.ncaa_doubles_pair_points(player_a_id,player_b_id,season,points,wins,losses,titles)
      values(least(l1,l2),greatest(l1,l2),v_season,0,0,1,0)
      on conflict(player_a_id,player_b_id,season) do update
        set losses=public.ncaa_doubles_pair_points.losses+1,
            updated_at=now();

      update public.players
      set fatigue=least(100,coalesce(fatigue,20)+2),
          form=greatest(1,least(100,coalesce(form,70)+case when id in (w1,w2) then 1 else -1 end))
      where id in (w1,w2,l1,l2);

      v_next:=array_append(v_next,wa);
      v_matches:=v_matches+1;
      i:=i+2;
    end loop;

    v_pairs:=v_next;
  end loop;

  v_title:=v_pairs[1];
  update public.ncaa_individual_doubles_entries
  set result_code='W'
  where id=v_title;

  select player_a_id,player_b_id into a1,a2
  from public.ncaa_individual_doubles_entries where id=v_title;

  update public.ncaa_doubles_pair_points
  set titles=titles+1,updated_at=now()
  where player_a_id=least(a1,a2) and player_b_id=greatest(a1,a2) and season=v_season;

  return jsonb_build_object(
    'ok',true,'tournament_id',t.id,
    'entries',(select count(*) from public.ncaa_individual_doubles_entries where tournament_id=t.id),
    'matches',v_matches,'winner_entry_id',v_title,
    'winner_player_ids',array[a1,a2]
  );
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
  v_seed_count int;
  v_pair_count int:=0;
  v_direct_count int:=0;
  v_wc_count int:=0;
  v_seed_no int;
  v_slot int;
  v_bracket int:=8;
  v_byes int:=0;
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
  v_seed_count:=least(v_draw,public.junior_doubles_seed_count(v_draw));
  while v_bracket<v_draw loop v_bracket:=v_bracket*2; end loop;
  v_byes:=greatest(0,v_bracket-v_draw);

  if exists(
    select 1 from public.junior_doubles_reservations
    where tournament_id=t.id
  ) then
    return jsonb_build_object(
      'ok',true,'already',true,
      'pairs',(select count(*) from public.junior_doubles_reservations where tournament_id=t.id),
      'direct_pairs',(select count(*) from public.junior_doubles_reservations where tournament_id=t.id and entry_method='direct'),
      'wildcard_pairs',(select count(*) from public.junior_doubles_reservations where tournament_id=t.id and entry_method='wildcard'),
      'alternates',(select count(*) from public.junior_doubles_signins where tournament_id=t.id and status='alternate')
    );
  end if;

  perform public.prepare_junior_doubles_signins(t.id);

  -- Direct acceptances are selected from already-signed partnerships using
  -- the six ITF 2026 acceptance groups, then ranking within each group.
  insert into public.junior_doubles_reservations(
    tournament_id,player_a_id,player_b_id,entry_method,acceptance_group,
    combined_rank,pair_strength,reserved_on,model_version
  )
  select
    s.tournament_id,s.player_a_id,s.player_b_id,'direct',
    s.acceptance_group,s.combined_rank,s.pair_strength,s.signed_on,
    'CB-JUNIOR-DOUBLES-ENTRY-v2'
  from public.junior_doubles_signins s
  where s.tournament_id=t.id
    and s.status='signed'
  order by
    s.acceptance_group,
    s.combined_rank,
    md5('junior-doubles-accept|'||t.id||'|'||s.player_a_id||'|'||s.player_b_id)
  limit v_direct
  on conflict do nothing;

  get diagnostics v_direct_count=row_count;

  update public.junior_doubles_signins s
  set status='accepted_direct'
  where s.tournament_id=t.id
    and exists(
      select 1
      from public.junior_doubles_reservations r
      where r.tournament_id=s.tournament_id
        and r.player_a_id=s.player_a_id
        and r.player_b_id=s.player_b_id
        and r.entry_method='direct'
    );

  -- Doubles wild cards are additional to the direct acceptances. Prefer
  -- host-national partnerships, then one host player, then strongest chemistry.
  insert into public.junior_doubles_reservations(
    tournament_id,player_a_id,player_b_id,entry_method,acceptance_group,
    combined_rank,pair_strength,reserved_on,model_version
  )
  select
    s.tournament_id,s.player_a_id,s.player_b_id,'wildcard',
    99,s.combined_rank,s.pair_strength,s.signed_on,
    'CB-JUNIOR-DOUBLES-ENTRY-v2'
  from public.junior_doubles_signins s
  join public.players a on a.id=s.player_a_id
  join public.players b on b.id=s.player_b_id
  where s.tournament_id=t.id
    and s.status='signed'
  order by
    case
      when upper(coalesce(a.country,''))=upper(coalesce(t.country,''))
       and upper(coalesce(b.country,''))=upper(coalesce(t.country,'')) then 0
      when upper(coalesce(a.country,''))=upper(coalesce(t.country,''))
        or upper(coalesce(b.country,''))=upper(coalesce(t.country,'')) then 1
      else 2
    end,
    s.affinity_score desc,
    s.pair_strength desc,
    md5('junior-doubles-wc|'||t.id||'|'||s.player_a_id||'|'||s.player_b_id)
  limit v_wc
  on conflict do nothing;

  get diagnostics v_wc_count=row_count;

  update public.junior_doubles_signins s
  set status='accepted_wildcard'
  where s.tournament_id=t.id
    and exists(
      select 1
      from public.junior_doubles_reservations r
      where r.tournament_id=s.tournament_id
        and r.player_a_id=s.player_a_id
        and r.player_b_id=s.player_b_id
        and r.entry_method='wildcard'
    );

  update public.junior_doubles_signins
  set status='alternate'
  where tournament_id=t.id and status='signed';

  select count(*) into v_pair_count
  from public.junior_doubles_reservations
  where tournament_id=t.id;

  if v_pair_count<>v_draw then
    delete from public.junior_doubles_reservations where tournament_id=t.id;
    update public.junior_doubles_signins
    set status='signed'
    where tournament_id=t.id;
    return jsonb_build_object(
      'ok',false,'reason','insufficient_signed_pair_field',
      'pairs_built',v_pair_count,'draw',v_draw,
      'signed_pairs',(select count(*) from public.junior_doubles_signins where tournament_id=t.id)
    );
  end if;

  -- Seed only the official number of teams. Professional ATP ranking is
  -- converted with the ITF seeding comparison chart by junior_doubles_effective_rank().
  with ranked as (
    select
      r.player_a_id,r.player_b_id,
      row_number() over(
        order by
          (
            coalesce(public.junior_doubles_effective_rank(r.player_a_id),999999)
            +coalesce(public.junior_doubles_effective_rank(r.player_b_id),999999)
          ),
          r.pair_strength desc,
          md5('junior-doubles-seed|'||t.id||'|'||r.player_a_id||'|'||r.player_b_id)
      )::int rn
    from public.junior_doubles_reservations r
    where r.tournament_id=t.id
  )
  update public.junior_doubles_reservations r
  set seed=case when x.rn<=v_seed_count then x.rn else null end,
      draw_slot=null
  from ranked x
  where r.tournament_id=t.id
    and r.player_a_id=x.player_a_id
    and r.player_b_id=x.player_b_id;

  -- ITF Junior 2026 public draw: seeds occupy the official lines used by
  -- 16, 24/32 and 48/64 draws. Required byes go to the highest seeds first.
  update public.junior_doubles_reservations r
  set draw_slot=public.world_tournament_seed_slot_for_event(
    t.id,v_bracket,r.seed
  )
  where r.tournament_id=t.id and r.seed is not null;

  with bye_slots as (
    select case when r.draw_slot%2=1 then r.draw_slot+1 else r.draw_slot-1 end slot
    from public.junior_doubles_reservations r
    where r.tournament_id=t.id
      and r.seed between 1 and least(v_byes,v_seed_count)
      and r.draw_slot is not null
  ),
  used as (
    select draw_slot slot
    from public.junior_doubles_reservations
    where tournament_id=t.id and draw_slot is not null
    union
    select slot from bye_slots
  ),
  free_slots as (
    select gs slot,
           row_number() over(
             order by md5('junior-doubles-slot-v3|'||t.id||'|'||gs)
           )::int rn
    from generate_series(1,v_bracket) gs
    where not exists(select 1 from used u where u.slot=gs)
  ),
  unseeded as (
    select r.player_a_id,r.player_b_id,
           row_number() over(
             order by md5('junior-doubles-team-v3|'||t.id||'|'||r.player_a_id||'|'||r.player_b_id)
           )::int rn
    from public.junior_doubles_reservations r
    where r.tournament_id=t.id and r.seed is null
  )
  update public.junior_doubles_reservations r
  set draw_slot=f.slot
  from unseeded u
  join free_slots f on f.rn=u.rn
  where r.tournament_id=t.id
    and r.player_a_id=u.player_a_id
    and r.player_b_id=u.player_b_id;

  return jsonb_build_object(
    'ok',true,
    'pairs',v_pair_count,
    'direct_pairs',v_direct_count,
    'wildcard_pairs',v_wc_count,
    'alternates',(select count(*) from public.junior_doubles_signins where tournament_id=t.id and status='alternate'),
    'seeds',v_seed_count,
    'draw',v_draw,'bracket',v_bracket,'byes',v_byes,
    'model','ITF Junior 2026 fixed sign-in partnerships -> official seed lines + byes + public draw v3'
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
  v_bracket int;
  v_byes int;
  v_round int;
  v_pos int;
  v_next int;
  v_match_no int;
  v_round_entries bigint[];
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
      entry_method text not null,
      acceptance_group int not null,
      signed_on date,
      seed int,
      draw_slot int
    ) on commit drop;

    perform public.prepare_junior_doubles_reservations(t.id);
    perform public.refresh_junior_doubles_reservations(t.id);

    insert into cb_jd(
      player_a_id,player_b_id,strength,combined_rank,
      entry_method,acceptance_group,signed_on,seed,draw_slot
    )
    select
      r.player_a_id,r.player_b_id,r.pair_strength,r.combined_rank,
      r.entry_method,r.acceptance_group,r.reserved_on,r.seed,r.draw_slot
    from public.junior_doubles_reservations r
    where r.tournament_id=t.id
    order by r.draw_slot,r.player_a_id,r.player_b_id;

    select count(*) into v_pair_count from cb_jd;
    -- A late withdrawal without an available alternate becomes a real bye.
    -- Only abort if the event no longer has enough teams to be playable.
    if v_pair_count<2 then
      continue;
    end if;

    -- Seeds and draw slots are fixed at doubles sign-in / public draw time.
    -- Do not re-rank or reconstruct the bracket here.

    delete from public.world_junior_doubles_matches where tournament_id=t.id;
    delete from public.world_junior_doubles_entries where tournament_id=t.id;

    insert into public.world_junior_doubles_entries(
      tournament_id,player_a_id,player_b_id,seed,draw_slot,simulated_on,
      entry_method,acceptance_group,combined_rank,pair_strength,signed_on,model_version
    )
    select
      t.id,player_a_id,player_b_id,seed,draw_slot,t.end_date,
      entry_method,acceptance_group,combined_rank,strength,signed_on,
      'CB-JUNIOR-DOUBLES-v5-SIGNIN'
    from cb_jd
    order by draw_slot;

    drop table if exists pg_temp.cb_jd_current;
    drop table if exists pg_temp.cb_jd_next;
    create temporary table cb_jd_current(pos int primary key,entry_id bigint) on commit drop;
    create temporary table cb_jd_next(pos int primary key,entry_id bigint) on commit drop;

    v_bracket:=8;
    while v_bracket<v_draw loop v_bracket:=v_bracket*2; end loop;

    insert into cb_jd_current(pos,entry_id)
    select g,e.id
    from generate_series(1,v_bracket) g
    left join public.world_junior_doubles_entries e
      on e.tournament_id=t.id and e.draw_slot=g;

    v_round:=1;

    while (select count(*) from cb_jd_current)>1 loop
      select count(*) into v_size from cb_jd_current;

      v_bracket:=1;
      while v_bracket<v_size loop
        v_bracket:=v_bracket*2;
      end loop;
      v_byes:=v_bracket-v_size;

      truncate cb_jd_next;
      v_next:=0;
      v_match_no:=0;

      v_code:=case
        when v_bracket>=64 then 'R64'
        when v_bracket>=32 then 'R32'
        when v_bracket>=16 then 'R16'
        when v_bracket>=8 then 'QF'
        when v_bracket>=4 then 'SF'
        else 'F' end;

      -- Highest seeds receive the byes needed to reduce the field to a
      -- power-of-two bracket. Byes are not stored as fake matches.
      if v_byes>0 then
        for rr in
          select c.entry_id
          from cb_jd_current c
          join public.world_junior_doubles_entries e on e.id=c.entry_id
          order by coalesce(e.seed,9999),c.pos
          limit v_byes
        loop
          v_next:=v_next+1;
          insert into cb_jd_next(pos,entry_id) values(v_next,rr.entry_id);
        end loop;
      end if;

      select array_agg(c.entry_id order by c.pos)
      into v_round_entries
      from cb_jd_current c
      join public.world_junior_doubles_entries e on e.id=c.entry_id
      where not exists(
        select 1 from cb_jd_next n where n.entry_id=c.entry_id
      );

      if coalesce(array_length(v_round_entries,1),0)>0 then
        for v_pos in 1..array_length(v_round_entries,1) by 2 loop
          v_a:=v_round_entries[v_pos];
          v_b:=v_round_entries[v_pos+1];

          if v_a is null and v_b is null then
            v_next:=v_next+1;
            insert into cb_jd_next(pos,entry_id) values(v_next,null);
            continue;
          elsif v_a is null or v_b is null then
            v_next:=v_next+1;
            insert into cb_jd_next(pos,entry_id) values(v_next,coalesce(v_a,v_b));
            continue;
          end if;

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

          v_match_no:=v_match_no+1;
          insert into public.world_junior_doubles_matches(
            tournament_id,round_no,round_code,match_no,
            pair_a_entry_id,pair_b_entry_id,winner_entry_id,loser_entry_id,
            score,win_probability,simulated_on,model_version
          ) values(
            t.id,v_round,v_code,v_match_no,v_a,v_b,v_w,v_l,
            v_score,round(v_prob,4),t.end_date,'CB-JUNIOR-DOUBLES-v5-SIGNIN'
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

          v_next:=v_next+1;
          insert into cb_jd_next(pos,entry_id) values(v_next,v_w);
        end loop;
      end if;

      truncate cb_jd_current;
      insert into cb_jd_current
      select row_number() over(order by pos)::int,entry_id
      from cb_jd_next
      order by pos;

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
    'from',p_from_date,'to',p_to_date,'model','CB-JUNIOR-DOUBLES-v5 fixed sign-in partnerships + alternates + real byes'
  );
end
$function$;

CREATE OR REPLACE FUNCTION public.audit_draw_integrity(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  v_main_rule_mismatches int:=0;
  v_qual_seed_mismatches int:=0;
  v_seed_slot_collisions int:=0;
  v_first_round_seed_collisions int:=0;
  v_materialized_seed_slot_mismatches int:=0;
  v_duplicate_draw_positions int:=0;
  v_bad_doubles_seed_counts int:=0;
  v_bad_ncaa_positions int:=0;
begin
  -- Standard main-draw seed-count rules for the circuits modeled by Court Boss.
  select count(*) into v_main_rule_mismatches
  from public.tournament_format_rules r
  where exists(
    select 1 from public.tournaments t
    where t.circuit=r.circuit and t.category=r.category
      and coalesce(t.singles_draw_size,t.draw_size)=r.main_draw_size
      and coalesce(t.is_active,true)
      and t.start_date between p_from_date and p_to_date
  )
  and (
    (r.circuit in ('ATP','Challenger') and r.main_draw_size=28 and r.seed_count<>8)
    or (r.circuit in ('ATP','Challenger') and r.main_draw_size=32 and r.seed_count<>8)
    or (r.circuit='ATP' and r.main_draw_size in (48,56) and r.seed_count<>16)
    or (r.circuit='ATP' and r.main_draw_size=96 and r.seed_count<>32)
    or (r.circuit='ATP' and r.category='Grand Chelem' and r.main_draw_size=128 and r.seed_count<>32)
    or (r.circuit='ITF' and r.main_draw_size=32 and r.seed_count<>8)
    or (r.circuit='Junior' and r.main_draw_size<=16 and r.seed_count<>4)
    or (r.circuit='Junior' and r.main_draw_size in (24,32) and r.seed_count<>8)
    or (r.circuit='Junior' and r.main_draw_size in (48,64,96,128) and r.seed_count<>16)
  );

  -- Qualifying seed counts. Each section must have no more than two seeds.
  with q as (
    select t.id,t.circuit,t.category,
           coalesce(t.qualifying_draw_size,0) qdraw,
           coalesce((public.tournament_qualifying_structure(t.id)->>'seed_count')::int,0) seeds
    from public.tournaments t
    where coalesce(t.is_active,true)
      and t.start_date between p_from_date and p_to_date
      and coalesce(t.qualifying_draw_size,0)>0
      and t.circuit in ('ATP','Challenger','ITF')
  )
  select count(*) into v_qual_seed_mismatches
  from q
  where
    (circuit='ATP' and category='ATP 250' and qdraw=16 and seeds<>8)
    or (circuit='ATP' and category in ('ATP 500','Masters 1000') and qdraw=16 and seeds<>8)
    or (circuit='ATP' and category in ('ATP 500','Masters 1000') and qdraw=24 and seeds<>12)
    or (circuit='ATP' and category in ('ATP 500','Masters 1000') and qdraw=28 and seeds<>14)
    or (circuit='ATP' and category in ('ATP 500','Masters 1000') and qdraw=48 and seeds<>24)
    or (circuit='Challenger' and qdraw=24 and seeds<>12)
    or (circuit='ITF' and qdraw in (32,48,64) and seeds<>16)
    or (category='Grand Chelem' and seeds<>least(32,qdraw));

  -- Validate the reusable seed-slot engine on every bracket shape used by the game.
  with configs(bracket,seeds) as (
    values (16,4),(32,8),(64,16),(128,32)
  ),
  slots as (
    select c.bracket,c.seeds,s.seed,
           public.world_tournament_seed_slot_for_event(
             987654321+c.bracket,c.bracket,s.seed
           ) slot
    from configs c
    cross join lateral generate_series(1,c.seeds) s(seed)
  )
  select
    count(*) filter(where duplicate_slot),
    count(*) filter(where first_round_collision)
  into v_seed_slot_collisions,v_first_round_seed_collisions
  from (
    select a.bracket,a.seed,
      exists(
        select 1 from slots b
        where b.bracket=a.bracket and b.seed<>a.seed and b.slot=a.slot
      ) duplicate_slot,
      exists(
        select 1 from slots b
        where b.bracket=a.bracket and b.seed<>a.seed
          and ((b.slot-1)/2)=((a.slot-1)/2)
      ) first_round_collision
    from slots a
  ) x;

  -- Materialized pro singles draws must keep seeded players on the same official slot engine.
  select count(*) into v_materialized_seed_slot_mismatches
  from public.world_tournament_entries e
  join public.world_tournament_states s on s.tournament_id=e.tournament_id
  join public.tournaments t on t.id=e.tournament_id
  where t.start_date between p_from_date and p_to_date
    and e.seed is not null
    and e.draw_slot is distinct from public.world_tournament_seed_slot_for_event(
      t.id,s.bracket_size,e.seed
    );

  with all_positions as (
    select tournament_id,draw_slot,count(*) n
    from public.world_tournament_entries e
    join public.tournaments t on t.id=e.tournament_id
    where t.start_date between p_from_date and p_to_date and draw_slot is not null
    group by tournament_id,draw_slot
    having count(*)>1
    union all
    select tournament_id,draw_slot,count(*) n
    from public.world_doubles_tournament_entries e
    join public.tournaments t on t.id=e.tournament_id
    where t.start_date between p_from_date and p_to_date and draw_slot is not null
    group by tournament_id,draw_slot
    having count(*)>1
    union all
    select tournament_id,draw_position,count(*) n
    from public.ncaa_individual_entries e
    join public.tournaments t on t.id=e.tournament_id
    where t.start_date between p_from_date and p_to_date
      and e.discipline='singles' and draw_position is not null
    group by tournament_id,draw_position
    having count(*)>1
    union all
    select tournament_id,draw_position,count(*) n
    from public.ncaa_individual_doubles_entries e
    join public.tournaments t on t.id=e.tournament_id
    where t.start_date between p_from_date and p_to_date and draw_position is not null
    group by tournament_id,draw_position
    having count(*)>1
  )
  select count(*) into v_duplicate_draw_positions from all_positions;

  -- Materialized doubles use 4 seeds for 16, 8 for 24/28/32, 16 for Slam 64.
  with d as (
    select e.tournament_id,t.category,t.doubles_draw_size,
           count(*) filter(where e.seed is not null) seeds
    from public.world_doubles_tournament_entries e
    join public.tournaments t on t.id=e.tournament_id
    where t.start_date between p_from_date and p_to_date
    group by e.tournament_id,t.category,t.doubles_draw_size
  )
  select count(*) into v_bad_doubles_seed_counts
  from d
  where (doubles_draw_size=16 and seeds<>4)
     or (doubles_draw_size in (24,28,32) and seeds<>8)
     or (category='Grand Chelem' and doubles_draw_size=64 and seeds<>16);

  select count(*) into v_bad_ncaa_positions
  from (
    select e.tournament_id,e.player_id
    from public.ncaa_individual_entries e
    join public.tournaments t on t.id=e.tournament_id
    where t.start_date between p_from_date and p_to_date
      and e.discipline='singles'
      and e.draw_position is null
    union all
    select e.tournament_id,e.id
    from public.ncaa_individual_doubles_entries e
    join public.tournaments t on t.id=e.tournament_id
    where t.start_date between p_from_date and p_to_date
      and e.draw_position is null
  ) z;

  return jsonb_build_object(
    'ok',
      v_main_rule_mismatches=0
      and v_qual_seed_mismatches=0
      and v_seed_slot_collisions=0
      and v_first_round_seed_collisions=0
      and v_materialized_seed_slot_mismatches=0
      and v_duplicate_draw_positions=0
      and v_bad_doubles_seed_counts=0
      and v_bad_ncaa_positions=0,
    'main_rule_mismatches',v_main_rule_mismatches,
    'qualifying_seed_mismatches',v_qual_seed_mismatches,
    'seed_slot_collisions',v_seed_slot_collisions,
    'first_round_seed_collisions',v_first_round_seed_collisions,
    'materialized_seed_slot_mismatches',v_materialized_seed_slot_mismatches,
    'duplicate_draw_positions',v_duplicate_draw_positions,
    'bad_doubles_seed_counts',v_bad_doubles_seed_counts,
    'bad_ncaa_positions',v_bad_ncaa_positions,
    'model','CB-DRAW-INTEGRITY-v1',
    'from',p_from_date,'to',p_to_date
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.audit_unified_circuit_integrity(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  v_overlaps int:=0;
  v_top200_itf int:=0;
  v_doubles_only_singles int:=0;
  v_singles_only_doubles int:=0;
  v_bad_junior_age int:=0;
  v_missing_standard_formats int:=0;
  v_missing_prize_profiles int:=0;
  v_draw_audit jsonb;
begin
  with raw_commitments as (
    select e.player_id,'T:'||t.id::text event_key,t.id tournament_id,
           coalesce(t.qualifying_start_date,t.main_draw_start_date,t.start_date) start_date,
           coalesce(t.end_date,t.start_date) end_date
    from public.world_tournament_entries e
    join public.tournaments t on t.id=e.tournament_id
    where coalesce(t.end_date,t.start_date)>=p_from_date and t.start_date<=p_to_date
    union all
    select e.player_id,'T:'||t.id::text,t.id,
           coalesce(t.qualifying_start_date,t.start_date),
           coalesce(t.qualifying_end_date,t.main_draw_start_date,t.end_date,t.start_date)
    from public.world_tournament_qualifying_entries e
    join public.tournaments t on t.id=e.tournament_id
    where coalesce(t.qualifying_end_date,t.end_date,t.start_date)>=p_from_date
      and coalesce(t.qualifying_start_date,t.start_date)<=p_to_date
    union all
    select wp.player_a_id,'T:'||t.id::text,t.id,
           coalesce(t.qualifying_start_date,t.main_draw_start_date,t.start_date),
           coalesce(t.end_date,t.start_date)
    from public.world_doubles_tournament_entries e
    join public.world_doubles_partnerships wp on wp.id=e.pair_id
    join public.tournaments t on t.id=e.tournament_id
    where coalesce(t.end_date,t.start_date)>=p_from_date and t.start_date<=p_to_date
    union all
    select wp.player_b_id,'T:'||t.id::text,t.id,
           coalesce(t.qualifying_start_date,t.main_draw_start_date,t.start_date),
           coalesce(t.end_date,t.start_date)
    from public.world_doubles_tournament_entries e
    join public.world_doubles_partnerships wp on wp.id=e.pair_id
    join public.tournaments t on t.id=e.tournament_id
    where coalesce(t.end_date,t.start_date)>=p_from_date and t.start_date<=p_to_date
    union all
    select wp.player_a_id,'T:'||t.id::text,t.id,
           coalesce(t.qualifying_start_date,t.start_date),
           coalesce(t.qualifying_end_date,t.main_draw_start_date,t.end_date,t.start_date)
    from public.world_doubles_qualifying_entries e
    join public.world_doubles_partnerships wp on wp.id=e.pair_id
    join public.tournaments t on t.id=e.tournament_id
    where coalesce(t.qualifying_end_date,t.end_date,t.start_date)>=p_from_date
      and coalesce(t.qualifying_start_date,t.start_date)<=p_to_date
    union all
    select wp.player_b_id,'T:'||t.id::text,t.id,
           coalesce(t.qualifying_start_date,t.start_date),
           coalesce(t.qualifying_end_date,t.main_draw_start_date,t.end_date,t.start_date)
    from public.world_doubles_qualifying_entries e
    join public.world_doubles_partnerships wp on wp.id=e.pair_id
    join public.tournaments t on t.id=e.tournament_id
    where coalesce(t.qualifying_end_date,t.end_date,t.start_date)>=p_from_date
      and coalesce(t.qualifying_start_date,t.start_date)<=p_to_date

    union all
    select e.player_id,'T:'||t.id::text,t.id,t.start_date,coalesce(t.end_date,t.start_date)
    from public.junior_tournament_entries e
    join public.tournaments t on t.id=e.tournament_id
    where t.start_date>date '2025-12-01'
      and coalesce(t.end_date,t.start_date)>=p_from_date and t.start_date<=p_to_date
    union all
    select e.player_a_id,'T:'||t.id::text,t.id,t.start_date,coalesce(t.end_date,t.start_date)
    from public.world_junior_doubles_entries e
    join public.tournaments t on t.id=e.tournament_id
    where coalesce(t.end_date,t.start_date)>=p_from_date and t.start_date<=p_to_date
    union all
    select e.player_b_id,'T:'||t.id::text,t.id,t.start_date,coalesce(t.end_date,t.start_date)
    from public.world_junior_doubles_entries e
    join public.tournaments t on t.id=e.tournament_id
    where coalesce(t.end_date,t.start_date)>=p_from_date and t.start_date<=p_to_date
    union all
    select e.player_id,'T:'||t.id::text,t.id,t.start_date,coalesce(t.end_date,t.start_date)
    from public.ncaa_individual_entries e
    join public.tournaments t on t.id=e.tournament_id
    where coalesce(t.end_date,t.start_date)>=p_from_date and t.start_date<=p_to_date
    union all
    select e.player_a_id,'T:'||t.id::text,t.id,t.start_date,coalesce(t.end_date,t.start_date)
    from public.ncaa_individual_doubles_entries e
    join public.tournaments t on t.id=e.tournament_id
    where coalesce(t.end_date,t.start_date)>=p_from_date and t.start_date<=p_to_date
    union all
    select e.player_b_id,'T:'||t.id::text,t.id,t.start_date,coalesce(t.end_date,t.start_date)
    from public.ncaa_individual_doubles_entries e
    join public.tournaments t on t.id=e.tournament_id
    where coalesce(t.end_date,t.start_date)>=p_from_date and t.start_date<=p_to_date
  ),
  commitments as (
    select player_id,event_key,tournament_id,min(start_date) start_date,max(end_date) end_date
    from raw_commitments
    group by player_id,event_key,tournament_id
  )
  select count(*) into v_overlaps
  from commitments a
  join commitments b
    on a.player_id=b.player_id
   and a.event_key<b.event_key
   and daterange(a.start_date,a.end_date,'[]') && daterange(b.start_date,b.end_date,'[]');

  select count(*) into v_top200_itf
  from (
    select e.player_id,t.id,
           public.player_rank_at_date(e.player_id,coalesce(t.main_entry_deadline,t.start_date-21)) r
    from public.world_tournament_entries e
    join public.tournaments t on t.id=e.tournament_id
    where t.circuit='ITF' and t.category in ('M15','M25')
      and t.start_date between p_from_date and p_to_date
    union all
    select e.player_id,t.id,
           public.player_rank_at_date(e.player_id,coalesce(t.qualifying_entry_deadline,t.start_date-21))
    from public.world_tournament_qualifying_entries e
    join public.tournaments t on t.id=e.tournament_id
    where t.circuit='ITF' and t.category in ('M15','M25')
      and t.start_date between p_from_date and p_to_date
  ) x
  where x.r between 1 and 200;

  select count(*) into v_doubles_only_singles
  from (
    select distinct e.player_id
    from public.world_tournament_entries e
    join public.tournaments t on t.id=e.tournament_id
    join public.players p on p.id=e.player_id
    where t.start_date between p_from_date and p_to_date and p.career_focus='doubles_only'
    union
    select distinct e.player_id
    from public.world_tournament_qualifying_entries e
    join public.tournaments t on t.id=e.tournament_id
    join public.players p on p.id=e.player_id
    where t.start_date between p_from_date and p_to_date and p.career_focus='doubles_only'
  ) x;

  select count(*) into v_singles_only_doubles
  from (
    select wp.player_a_id player_id,t.id
    from public.world_doubles_tournament_entries e
    join public.world_doubles_partnerships wp on wp.id=e.pair_id
    join public.tournaments t on t.id=e.tournament_id
    join public.players p on p.id=wp.player_a_id
    where t.start_date between p_from_date and p_to_date and p.career_focus='singles_only'
    union all
    select wp.player_b_id,t.id
    from public.world_doubles_tournament_entries e
    join public.world_doubles_partnerships wp on wp.id=e.pair_id
    join public.tournaments t on t.id=e.tournament_id
    join public.players p on p.id=wp.player_b_id
    where t.start_date between p_from_date and p_to_date and p.career_focus='singles_only'
  ) x;

  select count(*) into v_bad_junior_age
  from public.junior_tournament_entries e
  join public.tournaments t on t.id=e.tournament_id
  join public.players p on p.id=e.player_id
  where t.circuit='Junior'
    and t.start_date>date '2025-12-01'
    and t.start_date between p_from_date and p_to_date
    and coalesce(
      case when p.birth_date is not null then extract(year from age(t.start_date,p.birth_date))::int end,
      p.age,99
    ) not between 13 and 18;

  select count(*) into v_missing_standard_formats
  from public.tournaments t
  where coalesce(t.is_active,true)=true
    and t.start_date between p_from_date and p_to_date
    and (
      t.circuit in ('ATP','Challenger','ITF')
      or (t.circuit='Junior' and t.category not in ('Junior Davis Cup','Junior Finals','Junior Double Finals'))
    )
    and t.category not in ('United Cup','Laver Cup','Davis Cup')
    and not exists(
      select 1 from public.tournament_format_rules r
      where r.circuit=t.circuit and r.category=t.category
        and r.main_draw_size=coalesce(t.singles_draw_size,t.draw_size)
    );

  select count(*) into v_missing_prize_profiles
  from public.tournaments t
  where coalesce(t.is_active,true)=true
    and t.start_date between p_from_date and p_to_date
    and t.circuit in ('ATP','Challenger','ITF')
    and t.category not in ('ATP Finals','Next Gen Finals','United Cup','Laver Cup')
    and (
      coalesce(t.singles_prize_by_result,'{}'::jsonb)='{}'::jsonb
      or (coalesce(t.doubles_draw_size,0)>0 and coalesce(t.doubles_prize_by_result,'{}'::jsonb)='{}'::jsonb)
    );

  v_draw_audit:=public.audit_draw_integrity(p_from_date,p_to_date);

  return jsonb_build_object(
    'ok',v_overlaps=0 and v_top200_itf=0 and v_doubles_only_singles=0
         and v_singles_only_doubles=0 and v_bad_junior_age=0
         and v_missing_standard_formats=0 and v_missing_prize_profiles=0
         and coalesce((v_draw_audit->>'ok')::boolean,false),
    'calendar_overlap_pairs',v_overlaps,
    'top200_itf_playdown_violations',v_top200_itf,
    'doubles_only_in_singles',v_doubles_only_singles,
    'singles_only_in_doubles',v_singles_only_doubles,
    'junior_age_violations',v_bad_junior_age,
    'missing_standard_format_rules',v_missing_standard_formats,
    'missing_prize_profiles',v_missing_prize_profiles,
    'draw_integrity',v_draw_audit,
    'historical_identity_debt_excluded_through','2025-12-01',
    'from',p_from_date,'to',p_to_date,
    'model','CB-UNIFIED-INTEGRITY-v4'
  );
end;
$function$;

comment on function public.audit_draw_integrity(date,date)
  is 'Court Boss draw audit: seed counts, qualifying seed counts, official seed slots, first-round separation, duplicate positions and NCAA draw coverage.';
comment on function public.player_doubles_seed_rank_at_date(bigint,date)
  is 'Actual doubles ranking for seeding at a date; protected/entry rankings are intentionally excluded.';
comment on function public.ncaa_assign_individual_draw_positions(bigint)
  is 'Assigns NCAA singles/doubles bracket positions with separated seeds, top-seed byes and deterministic public draw of unseeded entries.';
