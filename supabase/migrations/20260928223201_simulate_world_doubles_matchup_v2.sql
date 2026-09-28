CREATE OR REPLACE FUNCTION public.simulate_world_doubles_tournaments(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  t record;
  wp record;
  fp record;
  wa players%rowtype;
  wb players%rowtype;
  fa players%rowtype;
  fb players%rowtype;
  v_year int;
  v_managed bigint;
  v_wpts int;
  v_fpts int;
  v_draw int;
  v_rounds int;
  v_simulated int:=0;
  v_seeded boolean:=false;
  v_title_a bigint;
  v_title_b bigint;
  v_pair_match jsonb;
  v_pair_prob numeric:=.5;
  v_pair_tmp record;
begin
  if p_to_date<=date '2025-12-01' then
    return jsonb_build_object(
      'tournaments_simulated',0,
      'from',p_from_date,
      'to',p_to_date,
      'historical_cutoff',true
    );
  end if;

  select managed_player_id into v_managed
  from career_state
  where id='demo';

  for t in
    select *
    from tournaments
    where doubles=true
      and coalesce(is_active,true)=true
      and coalesce(end_date,start_date)>greatest(p_from_date,date '2025-12-01')
      and coalesce(end_date,start_date)<=p_to_date
      and coalesce(circuit,'') not in ('NCAA','Junior','Federation')
      and coalesce(category,'') not in ('United Cup','Laver Cup')
      and not exists(
        select 1
        from world_doubles_tournament_simulations s
        where s.tournament_id=tournaments.id
      )
    order by coalesce(end_date,start_date),id
    limit 80
  loop
    v_year:=extract(year from coalesce(t.end_date,t.start_date))::int;

    if not exists(
      select 1
      from world_doubles_partnerships
      where season=v_year and active=true
    ) then
      perform refresh_world_doubles_partnerships(coalesce(t.end_date,t.start_date),2000);
      v_seeded:=true;
    end if;

    v_wpts:=coalesce(
      nullif(t.winner_points,0),
      case
        when coalesce(t.category,t.level,'') ilike '%Grand%Chelem%'
          or coalesce(t.category,t.level,'') ilike '%Grand Slam%' then 2000
        when coalesce(t.category,t.level,'') ilike '%ATP Finals%' then 1500
        when coalesce(t.category,t.level,'') ilike '%Masters 1000%' then 1000
        when coalesce(t.category,t.level,'') ilike '%ATP 500%' then 500
        when coalesce(t.category,t.level,'') ilike '%ATP 250%' then 250
        when coalesce(t.category,t.level,'') ilike '%Challenger 175%' then 175
        when coalesce(t.category,t.level,'') ilike '%Challenger 125%' then 125
        when coalesce(t.category,t.level,'') ilike '%Challenger 100%' then 100
        when coalesce(t.category,t.level,'') ilike '%Challenger 75%' then 75
        when coalesce(t.category,t.level,'') ilike '%Challenger 50%' then 50
        when coalesce(t.category,t.level,'') ilike '%M25%' then 25
        when coalesce(t.category,t.level,'') ilike '%M15%' then 15
        else 50
      end
    );
    v_fpts:=greatest(1,round(v_wpts*.60)::int);
    v_draw:=greatest(4,least(64,coalesce(t.doubles_draw_size,16)));
    v_rounds:=greatest(2,ceil(ln(v_draw::numeric)/ln(2::numeric))::int);

    select
      w.*,
      (
        w.pair_strength*.30
        +w.chemistry*.16
        +w.compatibility*.14
        +least(20,coalesce(pa.doubles,10))*.18
        +least(20,coalesce(pb.doubles,10))*.18
        +least(20,coalesce(pa.net_positioning,pa.volley,10))*.10
        +least(20,coalesce(pb.net_positioning,pb.volley,10))*.10
        +least(20,coalesce(pa.doubles_communication,pa.doubles,10))*.09
        +least(20,coalesce(pb.doubles_communication,pb.doubles,10))*.09
        +least(20,coalesce(pa.big_points,pa.composure,10))*.06
        +least(20,coalesce(pb.big_points,pb.composure,10))*.06
        +coalesce(ama.serve_rating,50)*.025
        +coalesce(amb.serve_rating,50)*.025
        +coalesce(ama.return_rating,50)*.035
        +coalesce(amb.return_rating,50)*.035
        +(coalesce(era.doubles_elo,1500)+coalesce(erb.doubles_elo,1500)-3000)*.020
        +case when a.career_focus='doubles_only' then 4.0 when a.career_focus='mixed' then 1.0 else 0 end
        +case when b.career_focus='doubles_only' then 4.0 when b.career_focus='mixed' then 1.0 else 0 end
        +(coalesce(plana.doubles_bias,10)+coalesce(planb.doubles_bias,10)-20)*.12
        +case
           when coalesce(plana.preferred_surface,'')=
             case when t.surface ilike 'Terre%' then 'Terre' when t.surface ilike 'Gazon%' then 'Gazon' else 'Dur' end
             then .7 else 0 end
        +case
           when coalesce(planb.preferred_surface,'')=
             case when t.surface ilike 'Terre%' then 'Terre' when t.surface ilike 'Gazon%' then 'Gazon' else 'Dur' end
             then .7 else 0 end
        +coalesce(public.player_psychology_modifier(a.id),0)*.45+
        coalesce(public.player_psychology_modifier(b.id),0)*.45+
        random()*6
      ) as tournament_strength
    into wp
    from world_doubles_partnerships w
    join players a on a.id=w.player_a_id
    join players b on b.id=w.player_b_id
    left join player_attributes pa on pa.player_id=a.id
    left join player_attributes pb on pb.player_id=b.id
    left join player_advanced_metrics ama on ama.player_id=a.id
    left join player_advanced_metrics amb on amb.player_id=b.id
    left join player_elo_ratings era on era.player_id=a.id
    left join player_elo_ratings erb on erb.player_id=b.id
    left join player_season_plans plana on plana.player_id=a.id and plana.season=v_year
    left join player_season_plans planb on planb.player_id=b.id and planb.season=v_year
    where w.season=v_year
      and w.active=true
      and a.career_status='active'
      and b.career_status='active'
      and coalesce(a.career_focus,'mixed')<>'singles_only'
      and coalesce(b.career_focus,'mixed')<>'singles_only'
      and a.injury_status='Fit'
      and b.injury_status='Fit'
      and coalesce(a.fitness,90)>=50
      and coalesce(b.fitness,90)>=50
      and coalesce(a.fatigue,20)<=85
      and coalesce(b.fatigue,20)<=85
      and a.id<>coalesce(v_managed,-1)
      and b.id<>coalesce(v_managed,-1)
      and (
        coalesce(a.doubles_ranking,999999)+coalesce(b.doubles_ranking,999999)
        <=case
          when v_wpts>=1000 then 450
          when v_wpts>=500 then 700
          when v_wpts>=250 then 1100
          when v_wpts>=100 then 1800
          else 3500
        end
        )
      and (
        v_wpts>=250
        or (v_wpts=175 and coalesce(a.doubles_ranking,999999)+coalesce(b.doubles_ranking,999999)>=40)
        or (v_wpts=125 and coalesce(a.doubles_ranking,999999)+coalesce(b.doubles_ranking,999999)>=60)
        or (v_wpts=100 and coalesce(a.doubles_ranking,999999)+coalesce(b.doubles_ranking,999999)>=80)
        or (v_wpts=75 and coalesce(a.doubles_ranking,999999)+coalesce(b.doubles_ranking,999999)>=120)
        or (v_wpts=50 and coalesce(a.doubles_ranking,999999)+coalesce(b.doubles_ranking,999999)>=180)
        or (v_wpts=25 and coalesce(a.doubles_ranking,999999)+coalesce(b.doubles_ranking,999999)>=350)
        or (v_wpts=15 and coalesce(a.doubles_ranking,999999)+coalesce(b.doubles_ranking,999999)>=500)
      )
      and (
        coalesce(t.category,t.level,'') not ilike '%ATP Finals%'
        or coalesce(w.race_rank,999999)<=8
      )
      and not exists(
        select 1
        from world_doubles_tournament_simulations os
        join tournaments ot on ot.id=os.tournament_id
        where (os.winner_pair_id=w.id or os.finalist_pair_id=w.id)
          and daterange(ot.start_date,coalesce(ot.end_date,ot.start_date),'[]')
              && daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
      )
    order by tournament_strength desc,w.id
    limit 1;

    if wp.id is null then continue; end if;

    select
      w.*,
      (
        w.pair_strength*.30
        +w.chemistry*.16
        +w.compatibility*.14
        +least(20,coalesce(pa.doubles,10))*.18
        +least(20,coalesce(pb.doubles,10))*.18
        +least(20,coalesce(pa.net_positioning,pa.volley,10))*.10
        +least(20,coalesce(pb.net_positioning,pb.volley,10))*.10
        +least(20,coalesce(pa.doubles_communication,pa.doubles,10))*.09
        +least(20,coalesce(pb.doubles_communication,pb.doubles,10))*.09
        +least(20,coalesce(pa.big_points,pa.composure,10))*.06
        +least(20,coalesce(pb.big_points,pb.composure,10))*.06
        +coalesce(ama.serve_rating,50)*.025
        +coalesce(amb.serve_rating,50)*.025
        +coalesce(ama.return_rating,50)*.035
        +coalesce(amb.return_rating,50)*.035
        +(coalesce(era.doubles_elo,1500)+coalesce(erb.doubles_elo,1500)-3000)*.020
        +case when a.career_focus='doubles_only' then 4.0 when a.career_focus='mixed' then 1.0 else 0 end
        +case when b.career_focus='doubles_only' then 4.0 when b.career_focus='mixed' then 1.0 else 0 end
        +(coalesce(plana.doubles_bias,10)+coalesce(planb.doubles_bias,10)-20)*.12
        +case
           when coalesce(plana.preferred_surface,'')=
             case when t.surface ilike 'Terre%' then 'Terre' when t.surface ilike 'Gazon%' then 'Gazon' else 'Dur' end
             then .7 else 0 end
        +case
           when coalesce(planb.preferred_surface,'')=
             case when t.surface ilike 'Terre%' then 'Terre' when t.surface ilike 'Gazon%' then 'Gazon' else 'Dur' end
             then .7 else 0 end
        +coalesce(public.player_psychology_modifier(a.id),0)*.45+
        coalesce(public.player_psychology_modifier(b.id),0)*.45+
        random()*6
      ) as tournament_strength
    into fp
    from world_doubles_partnerships w
    join players a on a.id=w.player_a_id
    join players b on b.id=w.player_b_id
    left join player_attributes pa on pa.player_id=a.id
    left join player_attributes pb on pb.player_id=b.id
    left join player_advanced_metrics ama on ama.player_id=a.id
    left join player_advanced_metrics amb on amb.player_id=b.id
    left join player_elo_ratings era on era.player_id=a.id
    left join player_elo_ratings erb on erb.player_id=b.id
    left join player_season_plans plana on plana.player_id=a.id and plana.season=v_year
    left join player_season_plans planb on planb.player_id=b.id and planb.season=v_year
    where w.season=v_year
      and w.active=true
      and w.id<>wp.id
      and a.career_status='active'
      and b.career_status='active'
      and coalesce(a.career_focus,'mixed')<>'singles_only'
      and coalesce(b.career_focus,'mixed')<>'singles_only'
      and a.injury_status='Fit'
      and b.injury_status='Fit'
      and coalesce(a.fitness,90)>=50
      and coalesce(b.fitness,90)>=50
      and coalesce(a.fatigue,20)<=85
      and coalesce(b.fatigue,20)<=85
      and a.id<>coalesce(v_managed,-1)
      and b.id<>coalesce(v_managed,-1)
      and (
        coalesce(a.doubles_ranking,999999)+coalesce(b.doubles_ranking,999999)
        <=case
          when v_wpts>=1000 then 550
          when v_wpts>=500 then 850
          when v_wpts>=250 then 1250
          when v_wpts>=100 then 2000
          else 3800
        end
        )
      and (
        v_wpts>=250
        or (v_wpts=175 and coalesce(a.doubles_ranking,999999)+coalesce(b.doubles_ranking,999999)>=40)
        or (v_wpts=125 and coalesce(a.doubles_ranking,999999)+coalesce(b.doubles_ranking,999999)>=60)
        or (v_wpts=100 and coalesce(a.doubles_ranking,999999)+coalesce(b.doubles_ranking,999999)>=80)
        or (v_wpts=75 and coalesce(a.doubles_ranking,999999)+coalesce(b.doubles_ranking,999999)>=120)
        or (v_wpts=50 and coalesce(a.doubles_ranking,999999)+coalesce(b.doubles_ranking,999999)>=180)
        or (v_wpts=25 and coalesce(a.doubles_ranking,999999)+coalesce(b.doubles_ranking,999999)>=350)
        or (v_wpts=15 and coalesce(a.doubles_ranking,999999)+coalesce(b.doubles_ranking,999999)>=500)
      )
      and (
        coalesce(t.category,t.level,'') not ilike '%ATP Finals%'
        or coalesce(w.race_rank,999999)<=8
      )
      and not exists(
        select 1
        from world_doubles_tournament_simulations os
        join tournaments ot on ot.id=os.tournament_id
        where (os.winner_pair_id=w.id or os.finalist_pair_id=w.id)
          and daterange(ot.start_date,coalesce(ot.end_date,ot.start_date),'[]')
              && daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
      )
    order by tournament_strength desc,w.id
    limit 1;

    if fp.id is null then continue; end if;

    v_pair_match:=public.doubles_pair_matchup_v2(
      wp.id,fp.id,t.surface,coalesce(t.end_date,t.start_date)
    );
    v_pair_prob:=coalesce((v_pair_match->>'pair_a_probability')::numeric,.5);

    if random()>v_pair_prob then
      v_pair_tmp:=wp;
      wp:=fp;
      fp:=v_pair_tmp;
      v_pair_prob:=1-v_pair_prob;
    end if;

    select * into wa from players where id=wp.player_a_id;
    select * into wb from players where id=wp.player_b_id;
    select * into fa from players where id=fp.player_a_id;
    select * into fb from players where id=fp.player_b_id;

    insert into world_doubles_tournament_simulations(
      tournament_id,season,winner_pair_id,finalist_pair_id,
      winner_points,finalist_points,draw_size,simulated_on,
      final_win_probability,model_version,matchup_components
    )
    values(
      t.id,v_year,wp.id,fp.id,v_wpts,v_fpts,v_draw,
      coalesce(t.end_date,t.start_date),
      round(v_pair_prob,4),'CB-DOUBLES-v2',coalesce(v_pair_match->'components','{}'::jsonb)
    );

    update world_doubles_partnerships
    set
      matches=matches+v_rounds,
      wins=wins+v_rounds,
      titles=titles+1,
      race_points=race_points+v_wpts,
      last_refresh_date=greatest(last_refresh_date,coalesce(t.end_date,t.start_date))
    where id=wp.id;

    update world_doubles_partnerships
    set
      matches=matches+v_rounds,
      wins=wins+greatest(0,v_rounds-1),
      race_points=race_points+v_fpts,
      last_refresh_date=greatest(last_refresh_date,coalesce(t.end_date,t.start_date))
    where id=fp.id;

    update players
    set
      doubles_points=greatest(0,coalesce(doubles_points,0)+v_wpts),
      doubles_snapshot_date=coalesce(t.end_date,t.start_date),
      doubles_source='Court Boss doubles tournament simulation',
      form=least(100,form+3),
      morale=least(100,morale+4),
      fatigue=least(100,fatigue+6)
    where id in (wp.player_a_id,wp.player_b_id);

    update players
    set
      doubles_points=greatest(0,coalesce(doubles_points,0)+v_fpts),
      doubles_snapshot_date=coalesce(t.end_date,t.start_date),
      doubles_source='Court Boss doubles tournament simulation',
      form=least(100,form+1),
      morale=least(100,morale+2),
      fatigue=least(100,fatigue+5)
    where id in (fp.player_a_id,fp.player_b_id);

    insert into player_titles(
      player_id,tournament_name,title_date,level,surface,event_type,
      partner_player_id,partner_name,verified,source_label,origin,date_precision
    )
    values(
      wa.id,t.name,coalesce(t.end_date,t.start_date),coalesce(t.category,t.level,t.circuit),
      t.surface,'doubles',wb.id,wb.name,false,'Court Boss · double mondial simulé','game','day'
    )
    returning id into v_title_a;
    perform credit_staff_title(v_title_a);

    insert into player_titles(
      player_id,tournament_name,title_date,level,surface,event_type,
      partner_player_id,partner_name,verified,source_label,origin,date_precision
    )
    values(
      wb.id,t.name,coalesce(t.end_date,t.start_date),coalesce(t.category,t.level,t.circuit),
      t.surface,'doubles',wa.id,wa.name,false,'Court Boss · double mondial simulé','game','day'
    )
    returning id into v_title_b;
    perform credit_staff_title(v_title_b);

    insert into player_final_results(
      player_id,tournament_name,final_date,level,surface,result,opponent_name,
      source,event_type,partner_player_id,partner_name
    )
    values
      (
        wa.id,t.name,coalesce(t.end_date,t.start_date),coalesce(t.category,t.level,t.circuit),t.surface,
        'Champion',fa.name||' / '||fb.name,'Court Boss doubles simulation','doubles',wb.id,wb.name
      ),
      (
        wb.id,t.name,coalesce(t.end_date,t.start_date),coalesce(t.category,t.level,t.circuit),t.surface,
        'Champion',fa.name||' / '||fb.name,'Court Boss doubles simulation','doubles',wa.id,wa.name
      ),
      (
        fa.id,t.name,coalesce(t.end_date,t.start_date),coalesce(t.category,t.level,t.circuit),t.surface,
        'Finaliste',wa.name||' / '||wb.name,'Court Boss doubles simulation','doubles',fb.id,fb.name
      ),
      (
        fb.id,t.name,coalesce(t.end_date,t.start_date),coalesce(t.category,t.level,t.circuit),t.surface,
        'Finaliste',wa.name||' / '||wb.name,'Court Boss doubles simulation','doubles',fa.id,fa.name
      );

    perform update_player_elo_after_match(
      wa.id,fa.id,t.surface,coalesce(t.end_date,t.start_date),true,
      case when v_wpts>=2000 then 1.30 when v_wpts>=1000 then 1.15 when v_wpts>=500 then 1.08 else 1 end
    );
    perform update_player_elo_after_match(
      wb.id,fb.id,t.surface,coalesce(t.end_date,t.start_date),true,
      case when v_wpts>=2000 then 1.30 when v_wpts>=1000 then 1.15 when v_wpts>=500 then 1.08 else 1 end
    );

    v_simulated:=v_simulated+1;
  end loop;

  with ranked as (
    select
      p.id,
      row_number() over(
        order by coalesce(p.doubles_points,0) desc,
                 coalesce(pa.doubles,10) desc,
                 coalesce(p.current_ability,50) desc,
                 p.id
      )::int as rr
    from players p
    left join player_attributes pa on pa.player_id=p.id
    where p.career_status='active'
      and coalesce(p.doubles_points,0)>0
      and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
  )
  update players p
  set
    doubles_ranking=r.rr,
    doubles_snapshot_date=p_to_date,
    doubles_source=case
      when p.id=coalesce(v_managed,-1) then p.doubles_source
      else 'Court Boss dynamic doubles season'
    end,
    career_high_doubles_rank=case
      when p.career_high_doubles_rank is null or r.rr<p.career_high_doubles_rank then r.rr
      else p.career_high_doubles_rank
    end,
    career_high_doubles_rank_date=case
      when p.career_high_doubles_rank is null or r.rr<p.career_high_doubles_rank then p_to_date
      else p.career_high_doubles_rank_date
    end,
    career_high_doubles_source=case
      when p.career_high_doubles_rank is null or r.rr<p.career_high_doubles_rank then 'Court Boss simulation'
      else p.career_high_doubles_source
    end
  from ranked r
  where p.id=r.id
    and p.id<>coalesce(v_managed,-1);

  with ranked as (
    select
      id,
      row_number() over(
        order by race_points desc,pair_strength desc,affinity_score desc,id
      )::int as rr
    from world_doubles_partnerships
    where season=extract(year from p_to_date)::int and active=true
  )
  update world_doubles_partnerships w
  set race_rank=r.rr
  from ranked r
  where w.id=r.id;

  return jsonb_build_object(
    'tournaments_simulated',v_simulated,
    'from',p_from_date,
    'to',p_to_date,
    'pairs_seeded',v_seeded,
    'titles_created',v_simulated*2,
    'match_model','CB-DOUBLES-v2'
  );
end;
$function$
