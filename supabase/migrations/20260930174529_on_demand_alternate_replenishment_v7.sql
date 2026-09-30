-- Sparse, deterministic alternate storage with on-demand replenishment.
-- Keeps Disk IO low while preserving promotion order when the initial stored ALT horizon is exhausted.


create or replace function public.materialize_next_world_tournament_alternates(
  p_tournament_id bigint,
  p_limit integer default 24
) returns jsonb
language plpgsql
set search_path to 'public'
as $function$
declare
  t public.tournaments%rowtype;
  st public.world_tournament_acceptance_states%rowtype;
  v_managed bigint;
  v_inserted integer:=0;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  select * into st from public.world_tournament_acceptance_states where tournament_id=p_tournament_id;
  select managed_player_id into v_managed from public.career_state where id='demo';

  if t.id is null or st.tournament_id is null then
    return jsonb_build_object('ok',false,'skipped','acceptance_list_missing');
  end if;

  with candidate_source as (
    select c.player_id,c.effective_rank,p.current_ability
    from public.tournament_candidate_player_ids(t.id,'direct',2000) c
    join public.players p on p.id=c.player_id
    where c.player_id is distinct from v_managed
      and public.ai_player_commits_to_tournament(c.player_id,t.id)
      and not (public.player_tournament_calendar_conflict(c.player_id,t.id,'direct')->>'conflict')::boolean

    union all

    select
      e.player_id,
      case
        when e.entry_method='protected' then coalesce(e.entry_rank,public.player_rank_at_date(e.player_id,st.frozen_on),999999)
        else coalesce(public.player_rank_at_date(e.player_id,st.frozen_on),e.entry_rank,999999)
      end::int,
      p.current_ability
    from public.entries e
    join public.players p on p.id=e.player_id
    where e.tournament_id=t.id
      and e.player_id=v_managed
      and e.status='entered'
      and coalesce(e.requested_on,st.frozen_on)<=st.frozen_on
      and e.entry_method in ('direct','protected','alternate')
  ),
  candidate_pool as (
    select
      cs.player_id,cs.effective_rank,cs.current_ability,
      row_number() over(order by cs.effective_rank,cs.current_ability desc,cs.player_id)::int rn
    from (
      select player_id,min(effective_rank)::int effective_rank,max(current_ability)::numeric current_ability
      from candidate_source
      group by player_id
    ) cs
  ),
  missing as (
    select
      cp.player_id,
      cp.effective_rank,
      (cp.rn-st.direct_slots)::int as alt_order
    from candidate_pool cp
    where cp.rn>st.direct_slots
      and not exists(
        select 1 from public.world_tournament_acceptance_entries e
        where e.tournament_id=t.id and e.player_id=cp.player_id
      )
    order by cp.rn
    limit greatest(1,least(coalesce(p_limit,24),128))
  )
  insert into public.world_tournament_acceptance_entries(
    tournament_id,player_id,list_group,acceptance_order,effective_rank,
    status,entry_method,snapshot_date,source_label
  )
  select
    t.id,m.player_id,'alternate',m.alt_order,m.effective_rank,
    'alternate','direct',st.frozen_on,
    'Court Boss frozen acceptance list · on-demand ALT replenishment'
  from missing m
  on conflict(tournament_id,player_id) do nothing;

  get diagnostics v_inserted=row_count;

  update public.world_tournament_acceptance_states
  set alternate_slots=(
        select count(*) from public.world_tournament_acceptance_entries e
        where e.tournament_id=t.id and e.list_group='alternate'
      ),
      metadata=metadata||jsonb_build_object(
        'last_on_demand_alt_inserted',v_inserted,
        'alternate_storage','sparse_on_demand'
      ),
      updated_at=now()
  where tournament_id=t.id;

  return jsonb_build_object(
    'ok',true,'tournament_id',t.id,'inserted',v_inserted,
    'model','CB-ACCEPTANCE-SPARSE-ALT-v7'
  );
end;
$function$;

