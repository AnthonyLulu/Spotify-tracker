-- Court Boss Career Depth V15
-- Long-horizon QA + dynamic Hall of Fame + deeper career operating economy + richer media storylines.

create or replace function public.career_operating_cost_profile_v15(p_date date default current_date)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  c public.career_state%rowtype;
  v_rank int:=9999;
  v_staff int:=0;
  v_level int:=1;
  v_tier text;
  v_team_ops numeric:=0;
  v_academy_ops numeric:=0;
  v_recommended int:=1;
begin
  select * into c from public.career_state where id='demo';
  if not found then
    return jsonb_build_object('ok',false,'reason','career_missing');
  end if;

  select coalesce(p.game_world_rank,p.ranking,c.singles_rank,9999)
    into v_rank
  from public.players p
  where p.id=c.managed_player_id;

  select count(*) into v_staff from public.staff;
  select coalesce(academy_level,1) into v_level from public.academies where id='demo';

  if v_rank<=5 then
    v_tier:='superstar'; v_recommended:=7; v_team_ops:=1750;
  elsif v_rank<=20 then
    v_tier:='elite'; v_recommended:=5; v_team_ops:=1150;
  elsif v_rank<=100 then
    v_tier:='tour'; v_recommended:=3; v_team_ops:=620;
  elsif v_rank<=250 then
    v_tier:='challenger'; v_recommended:=2; v_team_ops:=330;
  else
    v_tier:='lean'; v_recommended:=1; v_team_ops:=140;
  end if;

  -- Logistics/per-diem scale with how many people actually travel with the player.
  v_team_ops:=round(v_team_ops + greatest(0,v_staff-v_recommended)*85 + least(v_staff,v_recommended)*35);
  v_academy_ops:=round(case greatest(1,least(4,v_level))
    when 1 then 90 when 2 then 220 when 3 then 520 else 980 end);

  return jsonb_build_object(
    'ok',true,'date',p_date,'ranking',v_rank,'career_tier',v_tier,
    'staff_count',v_staff,'recommended_staff',v_recommended,
    'team_operations_weekly',v_team_ops,'academy_operations_weekly',v_academy_ops,
    'total_weekly',v_team_ops+v_academy_ops,
    'model','CB-CAREER-ECONOMY-v15'
  );
end;
$$;

create or replace function public.process_career_operating_costs_v15(p_date date, p_week int)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_profile jsonb;
  v_team numeric:=0;
  v_academy numeric:=0;
  v_total numeric:=0;
  v_balance numeric:=0;
  v_key text:='week:'||p_date::text||':career-ops-v15';
begin
  if exists(select 1 from public.finance_transactions where transaction_key=v_key) then
    return jsonb_build_object('ok',true,'processed',false,'reason','already_processed','profile',public.career_operating_cost_profile_v15(p_date));
  end if;

  v_profile:=public.career_operating_cost_profile_v15(p_date);
  if coalesce((v_profile->>'ok')::boolean,false)=false then return v_profile; end if;

  v_team:=coalesce((v_profile->>'team_operations_weekly')::numeric,0);
  v_academy:=coalesce((v_profile->>'academy_operations_weekly')::numeric,0);
  v_total:=v_team+v_academy;

  update public.career_state
  set budget=coalesce(budget,0)-v_total, updated_at=now()
  where id='demo'
  returning budget into v_balance;

  insert into public.finance_transactions(
    transaction_key,game_date,week,category,amount,currency,source_type,description,balance_after,metadata
  ) values (
    v_key,p_date,p_week,'entourage_ops',-v_team,'EUR','weekly_cycle',
    'Logistique entourage · déplacements locaux, hôtels et per diem',v_balance+v_academy,
    v_profile
  );

  insert into public.finance_transactions(
    transaction_key,game_date,week,category,amount,currency,source_type,description,balance_after,metadata
  ) values (
    v_key||':academy',p_date,p_week,'academy_ops',-v_academy,'EUR','weekly_cycle',
    'Fonctionnement académie · installations, terrain et développement',v_balance,
    v_profile
  );

  update public.finances
  set staff_cost=coalesce(staff_cost,0)+v_team,
      academy_cost=coalesce(academy_cost,0)+v_academy
  where id='demo';

  return jsonb_build_object('ok',true,'processed',true,'charged',v_total,'balance',v_balance,'profile',v_profile);
