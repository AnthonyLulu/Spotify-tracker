create table if not exists public.player_development_trait_cycles (
  review_month date primary key,
  evolved_on date not null,
  result jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
alter table public.player_development_trait_cycles enable row level security;
revoke all on table public.player_development_trait_cycles from public, anon, authenticated;
grant select, insert, update on table public.player_development_trait_cycles to service_role;

create or replace function public.evolve_player_development_traits(p_date date default current_date)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_date date:=coalesce(p_date,current_date);
  v_month date:=date_trunc('month',coalesce(p_date,current_date))::date;
  v_claimed int:=0;
  v_updated int:=0;
  v_phase_changes int:=0;
  v_result jsonb;
begin
  if v_date<=date '2025-12-01' then
    return jsonb_build_object('date',v_date,'updated',0,'historical_cutoff',true);
  end if;

  insert into public.player_development_trait_cycles(review_month,evolved_on)
  values(v_month,v_date)
  on conflict do nothing;
  get diagnostics v_claimed=row_count;
  if v_claimed=0 then
    select result into v_result from public.player_development_trait_cycles where review_month=v_month;
    return coalesce(v_result,'{}'::jsonb)||jsonb_build_object('date',v_date,'already_reviewed',true);
  end if;

  with calc as (
    select
      dp.player_id,
      greatest(1,least(20,dp.professionalism+
        case
          when p.age<=27 and dp.discipline>=14 and pa.work_rate>=14 and dp.coaching_environment>=13
               and mod(abs(hashtext('pro|'||p.id||'|'||v_month)),100)<8 then 1
          when p.fatigue>=78 and dp.discipline<=9 and dp.burnout_susceptibility>=15
               and mod(abs(hashtext('prodown|'||p.id||'|'||v_month)),100)<10 then -1
          else 0 end)) as professionalism,
      greatest(1,least(20,dp.coachability+
        case
          when p.age<=24 and dp.adaptability>=14 and dp.staff_stability>=13
               and mod(abs(hashtext('coachability|'||p.id||'|'||v_month)),100)<8 then 1
          when dp.loyalty<=7 and dp.staff_stability<=7
               and mod(abs(hashtext('coachabilitydown|'||p.id||'|'||v_month)),100)<8 then -1
          else 0 end)) as coachability,
      greatest(1,least(20,dp.resilience+
        case
          when (coalesce(p.injury_status,'Fit')<>'Fit' or p.form<=55) and dp.competitive_drive>=13
               and mod(abs(hashtext('resilience|'||p.id||'|'||v_month)),100)<10 then 1
          when dp.burnout_susceptibility>=17 and p.morale<=45
               and mod(abs(hashtext('resiliencedown|'||p.id||'|'||v_month)),100)<8 then -1
          else 0 end)) as resilience,
      greatest(1,least(20,dp.discipline+
        case
          when p.age<=26 and dp.professionalism>=15 and dp.coaching_environment>=14
               and mod(abs(hashtext('discipline|'||p.id||'|'||v_month)),100)<7 then 1
          when dp.controversy>=16 and dp.professionalism<=9
               and mod(abs(hashtext('disciplinedown|'||p.id||'|'||v_month)),100)<9 then -1
          else 0 end)) as discipline,
      greatest(1,least(20,dp.competitive_drive+
        case
          when p.age<=25 and dp.ambition>=16 and p.morale>=70
               and mod(abs(hashtext('drive|'||p.id||'|'||v_month)),100)<6 then 1
          when p.age>=33 and dp.burnout_susceptibility>=15 and p.fatigue>=60
               and mod(abs(hashtext('drivedown|'||p.id||'|'||v_month)),100)<8 then -1
          else 0 end)) as competitive_drive,
      greatest(1,least(20,dp.development_rate+
        case
          when p.age<=22 and dp.coachability>=15 and dp.professionalism>=14
               and dp.technical_environment>=14 and mod(abs(hashtext('devrate|'||p.id||'|'||v_month)),100)<6 then 1
          when p.age>dp.peak_age+3 and dp.burnout_susceptibility>=16
               and mod(abs(hashtext('devratedown|'||p.id||'|'||v_month)),100)<8 then -1
          else 0 end)) as development_rate,
      greatest(1,least(20,dp.confidence_volatility+
        case
          when p.age>=24 and dp.professionalism>=14 and dp.resilience>=14
               and mod(abs(hashtext('volatilitydown|'||p.id||'|'||v_month)),100)<9 then -1
          when p.morale<=45 and dp.resilience<=9
               and mod(abs(hashtext('volatilityup|'||p.id||'|'||v_month)),100)<10 then 1
          else 0 end)) as confidence_volatility,
      greatest(1,least(20,dp.potential_volatility+
        case
          when p.age>=24 and mod(abs(hashtext('pavol|'||p.id||'|'||v_month)),100)<15 then -1
          when p.age<=20 and dp.development_type in ('late','standard')
               and mod(abs(hashtext('pavolup|'||p.id||'|'||v_month)),100)<5 then 1
          else 0 end)) as potential_volatility,
      greatest(-10,least(10,
        case when dp.potential_momentum>0 then dp.potential_momentum-1
             when dp.potential_momentum<0 then dp.potential_momentum+1
             else 0 end)) as potential_momentum,
      greatest(27,least(35,dp.decline_start_age+
        case
          when pa.natural_fitness>=17 and pa.recovery>=16 and dp.professionalism>=15 and dp.injury_proneness<=10
               and extract(month from v_date)::int=12
               and mod(abs(hashtext('longevity|'||p.id||'|'||extract(year from v_date)::int)),100)<18 then 1
          when dp.injury_proneness>=17 and dp.resilience<=9 and coalesce(p.injury_status,'Fit')<>'Fit'
               and mod(abs(hashtext('earlydecline|'||p.id||'|'||v_month)),100)<12 then -1
          else 0 end)) as decline_start_age,
      case
        when p.age<=21 and p.potential-p.current_ability>=12 then 'prospect'
        when p.age<dp.peak_age and p.potential-p.current_ability>=6 then 'developing'
        when p.age between dp.peak_age and dp.decline_start_age and p.current_ability>=p.potential-3 then 'prime'
        when p.age>dp.decline_start_age then 'decline'
        when p.current_ability>=p.potential-2 then 'plateau'
        else 'maturing'
      end as phase
    from public.player_development_profiles dp
    join public.players p on p.id=dp.player_id
    join public.player_attributes pa on pa.player_id=p.id
    where p.career_status='active'
      and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
      and dp.last_review_date=v_date
  ),
  changed as (
    select c.*,dp.development_context old_context
    from calc c join public.player_development_profiles dp on dp.player_id=c.player_id
    where row(
      dp.professionalism,dp.coachability,dp.resilience,dp.discipline,dp.competitive_drive,
      dp.development_rate,dp.confidence_volatility,dp.potential_volatility,
      dp.potential_momentum,dp.decline_start_age,
      coalesce(dp.development_context->>'phase','')
    ) is distinct from row(
      c.professionalism,c.coachability,c.resilience,c.discipline,c.competitive_drive,
      c.development_rate,c.confidence_volatility,c.potential_volatility,
      c.potential_momentum,c.decline_start_age,c.phase
    )
  ),
  upd as (
    update public.player_development_profiles dp
    set professionalism=c.professionalism,
        coachability=c.coachability,
        resilience=c.resilience,
        discipline=c.discipline,
        competitive_drive=c.competitive_drive,
        development_rate=c.development_rate,
        confidence_volatility=c.confidence_volatility,
        potential_volatility=c.potential_volatility,
        potential_momentum=c.potential_momentum,
        decline_start_age=c.decline_start_age,
        development_context=coalesce(dp.development_context,'{}'::jsonb)||
          jsonb_build_object('phase',c.phase,'trait_review_date',v_date),
        updated_at=now()
    from changed c
    where dp.player_id=c.player_id
    returning dp.player_id,
      coalesce(c.old_context->>'phase','') old_phase,
      c.phase new_phase
  )
  select count(*)::int,
         count(*) filter(where old_phase<>new_phase)::int
  into v_updated,v_phase_changes
  from upd;

  v_result:=jsonb_build_object(
    'date',v_date,
    'review_month',v_month,
    'updated',coalesce(v_updated,0),
    'phase_changes',coalesce(v_phase_changes,0),
    'model','development-traits-v1'
  );
  update public.player_development_trait_cycles set result=v_result where review_month=v_month;
  return v_result;
end;
$$;

revoke all on function public.evolve_player_development_traits(date) from public, anon, authenticated;
grant execute on function public.evolve_player_development_traits(date) to service_role;
