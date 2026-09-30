
create table if not exists public.world_tournament_acceptance_states(
  tournament_id bigint primary key references public.tournaments(id) on delete cascade,
  frozen_on date not null,
  direct_slots integer not null,
  alternate_slots integer not null,
  status text not null default 'frozen' check(status in ('frozen','active','closed')),
  last_refreshed_on date,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.world_tournament_acceptance_states enable row level security;

create table if not exists public.world_tournament_acceptance_entries(
  tournament_id bigint not null references public.tournaments(id) on delete cascade,
  player_id bigint not null references public.players(id) on delete cascade,
  list_group text not null check(list_group in ('main','alternate')),
  acceptance_order integer not null,
  effective_rank integer,
  status text not null check(status in ('accepted','alternate','promoted','withdrawn')),
  entry_method text not null default 'direct',
  snapshot_date date not null,
  promoted_on date,
  withdrawn_on date,
  withdrawal_phase text,
  withdrawal_reason text,
  source_label text not null default 'Court Boss frozen acceptance list',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key(tournament_id,player_id)
);
alter table public.world_tournament_acceptance_entries enable row level security;

create unique index if not exists world_acceptance_list_order_key
  on public.world_tournament_acceptance_entries(tournament_id,list_group,acceptance_order);
create index if not exists idx_world_acceptance_status
  on public.world_tournament_acceptance_entries(tournament_id,status,acceptance_order);

CREATE OR REPLACE FUNCTION public.prepare_world_tournament_acceptance_list(
  p_tournament_id bigint,
  p_frozen_on date DEFAULT CURRENT_DATE
)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  r public.tournament_format_rules%rowtype;
  v_managed bigint;
  v_direct integer;
  v_alt integer;
  v_extra_wc integer:=0;
  v_reserved integer:=0;
  v_count integer:=0;
begin
  select * into t from public.tournaments
  where id=p_tournament_id and singles=true and coalesce(is_active,true)=true;
  if t.id is null then
    return jsonb_build_object('ok',false,'skipped','tournament_not_found');
  end if;
  if coalesce(t.circuit,'') not in ('ATP','Challenger','ITF')
     or coalesce(t.category,'') in ('United Cup','Laver Cup','Davis Cup','Junior Davis Cup') then
    return jsonb_build_object('ok',true,'skipped','unsupported_acceptance_event','tournament_id',t.id);
  end if;

  if exists(select 1 from public.world_tournament_acceptance_states s where s.tournament_id=t.id) then
    return jsonb_build_object(
      'ok',true,'existing',true,'tournament_id',t.id,
      'direct_slots',(select direct_slots from public.world_tournament_acceptance_states where tournament_id=t.id),
      'alternates',(select count(*) from public.world_tournament_acceptance_entries where tournament_id=t.id and list_group='alternate')
    );
  end if;

  select * into r from public.tournament_format_rules fr
  where fr.circuit=t.circuit and fr.category=t.category
    and fr.main_draw_size=coalesce(t.singles_draw_size,t.draw_size)
  limit 1;
  if r.rule_key is null or r.format_type<>'knockout' then
    return jsonb_build_object('ok',false,'skipped','missing_or_non_knockout_rule','tournament_id',t.id);
  end if;

  if coalesce(r.conditional_wildcard_rule,'')='ATP500_A_PLUS'
     and coalesce(r.wildcard_count_max,r.wildcard_count)>coalesce(r.wildcard_count,0) then
    v_extra_wc:=1;
  end if;

  v_reserved:=
    coalesce(r.qualifier_count,0)+coalesce(r.wildcard_count,0)+v_extra_wc+
    coalesce(r.special_exempt_slots,0)+coalesce(t.late_entry_slots,0)+
    coalesce(r.junior_reserved_slots,0)+coalesce(r.junior_accelerator_slots,0)+
    coalesce(r.college_accelerator_slots,0)+coalesce(r.nextgen_accelerator_main_slots,0);

  v_direct:=greatest(0,r.main_draw_size-v_reserved);
  v_alt:=greatest(40,least(160,greatest(1,v_direct)*3));

  select managed_player_id into v_managed from public.career_state where id='demo';

  with candidate_pool as (
    select
      c.player_id,c.effective_rank,p.current_ability,
      row_number() over(order by c.effective_rank,p.current_ability desc,c.player_id)::int rn
    from public.tournament_candidate_player_ids(
      t.id,'direct',least(2000,v_direct+v_alt+240)
    ) c
    join public.players p on p.id=c.player_id
    where c.player_id is distinct from v_managed
      and public.ai_player_commits_to_tournament(c.player_id,t.id)
      and not (public.player_tournament_calendar_conflict(c.player_id,t.id,'direct')->>'conflict')::boolean
  )
  insert into public.world_tournament_acceptance_entries(
    tournament_id,player_id,list_group,acceptance_order,effective_rank,
    status,entry_method,snapshot_date,source_label
  )
  select
    t.id,cp.player_id,
    case when cp.rn<=v_direct then 'main' else 'alternate' end,
    case when cp.rn<=v_direct then cp.rn else cp.rn-v_direct end,
    cp.effective_rank,
    case when cp.rn<=v_direct then 'accepted' else 'alternate' end,
    'direct',p_frozen_on,
    'Court Boss frozen original acceptance list · '||r.rule_key
  from candidate_pool cp
  where cp.rn<=v_direct+v_alt
  order by cp.rn;

  get diagnostics v_count=row_count;

  insert into public.world_tournament_acceptance_states(
    tournament_id,frozen_on,direct_slots,alternate_slots,status,last_refreshed_on,metadata,updated_at
  ) values(
    t.id,p_frozen_on,v_direct,
    (select count(*) from public.world_tournament_acceptance_entries where tournament_id=t.id and list_group='alternate'),
    'frozen',p_frozen_on,
    jsonb_build_object(
      'rule_key',r.rule_key,'main_draw_size',r.main_draw_size,
      'qualifier_slots',coalesce(r.qualifier_count,0),
      'wildcard_slots',coalesce(r.wildcard_count,0)+v_extra_wc,
      'reserved_non_da_slots',v_reserved,
      'model','CB-ACCEPTANCE-v1'
    ),now()
  );

  return jsonb_build_object(
    'ok',true,'tournament_id',t.id,'name',t.name,
    'frozen_on',p_frozen_on,'direct_slots',v_direct,
    'alternates',(select count(*) from public.world_tournament_acceptance_entries where tournament_id=t.id and list_group='alternate'),
    'rows',v_count,'model','CB-ACCEPTANCE-v1'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.refresh_world_tournament_acceptance_list(
  p_tournament_id bigint,
  p_date date DEFAULT CURRENT_DATE
)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  st public.world_tournament_acceptance_states%rowtype;
  v_q_start date;
  v_needed integer:=0;
  v_withdrawn integer:=0;
  v_promoted integer:=0;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  select * into st from public.world_tournament_acceptance_states where tournament_id=p_tournament_id;
  if t.id is null or st.tournament_id is null then
    return jsonb_build_object('ok',false,'skipped','acceptance_list_missing','tournament_id',p_tournament_id);
  end if;

  v_q_start:=coalesce(t.qualifying_start_date,t.main_draw_start_date,t.start_date);

  with unavailable as (
    select
      a.player_id,a.status,
      case
        when p.career_status<>'active' then 'career_unavailable'
        when exists(
          select 1 from public.injuries i
          where i.player_id=p.id and lower(coalesce(i.status,''))='active'
            and i.expected_return>=coalesce(t.main_draw_start_date,t.start_date)
        ) then 'injury'
        when p_date>=v_q_start-3 and (coalesce(p.fitness,90)<45 or coalesce(p.fatigue,20)>92) then 'condition'
        when (public.player_tournament_calendar_conflict(p.id,t.id,'direct')->>'conflict')::boolean then 'calendar_conflict'
        when p_date>=coalesce(t.withdrawal_deadline,t.singles_withdrawal_deadline,st.frozen_on)
             and not public.ai_player_commits_to_tournament(p.id,t.id) then 'schedule_withdrawal'
        else null
      end reason
    from public.world_tournament_acceptance_entries a
    join public.players p on p.id=a.player_id
    where a.tournament_id=t.id
      and a.status in ('accepted','promoted','alternate')
  )
  update public.world_tournament_acceptance_entries a
  set status='withdrawn',
      withdrawn_on=p_date,
      withdrawal_phase=case
        when a.status='alternate' then 'alternate_unavailable'
        when p_date<v_q_start then 'pre_q'
        else 'post_q'
      end,
      withdrawal_reason=u.reason,
      updated_at=now()
  from unavailable u
  where a.tournament_id=t.id and a.player_id=u.player_id
    and u.reason is not null
    and a.status<>'withdrawn';

  get diagnostics v_withdrawn=row_count;

  if p_date<v_q_start then
    select greatest(
      0,st.direct_slots-count(*)
    ) into v_needed
    from public.world_tournament_acceptance_entries a
    where a.tournament_id=t.id and a.status in ('accepted','promoted');

    if v_needed>0 then
      with picks as (
        select a.player_id
        from public.world_tournament_acceptance_entries a
        join public.players p on p.id=a.player_id
        where a.tournament_id=t.id
          and a.status='alternate'
          and p.career_status='active'
          and coalesce(p.injury_status,'Fit')='Fit'
          and coalesce(p.fitness,90)>=45
          and coalesce(p.fatigue,20)<=92
          and (public.tournament_entry_eligibility(p.id,t.id,'direct')->>'eligible')::boolean
          and not (public.player_tournament_calendar_conflict(p.id,t.id,'direct')->>'conflict')::boolean
        order by a.acceptance_order,a.effective_rank,a.player_id
        limit v_needed
      )
      update public.world_tournament_acceptance_entries a
      set status='promoted',promoted_on=p_date,entry_method='alternate',
          source_label='Court Boss original acceptance list · ALT promoted before qualifying',
          updated_at=now()
      where a.tournament_id=t.id
        and a.player_id in (select player_id from picks);

      get diagnostics v_promoted=row_count;
    end if;
  end if;

  update public.world_tournament_acceptance_states
  set status='active',last_refreshed_on=p_date,updated_at=now(),
      metadata=metadata||jsonb_build_object(
        'last_withdrawals',v_withdrawn,
        'last_alt_promotions',v_promoted,
        'post_q_vacancies',public.world_acceptance_postq_vacancy_count(t.id)
      )
  where tournament_id=t.id;

  return jsonb_build_object(
    'ok',true,'tournament_id',t.id,'date',p_date,
    'withdrawn',v_withdrawn,'alt_promoted',v_promoted,
    'post_q_vacancies',public.world_acceptance_postq_vacancy_count(t.id),
    'model','CB-ACCEPTANCE-v1'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.world_acceptance_postq_vacancy_count(p_tournament_id bigint)
RETURNS integer
LANGUAGE sql
STABLE
SET search_path TO 'public'
AS $function$
  select count(*)::int
  from public.world_tournament_acceptance_entries a
  where a.tournament_id=p_tournament_id
    and a.status='withdrawn'
    and a.withdrawal_phase='post_q'
    and (a.list_group='main' or a.promoted_on is not null);
$function$;

CREATE OR REPLACE FUNCTION public.refresh_world_acceptance_window(
  p_from_date date,
  p_to_date date
)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path TO 'public'
AS $function$
declare
  t record;
  v_deadline date;
  v_prepare jsonb;
  v_refresh jsonb;
  v_prepared integer:=0;
  v_refreshed integer:=0;
  v_promoted integer:=0;
  v_withdrawn integer:=0;
  v_skipped integer:=0;
begin
  for t in
    select x.*
    from public.tournaments x
    where x.singles=true and coalesce(x.is_active,true)=true
      and coalesce(x.circuit,'') in ('ATP','Challenger','ITF')
      and coalesce(x.category,'') not in ('United Cup','Laver Cup','Davis Cup','Junior Davis Cup')
      and x.start_date>date '2025-12-01'
      and x.start_date>=greatest(date '2025-12-01',p_from_date-14)
      and x.start_date<=p_to_date+84
    order by x.start_date,x.id
    limit 320
  loop
    v_deadline:=coalesce(t.main_entry_deadline,t.singles_entry_deadline,t.deadline,t.start_date-21);

    if v_deadline<=p_to_date
       and not exists(select 1 from public.world_tournament_acceptance_states s where s.tournament_id=t.id) then
      v_prepare:=public.prepare_world_tournament_acceptance_list(t.id,v_deadline);
      if coalesce((v_prepare->>'ok')::boolean,false) then v_prepared:=v_prepared+1;
      else v_skipped:=v_skipped+1; continue;
      end if;
    end if;

    if exists(select 1 from public.world_tournament_acceptance_states s where s.tournament_id=t.id) then
      v_refresh:=public.refresh_world_tournament_acceptance_list(t.id,p_to_date);
      if coalesce((v_refresh->>'ok')::boolean,false) then
        v_refreshed:=v_refreshed+1;
        v_promoted:=v_promoted+coalesce((v_refresh->>'alt_promoted')::int,0);
        v_withdrawn:=v_withdrawn+coalesce((v_refresh->>'withdrawn')::int,0);
      else
        v_skipped:=v_skipped+1;
      end if;
    end if;
  end loop;

  return jsonb_build_object(
    'prepared',v_prepared,'refreshed',v_refreshed,
    'withdrawn',v_withdrawn,'alternates_promoted',v_promoted,
    'skipped',v_skipped,'from',p_from_date,'to',p_to_date,
    'model','CB-ACCEPTANCE-v1'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.prepare_world_knockout_tournament(p_tournament_id bigint, p_prepared_on date DEFAULT CURRENT_DATE)
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

  if exists(select 1 from public.world_tournament_states s where s.tournament_id=t.id) then
    return jsonb_build_object('ok',true,'existing',true,'tournament_id',t.id,'status',
      (select status from public.world_tournament_states where tournament_id=t.id));
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

  perform public.prepare_world_tournament_acceptance_list(
    t.id,coalesce(t.main_entry_deadline,t.singles_entry_deadline,t.deadline,t.start_date-21)
  );
  perform public.refresh_world_tournament_acceptance_list(t.id,p_prepared_on);

  if exists(
    select 1 from public.world_tournament_acceptance_entries a
    where a.tournament_id=t.id and a.status in ('accepted','promoted')
  ) then
    insert into cb_entries_work(player_id,name,country,entry_method,ranking_at_entry)
    select c.player_id,c.name,c.country,'direct',a.effective_rank
    from public.world_tournament_acceptance_entries a
    join cb_candidates c on c.player_id=a.player_id
    where a.tournament_id=t.id
      and a.status in ('accepted','promoted')
      and not exists(select 1 from cb_entries_work e where e.player_id=c.player_id)
      and not exists(select 1 from cb_a_plus_wc aw where aw.player_id=c.player_id)
      and (public.tournament_entry_eligibility(c.player_id,t.id,'direct')->>'eligible')::boolean
      and not (public.player_tournament_calendar_conflict(c.player_id,t.id,'direct')->>'conflict')::boolean
    order by
      case when a.list_group='main' then 0 else 1 end,
      a.acceptance_order,c.player_id
    limit v_direct;
  else
    insert into cb_entries_work(player_id,name,country,entry_method,ranking_at_entry)
    select c.player_id,c.name,c.country,'direct',c.effective_rank
    from cb_candidates c
    where not exists(select 1 from cb_entries_work e where e.player_id=c.player_id)
      and not exists(select 1 from cb_a_plus_wc aw where aw.player_id=c.player_id)
      and (public.tournament_entry_eligibility(c.player_id,t.id,'direct')->>'eligible')::boolean
      and not (public.player_tournament_calendar_conflict(c.player_id,t.id,'direct')->>'conflict')::boolean
    order by c.effective_rank asc,c.selection_score desc,c.player_id
    limit v_direct;
  end if;

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
      and coalesce(p.injury_status,'Fit')='Fit'
      and not exists(
        select 1 from public.tournament_forfeits tf
        where tf.tournament_id=t.id and tf.player_id=q.player_id
      )
    order by q.qualifier_slot
    limit r.qualifier_count;

    select greatest(
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
    ) into v_needed;

    if v_needed>0 then
      perform public.refresh_world_tournament_lucky_losers(t.id,v_needed);

      insert into cb_entries_work(
        player_id,name,country,entry_method,ranking_at_entry,qualifying_points
      )
      select ll.player_id,p.name,p.country,'lucky_loser',ll.ranking_at_seeding,
             coalesce((r.qualifying_points->>ll.loss_round_code)::int,0)
      from public.world_tournament_lucky_losers ll
      join public.players p on p.id=ll.player_id
      where ll.tournament_id=t.id
        and not exists(select 1 from cb_entries_work e where e.player_id=ll.player_id)
        and coalesce(p.injury_status,'Fit')='Fit'
        and not exists(
          select 1 from public.tournament_forfeits tf
          where tf.tournament_id=t.id and tf.player_id=ll.player_id
        )
      order by ll.ll_order
      limit v_needed;

      update public.world_tournament_lucky_losers ll
      set selected=true
      where ll.tournament_id=t.id
        and exists(
          select 1 from cb_entries_work e
          where e.player_id=ll.player_id and e.entry_method='lucky_loser'
        );
    end if;

    select greatest(
      0,
      r.qualifier_count-(
        select count(*) from cb_entries_work
        where entry_method in (
          'qualifier',
          'junior_accelerator_qualifier',
          'college_accelerator_qualifier',
          'nextgen_accelerator_qualifier',
          'lucky_loser'
        )
      )
    ) into v_needed;

    if v_needed>0 then
      insert into cb_entries_work(
        player_id,name,country,entry_method,ranking_at_entry,qualifying_points
      )
      select c.player_id,c.name,c.country,'alternate',c.effective_rank,0
      from cb_candidates c
      where not exists(select 1 from cb_entries_work e where e.player_id=c.player_id)
        and (public.tournament_entry_eligibility(c.player_id,t.id,'qualifying')->>'eligible')::boolean
        and not exists(
          select 1 from public.tournament_forfeits tf
          where tf.tournament_id=t.id and tf.player_id=c.player_id
        )
      order by c.effective_rank asc,c.selection_score desc,c.player_id
      limit v_needed;
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
  v_ll_vacancies:=greatest(
    public.world_postq_direct_vacancy_count(t.id,v_direct),
    public.world_acceptance_postq_vacancy_count(t.id)
  );
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

    if v_ll_inserted<v_ll_vacancies and t.circuit='Challenger' then
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
    where not (
      t.circuit='ITF'
      and entry_method in (
        'qualifier','junior_accelerator_qualifier','college_accelerator_qualifier',
        'nextgen_accelerator_qualifier','lucky_loser'
      )
    )
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

  -- ITF main draws keep Qualifier/Lucky-Loser positions distinct.
  -- The Q/LL positions themselves are drawn, then successful qualifiers/LLs
  -- are randomly assigned to those positions with no section pre-designation.
  if t.circuit='ITF' then
    create temporary table cb_itf_q_slots(slot integer primary key) on commit drop;

    insert into cb_itf_q_slots(slot)
    select a.slot
    from cb_available_slots a
    order by md5('itf-q-position-v1|'||t.id::text||'|'||a.slot::text)
    limit (
      select count(*)
      from cb_entries_work e
      where e.draw_slot is null
        and e.entry_method in (
          'qualifier','junior_accelerator_qualifier','college_accelerator_qualifier',
          'nextgen_accelerator_qualifier','lucky_loser'
        )
    );

    with q_players as (
      select e.player_id,row_number() over(
        order by md5('itf-q-player-v1|'||t.id::text||'|'||e.player_id::text)
      ) rn
      from cb_entries_work e
      where e.draw_slot is null
        and e.entry_method in (
          'qualifier','junior_accelerator_qualifier','college_accelerator_qualifier',
          'nextgen_accelerator_qualifier','lucky_loser'
        )
    ),
    q_slots as (
      select s.slot,row_number() over(
        order by md5('itf-q-slot-v1|'||t.id::text||'|'||s.slot::text)
      ) rn
      from cb_itf_q_slots s
    )
    update cb_entries_work e
    set draw_slot=s.slot
    from q_players p
    join q_slots s using(rn)
    where e.player_id=p.player_id;

    delete from cb_available_slots a
    where exists(select 1 from cb_itf_q_slots q where q.slot=a.slot);
  end if;

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


  delete from public.world_tournament_matches
  where tournament_id=t.id and coalesce(is_qualifying,false)=false;
  delete from public.world_tournament_entries where tournament_id=t.id;

  insert into public.world_tournament_entries(
    tournament_id,player_id,seed,draw_slot,entry_method,ranking_at_entry,had_bye,
    matches_won,result_code,result_label,points_awarded,qualifying_points,
    last_opponent_id,last_opponent_name,last_score,simulated_on,source_label
  )
  select
    t.id,player_id,seed,draw_slot,entry_method,ranking_at_entry,had_bye,
    0,null,null,0,qualifying_points,
    null,null,null,p_prepared_on,
    'Court Boss progressive draw · '||r.rule_key
  from cb_entries_work;

  insert into public.world_tournament_states(
    tournament_id,rule_key,status,draw_size,bracket_size,rounds_count,
    draw_prepared_on,current_round_no,last_advanced_on,metadata,updated_at
  ) values(
    t.id,r.rule_key,'draw_prepared',v_main,v_bracket,v_rounds,
    p_prepared_on,0,p_prepared_on,
    jsonb_build_object(
      'byes',v_byes+v_pb_count,
      'performance_byes',v_pb_count,
      'pathway_entries',(select count(*) from cb_pathway_entries),
      'lucky_losers_inserted',v_ll_inserted,
      'model','CB-MATCH-v5-PROGRESSIVE'
    ),
    now()
  )
  on conflict(tournament_id) do update set
    rule_key=excluded.rule_key,status=excluded.status,draw_size=excluded.draw_size,
    bracket_size=excluded.bracket_size,rounds_count=excluded.rounds_count,
    draw_prepared_on=excluded.draw_prepared_on,current_round_no=0,
    last_advanced_on=excluded.last_advanced_on,metadata=excluded.metadata,updated_at=now();

  return jsonb_build_object(
    'ok',true,'tournament_id',t.id,'name',t.name,'rule_key',r.rule_key,
    'draw_size',v_main,'bracket_size',v_bracket,'participants',v_participants,
    'draw_prepared_on',p_prepared_on,'status','draw_prepared',
    'model','CB-MATCH-v5-PROGRESSIVE'
  );
end;
$function$

