-- Validate current V8 saves and supported legacy slots in career diagnostics.
CREATE OR REPLACE FUNCTION public.career_os_integrity_audit(p_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
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
  v_sponsor_missing_lifecycle int;
  v_sponsor_overpaid int;
  v_sponsor_expired_active int;
  v_sponsor_ledger_mismatch int;
  v_media_overdue int;
  v_self_relations int;
  v_ok boolean;
begin
  select * into c from public.career_state where id='demo';
  if not found then
    return jsonb_build_object('ok',false,'reason','career_missing','model','CB-CAREER-INTEGRITY-v4');
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
  where coalesce(snapshot_scope,'') not in (
      'managed_timeline_v8','managed_timeline_live_v8',
      'managed_squad_live_checkpoint_exact_v7','managed_squad_ledgers_exact_v6',
      'managed_squad_ledger_exact_v5','managed_squad_exact_v4',
      'managed_academy_exact_v3','managed_world_exact_v2'
    );

  select count(*) into v_invalid_save_snapshot
  from public.game_save_slots
  where managed_snapshot is null
     or jsonb_typeof(managed_snapshot)<>'object'
     or local_payload is null
     or jsonb_typeof(local_payload)<>'object'
     or case coalesce(snapshot_scope,'')
       when 'managed_timeline_v8' then
         coalesce(managed_snapshot->>'model','')<>'CB-MANAGED-SAVE-v8'
         or coalesce(managed_snapshot->>'checkpoint_kind','')='live'
         or jsonb_typeof(managed_snapshot->'record_occurrences') is distinct from 'array'
         or jsonb_typeof(managed_snapshot->'court_boss_match_stat_lines') is distinct from 'array'
         or jsonb_typeof(managed_snapshot->'court_boss_player_awards') is distinct from 'array'
         or jsonb_typeof(managed_snapshot->'court_boss_hof_profiles') is distinct from 'array'
         or jsonb_typeof(managed_snapshot->'court_boss_hof_classes') is distinct from 'array'
         or jsonb_typeof(managed_snapshot->'court_boss_retirement_ceremonies') is distinct from 'array'
       when 'managed_timeline_live_v8' then
         coalesce(managed_snapshot->>'model','')<>'CB-MANAGED-SAVE-v8'
         or coalesce(managed_snapshot->>'checkpoint_kind','')<>'live'
         or jsonb_typeof(managed_snapshot->'live_match_sessions') is distinct from 'array'
       when 'managed_squad_live_checkpoint_exact_v7' then coalesce(managed_snapshot->>'model','')<>'CB-MANAGED-SAVE-v7'
       when 'managed_squad_ledgers_exact_v6' then coalesce(managed_snapshot->>'model','')<>'CB-MANAGED-SAVE-v6'
       when 'managed_squad_ledger_exact_v5' then coalesce(managed_snapshot->>'model','')<>'CB-MANAGED-SAVE-v5'
       when 'managed_squad_exact_v4' then coalesce(managed_snapshot->>'model','')<>'CB-MANAGED-SAVE-v4'
       when 'managed_academy_exact_v3' then coalesce(managed_snapshot->>'model','')<>'CB-MANAGED-SAVE-v3'
       when 'managed_world_exact_v2' then coalesce(managed_snapshot->>'model','')<>'CB-MANAGED-SAVE-v2'
       else true
     end;

  select count(*) into v_save_metadata_mismatch
  from public.game_save_slots
  where coalesce(snapshot_scope,'') in (
      'managed_timeline_v8','managed_timeline_live_v8',
      'managed_squad_live_checkpoint_exact_v7','managed_squad_ledgers_exact_v6',
      'managed_squad_ledger_exact_v5','managed_squad_exact_v4',
      'managed_academy_exact_v3','managed_world_exact_v2'
    )
    and (
      coalesce(managed_snapshot->>'career_date','')<>coalesce(career_date::text,'')
      or coalesce((managed_snapshot->>'week')::int,-1)<>coalesce(week,-1)
      or coalesce((managed_snapshot->>'managed_player_id')::bigint,-1)<>coalesce(managed_player_id,-1)
      or coalesce(managed_snapshot#>>'{career,player_name}','')<>coalesce(player_name,'')
    );

  select count(*) into v_save_local_payload_mismatch
  from public.game_save_slots
  where coalesce(snapshot_scope,'') in (
      'managed_timeline_v8','managed_timeline_live_v8',
      'managed_squad_live_checkpoint_exact_v7','managed_squad_ledgers_exact_v6',
      'managed_squad_ledger_exact_v5','managed_squad_exact_v4',
      'managed_academy_exact_v3','managed_world_exact_v2'
    )
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

  select count(*) into v_sponsor_missing_lifecycle
  from public.sponsor_offers
  where status='accepted'
    and (accepted_on is null or starts_on is null or ends_on is null);

  select count(*) into v_sponsor_overpaid
  from public.sponsor_offers
  where coalesce(weeks_paid,0)>greatest(1,duration_weeks);

  select count(*) into v_sponsor_expired_active
  from public.sponsor_offers
  where status='accepted'
    and (
      (ends_on is not null and ends_on<coalesce(p_date,c.career_date,current_date))
      or coalesce(weeks_paid,0)>=greatest(1,duration_weeks)
    );

  select count(*) into v_sponsor_ledger_mismatch
  from public.sponsor_offers s
  where coalesce(s.weeks_paid,0)<>(
    select count(*)
    from public.finance_transactions ft
    where ft.category='sponsor_income'
      and ft.source_type='sponsor_offer'
      and ft.source_id=s.id
  );

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
    and v_legacy_slots=0
    and v_invalid_save_snapshot=0
    and v_save_metadata_mismatch=0
    and v_save_local_payload_mismatch=0
    and v_invalid_save_slot_shape=0
    and v_sponsor_missing_lifecycle=0
    and v_sponsor_overpaid=0
    and v_sponsor_expired_active=0
    and v_sponsor_ledger_mismatch=0;

  return jsonb_build_object(
    'ok',v_ok,
    'model','CB-CAREER-INTEGRITY-v4',
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
    'sponsor_missing_lifecycle',v_sponsor_missing_lifecycle,
    'sponsor_overpaid',v_sponsor_overpaid,
    'sponsor_expired_still_active',v_sponsor_expired_active,
    'sponsor_ledger_mismatches',v_sponsor_ledger_mismatch,
    'stale_media_questions',v_media_overdue,
    'self_relationships',v_self_relations
  );
end;
$function$
;
