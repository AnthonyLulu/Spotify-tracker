-- Withdraw unavailable qualifying alternates as well as accepted Q players.

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
