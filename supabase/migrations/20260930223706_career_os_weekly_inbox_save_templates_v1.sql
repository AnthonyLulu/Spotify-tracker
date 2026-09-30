-- Court Boss Career OS: automatic managed season plan, actionable inbox sync,
-- and internal pristine new-career template storage.

create table if not exists public.game_career_templates(
  id text primary key,
  managed_snapshot jsonb not null,
  local_payload jsonb not null default '{}'::jsonb,
  game_version text not null default '2026.10-career-os-v2',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.game_career_templates enable row level security;

comment on table public.game_career_templates is
  'Internal Court Boss pristine managed-career templates. Service-role only; no public RLS policy.';

CREATE OR REPLACE FUNCTION public.ensure_managed_season_plan(p_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  c public.career_state%rowtype;
  v_year int;
  v_rank int;
  v_plan text;
  v_target int;
  v_doubles int;
  v_reason text;
  r public.player_season_plans%rowtype;
begin
  select * into c from public.career_state where id='demo';
  if not found or c.managed_player_id is null then
    return jsonb_build_object('ok',false,'reason','managed_player_missing');
  end if;

  v_year:=extract(year from coalesce(p_date,c.career_date,current_date))::int;
  v_rank:=case
    when coalesce(c.career_focus,'mixed')='doubles_only' then coalesce(c.doubles_rank,999999)
    else coalesce(c.singles_rank,999999)
  end;

  v_plan:=case
    when coalesce(c.career_focus,'mixed')='doubles_only' then 'doubles_specialist'
    when coalesce(c.career_focus,'mixed')='singles_only' then 'singles_specialist'
    when v_rank<=100 then 'elite_selective'
    when v_rank<=300 then 'tour_regular'
    when v_rank<=900 then 'challenger_push'
    else 'itf_build'
  end;

  v_target:=case
    when v_plan='elite_selective' then 20
    when v_plan='tour_regular' then 23
    when v_plan='challenger_push' then 27
    when v_plan='itf_build' then 30
    when v_plan='doubles_specialist' then 25
    else 24
  end;

  v_doubles:=case
    when coalesce(c.career_focus,'mixed')='doubles_only' then 20
    when coalesce(c.career_focus,'mixed')='singles_only' then 1
    when coalesce(c.career_focus,'mixed')='singles_priority' then 6
    else 11
  end;

  v_reason:='Plan initial Career OS généré automatiquement selon le classement et l’orientation de carrière.';

  insert into public.player_season_plans(
    player_id,season,plan_type,target_events,preferred_surface,secondary_surface,
    rest_bias,travel_tolerance,prestige_bias,development_bias,doubles_bias,reason,
    updated_at,base_target_events,max_consecutive_weeks,rest_trigger_fatigue,
    schedule_risk_tolerance,mental_load_target,last_adapted_date
  )
  values(
    c.managed_player_id,v_year,v_plan,v_target,'Dur','Terre',
    10,10,case when v_rank<=300 then 15 else 10 end,
    case when v_rank>300 then 15 else 10 end,v_doubles,v_reason,
    now(),v_target,3,65,10,55,coalesce(p_date,c.career_date,current_date)
  )
  on conflict (player_id,season) do nothing;

  select * into r
  from public.player_season_plans
  where player_id=c.managed_player_id and season=v_year;

  return jsonb_build_object(
    'ok',true,'created',r.updated_at>=now()-interval '5 seconds',
    'player_id',c.managed_player_id,'season',v_year,'plan',to_jsonb(r)
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
  v_total int:=0;
begin
  select * into c from public.career_state where id='demo';

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
      'Blessure '||inj.severity||'. Retour estimé : '||to_char(inj.expected_return,'DD/MM/YYYY')||
        ' · risque d’aggravation '||coalesce(inj.aggravation_risk,0)::text||'%.',
      'medical',false,p_date,'urgent',
      'medical_protocol','Récupération active',jsonb_build_object('protocol','Récupération active'),
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
      and o.expires_at>=p_date
      and not exists(
        select 1 from public.inbox_items i
        where i.related_entity_type='doubles_partner_offer' and i.related_entity_id=o.id
          and i.decision_status in ('pending','resolved')
      );
    get diagnostics v_partners=row_count;
  end if;

  insert into public.inbox_items(
    kind,title,body,action_route,is_read,game_date,priority,
    action_type,action_label,action_payload,decision_status,
    related_entity_type,related_entity_id,expires_at
  )
  select
    'staff','Offre externe pour ton staff · '||coalesce(sp.name,'Staff'),
    coalesce(sp.name,'Un membre du staff')||' est sollicité par un autre joueur. Offre : '||
      round(u.offered_weekly)::text||' €/sem. · décision avant '||to_char(u.deadline,'DD/MM/YYYY')||'.',
    'staff',false,p_date,'high',
    'open_route','Voir le staff',jsonb_build_object('route','staff'),'pending',
    'staff_external_offer',u.id,u.deadline
  from public.user_staff_external_offers u
  left join public.staff_profiles sp on sp.id=u.staff_profile_id
  where u.status='pending' and u.deadline>=p_date
    and not exists(
      select 1 from public.inbox_items i
      where i.related_entity_type='staff_external_offer' and i.related_entity_id=u.id
        and i.decision_status in ('pending','resolved')
    );
  get diagnostics v_staff=row_count;

  v_total:=v_sponsors+v_scouting+v_contracts+v_medical+v_partners+v_staff;
  if v_total>0 then
    insert into public.career_event_log(event_date,week,system,event_type,summary,payload)
    values(
      p_date,p_week,'career','inbox_sync','Inbox Career OS synchronisée',
      jsonb_build_object(
        'sponsors',v_sponsors,'scouting',v_scouting,'contracts',v_contracts,
        'medical',v_medical,'partner_offers',v_partners,'staff_offers',v_staff
      )
    );
  end if;

  return jsonb_build_object(
    'ok',true,'created',v_total,'sponsors',v_sponsors,'scouting',v_scouting,'contracts',v_contracts,
    'medical',v_medical,'partner_offers',v_partners,'staff_offers',v_staff
  );
end;
$function$;
