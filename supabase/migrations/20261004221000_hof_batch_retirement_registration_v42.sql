
CREATE OR REPLACE FUNCTION public.court_boss_hof_register_retirements_batch(p_retired_date date)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
declare
  v_registered integer:=0;
  r record;
begin
  if p_retired_date is null then
    return jsonb_build_object('ok',false,'reason','retired_date_missing');
  end if;

  with target as (
    select p.id,p.name,p.country,p.retirement_reason,p.retired_date,
           coalesce(p.weeks_at_no1,0)::bigint base_weeks_no1
    from public.players p
    where lower(coalesce(p.career_status,''))='retired'
      and p.retired_date=p_retired_date
      and not exists(
        select 1 from public.court_boss_hof_profiles hp where hp.player_id=p.id
      )
  ),
  ft as (
    select pt.player_id,
      count(*)::bigint titles,
      count(*) filter(where public.cb_record_event_key(pt.tournament_name) in
        ('australian_open','roland_garros','wimbledon','us_open'))::bigint grand_slams,
      count(*) filter(where coalesce(pt.level,'') ilike '%1000%')::bigint masters,
      count(*) filter(where
        coalesce(pt.level,'') ilike '%ATP Finals%'
        or lower(coalesce(pt.tournament_name,'')) like '%tour finals%'
        or lower(coalesce(pt.tournament_name,'')) like '%atp finals%'
        or lower(coalesce(pt.tournament_name,'')) like '%masters cup%'
      )::bigint tour_finals
    from public.player_titles pt
    join target t on t.id=pt.player_id
    where pt.event_type='singles'
      and pt.title_date>date '2025-12-01'
      and pt.title_date<=p_retired_date
    group by pt.player_id
  ),
  fs as (
    select s.player_id,
      count(*) filter(where s.won)::bigint wins,
      count(*) filter(where not s.won)::bigint losses
    from public.court_boss_match_stat_lines s
    join target t on t.id=s.player_id
    where s.match_date>date '2025-12-01'
      and s.match_date<=p_retired_date
    group by s.player_id
  ),
  fn as (
    select rh.player_id,count(*)::bigint weeks_no1
    from public.ranking_history rh
    join target t on t.id=rh.player_id
    where rh.snapshot_date>date '2025-12-01'
      and rh.snapshot_date<=p_retired_date
      and rh.ranking=1
    group by rh.player_id
  ),
  fa as (
    select a.player_id,
      count(*) filter(where a.award_code='player_of_year' and a.award_rank=1)::bigint player_of_year
    from public.court_boss_player_awards a
    join target t on t.id=a.player_id
    where a.season>2025
      and a.season<=extract(year from p_retired_date)::int
    group by a.player_id
  ),
  hp as (
    select t.id player_id,count(y.season)::bigint player_of_year
    from target t
    join public.court_boss_year_end_no1_reference y on lower(y.player_name)=lower(t.name)
    where y.season<=least(2025,extract(year from p_retired_date)::int)
    group by t.id
  ),
  scored0 as (
    select
      t.id player_id,t.name,t.country,t.retirement_reason,t.retired_date,
      (coalesce(h.titles,0)+coalesce(ft.titles,0))::bigint titles,
      (coalesce(h.grand_slams,0)+coalesce(ft.grand_slams,0))::bigint grand_slams,
      (coalesce(h.masters,0)+coalesce(ft.masters,0))::bigint masters,
      (coalesce(h.tour_finals,0)+coalesce(ft.tour_finals,0))::bigint tour_finals,
      (greatest(coalesce(h.wins,0),coalesce(pcs.wins,0))+coalesce(fs.wins,0))::bigint wins,
      (greatest(coalesce(h.losses,0),coalesce(pcs.losses,0))+coalesce(fs.losses,0))::bigint losses,
      (t.base_weeks_no1+coalesce(fn.weeks_no1,0))::bigint weeks_no1,
      (coalesce(hp.player_of_year,0)+coalesce(fa.player_of_year,0))::bigint player_of_year
    from target t
    left join public.history_player_scores h on h.id=t.id
    left join public.player_career_stats pcs on pcs.player_id=t.id
    left join ft on ft.player_id=t.id
    left join fs on fs.player_id=t.id
    left join fn on fn.player_id=t.id
    left join fa on fa.player_id=t.id
    left join hp on hp.player_id=t.id
  ),
  scored as (
    select s.*,
      (
        s.grand_slams*10000
        +s.tour_finals*2200
        +s.masters*1200
        +greatest(s.titles-s.grand_slams-s.masters-s.tour_finals,0)*180
        +s.wins*2
        +s.weeks_no1*8
        +s.player_of_year*1500
      )::bigint legacy_score,
      extract(year from s.retired_date)::int+5 eligibility_year,
      (
        'Après '||s.titles||' titres'
        ||case when s.grand_slams>0 then ', '||s.grand_slams||' Majeur'||case when s.grand_slams>1 then 's' else '' end else '' end
        ||' et '||s.wins||' victoires, '||s.name
        ||' referme sa carrière professionnelle. '
        ||case when s.weeks_no1>0
          then 'Son passage au sommet pendant '||s.weeks_no1||' semaines restera une partie centrale de son héritage. '
          else 'Son héritage sera désormais jugé sur l’ensemble de son parcours. ' end
        ||'Première année d’éligibilité au Hall of Fame : '
        ||(extract(year from s.retired_date)::int+5)||'.'
      )::text speech
    from scored0 s
  ),
  profile_upsert as (
    insert into public.court_boss_hof_profiles(
      player_id,retired_date,eligibility_year,status,hof_score,
      retirement_ceremony_on,retirement_speech,metadata,updated_at
    )
    select
      s.player_id,s.retired_date,s.eligibility_year,'waiting',s.legacy_score,
      s.retired_date,s.speech,
      jsonb_build_object(
        'legacy_rank_at_retirement',null,
        'legacy_score_at_retirement',s.legacy_score,
        'titles',s.titles,'grand_slams',s.grand_slams,'masters',s.masters,
        'tour_finals',s.tour_finals,'wins',s.wins,'weeks_no1',s.weeks_no1,
        'rank_deferred_to_hof_cycle',true,
        'batch_registration',true
      ),now()
    from scored s
    on conflict(player_id) do update set
      retired_date=excluded.retired_date,
      eligibility_year=excluded.eligibility_year,
      hof_score=greatest(public.court_boss_hof_profiles.hof_score,excluded.hof_score),
      retirement_ceremony_on=coalesce(public.court_boss_hof_profiles.retirement_ceremony_on,excluded.retirement_ceremony_on),
      retirement_speech=coalesce(public.court_boss_hof_profiles.retirement_speech,excluded.retirement_speech),
      metadata=public.court_boss_hof_profiles.metadata||excluded.metadata,
      updated_at=now()
    returning player_id
  )
  insert into public.court_boss_retirement_ceremonies(
    player_id,retirement_date,ceremony_date,player_name,country,
    legacy_rank,legacy_score,titles,grand_slams,masters,tour_finals,wins,weeks_no1,
    eligibility_year,speech,metadata,updated_at
  )
  select
    s.player_id,s.retired_date,s.retired_date,s.name,s.country,
    null,s.legacy_score,s.titles,s.grand_slams,s.masters,s.tour_finals,s.wins,s.weeks_no1,
    s.eligibility_year,s.speech,
    jsonb_build_object(
      'career_status','retired',
      'retirement_reason',s.retirement_reason,
      'rank_deferred_to_hof_cycle',true,
      'batch_registration',true
    ),
    now()
  from scored s
  join profile_upsert u on u.player_id=s.player_id
  on conflict(player_id) do update set
    retirement_date=excluded.retirement_date,
    ceremony_date=excluded.ceremony_date,
    legacy_score=excluded.legacy_score,
    titles=excluded.titles,
    grand_slams=excluded.grand_slams,
    masters=excluded.masters,
    tour_finals=excluded.tour_finals,
    wins=excluded.wins,
    weeks_no1=excluded.weeks_no1,
    eligibility_year=excluded.eligibility_year,
    speech=excluded.speech,
    metadata=public.court_boss_retirement_ceremonies.metadata||excluded.metadata,
    updated_at=now();

  get diagnostics v_registered=row_count;

  for r in
    select rc.player_id,rc.player_name,rc.legacy_score,rc.titles,rc.grand_slams,
           rc.wins,rc.weeks_no1,rc.eligibility_year,rc.speech
    from public.court_boss_retirement_ceremonies rc
    where rc.retirement_date=p_retired_date
      and rc.world_news_published=false
      and (
        rc.grand_slams>0 or rc.titles>=10 or rc.weeks_no1>0 or rc.wins>=400
      )
  loop
    if public.court_boss_publish_world_story(
      'retirement:'||r.player_id,
      p_retired_date,r.player_id,'retirement',
      r.player_name||' met un terme à sa carrière après '||r.titles||' titres'
        ||case when r.grand_slams>0 then ', dont '||r.grand_slams||' en Grand Chelem' else '' end
        ||'. Il pourra être considéré pour le Hall of Fame à partir de '||r.eligibility_year||'.',
      jsonb_build_object(
        'legacy_rank',null,'legacy_score',r.legacy_score,
        'titles',r.titles,'grand_slams',r.grand_slams,'wins',r.wins,
        'eligibility_year',r.eligibility_year,'speech',r.speech,
        'rank_deferred_to_hof_cycle',true,
        'batch_registration',true
      )
    ) then
      update public.court_boss_retirement_ceremonies
      set world_news_published=true,updated_at=now()
      where player_id=r.player_id;
    end if;
  end loop;

  return jsonb_build_object(
    'ok',true,
    'retired_date',p_retired_date,
    'registered',v_registered,
    'model','CB-HOF-RETIREMENT-BATCH-v1'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.court_boss_hof_retirement_batch_trigger()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
declare
  v_date date;
begin
  for v_date in
    select distinct n.retired_date
    from new_rows n
    join old_rows o on o.id=n.id
    where lower(coalesce(n.career_status,''))='retired'
      and n.retired_date is not null
      and (
        lower(coalesce(o.career_status,''))<>'retired'
        or o.retired_date is distinct from n.retired_date
      )
  loop
    perform public.court_boss_hof_register_retirements_batch(v_date);
  end loop;
  return null;
end;
$function$;

DROP TRIGGER IF EXISTS trg_cb_hof_retirement ON public.players;
DROP TRIGGER IF EXISTS trg_cb_hof_retirement_batch ON public.players;

CREATE TRIGGER trg_cb_hof_retirement_batch
AFTER UPDATE ON public.players
REFERENCING OLD TABLE AS old_rows NEW TABLE AS new_rows
FOR EACH STATEMENT
EXECUTE FUNCTION public.court_boss_hof_retirement_batch_trigger();
