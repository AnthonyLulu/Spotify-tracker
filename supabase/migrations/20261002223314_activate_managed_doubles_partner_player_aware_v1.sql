CREATE OR REPLACE FUNCTION public.activate_managed_doubles_partner(
  p_player_id bigint,
  p_partner_id bigint,
  p_date date DEFAULT CURRENT_DATE,
  p_source text DEFAULT 'Utilisateur · partenaire double'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_date date:=coalesce(p_date,current_date);
  v_year int:=extract(year from v_date)::int;
  v_primary bigint;
  v_focus text;
  v_old public.player_doubles_commitments%rowtype;
  v_target_old public.player_doubles_commitments%rowtype;
  v_metric record;
  v_commitment int;
  v_pa bigint;
  v_pb bigint;
begin
  select managed_player_id into v_primary
  from public.career_state where id='demo';

  if p_player_id is null then raise exception 'Managed player missing'; end if;
  if p_player_id<>v_primary and not exists(
    select 1 from public.academy_roster
    where player_id=p_player_id and status='active'
  ) then
    raise exception 'Ce joueur ne fait pas partie du groupe géré';
  end if;

  select coalesce(career_focus,'mixed') into v_focus
  from public.players where id=p_player_id;

  if not found then raise exception 'Managed player missing'; end if;
  if v_focus='singles_only' then raise exception 'Orientation Simple exclusivement'; end if;
  if p_partner_id=p_player_id then raise exception 'Impossible de se choisir soi-même'; end if;

  if not exists(
    select 1 from public.players
    where id=p_partner_id
      and career_status='active'
      and doubles_ranking is not null
      and coalesce(career_focus,'mixed')<>'singles_only'
  ) then raise exception 'Partenaire indisponible'; end if;

  select * into v_metric
  from public.doubles_pair_metrics(p_player_id,p_partner_id,v_date);

  if v_metric.chemistry is null then raise exception 'Compatibilité indisponible'; end if;

  select * into v_old
  from public.player_doubles_commitments
  where player_id=p_player_id
  limit 1;

  select * into v_target_old
  from public.player_doubles_commitments
  where player_id=p_partner_id
  limit 1;

  if v_old.player_id is not null
     and v_old.active
     and v_old.primary_partner_id<>p_partner_id then
    insert into public.player_doubles_partner_history(
      player_id,partner_id,start_date,end_date,season,
      affinity_start,affinity_end,reason,source_label
    )
    values(
      p_player_id,v_old.primary_partner_id,v_old.started_at,v_date,
      v_old.season,v_old.affinity,v_old.affinity,
      'Changement de partenaire décidé par le joueur.',
      p_source
    );

    update public.player_doubles_commitments
    set active=false,last_review_date=v_date,updated_at=now()
    where player_id=v_old.primary_partner_id
      and active=true
      and primary_partner_id=p_player_id;

    update public.world_doubles_partnerships
    set active=false,dissolved_date=v_date,race_rank=null,
        source='Court Boss · paire quittée pour le joueur géré'
    where season=v_year
      and active=true
      and player_a_id=least(p_player_id,v_old.primary_partner_id)
      and player_b_id=greatest(p_player_id,v_old.primary_partner_id);
  end if;

  if v_target_old.player_id is not null
     and v_target_old.active
     and v_target_old.primary_partner_id<>p_player_id then
    insert into public.player_doubles_partner_history(
      player_id,partner_id,start_date,end_date,season,
      affinity_start,affinity_end,reason,source_label
    )
    values(
      p_partner_id,v_target_old.primary_partner_id,v_target_old.started_at,v_date,
      v_target_old.season,v_target_old.affinity,v_target_old.affinity,
      'Le joueur rejoint une nouvelle paire avec le joueur géré.',
      p_source
    );

    update public.player_doubles_commitments
    set active=false,last_review_date=v_date,updated_at=now()
    where player_id=v_target_old.primary_partner_id
      and active=true
      and primary_partner_id=p_partner_id;

    update public.world_doubles_partnerships
    set active=false,dissolved_date=v_date,race_rank=null,
        source='Court Boss · paire quittée pour le joueur géré'
    where season=v_year
      and active=true
      and player_a_id=least(p_partner_id,v_target_old.primary_partner_id)
      and player_b_id=greatest(p_partner_id,v_target_old.primary_partner_id);
  end if;

  delete from public.doubles_partnerships
  where player_a_id=p_player_id or player_b_id=p_player_id;

  insert into public.doubles_partnerships(
    player_a_id,player_b_id,chemistry,compatibility,pair_strength
  )
  values(
    p_player_id,p_partner_id,
    v_metric.chemistry,v_metric.compatibility,v_metric.pair_strength
  );

  v_commitment:=greatest(
    60,
    least(
      100,
      round(v_metric.affinity_score)::int
      +case when v_focus='doubles_only' then 6 when v_focus='mixed' then 2 else 0 end
    )
  );

  insert into public.player_doubles_commitments(
    player_id,season,primary_partner_id,started_at,last_review_date,
    commitment,affinity,switches,previous_partner_id,reason,source_label,active
  )
  values(
    p_player_id,v_year,p_partner_id,v_date,v_date,
    v_commitment,v_metric.chemistry,
    coalesce(v_old.switches,0)+case when v_old.player_id is not null and v_old.primary_partner_id<>p_partner_id then 1 else 0 end,
    case when v_old.player_id is not null and v_old.primary_partner_id<>p_partner_id then v_old.primary_partner_id else v_old.previous_partner_id end,
    case when v_focus='doubles_only'
      then 'Partenaire principal pour une carrière exclusivement en double.'
      else 'Partenaire principal choisi par le joueur.' end,
    p_source,true
  )
  on conflict(player_id) do update set
    season=excluded.season,
    previous_partner_id=case
      when public.player_doubles_commitments.primary_partner_id<>excluded.primary_partner_id
        then public.player_doubles_commitments.primary_partner_id
      else public.player_doubles_commitments.previous_partner_id end,
    primary_partner_id=excluded.primary_partner_id,
    started_at=case
      when public.player_doubles_commitments.primary_partner_id=excluded.primary_partner_id
        then public.player_doubles_commitments.started_at
      else excluded.started_at end,
    last_review_date=v_date,
    commitment=excluded.commitment,
    affinity=excluded.affinity,
    switches=public.player_doubles_commitments.switches+
      case when public.player_doubles_commitments.primary_partner_id<>excluded.primary_partner_id then 1 else 0 end,
    reason=excluded.reason,source_label=excluded.source_label,
    active=true,updated_at=now();

  insert into public.player_doubles_commitments(
    player_id,season,primary_partner_id,started_at,last_review_date,
    commitment,affinity,switches,previous_partner_id,reason,source_label,active
  )
  values(
    p_partner_id,v_year,p_player_id,v_date,v_date,
    greatest(55,least(98,v_commitment-2)),v_metric.chemistry,
    coalesce(v_target_old.switches,0)+case when v_target_old.player_id is not null and v_target_old.primary_partner_id<>p_player_id then 1 else 0 end,
    case when v_target_old.player_id is not null and v_target_old.primary_partner_id<>p_player_id then v_target_old.primary_partner_id else v_target_old.previous_partner_id end,
    'Partenariat principal avec le joueur géré.',
    p_source,true
  )
  on conflict(player_id) do update set
    season=excluded.season,
    previous_partner_id=case
      when public.player_doubles_commitments.primary_partner_id<>excluded.primary_partner_id
        then public.player_doubles_commitments.primary_partner_id
      else public.player_doubles_commitments.previous_partner_id end,
    primary_partner_id=excluded.primary_partner_id,
    started_at=case
      when public.player_doubles_commitments.primary_partner_id=excluded.primary_partner_id
        then public.player_doubles_commitments.started_at
      else excluded.started_at end,
    last_review_date=v_date,
    commitment=excluded.commitment,
    affinity=excluded.affinity,
    switches=public.player_doubles_commitments.switches+
      case when public.player_doubles_commitments.primary_partner_id<>excluded.primary_partner_id then 1 else 0 end,
    reason=excluded.reason,source_label=excluded.source_label,
    active=true,updated_at=now();

  v_pa:=least(p_player_id,p_partner_id);
  v_pb:=greatest(p_player_id,p_partner_id);

  insert into public.player_relationships(
    player_a_id,player_b_id,relation_type,affinity,trust,respect,closeness,
    is_simulated,source_label,formed_date,last_update,active
  )
  values(
    v_pa,v_pb,
    case when v_metric.chemistry>=91 and v_metric.compatibility>=86
         then 'Ami / partenaire' else 'Partenaire de double' end,
    v_metric.chemistry,
    round(v_metric.chemistry*.55+v_metric.compatibility*.45),
    round(v_metric.pair_strength*.55+v_metric.compatibility*.45),
    round(v_metric.chemistry*.70+v_metric.compatibility*.30),
    true,'Court Boss · relation issue du partenariat principal',
    v_date,v_date,true
  )
  on conflict(player_a_id,player_b_id) do update set
    relation_type=excluded.relation_type,
    affinity=excluded.affinity,
    trust=excluded.trust,
    respect=excluded.respect,
    closeness=excluded.closeness,
    source_label=excluded.source_label,
    last_update=v_date,
    active=true;

  return jsonb_build_object(
    'ok',true,
    'player_id',p_player_id,
    'partner_id',p_partner_id,
    'chemistry',v_metric.chemistry,
    'compatibility',v_metric.compatibility,
    'pair_strength',v_metric.pair_strength,
    'affinity_score',v_metric.affinity_score,
    'commitment',v_commitment
  );
end
$function$;
