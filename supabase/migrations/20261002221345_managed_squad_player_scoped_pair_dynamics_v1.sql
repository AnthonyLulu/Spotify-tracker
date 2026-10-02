create or replace function public.apply_managed_doubles_result(p_run_id bigint, p_date date default current_date)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_date date:=coalesce(p_date,current_date);
  v_run doubles_runs%rowtype;
  v_pair doubles_partnerships%rowtype;
  v_managed bigint;
  v_focus text;
  v_result_score int:=50;
  v_delta int:=0;
  v_title int:=0;
  v_final int:=0;
  v_new_momentum int:=50;
  v_new_chemistry int:=60;
  v_new_strength int:=60;
begin
  select * into v_run from doubles_runs where id=p_run_id;
  if not found then return jsonb_build_object('ok',false,'error','run_not_found'); end if;

  v_managed:=v_run.managed_player_id;
  if v_managed is null then
    select managed_player_id into v_managed from career_state where id='demo';
  end if;
  select coalesce(career_focus,'mixed') into v_focus from players where id=v_managed;
  if v_focus is null then
    select coalesce(career_focus,'mixed') into v_focus from career_state where id='demo';
  end if;

  select * into v_pair from doubles_partnerships where id=v_run.partnership_id limit 1;
  if v_pair.id is null then return jsonb_build_object('ok',false,'error','partnership_not_found'); end if;

  v_result_score:=case
    when v_run.user_round='Champion' then 100
    when v_run.user_round='F' then 88
    when v_run.user_round='SF' then 75
    when v_run.user_round='QF' then 62
    when v_run.user_round='Phase de groupes' then 55
    when v_run.user_round in ('R16','R32') then 46
    else 42 end;
  v_delta:=case
    when v_run.user_round='Champion' then 5
    when v_run.user_round='F' then 3
    when v_run.user_round='SF' then 2
    when v_run.user_round='QF' then 1
    when v_run.user_round='Phase de groupes' then 0
    when v_run.user_round='R16' then -1
    else -2 end;
  if v_focus='doubles_only' and v_delta>=0 then v_delta:=v_delta+1; end if;

  v_title:=case when v_run.user_round='Champion' then 1 else 0 end;
  v_final:=case when v_run.user_round in ('Champion','F') then 1 else 0 end;
  v_new_momentum:=greatest(0,least(100,round(coalesce(v_pair.momentum,50)*.70+v_result_score*.30)::int));
  v_new_chemistry:=greatest(35,least(99,
    coalesce(v_pair.chemistry,60)+v_delta+case when coalesce(v_pair.events_played,0)>=3 and v_delta>=0 then 1 else 0 end
  ));
  v_new_strength:=greatest(35,least(99,
    coalesce(v_pair.pair_strength,60)+case when v_delta>=4 then 2 when v_delta>=1 then 1 when v_delta<=-2 then -1 else 0 end
  ));

  update doubles_partnerships
  set events_played=events_played+1,finals=finals+v_final,titles=titles+v_title,
      momentum=v_new_momentum,chemistry=v_new_chemistry,pair_strength=v_new_strength,last_played=v_date
  where id=v_pair.id;

  update player_doubles_commitments
  set commitment=greatest(35,least(100,commitment+v_delta+case when v_title=1 then 2 else 0 end)),
      affinity=greatest(30,least(100,affinity+case when v_delta>=3 then 2 when v_delta>=1 then 1 when v_delta<=-2 then -1 else 0 end)),
      last_review_date=v_date,
      reason=case
        when v_title=1 then 'La paire gagne en engagement après un titre.'
        when v_run.user_round='F' then 'La paire se renforce après une finale.'
        when v_delta<0 then 'La paire traverse une période sportive moins convaincante.'
        else reason end,
      updated_at=now()
  where active=true
    and season=extract(year from v_date)::int
    and (
      (player_id=v_managed and primary_partner_id=v_run.partner_id)
      or (player_id=v_run.partner_id and primary_partner_id=v_managed)
    );

  update player_relationships
  set affinity=greatest(0,least(100,affinity+case when v_delta>=3 then 2 when v_delta>=1 then 1 when v_delta<=-2 then -1 else 0 end)),
      trust=greatest(0,least(100,trust+case when v_delta>=3 then 2 when v_delta>=1 then 1 when v_delta<=-2 then -1 else 0 end)),
      closeness=greatest(0,least(100,closeness+case when v_title=1 then 3 when v_delta>=1 then 1 when v_delta<=-2 then -1 else 0 end)),
      last_update=v_date
  where player_a_id=least(v_managed,v_run.partner_id)
    and player_b_id=greatest(v_managed,v_run.partner_id);

  return jsonb_build_object(
    'ok',true,'run_id',v_run.id,'managed_player_id',v_managed,'round',v_run.user_round,
    'commitment_delta',v_delta,'title_added',v_title,'final_added',v_final,
    'momentum',v_new_momentum,'chemistry',v_new_chemistry,'pair_strength',v_new_strength,
    'events_played',coalesce(v_pair.events_played,0)+1,
    'titles',coalesce(v_pair.titles,0)+v_title,'finals',coalesce(v_pair.finals,0)+v_final
  );
end
$function$;
