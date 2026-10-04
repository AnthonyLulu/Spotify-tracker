-- Court Boss V23.6: optimize living-world integrity audit at production scale

CREATE INDEX IF NOT EXISTS idx_player_staff_active_pair_v23
ON public.player_staff_assignments (player_id, staff_profile_id)
WHERE active=true;

CREATE INDEX IF NOT EXISTS idx_player_relationships_active_pair_v23
ON public.player_relationships (player_a_id, player_b_id)
WHERE active=true;

CREATE OR REPLACE FUNCTION public.living_world_integrity_audit_v14(p_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  v_date date:=coalesce(p_date,current_date);
  v_year int:=extract(year from coalesce(p_date,current_date))::int;
  v_year_start date:=make_date(extract(year from coalesce(p_date,current_date))::int,1,1);
  v_year_end date:=make_date(extract(year from coalesce(p_date,current_date))::int+1,1,1);
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
  select count(*) into v_active
  from public.players
  where career_status='active'
    and coalesce(data_source,'') not ilike 'hidden duplicate merged into %';

  select count(*) into v_ranked
  from public.players
  where career_status='active'
    and ranking_current=true
    and coalesce(data_source,'') not ilike 'hidden duplicate merged into %';

  select count(*) into v_juniors
  from public.players
  where career_status='active'
    and age between 13 and 17
    and (junior_ranking is not null or game_generated=true);

  select count(*) into v_ncaa
  from public.players
  where career_status='active' and ncaa_current=true;

  select count(*) into v_staff
  from public.staff_profiles
  where active=true;

  select count(*) into v_former_staff
  from public.staff_profiles
  where active=true and former_player_id is not null;

  select count(*) into v_bad_retired_rank
  from public.players
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
  where psa.active=true
    and (
      not exists(
        select 1 from public.staff_profiles sp
        where sp.id=psa.staff_profile_id and sp.active=true
      )
      or not exists(
        select 1 from public.players p
        where p.id=psa.player_id and p.career_status='active'
      )
    );

  select count(*) into v_orphan_relationships
  from public.player_relationships r
  where r.active=true
    and (
      r.player_a_id=r.player_b_id
      or not exists(select 1 from public.players a where a.id=r.player_a_id)
      or not exists(select 1 from public.players b where b.id=r.player_b_id)
    );

  select count(*) into v_slams
  from public.tournaments
  where is_active=true
    and circuit='ATP'
    and category='Grand Chelem'
    and start_date>=v_year_start
    and start_date<v_year_end;

  select count(*) into v_masters
  from public.tournaments
  where is_active=true
    and circuit='ATP'
    and category='Masters 1000'
    and start_date>=v_year_start
    and start_date<v_year_end;

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
    'model','CB-LIVING-WORLD-INTEGRITY-v23.6'
  );
end;
$function$;

revoke all on function public.living_world_integrity_audit_v14(date) from public,anon,authenticated;
grant execute on function public.living_world_integrity_audit_v14(date) to service_role;
