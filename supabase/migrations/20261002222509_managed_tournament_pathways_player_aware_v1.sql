-- Player-aware tournament pathway compatibility layer.
-- Production migration version: 20261002222509.
-- Keeps legacy managed_* wrappers while allowing explicit managed player selection.

-- managed_late_entry_status(bigint)
CREATE OR REPLACE FUNCTION public.managed_late_entry_status(p_target_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  managed_id bigint;
begin
  select managed_player_id into managed_id
  from public.career_state where id='demo';

  return public.managed_late_entry_status(
    p_target_tournament_id,
    managed_id
  );
end
$function$;

-- managed_late_entry_status(bigint,bigint)
CREATE OR REPLACE FUNCTION public.managed_late_entry_status(p_target_tournament_id bigint, p_player_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  career_day date;
  ranking_day date;
  rankv int;
  cutv int;
  schedule jsonb;
begin
  select * into t from public.tournaments where id=p_target_tournament_id;
  if t.id is null then
    return jsonb_build_object('eligible',false,'reason','tournament_not_found');
  end if;

  select career_date into career_day
  from public.career_state
  where id='demo';

  if p_player_id is null then
    return jsonb_build_object('eligible',false,'reason','managed_player_missing');
  end if;

  if coalesce(t.late_entry_slots,0)<=0 then
    return jsonb_build_object('eligible',false,'reason','no_late_entry_slot');
  end if;

  if career_day is null then career_day:=date '2025-12-01'; end if;

  if t.main_entry_deadline is not null and career_day<=t.main_entry_deadline then
    return jsonb_build_object(
      'eligible',false,'reason','regular_entry_still_open',
      'regular_deadline',t.main_entry_deadline,'late_entry_deadline',t.late_entry_deadline,
      'player_id',p_player_id
    );
  end if;

  if t.late_entry_deadline is not null and career_day>t.late_entry_deadline then
    return jsonb_build_object(
      'eligible',false,'reason','late_entry_closed',
      'late_entry_deadline',t.late_entry_deadline,'player_id',p_player_id
    );
  end if;

  ranking_day:=(
    t.start_date + ((8-extract(isodow from t.start_date)::int)%7)
  )-28;
  rankv:=public.player_rank_at_date(p_player_id,ranking_day);
  cutv:=coalesce(t.direct_cut,t.projected_direct_cut,0);

  if cutv<=0 then
    return jsonb_build_object(
      'eligible',false,'reason','missing_original_cut',
      'ranking',rankv,'ranking_date',ranking_day,'player_id',p_player_id
    );
  end if;

  if rankv>=cutv then
    return jsonb_build_object(
      'eligible',false,'reason','ranking_not_better_than_original_cut',
      'ranking',rankv,'original_cut',cutv,'ranking_date',ranking_day,
      'late_entry_deadline',t.late_entry_deadline,'player_id',p_player_id
    );
  end if;

  if not (public.tournament_entry_eligibility(p_player_id,t.id,'direct')->>'eligible')::boolean then
    return jsonb_build_object(
      'eligible',false,'reason','circuit_ineligible',
      'ranking',rankv,'original_cut',cutv,'player_id',p_player_id
    );
  end if;

  schedule:=public.managed_tournament_schedule_status(t.id,'direct',p_player_id);
  if coalesce((schedule->>'available')::boolean,false)=false then
    return jsonb_build_object(
      'eligible',false,'reason','calendar_conflict',
      'schedule',schedule,'player_id',p_player_id
    );
  end if;

  return jsonb_build_object(
    'eligible',true,
    'reason','late_entry_available',
    'ranking',rankv,
    'ranking_date',ranking_day,
    'original_cut',cutv,
    'late_entry_deadline',t.late_entry_deadline,
    'slots',t.late_entry_slots,
    'player_id',p_player_id
  );
end
$function$;

-- managed_performance_bye_status(bigint)
CREATE OR REPLACE FUNCTION public.managed_performance_bye_status(p_target_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  managed_id bigint;
begin
  select managed_player_id into managed_id
  from public.career_state where id='demo';

  return public.managed_performance_bye_status(
    p_target_tournament_id,
    managed_id
  );
end
$function$;

-- managed_performance_bye_status(bigint,bigint)
CREATE OR REPLACE FUNCTION public.managed_performance_bye_status(p_target_tournament_id bigint, p_player_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  rankv int;
  better_count int:=0;
  accepted boolean:=false;
  candidate boolean:=false;
begin
  select * into t from public.tournaments where id=p_target_tournament_id;

  if t.id is null or p_player_id is null or coalesce(t.performance_bye_slots,0)<=0 then
    return jsonb_build_object('eligible',false,'reason','no_performance_bye_rule');
  end if;

  select exists(
    select 1
    from public.tournament_performance_bye_candidate_ids(t.id) x
    where x.player_id=p_player_id
  ) into candidate;

  if not candidate then
    return jsonb_build_object('eligible',false,'reason','not_source_event_finalist','player_id',p_player_id);
  end if;

  select coalesce(ranking,999999) into rankv
  from public.players where id=p_player_id;
  rankv:=coalesce(rankv,999999);

  if exists(
    select 1 from public.world_tournament_acceptance_states s
    where s.tournament_id=t.id
  ) then
    accepted:=exists(
      select 1
      from public.world_tournament_acceptance_entries a
      where a.tournament_id=t.id
        and a.player_id=p_player_id
        and a.status in ('accepted','promoted')
    ) or exists(
      select 1 from public.wildcard_requests w
      where w.tournament_id=t.id
        and w.player_id=p_player_id
        and w.status='accepted'
    );

    select count(*) into better_count
    from public.world_tournament_acceptance_entries a
    where a.tournament_id=t.id
      and a.status in ('accepted','promoted')
      and a.effective_rank<rankv;
  else
    accepted:=rankv<=coalesce(t.direct_cut,t.projected_direct_cut,0)
      or exists(
        select 1 from public.wildcard_requests w
        where w.tournament_id=t.id
          and w.player_id=p_player_id
          and w.status='accepted'
      );

    select count(*) into better_count
    from public.tournament_candidate_player_ids(t.id,'candidate',256) x
    where x.effective_rank<rankv;
  end if;

  if not accepted then
    return jsonb_build_object('eligible',false,'reason','not_accepted_main_draw','player_id',p_player_id);
  end if;

  if better_count<16 then
    return jsonb_build_object(
      'eligible',false,'reason','would_be_top16_seed',
      'better_accepted_candidates',better_count,'player_id',p_player_id
    );
  end if;

  return jsonb_build_object(
    'eligible',true,
    'reason','source_event_finalist_outside_top16_seeds',
    'slots',t.performance_bye_slots,
    'source_event',t.performance_bye_source_event,
    'better_accepted_candidates',better_count,
    'player_id',p_player_id
  );
end
$function$;

-- managed_special_exempt_status(bigint)
CREATE OR REPLACE FUNCTION public.managed_special_exempt_status(p_target_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  managed_id bigint;
begin
  select managed_player_id into managed_id
  from public.career_state where id='demo';

  return public.managed_special_exempt_status(
    p_target_tournament_id,
    managed_id
  );
end
$function$;

-- managed_special_exempt_status(bigint,bigint)
CREATE OR REPLACE FUNCTION public.managed_special_exempt_status(p_target_tournament_id bigint, p_player_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  r public.tournament_format_rules%rowtype;
  prev record;
  rankv int;
begin
  select * into t from public.tournaments where id=p_target_tournament_id;
  if t.id is null or p_player_id is null then
    return jsonb_build_object('eligible',false,'reason','missing_target_or_player');
  end if;

  select * into r
  from public.tournament_format_rules fr
  where fr.circuit=t.circuit and fr.category=t.category
    and fr.main_draw_size=coalesce(t.singles_draw_size,t.draw_size)
  limit 1;

  if coalesce(r.special_exempt_slots,0)<=0 then
    return jsonb_build_object('eligible',false,'reason','no_special_exempt_slots','player_id',p_player_id);
  end if;

  rankv:=coalesce(public.player_rank_at_date(p_player_id,coalesce(t.main_entry_deadline,t.start_date)),999999);
  if rankv<=coalesce(t.direct_cut,t.projected_direct_cut,0) then
    return jsonb_build_object(
      'eligible',false,'reason','already_direct_acceptance',
      'ranking',rankv,'player_id',p_player_id
    );
  end if;

  select tr.tournament_id,tr.user_round,pt.name,pt.category,pt.circuit,pt.country,pt.start_date,pt.end_date
  into prev
  from public.tournament_runs tr
  join public.tournaments pt on pt.id=tr.tournament_id
  where tr.managed_player_id=p_player_id
    and tr.tournament_id<>t.id
    and pt.start_date<t.start_date
    and coalesce(pt.end_date,pt.start_date)>=coalesce(t.qualifying_start_date,t.start_date)
    and coalesce(pt.end_date,pt.start_date)<=t.start_date
    and tr.user_round in ('Champion','F','SF')
    and public.tournament_special_exempt_eligible(pt.id,t.id)
  order by coalesce(pt.end_date,pt.start_date) desc,tr.id desc
  limit 1;

  if prev.tournament_id is null then
    return jsonb_build_object(
      'eligible',false,'reason','no_qualified_previous_event',
      'slots',r.special_exempt_slots,'player_id',p_player_id
    );
  end if;

  return jsonb_build_object(
    'eligible',true,
    'reason','still_competing_previous_week',
    'slots',r.special_exempt_slots,
    'source_tournament_id',prev.tournament_id,
    'source_tournament',prev.name,
    'source_result',prev.user_round,
    'qualifying_start',t.qualifying_start_date,
    'target',t.name,
    'player_id',p_player_id
  );
end
$function$;

-- managed_tournament_pathway_status(bigint)
CREATE OR REPLACE FUNCTION public.managed_tournament_pathway_status(p_target_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  managed_id bigint;
begin
  select managed_player_id into managed_id
  from public.career_state where id='demo';

  return public.managed_tournament_pathway_status(
    p_target_tournament_id,
    managed_id
  );
end
$function$;

-- managed_tournament_pathway_status(bigint,bigint)
CREATE OR REPLACE FUNCTION public.managed_tournament_pathway_status(p_target_tournament_id bigint, p_player_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  le jsonb;
  hit boolean;
begin
  select * into t from public.tournaments where id=p_target_tournament_id;
  if p_player_id is null or t.id is null then
    return jsonb_build_object('eligible',false,'reason','missing_context');
  end if;

  le:=public.managed_late_entry_status(t.id,p_player_id);
  if coalesce((le->>'eligible')::boolean,false) then
    return jsonb_build_object(
      'eligible',true,'mode','late_entry','label','Late Entry ATP',
      'details',le,'player_id',p_player_id
    );
  end if;

  select exists(select 1 from public.nextgen_accelerator_candidate_ids(t.id,'main') x where x.player_id=p_player_id) into hit;
  if hit then return jsonb_build_object('eligible',true,'mode','nextgen_accelerator','label','Next Gen Accelerator · tableau','player_id',p_player_id); end if;

  select exists(select 1 from public.nextgen_accelerator_candidate_ids(t.id,'qualifying') x where x.player_id=p_player_id) into hit;
  if hit then return jsonb_build_object('eligible',true,'mode','nextgen_accelerator_qualifying','label','Next Gen Accelerator · qualifs','player_id',p_player_id); end if;

  select exists(select 1 from public.junior_accelerator_candidate_ids(t.id,'main') x where x.player_id=p_player_id) into hit;
  if hit then return jsonb_build_object('eligible',true,'mode','junior_accelerator','label','Junior Accelerator · tableau','player_id',p_player_id); end if;

  select exists(select 1 from public.junior_accelerator_candidate_ids(t.id,'qualifying') x where x.player_id=p_player_id) into hit;
  if hit then return jsonb_build_object('eligible',true,'mode','junior_accelerator_qualifying','label','Junior Accelerator · qualifs','player_id',p_player_id); end if;

  select exists(select 1 from public.atp_college_accelerator_candidate_ids(t.id,'main') x where x.player_id=p_player_id) into hit;
  if hit then return jsonb_build_object('eligible',true,'mode','college_accelerator','label','College Accelerator · tableau','player_id',p_player_id); end if;

  select exists(select 1 from public.atp_college_accelerator_candidate_ids(t.id,'qualifying') x where x.player_id=p_player_id) into hit;
  if hit then return jsonb_build_object('eligible',true,'mode','college_accelerator_qualifying','label','College Accelerator · qualifs','player_id',p_player_id); end if;

  select exists(select 1 from public.college_accelerator_candidate_ids(t.id) x where x.player_id=p_player_id) into hit;
  if hit and t.circuit='ITF' then
    return jsonb_build_object('eligible',true,'mode','college_accelerator','label','ITF College Accelerator · tableau','player_id',p_player_id);
  end if;

  select exists(select 1 from public.junior_reserved_candidate_ids(t.id) x where x.player_id=p_player_id) into hit;
  if hit then return jsonb_build_object('eligible',true,'mode','junior_reserved','label','ITF Junior Accelerator · tableau','player_id',p_player_id); end if;

  return jsonb_build_object('eligible',false,'reason','no_pathway','late_entry',le,'player_id',p_player_id);
end
$function$;

-- managed_tournament_schedule_status(bigint,text)
CREATE OR REPLACE FUNCTION public.managed_tournament_schedule_status(p_target_tournament_id bigint, p_entry_mode text DEFAULT 'direct'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  managed_id bigint;
begin
  select managed_player_id into managed_id
  from public.career_state where id='demo';

  return public.managed_tournament_schedule_status(
    p_target_tournament_id,
    p_entry_mode,
    managed_id
  );
end
$function$;

-- managed_tournament_schedule_status(bigint,text,bigint)
CREATE OR REPLACE FUNCTION public.managed_tournament_schedule_status(p_target_tournament_id bigint, p_entry_mode text, p_player_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  c jsonb;
begin
  if p_player_id is null then
    return jsonb_build_object('available',false,'reason','managed_player_missing');
  end if;

  c:=public.player_tournament_calendar_conflict(
    p_player_id,
    p_target_tournament_id,
    p_entry_mode
  );

  if coalesce((c->>'conflict')::boolean,false) then
    return jsonb_build_object(
      'available',false,
      'reason',coalesce(c->>'reason','calendar_conflict'),
      'entry_mode',p_entry_mode,
      'player_id',p_player_id,
      'conflict',c
    );
  end if;

  return jsonb_build_object(
    'available',true,
    'reason','available',
    'entry_mode',p_entry_mode,
    'player_id',p_player_id,
    'schedule',c
  );
end
$function$;

-- player_late_entry_status(bigint,bigint)
CREATE OR REPLACE FUNCTION public.player_late_entry_status(p_player_id bigint, p_target_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  career_day date;
  ranking_day date;
  rankv int;
  cutv int;
  schedule jsonb;
begin
  select * into t from public.tournaments where id=p_target_tournament_id;
  if t.id is null then
    return jsonb_build_object('eligible',false,'reason','tournament_not_found');
  end if;
  if not exists(select 1 from public.players where id=p_player_id) then
    return jsonb_build_object('eligible',false,'reason','player_not_found');
  end if;

  select career_date into career_day from public.career_state where id='demo';
  career_day:=coalesce(career_day,date '2025-12-01');

  if coalesce(t.late_entry_slots,0)<=0 then
    return jsonb_build_object('eligible',false,'reason','no_late_entry_slot');
  end if;
  if t.main_entry_deadline is not null and career_day<=t.main_entry_deadline then
    return jsonb_build_object('eligible',false,'reason','regular_entry_still_open','regular_deadline',t.main_entry_deadline,'late_entry_deadline',t.late_entry_deadline);
  end if;
  if t.late_entry_deadline is not null and career_day>t.late_entry_deadline then
    return jsonb_build_object('eligible',false,'reason','late_entry_closed','late_entry_deadline',t.late_entry_deadline);
  end if;

  ranking_day:=(t.start_date + ((8-extract(isodow from t.start_date)::int)%7))-28;
  rankv:=public.player_rank_at_date(p_player_id,ranking_day);
  cutv:=coalesce(t.direct_cut,t.projected_direct_cut,0);

  if cutv<=0 then
    return jsonb_build_object('eligible',false,'reason','missing_original_cut','ranking',rankv,'ranking_date',ranking_day);
  end if;
  if rankv>=cutv then
    return jsonb_build_object('eligible',false,'reason','ranking_not_better_than_original_cut','ranking',rankv,'original_cut',cutv,'ranking_date',ranking_day,'late_entry_deadline',t.late_entry_deadline);
  end if;

  if not coalesce((public.player_event_eligibility(p_player_id,t.id,'singles','direct')->>'eligible')::boolean,false) then
    return jsonb_build_object('eligible',false,'reason','circuit_ineligible','ranking',rankv,'original_cut',cutv);
  end if;

  schedule:=public.player_tournament_calendar_conflict(p_player_id,t.id,'direct');
  if coalesce((schedule->>'conflict')::boolean,false) then
    return jsonb_build_object('eligible',false,'reason','calendar_conflict','schedule',schedule);
  end if;

  return jsonb_build_object(
    'eligible',true,'reason','late_entry_available','ranking',rankv,'ranking_date',ranking_day,
    'original_cut',cutv,'late_entry_deadline',t.late_entry_deadline,'slots',t.late_entry_slots,'player_id',p_player_id
  );
end
$function$;

-- player_performance_bye_status(bigint,bigint)
CREATE OR REPLACE FUNCTION public.player_performance_bye_status(p_player_id bigint, p_target_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  rankv int;
  better_count int:=0;
  accepted boolean:=false;
  candidate boolean:=false;
begin
  select * into t from public.tournaments where id=p_target_tournament_id;
  if t.id is null or not exists(select 1 from public.players where id=p_player_id)
     or coalesce(t.performance_bye_slots,0)<=0 then
    return jsonb_build_object('eligible',false,'reason','no_performance_bye_rule');
  end if;

  rankv:=coalesce(public.player_rank_at_date(p_player_id,coalesce(t.main_entry_deadline,t.start_date)),999999);

  select exists(select 1 from public.tournament_performance_bye_candidate_ids(t.id) x where x.player_id=p_player_id) into candidate;
  if not candidate then
    return jsonb_build_object('eligible',false,'reason','not_source_event_finalist');
  end if;

  if exists(select 1 from public.world_tournament_acceptance_states s where s.tournament_id=t.id) then
    accepted:=exists(
      select 1 from public.world_tournament_acceptance_entries a
      where a.tournament_id=t.id and a.player_id=p_player_id and a.status in ('accepted','promoted')
    ) or exists(
      select 1 from public.wildcard_requests w
      where w.tournament_id=t.id and w.player_id=p_player_id and w.status='accepted'
    );

    select count(*) into better_count
    from public.world_tournament_acceptance_entries a
    where a.tournament_id=t.id and a.status in ('accepted','promoted') and a.effective_rank<rankv;
  else
    accepted:=rankv<=coalesce(t.direct_cut,t.projected_direct_cut,0)
      or exists(
        select 1 from public.wildcard_requests w
        where w.tournament_id=t.id and w.player_id=p_player_id and w.status='accepted'
      );

    select count(*) into better_count
    from public.tournament_candidate_player_ids(t.id,'candidate',256) x
    where x.effective_rank<rankv;
  end if;

  if not accepted then
    return jsonb_build_object('eligible',false,'reason','not_accepted_main_draw');
  end if;
  if better_count<16 then
    return jsonb_build_object('eligible',false,'reason','would_be_top16_seed','better_accepted_candidates',better_count);
  end if;

  return jsonb_build_object(
    'eligible',true,'reason','source_event_finalist_outside_top16_seeds',
    'slots',t.performance_bye_slots,'source_event',t.performance_bye_source_event,
    'better_accepted_candidates',better_count,'player_id',p_player_id
  );
end
$function$;

-- player_special_exempt_status(bigint,bigint)
CREATE OR REPLACE FUNCTION public.player_special_exempt_status(p_player_id bigint, p_target_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  r public.tournament_format_rules%rowtype;
  prev record;
  rankv int;
  primary_id bigint;
begin
  select * into t from public.tournaments where id=p_target_tournament_id;
  if t.id is null or not exists(select 1 from public.players where id=p_player_id) then
    return jsonb_build_object('eligible',false,'reason','missing_target_or_player');
  end if;
  select managed_player_id into primary_id from public.career_state where id='demo';

  select * into r
  from public.tournament_format_rules fr
  where fr.circuit=t.circuit and fr.category=t.category
    and fr.main_draw_size=coalesce(t.singles_draw_size,t.draw_size)
  limit 1;

  if coalesce(r.special_exempt_slots,0)<=0 then
    return jsonb_build_object('eligible',false,'reason','no_special_exempt_slots');
  end if;

  rankv:=coalesce(public.player_rank_at_date(p_player_id,coalesce(t.main_entry_deadline,t.start_date)),999999);
  if rankv<=coalesce(t.direct_cut,t.projected_direct_cut,0) then
    return jsonb_build_object('eligible',false,'reason','already_direct_acceptance','ranking',rankv);
  end if;

  select tr.tournament_id,tr.user_round,pt.name,pt.category,pt.circuit,pt.country,pt.start_date,pt.end_date
  into prev
  from public.tournament_runs tr
  join public.tournaments pt on pt.id=tr.tournament_id
  where tr.tournament_id<>t.id
    and (tr.managed_player_id=p_player_id or (tr.managed_player_id is null and p_player_id=primary_id))
    and pt.start_date<t.start_date
    and coalesce(pt.end_date,pt.start_date)>=coalesce(t.qualifying_start_date,t.start_date)
    and coalesce(pt.end_date,pt.start_date)<=t.start_date
    and tr.user_round in ('Champion','F','SF')
    and public.tournament_special_exempt_eligible(pt.id,t.id)
  order by coalesce(pt.end_date,pt.start_date) desc,tr.id desc
  limit 1;

  if prev.tournament_id is null then
    return jsonb_build_object('eligible',false,'reason','no_qualified_previous_event','slots',r.special_exempt_slots);
  end if;

  return jsonb_build_object(
    'eligible',true,'reason','still_competing_previous_week','slots',r.special_exempt_slots,
    'source_tournament_id',prev.tournament_id,'source_tournament',prev.name,'source_result',prev.user_round,
    'qualifying_start',t.qualifying_start_date,'target',t.name,'player_id',p_player_id
  );
end
$function$;

-- player_tournament_pathway_status(bigint,bigint)
CREATE OR REPLACE FUNCTION public.player_tournament_pathway_status(p_player_id bigint, p_target_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  le jsonb;
  hit boolean;
begin
  select * into t from public.tournaments where id=p_target_tournament_id;
  if t.id is null or not exists(select 1 from public.players where id=p_player_id) then
    return jsonb_build_object('eligible',false,'reason','missing_context');
  end if;

  le:=public.player_late_entry_status(p_player_id,t.id);
  if coalesce((le->>'eligible')::boolean,false) then
    return jsonb_build_object('eligible',true,'mode','late_entry','label','Late Entry ATP','details',le);
  end if;

  select exists(select 1 from public.nextgen_accelerator_candidate_ids(t.id,'main') x where x.player_id=p_player_id) into hit;
  if hit then return jsonb_build_object('eligible',true,'mode','nextgen_accelerator','label','Next Gen Accelerator · tableau'); end if;

  select exists(select 1 from public.nextgen_accelerator_candidate_ids(t.id,'qualifying') x where x.player_id=p_player_id) into hit;
  if hit then return jsonb_build_object('eligible',true,'mode','nextgen_accelerator_qualifying','label','Next Gen Accelerator · qualifs'); end if;

  select exists(select 1 from public.junior_accelerator_candidate_ids(t.id,'main') x where x.player_id=p_player_id) into hit;
  if hit then return jsonb_build_object('eligible',true,'mode','junior_accelerator','label','Junior Accelerator · tableau'); end if;

  select exists(select 1 from public.junior_accelerator_candidate_ids(t.id,'qualifying') x where x.player_id=p_player_id) into hit;
  if hit then return jsonb_build_object('eligible',true,'mode','junior_accelerator_qualifying','label','Junior Accelerator · qualifs'); end if;

  select exists(select 1 from public.atp_college_accelerator_candidate_ids(t.id,'main') x where x.player_id=p_player_id) into hit;
  if hit then return jsonb_build_object('eligible',true,'mode','college_accelerator','label','College Accelerator · tableau'); end if;

  select exists(select 1 from public.atp_college_accelerator_candidate_ids(t.id,'qualifying') x where x.player_id=p_player_id) into hit;
  if hit then return jsonb_build_object('eligible',true,'mode','college_accelerator_qualifying','label','College Accelerator · qualifs'); end if;

  select exists(select 1 from public.college_accelerator_candidate_ids(t.id) x where x.player_id=p_player_id) into hit;
  if hit and t.circuit='ITF' then return jsonb_build_object('eligible',true,'mode','college_accelerator','label','ITF College Accelerator · tableau'); end if;

  select exists(select 1 from public.junior_reserved_candidate_ids(t.id) x where x.player_id=p_player_id) into hit;
  if hit then return jsonb_build_object('eligible',true,'mode','junior_reserved','label','ITF Junior Accelerator · tableau'); end if;

  return jsonb_build_object('eligible',false,'reason','no_pathway','late_entry',le);
end
$function$;

