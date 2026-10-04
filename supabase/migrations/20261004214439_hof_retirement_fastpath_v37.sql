CREATE OR REPLACE FUNCTION public.court_boss_hof_register_retirement(p_player_id bigint, p_retired_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  p public.players%rowtype;
  l record;
  v_eligibility integer;
  v_speech text;
  v_publish boolean:=false;
begin
  select * into p from public.players where id=p_player_id;
  if p.id is null or p_retired_date is null then
    return jsonb_build_object('ok',false,'reason','player_or_date_missing');
  end if;

  with
  ft as (
    select
      count(*)::bigint titles,
      count(*) filter(where public.cb_record_event_key(pt.tournament_name) in
        ('australian_open','roland_garros','wimbledon','us_open'))::bigint slams,
      count(*) filter(where coalesce(pt.level,'') ilike '%1000%')::bigint masters,
      count(*) filter(where
        coalesce(pt.level,'') ilike '%ATP Finals%'
        or lower(coalesce(pt.tournament_name,'')) like '%tour finals%'
        or lower(coalesce(pt.tournament_name,'')) like '%atp finals%'
        or lower(coalesce(pt.tournament_name,'')) like '%masters cup%'
      )::bigint finals
    from public.player_titles pt
    where pt.player_id=p_player_id
      and pt.event_type='singles'
      and pt.title_date>date '2025-12-01'
      and pt.title_date<=p_retired_date
  ),
  fs as (
    select
      count(*) filter(where s.won)::bigint wins,
      count(*) filter(where not s.won)::bigint losses
    from public.court_boss_match_stat_lines s
    where s.player_id=p_player_id
      and s.match_date>date '2025-12-01'
      and s.match_date<=p_retired_date
  ),
  fn as (
    select count(*)::bigint weeks_no1
    from public.ranking_history rh
    where rh.player_id=p_player_id
      and rh.snapshot_date>date '2025-12-01'
      and rh.snapshot_date<=p_retired_date
      and rh.ranking=1
  ),
  fa as (
    select count(*) filter(
      where a.award_code='player_of_year' and a.award_rank=1
    )::bigint poy
    from public.court_boss_player_awards a
    where a.player_id=p_player_id
      and a.season>2025
      and a.season<=extract(year from p_retired_date)::int
  ),
  hp as (
    select count(*)::bigint poy
    from public.court_boss_year_end_no1_reference y
    where y.season<=least(2025,extract(year from p_retired_date)::int)
      and lower(y.player_name)=lower(p.name)
  ),
  one_player as (
    select
      (coalesce(h.titles,0)+coalesce(ft.titles,0))::bigint titles,
      (coalesce(h.grand_slams,0)+coalesce(ft.slams,0))::bigint grand_slams,
      (coalesce(h.masters,0)+coalesce(ft.masters,0))::bigint masters,
      (coalesce(h.tour_finals,0)+coalesce(ft.finals,0))::bigint tour_finals,
      (greatest(coalesce(h.wins,0),coalesce(pcs.wins,0))+coalesce(fs.wins,0))::bigint wins,
      (greatest(coalesce(h.losses,0),coalesce(pcs.losses,0))+coalesce(fs.losses,0))::bigint losses,
      (coalesce(p.weeks_at_no1,0)+coalesce(fn.weeks_no1,0))::bigint weeks_no1,
      (coalesce(hp.poy,0)+coalesce(fa.poy,0))::bigint player_of_year
    from public.players px
    left join public.history_player_scores h on h.id=px.id
    left join public.player_career_stats pcs on pcs.player_id=px.id
    cross join ft cross join fs cross join fn cross join fa cross join hp
    where px.id=p_player_id
  )
  select
    null::bigint as all_time_rank,
    o.titles,o.grand_slams,o.masters,o.tour_finals,o.wins,o.losses,o.weeks_no1,o.player_of_year,
    (
      o.grand_slams*10000
      +o.tour_finals*2200
      +o.masters*1200
      +greatest(o.titles-o.grand_slams-o.masters-o.tour_finals,0)*180
      +o.wins*2
      +o.weeks_no1*8
      +o.player_of_year*1500
    )::bigint as legacy_score
  into l
  from one_player o;

  if l.legacy_score is null then
    select
      null::bigint as all_time_rank,
      0::bigint as titles,0::bigint as grand_slams,0::bigint as masters,0::bigint as tour_finals,
      0::bigint as wins,0::bigint as losses,0::bigint as weeks_no1,0::bigint as player_of_year,
      0::bigint as legacy_score
    into l;
  end if;

  v_eligibility:=extract(year from p_retired_date)::int+5;

  v_speech:='Après '||coalesce(l.titles,0)||' titres'
    ||case when coalesce(l.grand_slams,0)>0 then ', '||l.grand_slams||' Majeur'||case when l.grand_slams>1 then 's' else '' end else '' end
    ||' et '||coalesce(l.wins,0)||' victoires, '||p.name
    ||' referme sa carrière professionnelle. '
    ||case when coalesce(l.weeks_no1,0)>0 then 'Son passage au sommet pendant '||l.weeks_no1||' semaines restera une partie centrale de son héritage. '
      else 'Son héritage sera désormais jugé sur l’ensemble de son parcours. ' end
    ||'Première année d’éligibilité au Hall of Fame : '||v_eligibility||'.';

  insert into public.court_boss_hof_profiles(
    player_id,retired_date,eligibility_year,status,hof_score,
    retirement_ceremony_on,retirement_speech,metadata,updated_at
  ) values(
    p_player_id,p_retired_date,v_eligibility,'waiting',coalesce(l.legacy_score,0),
    p_retired_date,v_speech,
    jsonb_build_object(
      'legacy_rank_at_retirement',null,
      'legacy_score_at_retirement',l.legacy_score,
      'titles',l.titles,'grand_slams',l.grand_slams,'masters',l.masters,
      'tour_finals',l.tour_finals,'wins',l.wins,'weeks_no1',l.weeks_no1,
      'rank_deferred_to_hof_cycle',true
    ),now()
  )
  on conflict(player_id) do update set
    retired_date=excluded.retired_date,
    eligibility_year=excluded.eligibility_year,
    hof_score=greatest(public.court_boss_hof_profiles.hof_score,excluded.hof_score),
    retirement_ceremony_on=coalesce(public.court_boss_hof_profiles.retirement_ceremony_on,excluded.retirement_ceremony_on),
    retirement_speech=coalesce(public.court_boss_hof_profiles.retirement_speech,excluded.retirement_speech),
    metadata=public.court_boss_hof_profiles.metadata||excluded.metadata,
    updated_at=now();

  insert into public.court_boss_retirement_ceremonies(
    player_id,retirement_date,ceremony_date,player_name,country,
    legacy_rank,legacy_score,titles,grand_slams,masters,tour_finals,wins,weeks_no1,
    eligibility_year,speech,metadata,updated_at
  ) values(
    p_player_id,p_retired_date,p_retired_date,p.name,p.country,
    null,l.legacy_score,coalesce(l.titles,0),coalesce(l.grand_slams,0),
    coalesce(l.masters,0),coalesce(l.tour_finals,0),coalesce(l.wins,0),coalesce(l.weeks_no1,0),
    v_eligibility,v_speech,
    jsonb_build_object(
      'career_status','retired',
      'retirement_reason',p.retirement_reason,
      'rank_deferred_to_hof_cycle',true
    ),
    now()
  )
  on conflict(player_id) do update set
    retirement_date=excluded.retirement_date,ceremony_date=excluded.ceremony_date,
    legacy_score=excluded.legacy_score,
    titles=excluded.titles,grand_slams=excluded.grand_slams,masters=excluded.masters,
    tour_finals=excluded.tour_finals,wins=excluded.wins,weeks_no1=excluded.weeks_no1,
    eligibility_year=excluded.eligibility_year,speech=excluded.speech,
    metadata=public.court_boss_retirement_ceremonies.metadata||excluded.metadata,updated_at=now();

  v_publish:=coalesce(l.grand_slams,0)>0
    or coalesce(l.titles,0)>=10
    or coalesce(l.weeks_no1,0)>0
    or coalesce(l.wins,0)>=400;

  if v_publish then
    if public.court_boss_publish_world_story(
      'retirement:'||p_player_id,
      p_retired_date,p_player_id,'retirement',
      p.name||' met un terme à sa carrière après '||coalesce(l.titles,0)||' titres'
        ||case when coalesce(l.grand_slams,0)>0 then ', dont '||l.grand_slams||' en Grand Chelem' else '' end
        ||'. Il pourra être considéré pour le Hall of Fame à partir de '||v_eligibility||'.',
      jsonb_build_object(
        'legacy_rank',null,'legacy_score',l.legacy_score,
        'titles',l.titles,'grand_slams',l.grand_slams,'wins',l.wins,
        'eligibility_year',v_eligibility,'speech',v_speech,
        'rank_deferred_to_hof_cycle',true
      )
    ) then
      update public.court_boss_retirement_ceremonies
      set world_news_published=true,updated_at=now()
      where player_id=p_player_id;
    end if;
  end if;

  return jsonb_build_object(
    'ok',true,'player_id',p_player_id,'retired_date',p_retired_date,
    'eligibility_year',v_eligibility,'published',v_publish,
    'rank_deferred_to_hof_cycle',true,
    'model','CB-HOF-RETIREMENT-v2-fast'
  );
end;
$function$;
