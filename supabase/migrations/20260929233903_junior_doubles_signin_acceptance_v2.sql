-- Court Boss ITF Junior doubles sign-in / acceptance engine v2
-- No doubles qualifying is created: ITF Junior doubles is formed after doubles sign-in.
-- Partnerships are fixed before acceptance, then ranked through the six ITF acceptance groups.
-- Alternates replace late withdrawals; if none is available the draw continues with a real bye.

create table if not exists public.junior_doubles_signins(
  tournament_id bigint not null references public.tournaments(id) on delete cascade,
  player_a_id bigint not null references public.players(id) on delete cascade,
  player_b_id bigint not null references public.players(id) on delete cascade,
  signed_on date not null,
  acceptance_group integer not null default 6,
  combined_rank integer not null default 1999998,
  pair_strength integer not null default 0,
  chemistry integer not null default 0,
  compatibility integer not null default 0,
  affinity_score numeric not null default 0,
  sign_priority numeric not null default 0,
  status text not null default 'signed',
  model_version text not null default 'CB-JUNIOR-DOUBLES-SIGNIN-v3',
  check(player_a_id<player_b_id),
  primary key(tournament_id,player_a_id,player_b_id)
);

alter table public.junior_doubles_signins enable row level security;

create index if not exists junior_doubles_signins_tournament_status_idx
  on public.junior_doubles_signins(tournament_id,status,acceptance_group,combined_rank);
create index if not exists junior_doubles_signins_player_a_idx
  on public.junior_doubles_signins(player_a_id,tournament_id);
create index if not exists junior_doubles_signins_player_b_idx
  on public.junior_doubles_signins(player_b_id,tournament_id);

alter table public.world_junior_doubles_entries
  add column if not exists entry_method text,
  add column if not exists acceptance_group integer,
  add column if not exists combined_rank integer,
  add column if not exists pair_strength integer,
  add column if not exists signed_on date,
  add column if not exists model_version text;

create index if not exists world_junior_doubles_entries_player_a_idx
  on public.world_junior_doubles_entries(player_a_id,tournament_id);
create index if not exists world_junior_doubles_entries_player_b_idx
  on public.world_junior_doubles_entries(player_b_id,tournament_id);

CREATE OR REPLACE FUNCTION public.junior_doubles_player_acceptance_status(p_player_id bigint, p_tournament_id bigint)
 RETURNS integer
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
begin
  -- 1 = singles main draw participant (excluding singles main-draw wild cards).
  if exists(
    select 1
    from public.junior_entry_reservations r
    where r.tournament_id=p_tournament_id
      and r.player_id=p_player_id
      and r.entry_method in ('direct','rating_acceptance_2026','alternate')
  )
  or exists(
    select 1
    from public.world_tournament_qualifying_entries q
    where q.tournament_id=p_tournament_id
      and q.player_id=p_player_id
      and q.qualified=true
  )
  or exists(
    select 1
    from public.world_tournament_entries e
    where e.tournament_id=p_tournament_id
      and e.player_id=p_player_id
      and e.entry_method<>'wildcard'
  ) then
    return 1;
  end if;

  -- 2 = singles qualifying participant OR singles main-draw wild card.
  if exists(
    select 1
    from public.world_tournament_qualifying_entries q
    where q.tournament_id=p_tournament_id
      and q.player_id=p_player_id
  )
  or exists(
    select 1
    from public.junior_entry_reservations r
    where r.tournament_id=p_tournament_id
      and r.player_id=p_player_id
      and r.entry_method='wildcard'
  )
  or exists(
    select 1
    from public.world_tournament_entries e
    where e.tournament_id=p_tournament_id
      and e.player_id=p_player_id
      and e.entry_method='wildcard'
  ) then
    return 2;
  end if;

  return 3;
end;
$function$;

CREATE OR REPLACE FUNCTION public.junior_doubles_team_acceptance_group(p_a bigint, p_b bigint, p_tournament_id bigint)
 RETURNS integer
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  sa int:=public.junior_doubles_player_acceptance_status(p_a,p_tournament_id);
  sb int:=public.junior_doubles_player_acceptance_status(p_b,p_tournament_id);
begin
  if sa=1 and sb=1 then return 1; end if;
  if least(sa,sb)=1 and greatest(sa,sb)=2 then return 2; end if;
  if least(sa,sb)=1 and greatest(sa,sb)=3 then return 3; end if;
  if sa=2 and sb=2 then return 4; end if;
  if least(sa,sb)=2 and greatest(sa,sb)=3 then return 5; end if;
  return 6;
end;
$function$;

CREATE OR REPLACE FUNCTION public.junior_doubles_wildcards(p_draw integer)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  select case
    when p_draw<=8 then 1
    when p_draw<=16 then 2
    when p_draw<=24 then 2
    when p_draw<=32 then 4
    when p_draw<=48 then 6
    else 8
  end;
$function$;

CREATE OR REPLACE FUNCTION public.junior_doubles_effective_rank(p_player_id bigint)
 RETURNS integer
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select case
    when p.junior_ranking is not null then p.junior_ranking
    when coalesce(p.ranking,999999)<=250 then 1
    when coalesce(p.ranking,999999)<=350 then 2
    when coalesce(p.ranking,999999)<=450 then 4
    when coalesce(p.ranking,999999)<=500 then 6
    when coalesce(p.ranking,999999)<=550 then 12
    when coalesce(p.ranking,999999)<=600 then 18
    when coalesce(p.ranking,999999)<=650 then 24
    when coalesce(p.ranking,999999)<=700 then 30
    when coalesce(p.ranking,999999)<=750 then 35
    when coalesce(p.ranking,999999)<=850 then 36+ceil((p.ranking-750)/25.0)::int
    else 999999
  end
  from public.players p
  where p.id=p_player_id;
$function$;

CREATE OR REPLACE FUNCTION public.junior_doubles_seed_count(p_draw integer)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  select case
    when p_draw<=8 then 2
    when p_draw<=16 then 4
    when p_draw<=32 then 8
    else 16
  end;
$function$;

