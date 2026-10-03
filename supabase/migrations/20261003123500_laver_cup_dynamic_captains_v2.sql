-- Court Boss · dynamic Laver Cup captains v2
-- 3-year legend rotation, save-world retirees, captain selection personality,
-- appointment news and captain attribution in edition history.

create or replace function public.laver_cup_captain_pick_score(
  p_player_id bigint,
  p_team_code text,
  p_season integer,
  p_selection_date date,
  p_base_score numeric
)
returns numeric
language plpgsql
stable
set search_path='public'
as $function$
declare
  v_start integer:=public.laver_cup_term_start(p_season);
  bias jsonb:='{}'::jsonb;
  rank_w numeric:=1;
  form_w numeric:=1;
  big_w numeric:=1;
  dbl_w numeric:=1;
  youth_w numeric:=1;
  rankv integer:=999;
  formv numeric:=70;
  bigv numeric:=10;
  dblv numeric:=10;
  agev integer:=27;
  score numeric:=coalesce(p_base_score,0);
begin
  select coalesce(c.selection_bias,'{}'::jsonb)
  into bias
  from public.laver_cup_captain_terms c
  where c.team_code=p_team_code and c.term_start_season=v_start
  limit 1;

  rank_w:=coalesce((bias->>'rank')::numeric,1);
  form_w:=coalesce((bias->>'form')::numeric,1);
  big_w:=coalesce((bias->>'big_points')::numeric,1);
  dbl_w:=coalesce((bias->>'doubles')::numeric,1);
  youth_w:=coalesce((bias->>'youth')::numeric,1);

  select
    coalesce(
      public.player_rank_at_date(p.id,p_selection_date),
      case when p.ranking_current then p.ranking end,
      p.game_world_rank,p.ranking,999
    )::int,
    coalesce(p.form,70)::numeric,
    coalesce(pa.big_points,10)::numeric,
    coalesce(pa.doubles,10)::numeric,
    coalesce(
      case when p.birth_date is not null
        then extract(year from age(p_selection_date,p.birth_date))::int
      end,
      p.age,27
    )::int
  into rankv,formv,bigv,dblv,agev
  from public.players p
  left join public.player_attributes pa on pa.player_id=p.id
  where p.id=p_player_id;

  if not found then return score; end if;

  score:=score
    + greatest(0,100-least(rankv,100))*(rank_w-1)*0.18
    + (formv-60)*(form_w-1)*0.18
    + bigv*(big_w-1)*0.50
    + dblv*(dbl_w-1)*0.45
    + greatest(0,24-agev)*(youth_w-1)*0.90;

  return round(score,3);
end;
$function$;

create or replace function public.ensure_laver_cup_captains(p_season integer)
returns jsonb
language plpgsql
set search_path='public'
as $function$
declare
  v_start integer := public.laver_cup_term_start(p_season);
  v_end integer := public.laver_cup_term_start(p_season)+2;
  v_team text;
  v_player bigint;
  v_prev bigint;
  v_score numeric;
  v_style jsonb;
  v_created integer := 0;
  v_term_id bigint;
  v_player_name text;
  v_news_date date;
