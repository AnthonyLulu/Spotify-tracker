create table if not exists public.player_singles_pathway_cycles(
  review_month date primary key,
  processed_on date not null,
  result jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
alter table public.player_singles_pathway_cycles enable row level security;
revoke all on table public.player_singles_pathway_cycles from public,anon,authenticated;
grant select,insert,update on table public.player_singles_pathway_cycles to service_role;

create or replace function public.refresh_player_singles_circuit_pyramid(p_date date default current_date)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_date date:=coalesce(p_date,current_date);
  v_month date:=date_trunc('month',coalesce(p_date,current_date))::date;
  v_claimed int:=0;
  v_active int:=0;
  v_after int:=0;
  v_demote_goal int:=0;
  v_promote_goal int:=0;
  v_demoted int:=0;
  v_promoted int:=0;
  v_managed bigint;
  v_result jsonb;
begin
  if v_date<=date '2025-12-01' then
    return jsonb_build_object('date',v_date,'promoted',0,'demoted',0,'historical_cutoff',true);
  end if;

  insert into public.player_singles_pathway_cycles(review_month,processed_on)
  values(v_month,v_date)
  on conflict do nothing;
  get diagnostics v_claimed=row_count;

  if v_claimed=0 then
    select result into v_result
    from public.player_singles_pathway_cycles
    where review_month=v_month;
    return coalesce(v_result,'{}'::jsonb)||jsonb_build_object('date',v_date,'already_reviewed',true);
  end if;

  select managed_player_id into v_managed
  from public.career_state where id='demo';

  select count(*) into v_active
  from public.players p
  where p.career_status='active'
    and p.ranking_current=true
    and coalesce(p.career_focus,'mixed')<>'doubles_only'
    and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %';

  v_demote_goal:=case
    when v_active>2000 then least(12,v_active-2000)
    else 0
  end;

  with doomed as (
    select p.id
    from public.players p
    where p.career_status='active'
      and p.ranking_current=true
      and p.id<>coalesce(v_managed,-1)
      and coalesce(p.career_focus,'mixed')<>'doubles_only'
      and coalesce(p.ranking,999999)>=1600
      and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
    order by
      coalesce(p.ranking,999999) desc,
      coalesce(p.points,0) asc,
      coalesce(p.current_ability,0) asc,
      coalesce(p.form,0) asc,
      p.id desc
    limit v_demote_goal
  )
  update public.players p
  set ranking_current=false,
      ranking=null,
      source_ranking=null,
      points=greatest(0,round(coalesce(p.points,0)*.55)::int),
      itf_ranking=coalesce(p.itf_ranking,300+mod(p.id,1700)::int),
      ranking_source='Court Boss ATP→ITF pathway '||v_date::text,
      ranking_snapshot_date=v_date,
      data_snapshot=v_date
  from doomed d
  where p.id=d.id;
  get diagnostics v_demoted=row_count;

  select count(*) into v_after
  from public.players p
  where p.career_status='active'
    and p.ranking_current=true
    and coalesce(p.career_focus,'mixed')<>'doubles_only'
    and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %';

  v_promote_goal:=least(24,greatest(0,2200-v_after));

  with candidate_pool as (
    select
      p.id,
      (
        coalesce(p.current_ability,45)*2.20
        +coalesce(p.potential,p.current_ability,45)*.55
        +coalesce(p.form,65)*.20
        +coalesce(p.fitness,85)*.10
        -coalesce(p.fatigue,20)*.12
        +case when coalesce(p.age,24)<=21
              then greatest(0,coalesce(p.potential,p.current_ability,45)-coalesce(p.current_ability,45))*.55
              else 0 end
        +case when p.itf_ranking is not null
              then greatest(0,14-coalesce(p.itf_ranking,2000)/120.0)
              else 0 end
        -greatest(0,coalesce(p.age,24)-31)*.90
        -ln(greatest(10,coalesce(p.game_world_rank,10000))+10)*1.20
        +mod(abs(hashtext('singles-path|'||p.id::text||'|'||v_month::text)),100)/25.0
      ) as pathway_score
    from public.players p
    where p.career_status='active'
      and p.ranking_current=false
      and p.id<>coalesce(v_managed,-1)
      and coalesce(p.ncaa_current,false)=false
      and p.junior_ranking is null
      and coalesce(p.career_focus,'mixed')<>'doubles_only'
      and coalesce(p.injury_status,'Fit')='Fit'
      and coalesce(p.fitness,90)>=55
      and coalesce(p.age,24) between 16 and 38
      and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
      and (
        p.itf_ranking is not null
        or p.game_world_rank between 1 and 10000
        or coalesce(p.current_ability,0)>=55
        or coalesce(p.potential,0)>=70
      )
  ),
  chosen as (
    select id,pathway_score,
           row_number() over(order by pathway_score desc,id)::int as rn
    from candidate_pool
    order by pathway_score desc,id
    limit v_promote_goal
  )
  update public.players p
  set ranking_current=true,
      ranking=v_after+c.rn,
      source_ranking=v_after+c.rn,
      points=greatest(coalesce(p.points,0),greatest(1,12-ceil(c.rn/2.0)::int)),
      ranking_source='Court Boss ITF→ATP pathway '||v_date::text,
      ranking_snapshot_date=v_date,
      data_snapshot=v_date
  from chosen c
  where p.id=c.id;
  get diagnostics v_promoted=row_count;

  perform public.refresh_game_world_ranks();

  v_result:=jsonb_build_object(
    'date',v_date,
    'review_month',v_month,
    'active_before',v_active,
    'demoted',v_demoted,
    'promoted',v_promoted,
    'target_atp_pool',2200,
    'monthly_turnover_cap',12,
    'promotion_cap',24,
    'model','Court Boss ATP↔ITF pyramid v1'
  );

  update public.player_singles_pathway_cycles
  set result=v_result
  where review_month=v_month;

  return v_result;
end;
$$;

revoke execute on function public.refresh_player_singles_circuit_pyramid(date) from public,anon,authenticated;
grant execute on function public.refresh_player_singles_circuit_pyramid(date) to service_role;
