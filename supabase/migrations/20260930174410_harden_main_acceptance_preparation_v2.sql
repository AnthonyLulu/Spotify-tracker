-- Harden main-draw acceptance preparation against partial state and duplicate candidate rows.
CREATE OR REPLACE FUNCTION public.prepare_world_tournament_acceptance_list(p_tournament_id bigint, p_frozen_on date DEFAULT CURRENT_DATE)
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

  -- Recover safely from an interrupted/partial previous preparation.
  delete from public.world_tournament_acceptance_entries
  where tournament_id=t.id;

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

  with candidate_source as (
    select
      c.player_id,c.effective_rank,p.current_ability
    from public.tournament_candidate_player_ids(
      t.id,'direct',
      case
        when exists(
          select 1 from public.entries ue
          where ue.tournament_id=t.id
            and ue.player_id=v_managed
            and ue.status='entered'
            and coalesce(ue.requested_on,p_frozen_on)<=p_frozen_on
        ) then 2000
        else least(2000,v_direct+v_alt+240)
      end
    ) c
    join public.players p on p.id=c.player_id
    where c.player_id is distinct from v_managed
      and public.ai_player_commits_to_tournament(c.player_id,t.id)
      and not (public.player_tournament_calendar_conflict(c.player_id,t.id,'direct')->>'conflict')::boolean

    union all

    select
      e.player_id,
      case
        when e.entry_method='protected' then coalesce(e.entry_rank,public.player_rank_at_date(e.player_id,p_frozen_on),999999)
        else coalesce(public.player_rank_at_date(e.player_id,p_frozen_on),e.entry_rank,999999)
      end::int as effective_rank,
      p.current_ability
    from public.entries e
    join public.players p on p.id=e.player_id
    where e.tournament_id=t.id
      and e.player_id=v_managed
      and e.status='entered'
      and coalesce(e.requested_on,p_frozen_on)<=p_frozen_on
      and e.entry_method in ('direct','protected','alternate')
  ),
  candidate_pool as (
    select
      cs.player_id,cs.effective_rank,cs.current_ability,
      row_number() over(order by cs.effective_rank,cs.current_ability desc,cs.player_id)::int rn
    from (
      select
        player_id,
        min(effective_rank)::int as effective_rank,
        max(current_ability)::numeric as current_ability
      from candidate_source
      group by player_id
    ) cs
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
     or cp.player_id=v_managed
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
$function$
;
