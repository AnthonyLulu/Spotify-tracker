-- Court Boss progressive qualifying engine v6
-- Persists the qualifying draw, advances Q rounds on their calendar dates,
-- and only creates qualifiers / Lucky Losers after the final qualifying round.

alter table public.world_tournament_qualifying_entries
  add column if not exists seed integer,
  add column if not exists draw_pos integer,
  add column if not exists section_no integer;

create unique index if not exists world_qualifying_entries_tournament_draw_pos_key
  on public.world_tournament_qualifying_entries(tournament_id,draw_pos)
  where draw_pos is not null;

create table if not exists public.world_qualifying_states(
  tournament_id bigint primary key references public.tournaments(id) on delete cascade,
  rule_key text not null,
  status text not null default 'draw_prepared'
    check(status in ('draw_prepared','live','completed')),
  draw_size integer not null,
  bracket_total integer not null,
  qualifier_slots integer not null,
  rounds_count integer not null,
  section_bracket integer not null,
  draw_prepared_on date not null,
  current_round_no integer not null default 0,
  last_advanced_on date,
  finalized_on date,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.world_qualifying_states enable row level security;

create index if not exists idx_world_qualifying_states_status_date
  on public.world_qualifying_states(status,last_advanced_on);

CREATE OR REPLACE FUNCTION public.prepare_world_qualifying_tournament(p_tournament_id bigint, p_prepared_on date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  r public.tournament_format_rules%rowtype;
  qs jsonb;
  v_managed bigint;
  v_qdraw int;
  v_qslots int;
  v_qwc int;
  v_qda int;
  v_qseed_count int;
  v_section_players int;
  v_section_bracket int;
  v_bracket_total int;
  v_byes int;
  v_direct int;
  v_rounds int;
  v_round int;
  v_size int;
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
  v_loss_points int;
  v_q_points int;
  v_loss_prize numeric;
  v_matches int:=0;
  v_selected int:=0;
  v_upper int:=30000;
  v_seed_pos int;
  v_section int;
  rec record;
begin
  select * into t
  from public.tournaments
  where id=p_tournament_id and singles=true and coalesce(is_active,true)=true;

  if t.id is null then
    return jsonb_build_object('ok',false,'skipped','tournament_not_found');
  end if;

  select * into r
  from public.tournament_format_rules fr
  where fr.circuit=t.circuit
    and fr.category=t.category
    and fr.main_draw_size=coalesce(t.singles_draw_size,t.draw_size)
  order by
    case when fr.qualifying_draw_size=coalesce(t.qualifying_draw_size,fr.qualifying_draw_size) then 0 else 1 end,
    fr.updated_at desc
  limit 1;

  qs:=public.tournament_qualifying_structure(t.id);
  v_qdraw:=coalesce((qs->>'draw_size')::int,0);
  v_qslots:=coalesce((qs->>'qualifier_slots')::int,0);
  v_qwc:=coalesce((qs->>'wildcards')::int,0);
  v_qda:=coalesce((qs->>'direct_acceptances')::int,0);
  v_qseed_count:=coalesce((qs->>'seed_count')::int,0);
  v_section_players:=coalesce((qs->>'section_players')::int,0);
  v_section_bracket:=coalesce((qs->>'section_bracket')::int,0);
  v_bracket_total:=coalesce((qs->>'bracket_total')::int,0);
  v_byes:=greatest(0,v_bracket_total-v_qdraw);

  if v_qdraw<=0 or v_qslots<=0 then
    return jsonb_build_object('ok',true,'skipped','no_qualifying','tournament_id',t.id);
  end if;

  if exists(select 1 from public.world_qualifying_states s where s.tournament_id=t.id) then
    return jsonb_build_object(
      'ok',true,'existing',true,'tournament_id',t.id,
      'status',(select status from public.world_qualifying_states where tournament_id=t.id)
    );
  end if;

  if exists(select 1 from public.world_tournament_qualifiers q where q.tournament_id=t.id) then
    return jsonb_build_object(
      'ok',true,'already_simulated',true,'tournament_id',t.id,'status','completed',
      'qualifiers',(select count(*) from public.world_tournament_qualifiers q where q.tournament_id=t.id)
    );
  end if;

  v_rounds:=ceil(ln(v_section_bracket::numeric)/ln(2::numeric))::int;

  v_direct:=greatest(
    0,
    r.main_draw_size-r.qualifier_count-r.wildcard_count
      -coalesce(r.special_exempt_slots,0)
      -coalesce(t.late_entry_slots,0)
      -coalesce(r.junior_reserved_slots,0)
      -coalesce(r.junior_accelerator_slots,0)
      -coalesce(r.college_accelerator_slots,0)
  );

  if t.category='Grand Chelem' then v_upper:=650;
  elsif t.category='Masters 1000' then v_upper:=550;
  elsif t.category='ATP 500' then v_upper:=850;
  elsif t.category='ATP 250' then v_upper:=1400;
  elsif t.category='Challenger 175' then v_upper:=2200;
  elsif t.category='Challenger 125' then v_upper:=3000;
  elsif t.category='Challenger 100' then v_upper:=4500;
  elsif t.category='Challenger 75' then v_upper:=7000;
  elsif t.category='Challenger 50' then v_upper:=12000;
  else v_upper:=30000;
  end if;

  select managed_player_id into v_managed from public.career_state where id='demo';

  delete from public.world_tournament_matches
  where tournament_id=t.id and is_qualifying=true;
  delete from public.world_tournament_qualifying_entries where tournament_id=t.id;
  delete from public.world_tournament_lucky_losers where tournament_id=t.id;

  drop table if exists pg_temp.cb_q_accel;
  drop table if exists pg_temp.cb_q_candidates;
  drop table if exists pg_temp.cb_q_pool;
  drop table if exists pg_temp.cb_q_current;
  drop table if exists pg_temp.cb_q_next;
  drop table if exists pg_temp.cb_q_used_slots;

  create temporary table cb_q_accel(
    player_id bigint primary key,
    entry_method text not null
  ) on commit drop;

  if coalesce(r.junior_accelerator_slots,0)>0
     and t.circuit='Challenger'
     and t.category in ('Challenger 50','Challenger 75') then
    insert into cb_q_accel(player_id,entry_method)
    select x.player_id,'junior_accelerator_qualifying'
    from public.junior_accelerator_candidate_ids(t.id,'qualifying') x
    limit r.junior_accelerator_slots
    on conflict(player_id) do nothing;
  end if;

  if coalesce(r.college_accelerator_slots,0)>0
     and t.circuit='Challenger'
     and t.category in ('Challenger 50','Challenger 75') then
    insert into cb_q_accel(player_id,entry_method)
    select x.player_id,'college_accelerator_qualifying'
    from public.atp_college_accelerator_candidate_ids(t.id,'qualifying') x
    limit r.college_accelerator_slots
    on conflict(player_id) do nothing;
  end if;

  if coalesce(r.nextgen_accelerator_qual_slots,0)>0 then
    insert into cb_q_accel(player_id,entry_method)
    select x.player_id,'nextgen_accelerator_qualifying'
    from public.nextgen_accelerator_candidate_ids(t.id,'qualifying') x
    limit r.nextgen_accelerator_qual_slots
    on conflict(player_id) do nothing;
  end if;

  -- Challenger 50/75 qualifying composition allows two JAS/CAS positions total.
  if t.circuit='Challenger' and t.category in ('Challenger 50','Challenger 75') then
    delete from cb_q_accel q
    where q.player_id in (
      select z.player_id
      from (
        select
          q2.player_id,
          row_number() over(
            order by
              case
                when q2.entry_method='junior_accelerator_qualifying' then
                  coalesce((
                    select je.year_end_rank
                    from public.junior_accelerator_entitlements je
                    where je.season=extract(year from t.start_date)::int
                      and je.player_id=q2.player_id
                  ),11)*100
                when q2.entry_method='college_accelerator_qualifying' then
                  coalesce((
                    select ce.year_end_ita_rank
                    from public.atp_college_accelerator_entitlements ce
                    where ce.season=extract(year from t.start_date)::int
                      and ce.player_id=q2.player_id
                  ),11)*100
                else 999999
              end,
              q2.player_id
          ) rn
        from cb_q_accel q2
        where q2.entry_method in (
          'junior_accelerator_qualifying',
          'college_accelerator_qualifying'
        )
      ) z
      where z.rn>2
    );
  end if;

  create temporary table cb_q_candidates(
    player_id bigint primary key,
    name text not null,
    country text,
    effective_rank int not null,
    potential int,
    selection_score numeric not null,
    rn int not null
  ) on commit drop;

  insert into cb_q_candidates(
    player_id,name,country,effective_rank,potential,selection_score,rn
  )
  select player_id,name,country,effective_rank,potential,selection_score,rn
  from (
    select
      p.id player_id,
      p.name,
      p.country,
      coalesce(
        public.player_rank_at_date(
          p.id,
          coalesce(t.qualifying_entry_deadline,t.main_entry_deadline,t.start_date-21)
        ),
        case when p.ranking_current then p.ranking end,
        p.game_world_rank,p.ranking,999999
      )::int effective_rank,
      coalesce(p.potential,50)::int potential,
      (
        p.current_ability*.50+p.form*.09+p.fitness*.05-p.fatigue*.04+
        case
          when t.surface ilike 'Terre%' then coalesce(a.clay_affinity,10)*.38
          when t.surface ilike 'Gazon%' then coalesce(a.grass_affinity,10)*.38
          else coalesce(a.hard_affinity,10)*.38
        end+
        coalesce(a.decision_making,a.tactics,10)*.09+
        coalesce(public.player_psychology_modifier(p.id),0)*.40+
        (mod(abs(hashtext('qual|'||t.id::text||'|'||p.id::text)),1000)/1000.0)*3
      ) selection_score,
      row_number() over(
        order by coalesce(
          public.player_rank_at_date(
            p.id,
            coalesce(t.qualifying_entry_deadline,t.main_entry_deadline,t.start_date-21)
          ),
          case when p.ranking_current then p.ranking end,
          p.game_world_rank,p.ranking,999999
        ),
        p.current_ability desc,p.id
      )::int rn
    from public.players p
    left join public.player_attributes a on a.player_id=p.id
    where p.career_status='active'
      and p.id is distinct from v_managed
      and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
      and coalesce(p.career_focus,'mixed')<>'doubles_only'
      and p.injury_status='Fit'
      and coalesce(p.fitness,90)>=45
      and coalesce(p.fatigue,20)<=90
      and coalesce(
        public.player_rank_at_date(
          p.id,
          coalesce(t.qualifying_entry_deadline,t.main_entry_deadline,t.start_date-21)
        ),
        case when p.ranking_current then p.ranking end,
        p.game_world_rank,p.ranking,999999
      )<=v_upper
      and not exists(select 1 from cb_q_accel qa where qa.player_id=p.id)
      and (
        (public.tournament_entry_eligibility(p.id,t.id,'qualifying')->>'eligible')::boolean
        or
        (public.tournament_entry_eligibility(p.id,t.id,'qualifying_wildcard')->>'eligible')::boolean
      )
      and not (public.player_tournament_calendar_conflict(p.id,t.id,'qualifying')->>'conflict')::boolean
  ) ranked;

  create temporary table cb_q_pool(
    player_id bigint primary key,
    name text not null,
    country text,
    effective_rank int not null,
    selection_score numeric not null,
    entry_method text not null,
    seed_no int,
    draw_pos int
  ) on commit drop;

  insert into cb_q_pool(
    player_id,name,country,effective_rank,selection_score,entry_method
  )
  select p.id,p.name,p.country,
         coalesce(
           public.player_rank_at_date(
             p.id,
             coalesce(t.qualifying_entry_deadline,t.main_entry_deadline,t.start_date-21)
           ),
           case when p.ranking_current then p.ranking end,p.game_world_rank,p.ranking,999999
         )::int,
         1000000::numeric,
         qa.entry_method
  from cb_q_accel qa
  join public.players p on p.id=qa.player_id;

  -- Qualifying wild cards: favor home-country prospects and stronger local/young profiles,
  -- while still respecting the circuit's eligibility rules.
  if v_qwc>0 then
    insert into cb_q_pool(
      player_id,name,country,effective_rank,selection_score,entry_method
    )
    select c.player_id,c.name,c.country,c.effective_rank,c.selection_score,'qualifying_wildcard'
    from cb_q_candidates c
    where c.rn>v_direct
      and not exists(select 1 from cb_q_pool q where q.player_id=c.player_id)
      and (public.tournament_entry_eligibility(c.player_id,t.id,'qualifying_wildcard')->>'eligible')::boolean
    order by
      (c.country is not distinct from t.country) desc,
      c.potential desc,
      c.selection_score desc,
      c.effective_rank asc,
      c.player_id
    limit v_qwc;
  end if;

  insert into cb_q_pool(
    player_id,name,country,effective_rank,selection_score,entry_method
  )
  select c.player_id,c.name,c.country,c.effective_rank,c.selection_score,'qualifying'
  from cb_q_candidates c
  where c.rn>v_direct
    and not exists(select 1 from cb_q_pool q where q.player_id=c.player_id)
    and (public.tournament_entry_eligibility(c.player_id,t.id,'qualifying')->>'eligible')::boolean
  order by c.effective_rank,c.selection_score desc,c.player_id
  limit greatest(0,v_qdraw-(select count(*) from cb_q_pool));

  select count(*) into v_selected from cb_q_pool;
  if v_selected<>v_qdraw then
    return jsonb_build_object(
      'ok',false,'skipped','insufficient_qualifying_players',
      'required',v_qdraw,'selected',v_selected,'tournament_id',t.id,
      'qualifying_structure',qs
    );
  end if;

  -- Qualifying seeds use the most recent ranking list available for the draw.
  with ranked as (
    select player_id,
           row_number() over(
             order by public.player_rank_at_date(
               player_id,coalesce(t.qualifying_start_date,t.start_date)
             ),player_id
           )::int sn
    from cb_q_pool
  )
  update cb_q_pool q
  set seed_no=rk.sn
  from ranked rk
  where q.player_id=rk.player_id
    and rk.sn<=v_qseed_count;

  create temporary table cb_q_current(
    pos int primary key,
    player_id bigint
  ) on commit drop;
  create temporary table cb_q_next(
    pos int primary key,
    player_id bigint
  ) on commit drop;
  create temporary table cb_q_used_slots(
    pos int primary key
  ) on commit drop;

  insert into cb_q_current(pos,player_id)
  select g,null::bigint
  from generate_series(1,v_bracket_total) g;

  -- First seed in every qualifying section.
  for v_section in 1..least(v_qslots,v_qseed_count) loop
    v_seed_pos:=(v_section-1)*v_section_bracket+1;
    update cb_q_current c
    set player_id=q.player_id
    from cb_q_pool q
    where c.pos=v_seed_pos and q.seed_no=v_section;
    insert into cb_q_used_slots(pos) values(v_seed_pos) on conflict do nothing;
  end loop;

  -- Second seed in each section. The sections are deterministically shuffled
  -- so seed 1/2 etc. do not always receive the same opposite seed.
  for rec in
    select q.player_id,q.seed_no,
           row_number() over(
             order by md5('q-seed-bottom|'||t.id::text||'|'||q.player_id::text)
           )::int section_ord
    from cb_q_pool q
    where q.seed_no>v_qslots and q.seed_no<=least(v_qseed_count,v_qslots*2)
    order by q.seed_no
  loop
    v_section:=((rec.section_ord-1)%v_qslots)+1;
    v_seed_pos:=v_section*v_section_bracket;
    update cb_q_current set player_id=rec.player_id where pos=v_seed_pos;
    insert into cb_q_used_slots(pos) values(v_seed_pos) on conflict do nothing;
  end loop;

  -- For non-power-of-two section sizes (notably ITF 48Q), distribute byes
  -- beside the seeded positions first.
  if v_byes>0 then
    for v_section in 1..v_qslots loop
      if v_byes<=0 then exit; end if;
      v_seed_pos:=(v_section-1)*v_section_bracket+2;
      if not exists(select 1 from cb_q_used_slots where pos=v_seed_pos) then
        insert into cb_q_used_slots(pos) values(v_seed_pos) on conflict do nothing;
        v_byes:=v_byes-1;
      end if;

      if v_byes<=0 then exit; end if;
      v_seed_pos:=v_section*v_section_bracket-1;
      if not exists(select 1 from cb_q_used_slots where pos=v_seed_pos) then
        insert into cb_q_used_slots(pos) values(v_seed_pos) on conflict do nothing;
        v_byes:=v_byes-1;
      end if;
    end loop;
  end if;

  -- Place unseeded players into the remaining non-bye slots.
  with available as (
    select c.pos,
           row_number() over(
             order by md5('q-slot|'||t.id::text||'|'||c.pos::text)
           )::int rn
    from cb_q_current c
    where c.player_id is null
      and not exists(select 1 from cb_q_used_slots u where u.pos=c.pos)
  ),
  unplaced as (
    select q.player_id,
           row_number() over(
             order by md5('q-player|'||t.id::text||'|'||q.player_id::text)
           )::int rn
    from cb_q_pool q
    where not exists(select 1 from cb_q_current c where c.player_id=q.player_id)
  )
  update cb_q_current c
  set player_id=u.player_id
  from available a
  join unplaced u using(rn)
  where c.pos=a.pos;


  update cb_q_pool q
  set draw_pos=c.pos
  from cb_q_current c
  where c.player_id=q.player_id;

  if exists(select 1 from cb_q_pool where draw_pos is null) then
    return jsonb_build_object(
      'ok',false,'skipped','qualifying_draw_slot_assignment_failed',
      'tournament_id',t.id
    );
  end if;

  insert into public.world_tournament_qualifying_entries(
    tournament_id,player_id,entry_method,ranking_at_entry,
    result_code,result_label,qualified,points_awarded,
    prize_awarded,prize_currency,prize_is_estimate,
    last_opponent_id,last_opponent_name,last_score,
    simulated_on,source_label,seed,draw_pos,section_no
  )
  select
    t.id,q.player_id,q.entry_method,q.effective_rank,
    'Q0','Qualifications · tableau',false,0,
    0,coalesce(t.prize_currency,'USD'),
    coalesce(t.qualifying_prize_is_estimate,t.prize_breakdown_is_estimate,true),
    null,null,null,null,
    'Court Boss progressive qualifying draw · '||coalesce(r.rule_key,'Q'),
    q.seed_no,q.draw_pos,
    ceil(q.draw_pos::numeric/greatest(1,v_section_bracket)::numeric)::int
  from cb_q_pool q;

  insert into public.world_qualifying_states(
    tournament_id,rule_key,status,draw_size,bracket_total,qualifier_slots,
    rounds_count,section_bracket,draw_prepared_on,current_round_no,
    last_advanced_on,metadata,updated_at
  ) values(
    t.id,r.rule_key,'draw_prepared',v_qdraw,v_bracket_total,v_qslots,
    v_rounds,v_section_bracket,p_prepared_on,0,null,
    jsonb_build_object(
      'seed_count',v_qseed_count,
      'wildcards',v_qwc,
      'byes',greatest(0,v_bracket_total-v_qdraw),
      'qualifying_start',t.qualifying_start_date,
      'qualifying_end',t.qualifying_end_date,
      'model','CB-MATCH-v6-PROGRESSIVE-Q'
    ),now()
  )
  on conflict(tournament_id) do update set
    rule_key=excluded.rule_key,status='draw_prepared',draw_size=excluded.draw_size,
    bracket_total=excluded.bracket_total,qualifier_slots=excluded.qualifier_slots,
    rounds_count=excluded.rounds_count,section_bracket=excluded.section_bracket,
    draw_prepared_on=excluded.draw_prepared_on,current_round_no=0,
    last_advanced_on=null,metadata=excluded.metadata,updated_at=now();

  insert into public.world_tournament_matches(
    tournament_id,round_no,round_code,group_name,match_no,
    player_a_id,player_b_id,winner_id,loser_id,score,best_of,
    player_a_win_probability,court_speed,model_version,matchup_components,
    simulated_on,is_qualifying
  )
  select
    t.id,-1,'Q1',
    'Q Section '||ceil(g::numeric/greatest(1,v_section_bracket)::numeric)::int,
    ((g+1)/2)::int,
    a.player_id,b.player_id,null,null,null,3,null,
    coalesce(t.court_speed,case
      when t.surface ilike 'Terre%' then .68
      when t.surface ilike 'Gazon%' then 1.15
      when coalesce(t.indoor,false) then 1.18 else 1.0 end),
    'CB-MATCH-v6-PROGRESSIVE-Q-SCHEDULED',
    jsonb_build_object(
      'phase','qualifying','status','scheduled',
      'entry_a',a.entry_method,'entry_b',b.entry_method
    ),
    coalesce(t.qualifying_start_date,t.start_date-1),
    true
  from generate_series(1,v_bracket_total,2) g
  left join public.world_tournament_qualifying_entries a
    on a.tournament_id=t.id and a.draw_pos=g
  left join public.world_tournament_qualifying_entries b
    on b.tournament_id=t.id and b.draw_pos=g+1
  where a.player_id is not null or b.player_id is not null
  on conflict(tournament_id,round_no,match_no) do nothing;

  return jsonb_build_object(
    'ok',true,'tournament_id',t.id,'name',t.name,
    'draw',v_qdraw,'bracket_total',v_bracket_total,
    'qualifier_slots',v_qslots,'rounds',v_rounds,
    'draw_prepared_on',p_prepared_on,'status','draw_prepared',
    'model','CB-MATCH-v6-PROGRESSIVE-Q'
  );
end;
$function$

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
begin
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
            simulated_on=v_round_date
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
$function$

CREATE OR REPLACE FUNCTION public.simulate_world_qualifying_full(p_tournament_id bigint, p_simulated_on date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  v_prepare jsonb;
  v_advance jsonb;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null then
    return jsonb_build_object('ok',false,'skipped','tournament_not_found');
  end if;

  v_prepare:=public.prepare_world_qualifying_tournament(
    t.id,least(p_simulated_on,coalesce(t.qualifying_signin_date,t.qualifying_start_date,t.start_date-1,p_simulated_on))
  );
  if coalesce(v_prepare->>'skipped','')='no_qualifying' then return v_prepare; end if;
  if coalesce((v_prepare->>'ok')::boolean,false)=false then return v_prepare; end if;

  v_advance:=public.advance_world_qualifying_tournament(t.id,p_simulated_on);
  return coalesce(v_advance,'{}'::jsonb)
    ||jsonb_build_object('prepare',v_prepare,'compatibility_wrapper',true);
end;
$function$

CREATE OR REPLACE FUNCTION public.simulate_world_qualifying_window(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t record;
  v_prepare jsonb;
  v_advance jsonb;
  v_prepared integer:=0;
  v_advanced integer:=0;
  v_completed integer:=0;
  v_matches integer:=0;
  v_skipped integer:=0;
  v_draw_date date;
begin
  if p_to_date<=date '2025-12-01' then
    return jsonb_build_object('qualifying_prepared',0,'historical_cutoff',true);
  end if;

  for t in
    select x.*
    from public.tournaments x
    where x.singles=true
      and coalesce(x.is_active,true)=true
      and coalesce(x.circuit,'') in ('ATP','Challenger','ITF')
      and coalesce(x.qualifying_draw_size,0)>0
      and coalesce(x.qualifying_end_date,x.start_date-1)>=greatest(p_from_date,date '2025-12-01')
      and coalesce(x.qualifying_signin_date,x.qualifying_start_date,x.start_date-1)<=p_to_date
    order by coalesce(x.qualifying_start_date,x.start_date-1),x.id
    limit 240
  loop
    v_draw_date:=coalesce(t.qualifying_signin_date,t.qualifying_start_date,t.start_date-1);

    if not exists(select 1 from public.world_qualifying_states s where s.tournament_id=t.id)
       and not exists(select 1 from public.world_tournament_qualifiers q where q.tournament_id=t.id)
       and v_draw_date<=p_to_date then
      v_prepare:=public.prepare_world_qualifying_tournament(t.id,v_draw_date);
      if coalesce((v_prepare->>'ok')::boolean,false) then
        v_prepared:=v_prepared+1;
      else
        v_skipped:=v_skipped+1;
        continue;
      end if;
    end if;

    if exists(select 1 from public.world_qualifying_states s where s.tournament_id=t.id) then
      v_advance:=public.advance_world_qualifying_tournament(t.id,p_to_date);
      if coalesce((v_advance->>'ok')::boolean,false) then
        if coalesce((v_advance->>'rounds_advanced')::int,0)>0 then v_advanced:=v_advanced+1; end if;
        v_matches:=v_matches+coalesce((v_advance->>'matches_played')::int,0);
        if v_advance->>'status'='completed' then v_completed:=v_completed+1; end if;
      else
        v_skipped:=v_skipped+1;
      end if;
    end if;
  end loop;

  return jsonb_build_object(
    'qualifying_prepared',v_prepared,
    'qualifying_advanced',v_advanced,
    'qualifying_completed',v_completed,
    'matches_played',v_matches,
    'skipped',v_skipped,
    'from',p_from_date,'to',p_to_date,
    'model','CB-MATCH-v6-PROGRESSIVE-Q'
  );
end;
$function$