end;
$$;

create or replace function public.refresh_hall_of_fame_dynamic_v15(p_date date default current_date)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_rows int:=0;
begin
  with title_stats as (
    select
      pt.player_id,
      count(*)::int as titles,
      count(*) filter(where lower(coalesce(pt.level,'')) ~ 'grand|slam')::int as slams,
      count(*) filter(where lower(coalesce(pt.level,'')) like '%1000%' or lower(coalesce(pt.level,'')) like '%masters%')::int as masters,
      count(*) filter(where lower(coalesce(pt.level,'')) like '%finals%')::int as finals
    from public.player_titles pt
    group by pt.player_id
  ),
  match_stats as (
    select player_id,
           sum(wins)::int as wins,
           sum(losses)::int as losses
    from (
      select winner_id as player_id,count(*)::int wins,0::int losses
      from public.world_tournament_matches
      where winner_id is not null group by winner_id
      union all
      select loser_id as player_id,0::int wins,count(*)::int losses
      from public.world_tournament_matches
      where loser_id is not null group by loser_id
    ) q
    group by player_id
  ),
  candidates as (
    select
      p.id,p.name,p.country,p.birth_date,p.career_status,p.ranking,p.points,p.photo_url,
      coalesce(ts.titles,0) as titles,
      coalesce(ts.slams,0) as grand_slams,
      coalesce(ts.masters,0) as masters,
      coalesce(ts.finals,0) as tour_finals,
      coalesce(ms.wins,0) as wins,
      coalesce(ms.losses,0) as losses,
      case when coalesce(ms.wins,0)+coalesce(ms.losses,0)>0
        then round(100.0*coalesce(ms.wins,0)/(coalesce(ms.wins,0)+coalesce(ms.losses,0)),1)
        else 0 end as win_pct,
      (
        coalesce(ts.slams,0)*10000
        +coalesce(ts.masters,0)*1200
        +coalesce(ts.finals,0)*1800
        +coalesce(ts.titles,0)*250
        +coalesce(p.weeks_at_no1,0)*80
        +case when coalesce(p.career_high_rank,9999)=1 then 3500 when coalesce(p.career_high_rank,9999)<=5 then 1200 when coalesce(p.career_high_rank,9999)<=10 then 500 else 0 end
        +coalesce(ms.wins,0)*15
      )::int as history_score
    from public.players p
    left join title_stats ts on ts.player_id=p.id
    left join match_stats ms on ms.player_id=p.id
    where lower(coalesce(p.career_status,''))='retired'
      and (
        coalesce(p.game_generated,false)=true
        or coalesce(p.retired_date,date '1900-01-01')>=date '2026-01-01'
      )
  )
  insert into public.hall_of_fame_candidates(
    id,name,country,birth_date,career_status,ranking,points,photo_url,
    titles,grand_slams,masters,tour_finals,wins,losses,win_pct,history_score
  )
  select
    id,name,country,birth_date,career_status,ranking,points,photo_url,
    titles,grand_slams,masters,tour_finals,wins,losses,win_pct,history_score
  from candidates
  where grand_slams>0
     or titles>=12
     or history_score>=5000
  on conflict(id) do update set
    name=excluded.name,country=excluded.country,birth_date=excluded.birth_date,
    career_status=excluded.career_status,ranking=excluded.ranking,points=excluded.points,
    photo_url=coalesce(excluded.photo_url,public.hall_of_fame_candidates.photo_url),
    titles=excluded.titles,grand_slams=excluded.grand_slams,masters=excluded.masters,
    tour_finals=excluded.tour_finals,wins=excluded.wins,losses=excluded.losses,
    win_pct=excluded.win_pct,history_score=excluded.history_score;

  get diagnostics v_rows=row_count;

  return jsonb_build_object(
    'ok',true,'date',p_date,'refreshed',v_rows,
    'total',(select count(*) from public.hall_of_fame_candidates),
    'future_retirees',(select count(*) from public.hall_of_fame_candidates h join public.players p on p.id=h.id where coalesce(p.retired_date,date '1900-01-01')>=date '2026-01-01'),
    'model','CB-HALL-OF-FAME-v15'
  );
