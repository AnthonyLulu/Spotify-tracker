create or replace function public.career_os_integrity_audit(p_date date)
returns jsonb
language plpgsql
set search_path to 'public'
as $function$
declare
  c public.career_state%rowtype;
  v_managed bigint;
  v_year int;
  v_capacity int;
  v_youth int;
  v_missing_plan int;
  v_duplicate_inbox int;
  v_expired_pending int;
  v_academy_overflow int;
  v_managed_injuries int;
  v_double_commitments int;
  v_duplicate_staff int;
  v_orphan_roster int;
  v_overdue_contracts int;
  v_template int;
  v_template_integrity int;
  v_legacy_slots int;
  v_save_slots int;
  v_invalid_save_snapshot int;
  v_save_metadata_mismatch int;
  v_save_local_payload_mismatch int;
  v_invalid_save_slot_shape int;
  v_media_overdue int;
  v_self_relations int;
  v_ok boolean;
begin
  select * into c from public.career_state where id='demo';
  if not found then
    return jsonb_build_object('ok',false,'reason','career_missing','model','CB-CAREER-INTEGRITY-v2');
  end if;

  v_managed:=c.managed_player_id;
  v_year:=extract(year from coalesce(p_date,c.career_date,current_date))::int;

  select coalesce(youth_capacity,8) into v_capacity
  from public.academies where id='demo';
  v_capacity:=coalesce(v_capacity,8);

  select count(*) into v_youth
  from public.academy_youth
  where status in ('prospect','signed','academy');

  select count(*) into v_missing_plan
  from (select 1) q
  where v_managed is not null
    and not exists(
      select 1 from public.player_season_plans
      where player_id=v_managed and season=v_year
    );

  select count(*) into v_duplicate_inbox
  from (
    select related_entity_type,related_entity_id
    from public.inbox_items
    where decision_status='pending'
      and related_entity_type is not null
      and related_entity_id is not null
    group by related_entity_type,related_entity_id
    having count(*)>1
  ) d;

  select count(*) into v_expired_pending
  from public.inbox_items
  where decision_status='pending'
    and expires_at is not null
    and expires_at<coalesce(p_date,c.career_date,current_date);

  v_academy_overflow:=greatest(0,v_youth-v_capacity);

  select count(*) into v_managed_injuries
  from public.injuries
  where player_id=v_managed and status='Active';

  select count(*) into v_double_commitments
  from public.player_doubles_commitments
  where player_id=v_managed and active=true;

  select count(*) into v_duplicate_staff
  from (
    select profile_id
    from public.staff
    where profile_id is not null
    group by profile_id
    having count(*)>1
  ) s;

  select count(*) into v_orphan_roster
  from public.academy_roster ar
  left join public.players p on p.id=ar.player_id
  where ar.status='active' and p.id is null;

  select count(*) into v_overdue_contracts
  from public.contracts
  where status='active'
    and end_date<coalesce(p_date,c.career_date,current_date);

  select count(*) into v_template
  from public.game_career_templates
  where id='default-2025-12-01';

  select count(*) into v_template_integrity
  from public.game_career_templates
  where id='default-2025-12-01'
    and managed_snapshot is not null
    and local_payload is not null
    and managed_snapshot->>'model'='CB-MANAGED-SAVE-v2'
    and managed_snapshot->>'career_date'='2025-12-01'
    and coalesce((managed_snapshot->>'week')::int,0)=1
    and local_payload->>'date'='2025-12-01'
    and coalesce((local_payload->>'week')::int,0)=1;

  select count(*) into v_save_slots
  from public.game_save_slots;

  select count(*) into v_legacy_slots
  from public.game_save_slots
  where coalesce(snapshot_scope,'')<>'managed_world_exact_v2';

  select count(*) into v_invalid_save_snapshot
  from public.game_save_slots
  where coalesce(snapshot_scope,'')='managed_world_exact_v2'
    and (
      managed_snapshot is null
      or jsonb_typeof(managed_snapshot)<>'object'
      or coalesce(managed_snapshot->>'model','')<>'CB-MANAGED-SAVE-v2'
      or local_payload is null
      or jsonb_typeof(local_payload)<>'object'
    );

  select count(*) into v_save_metadata_mismatch
  from public.game_save_slots
  where coalesce(snapshot_scope,'')='managed_world_exact_v2'
    and (
      coalesce(managed_snapshot->>'career_date','')<>coalesce(career_date::text,'')
      or coalesce((managed_snapshot->>'week')::int,-1)<>coalesce(week,-1)
      or coalesce((managed_snapshot->>'managed_player_id')::bigint,-1)<>coalesce(managed_player_id,-1)
      or coalesce(managed_snapshot#>>'{career,player_name}','')<>coalesce(player_name,'')
    );

  select count(*) into v_save_local_payload_mismatch
  from public.game_save_slots
  where coalesce(snapshot_scope,'')='managed_world_exact_v2'
    and (
      (local_payload ? 'date' and coalesce(local_payload->>'date','')<>coalesce(career_date::text,''))
      or
      (local_payload ? 'week' and coalesce((local_payload->>'week')::int,-1)<>coalesce(week,-1))
    );

  select count(*) into v_invalid_save_slot_shape
  from public.game_save_slots
  where slot_no not between 0 and 9
     or slot_type not in ('manual','autosave','quick')
     or (slot_no=0 and slot_type<>'autosave')
     or (slot_no=9 and slot_type<>'quick');

  select count(*) into v_media_overdue
  from public.media_events
  where response_status='pending'
    and event_date<coalesce(p_date,c.career_date,current_date)-30;

  select count(*) into v_self_relations
  from public.player_relationships
  where player_a_id=player_b_id;

  v_ok:=v_missing_plan=0
    and v_duplicate_inbox=0
    and v_expired_pending=0
    and v_academy_overflow=0
    and v_managed_injuries<=1
    and v_double_commitments<=1
    and v_duplicate_staff=0
    and v_orphan_roster=0
    and v_overdue_contracts=0
    and v_self_relations=0
    and v_template_integrity=1
    and v_invalid_save_snapshot=0
    and v_save_metadata_mismatch=0
    and v_save_local_payload_mismatch=0
    and v_invalid_save_slot_shape=0;

  return jsonb_build_object(
    'ok',v_ok,
    'model','CB-CAREER-INTEGRITY-v2',
    'date',coalesce(p_date,c.career_date,current_date),
    'missing_season_plan',v_missing_plan,
    'duplicate_pending_inbox',v_duplicate_inbox,
    'expired_pending_decisions',v_expired_pending,
    'academy_capacity',v_capacity,
    'academy_active_youth',v_youth,
    'academy_overflow',v_academy_overflow,
    'managed_active_injuries',v_managed_injuries,
    'active_doubles_commitments',v_double_commitments,
    'duplicate_staff_profiles',v_duplicate_staff,
    'orphan_academy_roster',v_orphan_roster,
    'overdue_active_contracts',v_overdue_contracts,
    'baseline_template_ready',v_template>0,
    'baseline_template_integrity',v_template_integrity=1,
    'save_slots_total',v_save_slots,
    'legacy_save_slots',v_legacy_slots,
    'invalid_save_snapshots',v_invalid_save_snapshot,
    'save_metadata_mismatches',v_save_metadata_mismatch,
    'save_local_payload_mismatches',v_save_local_payload_mismatch,
    'invalid_save_slot_shape',v_invalid_save_slot_shape,
    'stale_media_questions',v_media_overdue,
    'self_relationships',v_self_relations
  );
end;
$function$;
