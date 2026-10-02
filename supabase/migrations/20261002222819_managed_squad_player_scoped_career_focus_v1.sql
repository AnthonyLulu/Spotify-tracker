create or replace function public.set_player_career_focus(
  p_player_id bigint,
  p_focus text,
  p_date date default current_date
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_focus text:=lower(trim(coalesce(p_focus,'')));
  v_date date:=coalesce(p_date,current_date);
  v_old text;
  v_reason text;
begin
  if p_player_id is null or not exists(select 1 from public.players where id=p_player_id) then
    raise exception 'Player missing';
  end if;
  if v_focus not in ('singles_only','singles_priority','mixed','doubles_only') then
    raise exception 'Orientation de carrière invalide';
  end if;

  select coalesce(career_focus,'mixed') into v_old
  from public.players where id=p_player_id;

  v_reason:=case v_focus
    when 'singles_only' then 'Le joueur choisit de se consacrer exclusivement au simple.'
    when 'singles_priority' then 'Le joueur donne la priorité au simple tout en gardant le double disponible.'
    when 'doubles_only' then 'Le joueur choisit une carrière exclusivement en double.'
    else 'Le joueur poursuit un programme mixte simple et double.'
  end;

  if coalesce(v_old,'mixed')<>v_focus then
    insert into public.player_career_focus_history(
      player_id,changed_at,from_focus,to_focus,reason,source
    ) values(
      p_player_id,v_date,coalesce(v_old,'mixed'),v_focus,v_reason,'Utilisateur · groupe géré'
    );
  end if;

  update public.players
  set career_focus=v_focus,
      career_focus_changed_at=case when coalesce(v_old,'mixed')<>v_focus then v_date else career_focus_changed_at end,
      career_focus_reason=v_reason,
      career_focus_source='Utilisateur · groupe géré'
  where id=p_player_id;

  if v_focus='singles_only' then
    insert into public.player_doubles_partner_history(
      player_id,partner_id,start_date,end_date,season,
      affinity_start,affinity_end,reason,source_label
    )
    select
      c.player_id,c.primary_partner_id,c.started_at,v_date,c.season,
      c.affinity,c.affinity,
      'Fin du partenariat : choix Simple exclusivement.',
      'Utilisateur · groupe géré · carrière simple exclusivement'
    from public.player_doubles_commitments c
    where c.player_id=p_player_id and c.active=true;

    update public.player_doubles_commitments
    set active=false,last_review_date=v_date,
        reason='Fin du partenariat : choix Simple exclusivement.',
        updated_at=now()
    where player_id=p_player_id and active=true;

    delete from public.doubles_partnerships
    where player_a_id=p_player_id or player_b_id=p_player_id;

    update public.doubles_partner_offers
    set status='withdrawn',response_date=v_date
    where status='pending'
      and (from_player_id=p_player_id or to_player_id=p_player_id);
  end if;

  return jsonb_build_object(
    'ok',true,'player_id',p_player_id,'focus',v_focus,
    'previous',coalesce(v_old,'mixed'),
    'changed',coalesce(v_old,'mixed')<>v_focus,
    'changed_at',v_date,'reason',v_reason
  );
end
$function$;

revoke all on function public.set_player_career_focus(bigint,text,date) from public,anon,authenticated;
grant execute on function public.set_player_career_focus(bigint,text,date) to service_role;
