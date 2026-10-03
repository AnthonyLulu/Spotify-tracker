-- Court Boss · Next Gen Finals Race selection v4
-- Canonicalizes the live implementation after the temporary ATP-ranking prototype.
-- The Next Gen Race reuses the normal ATP Race season-point ledger, then applies the age filter.
-- Finals field: 7 Race qualifiers + 1 ATP wildcard, managed invitations, limited AI refusals.

alter table public.nextgen_finals_invitations
  add column if not exists nextgen_rank integer,
  add column if not exists nextgen_points numeric,
  add column if not exists selection_method text;

drop function if exists public.nextgen_finals_field(bigint);
drop function if exists public.nextgen_finals_candidate_pool(bigint);

CREATE OR REPLACE FUNCTION public.nextgen_finals_ai_refusal(p_tournament_id bigint, p_player_id bigint, p_atp_rank integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  p public.players%rowtype;
  prob numeric:=0.01;
  roll numeric;
  reason text:='available';
begin
  select * into p from public.players where id=p_player_id;
  if p.id is null then
    return jsonb_build_object('accept',false,'probability',1,'reason','missing_player');
  end if;

  if coalesce(p.injury_status,'Fit')<>'Fit' or coalesce(p.fitness,90)<45 then
    return jsonb_build_object('accept',false,'probability',1,'reason','physical_unavailable');
  end if;

  prob:=case
    when coalesce(p.race_ranking,999999)<=8 then .35
    when p_atp_rank<=5 then .12
    when p_atp_rank<=10 then .08
    when p_atp_rank<=20 then .04
    else .01
  end;

  if coalesce(p.fatigue,20)>=70 then prob:=prob+.04; end if;
  if coalesce(p.form,70)>=85 then prob:=prob-.02; end if;
  prob:=greatest(.005,least(.42,prob));

  roll:=mod(abs(hashtext('nextgen-finals-refusal|'||p_tournament_id||'|'||p_player_id))::bigint,10000)/10000.0;

  if roll<prob then
    reason:=case
      when coalesce(p.race_ranking,999999)<=8 then 'nitto_finals_priority'
      when coalesce(p.fatigue,20)>=70 then 'schedule_and_fatigue'
      when p_atp_rank<=10 then 'elite_schedule_choice'
      else 'schedule_choice'
    end;
  end if;

  return jsonb_build_object(
    'accept',roll>=prob,
    'probability',round(prob,4),
    'roll',round(roll,4),
    'reason',reason,
    'atp_rank',p_atp_rank,
    'atp_race_rank',coalesce(p.race_ranking,999999),
    'nextgen_rank',p.nextgen_ranking
  );
end;
$function$


CREATE OR REPLACE FUNCTION public.nextgen_finals_candidate_pool(p_tournament_id bigint)
 RETURNS TABLE(player_id bigint, player_name text, country text, atp_rank integer, nextgen_rank integer, nextgen_points numeric, is_managed boolean, injury_status text, fitness integer, fatigue integer, race_ranking integer, current_ability integer, form integer)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  with event as (
    select id,start_date,extract(year from start_date)::int season
    from public.tournaments
    where id=p_tournament_id
      and circuit='ATP'
      and category='Next Gen Finals'
    limit 1
  )
  select
    p.id,
    p.name,
    p.country,
    coalesce(
      public.player_rank_at_date(p.id,e.start_date-1),
      p.game_world_rank,
      case when p.ranking_current then p.ranking end,
      p.ranking,
      999999
    )::int as atp_rank,
    p.nextgen_ranking::int,
    coalesce(p.nextgen_points,0)::numeric,
    public.nextgen_is_managed_player(p.id),
    coalesce(p.injury_status,'Fit'),
    coalesce(p.fitness,90)::int,
    coalesce(p.fatigue,20)::int,
    coalesce(p.race_ranking,999999)::int,
    coalesce(p.current_ability,50)::int,
    coalesce(p.form,70)::int
  from public.players p
  cross join event e
  where public.nextgen_player_eligible(p.id,e.season)
    and p.career_status='active'
    and p.nextgen_ranking is not null
    and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
  order by p.nextgen_ranking,p.id;
$function$


CREATE OR REPLACE FUNCTION public.nextgen_fill_finals_slot(p_tournament_id bigint, p_field_slot integer, p_invited_on date, p_allow_managed_pending boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  rec record;
  ai jsonb;
  v_refusals int:=0;
  v_inv_id bigint;
  v_respond_by date;
  v_method text;
begin
  if p_field_slot not between 1 and 8 then
    return jsonb_build_object('ok',false,'reason','invalid_slot');
  end if;

  v_method:=case when p_field_slot=8 then 'atp_wildcard' else 'race_direct' end;

  if exists(
    select 1 from public.nextgen_finals_invitations
    where tournament_id=p_tournament_id
      and field_slot=p_field_slot
      and status in ('pending','accepted')
  ) then
    return jsonb_build_object('ok',true,'already_reserved',true,'slot',p_field_slot);
  end if;

  select count(*) into v_refusals
  from public.nextgen_finals_invitations
  where tournament_id=p_tournament_id and status='ai_declined';

  for rec in
    select c.*,
      row_number() over(
        order by
          case when v_method='race_direct' then c.nextgen_rank else 999999 end asc,
          case when v_method='atp_wildcard' then c.atp_rank else 999999 end asc,
          case when v_method='atp_wildcard' then c.form else 0 end desc,
          case when v_method='atp_wildcard' then c.current_ability else 0 end desc,
          c.player_id
      )::int as selection_order
    from public.nextgen_finals_candidate_pool(p_tournament_id) c
    where not exists(
      select 1 from public.nextgen_finals_invitations i
      where i.tournament_id=p_tournament_id and i.player_id=c.player_id
    )
    order by
      case when v_method='race_direct' then c.nextgen_rank else 999999 end asc,
      case when v_method='atp_wildcard' then c.atp_rank else 999999 end asc,
      case when v_method='atp_wildcard' then c.form else 0 end desc,
      case when v_method='atp_wildcard' then c.current_ability else 0 end desc,
      c.player_id
  loop
    if rec.injury_status<>'Fit' or rec.fitness<45 then
      insert into public.nextgen_finals_invitations(
        tournament_id,player_id,field_slot,atp_rank,nextgen_rank,nextgen_points,
        selection_order,selection_method,is_managed,status,invited_on,responded_on,
        refusal_probability,refusal_reason,decision_meta
      ) values(
        p_tournament_id,rec.player_id,p_field_slot,rec.atp_rank,rec.nextgen_rank,rec.nextgen_points,
        rec.selection_order,v_method,rec.is_managed,'unavailable',p_invited_on,p_invited_on,
        1,'physical_unavailable',
        jsonb_build_object('injury_status',rec.injury_status,'fitness',rec.fitness)
      );
      continue;
    end if;

    if rec.is_managed and p_allow_managed_pending then
      select least(t.start_date-2,p_invited_on+7)
      into v_respond_by
      from public.tournaments t where t.id=p_tournament_id;
      v_respond_by:=greatest(p_invited_on,v_respond_by);

      insert into public.nextgen_finals_invitations(
        tournament_id,player_id,field_slot,atp_rank,nextgen_rank,nextgen_points,
        selection_order,selection_method,is_managed,status,invited_on,respond_by,
        refusal_probability,refusal_reason
      ) values(
        p_tournament_id,rec.player_id,p_field_slot,rec.atp_rank,rec.nextgen_rank,rec.nextgen_points,
        rec.selection_order,v_method,true,'pending',p_invited_on,v_respond_by,
        null,'managed_decision'
      )
      returning id into v_inv_id;

      insert into public.inbox_items(
        kind,title,body,action_route,game_date,priority,is_read,
        action_type,action_label,action_payload,
        secondary_action_type,secondary_action_label,secondary_action_payload,
        decision_status,related_entity_type,related_entity_id,expires_at
      ) values(
        'selection','Next Gen ATP Finals · sélection',
        rec.player_name||' est appelé pour les Next Gen ATP Finals. '||
        case when v_method='race_direct'
          then 'Race Next Gen #'||rec.nextgen_rank||' · '||round(rec.nextgen_points)||' pts.'
          else 'Wild card ATP · Race Next Gen #'||rec.nextgen_rank||'.'
        end||
        ' Tu peux accepter ou refuser.',
        'calendar',p_invited_on,'high',false,
        'respond_nextgen_finals_invitation','Accepter',
        jsonb_build_object('invitation_id',v_inv_id,'decision','accept','player_id',rec.player_id,'tournament_id',p_tournament_id),
        'respond_nextgen_finals_invitation','Refuser',
        jsonb_build_object('invitation_id',v_inv_id,'decision','decline','player_id',rec.player_id,'tournament_id',p_tournament_id),
        'pending','nextgen_finals_invitation',v_inv_id,v_respond_by
      );

      return jsonb_build_object(
        'ok',true,'pending',true,'managed',true,'invitation_id',v_inv_id,
        'player_id',rec.player_id,'slot',p_field_slot,'atp_rank',rec.atp_rank,
        'nextgen_rank',rec.nextgen_rank,'nextgen_points',rec.nextgen_points,
        'selection_method',v_method
      );
    end if;

    if rec.is_managed and not p_allow_managed_pending then
      insert into public.nextgen_finals_invitations(
        tournament_id,player_id,field_slot,atp_rank,nextgen_rank,nextgen_points,
        selection_order,selection_method,is_managed,status,invited_on,responded_on,
        refusal_probability,refusal_reason
      ) values(
        p_tournament_id,rec.player_id,p_field_slot,rec.atp_rank,rec.nextgen_rank,rec.nextgen_points,
        rec.selection_order,v_method,true,'expired',p_invited_on,p_invited_on,null,'managed_window_closed'
      );
      continue;
    end if;

    ai:=public.nextgen_finals_ai_refusal(p_tournament_id,rec.player_id,rec.atp_rank);

    if coalesce((ai->>'accept')::boolean,true)=false and v_refusals<2 then
      insert into public.nextgen_finals_invitations(
        tournament_id,player_id,field_slot,atp_rank,nextgen_rank,nextgen_points,
        selection_order,selection_method,is_managed,status,invited_on,responded_on,
        refusal_probability,refusal_reason,decision_meta
      ) values(
        p_tournament_id,rec.player_id,p_field_slot,rec.atp_rank,rec.nextgen_rank,rec.nextgen_points,
        rec.selection_order,v_method,false,'ai_declined',p_invited_on,p_invited_on,
        (ai->>'probability')::numeric,coalesce(ai->>'reason','declined'),ai
      );
      v_refusals:=v_refusals+1;
      continue;
    end if;

    insert into public.nextgen_finals_invitations(
      tournament_id,player_id,field_slot,atp_rank,nextgen_rank,nextgen_points,
      selection_order,selection_method,is_managed,status,invited_on,responded_on,
      refusal_probability,refusal_reason,decision_meta
    ) values(
      p_tournament_id,rec.player_id,p_field_slot,rec.atp_rank,rec.nextgen_rank,rec.nextgen_points,
      rec.selection_order,v_method,false,'accepted',p_invited_on,p_invited_on,
      (ai->>'probability')::numeric,
      case when coalesce((ai->>'accept')::boolean,true)=false
        then 'refusal_cap_reached'
        else 'accepted'
      end,
      ai||jsonb_build_object('refusal_cap',2,'forced_by_cap',coalesce((ai->>'accept')::boolean,true)=false)
    )
    returning id into v_inv_id;

    return jsonb_build_object(
      'ok',true,'accepted',true,'managed',false,'invitation_id',v_inv_id,
      'player_id',rec.player_id,'slot',p_field_slot,'atp_rank',rec.atp_rank,
      'nextgen_rank',rec.nextgen_rank,'nextgen_points',rec.nextgen_points,
      'selection_method',v_method,'ai',ai,'refusals_used',v_refusals
    );
  end loop;

  return jsonb_build_object('ok',false,'reason','candidate_pool_exhausted','slot',p_field_slot);
end;
$function$


CREATE OR REPLACE FUNCTION public.prepare_nextgen_finals_selection(p_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  season int;
  game_date date;
  opens_on date;
  invited_on date;
  slot int;
  r jsonb;
  reserved int;
  accepted int;
  pending int;
  declined int;
  race_refresh jsonb;
begin
  select * into t
  from public.tournaments
  where id=p_tournament_id and circuit='ATP' and category='Next Gen Finals';

  if t.id is null then
    return jsonb_build_object('ok',false,'reason','not_nextgen_finals');
  end if;

  season:=extract(year from t.start_date)::int;
  game_date:=coalesce(
    (select career_date from public.career_state where id='demo'),
    t.start_date-21
  );
  opens_on:=t.start_date-21;

  if game_date<opens_on then
    return jsonb_build_object(
      'ok',true,'not_due',true,'tournament_id',t.id,'season',season,
      'opens_on',opens_on,
      'rule','7 Race Next Gen + 1 ATP wild card'
    );
  end if;

  invited_on:=least(game_date,t.start_date-2);
  race_refresh:=public.refresh_world_nextgen_race(invited_on);

  for slot in 1..8 loop
    if not exists(
      select 1 from public.nextgen_finals_invitations
      where tournament_id=t.id and field_slot=slot and status in ('pending','accepted')
    ) then
      r:=public.nextgen_fill_finals_slot(t.id,slot,invited_on,true);
      if coalesce((r->>'ok')::boolean,false)=false then
        return jsonb_build_object('ok',false,'reason','slot_fill_failed','slot',slot,'details',r);
      end if;
    end if;
  end loop;

  select count(*) into accepted
  from public.nextgen_finals_invitations
  where tournament_id=t.id and status='accepted';

  select count(*) into pending
  from public.nextgen_finals_invitations
  where tournament_id=t.id and status='pending';

  select count(*) into declined
  from public.nextgen_finals_invitations
  where tournament_id=t.id and status='ai_declined';

  reserved:=accepted+pending;

  return jsonb_build_object(
    'ok',reserved=8,
    'tournament_id',t.id,
    'season',season,
    'opens_on',opens_on,
    'invited_on',invited_on,
    'accepted',accepted,
    'pending_managed',pending,
    'reserved',reserved,
    'ai_refusals',declined,
    'max_ai_refusals',2,
    'points_engine','same season points as ATP Race',
    'race_refresh',race_refresh,
    'rule','7 Race Next Gen + 1 ATP wild card · refusal/forfeit = next eligible'
  );
end;
$function$


CREATE OR REPLACE FUNCTION public.nextgen_finals_field(p_tournament_id bigint)
 RETURNS TABLE(player_id bigint, player_name text, country text, field_slot integer, atp_rank integer, nextgen_rank integer, nextgen_points numeric, selection_status text, selection_method text, is_managed boolean)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select
    i.player_id,
    p.name,
    p.country,
    i.field_slot,
    i.atp_rank,
    i.nextgen_rank,
    i.nextgen_points,
    i.status,
    coalesce(i.selection_method,case when i.field_slot=8 then 'atp_wildcard' else 'race_direct' end),
    i.is_managed
  from public.nextgen_finals_invitations i
  join public.players p on p.id=i.player_id
  where i.tournament_id=p_tournament_id
    and i.status in ('accepted','pending')
  order by i.field_slot;
$function$


CREATE OR REPLACE FUNCTION public.nextgen_finals_player_status(p_tournament_id bigint, p_player_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  rowv record;
  season int;
  elig boolean;
begin
  select extract(year from start_date)::int into season
  from public.tournaments
  where id=p_tournament_id and circuit='ATP' and category='Next Gen Finals';

  if season is null then return jsonb_build_object('ok',false,'reason','not_nextgen_finals'); end if;
  elig:=public.nextgen_player_eligible(p_player_id,season);

  select * into rowv
  from public.nextgen_finals_invitations
  where tournament_id=p_tournament_id and player_id=p_player_id
  order by id desc limit 1;

  return jsonb_build_object(
    'ok',true,
    'eligible_age',coalesce(elig,false),
    'selected',rowv.status in ('accepted','pending'),
    'status',rowv.status,
    'field_slot',rowv.field_slot,
    'atp_rank',rowv.atp_rank,
    'nextgen_rank',rowv.nextgen_rank,
    'nextgen_points',rowv.nextgen_points,
    'selection_method',rowv.selection_method,
    'managed',rowv.is_managed,
    'rule','7 Race Next Gen + 1 ATP wild card'
  );
end;
$function$


update public.tournament_format_rules
set wildcard_count=1,
    wildcard_count_max=1,
    source_label='ATP 2026 Rulebook · Next Gen Finals · 7 Race direct acceptances + 1 ATP wildcard',
    source_url='https://www.atptour.com/-/media/files/rulebook/2026/2026-rulebook_25jan26.pdf',
    updated_at=now()
where rule_key='NEXTGEN_8';

update public.tournaments
set registration_mode='nextgen_selection',
    main_entry_deadline=null,
    singles_entry_deadline=null,
    qualifying_entry_deadline=null,
    entry_rule_note='Next Gen ATP Finals: Race Next Gen basée sur les mêmes points de saison que la Race ATP, filtrée par âge. 7 qualifiés via la Race Next Gen + 1 wild card ATP. Pas d’inscription manuelle. Un forfait/refus fait remonter le suivant de la Race. Les joueurs déjà qualifiés aux ATP Finals peuvent plus facilement décliner. Format: 2 groupes de 4, demi-finales et finale; BO5, sets à 4 jeux, tie-break à 3-3, no-ad; aucun point ATP.'
where circuit='ATP' and category='Next Gen Finals';
