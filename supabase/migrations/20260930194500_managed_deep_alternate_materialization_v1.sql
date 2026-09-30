-- Materialize complete alternate depth through the managed player's actual position.
-- If the user is ALT #272, rows #1..#272 are stored so vacancy promotion order remains truthful.

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
    from candidate_source cs
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
  where cp.rn<=greatest(
          v_direct+v_alt,
          coalesce(
            (select mp.rn from candidate_pool mp where mp.player_id=v_managed),
            0
          )
        )
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

CREATE OR REPLACE FUNCTION public.prepare_world_qualifying_acceptance_list(p_tournament_id bigint, p_snapshot_on date DEFAULT NULL::date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  r public.tournament_format_rules%rowtype;
  qs jsonb;
  v_snapshot date;
  v_close date;
  v_qdraw int:=0;
  v_qdirect int:=0;
  v_alt_target int:=0;
  v_selected int:=0;
  v_alts int:=0;
  v_managed bigint;
begin
  select * into t from public.tournaments
  where id=p_tournament_id and singles=true and coalesce(is_active,true)=true;

  if t.id is null then
    return jsonb_build_object('ok',false,'skipped','tournament_not_found');
  end if;
  if coalesce(t.circuit,'') not in ('ATP','Challenger','ITF') then
    return jsonb_build_object('ok',true,'skipped','unsupported_circuit','tournament_id',t.id);
  end if;

  qs:=public.tournament_qualifying_structure(t.id);
  v_qdraw:=coalesce((qs->>'draw_size')::int,0);
  v_qdirect:=coalesce((qs->>'direct_acceptances')::int,0);
  if v_qdraw<=0 or v_qdirect<=0 then
    return jsonb_build_object('ok',true,'skipped','no_qualifying_acceptance','tournament_id',t.id);
  end if;

  if exists(select 1 from public.world_qualifying_acceptance_states s where s.tournament_id=t.id) then
    return jsonb_build_object(
      'ok',true,'existing',true,'tournament_id',t.id,
      'accepted',(select count(*) from public.world_qualifying_acceptance_entries e where e.tournament_id=t.id and e.status in ('accepted','promoted')),
      'alternates',(select count(*) from public.world_qualifying_acceptance_entries e where e.tournament_id=t.id and e.status='alternate')
    );
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

  v_snapshot:=coalesce(
    p_snapshot_on,
    t.qualifying_entry_deadline,
    t.withdrawal_deadline,
    t.singles_withdrawal_deadline,
    t.freeze_deadline,
    t.qualifying_signin_date,
    t.qualifying_start_date-1,
    t.start_date-1
  );
  v_close:=coalesce(
    t.qualifying_signin_date,
    case when t.circuit='ITF' then t.freeze_deadline end,
    t.qualifying_start_date-1,
    t.start_date-1
  );
  v_alt_target:=greatest(32,least(256,v_qdraw*4));
  select managed_player_id into v_managed from public.career_state where id='demo';

  perform public.prepare_world_tournament_acceptance_list(
    t.id,coalesce(t.main_entry_deadline,t.singles_entry_deadline,t.deadline,t.start_date-21)
  );
  perform public.refresh_world_tournament_acceptance_list(t.id,v_snapshot);

  drop table if exists pg_temp.cb_qa_special;
  drop table if exists pg_temp.cb_qa_selected;
  drop table if exists pg_temp.cb_qa_candidates;

  create temporary table cb_qa_special(
    player_id bigint primary key,
    effective_rank int not null,
    entry_method text not null,
    priority_value int not null
  ) on commit drop;

  if coalesce(r.junior_accelerator_slots,0)>0
     and t.circuit='Challenger'
     and t.category in ('Challenger 50','Challenger 75') then
    insert into cb_qa_special(player_id,effective_rank,entry_method,priority_value)
    select x.player_id,
           coalesce(public.player_rank_at_date(x.player_id,v_snapshot),999999)::int,
           'junior_accelerator_qualifying',
           coalesce(x.year_end_rank,999)*100+1
    from public.junior_accelerator_candidate_ids(t.id,'qualifying') x
    limit r.junior_accelerator_slots
    on conflict(player_id) do nothing;
  end if;

  if coalesce(r.college_accelerator_slots,0)>0
     and t.circuit='Challenger'
     and t.category in ('Challenger 50','Challenger 75') then
    insert into cb_qa_special(player_id,effective_rank,entry_method,priority_value)
    select x.player_id,
           coalesce(public.player_rank_at_date(x.player_id,v_snapshot),999999)::int,
           'college_accelerator_qualifying',
           coalesce(x.year_end_ita_rank,999)*100+2
    from public.atp_college_accelerator_candidate_ids(t.id,'qualifying') x
    limit r.college_accelerator_slots
    on conflict(player_id) do nothing;
  end if;

  if t.circuit='Challenger' and t.category in ('Challenger 50','Challenger 75') then
    delete from cb_qa_special s
    where s.player_id in (
      select z.player_id from (
        select player_id,row_number() over(order by priority_value,player_id) rn
        from cb_qa_special
        where entry_method in ('junior_accelerator_qualifying','college_accelerator_qualifying')
      ) z where z.rn>2
    );
  end if;

  if coalesce(r.nextgen_accelerator_qual_slots,0)>0 then
    insert into cb_qa_special(player_id,effective_rank,entry_method,priority_value)
    select x.player_id,
           coalesce(x.effective_rank,public.player_rank_at_date(x.player_id,v_snapshot),999999)::int,
           'nextgen_accelerator_qualifying',
           coalesce(x.effective_rank,999999)*100+3
    from public.nextgen_accelerator_candidate_ids(t.id,'qualifying') x
    limit r.nextgen_accelerator_qual_slots
    on conflict(player_id) do nothing;
  end if;

  create temporary table cb_qa_candidates(
    player_id bigint primary key,
    effective_rank int not null
  ) on commit drop;

  insert into cb_qa_candidates(player_id,effective_rank)
  select c.player_id,c.effective_rank
  from public.tournament_candidate_player_ids(t.id,'qualifying',2000) c
  join public.players p on p.id=c.player_id
  where c.player_id is distinct from v_managed
    and not exists(select 1 from cb_qa_special s where s.player_id=c.player_id)
    and not exists(
      select 1 from public.world_tournament_acceptance_entries m
      where m.tournament_id=t.id and m.player_id=c.player_id
        and m.status in ('accepted','promoted')
    )
    and public.ai_player_commits_to_tournament(c.player_id,t.id)
    and not (public.player_tournament_calendar_conflict(c.player_id,t.id,'qualifying')->>'conflict')::boolean
  order by c.effective_rank,p.current_ability desc,c.player_id
  limit 2000;

  -- Managed-player entries are persisted separately from the autonomous AI pool.
  -- If the user is not accepted into the main draw, an active entry may still
  -- flow into the frozen qualifying acceptance list.
  insert into cb_qa_candidates(player_id,effective_rank)
  select
    e.player_id,
    case
      when e.entry_method='protected_qualifying' then coalesce(e.entry_rank,public.player_rank_at_date(e.player_id,v_snapshot),999999)
      else coalesce(public.player_rank_at_date(e.player_id,v_snapshot),e.entry_rank,999999)
    end::int
  from public.entries e
  where e.tournament_id=t.id
    and e.player_id=v_managed
    and e.status='entered'
    and coalesce(e.requested_on,v_snapshot)<=v_snapshot
    and e.entry_method not in ('late_entry','wildcard')
    and not exists(
      select 1 from public.world_tournament_acceptance_entries m
      where m.tournament_id=t.id and m.player_id=e.player_id
        and m.status in ('accepted','promoted')
    )
    and (public.tournament_entry_eligibility(e.player_id,t.id,'qualifying')->>'eligible')::boolean
  on conflict(player_id) do update set effective_rank=excluded.effective_rank;

  create temporary table cb_qa_selected(
    player_id bigint primary key,
    effective_rank int not null,
    entry_method text not null
  ) on commit drop;

  insert into cb_qa_selected(player_id,effective_rank,entry_method)
  select s.player_id,s.effective_rank,s.entry_method
  from cb_qa_special s
  where not exists(
    select 1 from public.world_tournament_acceptance_entries m
    where m.tournament_id=t.id and m.player_id=s.player_id
      and m.status in ('accepted','promoted')
  )
  order by s.priority_value,s.player_id
  limit v_qdirect;

  insert into cb_qa_selected(player_id,effective_rank,entry_method)
  select c.player_id,c.effective_rank,'qualifying'
  from cb_qa_candidates c
  where not exists(select 1 from cb_qa_selected s where s.player_id=c.player_id)
  order by c.effective_rank,c.player_id
  limit greatest(0,v_qdirect-(select count(*) from cb_qa_selected))
  on conflict(player_id) do nothing;

  select count(*) into v_selected from cb_qa_selected;
  if v_selected<>v_qdirect then
    return jsonb_build_object(
      'ok',false,'skipped','insufficient_qualifying_acceptances',
      'tournament_id',t.id,'required',v_qdirect,'selected',v_selected
    );
  end if;

  delete from public.world_qualifying_acceptance_entries where tournament_id=t.id;
  delete from public.world_qualifying_acceptance_states where tournament_id=t.id;

  insert into public.world_qualifying_acceptance_entries(
    tournament_id,player_id,list_group,acceptance_order,effective_rank,status,
    entry_method,snapshot_date,source_label
  )
  select t.id,s.player_id,'qualifying',
         row_number() over(order by s.effective_rank,s.player_id)::int,
         s.effective_rank,'accepted',s.entry_method,v_snapshot,
         'Court Boss qualifying advance acceptance · 2026 rules'
  from cb_qa_selected s;

  with ranked_alts as (
    select
      c.player_id,
      c.effective_rank,
      row_number() over(order by c.effective_rank,c.player_id)::int as alt_order
    from cb_qa_candidates c
    where not exists(
      select 1 from cb_qa_selected s where s.player_id=c.player_id
    )
  ),
  cutoff as (
    select greatest(
      v_alt_target,
      coalesce(
        (select r.alt_order from ranked_alts r where r.player_id=v_managed),
        0
      )
    )::int as max_alt_order
  )
  insert into public.world_qualifying_acceptance_entries(
    tournament_id,player_id,list_group,acceptance_order,effective_rank,status,
    entry_method,snapshot_date,source_label
  )
  select
    t.id,r.player_id,'alternate',r.alt_order,
    r.effective_rank,'alternate','qualifying_alternate',v_snapshot,
    'Court Boss qualifying alternate list · 2026 rules'
  from ranked_alts r
  cross join cutoff c
  where r.alt_order<=c.max_alt_order
  order by r.alt_order;

  get diagnostics v_alts=row_count;

  insert into public.world_qualifying_acceptance_states(
    tournament_id,created_on,movement_closes_on,direct_slots,alternate_slots,
    status,last_refreshed_on,metadata,updated_at
  ) values(
    t.id,v_snapshot,v_close,v_qdirect,v_alts,'active',v_snapshot,
    jsonb_build_object(
      'draw_size',v_qdraw,
      'direct_acceptances',v_qdirect,
      'qualifying_wildcards',coalesce((qs->>'wildcards')::int,0),
      'qualifier_slots',coalesce((qs->>'qualifier_slots')::int,0),
      'circuit',t.circuit,
      'rule_source',case when t.circuit='ITF' then '2026 ITF World Tennis Tour Regulations' else 'ATP 2026 Rulebook' end,
      'model','CB-Q-ACCEPTANCE-v1'
    ),now()
  );

  return jsonb_build_object(
    'ok',true,'tournament_id',t.id,'created_on',v_snapshot,
    'movement_closes_on',v_close,'accepted',v_selected,'alternates',v_alts,
    'direct_slots',v_qdirect,'draw_size',v_qdraw
  );
end;
$function$
;
