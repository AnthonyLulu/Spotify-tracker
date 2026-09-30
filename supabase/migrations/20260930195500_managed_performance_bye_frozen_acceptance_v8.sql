-- Performance Bye status follows the frozen main-draw acceptance list once it exists.
CREATE OR REPLACE FUNCTION public.managed_performance_bye_status(p_target_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  c public.career_state%rowtype;
  managed_id bigint;
  better_count int:=0;
  accepted boolean:=false;
  candidate boolean:=false;
begin
  select * into t from public.tournaments where id=p_target_tournament_id;
  select * into c from public.career_state where id='demo';
  managed_id:=c.managed_player_id;

  if t.id is null or managed_id is null or coalesce(t.performance_bye_slots,0)<=0 then
    return jsonb_build_object('eligible',false,'reason','no_performance_bye_rule');
  end if;

  select exists(
    select 1
    from public.tournament_performance_bye_candidate_ids(t.id) x
    where x.player_id=managed_id
  ) into candidate;

  if not candidate then
    return jsonb_build_object('eligible',false,'reason','not_source_event_finalist');
  end if;

  if exists(
    select 1 from public.world_tournament_acceptance_states s
    where s.tournament_id=t.id
  ) then
    accepted:=exists(
      select 1
      from public.world_tournament_acceptance_entries a
      where a.tournament_id=t.id
        and a.player_id=managed_id
        and a.status in ('accepted','promoted')
    ) or exists(
      select 1 from public.wildcard_requests w
      where w.tournament_id=t.id and w.status='accepted'
    );

    select count(*) into better_count
    from public.world_tournament_acceptance_entries a
    where a.tournament_id=t.id
      and a.status in ('accepted','promoted')
      and a.effective_rank<coalesce(c.singles_rank,999999);
  else
    accepted:=coalesce(c.singles_rank,999999)<=coalesce(t.direct_cut,t.projected_direct_cut,0)
      or exists(
        select 1 from public.wildcard_requests w
        where w.tournament_id=t.id and w.status='accepted'
      );

    select count(*) into better_count
    from public.tournament_candidate_player_ids(t.id,'candidate',256) x
    where x.effective_rank<coalesce(c.singles_rank,999999);
  end if;

  if not accepted then
    return jsonb_build_object('eligible',false,'reason','not_accepted_main_draw');
  end if;

  if better_count<16 then
    return jsonb_build_object(
      'eligible',false,'reason','would_be_top16_seed',
      'better_accepted_candidates',better_count
    );
  end if;

  return jsonb_build_object(
    'eligible',true,
    'reason','source_event_finalist_outside_top16_seeds',
    'slots',t.performance_bye_slots,
    'source_event',t.performance_bye_source_event,
    'better_accepted_candidates',better_count
  );
end
$function$
;
