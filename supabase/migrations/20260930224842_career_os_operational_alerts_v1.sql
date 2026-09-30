create or replace function public.career_sync_operational_alerts(p_date date,p_week integer)
returns jsonb
language plpgsql
set search_path to 'public'
as $function$
declare
  c public.career_state%rowtype;
  v_tournaments integer:=0;
  v_board integer:=0;
begin
  select * into c from public.career_state where id='demo';
  if not found then
    return jsonb_build_object('ok',false,'reason','career_missing','model','CB-CAREER-OPS-v2');
  end if;

  if c.managed_player_id is not null then
    insert into public.inbox_items(
      kind,title,body,action_route,is_read,game_date,priority,
      action_type,action_label,action_payload,decision_status,
      related_entity_type,related_entity_id,expires_at
    )
    select
      'tournament',
      'Deadline tournoi · '||x.name,
      'Date limite le '||to_char(x.deadline,'DD/MM/YYYY')||'. '||
        coalesce(x.category,x.circuit,'Tournoi')||' · début '||to_char(x.start_date,'DD/MM/YYYY')||
        ' · voie actuelle : '||case x.path_priority when 0 then 'tableau principal' when 1 then 'qualifications' else 'liste alternates' end||
        '. Vérifie le cut et ton calendrier avant de t’inscrire.',
      'calendar',false,p_date,
      case when x.deadline<=p_date+3 then 'urgent' else 'high' end,
      'open_route','Voir le calendrier',jsonb_build_object('route','calendar'),'info',
      'tournament_deadline',x.id,x.deadline
    from (
      select z.*
      from (
        select
          t.id,t.name,t.circuit,t.category,t.start_date,
          coalesce(t.singles_entry_deadline,t.main_entry_deadline,t.qualifying_entry_deadline,t.late_entry_deadline) as deadline,
          case
            when coalesce((public.player_event_eligibility(c.managed_player_id,t.id,'singles','direct')->>'eligible')::boolean,false) then 0
            when coalesce((public.player_event_eligibility(c.managed_player_id,t.id,'singles','qualifying')->>'eligible')::boolean,false) then 1
            when coalesce((public.player_event_eligibility(c.managed_player_id,t.id,'singles','alternate')->>'eligible')::boolean,false) then 2
            else 9
          end as path_priority
        from public.tournaments t
        where t.is_active=true
          and t.circuit in ('ATP','Challenger','ITF')
          and coalesce(t.category,'') not ilike '%United Cup%'
          and coalesce(t.category,'') not ilike '%Laver%'
          and coalesce(t.category,'') not ilike '%Finals%'
          and t.start_date>=p_date
          and coalesce(t.singles_entry_deadline,t.main_entry_deadline,t.qualifying_entry_deadline,t.late_entry_deadline)
                between p_date and p_date+14
          and not exists(
            select 1 from public.entries e
            where e.player_id=c.managed_player_id
              and e.tournament_id=t.id
              and e.status='entered'
          )
          and not exists(
            select 1 from public.inbox_items i
            where i.related_entity_type='tournament_deadline'
              and i.related_entity_id=t.id
              and i.decision_status<>'expired'
          )
      ) z
      where z.path_priority<9
      order by z.path_priority,z.deadline,z.start_date,z.id
      limit 3
    ) x;
    get diagnostics v_tournaments=row_count;
  end if;

  insert into public.inbox_items(
    kind,title,body,action_route,is_read,game_date,priority,
    action_type,action_label,action_payload,decision_status,
    related_entity_type,related_entity_id,expires_at
  )
  select
    'board',
    'Objectif sous surveillance · '||b.objective,
    'Progression '||coalesce(b.progress,0)::text||'% · échéance '||to_char(b.deadline,'DD/MM/YYYY')||
      '. '||coalesce(b.target_value,''),
    'board',false,p_date,
    case when b.deadline<=p_date+14 or coalesce(b.progress,0)<40 then 'urgent' else 'high' end,
    'open_route','Voir les objectifs',jsonb_build_object('route','board'),'info',
    'board_objective',b.id,b.deadline
  from public.board_objectives b
  where b.status='active'
    and b.deadline between p_date and p_date+56
    and coalesce(b.progress,0)<80
    and not exists(
      select 1 from public.inbox_items i
      where i.related_entity_type='board_objective'
        and i.related_entity_id=b.id
        and i.game_date>=p_date-28
    );
  get diagnostics v_board=row_count;

  if v_tournaments+v_board>0 then
    insert into public.career_event_log(event_date,week,system,event_type,summary,payload)
    values(
      p_date,p_week,'career','operational_alerts','Alertes opérationnelles Career OS',
      jsonb_build_object('tournament_deadlines',v_tournaments,'board_warnings',v_board)
    );
  end if;

  return jsonb_build_object(
    'ok',true,
    'tournament_deadlines',v_tournaments,
    'board_warnings',v_board,
    'created',v_tournaments+v_board,
    'model','CB-CAREER-OPS-v2'
  );
end;
$function$;
