create or replace function public.ensure_eligible_player_attribute_ceilings(p_date date default current_date)
returns jsonb
language plpgsql
security invoker
set search_path=public
as $$
declare
  r record;
  v_date date:=coalesce(p_date,current_date);
  v_created int:=0;
begin
  if v_date<=date '2025-12-01' then
    return jsonb_build_object('date',v_date,'created',0,'historical_cutoff',true);
  end if;

  for r in
    select p.id
    from public.players p
    left join public.player_attribute_ceilings c on c.player_id=p.id
    where c.player_id is null
      and p.career_status='active'
      and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
      and (
        p.ranking_current=true
        or p.game_generated=true
        or p.itf_ranking is not null
        or p.junior_ranking is not null
        or p.ncaa_current=true
        or p.doubles_ranking is not null
        or (
          p.game_world_rank between 1 and 5000
          and mod(abs(hashtext(p.id::text)),4)=mod(extract(month from v_date)::int-1,4)
        )
      )
  loop
    perform public.refresh_player_attribute_ceilings(v_date,r.id);
    v_created:=v_created+1;
  end loop;

  return jsonb_build_object(
    'date',v_date,
    'created',v_created,
    'high_fidelity_world_rank_limit',5000,
    'cohort',mod(extract(month from v_date)::int-1,4)
  );
end;
$$;

revoke execute on function public.ensure_eligible_player_attribute_ceilings(date) from public,anon,authenticated;
grant execute on function public.ensure_eligible_player_attribute_ceilings(date) to service_role;