CREATE OR REPLACE FUNCTION public.prepare_junior_doubles_signins(p_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  v_draw int;
  v_target_pairs int;
  v_pairs int:=0;
  v_p1 bigint;
  v_partner bigint;
  v_best_score numeric;
  v_score numeric;
  v_status_a int;
  v_status_b int;
  v_group int;
  v_ra int;
  v_rb int;
  v_combined int;
  v_sign_date date;
  m record;
  rr record;
begin
  select * into t
  from public.tournaments
  where id=p_tournament_id
    and circuit='Junior'
    and doubles=true
    and coalesce(is_active,true)=true;

  if t.id is null then
    return jsonb_build_object('ok',false,'reason','not_active_junior_doubles');
  end if;
  if t.category in ('Junior Davis Cup','Junior Finals','Junior Double Finals') then
    return jsonb_build_object('ok',false,'reason','special_event');
  end if;

  if exists(
    select 1 from public.junior_doubles_signins
    where tournament_id=t.id
  ) then
    return jsonb_build_object(
      'ok',true,'already',true,
      'signed_pairs',(select count(*) from public.junior_doubles_signins where tournament_id=t.id),
      'model','fixed partnerships before ITF acceptance'
    );
  end if;

  perform public.prepare_junior_entry_reservations(t.id);

  v_draw:=greatest(8,least(64,coalesce(t.doubles_draw_size,16)));
  v_target_pairs:=greatest(v_draw+8,least(64,ceil(v_draw*1.75)::int));
  v_sign_date:=case
    when coalesce(t.junior_draw_format,'')='round_robin_to_elimination'
      then greatest(t.start_date,coalesce(t.main_draw_start_date,t.start_date))-1
    else coalesce(t.main_draw_start_date,t.start_date)
  end;

  drop table if exists pg_temp.cb_jds_pool;
  create temporary table cb_jds_pool(
    player_id bigint primary key,
    status_class int not null,
    effective_rank int not null,
    country text,
    interest numeric not null
  ) on commit drop;

  insert into cb_jds_pool(player_id,status_class,effective_rank,country,interest)
  select
    p.id,
    public.junior_doubles_player_acceptance_status(p.id,t.id),
    coalesce(public.junior_doubles_effective_rank(p.id),999999),
    p.country,
    (
      case public.junior_doubles_player_acceptance_status(p.id,t.id)
        when 1 then 24
        when 2 then 15
        else 0 end
      +coalesce(pa.doubles,10)*1.45
      +coalesce(p.current_ability,50)*.28
      +coalesce(p.form,70)*.06
      -coalesce(p.fatigue,20)*.13
      +case coalesce(p.career_focus,'mixed')
        when 'doubles_only' then 18
        when 'mixed' then 7
        when 'singles_priority' then -4
        else 0 end
      +case when upper(coalesce(p.country,''))=upper(coalesce(t.country,'')) then 4 else 0 end
      +(mod(abs(hashtext('junior-double-sign|'||t.id||'|'||p.id)),1000)::numeric/1000.0)*3
    )
  from public.players p
  left join public.player_attributes pa on pa.player_id=p.id
  where p.career_status='active'
    and p.injury_status='Fit'
    and coalesce(p.fitness,90)>=45
    and coalesce(p.fatigue,20)<=90
    and coalesce(p.career_focus,'mixed')<>'singles_only'
    and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
    and (
      p.birth_date is null
      or (
        p.birth_date<=t.start_date-interval '13 years'
        and extract(year from t.start_date)::int-extract(year from p.birth_date)::int<=18
      )
    )
    and not (public.player_tournament_calendar_conflict(p.id,t.id,'doubles')->>'conflict')::boolean
    and public.junior_player_commits_to_event(p.id,t.id,'doubles')
  order by 5 desc,p.id
  limit greatest(v_draw*12,96);

  while v_pairs<v_target_pairs and (select count(*) from cb_jds_pool)>=2 loop
    select player_id into v_p1
    from cb_jds_pool
    order by interest desc,player_id
    limit 1;

    v_partner:=null;
    v_best_score:=-999999;

    select
      cand.player_id,
      (
        cand.interest*.32
        +coalesce(bb.doubles,10)*1.20
        +coalesce(b.current_ability,50)*.18
        +case when upper(coalesce(a.country,''))=upper(coalesce(b.country,'')) then 8 else 0 end
        +case
          when lower(coalesce(a.handedness,''))<>lower(coalesce(b.handedness,''))
           and (
             lower(coalesce(a.handedness,'')) like 'gauch%'
             or lower(coalesce(a.handedness,'')) like 'left%'
             or lower(coalesce(b.handedness,'')) like 'gauch%'
             or lower(coalesce(b.handedness,'')) like 'left%'
           )
          then 5 else 0 end
        +case
          when abs(coalesce(a.age,18)-coalesce(b.age,18))<=2 then 4
          when abs(coalesce(a.age,18)-coalesce(b.age,18))<=4 then 2
          else 0 end
        +case when exists(
          select 1 from public.world_doubles_partnerships wp
          where wp.active=true
            and least(wp.player_a_id,wp.player_b_id)=least(v_p1,cand.player_id)
            and greatest(wp.player_a_id,wp.player_b_id)=greatest(v_p1,cand.player_id)
        ) then 18 else 0 end
        +(mod(abs(hashtext(
          'junior-double-partner-lite|'||t.id||'|'||
          least(v_p1,cand.player_id)||'|'||greatest(v_p1,cand.player_id)
        )),1000)::numeric/1000.0)*2
      )
    into v_partner,v_best_score
    from cb_jds_pool cand
    join public.players a on a.id=v_p1
    join public.players b on b.id=cand.player_id
    left join public.player_attributes bb on bb.player_id=b.id
    where cand.player_id<>v_p1
    order by 2 desc,cand.player_id
    limit 1;

    if v_partner is null then
      delete from cb_jds_pool where player_id=v_p1;
      continue;
    end if;

    v_status_a:=public.junior_doubles_player_acceptance_status(v_p1,t.id);
    v_status_b:=public.junior_doubles_player_acceptance_status(v_partner,t.id);
    v_group:=public.junior_doubles_team_acceptance_group(v_p1,v_partner,t.id);
    v_ra:=coalesce(public.junior_doubles_effective_rank(v_p1),999999);
    v_rb:=coalesce(public.junior_doubles_effective_rank(v_partner),999999);

    v_combined:=case
      when v_ra<999999 and v_rb<999999 then v_ra+v_rb
      when v_ra<999999 then 999999+v_ra
      when v_rb<999999 then 999999+v_rb
      else 1999998 end;

    select * into m
    from public.doubles_pair_metrics(v_p1,v_partner,t.start_date)
    limit 1;

    insert into public.junior_doubles_signins(
      tournament_id,player_a_id,player_b_id,signed_on,
      acceptance_group,combined_rank,pair_strength,chemistry,compatibility,
      affinity_score,sign_priority,status,model_version
    ) values(
      t.id,least(v_p1,v_partner),greatest(v_p1,v_partner),v_sign_date,
      v_group,v_combined,
      coalesce(m.pair_strength,0),coalesce(m.chemistry,0),coalesce(m.compatibility,0),
      coalesce(m.affinity_score,0),
      v_best_score,'signed','CB-JUNIOR-DOUBLES-SIGNIN-v3'
    )
    on conflict do nothing;

    delete from cb_jds_pool where player_id in (v_p1,v_partner);
    v_pairs:=v_pairs+1;
  end loop;

  return jsonb_build_object(
    'ok',true,
    'signed_pairs',(select count(*) from public.junior_doubles_signins where tournament_id=t.id),
    'draw',v_draw,
    'target_signins',v_target_pairs,
    'sign_date',v_sign_date,
    'model','players form fixed partnerships first; ITF acceptance is applied afterwards'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.prepare_junior_doubles_reservations(p_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  v_draw int;
  v_wc int;
  v_direct int;
  v_seed_count int;
  v_pair_count int:=0;
  v_direct_count int:=0;
  v_wc_count int:=0;
  v_seed_no int;
  v_slot int;
begin
  select * into t
  from public.tournaments
  where id=p_tournament_id
    and circuit='Junior'
    and doubles=true
    and coalesce(is_active,true)=true;

  if t.id is null then
    return jsonb_build_object('ok',false,'reason','not_active_junior_doubles');
  end if;

  if t.category in ('Junior Davis Cup','Junior Finals','Junior Double Finals') then
    return jsonb_build_object('ok',false,'reason','special_event');
  end if;

  v_draw:=greatest(8,least(64,coalesce(t.doubles_draw_size,16)));
  v_wc:=least(v_draw,public.junior_doubles_wildcards(v_draw));
  v_direct:=v_draw-v_wc;
  v_seed_count:=least(v_draw,public.junior_doubles_seed_count(v_draw));

  if exists(
    select 1 from public.junior_doubles_reservations
    where tournament_id=t.id
  ) then
    return jsonb_build_object(
      'ok',true,'already',true,
      'pairs',(select count(*) from public.junior_doubles_reservations where tournament_id=t.id),
      'direct_pairs',(select count(*) from public.junior_doubles_reservations where tournament_id=t.id and entry_method='direct'),
      'wildcard_pairs',(select count(*) from public.junior_doubles_reservations where tournament_id=t.id and entry_method='wildcard'),
      'alternates',(select count(*) from public.junior_doubles_signins where tournament_id=t.id and status='alternate')
    );
  end if;

  perform public.prepare_junior_doubles_signins(t.id);

  -- Direct acceptances are selected from already-signed partnerships using
  -- the six ITF 2026 acceptance groups, then ranking within each group.
  insert into public.junior_doubles_reservations(
    tournament_id,player_a_id,player_b_id,entry_method,acceptance_group,
    combined_rank,pair_strength,reserved_on,model_version
  )
  select
    s.tournament_id,s.player_a_id,s.player_b_id,'direct',
    s.acceptance_group,s.combined_rank,s.pair_strength,s.signed_on,
    'CB-JUNIOR-DOUBLES-ENTRY-v2'
  from public.junior_doubles_signins s
  where s.tournament_id=t.id
    and s.status='signed'
  order by
    s.acceptance_group,
    s.combined_rank,
    md5('junior-doubles-accept|'||t.id||'|'||s.player_a_id||'|'||s.player_b_id)
  limit v_direct
  on conflict do nothing;

  get diagnostics v_direct_count=row_count;

  update public.junior_doubles_signins s
  set status='accepted_direct'
  where s.tournament_id=t.id
    and exists(
      select 1
      from public.junior_doubles_reservations r
      where r.tournament_id=s.tournament_id
        and r.player_a_id=s.player_a_id
        and r.player_b_id=s.player_b_id
        and r.entry_method='direct'
    );

  -- Doubles wild cards are additional to the direct acceptances. Prefer
  -- host-national partnerships, then one host player, then strongest chemistry.
  insert into public.junior_doubles_reservations(
    tournament_id,player_a_id,player_b_id,entry_method,acceptance_group,
    combined_rank,pair_strength,reserved_on,model_version
  )
  select
    s.tournament_id,s.player_a_id,s.player_b_id,'wildcard',
    99,s.combined_rank,s.pair_strength,s.signed_on,
    'CB-JUNIOR-DOUBLES-ENTRY-v2'
  from public.junior_doubles_signins s
  join public.players a on a.id=s.player_a_id
  join public.players b on b.id=s.player_b_id
  where s.tournament_id=t.id
    and s.status='signed'
  order by
    case
      when upper(coalesce(a.country,''))=upper(coalesce(t.country,''))
       and upper(coalesce(b.country,''))=upper(coalesce(t.country,'')) then 0
      when upper(coalesce(a.country,''))=upper(coalesce(t.country,''))
        or upper(coalesce(b.country,''))=upper(coalesce(t.country,'')) then 1
      else 2
    end,
    s.affinity_score desc,
    s.pair_strength desc,
    md5('junior-doubles-wc|'||t.id||'|'||s.player_a_id||'|'||s.player_b_id)
  limit v_wc
  on conflict do nothing;

  get diagnostics v_wc_count=row_count;

  update public.junior_doubles_signins s
  set status='accepted_wildcard'
  where s.tournament_id=t.id
    and exists(
      select 1
      from public.junior_doubles_reservations r
      where r.tournament_id=s.tournament_id
        and r.player_a_id=s.player_a_id
        and r.player_b_id=s.player_b_id
        and r.entry_method='wildcard'
    );

  update public.junior_doubles_signins
  set status='alternate'
  where tournament_id=t.id and status='signed';

  select count(*) into v_pair_count
  from public.junior_doubles_reservations
  where tournament_id=t.id;

  if v_pair_count<>v_draw then
    delete from public.junior_doubles_reservations where tournament_id=t.id;
    update public.junior_doubles_signins
    set status='signed'
    where tournament_id=t.id;
    return jsonb_build_object(
      'ok',false,'reason','insufficient_signed_pair_field',
      'pairs_built',v_pair_count,'draw',v_draw,
      'signed_pairs',(select count(*) from public.junior_doubles_signins where tournament_id=t.id)
    );
  end if;

  -- Seed only the official number of teams. Professional ATP ranking is
  -- converted with the ITF seeding comparison chart by junior_doubles_effective_rank().
  with ranked as (
    select
      r.player_a_id,r.player_b_id,
      row_number() over(
        order by
          (
            coalesce(public.junior_doubles_effective_rank(r.player_a_id),999999)
            +coalesce(public.junior_doubles_effective_rank(r.player_b_id),999999)
          ),
          r.pair_strength desc,
          md5('junior-doubles-seed|'||t.id||'|'||r.player_a_id||'|'||r.player_b_id)
      )::int rn
    from public.junior_doubles_reservations r
    where r.tournament_id=t.id
  )
  update public.junior_doubles_reservations r
  set seed=case when x.rn<=v_seed_count then x.rn else null end,
      draw_slot=null
  from ranked x
  where r.tournament_id=t.id
    and r.player_a_id=x.player_a_id
    and r.player_b_id=x.player_b_id;

  drop table if exists pg_temp.cb_jdr_seed_slots;
  create temporary table cb_jdr_seed_slots(
    seed_no int primary key,
    slot int unique not null
  ) on commit drop;

  -- Seed 1 / 2 on opposite ends, then place remaining seeds as far apart as possible.
  if v_seed_count>=1 then
    insert into cb_jdr_seed_slots values(1,1);
  end if;
  if v_seed_count>=2 then
    insert into cb_jdr_seed_slots values(2,v_draw);
  end if;

  if v_seed_count>=3 then
    for v_seed_no in 3..v_seed_count loop
      select gs into v_slot
      from generate_series(2,greatest(2,v_draw-1)) gs
      where not exists(
        select 1 from cb_jdr_seed_slots ss where ss.slot=gs
      )
      order by
        (
          select min(abs(gs-ss.slot))
          from cb_jdr_seed_slots ss
        ) desc,
        md5('junior-doubles-seed-slot|'||t.id||'|'||v_seed_no||'|'||gs)
      limit 1;

      if v_slot is not null then
        insert into cb_jdr_seed_slots(seed_no,slot) values(v_seed_no,v_slot);
      end if;
    end loop;
  end if;

  update public.junior_doubles_reservations r
  set draw_slot=s.slot
  from cb_jdr_seed_slots s
  where r.tournament_id=t.id and r.seed=s.seed_no;

  -- Random/deterministic public draw for all unseeded teams into remaining lines.
  with free_slots as (
    select gs slot,
           row_number() over(
             order by md5('junior-doubles-slot|'||t.id||'|'||gs)
           )::int rn
    from generate_series(1,v_draw) gs
    where not exists(
      select 1 from cb_jdr_seed_slots s where s.slot=gs
    )
  ),
  unseeded as (
    select r.player_a_id,r.player_b_id,
           row_number() over(
             order by md5('junior-doubles-team-draw|'||t.id||'|'||r.player_a_id||'|'||r.player_b_id)
           )::int rn
    from public.junior_doubles_reservations r
    where r.tournament_id=t.id and r.seed is null
  )
  update public.junior_doubles_reservations r
  set draw_slot=f.slot
  from unseeded u
  join free_slots f on f.rn=u.rn
  where r.tournament_id=t.id
    and r.player_a_id=u.player_a_id
    and r.player_b_id=u.player_b_id;

  return jsonb_build_object(
    'ok',true,
    'pairs',v_pair_count,
    'direct_pairs',v_direct_count,
    'wildcard_pairs',v_wc_count,
    'alternates',(select count(*) from public.junior_doubles_signins where tournament_id=t.id and status='alternate'),
    'seeds',v_seed_count,
    'draw',v_draw,
    'model','ITF Junior 2026 fixed sign-in partnerships -> 6-group acceptance -> public draw v2'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.prepare_junior_doubles_window(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t record;
  r jsonb;
  prepared int:=0;
  skipped int:=0;
  pairs int:=0;
begin
  for t in
    select *
    from public.tournaments
    where circuit='Junior'
      and doubles=true
      and coalesce(is_active,true)=true
      and category not in ('Junior Davis Cup','Junior Finals','Junior Double Finals')
      and coalesce(doubles_draw_size,0)>=8
      and coalesce(main_draw_start_date,start_date)>p_from_date
      and coalesce(main_draw_start_date,start_date)<=p_to_date
    order by coalesce(main_draw_start_date,start_date),id
    limit 150
  loop
    r:=public.prepare_junior_doubles_reservations(t.id);
    if coalesce((r->>'ok')::boolean,false) then
      prepared:=prepared+1;
      pairs:=pairs+coalesce((r->>'pairs')::int,0);
    else
      skipped:=skipped+1;
    end if;
  end loop;

  return jsonb_build_object(
    'events_prepared',prepared,
    'events_skipped',skipped,
    'pairs_reserved',pairs,
    'from',p_from_date,'to',p_to_date,
    'model','ITF Junior doubles sign-in/acceptance window v2'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.refresh_junior_doubles_reservations(p_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  bad record;
  alt record;
  v_slot int;
  v_replaced int:=0;
  v_withdrawn int:=0;
begin
  select * into t
  from public.tournaments
  where id=p_tournament_id
    and circuit='Junior'
    and doubles=true
    and coalesce(is_active,true)=true;

  if t.id is null then
    return jsonb_build_object('ok',false,'reason','not_active_junior_doubles');
  end if;

  for bad in
    select r.*
    from public.junior_doubles_reservations r
    join public.players a on a.id=r.player_a_id
    join public.players b on b.id=r.player_b_id
    where r.tournament_id=t.id
      and (
        a.career_status<>'active' or b.career_status<>'active'
        or a.injury_status<>'Fit' or b.injury_status<>'Fit'
        or coalesce(a.fitness,90)<40 or coalesce(b.fitness,90)<40
        or (
          public.player_tournament_calendar_conflict(a.id,t.id,'doubles')->>'conflict'
        )::boolean
        or (
          public.player_tournament_calendar_conflict(b.id,t.id,'doubles')->>'conflict'
        )::boolean
      )
    order by coalesce(r.seed,9999),r.draw_slot
  loop
    v_slot:=bad.draw_slot;

    update public.junior_doubles_signins
    set status='withdrawn_after_acceptance'
    where tournament_id=t.id
      and player_a_id=bad.player_a_id
      and player_b_id=bad.player_b_id;

    delete from public.junior_doubles_reservations
    where tournament_id=t.id
      and player_a_id=bad.player_a_id
      and player_b_id=bad.player_b_id;

    v_withdrawn:=v_withdrawn+1;

    select s.*
    into alt
    from public.junior_doubles_signins s
    join public.players a on a.id=s.player_a_id
    join public.players b on b.id=s.player_b_id
    where s.tournament_id=t.id
      and s.status='alternate'
      and a.career_status='active'
      and b.career_status='active'
      and a.injury_status='Fit'
      and b.injury_status='Fit'
      and coalesce(a.fitness,90)>=40
      and coalesce(b.fitness,90)>=40
      and not (
        public.player_tournament_calendar_conflict(a.id,t.id,'doubles')->>'conflict'
      )::boolean
      and not (
        public.player_tournament_calendar_conflict(b.id,t.id,'doubles')->>'conflict'
      )::boolean
    order by
      s.acceptance_group,
      s.combined_rank,
      md5('junior-doubles-alt|'||t.id||'|'||s.player_a_id||'|'||s.player_b_id)
    limit 1;

    if alt.tournament_id is not null then
      insert into public.junior_doubles_reservations(
        tournament_id,player_a_id,player_b_id,entry_method,acceptance_group,
        combined_rank,pair_strength,seed,draw_slot,reserved_on,model_version
      ) values(
        t.id,alt.player_a_id,alt.player_b_id,'alternate',alt.acceptance_group,
        alt.combined_rank,alt.pair_strength,null,v_slot,
        coalesce(alt.signed_on,t.start_date),
        'CB-JUNIOR-DOUBLES-ENTRY-v2'
      );

      update public.junior_doubles_signins
      set status='accepted_alternate'
      where tournament_id=t.id
        and player_a_id=alt.player_a_id
        and player_b_id=alt.player_b_id;

      v_replaced:=v_replaced+1;
    end if;
  end loop;

  return jsonb_build_object(
    'ok',true,
    'withdrawn_pairs',v_withdrawn,
    'replacements',v_replaced,
    'remaining_pairs',(
      select count(*) from public.junior_doubles_reservations where tournament_id=t.id
    ),
    'model','fixed partnership alternates v2'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.simulate_junior_world_doubles_full(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  v_managed bigint;
  v_draw int;
  v_pair_count int;
  v_p1 bigint;
  v_best_partner bigint;
  v_pair_strength int;
  v_best_strength int;
  v_size int;
  v_bracket int;
  v_byes int;
  v_round int;
  v_pos int;
  v_next int;
  v_match_no int;
  v_round_entries bigint[];
  v_a bigint;
  v_b bigint;
  v_w bigint;
  v_l bigint;
  v_sa int;
  v_sb int;
  v_prob numeric;
  v_awon boolean;
  v_score text;
  v_code text;
  v_winner bigint;
  v_count int:=0;
  v_matches int:=0;
  rr record;
begin
  select managed_player_id into v_managed from public.career_state where id='demo';

  for t in
    select *
    from public.tournaments
    where circuit='Junior'
      and doubles=true
      and coalesce(is_active,true)=true
      and coalesce(end_date,start_date)>p_from_date
      and coalesce(end_date,start_date)<=p_to_date
      and category not in ('Junior Davis Cup','Junior Finals','Junior Double Finals')
      and coalesce(doubles_draw_size,0)>=8
      and not exists(select 1 from public.world_junior_doubles_entries e where e.tournament_id=tournaments.id)
    order by
      date_trunc('week',start_date::timestamp),
      case
        when category='Junior Grand Slam' then 100
        when category='J500' then 90
        when category='J300' then 80
        when category='J200' then 70
        when category='J100' then 60
        when category='J60' then 50
        when category='J30' then 40
        else 10 end desc,
      coalesce(end_date,start_date),id
    limit 100
  loop
    v_draw:=least(32,coalesce(t.doubles_draw_size,16));

    drop table if exists pg_temp.cb_jd_pool;
    drop table if exists pg_temp.cb_jd;
    create temporary table cb_jd_pool(
      player_id bigint primary key,
      rankv int
    ) on commit drop;
    create temporary table cb_jd(
      entry_no int generated always as identity primary key,
      player_a_id bigint not null,
      player_b_id bigint not null,
      strength int not null,
      combined_rank int not null default 1999998,
      entry_method text not null,
      acceptance_group int not null,
      signed_on date,
      seed int,
      draw_slot int
    ) on commit drop;

    perform public.prepare_junior_doubles_reservations(t.id);
    perform public.refresh_junior_doubles_reservations(t.id);

    insert into cb_jd(
      player_a_id,player_b_id,strength,combined_rank,
      entry_method,acceptance_group,signed_on,seed,draw_slot
    )
    select
      r.player_a_id,r.player_b_id,r.pair_strength,r.combined_rank,
      r.entry_method,r.acceptance_group,r.reserved_on,r.seed,r.draw_slot
    from public.junior_doubles_reservations r
    where r.tournament_id=t.id
    order by r.draw_slot,r.player_a_id,r.player_b_id;

    select count(*) into v_pair_count from cb_jd;
    -- A late withdrawal without an available alternate becomes a real bye.
    -- Only abort if the event no longer has enough teams to be playable.
    if v_pair_count<2 then
      continue;
    end if;

    -- Seeds and draw slots are fixed at doubles sign-in / public draw time.
    -- Do not re-rank or reconstruct the bracket here.

    delete from public.world_junior_doubles_matches where tournament_id=t.id;
    delete from public.world_junior_doubles_entries where tournament_id=t.id;

    insert into public.world_junior_doubles_entries(
      tournament_id,player_a_id,player_b_id,seed,draw_slot,simulated_on,
      entry_method,acceptance_group,combined_rank,pair_strength,signed_on,model_version
    )
    select
      t.id,player_a_id,player_b_id,seed,draw_slot,t.end_date,
      entry_method,acceptance_group,combined_rank,strength,signed_on,
      'CB-JUNIOR-DOUBLES-v5-SIGNIN'
    from cb_jd
    order by draw_slot;

    drop table if exists pg_temp.cb_jd_current;
    drop table if exists pg_temp.cb_jd_next;
    create temporary table cb_jd_current(pos int primary key,entry_id bigint) on commit drop;
    create temporary table cb_jd_next(pos int primary key,entry_id bigint) on commit drop;

    insert into cb_jd_current(pos,entry_id)
    select draw_slot,id
    from public.world_junior_doubles_entries
    where tournament_id=t.id;

    v_round:=1;

    while (select count(*) from cb_jd_current)>1 loop
      select count(*) into v_size from cb_jd_current;

      v_bracket:=1;
      while v_bracket<v_size loop
        v_bracket:=v_bracket*2;
      end loop;
      v_byes:=v_bracket-v_size;

      truncate cb_jd_next;
      v_next:=0;
      v_match_no:=0;

      v_code:=case
        when v_bracket>=64 then 'R64'
        when v_bracket>=32 then 'R32'
        when v_bracket>=16 then 'R16'
        when v_bracket>=8 then 'QF'
        when v_bracket>=4 then 'SF'
        else 'F' end;

      -- Highest seeds receive the byes needed to reduce the field to a
      -- power-of-two bracket. Byes are not stored as fake matches.
      if v_byes>0 then
        for rr in
          select c.entry_id
          from cb_jd_current c
          join public.world_junior_doubles_entries e on e.id=c.entry_id
          order by coalesce(e.seed,9999),c.pos
          limit v_byes
        loop
          v_next:=v_next+1;
          insert into cb_jd_next(pos,entry_id) values(v_next,rr.entry_id);
        end loop;
      end if;

      select array_agg(c.entry_id order by c.pos)
      into v_round_entries
      from cb_jd_current c
      join public.world_junior_doubles_entries e on e.id=c.entry_id
      where not exists(
        select 1 from cb_jd_next n where n.entry_id=c.entry_id
      );

      if coalesce(array_length(v_round_entries,1),0)>0 then
        for v_pos in 1..array_length(v_round_entries,1) by 2 loop
          v_a:=v_round_entries[v_pos];
          v_b:=v_round_entries[v_pos+1];

          if v_a is null or v_b is null then
            raise exception 'Invalid junior doubles bracket at tournament %, round %, field %',t.id,v_round,v_size;
          end if;

          select d.strength into v_sa
          from public.world_junior_doubles_entries e
          join cb_jd d on d.player_a_id=e.player_a_id and d.player_b_id=e.player_b_id
          where e.id=v_a;

          select d.strength into v_sb
          from public.world_junior_doubles_entries e
          join cb_jd d on d.player_a_id=e.player_a_id and d.player_b_id=e.player_b_id
          where e.id=v_b;

          v_prob:=greatest(.08,least(.92,1/(1+exp(-(coalesce(v_sa,50)-coalesce(v_sb,50))/8.0))));
          v_awon:=random()<v_prob;
          v_w:=case when v_awon then v_a else v_b end;
          v_l:=case when v_awon then v_b else v_a end;
          v_score:=public.world_tournament_score(v_prob,v_awon,3);

          v_match_no:=v_match_no+1;
          insert into public.world_junior_doubles_matches(
            tournament_id,round_no,round_code,match_no,
            pair_a_entry_id,pair_b_entry_id,winner_entry_id,loser_entry_id,
            score,win_probability,simulated_on,model_version
          ) values(
            t.id,v_round,v_code,v_match_no,v_a,v_b,v_w,v_l,
            v_score,round(v_prob,4),t.end_date,'CB-JUNIOR-DOUBLES-v5-SIGNIN'
          );
          v_matches:=v_matches+1;

          update public.world_junior_doubles_entries
          set result_code=v_code,
              points_awarded=public.junior_points_for('doubles',t.category,v_code),
              last_opponent=(
                select pa.name||' / '||pb.name
                from public.world_junior_doubles_entries oe
                join public.players pa on pa.id=oe.player_a_id
                join public.players pb on pb.id=oe.player_b_id
                where oe.id=v_w
              ),
              last_score=case when v_l=v_a then v_score else public.world_invert_tennis_score(v_score) end
          where id=v_l;

          update public.world_junior_doubles_entries
          set matches_won=matches_won+1
          where id=v_w;

          v_next:=v_next+1;
          insert into cb_jd_next(pos,entry_id) values(v_next,v_w);
        end loop;
      end if;

      truncate cb_jd_current;
      insert into cb_jd_current
      select row_number() over(order by pos)::int,entry_id
      from cb_jd_next
      order by pos;

      v_round:=v_round+1;
    end loop;

    select entry_id into v_winner from cb_jd_current limit 1;

    update public.world_junior_doubles_entries
    set result_code='W',
        points_awarded=public.junior_points_for('doubles',t.category,'W')
    where id=v_winner;

    update public.players p
    set junior_doubles_game_points=coalesce(p.junior_doubles_game_points,0)+e.points_awarded
    from public.world_junior_doubles_entries e
    where e.tournament_id=t.id
      and p.id in (e.player_a_id,e.player_b_id);

    for rr in
      select e.*,a.name a_name,b.name b_name
      from public.world_junior_doubles_entries e
      join public.players a on a.id=e.player_a_id
      join public.players b on b.id=e.player_b_id
      where e.id=v_winner
    loop
      insert into public.player_titles(
        player_id,tournament_name,title_date,level,surface,event_type,
        partner_player_id,partner_name,verified,source_label,origin
      )
      values
        (rr.player_a_id,t.name,t.end_date,t.category,t.surface,'junior_doubles',rr.player_b_id,rr.b_name,false,'Court Boss junior doubles full draw','game'),
        (rr.player_b_id,t.name,t.end_date,t.category,t.surface,'junior_doubles',rr.player_a_id,rr.a_name,false,'Court Boss junior doubles full draw','game')
      on conflict(player_id,tournament_name,title_date,event_type) do nothing;
    end loop;

    v_count:=v_count+1;
  end loop;

  return jsonb_build_object(
    'doubles_simulated',v_count,'matches_simulated',v_matches,
    'from',p_from_date,'to',p_to_date,'model','CB-JUNIOR-DOUBLES-v5 fixed sign-in partnerships + alternates + real byes'
  );
end
$function$;

CREATE OR REPLACE FUNCTION public.player_has_world_event_in_week(p_player_id bigint, p_week_start date, p_exclude_tournament_id bigint DEFAULT NULL::bigint)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select exists(
    select 1
    from public.world_tournament_entries e
    join public.tournaments t on t.id=e.tournament_id
    where e.player_id=p_player_id
      and t.id is distinct from p_exclude_tournament_id
      and daterange(coalesce(t.qualifying_start_date,t.main_draw_start_date,t.start_date),coalesce(t.end_date,t.start_date),'[]')
          && daterange(p_week_start,p_week_start+6,'[]')
    union all
    select 1
    from public.world_tournament_qualifying_entries e
    join public.tournaments t on t.id=e.tournament_id
    where e.player_id=p_player_id
      and t.id is distinct from p_exclude_tournament_id
      and daterange(coalesce(t.qualifying_start_date,t.start_date),coalesce(t.qualifying_end_date,t.main_draw_start_date,t.end_date,t.start_date),'[]')
          && daterange(p_week_start,p_week_start+6,'[]')
    union all
    select 1
    from public.world_doubles_tournament_entries e
    join public.world_doubles_partnerships p on p.id=e.pair_id
    join public.tournaments t on t.id=e.tournament_id
    where p_player_id in (p.player_a_id,p.player_b_id)
      and t.id is distinct from p_exclude_tournament_id
      and daterange(coalesce(t.qualifying_start_date,t.main_draw_start_date,t.start_date),coalesce(t.end_date,t.start_date),'[]')
          && daterange(p_week_start,p_week_start+6,'[]')
    union all
    select 1
    from public.world_junior_doubles_entries e
    join public.tournaments t on t.id=e.tournament_id
    where p_player_id in (e.player_a_id,e.player_b_id)
      and t.id is distinct from p_exclude_tournament_id
      and daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
          && daterange(p_week_start,p_week_start+6,'[]')
    union all
    select 1
    from public.junior_entry_reservations jr
    join public.tournaments t on t.id=jr.tournament_id
    where jr.player_id=p_player_id
      and t.id is distinct from p_exclude_tournament_id
      and daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
          && daterange(p_week_start,p_week_start+6,'[]')
    union all
    select 1
    from public.junior_doubles_reservations dr
    join public.tournaments t on t.id=dr.tournament_id
    where p_player_id in (dr.player_a_id,dr.player_b_id)
      and t.id is distinct from p_exclude_tournament_id
      and daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
          && daterange(p_week_start,p_week_start+6,'[]')
    union all
    select 1
    from public.ncaa_individual_entries e
    join public.tournaments t on t.id=e.tournament_id
    where e.player_id=p_player_id
      and t.id is distinct from p_exclude_tournament_id
      and daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
          && daterange(p_week_start,p_week_start+6,'[]')
    union all
    select 1
    from public.ncaa_individual_doubles_entries e
    join public.tournaments t on t.id=e.tournament_id
    where p_player_id in (e.player_a_id,e.player_b_id)
      and t.id is distinct from p_exclude_tournament_id
      and daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
          && daterange(p_week_start,p_week_start+6,'[]')
    union all
    select 1
    from public.players pl
    join public.ncaa_team_event_entries te on te.team_id=pl.ncaa_team_id
    join public.tournaments t on t.id=te.tournament_id
    where pl.id=p_player_id
      and t.id is distinct from p_exclude_tournament_id
      and daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
          && daterange(p_week_start,p_week_start+6,'[]')
    union all
    select 1
    from public.junior_davis_squads s
    join public.tournaments t on t.id=s.tournament_id
    where s.player_id=p_player_id
      and t.id is distinct from p_exclude_tournament_id
      and daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
          && daterange(p_week_start,p_week_start+6,'[]')

    union all
    select 1
    from public.laver_cup_rosters lr
    join public.tournaments lt on lt.id=lr.tournament_id
    where lr.player_id=p_player_id
      and lt.id is distinct from p_exclude_tournament_id
      and daterange(lt.start_date,coalesce(lt.end_date,lt.start_date),'[]')
          && daterange(p_week_start,p_week_start+6,'[]')
    union all
    select 1
    from public.united_cup_atp_rosters ur
    join public.tournaments ut on ut.id=ur.tournament_id
    where ur.player_id=p_player_id
      and ut.id is distinct from p_exclude_tournament_id
      and daterange(ut.start_date,coalesce(ut.end_date,ut.start_date),'[]')
          && daterange(p_week_start,p_week_start+6,'[]')
    union all
    select 1
    from public.davis_squad ds
    join public.davis_ties dt on ds.nation in (dt.home_nation,dt.away_nation)
    where ds.player_id=p_player_id
      and dt.status in ('scheduled','completed')
      and dt.tie_date between p_week_start and p_week_start+6
    union all
    select 1
    from public.players pl
    join public.college_duals cd on pl.ncaa_team_id in (cd.home_team_id,cd.away_team_id)
    where pl.id=p_player_id
      and pl.ncaa_current=true
      and cd.status in ('scheduled','completed')
      and cd.match_date between p_week_start and p_week_start+6
  );
$function$;

CREATE OR REPLACE FUNCTION public.player_tournament_calendar_conflict(p_player_id bigint, p_tournament_id bigint, p_entry_method text DEFAULT 'direct'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  method text:=lower(coalesce(p_entry_method,'direct'));
  commit_start date;
  commit_end date;
  week_monday date;
  managed_id bigint;
  c record;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null then
    return jsonb_build_object('conflict',true,'reason','tournament_not_found');
  end if;

  select managed_player_id into managed_id from public.career_state where id='demo';

  week_monday:=date_trunc('week',coalesce(t.main_draw_start_date,t.start_date)::timestamp)::date;
  commit_start:=case
    when method in ('qualifying','qualifying_wildcard','protected_qualifying','doubles_qualifying')
      then coalesce(t.qualifying_start_date,t.main_draw_start_date,t.start_date)
    else coalesce(t.main_draw_start_date,t.start_date)
  end;
  commit_end:=coalesce(t.end_date,t.start_date);

  if exists(
    select 1
    from public.united_cup_atp_rosters ur
    join public.tournaments ut on ut.id=ur.tournament_id
    where ur.player_id=p_player_id
      and ut.id<>t.id
      and daterange(ut.start_date,coalesce(ut.end_date,ut.start_date),'[]')
          && daterange(commit_start,commit_end,'[]')
  ) then
    return jsonb_build_object(
      'conflict',true,
      'reason','united_cup_commitment',
      'other_tournament','United Cup',
      'other_discipline','national_mixed_team'
    );
  end if;

  select et.id tournament_id,
         'Junior Davis Cup · '||s.nation tournament_name,
         et.start_date start_date,coalesce(et.end_date,et.start_date) end_date,
         'junior_national_team'::text discipline
  into c
  from public.junior_davis_squads s
  join public.tournaments et on et.id=s.tournament_id
  where s.player_id=p_player_id
    and et.id<>t.id
    and daterange(et.start_date,coalesce(et.end_date,et.start_date),'[]')
        && daterange(commit_start,commit_end,'[]')
  order by et.start_date,et.id
  limit 1;

  if c.tournament_id is not null then
    return jsonb_build_object(
      'conflict',true,'reason','junior_national_team_commitment',
      'other_tournament_id',c.tournament_id,'other_event',c.tournament_name,
      'other_discipline','junior_national_team'
    );
  end if;

  c:=null;
  select dt.id tournament_id,
         'Davis Cup · '||dt.home_nation||' v '||dt.away_nation tournament_name,
         dt.tie_date start_date,dt.tie_date end_date,'davis'::text discipline
  into c
  from public.davis_squad ds
  join public.davis_ties dt on ds.nation in (dt.home_nation,dt.away_nation)
  where ds.player_id=p_player_id
    and dt.status in ('scheduled','completed')
    and dt.tie_date between commit_start and commit_end
  order by dt.tie_date,dt.id
  limit 1;

  if c.tournament_id is not null then
    return jsonb_build_object(
      'conflict',true,'reason','national_team_commitment',
      'other_davis_tie_id',c.tournament_id,'other_event',c.tournament_name,
      'other_discipline','davis'
    );
  end if;

  c:=null;
  select cd.id tournament_id,
         'NCAA · '||h.name||' v '||a.name tournament_name,
         cd.match_date start_date,cd.match_date end_date,
         coalesce(cd.competition,'NCAA Division I')::text discipline
  into c
  from public.players pl
  join public.college_duals cd
    on cd.home_team_id=pl.ncaa_team_id or cd.away_team_id=pl.ncaa_team_id
  join public.college_teams h on h.id=cd.home_team_id
  join public.college_teams a on a.id=cd.away_team_id
  where pl.id=p_player_id
    and pl.ncaa_current=true
    and cd.status in ('scheduled','completed')
    and cd.match_date between commit_start and commit_end
    and (
      (
        coalesce(cd.competition,'NCAA Division I')<>'NCAA Division I'
        and not (t.circuit='ATP' and t.category='Grand Chelem')
      )
      or t.circuit not in ('ATP','Challenger','ITF','Junior')
    )
  order by cd.match_date,cd.id
  limit 1;

  if c.tournament_id is not null then
    return jsonb_build_object(
      'conflict',true,'reason','college_priority_commitment',
      'other_college_dual_id',c.tournament_id,'other_event',c.tournament_name,
      'other_discipline',c.discipline
    );
  end if;

  c:=null;
  select x.tournament_id,x.tournament_name,x.start_date,x.end_date,x.discipline
  into c
  from (
    select ot.id tournament_id,ot.name tournament_name,ot.start_date,ot.end_date,'singles'::text discipline
    from public.world_tournament_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where e.player_id=p_player_id and ot.id<>t.id
      and daterange(
            coalesce(ot.qualifying_start_date,ot.main_draw_start_date,ot.start_date),
            coalesce(ot.end_date,ot.start_date),'[]'
          ) && daterange(commit_start,commit_end,'[]')

    union all
    select ot.id,ot.name,ot.start_date,ot.end_date,'qualifying'
    from public.world_tournament_qualifying_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where e.player_id=p_player_id and ot.id<>t.id
      and daterange(
            coalesce(ot.qualifying_start_date,ot.start_date),
            coalesce(ot.qualifying_end_date,ot.main_draw_start_date,ot.end_date,ot.start_date),'[]'
          ) && daterange(commit_start,commit_end,'[]')

    union all
    select ot.id,ot.name,ot.start_date,ot.end_date,'doubles'
    from public.world_doubles_tournament_entries e
    join public.world_doubles_partnerships p on p.id=e.pair_id
    join public.tournaments ot on ot.id=e.tournament_id
    where p_player_id in (p.player_a_id,p.player_b_id) and ot.id<>t.id
      and daterange(
            coalesce(ot.qualifying_start_date,ot.main_draw_start_date,ot.start_date),
            coalesce(ot.end_date,ot.start_date),'[]'
          ) && daterange(commit_start,commit_end,'[]')

    union all
    select ot.id,ot.name,ot.start_date,ot.end_date,'junior_doubles'
    from public.world_junior_doubles_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where p_player_id in (e.player_a_id,e.player_b_id) and ot.id<>t.id
      and daterange(ot.start_date,coalesce(ot.end_date,ot.start_date),'[]')
          && daterange(commit_start,commit_end,'[]')

    union all
    select ot.id,ot.name,ot.start_date,ot.end_date,'junior_reserved'
    from public.junior_entry_reservations jr
    join public.tournaments ot on ot.id=jr.tournament_id
    where jr.player_id=p_player_id and ot.id<>t.id
      and daterange(ot.start_date,coalesce(ot.end_date,ot.start_date),'[]')
          && daterange(commit_start,commit_end,'[]')

    union all
    select ot.id,ot.name,ot.start_date,ot.end_date,'junior_doubles_reserved'
    from public.junior_doubles_reservations dr
    join public.tournaments ot on ot.id=dr.tournament_id
    where p_player_id in (dr.player_a_id,dr.player_b_id)
      and ot.id<>t.id
      and daterange(ot.start_date,coalesce(ot.end_date,ot.start_date),'[]')
          && daterange(commit_start,commit_end,'[]')

    union all
    select lt.id,lt.name,lt.start_date,lt.end_date,'laver_cup'
    from public.laver_cup_rosters lr
    join public.tournaments lt on lt.id=lr.tournament_id
    where lr.player_id=p_player_id
      and lt.id<>t.id
      and daterange(lt.start_date,coalesce(lt.end_date,lt.start_date),'[]')
          && daterange(commit_start,commit_end,'[]')

    union all
    select ot.id,ot.name,ot.start_date,ot.end_date,'ncaa_individual'
    from public.ncaa_individual_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where e.player_id=p_player_id and ot.id<>t.id
      and daterange(ot.start_date,coalesce(ot.end_date,ot.start_date),'[]')
          && daterange(commit_start,commit_end,'[]')

    union all
    select ot.id,ot.name,ot.start_date,ot.end_date,'ncaa_doubles'
    from public.ncaa_individual_doubles_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where p_player_id in (e.player_a_id,e.player_b_id) and ot.id<>t.id
      and daterange(ot.start_date,coalesce(ot.end_date,ot.start_date),'[]')
          && daterange(commit_start,commit_end,'[]')
  ) x
  order by x.start_date,x.tournament_id
  limit 1;

  if c.tournament_id is not null then
    return jsonb_build_object(
      'conflict',true,'reason','calendar_overlap',
      'other_tournament_id',c.tournament_id,'other_tournament',c.tournament_name,
      'other_discipline',c.discipline
    );
  end if;

  if managed_id is not null and p_player_id=managed_id then
    c:=null;
    select x.tournament_id,x.tournament_name,x.start_date,x.end_date,x.discipline
    into c
    from (
      select tr.tournament_id,ot.name tournament_name,ot.start_date,ot.end_date,'singles'::text discipline,
             coalesce(ot.qualifying_start_date,ot.main_draw_start_date,ot.start_date) event_start
      from public.tournament_runs tr
      join public.tournaments ot on ot.id=tr.tournament_id
      where tr.tournament_id<>t.id
      union all
      select dr.tournament_id,ot.name,ot.start_date,ot.end_date,'doubles',
             coalesce(ot.qualifying_start_date,ot.main_draw_start_date,ot.start_date)
      from public.doubles_runs dr
      join public.tournaments ot on ot.id=dr.tournament_id
      where dr.tournament_id<>t.id
    ) x
    where daterange(x.event_start,coalesce(x.end_date,x.start_date),'[]')
          && daterange(commit_start,commit_end,'[]')
    order by x.event_start
    limit 1;

    if c.tournament_id is not null then
      return jsonb_build_object(
        'conflict',true,'reason','calendar_overlap',
        'other_tournament_id',c.tournament_id,'other_tournament',c.tournament_name,
        'other_discipline',c.discipline
      );
    end if;
  end if;

  if method in ('qualifying','qualifying_wildcard','protected_qualifying','doubles_qualifying') then
    c:=null;
    select x.tournament_id,x.tournament_name,x.result_code,x.discipline
    into c
    from (
      select ot.id tournament_id,ot.name tournament_name,e.result_code,'singles'::text discipline,
             coalesce(ot.end_date,ot.start_date) event_end,
             coalesce(ot.main_draw_start_date,ot.start_date) main_start
      from public.world_tournament_entries e
      join public.tournaments ot on ot.id=e.tournament_id
      where e.player_id=p_player_id and ot.id<>t.id

      union all
      select ot.id,ot.name,e.result_code,'doubles',
             coalesce(ot.end_date,ot.start_date),
             coalesce(ot.main_draw_start_date,ot.start_date)
      from public.world_doubles_tournament_entries e
      join public.world_doubles_partnerships p on p.id=e.pair_id
      join public.tournaments ot on ot.id=e.tournament_id
      where p_player_id in (p.player_a_id,p.player_b_id) and ot.id<>t.id

      union all
      select ot.id,ot.name,e.result_code,'junior_doubles',
             coalesce(ot.end_date,ot.start_date),
             coalesce(ot.main_draw_start_date,ot.start_date)
      from public.world_junior_doubles_entries e
      join public.tournaments ot on ot.id=e.tournament_id
      where p_player_id in (e.player_a_id,e.player_b_id) and ot.id<>t.id
    ) x
    where x.event_end>=commit_start
      and x.main_start<week_monday
      and coalesce(x.result_code,'') in ('W','F','SF')
    order by x.event_end desc
    limit 1;

    if c.tournament_id is not null then
      return jsonb_build_object(
        'conflict',true,'reason','still_competing_before_qualifying',
        'other_tournament_id',c.tournament_id,'other_tournament',c.tournament_name,
        'other_result',c.result_code,'other_discipline',c.discipline,
        'qualifying_start',commit_start
      );
    end if;
  end if;

  return jsonb_build_object(
    'conflict',false,'reason','available',
    'commitment_start',commit_start,'commitment_end',commit_end,'week_monday',week_monday
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.ncaa_team_lineup(p_team_id bigint, p_date date)
 RETURNS bigint[]
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select coalesce(array_agg(id order by score desc,id),'{}'::bigint[])
  from (
    select p.id,
      coalesce(p.current_ability,50)
      +coalesce(p.form,70)*.11
      +coalesce(p.fitness,85)*.05
      -coalesce(p.fatigue,20)*.07
      +coalesce(us.current_rating,10)*1.8
      -coalesce(p.ncaa_rank,500)*.004 as score
    from public.players p
    left join public.player_utr_state us on us.player_id=p.id
    where p.ncaa_current=true
      and p.ncaa_team_id=p_team_id
      and p.career_status='active'
      and p.injury_status='Fit'
      and coalesce(p.fitness,90)>=45

      and not exists(
        select 1
        from public.davis_squad ds
        join public.davis_ties dt on ds.nation in (dt.home_nation,dt.away_nation)
        where ds.player_id=p.id
          and dt.status in ('scheduled','completed')
          and dt.tie_date=p_date
      )

      and not exists(
        select 1
        from public.world_tournament_entries we
        join public.tournaments et on et.id=we.tournament_id
        where we.player_id=p.id
          and daterange(
                coalesce(et.qualifying_start_date,et.main_draw_start_date,et.start_date),
                coalesce(et.end_date,et.start_date),'[]'
              ) && daterange(p_date,p_date,'[]')
      )

      and not exists(
        select 1
        from public.world_tournament_qualifying_entries qe
        join public.tournaments et on et.id=qe.tournament_id
        where qe.player_id=p.id
          and daterange(
                coalesce(et.qualifying_start_date,et.start_date),
                coalesce(et.qualifying_end_date,et.main_draw_start_date,et.end_date,et.start_date),'[]'
              ) && daterange(p_date,p_date,'[]')
      )

      and not exists(
        select 1
        from public.world_doubles_tournament_entries de
        join public.world_doubles_partnerships wp on wp.id=de.pair_id
        join public.tournaments et on et.id=de.tournament_id
        where p.id in (wp.player_a_id,wp.player_b_id)
          and daterange(
                coalesce(et.qualifying_start_date,et.main_draw_start_date,et.start_date),
                coalesce(et.end_date,et.start_date),'[]'
              ) && daterange(p_date,p_date,'[]')
      )

      and not exists(
        select 1
        from public.junior_entry_reservations jr
        join public.tournaments et on et.id=jr.tournament_id
        where jr.player_id=p.id
          and daterange(et.start_date,coalesce(et.end_date,et.start_date),'[]')
              && daterange(p_date,p_date,'[]')
      )

      and not exists(
        select 1
        from public.junior_doubles_reservations dr
        join public.tournaments et on et.id=dr.tournament_id
        where p.id in (dr.player_a_id,dr.player_b_id)
          and daterange(et.start_date,coalesce(et.end_date,et.start_date),'[]')
              && daterange(p_date,p_date,'[]')
      )

      and not exists(
        select 1
        from public.laver_cup_rosters lr
        join public.tournaments lt on lt.id=lr.tournament_id
        where lr.player_id=p.id
          and p_date between lt.start_date and coalesce(lt.end_date,lt.start_date)
      )

      and not exists(
        select 1
        from public.ncaa_individual_entries ie
        join public.tournaments et on et.id=ie.tournament_id
        where ie.player_id=p.id
          and daterange(et.start_date,coalesce(et.end_date,et.start_date),'[]')
              && daterange(p_date,p_date,'[]')
      )

      and not exists(
        select 1
        from public.ncaa_individual_doubles_entries ide
        join public.tournaments et on et.id=ide.tournament_id
        where p.id in (ide.player_a_id,ide.player_b_id)
          and daterange(et.start_date,coalesce(et.end_date,et.start_date),'[]')
              && daterange(p_date,p_date,'[]')
      )
    order by score desc,p.id
    limit 6
  ) x;
$function$;

CREATE OR REPLACE FUNCTION public.ncaa_team_doubles_lineup(p_team_id bigint, p_date date)
 RETURNS bigint[]
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select coalesce(array_agg(id order by score desc,id),'{}'::bigint[])
  from (
    select p.id,
      coalesce(p.current_ability,50)*.55
      +coalesce(pa.doubles,10)*1.65
      +coalesce(p.form,70)*.08
      +coalesce(p.fitness,85)*.04
      -coalesce(p.fatigue,20)*.06
      +coalesce(us.current_rating,10)*.8 as score
    from public.players p
    left join public.player_attributes pa on pa.player_id=p.id
    left join public.player_utr_state us on us.player_id=p.id
    where p.ncaa_current=true
      and p.ncaa_team_id=p_team_id
      and p.career_status='active'
      and p.injury_status='Fit'
      and coalesce(p.fitness,90)>=45
      and coalesce(p.career_focus,'mixed')<>'singles_only'

      and not exists(
        select 1
        from public.davis_squad ds
        join public.davis_ties dt on ds.nation in (dt.home_nation,dt.away_nation)
        where ds.player_id=p.id
          and dt.status in ('scheduled','completed')
          and dt.tie_date=p_date
      )

      and not exists(
        select 1
        from public.world_tournament_entries we
        join public.tournaments et on et.id=we.tournament_id
        where we.player_id=p.id
          and daterange(
                coalesce(et.qualifying_start_date,et.main_draw_start_date,et.start_date),
                coalesce(et.end_date,et.start_date),'[]'
              ) && daterange(p_date,p_date,'[]')
      )

      and not exists(
        select 1
        from public.world_tournament_qualifying_entries qe
        join public.tournaments et on et.id=qe.tournament_id
        where qe.player_id=p.id
          and daterange(
                coalesce(et.qualifying_start_date,et.start_date),
                coalesce(et.qualifying_end_date,et.main_draw_start_date,et.end_date,et.start_date),'[]'
              ) && daterange(p_date,p_date,'[]')
      )

      and not exists(
        select 1
        from public.world_doubles_tournament_entries de
        join public.world_doubles_partnerships wp on wp.id=de.pair_id
        join public.tournaments et on et.id=de.tournament_id
        where p.id in (wp.player_a_id,wp.player_b_id)
          and daterange(
                coalesce(et.qualifying_start_date,et.main_draw_start_date,et.start_date),
                coalesce(et.end_date,et.start_date),'[]'
              ) && daterange(p_date,p_date,'[]')
      )

      and not exists(
        select 1
        from public.junior_entry_reservations jr
        join public.tournaments et on et.id=jr.tournament_id
        where jr.player_id=p.id
          and daterange(et.start_date,coalesce(et.end_date,et.start_date),'[]')
              && daterange(p_date,p_date,'[]')
      )

      and not exists(
        select 1
        from public.junior_doubles_reservations dr
        join public.tournaments et on et.id=dr.tournament_id
        where p.id in (dr.player_a_id,dr.player_b_id)
          and daterange(et.start_date,coalesce(et.end_date,et.start_date),'[]')
              && daterange(p_date,p_date,'[]')
      )

      and not exists(
        select 1
        from public.laver_cup_rosters lr
        join public.tournaments lt on lt.id=lr.tournament_id
        where lr.player_id=p.id
          and p_date between lt.start_date and coalesce(lt.end_date,lt.start_date)
      )

      and not exists(
        select 1
        from public.ncaa_individual_entries ie
        join public.tournaments et on et.id=ie.tournament_id
        where ie.player_id=p.id
          and daterange(et.start_date,coalesce(et.end_date,et.start_date),'[]')
              && daterange(p_date,p_date,'[]')
      )

      and not exists(
        select 1
        from public.ncaa_individual_doubles_entries ide
        join public.tournaments et on et.id=ide.tournament_id
        where p.id in (ide.player_a_id,ide.player_b_id)
          and daterange(et.start_date,coalesce(et.end_date,et.start_date),'[]')
              && daterange(p_date,p_date,'[]')
      )
    order by score desc,p.id
    limit 6
  ) x;
$function$;

CREATE OR REPLACE FUNCTION public.ncaa_individual_player_available(p_player_id bigint, p_tournament_id bigint)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null then return false; end if;

  if not exists(
    select 1 from public.players p
    where p.id=p_player_id
      and p.ncaa_current=true
      and p.career_status='active'
      and p.injury_status='Fit'
      and coalesce(p.fitness,90)>=45
  ) then return false; end if;

  if exists(
    select 1
    from public.players p
    join public.ncaa_team_event_entries te on te.team_id=p.ncaa_team_id
    join public.tournaments et on et.id=te.tournament_id
    where p.id=p_player_id
      and et.id<>t.id
      and daterange(et.start_date,coalesce(et.end_date,et.start_date),'[]')
          && daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
  ) then return false; end if;

  if exists(
    select 1
    from public.junior_entry_reservations jr
    join public.tournaments jt on jt.id=jr.tournament_id
    where jr.player_id=p_player_id
      and jt.id<>t.id
      and daterange(jt.start_date,coalesce(jt.end_date,jt.start_date),'[]')
          && daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
  ) then return false; end if;

  if exists(
    select 1
    from public.junior_doubles_reservations dr
    join public.tournaments dt on dt.id=dr.tournament_id
    where p_player_id in (dr.player_a_id,dr.player_b_id)
      and dt.id<>t.id
      and daterange(dt.start_date,coalesce(dt.end_date,dt.start_date),'[]')
          && daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
  ) then return false; end if;

  if exists(
    select 1
    from public.laver_cup_rosters lr
    join public.tournaments lt on lt.id=lr.tournament_id
    where lr.player_id=p_player_id
      and lt.id<>t.id
      and daterange(lt.start_date,coalesce(lt.end_date,lt.start_date),'[]')
          && daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
  ) then return false; end if;

  if exists(
    select 1
    from public.ncaa_individual_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where e.player_id=p_player_id
      and ot.id<>t.id
      and daterange(ot.start_date,coalesce(ot.end_date,ot.start_date),'[]')
          && daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
  ) then return false; end if;

  if exists(
    select 1
    from public.ncaa_individual_doubles_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where p_player_id in (e.player_a_id,e.player_b_id)
      and ot.id<>t.id
      and daterange(ot.start_date,coalesce(ot.end_date,ot.start_date),'[]')
          && daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
  ) then return false; end if;

  if exists(
    select 1
    from public.world_tournament_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where e.player_id=p_player_id
      and daterange(
            coalesce(ot.qualifying_start_date,ot.main_draw_start_date,ot.start_date),
            coalesce(ot.end_date,ot.start_date),'[]'
          ) && daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
  ) then return false; end if;

  if exists(
    select 1
    from public.world_tournament_qualifying_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where e.player_id=p_player_id
      and daterange(
            coalesce(ot.qualifying_start_date,ot.start_date),
            coalesce(ot.qualifying_end_date,ot.main_draw_start_date,ot.end_date,ot.start_date),'[]'
          ) && daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
  ) then return false; end if;

  if exists(
    select 1
    from public.world_doubles_tournament_entries e
    join public.world_doubles_partnerships wp on wp.id=e.pair_id
    join public.tournaments ot on ot.id=e.tournament_id
    where p_player_id in (wp.player_a_id,wp.player_b_id)
      and daterange(
            coalesce(ot.qualifying_start_date,ot.main_draw_start_date,ot.start_date),
            coalesce(ot.end_date,ot.start_date),'[]'
          ) && daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
  ) then return false; end if;

  if exists(
    select 1
    from public.davis_squad ds
    join public.davis_ties dt on ds.nation in (dt.home_nation,dt.away_nation)
    where ds.player_id=p_player_id
      and dt.status in ('scheduled','completed')
      and dt.tie_date between t.start_date and coalesce(t.end_date,t.start_date)
  ) then return false; end if;

  return true;
end;
$function$;