end;
$$;

create or replace function public.career_generate_media_event_v15(p_date date)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  c public.career_state%rowtype;
  p public.players%rowtype;
  inj public.injuries%rowtype;
  rel record;
  v_kind text:='career';
  v_headline text;
  v_body text;
  v_tone text:='neutral';
  v_priority text:='normal';
begin
  select * into c from public.career_state where id='demo';
  if not found then return jsonb_build_object('ok',false,'created',false,'reason','career_missing'); end if;
  select * into p from public.players where id=c.managed_player_id;

  if exists(
    select 1 from public.media_events
    where date_trunc('month',event_date)=date_trunc('month',p_date)
      and related_player_id=c.managed_player_id
  ) then
    return jsonb_build_object('ok',true,'created',false,'reason','monthly_story_exists');
  end if;

  select * into inj from public.injuries
  where player_id=c.managed_player_id and lower(coalesce(status,''))='active'
  order by started_at desc limit 1;

  if found then
    v_kind:='medical'; v_tone:='concern'; v_priority:='high';
    v_headline:=c.player_name||' doit gérer son calendrier avec prudence';
    v_body:='Le staff médical suit une '||coalesce(inj.injury_type,'blessure')||'. La question n’est plus seulement le prochain match : il faut arbitrer entre reprise, risque de rechute et objectifs de saison.';
  else
    select r.*,case when r.player_a_id=c.managed_player_id then pb.name else pa.name end as other_name
    into rel
    from public.player_relationships r
    join public.players pa on pa.id=r.player_a_id
    join public.players pb on pb.id=r.player_b_id
    where r.active=true
      and (r.player_a_id=c.managed_player_id or r.player_b_id=c.managed_player_id)
      and lower(coalesce(r.relation_type,'')) like '%rival%'
    order by r.respect desc,r.last_update desc
    limit 1;

    if found and coalesce(p.form,c.form,70)>=74 then
      v_kind:='rivalry'; v_tone:='competitive'; v_priority:='normal';
      v_headline:=c.player_name||' et '||coalesce(rel.other_name,'un rival')||' alimentent une rivalité sportive';
      v_body:='Les résultats et la proximité sportive donnent du poids à cette confrontation. Le respect reste élevé, mais chaque nouveau duel peut modifier la dynamique entre les deux joueurs.';
    elsif coalesce(c.singles_rank,999999)<=10 then
      v_kind:='spotlight'; v_tone:='positive';
      v_headline:=c.player_name||' s’installe au premier plan';
      v_body:='Le classement place désormais '||c.player_name||' dans une exposition permanente. Les attentes montent, les adversaires préparent davantage les confrontations et chaque choix de calendrier est commenté.';
    elsif coalesce(c.fatigue,0)>=72 then
      v_kind:='workload'; v_tone:='concern'; v_priority:='high';
      v_headline:='Le calendrier de '||c.player_name||' commence à peser';
      v_body:='La charge récente nourrit le débat entre continuité sportive et récupération. Staff, déplacements et préparation physique deviennent aussi importants que le prochain résultat.';
    elsif coalesce(c.form,70)>=82 then
      v_kind:='form'; v_tone:='positive';
      v_headline:='La dynamique de '||c.player_name||' attire les regards';
      v_body:='La forme récente renforce les attentes. Le prochain bloc de tournois peut transformer une bonne série en véritable changement de statut.';
    else
      select r.*,case when r.player_a_id=c.managed_player_id then pb.name else pa.name end as other_name
      into rel
      from public.player_relationships r
      join public.players pa on pa.id=r.player_a_id
      join public.players pb on pb.id=r.player_b_id
      where r.active=true
        and (r.player_a_id=c.managed_player_id or r.player_b_id=c.managed_player_id)
        and coalesce(r.affinity,0)>=82
      order by r.affinity desc,r.last_update desc
      limit 1;

      if found then
        v_kind:='relationship'; v_tone:='positive';
        v_headline:='Un lien fort se construit sur le circuit';
        v_body:=c.player_name||' entretient une forte affinité sportive avec '||coalesce(rel.other_name,'un autre joueur')||'. En double, à l’entraînement ou dans les périodes difficiles, ce type de relation peut influencer la carrière.';
      else
        v_kind:='career'; v_tone:='neutral';
        v_headline:='Le projet '||c.player_name||' continue de se construire';
        v_body:='Progression, calendrier, staff, finances et récupération restent liés. Les choix du manager façonnent autant la trajectoire que les résultats bruts.';
      end if;
    end if;
  end if;

  insert into public.media_events(
    event_date,kind,headline,body,tone,priority,action_route,related_player_id
  ) values(
    p_date,v_kind,v_headline,v_body,v_tone,v_priority,
    case when v_kind='medical' then 'medical' when v_kind in ('relationship','rivalry') then 'relationships' else 'myplayer' end,
    c.managed_player_id
  );

  insert into public.inbox_items(
    kind,title,body,action_route,is_read,game_date,priority,action_type,action_label,action_payload,
    related_entity_type,related_entity_id,decision_status
  ) values(
    'media',v_headline,v_body,
    case when v_kind='medical' then 'medical' when v_kind in ('relationship','rivalry') then 'relationships' else 'myplayer' end,
    false,p_date,v_priority,'open_route','Voir le contexte',
    jsonb_build_object('route',case when v_kind='medical' then 'medical' when v_kind in ('relationship','rivalry') then 'relationships' else 'myplayer' end),
    'player',c.managed_player_id,'info'
  );

  return jsonb_build_object('ok',true,'created',true,'kind',v_kind,'headline',v_headline,'model','CB-MEDIA-v15');