begin
  if v_start=2025 then
    insert into public.laver_cup_captain_terms(
      team_code,term_start_season,term_end_season,captain_player_id,appointed_on,
      captain_style,style_label,selection_bias,legend_score,appointment_source,historical_baseline
    )
    select 'EUROPE',2025,2027,p.id,date '2025-01-01',
      'connector','Leadership & cohésion',
      jsonb_build_object('code','connector','label','Leadership & cohésion','rank',1.0,'form',1.1,'big_points',1.0,'doubles',1.0,'youth',1.0),
      100,'official_baseline',true
    from public.players p
    where p.name='Yannick Noah'
      and p.career_status='retired'
      and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
    order by p.is_real desc,p.id
    limit 1
    on conflict(team_code,term_start_season) do nothing;

    insert into public.laver_cup_captain_terms(
      team_code,term_start_season,term_end_season,captain_player_id,appointed_on,
      captain_style,style_label,selection_bias,legend_score,appointment_source,historical_baseline
    )
    select 'WORLD',2025,2027,p.id,date '2025-01-01',
      'big_match','Grands rendez-vous',
      jsonb_build_object('code','big_match','label','Grands rendez-vous','rank',1.0,'form',0.95,'big_points',1.35,'doubles',0.9,'youth',0.85),
      100,'official_baseline',true
    from public.players p
    where p.name='Andre Agassi'
      and p.career_status='retired'
      and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
    order by p.is_real desc,p.id
    limit 1
    on conflict(team_code,term_start_season) do nothing;
  end if;

  for v_team in select unnest(array['EUROPE','WORLD']) loop
    if exists(
      select 1 from public.laver_cup_captain_terms
      where team_code=v_team and term_start_season=v_start
    ) then
      continue;
    end if;

    select captain_player_id into v_prev
    from public.laver_cup_captain_terms
    where team_code=v_team and term_end_season=v_start-1
    limit 1;

    select x.id,x.legend_score
    into v_player,v_score
    from (
      select
        p.id,
        (
          case
            when coalesce(p.career_high_rank,9999)=1 then 100
            when coalesce(p.career_high_rank,9999)=2 then 88
            when coalesce(p.career_high_rank,9999)=3 then 80
            when coalesce(p.career_high_rank,9999)<=5 then 66
            when coalesce(p.career_high_rank,9999)<=10 then 48
            else 25
          end
          + least(30,coalesce(p.weeks_at_no1,0)*0.12)
          + least(28,coalesce(p.weeks_top10,0)*0.03)
          + case when coalesce(p.career_high_doubles_rank,9999)=1 then 8 else 0 end
          + mod(abs(hashtext('laver-captain|'||v_start||'|'||v_team||'|'||p.id))::bigint,1600)/100.0
        )::numeric as legend_score
      from public.players p
      where p.career_status='retired'
        and public.laver_region(p.country)=v_team
        and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
        and p.id is distinct from v_prev
        and (
          coalesce(p.career_high_rank,9999)<=5
          or coalesce(p.weeks_at_no1,0)>0
          or coalesce(p.weeks_top10,0)>=200
        )
        and (p.retired_date is null or p.retired_date <= make_date(v_start-1,12,31))
    ) x
    order by x.legend_score desc,x.id
    limit 1;

    if v_player is null then
      return jsonb_build_object(
        'ok',false,'reason','no_eligible_legend','team',v_team,
        'term_start',v_start,'previous_captain_id',v_prev
      );
    end if;

    v_style:=public.laver_cup_style_payload(v_player,v_start);

    insert into public.laver_cup_captain_terms(
      team_code,term_start_season,term_end_season,captain_player_id,appointed_on,
      captain_style,style_label,selection_bias,legend_score,appointment_source,historical_baseline
    ) values(
      v_team,v_start,v_end,v_player,make_date(v_start,1,1),
      v_style->>'code',v_style->>'label',v_style,v_score,'career_legend_rotation',false
    )
    returning id into v_term_id;

    select name into v_player_name from public.players where id=v_player;
    v_news_date:=coalesce(
      (select career_date from public.career_state where id='demo'),
      make_date(v_start,1,1)
    );

    insert into public.inbox_items(
      kind,title,body,action_route,game_date,priority,is_read,
      decision_status,related_entity_type,related_entity_id
    )
    select
      'selection',
      'Laver Cup · nouveau capitaine '||
        case when v_team='EUROPE' then 'Team Europe' else 'Team World' end,
      coalesce(v_player_name,'Une légende')||' prend les commandes de '||
        case when v_team='EUROPE' then 'Team Europe' else 'Team World' end||
        ' pour le mandat '||v_start||'–'||v_end||
        '. Style : '||coalesce(v_style->>'label','Leadership')||'.',
      'calendar',v_news_date,'normal',false,
      'info','laver_cup_captain_term',v_term_id
    where not exists(
      select 1 from public.inbox_items i
      where i.related_entity_type='laver_cup_captain_term'
        and i.related_entity_id=v_term_id
    );

    v_created:=v_created+1;
  end loop;

  return jsonb_build_object('ok',true,'term_start',v_start,'term_end',v_end,'created',v_created);
