-- Career OS inbox orchestration v2
-- Centralizes actionable decisions in career_sync_actionable_inbox and keeps weekly digest informational.

CREATE OR REPLACE FUNCTION public.career_publish_weekly_digest(p_date date, p_week integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  c public.career_state%rowtype;
  v_unread int:=0;
  v_pending int:=0;
  v_scouts int:=0;
  v_expiring int:=0;
  v_body text;
  v_created boolean:=false;
begin
  select * into c from public.career_state where id='demo';
  if not found then
    return jsonb_build_object('ok',false,'reason','career_missing','model','CB-CAREER-DIGEST-v3');
  end if;

  select count(*) into v_unread from public.inbox_items where not is_read;
  select count(*) into v_pending from public.inbox_items where decision_status='pending'
    and (expires_at is null or expires_at>=p_date);
  select count(*) into v_scouts from public.scouting_assignments where status='completed'
    and coalesce(last_update,p_date)>=p_date-7;
  select count(*) into v_expiring from public.contracts where status='active'
    and end_date between p_date and p_date+35;

  if not exists(select 1 from public.inbox_items where kind='weekly_digest' and game_date=p_date) then
    v_body:='Classement simple #'||coalesce(c.singles_rank,0)||' · double #'||coalesce(c.doubles_rank,0)||
      ' · forme '||coalesce(c.form,0)||'% · fitness '||coalesce(c.fitness,0)||'% · fatigue '||coalesce(c.fatigue,0)||'%.'||
      case when v_pending>0 then ' '||v_pending||' décision(s) attendent ton arbitrage.' else '' end||
      case when v_scouts>0 then ' '||v_scouts||' rapport(s) scouting récent(s).' else '' end||
      case when v_expiring>0 then ' '||v_expiring||' contrat(s) arrivent à échéance sous 5 semaines.' else '' end;

    insert into public.inbox_items(
      kind,title,body,action_route,is_read,game_date,priority,
      action_type,action_label,action_payload,decision_status
    ) values(
      'weekly_digest','Rapport manager · semaine '||p_week,v_body,'home',false,p_date,
      case when v_pending>0 or v_expiring>0 or coalesce(c.fatigue,0)>=70 then 'high' else 'normal' end,
      'open_route','Ouvrir le centre manager',jsonb_build_object('route','home'),'info'
    );
    v_created:=true;
  end if;

  if not exists(
    select 1 from public.career_event_log
    where event_date=p_date and week=p_week and system='career' and event_type='weekly_digest'
  ) then
    insert into public.career_event_log(event_date,week,system,event_type,summary,payload)
    values(
      p_date,p_week,'career','weekly_digest','Rapport manager hebdomadaire',
      jsonb_build_object(
        'rank',c.singles_rank,'doubles_rank',c.doubles_rank,'fitness',c.fitness,
        'fatigue',c.fatigue,'pending_decisions',v_pending,'expiring_contracts',v_expiring
      )
    );
  end if;

  return jsonb_build_object(
    'ok',true,'created',v_created,'unread',v_unread,'pending_decisions',v_pending,
    'expiring_contracts',v_expiring,'completed_scouting',v_scouts,
    'model','CB-CAREER-DIGEST-v3'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.career_sync_actionable_inbox(p_date date, p_week integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  c public.career_state%rowtype;
  v_sponsors int:=0;
  v_scouting int:=0;
  v_contracts int:=0;
  v_medical int:=0;
  v_partners int:=0;
  v_staff int:=0;
  v_fatigue int:=0;
  v_total int:=0;
begin
  select * into c from public.career_state where id='demo';
  if not found then
    return jsonb_build_object('ok',false,'reason','career_missing','model','CB-CAREER-INBOX-v2');
  end if;

  update public.inbox_items
  set decision_status='expired'
  where decision_status='pending'
    and expires_at is not null
    and expires_at<p_date;

  insert into public.inbox_items(
    kind,title,body,action_route,is_read,game_date,priority,
    action_type,action_label,action_payload,
    secondary_action_type,secondary_action_label,secondary_action_payload,
    decision_status,related_entity_type,related_entity_id,expires_at
  )
  select
    'commercial','Offre sponsor · '||s.brand,
    s.brand||' propose '||round(s.weekly_value)::text||' €/sem. et '||round(s.signing_bonus)::text||' € de prime. '||coalesce(s.requirement,''),
    'finance',false,p_date,'high',
    'accept_sponsor','Accepter',jsonb_build_object('offer_id',s.id),
    'decline_sponsor','Refuser',jsonb_build_object('offer_id',s.id),
    'pending','sponsor_offer',s.id,p_date+21
  from public.sponsor_offers s
  where s.status in ('available','pending')
    and not exists(
      select 1 from public.inbox_items i
      where i.related_entity_type='sponsor_offer' and i.related_entity_id=s.id
        and i.decision_status in ('pending','resolved')
    );
  get diagnostics v_sponsors=row_count;

  insert into public.inbox_items(
    kind,title,body,action_route,is_read,game_date,priority,
    action_type,action_label,action_payload,decision_status,
    related_entity_type,related_entity_id
  )
  select
    'scouting','Rapport scouting disponible · '||coalesce(sa.region,'Mission'),
    coalesce(sa.scout_name,'Le recruteur')||' a terminé sa mission '||coalesce(sa.focus,'')||
      '. Confiance '||coalesce(sa.confidence,0)::text||'%.',
    'scouting',false,p_date,'normal',
    'open_route','Voir le rapport',jsonb_build_object('route','scouting'),'info',
    'scouting_assignment',sa.id
  from public.scouting_assignments sa
  where sa.status='completed'
    and not exists(
      select 1 from public.inbox_items i
      where i.related_entity_type='scouting_assignment' and i.related_entity_id=sa.id
    );
  get diagnostics v_scouting=row_count;

  insert into public.inbox_items(
    kind,title,body,action_route,is_read,game_date,priority,
    action_type,action_label,action_payload,decision_status,
    related_entity_type,related_entity_id,expires_at
  )
  select
    'contract','Contrat à renouveler · '||co.subject_name,
    co.subject_name||' arrive en fin de contrat le '||to_char(co.end_date,'DD/MM/YYYY')||
      '. Salaire actuel : '||round(co.weekly_salary)::text||' €/sem.',
    'contracts',false,p_date,
    case when co.end_date<=p_date+14 then 'urgent' else 'high' end,
    'open_route','Voir les contrats',jsonb_build_object('route','contracts'),'pending',
    'contract',co.id,co.end_date
  from public.contracts co
  where co.status='active'
    and co.end_date between p_date and p_date+35
    and not exists(
      select 1 from public.inbox_items i
      where i.related_entity_type='contract' and i.related_entity_id=co.id
        and i.decision_status in ('pending','resolved')
    );
  get diagnostics v_contracts=row_count;

  if c.managed_player_id is not null then
    insert into public.inbox_items(
      kind,title,body,action_route,is_read,game_date,priority,
      action_type,action_label,action_payload,
      secondary_action_type,secondary_action_label,secondary_action_payload,
      decision_status,related_entity_type,related_entity_id,expires_at
    )
    select
      'medical','Alerte médicale · '||inj.injury_type,
      'Blessure '||inj.severity||'. Retour estimé : '||coalesce(to_char(inj.expected_return,'DD/MM/YYYY'),'à déterminer')||
        ' · risque d’aggravation '||coalesce(inj.aggravation_risk,0)::text||'%.',
      'medical',false,p_date,'urgent',
      'medical_protocol','Récupération active',jsonb_build_object('injury_id',inj.id,'protocol','Récupération active'),
      'open_route','Voir le dossier',jsonb_build_object('route','medical'),
      'pending','injury',inj.id,inj.expected_return
    from public.injuries inj
    where inj.player_id=c.managed_player_id and inj.status='Active'
      and not exists(
        select 1 from public.inbox_items i
        where i.related_entity_type='injury' and i.related_entity_id=inj.id
          and i.decision_status in ('pending','resolved')
      );
    get diagnostics v_medical=row_count;

    insert into public.inbox_items(
      kind,title,body,action_route,is_read,game_date,priority,
      action_type,action_label,action_payload,
      secondary_action_type,secondary_action_label,secondary_action_payload,
      decision_status,related_entity_type,related_entity_id,expires_at
    )
    select
      'double','Proposition de double · '||coalesce(p.name,'Joueur'),
      coalesce(p.name,'Un joueur')||' te propose un partenariat principal. Chimie '||
        coalesce(o.chemistry,0)::text||'% · compatibilité '||coalesce(o.compatibility,0)::text||'%.',
      'doubles',false,p_date,'high',
      'respond_partner_offer','Accepter',jsonb_build_object('offer_id',o.id,'decision','accept'),
      'respond_partner_offer','Refuser',jsonb_build_object('offer_id',o.id,'decision','decline'),
      'pending','doubles_partner_offer',o.id,o.expires_at
    from public.doubles_partner_offers o
    left join public.players p on p.id=o.from_player_id
    where o.to_player_id=c.managed_player_id
      and o.direction='incoming' and o.status='pending'
      and coalesce(o.expires_at,p_date)>=p_date
      and not exists(
        select 1 from public.inbox_items i
        where i.related_entity_type='doubles_partner_offer' and i.related_entity_id=o.id
          and i.decision_status in ('pending','resolved')
      );
    get diagnostics v_partners=row_count;
  end if;

  insert into public.inbox_items(
    kind,title,body,action_route,is_read,game_date,priority,
    action_type,action_label,action_payload,
    secondary_action_type,secondary_action_label,secondary_action_payload,
    decision_status,related_entity_type,related_entity_id,expires_at
  )
  select
    'staff','Offre externe pour ton staff · '||coalesce(sp.name,'Staff'),
    coalesce(sp.name,'Un membre du staff')||' est sollicité par '||coalesce(p.name,'un autre joueur')||
      '. Offre : '||round(u.offered_weekly)::text||' €/sem. · décision avant '||to_char(u.deadline,'DD/MM/YYYY')||'.',
    'staff',false,p_date,'urgent',
    'match_staff_offer','Aligner l’offre',jsonb_build_object('offer_id',u.id),
    'release_staff_offer','Laisser partir',jsonb_build_object('offer_id',u.id),
    'pending','staff_external_offer',u.id,u.deadline
  from public.user_staff_external_offers u
  left join public.staff_profiles sp on sp.id=u.staff_profile_id
  left join public.players p on p.id=u.competitor_player_id
  where u.status='pending' and coalesce(u.deadline,p_date)>=p_date
    and not exists(
      select 1 from public.inbox_items i
      where i.related_entity_type='staff_external_offer' and i.related_entity_id=u.id
        and i.decision_status in ('pending','resolved')
    );
  get diagnostics v_staff=row_count;

  if coalesce(c.fatigue,0)>=70
     and not exists(
       select 1 from public.inbox_items i
       where i.kind='medical' and i.title='Fatigue critique'
         and i.game_date=p_date
     ) then
    insert into public.inbox_items(
      kind,title,body,action_route,is_read,game_date,priority,
      action_type,action_label,action_payload,
      secondary_action_type,secondary_action_label,secondary_action_payload,
      decision_status,expires_at
    ) values(
      'medical','Fatigue critique',
      'La fatigue est à '||coalesce(c.fatigue,0)||'%. Le staff recommande de réduire immédiatement la charge.',
      'training',false,p_date,'urgent',
      'medical_protocol','Récupération active',jsonb_build_object('protocol','Récupération active'),
      'open_route','Modifier l’entraînement',jsonb_build_object('route','training'),
      'pending',p_date+7
    );
    v_fatigue:=1;
  end if;

  v_total:=v_sponsors+v_scouting+v_contracts+v_medical+v_partners+v_staff+v_fatigue;

  if v_total>0 and not exists(
    select 1 from public.career_event_log
    where event_date=p_date and week=p_week and system='career' and event_type='inbox_sync'
  ) then
    insert into public.career_event_log(event_date,week,system,event_type,summary,payload)
    values(
      p_date,p_week,'career','inbox_sync','Inbox Career OS synchronisée',
      jsonb_build_object(
        'sponsors',v_sponsors,'scouting',v_scouting,'contracts',v_contracts,
        'medical',v_medical,'partner_offers',v_partners,'staff_offers',v_staff,'fatigue',v_fatigue
      )
    );
  end if;

  return jsonb_build_object(
    'ok',true,'created',v_total,
    'sponsors',v_sponsors,'scouting',v_scouting,'contracts',v_contracts,
    'medical',v_medical,'partner_offers',v_partners,'staff_offers',v_staff,'fatigue',v_fatigue,
    'model','CB-CAREER-INBOX-v2'
  );
end;
$function$;