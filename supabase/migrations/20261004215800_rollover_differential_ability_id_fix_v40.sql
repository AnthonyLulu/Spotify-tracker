CREATE OR REPLACE FUNCTION public.rollover_season_daily_v22(p_new_year integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  c career_state%rowtype;
  title_count int;
  final_count int;
  prize numeric;
  retired_count int:=0;
  processed_count int:=0;
  age_updates int:=0;
  newgen_result jsonb;
  ncaa_result jsonb;
  lifecycle_result jsonb;
  calendar_result jsonb;
  next_calendar_result jsonb;
  ranking_result jsonb;
begin
  select * into c from career_state where id='demo';
  if not found then raise exception 'Career not found'; end if;

  calendar_result:=public.ensure_calendar_season(p_new_year);
  next_calendar_result:=public.ensure_calendar_season(p_new_year+1);

  select count(*) filter(where user_round='Champion'),
         count(*) filter(where user_round in ('Champion','F')),
         coalesce(sum(user_prize),0)
    into title_count,final_count,prize
  from tournament_runs
  where extract(year from played_at)=c.season_year;

  insert into season_history(season_year,final_rank,doubles_rank,titles,finals,prize_money,points)
  values(c.season_year,c.singles_rank,c.doubles_rank,title_count,final_count,prize,c.points)
  on conflict(season_year) do update set
    final_rank=excluded.final_rank,doubles_rank=excluded.doubles_rank,titles=excluded.titles,
    finals=excluded.finals,prize_money=excluded.prize_money,points=excluded.points;

  age_updates:=public.refresh_player_simulation_ages(make_date(p_new_year,1,1));

  select public.advance_ncaa_lifecycle(p_new_year) into ncaa_result;

  with ability_changes as (
    select
      p.id as player_id,
      greatest(30,least(p.potential,
        p.current_ability+case
          when p.age is not null and p.age<=23 and p.potential>p.current_ability and ((p.id+p_new_year)%4)=0 then 1
          when p.age is not null and p.age>=34 and ((p.id+p_new_year)%3)=0 then -1
          else 0 end
      ))::int as new_current_ability,
      greatest(p.current_ability,
        p.potential-case
          when p.age is not null and p.age>=30 and ((p.id+p_new_year)%5)=0 then 1
          else 0 end
      )::int as new_potential
    from public.players p
    where p.ranking_current=true
  ),
  changed as (
    select
      a.player_id,
      a.new_current_ability,
      a.new_potential
    from ability_changes a
    join public.players p on p.id=a.player_id
    where p.current_ability is distinct from a.new_current_ability
       or p.potential is distinct from a.new_potential
  )
  update public.players p
  set current_ability=cg.new_current_ability,
      potential=cg.new_potential
  from changed cg
  where p.id=cg.player_id;

  get diagnostics processed_count=row_count;

  select public.refresh_player_career_lifecycle(make_date(p_new_year,1,1))
    into lifecycle_result;
  retired_count:=coalesce((lifecycle_result->>'retired')::int,0);

  select public.generate_newgens(p_new_year) into newgen_result;

  update career_state
  set season_year=p_new_year,week=1,career_date=make_date(p_new_year,1,1)-1,
      fatigue=greatest(5,fatigue-20),fitness=least(100,fitness+10),morale=least(100,morale+5),
      injury_status='Fit',updated_at=now()
  where id='demo';

  update college_career_state
  set eligibility_years=greatest(0,eligibility_years-1),
      academic_progress=greatest(45,academic_progress-5),
      coach_trust=greatest(40,coach_trust-4)
  where player_id is not null
    and status in ('committed','active');

  update sponsor_offers set status='available' where status='declined';

  ranking_result:=public.refresh_world_rankings(make_date(p_new_year,1,1));

  return jsonb_build_object(
    'new_year',p_new_year,
    'age_updates',age_updates,
    'retired_players',retired_count,'processed_players',processed_count,
    'newgens',newgen_result,'ncaa_lifecycle',ncaa_result,'career_lifecycle',lifecycle_result,
    'calendar',calendar_result,'next_calendar',next_calendar_result,
    'ranking',ranking_result,
    'previous_titles',title_count,'previous_prize',prize
  );
end;
$function$;