end;
$function$;

create or replace function public.prepare_laver_cup_roster(p_tournament_id bigint)
returns jsonb
language plpgsql
set search_path='public'
as $function$
declare
  t public.tournaments%rowtype;
  rg_end date;
  selection_date date;
  invite_date date;
  respond_by date;
  season integer;
  captain_ctx jsonb;
  team text;
  slot int;
  rec record;
  backup record;
  invitation_id bigint;
  filled boolean;
  backup_filled boolean;
  v_count int;
  pending_count int:=0;
  ai_declines int:=0;
  captain_id bigint;
  captain_name text;
  captain_style text;
begin
  select * into t
  from public.tournaments
  where id=p_tournament_id and category='Laver Cup' and coalesce(is_active,true)=true;

  if t.id is null then return jsonb_build_object('ok',false,'reason','not_laver_cup'); end if;

  if exists(select 1 from public.laver_cup_rosters where tournament_id=t.id) then
    return jsonb_build_object(
      'ok',true,'already',true,
      'europe',(select count(*) from public.laver_cup_rosters where tournament_id=t.id and team_code='EUROPE'),
      'world',(select count(*) from public.laver_cup_rosters where tournament_id=t.id and team_code='WORLD'),
      'pending_managed_invites',(select count(*) from public.laver_cup_invitations where tournament_id=t.id and status='pending' and is_managed)
    );
  end if;

  season:=extract(year from t.start_date)::int;
  captain_ctx:=public.laver_cup_captain_context(season);
  if coalesce((captain_ctx->>'ok')::boolean,false)=false then
    return jsonb_build_object('ok',false,'reason','captain_context_failed','captain_context',captain_ctx);
  end if;

  select max(end_date) into rg_end
  from public.tournaments
  where category='Grand Chelem'
    and name ilike '%Roland%'
    and extract(year from end_date)::int=season;

  selection_date:=coalesce(rg_end+1,make_date(season,6,8));
  select coalesce(career_date,selection_date) into invite_date
  from public.career_state where id='demo';
  invite_date:=coalesce(invite_date,selection_date);
  respond_by:=greatest(invite_date,least(t.start_date-2,invite_date+7));

  for team in select unnest(array['EUROPE','WORLD']) loop
    select c.captain_player_id,p.name,c.style_label
    into captain_id,captain_name,captain_style
    from public.laver_cup_captain_terms c
    join public.players p on p.id=c.captain_player_id
    where c.team_code=team and c.term_start_season=public.laver_cup_term_start(season)
    limit 1;

    for slot in 1..6 loop
      filled:=false;

      for rec in
        select c.*,
          case when slot>3
            then public.laver_cup_captain_pick_score(
              c.player_id,team,season,selection_date,c.selection_score
            )
            else c.selection_score
          end as final_selection_score
        from public.laver_candidate_pool(t.id,team,selection_date) c
        where not exists(
          select 1 from public.laver_cup_invitations i
          where i.tournament_id=t.id and i.player_id=c.player_id
        )
        and not exists(
          select 1 from public.laver_cup_rosters r
          where r.tournament_id=t.id and r.player_id=c.player_id
        )
        order by
          case when slot<=3 then c.ranking_at_selection else 999999 end asc,
          case when slot>3 then public.laver_cup_captain_pick_score(
            c.player_id,team,season,selection_date,c.selection_score
          ) else 0 end desc,
          c.ranking_at_selection asc,
          c.player_id
      loop
        if rec.is_managed then
          insert into public.laver_cup_invitations(
            tournament_id,team_code,player_id,roster_slot,selection_method,
            ranking_at_selection,selection_score,is_managed,status,
            invited_on,respond_by,acceptance_probability,response_reason
          ) values(
            t.id,team,rec.player_id,slot,
            case when slot<=3 then 'ranking_invitation' else 'captain_pick' end,
            rec.ranking_at_selection,rec.final_selection_score,true,'pending',
            invite_date,respond_by,null,
            case when slot<=3 then 'Décision du joueur géré'
              else 'Choix de '||coalesce(captain_name,'capitaine')||' · '||coalesce(captain_style,'Leadership')
            end
          )
          returning id into invitation_id;

          backup_filled:=false;
          for backup in
            select c.*,
              case when slot>3
                then public.laver_cup_captain_pick_score(
                  c.player_id,team,season,selection_date,c.selection_score
                )
                else c.selection_score
              end as final_selection_score
            from public.laver_candidate_pool(t.id,team,selection_date) c
            where not c.is_managed
              and c.player_id<>rec.player_id
              and not exists(
                select 1 from public.laver_cup_invitations i
                where i.tournament_id=t.id and i.player_id=c.player_id
              )
              and not exists(
                select 1 from public.laver_cup_rosters r
                where r.tournament_id=t.id and r.player_id=c.player_id
              )
            order by
              case when slot<=3 then c.ranking_at_selection else 999999 end asc,
              case when slot>3 then public.laver_cup_captain_pick_score(
                c.player_id,team,season,selection_date,c.selection_score
              ) else 0 end desc,
              c.ranking_at_selection asc,
              c.player_id
          loop
            insert into public.laver_cup_invitations(
              tournament_id,team_code,player_id,roster_slot,selection_method,
              ranking_at_selection,selection_score,is_managed,status,
              invited_on,respond_by,responded_on,acceptance_probability,response_reason
            ) values(
              t.id,team,backup.player_id,slot,'managed_invite_backup',
              backup.ranking_at_selection,backup.final_selection_score,false,
              case when backup.ai_accept then 'accepted' else 'declined' end,
              invite_date,respond_by,invite_date,backup.acceptance_probability,
              case when backup.ai_accept then 'Remplaçant provisoire disponible' else 'Joueur IA indisponible / refus' end
            );

            if backup.ai_accept then
              insert into public.laver_cup_rosters(
                tournament_id,team_code,player_id,roster_slot,
                selection_method,ranking_at_selection,selected_on
              ) values(
                t.id,team,backup.player_id,slot,
                'managed_invite_backup',backup.ranking_at_selection,selection_date
              );

              update public.laver_cup_invitations
              set provisional_player_id=backup.player_id,updated_at=now()
              where id=invitation_id;

              insert into public.inbox_items(
                kind,title,body,action_route,game_date,priority,is_read,
                action_type,action_label,action_payload,
                secondary_action_type,secondary_action_label,secondary_action_payload,
                decision_status,related_entity_type,related_entity_id,expires_at
              ) values(
                'selection',
                'Laver Cup · invitation Team '||case when team='EUROPE' then 'Europe' else 'World' end,
                case when slot<=3
                  then 'La Laver Cup veut sélectionner '||rec.player_name||
                    ' via le classement. Rang au moment de la sélection : #'||rec.ranking_at_selection||
                    '. Forme/sélection : '||round(rec.final_selection_score,1)||'.'
                  else coalesce(captain_name,'Le capitaine')||
                    ' ('||coalesce(captain_style,'Leadership')||') veut sélectionner '||
                    rec.player_name||' pour la Laver Cup. Rang : #'||rec.ranking_at_selection||
                    '. Score de choix : '||round(rec.final_selection_score,1)||'.'
                end||
                ' Tu peux accepter ou refuser. Un remplaçant reste en attente jusqu’à ta décision.',
                'calendar',invite_date,'high',false,
                'respond_laver_cup_invitation','Accepter',
                jsonb_build_object('invitation_id',invitation_id,'decision','accept','player_id',rec.player_id,'tournament_id',t.id),
                'respond_laver_cup_invitation','Refuser',
                jsonb_build_object('invitation_id',invitation_id,'decision','decline','player_id',rec.player_id,'tournament_id',t.id),
                'pending','laver_cup_invitation',invitation_id,respond_by
              );

              pending_count:=pending_count+1;
              backup_filled:=true;
              filled:=true;
              exit;
            else
              ai_declines:=ai_declines+1;
            end if;
          end loop;

          if not backup_filled then
            return jsonb_build_object('ok',false,'reason','no_provisional_backup','team',team,'slot',slot,'player_id',rec.player_id);
          end if;
          exit;
        else
          insert into public.laver_cup_invitations(
            tournament_id,team_code,player_id,roster_slot,selection_method,
            ranking_at_selection,selection_score,is_managed,status,
            invited_on,respond_by,responded_on,acceptance_probability,response_reason
          ) values(
            t.id,team,rec.player_id,slot,
            case when slot<=3 then 'ranking_invitation' else 'captain_pick' end,
            rec.ranking_at_selection,rec.final_selection_score,false,
            case when rec.ai_accept then 'accepted' else 'declined' end,
            invite_date,respond_by,invite_date,rec.acceptance_probability,
            case when rec.ai_accept then
              case when slot<=3 then 'Invitation classement acceptée'
              else 'Choix de '||coalesce(captain_name,'capitaine')||' accepté · '||coalesce(captain_style,'Leadership')
              end
            else 'Invitation refusée par le joueur IA' end
          );

          if rec.ai_accept then
            insert into public.laver_cup_rosters(
              tournament_id,team_code,player_id,roster_slot,
              selection_method,ranking_at_selection,selected_on
            ) values(
              t.id,team,rec.player_id,slot,
              case when slot<=3 then 'ranking_auto' else 'captain_pick' end,
              rec.ranking_at_selection,selection_date
            );
            filled:=true;
            exit;
          else
            ai_declines:=ai_declines+1;
          end if;
        end if;
      end loop;

      if not filled then
        return jsonb_build_object('ok',false,'reason','incomplete_roster','team',team,'slot',slot);
      end if;
    end loop;

    select count(*) into v_count
    from public.laver_cup_rosters
    where tournament_id=t.id and team_code=team;

    if v_count<>6 then
      return jsonb_build_object('ok',false,'reason','incomplete_roster','team',team,'count',v_count);
    end if;
  end loop;

  return jsonb_build_object(
    'ok',true,'selection_date',selection_date,'invite_date',invite_date,'respond_by',respond_by,
    'europe',6,'world',6,'pending_managed_invites',pending_count,'ai_declines',ai_declines,
    'captains',captain_ctx->'captains',
    'model','CB-LAVER-SELECTION-v3 · ranking + form + recent results + captain style + AI refusals + managed invitations'
  );
