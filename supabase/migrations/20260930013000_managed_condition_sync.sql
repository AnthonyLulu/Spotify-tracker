-- Court Boss managed-player condition synchronization
-- Ensures career_state and players share one condition state across manual matches,
-- world simulation, injuries, recovery and medical treatment.

CREATE OR REPLACE FUNCTION public.sync_managed_condition_from_player()
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_player_id bigint;
  p public.players%rowtype;
  v_rows int:=0;
begin
  select managed_player_id into v_player_id
  from public.career_state
  where id='demo';

  if v_player_id is null then
    return jsonb_build_object('ok',false,'reason','managed_player_missing');
  end if;

  select * into p
  from public.players
  where id=v_player_id;

  if p.id is null then
    return jsonb_build_object('ok',false,'reason','player_missing','player_id',v_player_id);
  end if;

  update public.career_state
  set fatigue=coalesce(p.fatigue,fatigue),
      fitness=coalesce(p.fitness,fitness),
      form=coalesce(p.form,form),
      morale=coalesce(p.morale,morale),
      injury_status=coalesce(p.injury_status,injury_status,'Fit'),
      updated_at=now()
  where id='demo';

  get diagnostics v_rows=row_count;

  return jsonb_build_object(
    'ok',v_rows=1,
    'player_id',v_player_id,
    'fatigue',p.fatigue,
    'fitness',p.fitness,
    'form',p.form,
    'morale',p.morale,
    'injury_status',p.injury_status
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.sync_managed_condition_to_player()
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  c public.career_state%rowtype;
  v_rows int:=0;
begin
  select * into c
  from public.career_state
  where id='demo';

  if c.managed_player_id is null then
    return jsonb_build_object('ok',false,'reason','managed_player_missing');
  end if;

  update public.players p
  set fatigue=coalesce(c.fatigue,p.fatigue),
      fitness=coalesce(c.fitness,p.fitness),
      form=coalesce(c.form,p.form),
      morale=coalesce(c.morale,p.morale),
      injury_status=coalesce(c.injury_status,p.injury_status,'Fit')
  where p.id=c.managed_player_id;

  get diagnostics v_rows=row_count;

  return jsonb_build_object(
    'ok',v_rows=1,
    'player_id',c.managed_player_id,
    'fatigue',c.fatigue,
    'fitness',c.fitness,
    'form',c.form,
    'morale',c.morale,
    'injury_status',c.injury_status
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.trg_sync_managed_condition_to_player()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  if new.id='demo' and new.managed_player_id is not null then
    update public.players p
    set fatigue=coalesce(new.fatigue,p.fatigue),
        fitness=coalesce(new.fitness,p.fitness),
        form=coalesce(new.form,p.form),
        morale=coalesce(new.morale,p.morale),
        injury_status=coalesce(new.injury_status,p.injury_status,'Fit')
    where p.id=new.managed_player_id;
  end if;
  return new;
end;
$function$;

drop trigger if exists career_state_condition_sync_trg on public.career_state;
create trigger career_state_condition_sync_trg
after insert or update of managed_player_id,fatigue,fitness,form,morale,injury_status
on public.career_state
for each row
execute function public.trg_sync_managed_condition_to_player();

select public.sync_managed_condition_to_player();