end;
$$;

create or replace function public.career_long_term_health_v15(p_date date default current_date)
returns jsonb
language sql
security definer
set search_path=public
as $$
  select jsonb_build_object(
    'ok',true,
    'date',p_date,
    'living_world',public.living_world_integrity_audit_v14(p_date),
    'horizon_2050',public.living_world_horizon_test_v14(2025,2050),
    'economy',public.career_operating_cost_profile_v15(p_date),
    'hall_of_fame_total',(select count(*) from public.hall_of_fame_candidates),
    'active_staff_profiles',(select count(*) from public.staff_profiles where active=true),
    'active_players',(select count(*) from public.players where career_status='active'),
    'retired_ranked',(select count(*) from public.players where career_status='retired' and ranking_current=true),
    'future_retired_entries',(
      select count(*)
      from public.entries e
      join public.players p on p.id=e.player_id
      join public.tournaments t on t.id=e.tournament_id
      where p.career_status='retired' and coalesce(e.status,'')='entered' and t.start_date>=p_date
    ),
    'model','CB-CAREER-LONG-HORIZON-v15'
  );
$$;

revoke all on function public.career_operating_cost_profile_v15(date) from public,anon,authenticated;
revoke all on function public.process_career_operating_costs_v15(date,int) from public,anon,authenticated;
revoke all on function public.refresh_hall_of_fame_dynamic_v15(date) from public,anon,authenticated;
revoke all on function public.career_generate_media_event_v15(date) from public,anon,authenticated;
revoke all on function public.career_long_term_health_v15(date) from public,anon,authenticated;
grant execute on function public.career_operating_cost_profile_v15(date) to service_role;
grant execute on function public.process_career_operating_costs_v15(date,int) to service_role;
grant execute on function public.refresh_hall_of_fame_dynamic_v15(date) to service_role;
grant execute on function public.career_generate_media_event_v15(date) to service_role;
grant execute on function public.career_long_term_health_v15(date) to service_role;
