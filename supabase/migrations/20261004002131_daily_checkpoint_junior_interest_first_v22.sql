-- V22 checkpoint performance: reject uninterested junior candidates before
-- invoking the expensive cross-circuit calendar arbiter.
CREATE OR REPLACE FUNCTION public.junior_event_decision_v19(p_player_id bigint, p_tournament_id bigint, p_discipline text DEFAULT 'singles'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  p public.players%rowtype;
  t public.tournaments%rowtype;
  discipline text:=lower(coalesce(p_discipline,'singles'));
  elig jsonb;
  r int;
  v_age int;
  v_prob numeric:=50;
  v_priority numeric:=0;
  v_roll numeric;
  v_raw boolean;
begin
  select * into p from public.players where id=p_player_id;
  select * into t from public.tournaments where id=p_tournament_id;
  if p.id is null or t.id is null or t.circuit<>'Junior' or not coalesce(t.is_active,true) then
    return jsonb_build_object('eligible',false,'raw_interest',false,'reason','missing_or_not_junior');
  end if;

  -- Cheap junior eligibility first. Calendar conflict is intentionally deferred
  -- until after deterministic interest so thousands of uninterested candidates
  -- do not execute the cross-circuit conflict arbiter.
  if coalesce(p.career_status,'active')<>'active' then
    return jsonb_build_object('eligible',false,'raw_interest',false,'reason','inactive_player','probability',0,'priority_score',0,'model','CB-JUNIOR-ENTRY-v22');
  end if;

  v_age:=coalesce(
    case when p.birth_date is not null then extract(year from age(t.start_date,p.birth_date))::int end,
    p.age,99
  );
  if v_age<13 or v_age>18 then
    return jsonb_build_object('eligible',false,'raw_interest',false,'reason','junior_age_ineligible','age',v_age,'probability',0,'priority_score',0,'model','CB-JUNIOR-ENTRY-v22');
  end if;
  if discipline='doubles' and coalesce(p.career_focus,'mixed')='singles_only' then
    return jsonb_build_object('eligible',false,'raw_interest',false,'reason','singles_only','probability',0,'priority_score',0,'model','CB-JUNIOR-ENTRY-v22');
  end if;
  if discipline<>'doubles' and coalesce(p.career_focus,'mixed')='doubles_only' then
    return jsonb_build_object('eligible',false,'raw_interest',false,'reason','doubles_only','probability',0,'priority_score',0,'model','CB-JUNIOR-ENTRY-v22');
  end if;
  r:=case when discipline='doubles'
    then coalesce(p.junior_doubles_ranking,p.junior_ranking,999999)
    else coalesce(p.junior_ranking,999999) end;

  v_prob:=case t.category
    when 'Junior Grand Slam' then case when r<=25 then 98 when r<=75 then 92 when r<=150 then 72 when r<=300 then 38 else 8 end
    when 'J500' then case when r<=20 then 96 when r<=75 then 89 when r<=175 then 64 when r<=400 then 30 else 6 end
    when 'J300' then case when r<=20 then 78 when r<=100 then 92 when r<=250 then 76 when r<=550 then 40 else 9 end
    when 'J200' then case when r<=20 then 25 when r<=100 then 68 when r<=300 then 90 when r<=650 then 58 else 16 end
    when 'J100' then case when r<=20 then 5 when r<=100 then 24 when r<=300 then 68 when r<=800 then 90 else 48 end
    when 'J60' then case when r<=20 then 1 when r<=100 then 6 when r<=300 then 30 when r<=800 then 80 else 86 end
    when 'J30' then case when r<=20 then .3 when r<=100 then 2 when r<=300 then 10 when r<=800 then 54 else 94 end
    else 50 end;

  v_priority:=case t.category
    when 'Junior Grand Slam' then 900
    when 'J500' then 800
    when 'J300' then 700
    when 'J200' then 600
    when 'J100' then 500
    when 'J60' then 400
    when 'J30' then 300
    else 350 end;

  if p.country is not null and t.country is not null and p.country=t.country then
    v_prob:=v_prob+12;
    v_priority:=v_priority+30;
  end if;

  if v_age<=14 then
    v_prob:=v_prob+case
      when t.category in ('J30','J60','J100') then 10
      when t.category in ('J500','Junior Grand Slam') then -20
      else 0 end;
  elsif v_age>=17 and r<=150 then
    v_prob:=v_prob+case
      when t.category in ('J300','J500','Junior Grand Slam') then 8
      when t.category in ('J30','J60') then -10
      else 0 end;
  end if;

  -- Strong pro juniors naturally graduate out of low-grade junior events.
  if coalesce(p.ranking,999999)<=100 then
    v_prob:=v_prob-case
      when t.category='Junior Grand Slam' then 68
      when t.category='J500' then 84
      else 97 end;
  elsif coalesce(p.ranking,999999)<=250 then
    v_prob:=v_prob-case
      when t.category='Junior Grand Slam' then 42
      when t.category='J500' then 58
      when t.category='J300' then 70
      else 90 end;
  elsif coalesce(p.ranking,999999)<=500 then
    v_prob:=v_prob-case
      when t.category='Junior Grand Slam' then 18
      when t.category='J500' then 24
      when t.category='J300' then 34
      when t.category='J200' then 54
      else 74 end;
  end if;

  if discipline='doubles' then
    v_prob:=v_prob+case
      when coalesce(p.career_focus,'mixed')='singles_only' then -100
      when coalesce(p.career_focus,'mixed')='doubles_only' then 18
      when coalesce(p.career_focus,'mixed')='mixed' then 6
      else 0 end;
  end if;

  -- Fatigue affects preference, not junior eligibility.
  if coalesce(p.fatigue,20)>=72 then v_prob:=v_prob-10; end if;
  if coalesce(p.fatigue,20)>=84 then v_prob:=v_prob-10; end if;

  v_prob:=greatest(.2,least(99,v_prob));
  v_roll:=mod(abs(hashtext('junior-entry-v19|'||t.id||'|'||p.id||'|'||discipline)),10000)/100.0;
  v_raw:=v_roll<v_prob;

  if not v_raw then
    return jsonb_build_object(
      'eligible',true,'raw_interest',false,'probability',round(v_prob,2),
      'roll',round(v_roll,2),'priority_score',v_priority,
      'junior_rank',r,'age',v_age,'reason','not_interested','model','CB-JUNIOR-ENTRY-v22'
    );
  end if;

  elig:=public.player_event_eligibility(
    p.id,t.id,
    case when discipline='doubles' then 'junior_doubles' else 'junior_singles' end,
    'direct'
  );
  if not coalesce((elig->>'eligible')::boolean,false) then
    return elig || jsonb_build_object(
      'raw_interest',true,'probability',round(v_prob,2),'roll',round(v_roll,2),
      'priority_score',v_priority,'junior_rank',r,'age',v_age,'model','CB-JUNIOR-ENTRY-v22'
    );
  end if;

  return jsonb_build_object(
    'eligible',true,'raw_interest',true,'probability',round(v_prob,2),
    'roll',round(v_roll,2),'priority_score',v_priority,
    'junior_rank',r,'age',v_age,'model','CB-JUNIOR-ENTRY-v22'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.junior_player_commits_to_event(p_player_id bigint, p_tournament_id bigint, p_discipline text DEFAULT 'singles'::text)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  d jsonb;
  discipline text:=lower(coalesce(p_discipline,'singles'));
  v_priority numeric;
  v_week date;
  v_better boolean:=false;
  v_country text;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null or t.circuit<>'Junior' or not coalesce(t.is_active,true) then return false; end if;

  d:=public.junior_event_decision_v19(p_player_id,p_tournament_id,discipline);
  if not coalesce((d->>'eligible')::boolean,false)
     or not coalesce((d->>'raw_interest')::boolean,false) then return false; end if;

  v_priority:=coalesce((d->>'priority_score')::numeric,0);
  v_week:=date_trunc('week',coalesce(t.main_draw_start_date,t.start_date)::timestamp)::date;
  select country into v_country from public.players where id=p_player_id;

  -- ITF juniors may submit multiple entries, but after withdrawal deadlines they
  -- can remain accepted in only one event for the week. Reservations represent
  -- that final accepted choice.
  select exists(
    select 1
    from (
      select x.id
      from public.tournaments x
      where x.id<>t.id
        and x.circuit='Junior'
        and coalesce(x.is_active,true)
        and coalesce(x.main_draw_start_date,x.start_date) between v_week and v_week+6
        and (
          (
            case x.category
              when 'Junior Grand Slam' then 900
              when 'J500' then 800
              when 'J300' then 700
              when 'J200' then 600
              when 'J100' then 500
              when 'J60' then 400
              when 'J30' then 300
              else 350
            end
            +case when v_country is not null and x.country=v_country then 30 else 0 end
          )>v_priority
          or (
            (
              case x.category
                when 'Junior Grand Slam' then 900
                when 'J500' then 800
                when 'J300' then 700
                when 'J200' then 600
                when 'J100' then 500
                when 'J60' then 400
                when 'J30' then 300
                else 350
              end
              +case when v_country is not null and x.country=v_country then 30 else 0 end
            )=v_priority
            and x.id<t.id
          )
        )
    ) ot
    cross join lateral (
      select public.junior_event_decision_v19(p_player_id,ot.id,discipline) j
    ) od
    where true
      and coalesce((od.j->>'eligible')::boolean,false)
      and coalesce((od.j->>'raw_interest')::boolean,false)
      and (
        coalesce((od.j->>'priority_score')::numeric,0)>v_priority
        or (
          coalesce((od.j->>'priority_score')::numeric,0)=v_priority
          and ot.id<t.id
        )
      )
  ) into v_better;

  return not v_better;
end;
$function$;