create or replace function public.materialize_next_world_qualifying_alternates(
  p_tournament_id bigint,
  p_limit integer default 24
) returns jsonb
language plpgsql
set search_path to 'public'
as $function$
declare
  t public.tournaments%rowtype;
  st public.world_qualifying_acceptance_states%rowtype;
  v_managed bigint;
  v_inserted integer:=0;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  select * into st from public.world_qualifying_acceptance_states where tournament_id=p_tournament_id;
  select managed_player_id into v_managed from public.career_state where id='demo';

  if t.id is null or st.tournament_id is null then
    return jsonb_build_object('ok',false,'skipped','qualifying_acceptance_list_missing');
  end if;

  with candidate_source as (
    select c.player_id,c.effective_rank
    from public.tournament_candidate_player_ids(t.id,'qualifying',2000) c
    where c.player_id is distinct from v_managed
      and not exists(
        select 1 from public.world_tournament_acceptance_entries m
        where m.tournament_id=t.id and m.player_id=c.player_id
          and m.status in ('accepted','promoted')
      )
      and public.ai_player_commits_to_tournament(c.player_id,t.id)
      and not (public.player_tournament_calendar_conflict(c.player_id,t.id,'qualifying')->>'conflict')::boolean

    union all

    select
      e.player_id,
      case
        when e.entry_method='protected_qualifying' then coalesce(e.entry_rank,public.player_rank_at_date(e.player_id,st.created_on),999999)
        else coalesce(public.player_rank_at_date(e.player_id,st.created_on),e.entry_rank,999999)
      end::int
    from public.entries e
    where e.tournament_id=t.id
      and e.player_id=v_managed
      and e.status='entered'
      and coalesce(e.requested_on,st.created_on)<=st.created_on
      and e.entry_method not in ('late_entry','wildcard')
      and not exists(
        select 1 from public.world_tournament_acceptance_entries m
        where m.tournament_id=t.id and m.player_id=e.player_id
          and m.status in ('accepted','promoted')
      )
      and (public.tournament_entry_eligibility(e.player_id,t.id,'qualifying')->>'eligible')::boolean
  ),
  candidate_pool as (
    select player_id,min(effective_rank)::int effective_rank
    from candidate_source
    group by player_id
  ),
  ranked_alts as (
    select
      cp.player_id,cp.effective_rank,
      row_number() over(order by cp.effective_rank,cp.player_id)::int alt_order
    from candidate_pool cp
    where not exists(
      select 1 from public.world_qualifying_acceptance_entries q
      where q.tournament_id=t.id
        and q.player_id=cp.player_id
        and q.list_group='qualifying'
    )
  ),
  missing as (
    select ra.*
    from ranked_alts ra
    where not exists(
      select 1 from public.world_qualifying_acceptance_entries q
      where q.tournament_id=t.id and q.player_id=ra.player_id
    )
    order by ra.alt_order
    limit greatest(1,least(coalesce(p_limit,24),128))
  )
  insert into public.world_qualifying_acceptance_entries(
    tournament_id,player_id,list_group,acceptance_order,effective_rank,status,
    entry_method,snapshot_date,source_label
  )
  select
    t.id,m.player_id,'alternate',m.alt_order,m.effective_rank,'alternate',
    'qualifying_alternate',st.created_on,
    'Court Boss qualifying acceptance list · on-demand ALT replenishment'
  from missing m
  on conflict(tournament_id,player_id) do nothing;

  get diagnostics v_inserted=row_count;

  update public.world_qualifying_acceptance_states
  set alternate_slots=(
        select count(*) from public.world_qualifying_acceptance_entries q
        where q.tournament_id=t.id and q.status='alternate'
      ),
      metadata=metadata||jsonb_build_object(
        'last_on_demand_alt_inserted',v_inserted,
        'alternate_storage','sparse_on_demand'
      ),
      updated_at=now()
  where tournament_id=t.id;

  return jsonb_build_object(
    'ok',true,'tournament_id',t.id,'inserted',v_inserted,
    'model','CB-Q-ACCEPTANCE-SPARSE-ALT-v7'
  );
end;
$function$;


CREATE OR REPLACE FUNCTION public.refresh_world_tournament_acceptance_list(p_tournament_id bigint, p_date date DEFAULT CURRENT_DATE)
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
  v_managed bigint;
begin
  select managed_player_id into v_managed from public.career_state where id='demo';
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
        when p.id=v_managed and not exists(
          select 1 from public.entries ue
          where ue.tournament_id=t.id and ue.player_id=v_managed and ue.status='entered'
        ) then 'managed_withdrawal'
        when p.career_status<>'active' then 'career_unavailable'
        when exists(
          select 1 from public.injuries i
          where i.player_id=p.id and lower(coalesce(i.status,''))='active'
            and i.expected_return>=coalesce(t.main_draw_start_date,t.start_date)
        ) then 'injury'
        when p_date>=v_q_start-3 and (coalesce(p.fitness,90)<45 or coalesce(p.fatigue,20)>92) then 'condition'
        when (public.player_tournament_calendar_conflict(p.id,t.id,'direct')->>'conflict')::boolean then 'calendar_conflict'
        when p.id is distinct from v_managed
             and p_date>=coalesce(t.withdrawal_deadline,t.singles_withdrawal_deadline,st.frozen_on)
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
      perform public.materialize_next_world_tournament_alternates(
        t.id,greatest(24,least(128,v_needed*6))
      );

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
$function$
;

