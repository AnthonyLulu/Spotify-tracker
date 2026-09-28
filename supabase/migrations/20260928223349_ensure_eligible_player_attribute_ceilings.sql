create or replace function public.ensure_eligible_player_attribute_ceilings(p_date date default current_date)
returns jsonb
language plpgsql
security invoker
set search_path=public
as $$
declare
  r record;
  v_created int:=0;
begin
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
      )
  loop
    perform public.refresh_player_attribute_ceilings(coalesce(p_date,current_date),r.id);
    v_created:=v_created+1;
  end loop;
  return jsonb_build_object('date',coalesce(p_date,current_date),'created',v_created);
end;
$$;
