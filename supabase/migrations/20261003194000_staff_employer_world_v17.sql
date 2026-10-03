-- Court Boss Staff Employer World V17
-- FM-style employer history, AI job market, reputation breakouts, bonded reunions and progressive former-player careers.

create table if not exists public.staff_employer_history_v17(
  id bigserial primary key,
  staff_profile_id bigint not null references public.staff_profiles(id) on delete cascade,
  assignment_id bigint references public.player_staff_assignments(id) on delete set null,
  player_id bigint references public.players(id) on delete set null,
  employer_label text,
  country text,
  role text,
  started_on date not null,
  ended_on date,
  weekly_salary numeric,
  entry_reason text,
  exit_reason text,
  source_label text not null default 'Court Boss · staff employer history v17',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists ux_staff_employer_history_v17_assignment
  on public.staff_employer_history_v17(assignment_id) where assignment_id is not null;
create index if not exists idx_staff_employer_history_v17_staff
  on public.staff_employer_history_v17(staff_profile_id,started_on desc);

create table if not exists public.staff_reputation_snapshots_v17(
  staff_profile_id bigint not null references public.staff_profiles(id) on delete cascade,
  snapshot_month date not null,
  reputation integer not null,
  best_client_rank integer,
  title_points integer not null default 0,
  active_clients integer not null default 0,
  market_status text,
  asking_weekly_cost numeric,
  created_at timestamptz not null default now(),
  primary key(staff_profile_id,snapshot_month)
);

create table if not exists public.staff_job_offers_v17(
  id bigserial primary key,
  staff_profile_id bigint not null references public.staff_profiles(id) on delete cascade,
  from_player_id bigint references public.players(id) on delete set null,
  to_player_id bigint not null references public.players(id) on delete cascade,
  offered_role text not null,
  weekly_salary numeric not null,
  signing_bonus numeric not null default 0,
  offer_date date not null,
  deadline date not null,
  status text not null default 'pending',
  decision_score numeric,
  decision_reason text,
  resolved_at date,
  source_label text not null default 'Court Boss · AI employer market v17',
  created_at timestamptz not null default now()
);
create unique index if not exists ux_staff_job_offers_v17_pending
  on public.staff_job_offers_v17(staff_profile_id) where status='pending';
create index if not exists idx_staff_job_offers_v17_deadline
  on public.staff_job_offers_v17(status,deadline);

alter table public.staff_employer_history_v17 enable row level security;
alter table public.staff_reputation_snapshots_v17 enable row level security;
alter table public.staff_job_offers_v17 enable row level security;
revoke all on table public.staff_employer_history_v17 from anon,authenticated;
revoke all on table public.staff_reputation_snapshots_v17 from anon,authenticated;
revoke all on table public.staff_job_offers_v17 from anon,authenticated;
grant select,insert,update,delete on table public.staff_employer_history_v17 to service_role;
grant select,insert,update,delete on table public.staff_reputation_snapshots_v17 to service_role;
grant select,insert,update,delete on table public.staff_job_offers_v17 to service_role;

CREATE OR REPLACE FUNCTION public.sync_staff_employer_history_v17(p_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_date date:=coalesce(p_date,current_date);
  v_inserted int:=0;
  v_closed int:=0;
begin
  insert into public.staff_employer_history_v17(
    staff_profile_id,assignment_id,player_id,employer_label,country,role,
    started_on,ended_on,weekly_salary,entry_reason,exit_reason
  )
  select
    psa.staff_profile_id,psa.id,psa.player_id,p.name,p.country,psa.role,
    coalesce(psa.start_date,psa.snapshot_date,v_date),
    psa.end_date,psa.weekly_salary,
    coalesce(psa.source_label,psa.notes,'Affectation staff'),
    psa.ended_reason
  from public.player_staff_assignments psa
  join public.players p on p.id=psa.player_id
  where not exists(
    select 1 from public.staff_employer_history_v17 h where h.assignment_id=psa.id
  )
  on conflict do nothing;
  get diagnostics v_inserted=row_count;

  update public.staff_employer_history_v17 h
  set ended_on=psa.end_date,
      exit_reason=coalesce(psa.ended_reason,h.exit_reason),
      weekly_salary=coalesce(psa.weekly_salary,h.weekly_salary),
      updated_at=now()
  from public.player_staff_assignments psa
  where h.assignment_id=psa.id
    and (
      h.ended_on is distinct from psa.end_date
      or h.exit_reason is distinct from psa.ended_reason
      or h.weekly_salary is distinct from psa.weekly_salary
    );
  get diagnostics v_closed=row_count;

  return jsonb_build_object(
    'date',v_date,
    'inserted',v_inserted,
    'updated',v_closed,
    'history_rows',(select count(*) from public.staff_employer_history_v17),
    'model','CB-STAFF-EMPLOYER-HISTORY-v17'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.refresh_staff_reputation_dynamics_v17(p_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_date date:=coalesce(p_date,current_date);
  v_month date:=date_trunc('month',coalesce(p_date,current_date))::date;
  r record;
  prev record;
  v_delta int;
  v_old int;
  v_new int;
  v_updated int:=0;
  v_breakouts int:=0;
  v_fades int:=0;
begin
  if v_date<=date '2025-12-01' or extract(month from v_date)::int not in (1,4,7,10) then
    return jsonb_build_object('date',v_date,'updated',0,'quarterly',false,'model','CB-STAFF-REPUTATION-v17');
  end if;

  for r in
    select
      sp.id,sp.name,sp.reputation,sp.asking_weekly_cost,sp.market_status,
      coalesce(scs.best_client_rank,999999) as best_client_rank,
      coalesce(scs.title_points,0) as title_points,
      coalesce(scs.active_clients,0) as active_clients,
      scs.last_title_date,
      exists(select 1 from public.staff s where s.profile_id=sp.id) as user_staff
    from public.staff_profiles sp
    left join public.staff_career_stats scs on scs.staff_profile_id=sp.id
    where sp.active=true
      and (
        coalesce(scs.active_clients,0)>0
        or exists(select 1 from public.staff s where s.profile_id=sp.id)
        or exists(
          select 1 from public.staff_reputation_snapshots_v17 h
          where h.staff_profile_id=sp.id and h.snapshot_month<v_month
        )
      )
    order by sp.id
  loop
    select *
    into prev
    from public.staff_reputation_snapshots_v17 h
    where h.staff_profile_id=r.id
      and h.snapshot_month<v_month
    order by h.snapshot_month desc
    limit 1;

    v_delta:=0;
    if prev.staff_profile_id is not null then
      if (
        (coalesce(prev.best_client_rank,999999)>50 and r.best_client_rank<=10)
        or (coalesce(prev.best_client_rank,999999)>100 and r.best_client_rank<=5)
        or (r.title_points-coalesce(prev.title_points,0))>=150
      ) then
        v_delta:=2;
      elsif (
        (coalesce(prev.best_client_rank,999999)>150 and r.best_client_rank<=50)
        or (coalesce(prev.best_client_rank,999999)-r.best_client_rank)>=250
        or (r.title_points-coalesce(prev.title_points,0))>=70
      ) then
        v_delta:=1;
      elsif r.active_clients=0
        and r.reputation>=13
        and coalesce(r.last_title_date,date '1900-01-01')<v_date-365
        and mod(abs(hashtext('staff-fade|'||r.id::text||'|'||to_char(v_month,'YYYY-MM'))),100)<18
      then
        v_delta:=-1;
      end if;
    end if;

    v_old:=r.reputation;
    v_new:=greatest(1,least(20,v_old+v_delta));

    if v_new<>v_old then
      update public.staff_profiles
      set reputation=v_new,
          asking_weekly_cost=greatest(
            150,
            round(coalesce(asking_weekly_cost,500)*
              case
                when v_delta>=2 then 1.12
                when v_delta=1 then 1.05
                else .96
              end
            )
          ),
          updated_at=now()
      where id=r.id;

      insert into public.staff_career_events(
        staff_profile_id,event_date,event_type,description,reputation_before,reputation_after
      )
      values(
        r.id,v_date,
        case when v_delta>=2 then 'reputation_breakthrough'
             when v_delta=1 then 'reputation_rise'
             else 'reputation_fade' end,
        case
          when v_delta>=2 then
            'Explosion de réputation après une forte progression des joueurs accompagnés ou un résultat majeur.'
          when v_delta=1 then
            'Réputation en hausse grâce aux résultats et à la progression des joueurs accompagnés.'
          else
            'Réputation en léger recul après une période prolongée sans résultat marquant.'
        end,
        v_old,v_new
      );
      v_updated:=v_updated+1;
      if v_delta>=2 then v_breakouts:=v_breakouts+1; end if;
      if v_delta<0 then v_fades:=v_fades+1; end if;
    end if;

    insert into public.staff_reputation_snapshots_v17(
      staff_profile_id,snapshot_month,reputation,best_client_rank,title_points,
      active_clients,market_status,asking_weekly_cost
    )
    select
      sp.id,v_month,sp.reputation,r.best_client_rank,r.title_points,
      r.active_clients,sp.market_status,sp.asking_weekly_cost
    from public.staff_profiles sp
    where sp.id=r.id
    on conflict(staff_profile_id,snapshot_month) do update set
      reputation=excluded.reputation,
      best_client_rank=excluded.best_client_rank,
      title_points=excluded.title_points,
      active_clients=excluded.active_clients,
      market_status=excluded.market_status,
      asking_weekly_cost=excluded.asking_weekly_cost;
  end loop;

  return jsonb_build_object(
    'date',v_date,
    'updated',v_updated,
    'breakouts',v_breakouts,
    'fades',v_fades,
    'snapshots_this_quarter',(
      select count(*) from public.staff_reputation_snapshots_v17 where snapshot_month=v_month
    ),
    'model','CB-STAFF-REPUTATION-v17'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.refresh_staff_bonded_reunions_v17(p_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_date date:=coalesce(p_date,current_date);
  v_managed bigint;
  r record;
  v_existing int;
  v_desired int;
  v_load int;
  v_joined int:=0;
  v_international int:=0;
  v_role_group text;
begin
  if v_date<=date '2025-12-01' then
    return jsonb_build_object('date',v_date,'reunions',0,'historical_cutoff',true);
  end if;

  select managed_player_id into v_managed from public.career_state where id='demo';

  for r in
    select
      b.staff_profile_id,b.player_id,b.bond_type,b.affinity,b.trust,b.respect,
      sp.name,sp.primary_role,sp.nationality,sp.asking_weekly_cost,sp.max_clients,
      sp.market_status,sp.regions,
      p.name as player_name,p.country as player_country,
      coalesce(p.game_world_rank,p.ranking,999999)::int as player_rank,
      public.staff_fit_score(p.id,sp.id,sp.primary_role)::int as fit
    from public.staff_player_bonds b
    join public.staff_profiles sp on sp.id=b.staff_profile_id
    join public.players p on p.id=b.player_id
    where b.active=true
      and b.bond_type in ('Joueur favori','Ancien joueur apprécié')
      and b.affinity>=84 and b.trust>=80 and b.respect>=75
      and sp.active=true
      and sp.market_status='available'
      and coalesce(sp.available_from,date '1900-01-01')<=v_date
      and p.career_status='active'
      and p.id<>coalesce(v_managed,-1)
      and not exists(select 1 from public.staff s where s.profile_id=sp.id)
      and not exists(
        select 1 from public.player_staff_assignments psa
        where psa.staff_profile_id=sp.id and psa.player_id=p.id and psa.active=true
      )
      and public.staff_role_group(sp.primary_role) in ('coach','fitness','medical','analysis','mental')
    order by
      case b.bond_type when 'Joueur favori' then 0 else 1 end,
      (b.affinity+b.trust+b.respect) desc,
      rtrim(sp.name),
      sp.id
    limit 120
  loop
    exit when v_joined>=16;
    v_role_group:=public.staff_role_group(r.primary_role);

    select count(*) into v_load
    from public.player_staff_assignments
    where staff_profile_id=r.staff_profile_id and active=true;
    if v_load>=coalesce(r.max_clients,1) then continue; end if;

    select count(*) into v_existing
    from public.player_staff_assignments psa
    join public.staff_profiles sx on sx.id=psa.staff_profile_id
    where psa.player_id=r.player_id
      and psa.active=true
      and public.staff_role_group(sx.primary_role)=v_role_group;

    v_desired:=case v_role_group
      when 'coach' then case when r.player_rank<=50 then 2 else 1 end
      when 'fitness' then 1
      when 'medical' then case when r.player_rank<=1500 then 1 else 0 end
      when 'analysis' then case when r.player_rank<=500 then 1 else 0 end
      when 'mental' then case when r.player_rank<=200 then 1 else 0 end
      else 0
    end;

    if v_existing>=v_desired or v_desired=0 then continue; end if;

    insert into public.player_staff_assignments(
      player_id,staff_profile_id,role,start_date,end_date,active,verified,
      affinity,trust,source_label,snapshot_date,notes,weekly_salary,
      contract_end,assignment_generation,last_review_date,role_fit,satisfaction,team_chemistry
    )
    values(
      r.player_id,r.staff_profile_id,r.primary_role,v_date,null,true,false,
      greatest(82,r.affinity),greatest(80,r.trust),
      'Court Boss · retrouvailles staff-joueur v17',v_date,
      'Le lien construit lors d’une ancienne collaboration a favorisé les retrouvailles.',
      round(coalesce(r.asking_weekly_cost,500)*1.05),
      v_date+(52+mod(abs(hashtext('reunion|'||r.staff_profile_id::text||'|'||r.player_id::text)),79))*7,
      1,v_date,r.fit,
      greatest(80,round((r.affinity+r.trust)/2.0)::int),
      greatest(78,round((r.affinity+r.trust+r.respect)/3.0)::int)
    )
    on conflict do nothing;

    if found then
      update public.staff_profiles
      set market_status=case when v_load+1>=coalesce(max_clients,1) then 'contracted' else 'available' end,
          available_from=case when v_load+1>=coalesce(max_clients,1) then null else v_date end,
          regions=case
            when r.player_country is null then regions
            when r.player_country=any(coalesce(regions,array[]::text[])) then regions
            else array_append(coalesce(regions,array[]::text[]),r.player_country)
          end,
          updated_at=now()
      where id=r.staff_profile_id;

      insert into public.staff_career_events(
        staff_profile_id,event_date,event_type,player_id,role,description
      )
      values(
        r.staff_profile_id,v_date,'reunited_favorite_player',r.player_id,r.primary_role,
        'Retrouvailles avec '||r.player_name||' après une ancienne collaboration marquante.'
      );

      if r.player_country is not null
         and r.nationality is not null
         and r.player_country<>r.nationality
      then
        insert into public.staff_career_events(
          staff_profile_id,event_date,event_type,player_id,role,description
        )
        values(
          r.staff_profile_id,v_date,'international_move',r.player_id,r.primary_role,
          'Nouveau projet international en '||r.player_country||' auprès de '||r.player_name||'.'
        );
        v_international:=v_international+1;
      end if;

      v_joined:=v_joined+1;
    end if;
  end loop;

  return jsonb_build_object(
    'date',v_date,
    'reunions',v_joined,
    'international_reunions',v_international,
    'model','CB-STAFF-BONDS-v17'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.refresh_staff_job_market_v17(p_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_date date:=coalesce(p_date,current_date);
  v_managed bigint;
  r record;
  v_score numeric;
  v_reason text;
  v_salary_uplift numeric;
  v_rank_gain numeric;
  v_fit_gain numeric;
  v_current_bond text;
  v_target_bond text;
  v_current_satisfaction int;
  v_current_fit int;
  v_target_fit int;
  v_current_rank int;
  v_target_rank int;
  v_current_country text;
  v_target_country text;
  v_travel int;
  v_load int;
  v_rep_before int;
  v_rep_after int;
  v_created int:=0;
  v_accepted int:=0;
  v_rejected int:=0;
  v_international int:=0;
begin
  if v_date<=date '2025-12-01' then
    return jsonb_build_object(
      'date',v_date,'created',0,'accepted',0,'rejected',0,'historical_cutoff',true,
      'model','CB-STAFF-JOB-MARKET-v17'
    );
  end if;

  select managed_player_id into v_managed from public.career_state where id='demo';

  -- Resolve mature offers first. The decision is driven by salary, sporting project,
  -- fit, ambition, loyalty, current satisfaction and persistent player bonds.
  for r in
    select
      o.*,sp.name,sp.primary_role,sp.reputation,sp.ambition,sp.loyalty,
      sp.max_clients,sp.nationality,
      coalesce(pref.travel_tolerance,10) as travel_tolerance
    from public.staff_job_offers_v17 o
    join public.staff_profiles sp on sp.id=o.staff_profile_id
    left join public.staff_preferences pref on pref.staff_profile_id=sp.id
    where o.status='pending' and o.deadline<v_date
    order by o.deadline,o.id
    limit 80
  loop
    select
      coalesce(psa.satisfaction,70),
      coalesce(psa.role_fit,public.staff_fit_score(r.from_player_id,r.staff_profile_id,r.offered_role)),
      coalesce(p.game_world_rank,p.ranking,999999)::int,
      p.country,
      coalesce(psa.weekly_salary,sp.asking_weekly_cost,500)
    into
      v_current_satisfaction,v_current_fit,v_current_rank,v_current_country,v_salary_uplift
    from public.staff_profiles sp
    left join public.player_staff_assignments psa
      on psa.staff_profile_id=sp.id
     and psa.player_id=r.from_player_id
     and psa.active=true
    left join public.players p on p.id=r.from_player_id
    where sp.id=r.staff_profile_id;

    select
      coalesce(p.game_world_rank,p.ranking,999999)::int,
      p.country,
      public.staff_fit_score(p.id,r.staff_profile_id,r.offered_role)::int
    into v_target_rank,v_target_country,v_target_fit
    from public.players p
    where p.id=r.to_player_id;

    select bond_type into v_current_bond
    from public.staff_player_bonds
    where staff_profile_id=r.staff_profile_id
      and player_id=r.from_player_id and active=true;

    select bond_type into v_target_bond
    from public.staff_player_bonds
    where staff_profile_id=r.staff_profile_id
      and player_id=r.to_player_id and active=true;

    v_salary_uplift:=greatest(-25,least(120,
      (r.weekly_salary/nullif(coalesce(v_salary_uplift,500),0)-1)*100
    ));
    v_rank_gain:=greatest(-20,least(25,
      case
        when v_target_rank<=10 then 18
        when v_target_rank<=50 then 13
        when v_target_rank<=200 then 8
        when v_target_rank<=500 then 4
        else 0
      end
      +case when v_target_rank*2<v_current_rank then 6 else 0 end
    ));
    v_fit_gain:=coalesce(v_target_fit,60)-coalesce(v_current_fit,60);

    v_score:=
      35
      +v_salary_uplift*.36
      +v_rank_gain
      +greatest(-8,least(10,v_fit_gain*.55))
      +coalesce(r.ambition,10)*.75
      -coalesce(r.loyalty,10)*.65
      -greatest(0,coalesce(v_current_satisfaction,70)-70)*.35
      +case coalesce(v_current_bond,'')
         when 'Joueur favori' then -24
         when 'Ancien joueur apprécié' then -12
         when 'Relation de confiance' then -7
         else 0 end
      +case coalesce(v_target_bond,'')
         when 'Joueur favori' then 22
         when 'Ancien joueur apprécié' then 12
         when 'Relation de confiance' then 7
         else 0 end
      +case when v_target_country=coalesce(r.nationality,'') then 4 else 0 end
      +case
         when v_target_country is distinct from v_current_country
           then (coalesce(r.travel_tolerance,10)-10)*.55
         else 2
       end
      +mod(abs(hashtext('decision|'||r.id::text||'|'||v_date::text)),10);

    v_reason:=case
      when coalesce(v_current_bond,'')='Joueur favori' and v_score<60
        then 'Fidélité forte au joueur actuel'
      when coalesce(v_target_bond,'') in ('Joueur favori','Ancien joueur apprécié') and v_score>=55
        then 'Retrouvailles avec un joueur très apprécié'
      when v_salary_uplift>=30 and v_score>=55
        then 'Offre financière nettement supérieure'
      when v_rank_gain>=13 and v_score>=55
        then 'Projet sportif de très haut niveau'
      when v_fit_gain>=10 and v_score>=55
        then 'Compatibilité nettement meilleure avec le nouveau projet'
      when v_target_country is distinct from v_current_country
           and coalesce(r.travel_tolerance,10)>=14 and v_score>=55
        then 'Envie d’un nouveau projet international'
      when v_score<55 and coalesce(r.loyalty,10)>=15
        then 'Loyauté envers le projet actuel'
      when v_score<55 and v_salary_uplift<15
        then 'Offre jugée insuffisante'
      else case when v_score>=55 then 'Nouveau défi sportif' else 'Projet actuel préféré' end
    end;

    if v_score>=55 then
      select count(*) into v_load
      from public.player_staff_assignments
      where staff_profile_id=r.staff_profile_id and active=true;

      if public.staff_role_group(r.primary_role)='coach'
         or coalesce(r.max_clients,1)<=1
         or v_load>=coalesce(r.max_clients,1)
      then
        update public.player_staff_assignments
        set active=false,end_date=v_date,ended_reason='Départ après offre employeur IA V17'
        where staff_profile_id=r.staff_profile_id
          and player_id=r.from_player_id and active=true;
      end if;

      insert into public.player_staff_assignments(
        player_id,staff_profile_id,role,start_date,end_date,active,verified,
        affinity,trust,source_label,snapshot_date,notes,weekly_salary,contract_end,
        assignment_generation,last_review_date,role_fit,satisfaction,team_chemistry,
        poached_from_player_id
      )
      values(
        r.to_player_id,r.staff_profile_id,r.offered_role,v_date,null,true,false,
        greatest(60,least(92,65+coalesce(v_target_fit,60)/7)),
        greatest(56,least(92,60+coalesce(v_target_fit,60)/8)),
        'Court Boss · marché employeur IA v17',v_date,
        v_reason,
        r.weekly_salary,
        v_date+(78+mod(abs(hashtext('job-contract|'||r.id::text)),79))*7,
        1,v_date,v_target_fit,
        greatest(62,least(94,65+coalesce(v_target_fit,60)/5)),
        greatest(60,least(94,64+coalesce(v_target_fit,60)/6)),
        r.from_player_id
      )
      on conflict do nothing;

      v_rep_before:=r.reputation;
      v_rep_after:=least(20,v_rep_before+case when v_target_rank<=20 and v_current_rank>100 then 1 else 0 end);

      update public.staff_profiles
      set reputation=v_rep_after,
          asking_weekly_cost=greatest(
            asking_weekly_cost,
            round(r.weekly_salary*case when v_rep_after>v_rep_before then 1.05 else 1 end)
          ),
          market_status=case
            when (
              select count(*) from public.player_staff_assignments psa
              where psa.staff_profile_id=r.staff_profile_id and psa.active=true
            )>=coalesce(max_clients,1) then 'contracted'
            else 'available'
          end,
          available_from=case
            when (
              select count(*) from public.player_staff_assignments psa
              where psa.staff_profile_id=r.staff_profile_id and psa.active=true
            )>=coalesce(max_clients,1) then null
            else v_date
          end,
          regions=case
            when v_target_country is null then regions
            when v_target_country=any(coalesce(regions,array[]::text[])) then regions
            else array_append(coalesce(regions,array[]::text[]),v_target_country)
          end,
          adaptability_rating=least(20,
            adaptability_rating+
            case
              when v_target_country is distinct from v_current_country
               and mod(abs(hashtext('adapt-move|'||id::text||'|'||v_date::text)),100)<35
              then 1 else 0 end
          ),
          updated_at=now()
      where id=r.staff_profile_id;

      update public.staff_job_offers_v17
      set status='accepted',decision_score=round(v_score,1),decision_reason=v_reason,resolved_at=v_date
      where id=r.id;

      insert into public.staff_career_events(
        staff_profile_id,event_date,event_type,player_id,other_player_id,role,
        description,reputation_before,reputation_after
      )
      values(
        r.staff_profile_id,v_date,
        case when coalesce(v_target_bond,'') in ('Joueur favori','Ancien joueur apprécié')
             then 'followed_favorite_player'
             else 'job_offer_accepted' end,
        r.to_player_id,r.from_player_id,r.offered_role,
        'Offre acceptée : '||v_reason||'.',
        v_rep_before,v_rep_after
      );

      if v_target_country is distinct from v_current_country then
        insert into public.staff_career_events(
          staff_profile_id,event_date,event_type,player_id,other_player_id,role,description
        )
        values(
          r.staff_profile_id,v_date,'international_move',
          r.to_player_id,r.from_player_id,r.offered_role,
          'Changement de pays : '||coalesce(v_current_country,'?')||' → '||coalesce(v_target_country,'?')||'.'
        );
        v_international:=v_international+1;
      end if;

      v_accepted:=v_accepted+1;
    else
      update public.staff_job_offers_v17
      set status='rejected',decision_score=round(v_score,1),decision_reason=v_reason,resolved_at=v_date
      where id=r.id;

      insert into public.staff_career_events(
        staff_profile_id,event_date,event_type,player_id,other_player_id,role,description
      )
      values(
        r.staff_profile_id,v_date,'job_offer_rejected',
        r.from_player_id,r.to_player_id,r.offered_role,
        'Offre refusée : '||v_reason||'.'
      );
      v_rejected:=v_rejected+1;
    end if;
  end loop;

  -- Generate offers for contracted AI staff only. User staff remains governed by the
  -- interactive external-offer system already used by the game.
  insert into public.staff_job_offers_v17(
    staff_profile_id,from_player_id,to_player_id,offered_role,
    weekly_salary,signing_bonus,offer_date,deadline,status
  )
  select
    src.staff_profile_id,src.player_id,target.id,src.role,
    round(greatest(coalesce(src.weekly_salary,sp.asking_weekly_cost,500),sp.asking_weekly_cost)*
      (
        1.12
        +case when target.wr<=20 then .20 when target.wr<=100 then .12 else .06 end
        +sp.reputation*.005
        +sp.ambition*.004
        +mod(abs(hashtext('salary|'||src.staff_profile_id::text||'|'||to_char(v_date,'YYYY-MM'))),12)/100.0
      )
    ),
    round(greatest(coalesce(src.weekly_salary,sp.asking_weekly_cost,500),sp.asking_weekly_cost)*
      (1.5+sp.reputation*.10)
    ),
    v_date,
    v_date+(7+mod(abs(hashtext('deadline-v17|'||src.staff_profile_id::text||'|'||v_date::text)),15)),
    'pending'
  from (
    select psa.*
    from public.player_staff_assignments psa
    join public.staff_profiles sx on sx.id=psa.staff_profile_id
    join public.players px on px.id=psa.player_id
    where psa.active=true
      and px.career_status='active'
      and sx.active=true
      and sx.reputation>=10
      and coalesce(psa.start_date,psa.snapshot_date,v_date)<=v_date-90
      and not exists(select 1 from public.staff s where s.profile_id=psa.staff_profile_id)
      and not exists(
        select 1 from public.staff_job_offers_v17 o
        where o.staff_profile_id=psa.staff_profile_id and o.status='pending'
      )
      and mod(abs(hashtext(
        'market-v17|'||psa.staff_profile_id::text||'|'||psa.player_id::text||'|'||to_char(v_date,'YYYY-MM')
      )),100)<greatest(4,least(18,4+sx.reputation/2+sx.ambition/4-sx.loyalty/6))
    order by sx.reputation desc,coalesce(px.game_world_rank,px.ranking,999999),psa.id
    limit 90
  ) src
  join public.staff_profiles sp on sp.id=src.staff_profile_id
  join public.players source_player on source_player.id=src.player_id
  join lateral (
    select
      p.id,p.country,coalesce(p.game_world_rank,p.ranking,999999)::int wr,
      public.staff_fit_score(p.id,src.staff_profile_id,src.role)::int fit
    from public.players p
    where p.career_status='active'
      and p.id<>src.player_id
      and p.id<>coalesce(v_managed,-1)
      and coalesce(p.game_world_rank,p.ranking,999999)<=600
      and not exists(
        select 1 from public.player_staff_assignments e
        where e.player_id=p.id and e.staff_profile_id=src.staff_profile_id and e.active=true
      )
      and (
        coalesce(p.game_world_rank,p.ranking,999999)+80
          <coalesce(source_player.game_world_rank,source_player.ranking,999999)
        or coalesce(p.game_world_rank,p.ranking,999999)<=50
      )
      and public.staff_fit_score(p.id,src.staff_profile_id,src.role)
          >=coalesce(src.role_fit,public.staff_fit_score(src.player_id,src.staff_profile_id,src.role))+3
    order by
      case when p.country=sp.nationality then 0 else 1 end,
      coalesce(p.game_world_rank,p.ranking,999999),
      public.staff_fit_score(p.id,src.staff_profile_id,src.role) desc,
      p.id
    limit 1
  ) target on true
  where not exists(
    select 1 from public.staff_job_offers_v17 o
    where o.staff_profile_id=src.staff_profile_id and o.status='pending'
  )
  order by sp.reputation desc,target.wr,src.id
  limit 30
  on conflict do nothing;

  get diagnostics v_created=row_count;

  return jsonb_build_object(
    'date',v_date,
    'created',v_created,
    'accepted',v_accepted,
    'rejected',v_rejected,
    'international_moves',v_international,
    'pending',(select count(*) from public.staff_job_offers_v17 where status='pending'),
    'model','CB-STAFF-JOB-MARKET-v17'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.shape_former_player_staff_v17(p_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_date date:=coalesce(p_date,current_date);
  v_year int:=extract(year from coalesce(p_date,current_date))::int;
  r record;
  v_role text;
  v_updated int:=0;
begin
  for r in
    select
      sp.id,sp.former_player_id,sp.name,sp.generation_year,sp.source_label,
      p.career_high_rank,p.career_high_doubles_rank,p.style,p.country,
      coalesce(pa.serve_power,10) serve_power,
      coalesce(pa.volley,10) volley,
      coalesce(pa.tactics,10) tactics,
      coalesce(pa.anticipation,10) anticipation,
      coalesce(pa.return_game,10) return_game
    from public.staff_profiles sp
    join public.players p on p.id=sp.former_player_id
    left join public.player_attributes pa on pa.player_id=p.id
    where sp.active=true
      and sp.former_player_id is not null
      and coalesce(sp.generation_year,0)>=2026
      and coalesce(sp.source_label,'') not ilike '%staff v17 shaped%'
    order by coalesce(p.career_high_rank,99999),sp.id
    limit 400
  loop
    v_role:=case
      when coalesce(r.career_high_doubles_rank,99999)<=20
           and mod(abs(hashtext('former-role|'||r.id::text)),100)<28
        then 'Coach tactique'
      when coalesce(r.career_high_rank,99999)<=10 then
        case mod(abs(hashtext('champ-role|'||r.id::text)),10)
          when 0 then 'Agent'
          when 1 then 'Recruteur'
          when 2 then 'Coach tactique'
          else 'Coach principal'
        end
      when r.serve_power>=16 and mod(abs(hashtext('serve-role|'||r.id::text)),100)<38
        then 'Coach technique'
      when r.volley>=15 and mod(abs(hashtext('volley-role|'||r.id::text)),100)<30
        then 'Coach technique'
      when r.tactics>=15 or r.anticipation>=15
        then case when mod(abs(hashtext('tact-role|'||r.id::text)),100)<25
             then 'Analyste vidéo' else 'Coach tactique' end
      when coalesce(r.career_high_rank,99999)<=200
        then case mod(abs(hashtext('tour-role|'||r.id::text)),5)
          when 0 then 'Recruteur'
          when 1 then 'Coach jeunes'
          else 'Coach technique'
        end
      else
        case mod(abs(hashtext('depth-role|'||r.id::text)),4)
          when 0 then 'Recruteur'
          when 1 then 'Agent'
          else 'Coach jeunes'
        end
    end;

    update public.staff_profiles
    set primary_role=v_role,
        specialty=case
          when v_role='Agent' then 'Négociation & réseau joueur'
          when v_role='Recruteur' then 'Détection & lecture du circuit'
          when v_role='Coach principal' then 'Gestion globale & haute performance'
          when v_role='Coach tactique' then 'Lecture tactique & plans de match'
          when v_role='Analyste vidéo' then 'Analyse adversaire & tendances'
          when v_role='Coach jeunes' then 'Développement & transition vers le circuit'
          else case
            when r.serve_power>=16 then 'Service & premier coup'
            when r.volley>=15 then 'Jeu vers l’avant'
            when r.return_game>=15 then 'Retour & pression'
            else 'Technique issue de l’expérience pro'
          end
        end,
        coach_rating=greatest(coach_rating,
          case when coalesce(r.career_high_rank,99999)<=10 then 16
               when coalesce(r.career_high_rank,99999)<=50 then 14
               when coalesce(r.career_high_rank,99999)<=200 then 12 else 10 end
        ),
        tactical_rating=greatest(tactical_rating,least(20,8+r.tactics/2+r.anticipation/4)),
        communication_rating=greatest(communication_rating,
          10+mod(abs(hashtext('former-com|'||id::text)),9)
        ),
        negotiation_rating=case
          when v_role='Agent' then greatest(negotiation_rating,14+mod(abs(hashtext('former-neg|'||id::text)),7))
          else negotiation_rating
        end,
        scouting_rating=case
          when v_role in ('Recruteur','Analyste vidéo')
            then greatest(scouting_rating,13+mod(abs(hashtext('former-scout|'||id::text)),8))
          else scouting_rating
        end,
        max_clients=case
          when v_role='Agent' then greatest(max_clients,6)
          when v_role='Recruteur' then greatest(max_clients,4)
          when v_role='Analyste vidéo' then greatest(max_clients,3)
          else 1
        end,
        source_label=coalesce(source_label,'Court Boss')||' · staff v17 shaped',
        updated_at=now()
    where id=r.id;

    insert into public.staff_career_events(
      staff_profile_id,event_date,event_type,role,description
    )
    values(
      r.id,v_date,'former_player_staff_entry',v_role,
      'Début de seconde carrière après le circuit professionnel · rôle : '||v_role||'.'
    );

    v_updated:=v_updated+1;
  end loop;

  return jsonb_build_object(
    'date',v_date,
    'shaped',v_updated,
    'model','CB-FORMER-PLAYER-STAFF-v17'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.ensure_world_staff_pool(p_date date DEFAULT CURRENT_DATE, p_former_target integer DEFAULT 1500)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_date date:=coalesce(p_date,current_date);
  v_year int:=extract(year from coalesce(p_date,current_date))::int;
  v_former_target int:=greatest(300,least(coalesce(p_former_target,1500),2500));
  v_need int:=0;
  v_created_former int:=0;
  v_created_generated int:=0;
  v_existing_former int:=0;
  v_role text;
  v_target int;
  v_idx int;
  v_seed int;
  v_country text;
  v_name text;
  v_age int;
  v_rep int;
  v_max_clients int;
  v_countries text[]:=array[
    'FRA','ESP','ITA','GER','GBR','USA','AUS','CAN','ARG','BRA',
    'CZE','SRB','CRO','POL','NED','BEL','SWE','NOR','DEN','AUT',
    'SUI','POR','GRE','ROU','HUN','JPN','KOR','CHN','IND','TUR',
    'MEX','COL','CHI','RSA','MAR','TUN','EGY','NZL','FIN','SVK'
  ];
  v_roles text[]:=array[
    'Coach principal','Coach technique','Coach tactique',
    'Préparateur physique','Kinésithérapeute','Ostéopathe',
    'Analyste vidéo','Préparateur mental','Recruteur',
    'Nutritionniste','Agent'
  ];
  v_targets int[]:=array[
    900,350,350,
    1000,500,100,
    250,150,300,
    100,100
  ];
begin
  perform pg_advisory_xact_lock(94832013);

  select count(*)::int into v_existing_former
  from public.staff_profiles
  where former_player_status='yes' and former_player_id is not null;

  v_need:=greatest(0,v_former_target-v_existing_former);

  if v_need>0 then
    with eligible as (
      select
        p.id,p.name,p.country,p.is_real,p.birth_date,p.career_high_rank,
        coalesce(p.current_ability,50) as ca,
        coalesce(p.potential,55) as pot,
        coalesce(pa.tactics,10) as tactics,
        coalesce(pa.anticipation,10) as anticipation,
        coalesce(pa.concentration,10) as concentration,
        row_number() over(
          order by
            case when p.is_real then 0 else 1 end,
            coalesce(p.career_high_rank,99999),
            coalesce(p.current_ability,50) desc,
            p.id
        ) as rn
      from public.players p
      left join public.player_attributes pa on pa.player_id=p.id
      where p.career_status='retired'
        and p.birth_date is not null
        and extract(year from age(v_date,p.birth_date)) between 30 and 66
        and coalesce(p.retired_date,date '1900-01-01')
            <= v_date-(90+mod(abs(hashtext('staff-cooldown-v17|'||p.id::text)),640))
        and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
        and not exists(
          select 1 from public.staff_profiles sp where sp.former_player_id=p.id
        )
      order by
        case when p.is_real then 0 else 1 end,
        coalesce(p.career_high_rank,99999),
        p.id
      limit v_need
    )
    insert into public.staff_profiles(
      name,nationality,primary_role,secondary_roles,is_real,
      former_player_status,former_player_id,
      coach_rating,technical_rating,tactical_rating,mental_rating,
      fitness_rating,medical_rating,scouting_rating,youth_rating,
      motivation_rating,communication_rating,adaptability_rating,reputation,
      specialty,notes,source_label,source_cutoff_date,verified,active,
      world_generated,generation_year,market_status,available_from,
      staff_birth_date,retirement_year,asking_weekly_cost,max_clients
    )
    select
      e.name,e.country,
      case mod(abs(hashtext(e.id::text||'|'||v_year::text)),6)
        when 0 then 'Coach principal'
        when 1 then 'Coach technique'
        when 2 then 'Coach tactique'
        when 3 then 'Coach jeunes'
        when 4 then 'Recruteur'
        else 'Coach'
      end,
      case mod(abs(hashtext('secondary|'||e.id::text)),5)
        when 0 then array['Consultant']
        when 1 then array['Scout']
        when 2 then array['Sparring coach']
        when 3 then array['Développement jeunes']
        else array['Analyse tactique']
      end,
      e.is_real,'yes',e.id,
      greatest(8,least(20,round(
        9
        + case when coalesce(e.career_high_rank,99999)<=10 then 6
               when coalesce(e.career_high_rank,99999)<=50 then 5
               when coalesce(e.career_high_rank,99999)<=200 then 3
               else 1 end
        + e.tactics*.20
      )::int)),
      greatest(7,least(20,round(8+e.ca*.08+e.anticipation*.22)::int)),
      greatest(7,least(20,round(8+e.tactics*.42+e.anticipation*.20)::int)),
      greatest(7,least(20,round(8+e.concentration*.35+e.tactics*.15)::int)),
      greatest(6,least(18,round(7+e.ca*.07)::int)),
      6+mod(abs(hashtext('med|'||e.id::text)),8),
      greatest(7,least(20,round(8+e.anticipation*.28+e.tactics*.18)::int)),
      greatest(8,least(20,round(9+e.pot*.07+e.tactics*.15)::int)),
      10+mod(abs(hashtext('mot|'||e.id::text)),9),
      10+mod(abs(hashtext('com|'||e.id::text)),9),
      10+mod(abs(hashtext('adapt|'||e.id::text)),9),
      greatest(9,least(20,
        10+case when coalesce(e.career_high_rank,99999)<=10 then 9
                when coalesce(e.career_high_rank,99999)<=50 then 7
                when coalesce(e.career_high_rank,99999)<=200 then 5
                else 2 end
      )),
      'Reconversion après carrière professionnelle',
      'Ancien joueur reconverti dans le staff. Les attributs 1–20 sont des évaluations Court Boss.',
      'Court Boss · reconversion dynamique ancien joueur',
      v_date,false,true,
      true,v_year,'available',v_date,
      e.birth_date,
      v_year+greatest(3,68-extract(year from age(v_date,e.birth_date))::int),
      350 + (
        greatest(9,least(20,
          10+case when coalesce(e.career_high_rank,99999)<=10 then 9
                  when coalesce(e.career_high_rank,99999)<=50 then 7
                  when coalesce(e.career_high_rank,99999)<=200 then 5
                  else 2 end
        ))
      )*75,
      case when mod(abs(hashtext(e.id::text)),7)=0 then 2 else 1 end
    from eligible e
    on conflict(name) do nothing;

    get diagnostics v_created_former=row_count;
  end if;

  for v_idx in 1..array_length(v_roles,1) loop
    v_role:=v_roles[v_idx];
    v_target:=v_targets[v_idx];

    select greatest(0,v_target-count(*))::int
    into v_need
    from public.staff_profiles
    where world_generated=true
      and former_player_id is null
      and primary_role=v_role
      and active=true;

    if v_need>0 then
      for v_seed in 1..v_need loop
        v_country:=v_countries[
          1+mod(
            abs(hashtext(v_role||'|'||v_year::text||'|'||v_seed::text)),
            array_length(v_countries,1)
          )
        ];
        v_name:=public.cb_generated_staff_name(
          v_country,
          9000000+v_idx*100000+v_year*1000+v_seed
        );
        v_age:=28+mod(abs(hashtext('age|'||v_name)),29);
        v_rep:=8+mod(abs(hashtext('rep|'||v_name)),9);
        v_max_clients:=case
          when public.staff_role_group(v_role)='coach' then 1
          when public.staff_role_group(v_role) in ('fitness','medical') then 3
          when public.staff_role_group(v_role)='analysis' then 3
          when public.staff_role_group(v_role)='mental' then 2
          when public.staff_role_group(v_role)='scout' then 4
          else 3
        end;

        insert into public.staff_profiles(
          name,nationality,primary_role,secondary_roles,is_real,
          former_player_status,former_player_id,
          coach_rating,technical_rating,tactical_rating,mental_rating,
          fitness_rating,medical_rating,scouting_rating,youth_rating,
          motivation_rating,communication_rating,adaptability_rating,reputation,
          specialty,notes,source_label,source_cutoff_date,verified,active,
          world_generated,generation_year,market_status,available_from,
          staff_birth_date,retirement_year,asking_weekly_cost,max_clients
        )
        values(
          v_name,v_country,v_role,
          case public.staff_role_group(v_role)
            when 'coach' then array['Développement','Match']
            when 'fitness' then array['Prévention','Condition physique']
            when 'medical' then array['Récupération','Réathlétisation']
            when 'analysis' then array['Data','Analyse adversaire']
            when 'mental' then array['Confiance','Pression']
            when 'scout' then array['Détection','Réseau international']
            else array['Performance']
          end,
          false,'no',null,
          case when public.staff_role_group(v_role)='coach' then 11+mod(abs(hashtext('coach|'||v_name)),9) else 5+mod(abs(hashtext('coach|'||v_name)),7) end,
          case when public.staff_role_group(v_role)='coach' then 10+mod(abs(hashtext('tech|'||v_name)),10) else 5+mod(abs(hashtext('tech|'||v_name)),8) end,
          case when public.staff_role_group(v_role) in ('coach','analysis') then 10+mod(abs(hashtext('tact|'||v_name)),10) else 5+mod(abs(hashtext('tact|'||v_name)),8) end,
          case when public.staff_role_group(v_role)='mental' then 13+mod(abs(hashtext('ment|'||v_name)),8) else 7+mod(abs(hashtext('ment|'||v_name)),11) end,
          case when public.staff_role_group(v_role)='fitness' then 13+mod(abs(hashtext('fit|'||v_name)),8) else 6+mod(abs(hashtext('fit|'||v_name)),11) end,
          case when public.staff_role_group(v_role)='medical' then 13+mod(abs(hashtext('med|'||v_name)),8) else 5+mod(abs(hashtext('med|'||v_name)),10) end,
          case when public.staff_role_group(v_role)='scout' then 13+mod(abs(hashtext('scout|'||v_name)),8)
               when public.staff_role_group(v_role)='analysis' then 11+mod(abs(hashtext('scout|'||v_name)),9)
               else 6+mod(abs(hashtext('scout|'||v_name)),10) end,
          8+mod(abs(hashtext('youth|'||v_name)),12),
          9+mod(abs(hashtext('mot|'||v_name)),11),
          9+mod(abs(hashtext('com|'||v_name)),11),
          9+mod(abs(hashtext('adapt|'||v_name)),11),
          v_rep,
          case public.staff_role_group(v_role)
            when 'coach' then 'Coaching haute performance'
            when 'fitness' then 'Préparation physique & prévention'
            when 'medical' then 'Récupération & prévention des blessures'
            when 'analysis' then 'Analyse vidéo & data'
            when 'mental' then 'Préparation mentale & pression'
            when 'scout' then 'Scouting international'
            else 'Performance'
          end,
          'Profil staff généré de manière persistante par Court Boss.',
          'Court Boss · staff mondial généré',
          v_date,false,true,
          true,v_year,'available',v_date,
          make_date(v_year-v_age,1+mod(abs(hashtext('m|'||v_name)),12),1+mod(abs(hashtext('d|'||v_name)),28)),
          v_year+(64-v_age)+mod(abs(hashtext('retire|'||v_name)),8),
          250+v_rep*70+
            case public.staff_role_group(v_role)
              when 'coach' then 220
              when 'medical' then 180
              when 'fitness' then 170
              when 'analysis' then 150
              when 'mental' then 140
              when 'scout' then 130
              else 100
            end,
          v_max_clients
        )
        on conflict(name) do nothing;

        if found then
          v_created_generated:=v_created_generated+1;
        end if;
      end loop;
    end if;
  end loop;

  update public.staff_profiles
  set active=false,market_status='retired'
  where active=true
    and retirement_year is not null
    and retirement_year<=v_year;

  return jsonb_build_object(
    'date',v_date,
    'former_created',v_created_former,
    'generated_created',v_created_generated,
    'total_profiles',(select count(*) from public.staff_profiles),
    'active_profiles',(select count(*) from public.staff_profiles where active=true),
    'former_players',(select count(*) from public.staff_profiles where former_player_status='yes' and former_player_id is not null)
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.refresh_staff_market(p_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_date date:=coalesce(p_date,current_date);
  v_pool jsonb;
  v_shape jsonb;
  v_reunions jsonb;
  v_assign jsonb;
  v_lower jsonb;
  v_inserted int:=0;
begin
  v_pool:=public.ensure_world_staff_pool(v_date,1500);
  perform public.ensure_agent_staff_depth(v_date,450);
  v_shape:=public.shape_former_player_staff_v17(v_date);
  v_reunions:=public.refresh_staff_bonded_reunions_v17(v_date);
  v_assign:=public.refresh_world_staff_assignments(v_date);
  v_lower:=public.refresh_lower_tour_staff_assignments(v_date);

  update public.staff_candidates c
  set status=case
    when exists(select 1 from public.staff s where s.profile_id=c.profile_id) then 'hired'
    when exists(
      select 1 from public.staff_profiles sp
      where sp.id=c.profile_id and sp.active=true and sp.market_status='available'
    ) then 'available'
    else 'unavailable'
  end
  where c.profile_id is not null;

  delete from public.staff_candidates c
  where c.profile_id is not null
    and c.status='unavailable';

  -- Refresh untouched market slots every month so the list stays alive, but
  -- keep candidates already interviewed or negotiated with by the player.
  delete from public.staff_candidates
  where status='available'
    and coalesce(interview_status,'not_started')='not_started'
    and profile_id is not null;

  with available as (
    select
      sp.*,
      public.staff_role_group(sp.primary_role) as role_group,
      row_number() over(
        partition by public.staff_role_group(sp.primary_role)
        order by
          sp.reputation desc,
          case public.staff_role_group(sp.primary_role)
            when 'coach' then case when sp.primary_role ilike '%double%' then sp.doubles_coaching_rating else sp.coach_rating end
            when 'fitness' then sp.fitness_rating
            when 'medical' then sp.medical_rating
            when 'analysis' then greatest(sp.tactical_rating,sp.scouting_rating)
            when 'mental' then sp.mental_rating
            when 'scout' then sp.scouting_rating
            when 'agent' then sp.negotiation_rating
            when 'nutrition' then greatest(sp.fitness_rating,sp.medical_rating)
            else greatest(sp.coach_rating,sp.reputation)
          end desc,
          public.staff_fit_score(
            (select managed_player_id from public.career_state where id='demo'),
            sp.id,
            sp.primary_role
          ) desc,
          abs(hashtext(sp.id::text||'|'||to_char(v_date,'YYYY-MM')))
      )::int as role_rank
    from public.staff_profiles sp
    where sp.active=true
      and sp.market_status='available'
      and coalesce(sp.available_from,date '1900-01-01')<=v_date
      and not exists(select 1 from public.staff_candidates c where c.profile_id=sp.id)
      and not exists(select 1 from public.staff s where s.profile_id=sp.id)
  ),
  balanced as (
    select *
    from available a
    where a.role_rank <= case a.role_group
      when 'coach' then 30
      when 'fitness' then 14
      when 'medical' then 14
      when 'analysis' then 12
      when 'mental' then 10
      when 'scout' then 18
      when 'agent' then 12
      when 'nutrition' then 8
      else 2
    end
  ),
  ranked as (
    select b.*,
           row_number() over(
             order by
               case b.role_group
                 when 'coach' then 1
                 when 'fitness' then 2
                 when 'medical' then 3
                 when 'analysis' then 4
                 when 'mental' then 5
                 when 'scout' then 6
                 when 'agent' then 7
                 when 'nutrition' then 8
                 else 9
               end,
               b.role_rank
           )::int as market_rank
    from balanced b
  )
  insert into public.staff_candidates(
    name,role,skill,weekly_cost,signing_cost,specialty,status,profile_id,
    managed_fit,interview_status,competing_offers
  )
  select
    r.name,
    r.primary_role,
    case r.role_group
      when 'coach' then r.coach_rating
      when 'fitness' then r.fitness_rating
      when 'medical' then r.medical_rating
      when 'analysis' then greatest(r.tactical_rating,r.scouting_rating)
      when 'mental' then r.mental_rating
      when 'scout' then r.scouting_rating
      when 'agent' then r.negotiation_rating
      when 'nutrition' then greatest(r.fitness_rating,r.medical_rating)
      else greatest(r.coach_rating,r.reputation)
    end,
    r.asking_weekly_cost,
    round(r.asking_weekly_cost*(1.5+r.reputation/20.0))::numeric,
    r.specialty,
    'available',
    r.id,
    public.staff_fit_score(
      (select managed_player_id from public.career_state where id='demo'),
      r.id,
      r.primary_role
    ),
    'not_started',
    0
  from ranked r
  order by r.market_rank
  limit greatest(
    0,
    120-(select count(*) from public.staff_candidates where status in ('available','hired'))
  );

  get diagnostics v_inserted=row_count;

  return jsonb_build_object(
    'date',v_date,
    'pool',v_pool,
    'former_player_staff_v17',v_shape,
    'bonded_reunions_v17',v_reunions,
    'top_tour_assignments',v_assign,
    'lower_tour_assignments',v_lower,
    'market_added',v_inserted,
    'market_available',(select count(*) from public.staff_candidates where status='available'),
    'market_hired',(select count(*) from public.staff_candidates where status='hired'),
    'market_by_group',(
      select coalesce(jsonb_object_agg(role_group,n), '{}'::jsonb)
      from (
        select public.staff_role_group(role) role_group,count(*) n
        from public.staff_candidates
        where status='available'
        group by public.staff_role_group(role)
      ) q
    )
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.publish_staff_world_news(p_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_date date:=coalesce(p_date,current_date);
  v_added int:=0;
  r record;
  headline text;
begin
  for r in
    select
      e.id,e.event_date,e.event_type,e.description,e.player_id,e.other_player_id,
      sp.name as staff_name,sp.primary_role,sp.reputation,
      p.name as player_name,coalesce(p.game_world_rank,p.ranking,999999) as player_rank,
      op.name as other_player_name
    from public.staff_career_events e
    join public.staff_profiles sp on sp.id=e.staff_profile_id
    left join public.players p on p.id=e.player_id
    left join public.players op on op.id=e.other_player_id
    where e.event_date>=date_trunc('month',v_date)::date
      and e.event_date<=v_date
      and e.event_type in (
        'poached','left_user_for_offer','retained_after_offer','season_review','reputation',
        'job_offer_accepted','followed_favorite_player','reunited_favorite_player',
        'international_move','reputation_breakthrough','former_player_staff_entry'
      )
      and not exists(select 1 from public.staff_news_published n where n.event_id=e.id)
      and (
        coalesce(p.game_world_rank,p.ranking,999999)<=50
        or sp.reputation>=17
        or e.event_type in (
          'season_review','poached','job_offer_accepted','followed_favorite_player',
          'reunited_favorite_player','international_move','reputation_breakthrough'
        )
      )
    order by e.event_date,e.id
    limit 12
  loop
    headline:=case r.event_type
      when 'poached' then
        coalesce(r.staff_name,'Un coach')||' rejoint '||coalesce(r.player_name,'un nouveau joueur')
        ||case when r.other_player_name is not null then ' après avoir quitté '||r.other_player_name else '' end||'.'
      when 'left_user_for_offer' then
        coalesce(r.staff_name,'Un membre du staff')||' change de projet et rejoint '||coalesce(r.player_name,'un autre joueur')||'.'
      when 'retained_after_offer' then
        coalesce(r.staff_name,'Un membre du staff')||' prolonge finalement son aventure malgré une approche extérieure.'
      when 'season_review' then
        coalesce(r.staff_name,'Un coach')||' voit sa cote progresser après une grosse saison.'
      when 'job_offer_accepted' then
        coalesce(r.staff_name,'Un membre du staff')||' change de projet et rejoint '||coalesce(r.player_name,'un nouveau joueur')||'.'
      when 'followed_favorite_player' then
        coalesce(r.staff_name,'Un coach')||' choisit de suivre '||coalesce(r.player_name,'un joueur avec qui le lien est fort')||'.'
      when 'reunited_favorite_player' then
        coalesce(r.staff_name,'Un coach')||' retrouve '||coalesce(r.player_name,'un ancien joueur')||' pour une nouvelle collaboration.'
      when 'international_move' then
        coalesce(r.staff_name,'Un membre du staff')||' tente une nouvelle aventure internationale.'
      when 'reputation_breakthrough' then
        coalesce(r.staff_name,'Un coach')||' explose sur le marché après une série de résultats majeurs.'
      when 'former_player_staff_entry' then
        coalesce(r.staff_name,'Un ancien joueur')||' entame sa seconde carrière dans le staff.'
      else
        coalesce(r.staff_name,'Un membre du staff')||' fait évoluer sa réputation sur le circuit.'
    end;

    insert into public.news_items(body) values(headline);
    insert into public.staff_news_published(event_id) values(r.id) on conflict do nothing;
    v_added:=v_added+1;
  end loop;

  return jsonb_build_object('date',v_date,'published',v_added);
end;
$function$;

revoke all on function public.sync_staff_employer_history_v17(date) from public,anon,authenticated;
revoke all on function public.refresh_staff_reputation_dynamics_v17(date) from public,anon,authenticated;
revoke all on function public.refresh_staff_bonded_reunions_v17(date) from public,anon,authenticated;
revoke all on function public.refresh_staff_job_market_v17(date) from public,anon,authenticated;
revoke all on function public.shape_former_player_staff_v17(date) from public,anon,authenticated;
grant execute on function public.sync_staff_employer_history_v17(date) to service_role;
grant execute on function public.refresh_staff_reputation_dynamics_v17(date) to service_role;
grant execute on function public.refresh_staff_bonded_reunions_v17(date) to service_role;
grant execute on function public.refresh_staff_job_market_v17(date) to service_role;
grant execute on function public.shape_former_player_staff_v17(date) to service_role;
