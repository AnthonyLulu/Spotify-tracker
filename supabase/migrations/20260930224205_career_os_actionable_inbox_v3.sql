do $do$
declare
  v text;
begin
  select pg_get_functiondef(p.oid) into v
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='career_sync_actionable_inbox';

  if strpos(v, $q$'injury_id',i.related_entity_id$q$)=0 then
    v := replace(
      v,
      '  v_total:=v_sponsors+v_scouting+v_contracts+v_medical+v_partners+v_staff;',
      $patch$
  update public.inbox_items i
  set action_payload=jsonb_build_object(
        'injury_id',i.related_entity_id,
        'protocol',coalesce(i.action_payload->>'protocol','Récupération active')
      )
  where i.related_entity_type='injury'
    and i.decision_status='pending'
    and i.action_type='medical_protocol';

  v_total:=v_sponsors+v_scouting+v_contracts+v_medical+v_partners+v_staff;
$patch$
    );
  end if;

  if strpos(v, $q$secondary_action_label='Laisser partir'$q$)=0 then
    v := replace(
      v,
      '  v_total:=v_sponsors+v_scouting+v_contracts+v_medical+v_partners+v_staff;',
      $patch$
  update public.inbox_items i
  set action_type='match_staff_offer',
      action_label='S’aligner',
      action_payload=jsonb_build_object('offer_id',i.related_entity_id),
      secondary_action_type='release_staff_offer',
      secondary_action_label='Laisser partir',
      secondary_action_payload=jsonb_build_object('offer_id',i.related_entity_id)
  where i.related_entity_type='staff_external_offer'
    and i.decision_status='pending';

  v_total:=v_sponsors+v_scouting+v_contracts+v_medical+v_partners+v_staff;
$patch$
    );
  end if;

  if strpos(v, $q$secondary_action_label='Voir le contrat'$q$)=0 then
    v := replace(
      v,
      '  v_total:=v_sponsors+v_scouting+v_contracts+v_medical+v_partners+v_staff;',
      $patch$
  update public.inbox_items i
  set action_type='renew_contract',
      action_label='Renouveler +1 an',
      action_payload=jsonb_build_object('contract_id',i.related_entity_id),
      secondary_action_type='open_route',
      secondary_action_label='Voir le contrat',
      secondary_action_payload=jsonb_build_object('route','contracts')
  where i.related_entity_type='contract'
    and i.decision_status='pending';

  v_total:=v_sponsors+v_scouting+v_contracts+v_medical+v_partners+v_staff;
$patch$
    );
  end if;

  execute v;
end
$do$;

do $do$
declare
  v text;
begin
  select pg_get_functiondef(p.oid) into v
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='career_publish_weekly_digest';

  v := replace(
    v,
    $q$'weekly_digest','Rapport manager · semaine '||p_week,v_body,'home',false,p_date,$q$,
    $q$'weekly_digest','Rapport manager · semaine '||p_week,v_body,'careerhub',false,p_date,$q$
  );
  v := replace(
    v,
    $q$'open_route','Ouvrir le centre manager',jsonb_build_object('route','home'),'info'$q$,
    $q$'open_route','Ouvrir le centre manager',jsonb_build_object('route','careerhub'),'info'$q$
  );
  execute v;
end
$do$;

update public.inbox_items i
set action_payload=jsonb_build_object(
      'injury_id',i.related_entity_id,
      'protocol',coalesce(i.action_payload->>'protocol','Récupération active')
    )
where i.related_entity_type='injury'
  and i.decision_status='pending'
  and i.action_type='medical_protocol';

update public.inbox_items i
set action_type='match_staff_offer',
    action_label='S’aligner',
    action_payload=jsonb_build_object('offer_id',i.related_entity_id),
    secondary_action_type='release_staff_offer',
    secondary_action_label='Laisser partir',
    secondary_action_payload=jsonb_build_object('offer_id',i.related_entity_id)
where i.related_entity_type='staff_external_offer'
  and i.decision_status='pending';

update public.inbox_items i
set action_type='renew_contract',
    action_label='Renouveler +1 an',
    action_payload=jsonb_build_object('contract_id',i.related_entity_id),
    secondary_action_type='open_route',
    secondary_action_label='Voir le contrat',
    secondary_action_payload=jsonb_build_object('route','contracts')
where i.related_entity_type='contract'
  and i.decision_status='pending';

update public.inbox_items
set action_route='careerhub',
    action_payload=jsonb_build_object('route','careerhub')
where kind='weekly_digest'
  and action_type='open_route';

select public.career_sync_actionable_inbox(
  (select career_date from public.career_state where id='demo'),
  (select week from public.career_state where id='demo')
);
