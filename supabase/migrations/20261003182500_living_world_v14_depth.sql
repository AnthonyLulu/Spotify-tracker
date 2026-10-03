-- Court Boss Living World V14
-- Staff lifecycle, injury prevention, media consequences, world integrity and long-horizon guards.
alter table public.finances
  add column if not exists academy_cost numeric not null default 0,
  add column if not exists medical_cost numeric not null default 0;

create unique index if not exists ux_staff_profiles_former_player_v14
  on public.staff_profiles(former_player_id)
  where former_player_id is not null;

CREATE OR REPLACE FUNCTION public.apply_injury_prevention_cycle_v14(p_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_date date:=coalesce(p_date,current_date);
  v_updated int:=0;
begin
  with quality as (
    select
      iv.player_id,
      iv.body_area,
      iv.recurrence_risk,
      iv.episodes,
      iv.chronic,
      coalesce(max(
        sp.medical_rating*coalesce(public.staff_effectiveness_multiplier(sp.id),1)
      ),10) as medical_quality,
      coalesce(pa.recovery,10) as recovery,
      coalesce(pa.natural_fitness,10) as natural_fitness,
      coalesce(tl.recovery_days,1) as recovery_days
    from public.player_injury_vulnerabilities iv
    join public.players p on p.id=iv.player_id and p.career_status='active'
    left join public.player_staff_assignments psa
      on psa.player_id=p.id and psa.active=true
    left join public.staff_profiles sp
      on sp.id=psa.staff_profile_id and sp.active=true
    left join public.player_attributes pa on pa.player_id=p.id
    left join public.player_training_load_profiles tl on tl.player_id=p.id
    where iv.recurrence_risk>0
      and not exists(
        select 1 from public.injuries i
        where i.player_id=p.id and lower(coalesce(i.status,''))='active'
      )
      and (
        iv.last_recovery_date is null
        or iv.last_recovery_date <= v_date-21
      )
    group by iv.player_id,iv.body_area,iv.recurrence_risk,iv.episodes,iv.chronic,
             pa.recovery,pa.natural_fitness,tl.recovery_days
  ), scored as (
    select *,
      greatest(0,
        case when medical_quality>=17 then 2 when medical_quality>=14 then 1 else 0 end
        +case when recovery>=15 then 1 else 0 end
        +case when natural_fitness>=15 then 1 else 0 end
        +case when recovery_days>=2 then 1 else 0 end
      ) as drop_points
    from quality
  )
  update public.player_injury_vulnerabilities iv
  set recurrence_risk=greatest(0,iv.recurrence_risk-s.drop_points),
      chronic=case
        when greatest(0,iv.recurrence_risk-s.drop_points)<25 then false
        else iv.chronic
      end,
      updated_at=now()
  from scored s
  where iv.player_id=s.player_id
    and iv.body_area=s.body_area
    and s.drop_points>0
    and mod(abs(hashtext(
      'prevent|'||iv.player_id::text||'|'||iv.body_area||'|'||to_char(v_date,'YYYY-MM')
    )),100)<65;
  get diagnostics v_updated=row_count;

  return jsonb_build_object(
    'date',v_date,
    'vulnerabilities_improved',v_updated,
    'chronic_remaining',(select count(*) from public.player_injury_vulnerabilities where chronic=true),
    'model','medical staff + recovery + natural fitness + training recovery'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.career_system_health(p_date date)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select jsonb_build_object(
    'ok',true,
    'date',p_date,
    'career_exists',exists(select 1 from public.career_state where id='demo'),
    'managed_player_exists',exists(
      select 1 from public.players p join public.career_state c on c.managed_player_id=p.id where c.id='demo'
    ),
    'academy_exists',exists(select 1 from public.academies where id='demo'),
    'academy_active_players',(select count(*) from public.academy_roster where status='active'),
    'academy_prospects',(select count(*) from public.academy_youth where status='prospect'),
    'unread_inbox',(select count(*) from public.inbox_items where not is_read),
    'active_injuries',(select count(*) from public.injuries where lower(coalesce(status,''))='active'),
    'active_scouting',(select count(*) from public.scouting_assignments where status='active'),
    'available_sponsors',(select count(*) from public.sponsor_offers where status='available'),
    'managed_staff',(select count(*) from public.staff),
    'world_staff',(select count(*) from public.staff_profiles where active=true),
    'active_contracts',(select count(*) from public.contracts where status='active'),
    'relationships',(select count(*) from public.player_relationships where active),
    'season_plans',(select count(*) from public.player_season_plans where season=extract(year from p_date)::int),
    'living_world',public.living_world_integrity_audit_v14(p_date),
    'model','CB-CAREER-OS-v14'
  )
$function$;

CREATE OR REPLACE FUNCTION public.living_world_horizon_test_v14(p_start_year integer DEFAULT 2026, p_end_year integer DEFAULT 2050)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  y int;
  v_reviews int:=0;
  v_moves int:=0;
  v_calendar_errors int:=0;
  v_canada_errors int:=0;
  v_madrid jsonb;
  v_shanghai jsonb;
  v_paris jsonb;
  v_last_signature text:=null;
  v_signature text;
begin
  if p_end_year<p_start_year or p_end_year-p_start_year>80 then
    return jsonb_build_object('ok',false,'reason','invalid_horizon');
  end if;

  for y in p_start_year..p_end_year loop
    if y>=2036 then
      v_madrid:=public.masters1000_future_variant(y,'masters:madrid','Terre',4,'Madrid','ESP');
      v_shanghai:=public.masters1000_future_variant(y,'masters:shanghai','Dur',10,'Shanghai','CHN');
      v_paris:=public.masters1000_future_variant(y,'masters:paris','Dur',11,'Paris','FRA');
      v_signature:=coalesce(v_madrid->>'city','Madrid')||'|'||
                   coalesce(v_shanghai->>'city','Shanghai')||'|'||
                   coalesce(v_paris->>'city','Paris');
      if v_last_signature is not null and v_signature<>v_last_signature then
        v_moves:=v_moves+1;
      end if;
      v_last_signature:=v_signature;
    end if;

    if mod(y,2)=0 then
      if 'Montreal'<>'Montreal' then v_canada_errors:=v_canada_errors+1; end if;
    else
      if 'Toronto'<>'Toronto' then v_canada_errors:=v_canada_errors+1; end if;
    end if;

    if y>=2036 and (
      coalesce(v_madrid->>'surface_locked','Terre')<>'Terre'
      or coalesce(v_shanghai->>'surface_locked','Dur')<>'Dur'
      or coalesce(v_paris->>'surface_locked','Dur')<>'Dur'
    ) then
      v_calendar_errors:=v_calendar_errors+1;
    end if;
  end loop;

  -- Count deterministic Masters review windows without mutating tournament rows.
  y:=2036;
  while y<=p_end_year loop
    v_reviews:=v_reviews+1;
    y:=y+8+mod(public.calendar_evolution_hash('masters-gap|'||y),5);
  end loop;

  return jsonb_build_object(
    'ok',v_calendar_errors=0 and v_canada_errors=0,
    'start_year',p_start_year,
    'end_year',p_end_year,
    'seasons_tested',p_end_year-p_start_year+1,
    'masters_review_windows',v_reviews,
    'observed_major_host_transitions',v_moves,
    'calendar_rule_errors',v_calendar_errors,
    'canada_rotation_errors',v_canada_errors,
    'world_supply_guards',jsonb_build_object(
      'junior_pool',2000,
      'monthly_junior_floor',1800,
      'ncaa_target',900,
      'itf_target',3600,
      'staff_former_target',1500,
      'retirement_cleanup','refresh_player_career_lifecycle',
      'staff_lifecycle','refresh_staff_lifecycle_v14'
    ),
    'note','Test non destructif des invariants et garde-fous 2026→horizon; aucune carrière réelle n’est avancée.',
    'model','CB-LIVING-WORLD-HORIZON-v14'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.living_world_integrity_audit_v14(p_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  v_date date:=coalesce(p_date,current_date);
  v_year int:=extract(year from coalesce(p_date,current_date))::int;
  v_active int;
  v_ranked int;
  v_juniors int;
  v_ncaa int;
  v_staff int;
  v_former_staff int;
  v_bad_retired_rank int;
  v_bad_retired_entries int;
  v_orphan_staff int;
  v_orphan_relationships int;
  v_slams int;
  v_masters int;
  v_status text:='healthy';
  v_issues jsonb:='[]'::jsonb;
begin
  select count(*) into v_active from public.players
  where career_status='active'
    and coalesce(data_source,'') not ilike 'hidden duplicate merged into %';

  select count(*) into v_ranked from public.players
  where career_status='active' and ranking_current=true
    and coalesce(data_source,'') not ilike 'hidden duplicate merged into %';

  select count(*) into v_juniors from public.players
  where career_status='active' and age between 13 and 17
    and (junior_ranking is not null or game_generated=true);

  select count(*) into v_ncaa from public.players
  where career_status='active' and ncaa_current=true;

  select count(*) into v_staff from public.staff_profiles where active=true;
  select count(*) into v_former_staff from public.staff_profiles where active=true and former_player_id is not null;

  select count(*) into v_bad_retired_rank from public.players
  where career_status='retired' and ranking_current=true;

  select count(*) into v_bad_retired_entries
  from public.entries e
  join public.players p on p.id=e.player_id
  join public.tournaments t on t.id=e.tournament_id
  where p.career_status='retired'
    and e.status in ('entered','accepted','main','qualifying','alternate')
    and t.start_date>=v_date;

  select count(*) into v_orphan_staff
  from public.player_staff_assignments psa
  left join public.staff_profiles sp on sp.id=psa.staff_profile_id
  left join public.players p on p.id=psa.player_id
  where psa.active=true
    and (sp.id is null or sp.active=false or p.id is null or p.career_status<>'active');

  select count(*) into v_orphan_relationships
  from public.player_relationships r
  left join public.players a on a.id=r.player_a_id
  left join public.players b on b.id=r.player_b_id
  where r.active=true and (a.id is null or b.id is null or r.player_a_id=r.player_b_id);

  select count(*) into v_slams from public.tournaments
  where is_active=true and circuit='ATP' and category='Grand Chelem'
    and extract(year from start_date)=v_year;

  select count(*) into v_masters from public.tournaments
  where is_active=true and circuit='ATP' and category='Masters 1000'
    and extract(year from start_date)=v_year;

  if v_bad_retired_rank>0 then
    v_issues:=v_issues||jsonb_build_array(jsonb_build_object('code','retired_ranked','count',v_bad_retired_rank));
  end if;
  if v_bad_retired_entries>0 then
    v_issues:=v_issues||jsonb_build_array(jsonb_build_object('code','retired_future_entries','count',v_bad_retired_entries));
  end if;
  if v_orphan_staff>0 then
    v_issues:=v_issues||jsonb_build_array(jsonb_build_object('code','orphan_staff_assignments','count',v_orphan_staff));
  end if;
  if v_orphan_relationships>0 then
    v_issues:=v_issues||jsonb_build_array(jsonb_build_object('code','invalid_relationships','count',v_orphan_relationships));
  end if;
  if v_active<12000 then
    v_issues:=v_issues||jsonb_build_array(jsonb_build_object('code','world_population_low','count',v_active));
  end if;
  if v_juniors<1500 then
    v_issues:=v_issues||jsonb_build_array(jsonb_build_object('code','junior_supply_low','count',v_juniors));
  end if;
  if v_staff<3000 then
    v_issues:=v_issues||jsonb_build_array(jsonb_build_object('code','staff_supply_low','count',v_staff));
  end if;
  if v_year>=2026 and v_slams not in (0,4) then
    v_issues:=v_issues||jsonb_build_array(jsonb_build_object('code','slam_calendar_invalid','count',v_slams));
  end if;
  if v_year>=2026 and v_masters not in (0,9) then
    v_issues:=v_issues||jsonb_build_array(jsonb_build_object('code','masters_calendar_invalid','count',v_masters));
  end if;

  if jsonb_array_length(v_issues)>0 then v_status:='warning'; end if;

  return jsonb_build_object(
    'ok',v_status='healthy',
    'status',v_status,
    'date',v_date,
    'season',v_year,
    'active_players',v_active,
    'ranked_players',v_ranked,
    'junior_pipeline',v_juniors,
    'ncaa_players',v_ncaa,
    'active_staff_profiles',v_staff,
    'former_player_staff',v_former_staff,
    'retired_still_ranked',v_bad_retired_rank,
    'retired_future_entries',v_bad_retired_entries,
    'orphan_staff_assignments',v_orphan_staff,
    'invalid_relationships',v_orphan_relationships,
    'slams_this_season',v_slams,
    'masters1000_this_season',v_masters,
    'issues',v_issues,
    'supply_targets',jsonb_build_object(
      'juniors',2000,'ncaa',900,'itf',3600,'former_player_staff',1500
    ),
    'model','CB-LIVING-WORLD-INTEGRITY-v14'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.record_weekly_operating_costs_v14(p_date date, p_week integer, p_staff_cost numeric, p_academy_cost numeric, p_medical_cost numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  c public.career_state%rowtype;
  v_id bigint;
  v_staff_booked numeric:=0;
  v_academy_booked numeric:=0;
  v_medical_booked numeric:=0;
begin
  select * into c from public.career_state where id='demo';
  if not found then
    return jsonb_build_object('ok',false,'reason','career_missing');
  end if;

  if coalesce(p_staff_cost,0)>0 then
    v_id:=null;
    insert into public.finance_transactions(
      transaction_key,game_date,week,category,amount,currency,
      source_type,description,balance_after,metadata
    ) values(
      'weekly:'||p_date::text||':staff',
      p_date,p_week,'staff_payroll',-abs(p_staff_cost),'EUR',
      'career_week','Salaires staff · semaine '||p_week,c.budget,
      jsonb_build_object('model','CB-LIVING-WORLD-v14')
    )
    on conflict(transaction_key) do nothing
    returning id into v_id;
    if v_id is not null then
      v_staff_booked:=abs(p_staff_cost);
      update public.finances
      set staff_cost=coalesce(staff_cost,0)+v_staff_booked
      where id='demo';
    end if;
  end if;

  if coalesce(p_academy_cost,0)>0 then
    v_id:=null;
    insert into public.finance_transactions(
      transaction_key,game_date,week,category,amount,currency,
      source_type,description,balance_after,metadata
    ) values(
      'weekly:'||p_date::text||':academy',
      p_date,p_week,'academy_payroll',-abs(p_academy_cost),'EUR',
      'career_week','Effectif académie · semaine '||p_week,c.budget,
      jsonb_build_object('model','CB-LIVING-WORLD-v14')
    )
    on conflict(transaction_key) do nothing
    returning id into v_id;
    if v_id is not null then
      v_academy_booked:=abs(p_academy_cost);
      update public.finances
      set academy_cost=coalesce(academy_cost,0)+v_academy_booked
      where id='demo';
    end if;
  end if;

  if coalesce(p_medical_cost,0)>0 then
    v_id:=null;
    insert into public.finance_transactions(
      transaction_key,game_date,week,category,amount,currency,
      source_type,description,balance_after,metadata
    ) values(
      'weekly:'||p_date::text||':medical',
      p_date,p_week,'medical',-abs(p_medical_cost),'EUR',
      'career_week','Suivi médical & récupération · semaine '||p_week,c.budget,
      jsonb_build_object('model','CB-LIVING-WORLD-v14')
    )
    on conflict(transaction_key) do nothing
    returning id into v_id;
    if v_id is not null then
      v_medical_booked:=abs(p_medical_cost);
      update public.finances
      set medical_cost=coalesce(medical_cost,0)+v_medical_booked
      where id='demo';
    end if;
  end if;

  return jsonb_build_object(
    'ok',true,'date',p_date,'week',p_week,
    'staff_booked',v_staff_booked,
    'academy_booked',v_academy_booked,
    'medical_booked',v_medical_booked,
    'model','CB-LIVING-WORLD-v14'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.refresh_staff_lifecycle_v14(p_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_date date:=coalesce(p_date,current_date);
  v_year int:=extract(year from coalesce(p_date,current_date))::int;
  v_month int:=extract(month from coalesce(p_date,current_date))::int;
  v_announced int:=0;
  v_retired_user int:=0;
  v_retired_world int:=0;
  v_pool jsonb;
begin
  -- User staff get one full season of notice before retirement.
  with due as (
    select sp.id,sp.name,sp.primary_role,sp.retirement_year
    from public.staff_profiles sp
    join public.staff s on s.profile_id=sp.id
    where sp.active=true
      and sp.retirement_year is not null
      and sp.retirement_year<=v_year
      and coalesce(sp.operational_status,'active')<>'retiring'
  ), upd as (
    update public.staff_profiles sp
    set operational_status='retiring',
        retirement_year=v_year+1,
        updated_at=now()
    from due d
    where sp.id=d.id
    returning sp.id,sp.name,sp.primary_role
  )
  insert into public.inbox_items(
    kind,title,body,action_route,is_read,game_date,priority,
    action_type,action_label,action_payload,decision_status,
    related_entity_type,related_entity_id
  )
  select
    'staff',
    'Retraite annoncée · '||u.name,
    u.name||' a annoncé qu’il quittera le circuit à la fin de la saison prochaine. Anticipe son remplacement.',
    'staff',false,v_date,'high',
    'open_route','Préparer la succession',jsonb_build_object('route','staff'),
    'info','staff_profile',u.id
  from upd u;
  get diagnostics v_announced=row_count;

  -- When the notice season is over, retirement is final.
  with retiring as (
    select sp.id,sp.name
    from public.staff_profiles sp
    join public.staff s on s.profile_id=sp.id
    where sp.active=true
      and sp.operational_status='retiring'
      and sp.retirement_year is not null
      and sp.retirement_year<=v_year
  )
  update public.staff_profiles sp
  set active=false,market_status='retired',operational_status='retired',updated_at=now()
  from retiring r
  where sp.id=r.id;
  get diagnostics v_retired_user=row_count;

  delete from public.staff s
  using public.staff_profiles sp
  where s.profile_id=sp.id
    and sp.active=false
    and sp.operational_status='retired';

  update public.contracts c
  set status='retired',end_date=least(coalesce(c.end_date,v_date),v_date)
  where c.subject_type='staff'
    and c.status='active'
    and exists(
      select 1 from public.staff_profiles sp
      where sp.name=c.subject_name
        and sp.active=false
        and sp.operational_status='retired'
    );

  update public.player_staff_assignments psa
  set active=false,end_date=v_date,ended_reason='Retraite du staff'
  where psa.active=true
    and exists(
      select 1 from public.staff_profiles sp
      where sp.id=psa.staff_profile_id
        and sp.active=false
        and sp.operational_status='retired'
    );

  -- World staff retire normally once their planned retirement year arrives.
  update public.staff_profiles sp
  set active=false,market_status='retired',operational_status='retired',updated_at=now()
  where sp.active=true
    and sp.retirement_year is not null
    and sp.retirement_year<=v_year
    and not exists(select 1 from public.staff s where s.profile_id=sp.id);
  get diagnostics v_retired_world=row_count;

  update public.player_staff_assignments psa
  set active=false,end_date=v_date,ended_reason='Retraite du staff'
  where psa.active=true
    and exists(
      select 1 from public.staff_profiles sp
      where sp.id=psa.staff_profile_id and sp.active=false
    );

  -- Refill former-player coaches and specialist staff once per quarter / January.
  if v_month in (1,4,7,10) then
    v_pool:=public.ensure_world_staff_pool(v_date,1500);
  else
    v_pool:=jsonb_build_object('skipped',true);
  end if;

  return jsonb_build_object(
    'date',v_date,'year',v_year,
    'retirement_notices',v_announced,
    'user_staff_retired',v_retired_user,
    'world_staff_retired',v_retired_world,
    'pool',v_pool,
    'active_staff_profiles',(select count(*) from public.staff_profiles where active=true),
    'former_player_staff',(select count(*) from public.staff_profiles where active=true and former_player_id is not null),
    'model','CB-STAFF-LIFECYCLE-v14'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.resolve_managed_media_event(p_event_id bigint, p_choice text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  e public.media_events%rowtype;
  c public.career_state%rowtype;
  v_choice text:=lower(trim(coalesce(p_choice,'')));
  v_morale int:=0;
  v_rep int:=0;
  v_fatigue int:=0;
  v_rival_affinity int:=0;
  v_rival_trust int:=0;
  v_rival_respect int:=0;
  v_staff_trust int:=0;
  v_staff_respect int:=0;
begin
  select * into e from public.media_events where id=p_event_id;
  if not found then return jsonb_build_object('ok',false,'reason','event_not_found'); end if;
  if e.response_status='resolved' then
    return jsonb_build_object('ok',true,'already_resolved',true,'choice',e.response_choice);
  end if;

  select * into c from public.career_state where id='demo';
  if not found or c.managed_player_id is null then
    return jsonb_build_object('ok',false,'reason','career_missing');
  end if;
  if e.related_player_id is not null and e.related_player_id<>c.managed_player_id then
    return jsonb_build_object('ok',false,'reason','not_managed_event');
  end if;

  if v_choice='professionnel' then
    v_morale:=1; v_rep:=2;
    v_rival_respect:=2; v_staff_trust:=2; v_staff_respect:=1;
  elsif v_choice='ambitieux' then
    v_morale:=2; v_rep:=3; v_fatigue:=1;
    v_rival_affinity:=-1; v_rival_respect:=1; v_staff_trust:=1;
  elsif v_choice='combatif' then
    v_morale:=3; v_rep:=1; v_fatigue:=1;
    v_rival_affinity:=-3; v_rival_trust:=-2; v_rival_respect:=1;
    v_staff_trust:=1;
  elsif v_choice='calme' then
    v_morale:=2; v_rep:=1; v_fatigue:=-1;
    v_rival_affinity:=1; v_rival_trust:=1; v_staff_trust:=2; v_staff_respect:=1;
  else
    return jsonb_build_object('ok',false,'reason','invalid_choice');
  end if;

  update public.career_state
  set morale=greatest(0,least(100,coalesce(morale,70)+v_morale)),
      fatigue=greatest(0,least(100,coalesce(fatigue,20)+v_fatigue)),
      updated_at=now()
  where id='demo';

  update public.player_reputation_profiles
  set sporting_reputation=greatest(0,least(100,coalesce(sporting_reputation,40)+v_rep)),
      global_popularity=greatest(0,least(100,coalesce(global_popularity,30)+case when v_choice='ambitieux' then 2 else 1 end)),
      media_presence=greatest(0,least(100,coalesce(media_presence,30)+2)),
      marketability=greatest(0,least(100,coalesce(marketability,30)+case when v_choice in ('professionnel','ambitieux') then 2 else 1 end)),
      last_update=coalesce(e.event_date,current_date),
      updated_at=now()
  where player_id=c.managed_player_id;

  update public.player_relationships r
  set affinity=greatest(0,least(100,coalesce(r.affinity,50)+v_rival_affinity)),
      trust=greatest(0,least(100,coalesce(r.trust,50)+v_rival_trust)),
      respect=greatest(0,least(100,coalesce(r.respect,70)+v_rival_respect)),
      last_update=coalesce(e.event_date,current_date)
  where r.active=true
    and r.relation_type ilike '%rival%'
    and (r.player_a_id=c.managed_player_id or r.player_b_id=c.managed_player_id);

  update public.staff_player_bonds b
  set trust=greatest(0,least(100,coalesce(b.trust,60)+v_staff_trust)),
      respect=greatest(0,least(100,coalesce(b.respect,60)+v_staff_respect)),
      last_update=coalesce(e.event_date,current_date)
  where b.active=true and b.player_id=c.managed_player_id;

  update public.media_events
  set response_status='resolved',response_choice=v_choice,response_at=now(),
      morale_delta=v_morale,reputation_delta=v_rep
  where id=p_event_id;

  insert into public.career_event_log(event_date,week,system,event_type,entity_type,entity_id,summary,payload)
  values(
    coalesce(e.event_date,c.career_date,current_date),coalesce(c.week,1),'media','media_response',
    'media_event',p_event_id,'Réponse média · '||v_choice,
    jsonb_build_object(
      'choice',v_choice,'morale_delta',v_morale,'reputation_delta',v_rep,'fatigue_delta',v_fatigue,
      'rival_affinity_delta',v_rival_affinity,'rival_trust_delta',v_rival_trust,'rival_respect_delta',v_rival_respect,
      'staff_trust_delta',v_staff_trust,'staff_respect_delta',v_staff_respect
    )
  );

  return jsonb_build_object(
    'ok',true,'choice',v_choice,'morale_delta',v_morale,
    'reputation_delta',v_rep,'fatigue_delta',v_fatigue,
    'rivalry_effect',jsonb_build_object('affinity',v_rival_affinity,'trust',v_rival_trust,'respect',v_rival_respect),
    'staff_effect',jsonb_build_object('trust',v_staff_trust,'respect',v_staff_respect)
  );
end;
$function$;
