
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
    select
      p.id,p.name,p.country,p.retirement_reason,p.retired_date,
      coalesce(p.weeks_at_no1,0)::bigint weeks_no1,
      coalesce(h.titles,0)::bigint historical_titles,
      coalesce(h.grand_slams,0)::bigint historical_slams,
      coalesce(h.masters,0)::bigint historical_masters,
      coalesce(h.tour_finals,0)::bigint historical_finals,
      greatest(coalesce(h.wins,0),coalesce(pcs.wins,0))::bigint materialized_wins,
      greatest(coalesce(h.losses,0),coalesce(pcs.losses,0))::bigint materialized_losses
    from public.players p
    left join public.history_player_scores h on h.id=p.id
    left join public.player_career_stats pcs on pcs.player_id=p.id
    where lower(coalesce(p.career_status,''))='retired'
      and p.retired_date=p_retired_date
      and not exists(
        select 1 from public.court_boss_hof_profiles hp where hp.player_id=p.id
      )
  ),
  scored as (
    select
      t.*,
      (
        t.historical_slams*10000
        +t.historical_finals*2200
        +t.historical_masters*1200
        +greatest(t.historical_titles-t.historical_slams-t.historical_masters-t.historical_finals,0)*180
        +t.materialized_wins*2
        +t.weeks_no1*8
      )::bigint legacy_score,
      extract(year from t.retired_date)::int+5 eligibility_year,
      (
        'Après '||t.historical_titles||' titres recensés'
        ||case when t.historical_slams>0 then ', '||t.historical_slams||' Majeur'||case when t.historical_slams>1 then 's' else '' end else '' end
        ||' et '||t.materialized_wins||' victoires déjà consolidées, '||t.name
        ||' referme sa carrière professionnelle. '
        ||'Son dossier statistique complet sera figé lors du cycle Hall of Fame. '
        ||'Première année d’éligibilité : '||(extract(year from t.retired_date)::int+5)||'.'
      )::text speech
    from target t
  ),
  profile_upsert as (
    insert into public.court_boss_hof_profiles(
      player_id,retired_date,eligibility_year,status,hof_score,
      retirement_ceremony_on,retirement_speech,metadata,updated_at
    )
    select
      s.id,s.retired_date,s.eligibility_year,'waiting',s.legacy_score,
      s.retired_date,s.speech,
      jsonb_build_object(
        'legacy_rank_at_retirement',null,
        'legacy_score_at_retirement',s.legacy_score,
        'titles_materialized',s.historical_titles,
        'grand_slams_materialized',s.historical_slams,
        'wins_materialized',s.materialized_wins,
        'rank_deferred_to_hof_cycle',true,
        'stats_deferred_to_hof_cycle',true,
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
    s.id,s.retired_date,s.retired_date,s.name,s.country,
    null,s.legacy_score,s.historical_titles,s.historical_slams,
    s.historical_masters,s.historical_finals,s.materialized_wins,s.weeks_no1,
    s.eligibility_year,s.speech,
    jsonb_build_object(
      'career_status','retired',
      'retirement_reason',s.retirement_reason,
      'rank_deferred_to_hof_cycle',true,
      'stats_deferred_to_hof_cycle',true,
      'batch_registration',true
    ),
    now()
  from scored s
  join profile_upsert u on u.player_id=s.id
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
      r.player_name||' met un terme à sa carrière. Son dossier Hall of Fame sera figé au cycle annuel.',
      jsonb_build_object(
        'legacy_rank',null,'legacy_score_materialized',r.legacy_score,
        'titles_materialized',r.titles,'grand_slams_materialized',r.grand_slams,
        'wins_materialized',r.wins,'eligibility_year',r.eligibility_year,
        'speech',r.speech,'stats_deferred_to_hof_cycle',true
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
    'exact_legacy_stats_deferred',true,
    'model','CB-HOF-RETIREMENT-BATCH-v2'
  );
end;
$function$;