CREATE OR REPLACE FUNCTION public.refresh_world_qualifying_acceptance_list(p_tournament_id bigint, p_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  s public.world_qualifying_acceptance_states%rowtype;
  v_active int:=0;
  v_need int:=0;
  v_promoted int:=0;
  v_withdrawn int:=0;
  v_player bigint;
  v_managed bigint;
  v_onsite boolean:=false;
begin
  select managed_player_id into v_managed from public.career_state where id='demo';
  select * into t from public.tournaments where id=p_tournament_id;
  select * into s from public.world_qualifying_acceptance_states where tournament_id=p_tournament_id;

  if t.id is null or s.tournament_id is null then
    return jsonb_build_object('ok',false,'skipped','qualifying_acceptance_not_found','tournament_id',p_tournament_id);
  end if;

  if exists(select 1 from public.world_qualifying_states q where q.tournament_id=t.id) then
    update public.world_qualifying_acceptance_states
    set status='closed',last_refreshed_on=p_date,updated_at=now()
    where tournament_id=t.id;
    return jsonb_build_object('ok',true,'tournament_id',t.id,'closed',true,'reason','qualifying_draw_prepared');
  end if;

  v_onsite:=p_date>=coalesce(
    t.qualifying_signin_date,
    case when t.circuit='ITF' then t.freeze_deadline end,
    t.qualifying_start_date-1,
    t.start_date-1
  );

  with bad as (
    select e.player_id,
           case
             when e.player_id=v_managed and not exists(
               select 1 from public.entries ue
               where ue.tournament_id=t.id and ue.player_id=v_managed and ue.status='entered'
             ) then 'managed_withdrawal'
             when exists(
               select 1 from public.world_tournament_acceptance_entries m
               where m.tournament_id=t.id and m.player_id=e.player_id
                 and m.status in ('accepted','promoted')
             ) then 'promoted_to_main_draw'
             when p.id is null or p.career_status<>'active' then 'inactive'
             when p.injury_status<>'Fit' then 'injury'
             when coalesce(p.fitness,90)<45 then 'fitness'
             when coalesce(p.fatigue,20)>90 then 'fatigue'
             when (public.player_tournament_calendar_conflict(e.player_id,t.id,'qualifying')->>'conflict')::boolean then 'calendar_conflict'
             else null
           end reason
    from public.world_qualifying_acceptance_entries e
    left join public.players p on p.id=e.player_id
    where e.tournament_id=t.id
      and e.status in ('accepted','promoted','alternate')
  )
  update public.world_qualifying_acceptance_entries e
  set status='withdrawn',withdrawn_on=p_date,withdrawal_phase='pre_q',
      withdrawal_reason=b.reason,updated_at=now()
  from bad b
  where e.tournament_id=t.id and e.player_id=b.player_id and b.reason is not null;

  get diagnostics v_withdrawn=row_count;

  select count(*) into v_active
  from public.world_qualifying_acceptance_entries
  where tournament_id=t.id and status in ('accepted','promoted');
  v_need:=greatest(0,s.direct_slots-v_active);

  if v_need>0 then
    perform public.materialize_next_world_qualifying_alternates(
      t.id,greatest(24,least(128,v_need*6))
    );
  end if;

  while v_need>0 loop
    select e.player_id into v_player
    from public.world_qualifying_acceptance_entries e
    join public.players p on p.id=e.player_id
    where e.tournament_id=t.id
      and e.status='alternate'
      and p.career_status='active'
      and p.injury_status='Fit'
      and coalesce(p.fitness,90)>=45
      and coalesce(p.fatigue,20)<=90
      and (public.tournament_entry_eligibility(e.player_id,t.id,'qualifying')->>'eligible')::boolean
      and (e.player_id=v_managed or public.ai_player_commits_to_tournament(e.player_id,t.id))
      and not (public.player_tournament_calendar_conflict(e.player_id,t.id,'qualifying')->>'conflict')::boolean
      and not exists(
        select 1 from public.world_tournament_acceptance_entries m
        where m.tournament_id=t.id and m.player_id=e.player_id
          and m.status in ('accepted','promoted')
      )
    order by
      case when v_onsite then coalesce(public.player_rank_at_date(e.player_id,p_date),e.effective_rank) else e.acceptance_order end,
      e.acceptance_order,e.player_id
    limit 1;

    exit when v_player is null;

    update public.world_qualifying_acceptance_entries
    set status='promoted',promoted_on=p_date,
        entry_method=case when v_onsite then 'onsite_alternate' else 'qualifying_alternate' end,
        effective_rank=coalesce(public.player_rank_at_date(v_player,p_date),effective_rank),
        updated_at=now()
    where tournament_id=t.id and player_id=v_player;

    v_promoted:=v_promoted+1;
    v_need:=v_need-1;
    v_player:=null;
  end loop;

  select count(*) into v_active
  from public.world_qualifying_acceptance_entries
  where tournament_id=t.id and status in ('accepted','promoted');

  update public.world_qualifying_acceptance_states
  set status=case
        when p_date>=coalesce(t.qualifying_signin_date,t.qualifying_start_date-1,t.start_date-1) then 'closed'
        else 'active'
      end,
      last_refreshed_on=p_date,
      alternate_slots=(select count(*) from public.world_qualifying_acceptance_entries e where e.tournament_id=t.id and e.status='alternate'),
      updated_at=now()
  where tournament_id=t.id;

  return jsonb_build_object(
    'ok',true,'tournament_id',t.id,'date',p_date,
    'active_acceptances',v_active,'required',s.direct_slots,
    'withdrawn',v_withdrawn,'promoted',v_promoted,
    'onsite_phase',v_onsite,'shortfall',greatest(0,s.direct_slots-v_active)
  );
end;
$function$
;
