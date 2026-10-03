-- Court Boss Living World V16 integrity repair
CREATE OR REPLACE FUNCTION public.repair_living_world_integrity_v16(p_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_date date:=coalesce(p_date,current_date);
  v_retired_ranked int:=0;
  v_entries_withdrawn int:=0;
  v_world_entries_removed int:=0;
  v_pairs_dissolved int:=0;
  v_double_entries_removed int:=0;
  v_staff_unassigned int:=0;
  v_self_relations_closed int:=0;
  v_retired_injuries_closed int:=0;
begin
  update public.players p
  set ranking_current=false,
      race_ranking=null,
      nextgen_ranking=null,
      game_world_rank=null
  where p.career_status='retired'
    and (
      p.ranking_current=true
      or p.race_ranking is not null
      or p.nextgen_ranking is not null
      or p.game_world_rank is not null
    );
  get diagnostics v_retired_ranked=row_count;

  update public.entries e
  set status='withdrawn',
      withdrawn_on=coalesce(e.withdrawn_on,v_date),
      updated_at=now(),
      metadata=coalesce(e.metadata,'{}'::jsonb)||jsonb_build_object(
        'integrity_repair','retired_player',
        'repaired_on',v_date
      )
  from public.players p, public.tournaments t
  where e.player_id=p.id
    and e.tournament_id=t.id
    and p.career_status='retired'
    and t.start_date>=v_date
    and coalesce(e.status,'entered') not in ('withdrawn','cancelled','rejected');
  get diagnostics v_entries_withdrawn=row_count;

  delete from public.world_tournament_entries w
  using public.players p,public.tournaments t
  where w.player_id=p.id
    and w.tournament_id=t.id
    and p.career_status='retired'
    and t.start_date>=v_date
    and w.simulated_on is null;
  get diagnostics v_world_entries_removed=row_count;

  update public.world_doubles_partnerships w
  set active=false,
      dissolved_date=coalesce(w.dissolved_date,v_date),
      race_rank=null,
      source=coalesce(w.source,'')||case when coalesce(w.source,'')='' then '' else ' · ' end||'Court Boss integrity repair v16'
  where w.active=true
    and exists(
      select 1
      from public.players p
      where p.career_status='retired'
        and (p.id=w.player_a_id or p.id=w.player_b_id)
    );
  get diagnostics v_pairs_dissolved=row_count;

  delete from public.world_doubles_tournament_entries e
  using public.world_doubles_partnerships w,public.tournaments t
  where e.pair_id=w.id
    and e.tournament_id=t.id
    and w.active=false
    and t.start_date>=v_date
    and e.simulated_on is null;
  get diagnostics v_double_entries_removed=row_count;

  update public.player_staff_assignments psa
  set active=false,
      end_date=coalesce(psa.end_date,v_date),
      ended_reason=coalesce(psa.ended_reason,
        case
          when exists(select 1 from public.players p where p.id=psa.player_id and p.career_status='retired')
            then 'Retraite du joueur'
          else 'Staff indisponible'
        end
      ),
      last_review_date=v_date
  where psa.active=true
    and (
      exists(select 1 from public.players p where p.id=psa.player_id and p.career_status='retired')
      or exists(select 1 from public.staff_profiles sp where sp.id=psa.staff_profile_id and sp.active=false)
      or not exists(select 1 from public.players p where p.id=psa.player_id)
      or not exists(select 1 from public.staff_profiles sp where sp.id=psa.staff_profile_id)
    );
  get diagnostics v_staff_unassigned=row_count;

  update public.player_relationships r
  set active=false,
      last_update=v_date,
      source_label=coalesce(r.source_label,'Court Boss')||' · integrity repair v16'
  where r.active=true
    and (
      r.player_a_id=r.player_b_id
      or not exists(select 1 from public.players p where p.id=r.player_a_id)
      or not exists(select 1 from public.players p where p.id=r.player_b_id)
    );
  get diagnostics v_self_relations_closed=row_count;

  update public.injuries i
  set status='recovered',
      expected_return=least(coalesce(i.expected_return,v_date),v_date),
      treatment=coalesce(i.treatment,'')||case when coalesce(i.treatment,'')='' then '' else ' · ' end||'Carrière terminée'
  where lower(coalesce(i.status,''))='active'
    and exists(
      select 1 from public.players p
      where p.id=i.player_id and p.career_status='retired'
    );
  get diagnostics v_retired_injuries_closed=row_count;

  return jsonb_build_object(
    'ok',true,
    'date',v_date,
    'retired_rank_state_fixed',v_retired_ranked,
    'managed_entries_withdrawn',v_entries_withdrawn,
    'world_entries_removed',v_world_entries_removed,
    'doubles_partnerships_dissolved',v_pairs_dissolved,
    'future_doubles_entries_removed',v_double_entries_removed,
    'staff_assignments_closed',v_staff_unassigned,
    'invalid_relationships_closed',v_self_relations_closed,
    'retired_injuries_closed',v_retired_injuries_closed,
    'repairs_total',
      v_retired_ranked+v_entries_withdrawn+v_world_entries_removed+
      v_pairs_dissolved+v_double_entries_removed+v_staff_unassigned+
      v_self_relations_closed+v_retired_injuries_closed,
    'model','CB-LIVING-WORLD-REPAIR-v16'
  );
end;
$function$
;

revoke all on function public.repair_living_world_integrity_v16(date) from public,anon,authenticated;
grant execute on function public.repair_living_world_integrity_v16(date) to service_role;
