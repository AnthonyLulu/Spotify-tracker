CREATE OR REPLACE FUNCTION public.materialize_next_world_tournament_alternates(p_tournament_id bigint, p_limit integer DEFAULT 24)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  st public.world_tournament_acceptance_states%rowtype;
  v_managed bigint;
  v_inserted integer:=0;
  v_eligible_order integer:=0;
  v_target integer;
  v_added integer:=0;
  rec record;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  select * into st from public.world_tournament_acceptance_states where tournament_id=p_tournament_id;
  select managed_player_id into v_managed from public.career_state where id='demo';

  if t.id is null or st.tournament_id is null then
    return jsonb_build_object('ok',false,'skipped','acceptance_list_missing');
  end if;

  -- V74: the original all-player query evaluates costly AI decisions and
  -- calendar conflicts on every eligible candidate BEFORE limiting to the
  -- 1..128 alternate places requested. Ranking is deterministic, so scan in
  -- the SAME global rank/ability/id order and stop after enough missing
  -- alternatives are materialized. This is a short-circuit evaluation, NOT
  -- a change to eligibility, mandatory entrants, or acceptance ordering.
  v_target:=greatest(1,least(coalesce(p_limit,24),128));

  for rec in
    with candidate_source as (
      select c.player_id,c.effective_rank,p.current_ability
      from public.tournament_candidate_player_ids(t.id,'direct',2000) c
      join public.players p on p.id=c.player_id
      where c.player_id is distinct from v_managed

      union all

      select e.player_id,
        case
          when e.entry_method='protected'
            then coalesce(e.entry_rank,public.player_rank_at_date(e.player_id,st.frozen_on),999999)
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
    )
    select player_id,min(effective_rank)::int effective_rank,
           max(current_ability)::numeric current_ability
    from candidate_source
    group by player_id
    order by min(effective_rank),max(current_ability) desc,player_id
  loop
    -- The managed entry is already explicitly committed; all other player
    -- decisions and direct calendar conflict rules stay byte-for-byte alike.
    if rec.player_id is distinct from v_managed then
      if public.ai_player_commits_to_tournament(rec.player_id,t.id) is distinct from true then
        continue;
      end if;
      if (public.player_tournament_calendar_conflict(rec.player_id,t.id,'direct')
          ->>'conflict')::boolean is distinct from false then
        continue;
      end if;
    end if;

    v_eligible_order:=v_eligible_order+1;
    if v_eligible_order<=st.direct_slots then
      continue;
    end if;

    if exists(
       select 1 from public.world_tournament_acceptance_entries e
       where e.tournament_id=t.id and e.player_id=rec.player_id
    ) then
      continue;
    end if;

    insert into public.world_tournament_acceptance_entries(
      tournament_id,player_id,list_group,acceptance_order,effective_rank,
      status,entry_method,snapshot_date,source_label
    ) values (
      t.id,rec.player_id,'alternate',v_eligible_order-st.direct_slots,
      rec.effective_rank,'alternate','direct',st.frozen_on,
      'Court Boss frozen acceptance list · on-demand ALT replenishment'
    )
    on conflict(tournament_id,player_id) do nothing;

    get diagnostics v_added=row_count;
    v_inserted:=v_inserted+v_added;
    exit when v_inserted>=v_target;
  end loop;

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
$function$
;
