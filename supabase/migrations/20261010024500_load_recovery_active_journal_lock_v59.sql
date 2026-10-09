-- Court Boss P0 v59: protect crash-recovery journal against overlapping load requests.
-- A new prepare must NEVER erase an already-applying or rollback-pending snapshot.
-- Prepared-but-not-applying journal may be replaced; the stale operation token
-- will then fail its transition to applying, without any restore taking place.
-- No table modifications or save-data rewrites.
CREATE OR REPLACE FUNCTION public.cb_prepare_load_recovery_v33(p_browser_key text, p_slot_no integer, p_safety_snapshot jsonb, p_safety_digest text, p_legacy_snapshot jsonb, p_legacy_present boolean, p_legacy_digest text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_operation_id uuid := gen_random_uuid();
  v_saved_operation_id uuid;
begin
  if p_browser_key is null or p_browser_key !~ '^browser:[0-9a-fA-F-]{36}$' then
    raise exception 'invalid browser key';
  end if;
  if p_slot_no < 0 or p_slot_no > 9 then
    raise exception 'invalid slot';
  end if;
  if p_safety_snapshot is null or jsonb_typeof(p_safety_snapshot) <> 'object' then
    raise exception 'invalid safety snapshot';
  end if;
  if p_safety_digest is null or p_safety_digest !~ '^[0-9a-fA-F]{64}$' then
    raise exception 'invalid safety digest';
  end if;
  if coalesce(p_legacy_digest,'') <> '' and p_legacy_digest !~ '^[0-9a-fA-F]{64}$' then
    raise exception 'invalid legacy digest';
  end if;

  insert into court_boss_private.load_recovery_v33(
    browser_key,operation_id,slot_no,status,safety_snapshot,safety_digest,
    legacy_snapshot,legacy_present,legacy_digest,last_error,created_at,updated_at
  ) values (
    p_browser_key,v_operation_id,p_slot_no,'prepared',p_safety_snapshot,lower(p_safety_digest),
    p_legacy_snapshot,coalesce(p_legacy_present,false),lower(coalesce(p_legacy_digest,'')),null,now(),now()
  )
  on conflict(browser_key) do update set
    operation_id=excluded.operation_id,
    slot_no=excluded.slot_no,
    status='prepared',
    safety_snapshot=excluded.safety_snapshot,
    safety_digest=excluded.safety_digest,
    legacy_snapshot=excluded.legacy_snapshot,
    legacy_present=excluded.legacy_present,
    legacy_digest=excluded.legacy_digest,
    last_error=null,
    created_at=now(),
    updated_at=now()
  where court_boss_private.load_recovery_v33.status='prepared'
  returning operation_id into v_saved_operation_id;

  if v_saved_operation_id is null then
    raise exception 'load_recovery_locked: active or pending recovery journal must be resolved first'
      using errcode='55P03';
  end if;

  return v_saved_operation_id;
end
$function$
;
