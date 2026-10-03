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
      when coalesce(v_target_bond,'') in ('Joueur favori','Ancien joueur apprécié') and v_score>=65
        then 'Retrouvailles avec un joueur très apprécié'
      when v_salary_uplift>=30 and v_score>=65
        then 'Offre financière nettement supérieure'
      when v_rank_gain>=13 and v_score>=65
        then 'Projet sportif de très haut niveau'
      when v_fit_gain>=10 and v_score>=65
        then 'Compatibilité nettement meilleure avec le nouveau projet'
      when v_target_country is distinct from v_current_country
           and coalesce(r.travel_tolerance,10)>=14 and v_score>=65
        then 'Envie d’un nouveau projet international'
      when v_score<65 and coalesce(r.loyalty,10)>=15
        then 'Loyauté envers le projet actuel'
      when v_score<65 and v_salary_uplift<15
        then 'Offre jugée insuffisante'
      else case when v_score>=65 then 'Nouveau défi sportif' else 'Projet actuel préféré' end
    end;

    if v_score>=65 then
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