end;
$function$;

create or replace function public.laver_cup_history_attach_captains()
returns trigger
language plpgsql
set search_path='public'
as $function$
declare
  v_start integer;
begin
  perform public.ensure_laver_cup_captains(new.season);
  v_start:=public.laver_cup_term_start(new.season);

  select captain_player_id into new.europe_captain_player_id
  from public.laver_cup_captain_terms
  where team_code='EUROPE' and term_start_season=v_start
  limit 1;

  select captain_player_id into new.world_captain_player_id
  from public.laver_cup_captain_terms
  where team_code='WORLD' and term_start_season=v_start
  limit 1;

  return new;
end;
$function$;

drop trigger if exists laver_cup_history_attach_captains_trg on public.laver_cup_history;
create trigger laver_cup_history_attach_captains_trg
before insert or update of season on public.laver_cup_history
for each row execute function public.laver_cup_history_attach_captains();

update public.laver_cup_history h
set europe_captain_player_id=e.captain_player_id,
    world_captain_player_id=w.captain_player_id
from public.laver_cup_captain_terms e,
     public.laver_cup_captain_terms w
where e.team_code='EUROPE'
  and w.team_code='WORLD'
  and e.term_start_season=public.laver_cup_term_start(h.season)
  and w.term_start_season=public.laver_cup_term_start(h.season)
  and (
    h.europe_captain_player_id is distinct from e.captain_player_id
    or h.world_captain_player_id is distinct from w.captain_player_id
  );
