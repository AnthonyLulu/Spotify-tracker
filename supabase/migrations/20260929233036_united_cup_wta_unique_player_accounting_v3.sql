-- Court Boss United Cup WTA unique-player accounting v3
-- Prevents duplicate stats/prize when one WTA player fills multiple submitted roles.

create table if not exists public.united_cup_wta_player_totals(
  tournament_id bigint not null references public.tournaments(id) on delete cascade,
  country text not null,
  player_name text not null,
  primary_role text not null,
  singles_wins integer not null default 0,
  mixed_wins integer not null default 0,
  wta_points_earned integer not null default 0,
  participation_fee numeric not null default 0,
  team_prize numeric not null default 0,
  singles_prize numeric not null default 0,
  mixed_prize numeric not null default 0,
  prize_earned numeric not null default 0,
  snapshot_date date,
  source_label text not null default 'Court Boss United Cup WTA external player totals v1',
  primary key(tournament_id,country,player_name)
);

alter table public.united_cup_wta_player_totals enable row level security;

create index if not exists united_cup_wta_player_totals_country_idx
  on public.united_cup_wta_player_totals(tournament_id,country,prize_earned desc);

CREATE OR REPLACE FUNCTION public.refresh_united_cup_wta_player_stats(p_tournament_id bigint, p_player_name text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_country text;
  v_primary_role text;
  v_entry_singles_rank int;
  v_entry_doubles_rank int;
  v_singles_wins int:=0;
  v_mixed_wins int:=0;
  v_knockout_win boolean:=false;
  v_points int:=0;
  v_participation numeric:=0;
  v_team_prize numeric:=0;
  v_singles_prize numeric:=0;
  v_mixed_prize numeric:=0;
  v_total_prize numeric:=0;
  v_snapshot date;
begin
  select
    min(country),
    case when bool_or(role='singles1') then 'singles1' else 'doubles' end,
    min(entry_singles_rank) filter(where entry_singles_rank is not null),
    min(entry_doubles_rank) filter(where entry_doubles_rank is not null)
  into v_country,v_primary_role,v_entry_singles_rank,v_entry_doubles_rank
  from public.united_cup_wta_rosters
  where tournament_id=p_tournament_id
    and player_name=p_player_name;

  if v_country is null then
    return jsonb_build_object('ok',false,'reason','player_not_in_wta_roster','player_name',p_player_name);
  end if;

  select
    count(*) filter(
      where r.rubber_type='women_singles'
        and (
          (r.nation_a_wta_name=p_player_name and r.winner_nation=t.nation_a)
          or
          (r.nation_b_wta_name=p_player_name and r.winner_nation=t.nation_b)
        )
    )::int,
    count(*) filter(
      where r.rubber_type='mixed_doubles'
        and (
          (r.nation_a_wta_name=p_player_name and r.winner_nation=t.nation_a)
          or
          (r.nation_b_wta_name=p_player_name and r.winner_nation=t.nation_b)
        )
    )::int,
    coalesce(bool_or(
      r.rubber_type='women_singles'
      and upper(t.stage) in ('QF','SF','F')
      and (
        (r.nation_a_wta_name=p_player_name and r.winner_nation=t.nation_a)
        or
        (r.nation_b_wta_name=p_player_name and r.winner_nation=t.nation_b)
      )
    ),false)
  into v_singles_wins,v_mixed_wins,v_knockout_win
  from public.united_cup_rubbers r
  join public.united_cup_ties t on t.id=r.tie_id
  where t.tournament_id=p_tournament_id;

  v_points:=case
    when v_primary_role='singles1'
    then public.united_cup_wta_points(v_singles_wins,v_knockout_win)
    else 0
  end;

  select coalesce(sum(
    public.united_cup_prize_component(
      p_tournament_id,'team_win_per_player',
      case when upper(stage)='GROUP' then 'GROUP' else upper(stage) end
    )
  ),0)
  into v_team_prize
  from public.united_cup_ties
  where tournament_id=p_tournament_id
    and status='completed'
    and winner_nation=v_country;

  select coalesce(sum(
    public.united_cup_prize_component(
      p_tournament_id,'singles_match_win_no1',
      case when upper(t.stage)='GROUP' then 'GROUP' else upper(t.stage) end
    )
  ),0)
  into v_singles_prize
  from public.united_cup_ties t
  join public.united_cup_rubbers r on r.tie_id=t.id
  where t.tournament_id=p_tournament_id
    and t.status='completed'
    and r.rubber_type='women_singles'
    and r.winner_nation=v_country
    and (
      (t.nation_a=v_country and r.nation_a_wta_name=p_player_name)
      or
      (t.nation_b=v_country and r.nation_b_wta_name=p_player_name)
    );

  select coalesce(sum(
    public.united_cup_prize_component(
      p_tournament_id,'mixed_doubles_match_win',
      case when upper(t.stage)='GROUP' then 'GROUP' else upper(t.stage) end
    )
  ),0)
  into v_mixed_prize
  from public.united_cup_ties t
  join public.united_cup_rubbers r on r.tie_id=t.id
  where t.tournament_id=p_tournament_id
    and t.status='completed'
    and r.rubber_type='mixed_doubles'
    and r.winner_nation=v_country
    and (
      (t.nation_a=v_country and r.nation_a_wta_name=p_player_name)
      or
      (t.nation_b=v_country and r.nation_b_wta_name=p_player_name)
    );

  v_participation:=public.united_cup_participation_fee(
    coalesce(
      case when v_primary_role='singles1' then v_entry_singles_rank else v_entry_doubles_rank end,
      v_entry_singles_rank,v_entry_doubles_rank,999999
    ),
    v_primary_role
  );

  v_total_prize:=v_participation+v_team_prize+v_singles_prize+v_mixed_prize;

  select coalesce(end_date,start_date,current_date)
  into v_snapshot
  from public.tournaments
  where id=p_tournament_id;

  insert into public.united_cup_wta_player_totals(
    tournament_id,country,player_name,primary_role,
    singles_wins,mixed_wins,wta_points_earned,
    participation_fee,team_prize,singles_prize,mixed_prize,prize_earned,
    snapshot_date,source_label
  ) values(
    p_tournament_id,v_country,p_player_name,v_primary_role,
    v_singles_wins,v_mixed_wins,v_points,
    v_participation,v_team_prize,v_singles_prize,v_mixed_prize,v_total_prize,
    v_snapshot,'Court Boss United Cup WTA external player totals v1'
  )
  on conflict(tournament_id,country,player_name) do update set
    primary_role=excluded.primary_role,
    singles_wins=excluded.singles_wins,
    mixed_wins=excluded.mixed_wins,
    wta_points_earned=excluded.wta_points_earned,
    participation_fee=excluded.participation_fee,
    team_prize=excluded.team_prize,
    singles_prize=excluded.singles_prize,
    mixed_prize=excluded.mixed_prize,
    prize_earned=excluded.prize_earned,
    snapshot_date=excluded.snapshot_date,
    source_label=excluded.source_label;

  update public.united_cup_wta_rosters
  set singles_wins=0,
      mixed_wins=0,
      wta_points_earned=0,
      prize_earned=0
  where tournament_id=p_tournament_id
    and country=v_country
    and player_name=p_player_name;

  update public.united_cup_wta_rosters
  set singles_wins=v_singles_wins,
      mixed_wins=v_mixed_wins,
      wta_points_earned=v_points,
      prize_earned=v_total_prize
  where tournament_id=p_tournament_id
    and country=v_country
    and player_name=p_player_name
    and role=v_primary_role;

  return jsonb_build_object(
    'ok',true,
    'player_name',p_player_name,
    'country',v_country,
    'primary_role',v_primary_role,
    'singles_wins',v_singles_wins,
    'mixed_wins',v_mixed_wins,
    'knockout_win',v_knockout_win,
    'wta_points',v_points,
    'prize_earned',v_total_prize,
    'layer','external_wta_player'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.refresh_united_cup_wta_player_totals(p_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  r record;
  v_result jsonb;
  v_players int:=0;
begin
  delete from public.united_cup_wta_player_totals
  where tournament_id=p_tournament_id;

  update public.united_cup_wta_rosters
  set singles_wins=0,
      mixed_wins=0,
      wta_points_earned=0,
      prize_earned=0
  where tournament_id=p_tournament_id;

  for r in
    select country,player_name
    from public.united_cup_wta_rosters
    where tournament_id=p_tournament_id
    group by country,player_name
    order by country,player_name
  loop
    v_result:=public.refresh_united_cup_wta_player_stats(
      p_tournament_id,r.player_name
    );
    if coalesce((v_result->>'ok')::boolean,false) then
      v_players:=v_players+1;
    end if;
  end loop;

  return jsonb_build_object(
    'ok',true,
    'players',v_players,
    'points_total',(
      select coalesce(sum(wta_points_earned),0)
      from public.united_cup_wta_player_totals
      where tournament_id=p_tournament_id
    ),
    'prize_total',(
      select coalesce(sum(prize_earned),0)
      from public.united_cup_wta_player_totals
      where tournament_id=p_tournament_id
    ),
    'model','United Cup WTA external player totals v1'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.recalculate_united_cup_stats(p_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  r record;
  v_singles_wins int;
  v_mixed_wins int;
  v_points int;
  v_team_prize numeric;
  v_singles_prize numeric;
  v_mixed_prize numeric;
  v_participation numeric;
  v_prize numeric;
  v_wta_wins int;
  v_wta_mixed int;
  v_wta_points int;
  v_has_knockout boolean;
begin
  for r in
    select *
    from public.united_cup_atp_rosters
    where tournament_id=p_tournament_id
  loop
    select
      count(*) filter(
        where ur.rubber_type='men_singles'
          and ur.winner_nation=r.country
          and (
            (ut.nation_a=r.country and ur.nation_a_male_id=r.player_id)
            or (ut.nation_b=r.country and ur.nation_b_male_id=r.player_id)
          )
      )::int,
      count(*) filter(
        where ur.rubber_type='mixed_doubles'
          and ur.winner_nation=r.country
          and (
            (ut.nation_a=r.country and ur.nation_a_male_id=r.player_id)
            or (ut.nation_b=r.country and ur.nation_b_male_id=r.player_id)
          )
      )::int,
      coalesce(sum(
        case
          when ur.rubber_type='men_singles'
           and ur.winner_nation=r.country
           and (
             (ut.nation_a=r.country and ur.nation_a_male_id=r.player_id)
             or (ut.nation_b=r.country and ur.nation_b_male_id=r.player_id)
           )
          then ur.atp_points_awarded
          else 0
        end
      ),0)::int
    into v_singles_wins,v_mixed_wins,v_points
    from public.united_cup_ties ut
    join public.united_cup_rubbers ur on ur.tie_id=ut.id
    where ut.tournament_id=p_tournament_id
      and ut.status='completed';

    select coalesce(sum(
      public.united_cup_prize_component(
        p_tournament_id,'team_win_per_player',
        case when upper(stage)='GROUP' then 'GROUP' else upper(stage) end
      )
    ),0)
    into v_team_prize
    from public.united_cup_ties
    where tournament_id=p_tournament_id
      and status='completed'
      and winner_nation=r.country;

    select coalesce(sum(
      public.united_cup_prize_component(
        p_tournament_id,'singles_match_win_no1',
        case when upper(ut.stage)='GROUP' then 'GROUP' else upper(ut.stage) end
      )
    ),0)
    into v_singles_prize
    from public.united_cup_ties ut
    join public.united_cup_rubbers ur on ur.tie_id=ut.id
    where ut.tournament_id=p_tournament_id
      and ut.status='completed'
      and ur.rubber_type='men_singles'
      and ur.winner_nation=r.country
      and (
        (ut.nation_a=r.country and ur.nation_a_male_id=r.player_id)
        or (ut.nation_b=r.country and ur.nation_b_male_id=r.player_id)
      );

    select coalesce(sum(
      public.united_cup_prize_component(
        p_tournament_id,'mixed_doubles_match_win',
        case when upper(ut.stage)='GROUP' then 'GROUP' else upper(ut.stage) end
      )
    ),0)
    into v_mixed_prize
    from public.united_cup_ties ut
    join public.united_cup_rubbers ur on ur.tie_id=ut.id
    where ut.tournament_id=p_tournament_id
      and ut.status='completed'
      and ur.rubber_type='mixed_doubles'
      and ur.winner_nation=r.country
      and (
        (ut.nation_a=r.country and ur.nation_a_male_id=r.player_id)
        or (ut.nation_b=r.country and ur.nation_b_male_id=r.player_id)
      );

    v_participation:=public.united_cup_participation_fee(
      coalesce(
        case when r.role='singles1' then r.entry_singles_rank else r.entry_doubles_rank end,
        r.entry_singles_rank,r.entry_doubles_rank,999999
      ),
      r.role
    );

    v_prize:=v_participation+v_team_prize+v_singles_prize+v_mixed_prize;

    update public.united_cup_atp_rosters
    set singles_wins=v_singles_wins,
        mixed_wins=v_mixed_wins,
        atp_points_earned=v_points,
        prize_earned=v_prize
    where tournament_id=p_tournament_id
      and country=r.country
      and role=r.role;
  end loop;

  perform public.refresh_united_cup_wta_player_totals(p_tournament_id);

  -- ATP ranking points are rebuilt from completed men's singles rubbers.
  delete from public.world_ranking_points
  where tournament_id=p_tournament_id;

  insert into public.world_ranking_points(
    player_id,tournament_id,label,earned_date,expiry_date,points,active,source_label
  )
  select
    roster.player_id,p_tournament_id,
    'United Cup · total',
    t.end_date,t.end_date+364,
    roster.atp_points_earned,true,
    'Court Boss United Cup · official 2026 opponent-rank points table'
  from public.united_cup_atp_rosters roster
  join public.tournaments t on t.id=p_tournament_id
  where roster.tournament_id=p_tournament_id
    and roster.atp_points_earned>0
  on conflict(player_id,tournament_id) do update set
    label=excluded.label,
    earned_date=excluded.earned_date,
    expiry_date=excluded.expiry_date,
    points=excluded.points,
    active=true,
    source_label=excluded.source_label;

  return jsonb_build_object(
    'ok',true,
    'atp_points_total',(
      select coalesce(sum(atp_points_earned),0)
      from public.united_cup_atp_rosters
      where tournament_id=p_tournament_id
    ),
    'atp_max',(
      select coalesce(max(atp_points_earned),0)
      from public.united_cup_atp_rosters
      where tournament_id=p_tournament_id
    ),
    'wta_max',(
      select coalesce(max(wta_points_earned),0)
      from public.united_cup_wta_rosters
      where tournament_id=p_tournament_id
    ),
    'prize_total',(
      select
        coalesce((select sum(prize_earned) from public.united_cup_atp_rosters where tournament_id=p_tournament_id),0)
        +
        coalesce((select sum(prize_earned) from public.united_cup_wta_rosters where tournament_id=p_tournament_id),0)
    )
  );
end;
$function$;
