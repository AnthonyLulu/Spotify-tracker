-- Career OS interactive media decisions.
alter table public.media_events
  add column if not exists response_status text not null default 'pending',
  add column if not exists response_choice text,
  add column if not exists response_at timestamptz,
  add column if not exists morale_delta integer not null default 0,
  add column if not exists reputation_delta integer not null default 0;

CREATE OR REPLACE FUNCTION public.resolve_managed_media_event(p_event_id bigint, p_choice text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  e public.media_events%rowtype;
  c public.career_state%rowtype;
  v_choice text:=lower(trim(coalesce(p_choice,'')));
  v_morale int:=0;
  v_rep int:=0;
  v_fatigue int:=0;
begin
  select * into e from public.media_events where id=p_event_id;
  if not found then return jsonb_build_object('ok',false,'reason','event_not_found'); end if;
  if e.response_status='resolved' then
    return jsonb_build_object('ok',true,'already_resolved',true,'choice',e.response_choice);
  end if;

  select * into c from public.career_state where id='demo';
  if not found or c.managed_player_id is null then
    return jsonb_build_object('ok',false,'reason','career_missing');
  end if;
  if e.related_player_id is not null and e.related_player_id<>c.managed_player_id then
    return jsonb_build_object('ok',false,'reason','not_managed_event');
  end if;

  if v_choice='professionnel' then
    v_morale:=1; v_rep:=2;
  elsif v_choice='ambitieux' then
    v_morale:=2; v_rep:=3; v_fatigue:=1;
  elsif v_choice='combatif' then
    v_morale:=3; v_rep:=1; v_fatigue:=1;
  elsif v_choice='calme' then
    v_morale:=2; v_rep:=1; v_fatigue:=-1;
  else
    return jsonb_build_object('ok',false,'reason','invalid_choice');
  end if;

  update public.career_state
  set morale=greatest(0,least(100,coalesce(morale,70)+v_morale)),
      fatigue=greatest(0,least(100,coalesce(fatigue,20)+v_fatigue)),
      updated_at=now()
  where id='demo';

  update public.player_reputation_profiles
  set sporting_reputation=greatest(0,least(100,coalesce(sporting_reputation,40)+v_rep)),
      global_popularity=greatest(0,least(100,coalesce(global_popularity,30)+case when v_choice='ambitieux' then 2 else 1 end)),
      media_presence=greatest(0,least(100,coalesce(media_presence,30)+2)),
      marketability=greatest(0,least(100,coalesce(marketability,30)+case when v_choice in ('professionnel','ambitieux') then 2 else 1 end)),
      last_update=coalesce(e.event_date,current_date),
      updated_at=now()
  where player_id=c.managed_player_id;

  update public.media_events
  set response_status='resolved',response_choice=v_choice,response_at=now(),
      morale_delta=v_morale,reputation_delta=v_rep
  where id=p_event_id;

  insert into public.career_event_log(event_date,week,system,event_type,entity_type,entity_id,summary,payload)
  values(
    coalesce(e.event_date,c.career_date,current_date),coalesce(c.week,1),'media','media_response',
    'media_event',p_event_id,'Réponse média · '||v_choice,
    jsonb_build_object('choice',v_choice,'morale_delta',v_morale,'reputation_delta',v_rep,'fatigue_delta',v_fatigue)
  );

  return jsonb_build_object(
    'ok',true,'choice',v_choice,'morale_delta',v_morale,
    'reputation_delta',v_rep,'fatigue_delta',v_fatigue
  );
end;
$function$;
