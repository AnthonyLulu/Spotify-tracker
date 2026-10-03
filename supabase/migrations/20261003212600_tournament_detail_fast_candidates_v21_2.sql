create or replace function public.tournament_detail_candidate_player_ids_v21_2(
  p_tournament_id bigint,
  p_entry_method text default 'candidate',
  p_limit integer default 256
)
returns table(player_id bigint, effective_rank integer)
language plpgsql
stable
set search_path to 'public'
as $function$
declare
  t public.tournaments%rowtype;
  method text:=lower(coalesce(p_entry_method,'candidate'));
  v_min int:=1;
  v_max int:=30000;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null then return; end if;

  if t.circuit='ATP' then
    v_min:=1; v_max:=500;
  elsif t.circuit='Challenger' then
    if t.category='Challenger 175' then
      v_min:=1; v_max:=case when method in ('direct','protected') then 500 else 2200 end;
    elsif t.category='Challenger 125' then
      v_min:=case when method in ('wildcard','candidate') then 11 else 51 end;
      v_max:=case when method='direct' then 500 else 3200 end;
    elsif t.category='Challenger 100' then
      v_min:=case when method in ('wildcard','candidate') then 11 else 51 end; v_max:=5000;
    elsif t.category='Challenger 75' then
      v_min:=51; v_max:=8000;
    elsif t.category='Challenger 50' then
      v_min:=case when method in ('wildcard','candidate') then 51 else 151 end; v_max:=14000;
    else
      v_min:=1; v_max:=5000;
    end if;
  end if;

  if t.circuit in ('ATP','Challenger') then
    return query
    with busy as materialized (
      select b.player_id
      from public.tournament_busy_player_ids_v20_5(t.id,method) b
    ),
    ranked as (
      select
        p.id,
        coalesce(case when p.ranking_current then p.ranking end,p.game_world_rank,p.ranking,999999)::int as rank_value,
        p.current_ability,
        p.country
      from public.players p
      where p.career_status='active'
        and coalesce(p.career_focus,'mixed')<>'doubles_only'
        and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
        and coalesce(
          case when p.birth_date is not null
            then extract(year from age(coalesce(t.qualifying_start_date,t.start_date),p.birth_date))::int end,
          p.age,99
        )>=14
        and coalesce(case when p.ranking_current then p.ranking end,p.game_world_rank,p.ranking,999999)
            between v_min and v_max
        and not exists(select 1 from busy b where b.player_id=p.id)
        and not (
          t.circuit='Challenger'
          and t.category='Challenger 50'
          and method='wildcard'
          and coalesce(case when p.ranking_current then p.ranking end,p.game_world_rank,p.ranking,999999) between 51 and 100
          and p.country is distinct from t.country
        )
      order by
        coalesce(case when p.ranking_current then p.ranking end,p.game_world_rank,p.ranking,999999),
        p.current_ability desc,p.id
      limit greatest(32,least(coalesce(p_limit,256),1200))
    )
    select r.id,r.rank_value
    from ranked r
    order by r.rank_value,r.current_ability desc,r.id;
    return;
  end if;

  if t.circuit='ITF' then
    return query
    with busy as materialized (
      select b.player_id
      from public.tournament_busy_player_ids_v20_5(t.id,method) b
    ),
    pool as (
      select
        p.id,
        case
          when p.ranking is not null and coalesce(p.ranking_current,true) then p.ranking::int
          when p.itf_ranking is not null then 100000+p.itf_ranking::int
          else 200000+greatest(1,1000-coalesce(p.current_ability,40)*10-round(coalesce(p.form,50)*0.5)::int)
        end as rank_value,
        p.current_ability,p.form
      from public.players p
      where p.career_status='active'
        and coalesce(p.career_focus,'mixed')<>'doubles_only'
        and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
        and coalesce(
          case when p.birth_date is not null
            then extract(year from age(coalesce(t.qualifying_start_date,t.start_date),p.birth_date))::int end,
          p.age,99
        )>=14
        and not exists(select 1 from busy b where b.player_id=p.id)
      order by
        case
          when p.ranking is not null and coalesce(p.ranking_current,true) then 1
          when p.itf_ranking is not null then 2
          else 3
        end,
        case when p.ranking is not null and coalesce(p.ranking_current,true) then p.ranking else 999999 end,
        case when p.itf_ranking is not null then p.itf_ranking else 999999 end,
        p.current_ability desc,p.form desc,p.id
      limit greatest(64,least(coalesce(p_limit,256),900))
    )
    select p.id,p.rank_value
    from pool p
    order by p.rank_value,p.current_ability desc,p.id;
    return;
  end if;

  return;
end;
$function$;

revoke all on function public.tournament_detail_candidate_player_ids_v21_2(bigint,text,integer) from public;
revoke all on function public.tournament_detail_candidate_player_ids_v21_2(bigint,text,integer) from anon;
revoke all on function public.tournament_detail_candidate_player_ids_v21_2(bigint,text,integer) from authenticated;
grant execute on function public.tournament_detail_candidate_player_ids_v21_2(bigint,text,integer) to service_role;
