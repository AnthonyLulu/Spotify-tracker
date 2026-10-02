-- Court Boss ATP 2026: zero-pointer replacement eligibility.
-- A mandatory M1000 zero-pointer is only replaceable after consecutive mandatory misses
-- with a medical basis, matching ATP Rulebook 9.03 Note 3 behavior.

alter table public.atp_ranking_zero_pointers
  add column if not exists eligibility_reason text;

create or replace function public.atp_zero_pointer_medical_eligibility(
  p_player_id bigint,
  p_tournament_id bigint,
  p_as_of date default current_date
)
returns jsonb
language plpgsql
stable
set search_path='public'
as $$
declare
  cur_t record;
  prev_t record;
  cur_missed boolean:=false;
  prev_missed boolean:=false;
  cur_med boolean:=false;
  prev_med boolean:=false;
  injury_overlap boolean:=false;
begin
  select id,name,start_date,end_date,category
  into cur_t
  from public.tournaments
  where id=p_tournament_id
    and category in ('Grand Chelem','Masters 1000','ATP Finals');

  if cur_t.id is null then
    return jsonb_build_object('eligible',false,'reason','not_mandatory_event');
  end if;

  select t.id,t.name,t.start_date,t.end_date,t.category
  into prev_t
  from public.tournaments t
  where t.category in ('Grand Chelem','Masters 1000','ATP Finals')
    and coalesce(t.end_date,t.start_date)<coalesce(cur_t.start_date,cur_t.end_date)
    and extract(year from t.start_date) between extract(year from cur_t.start_date)-1 and extract(year from cur_t.start_date)
  order by coalesce(t.end_date,t.start_date) desc,t.id desc
  limit 1;

  select exists(
    select 1 from public.tournament_forfeits f
    where f.tournament_id=cur_t.id and f.player_id=p_player_id
  ),
  exists(
    select 1 from public.tournament_forfeits f
    where f.tournament_id=cur_t.id and f.player_id=p_player_id
      and coalesce(f.medical_withdrawal,false)=true
  )
  into cur_missed,cur_med;

  if prev_t.id is not null then
    select exists(
      select 1 from public.tournament_forfeits f
      where f.tournament_id=prev_t.id and f.player_id=p_player_id
    ),
    exists(
      select 1 from public.tournament_forfeits f
      where f.tournament_id=prev_t.id and f.player_id=p_player_id
        and coalesce(f.medical_withdrawal,false)=true
    )
    into prev_missed,prev_med;
  end if;

  select exists(
    select 1
    from public.injuries i
    where i.player_id=p_player_id
      and lower(coalesce(i.status,'')) in ('active','resolved','recovered')
      and i.started_at::date<=coalesce(cur_t.end_date,cur_t.start_date)
      and coalesce(i.expected_return::date,p_as_of)>=coalesce(prev_t.start_date,cur_t.start_date)
  ) into injury_overlap;

  return jsonb_build_object(
    'eligible',cur_missed and prev_missed and (cur_med or prev_med or injury_overlap),
    'reason',
      case
        when not cur_missed then 'current_mandatory_not_missed'
        when prev_t.id is null then 'no_previous_mandatory_event'
        when not prev_missed then 'not_two_consecutive_mandatory_misses'
        when not (cur_med or prev_med or injury_overlap) then 'medical_approval_basis_missing'
        else 'two_consecutive_mandatory_misses_with_medical_basis'
      end,
    'previous_event_id',prev_t.id,
    'previous_event_name',prev_t.name,
    'current_event_id',cur_t.id,
    'current_event_name',cur_t.name,
    'medical_basis',(cur_med or prev_med or injury_overlap)
  );
end;
$$;

create or replace function public.record_atp_zero_pointer(
  p_player_id bigint,
  p_tournament_id bigint,
  p_withdrawal_date date default current_date,
  p_reason text default 'withdrawal'
)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  t public.tournaments%rowtype;
  v_cat text;
  v_earned date;
  v_elig jsonb;
  v_replacement boolean:=false;
  v_elig_reason text;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null then return jsonb_build_object('recorded',false,'reason','tournament_not_found'); end if;

  v_cat:=case
    when t.category='Grand Chelem' then 'Grand Slam'
    when t.category='Masters 1000' then 'M1000'
    when t.category='ATP 500' then 'ATP500'
    else null end;

  if v_cat is null then
    return jsonb_build_object('recorded',false,'reason','not_zero_pointer_category','category',t.category);
  end if;

  if v_cat='ATP500' then
    return jsonb_build_object(
      'recorded',false,
      'reason','atp500_commitment_penalty_requires_specific_commitment_rule',
      'category',v_cat
    );
  end if;

  v_earned:=coalesce(t.end_date,t.start_date,p_withdrawal_date);

  if v_cat='M1000' then
    v_elig:=public.atp_zero_pointer_medical_eligibility(p_player_id,p_tournament_id,p_withdrawal_date);
    v_replacement:=coalesce((v_elig->>'eligible')::boolean,false);
    v_elig_reason:=v_elig->>'reason';
  else
    v_elig_reason:='grand_slam_zero_pointer_not_replaceable_under_m1000_rule';
  end if;

  insert into public.atp_ranking_zero_pointers(
    player_id,tournament_id,earned_date,expiry_date,rank_category,reason,
    replacement_eligible,active,source_label,eligibility_reason
  )
  values(
    p_player_id,p_tournament_id,v_earned,v_earned+364,v_cat,p_reason,
    v_replacement,true,'Court Boss · ATP mandatory zero pointer',v_elig_reason
  )
  on conflict(player_id,tournament_id) do update set
    earned_date=excluded.earned_date,
    expiry_date=excluded.expiry_date,
    rank_category=excluded.rank_category,
    reason=excluded.reason,
    replacement_eligible=excluded.replacement_eligible,
    active=true,
    source_label=excluded.source_label,
    eligibility_reason=excluded.eligibility_reason;

  return jsonb_build_object(
    'recorded',true,'player_id',p_player_id,'tournament_id',p_tournament_id,
    'category',v_cat,'earned_date',v_earned,'expiry_date',v_earned+364,
    'replacement_eligible',v_replacement,'eligibility',v_elig,
    'eligibility_reason',v_elig_reason
  );
end;
$$;

create or replace function public.sync_atp_zero_pointers(p_date date default current_date)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  r record;
  v_result jsonb;
  v_synced int:=0;
begin
  for r in
    select distinct f.player_id,f.tournament_id,
           coalesce(f.withdrawn_on::date,f.created_at::date,p_date) wd,
           coalesce(f.reason,'withdrawal/forfeit') reason
    from public.tournament_forfeits f
    join public.tournaments t on t.id=f.tournament_id
    where t.category in ('Grand Chelem','Masters 1000')
      and coalesce(f.withdrawn_on::date,f.created_at::date,t.start_date)<=p_date
      and (
        exists(
          select 1 from public.world_tournament_acceptance_entries a
          where a.tournament_id=t.id and a.player_id=f.player_id
            and coalesce(a.entry_method,'direct') not ilike '%qualif%'
        )
        or exists(
          select 1 from public.entries e
          where e.tournament_id=t.id and e.player_id=f.player_id
            and coalesce(e.entry_method,'direct') not ilike '%qualif%'
        )
      )
  loop
    v_result:=public.record_atp_zero_pointer(r.player_id,r.tournament_id,r.wd,r.reason);
    if coalesce((v_result->>'recorded')::boolean,false) then v_synced:=v_synced+1; end if;
  end loop;

  update public.atp_ranking_zero_pointers
  set active=(expiry_date>=p_date);

  return jsonb_build_object('date',p_date,'synced',v_synced);
end;
$$;

create or replace function public.atp_player_breakdown(p_player_id bigint,p_date date)
returns table(
 event_key text,label text,earned_date date,drop_date date,points integer,rank_category text,
 counting boolean,counting_reason text,replaced_m1000 boolean,replacement_event boolean,
 source_kind text,estimated boolean
)
language sql stable set search_path='public'
as $$
with pool as (select * from public.atp_event_pool(p_player_id,p_date)),
counts as (
 select
   count(*) filter(where rank_category in ('Grand Slam','M1000'))::int mandatory_events,
   count(*) filter(where rank_category not in ('Grand Slam','M1000','Finals','Reconciliation'))::int optional_events
 from pool
),
slot_info as (
 select mandatory_events,optional_events,
        greatest(0,18-mandatory_events)::int optional_slots,
        greatest(0,least(3,optional_events-greatest(0,18-mandatory_events)))::int replacement_capacity
 from counts
),
m_candidates as (
 select p.*,row_number() over(order by p.points asc,p.earned_date asc,p.event_key) rn
 from pool p
 where p.rank_category='M1000'
   and (
     p.source_kind<>'zero_pointer'
     or exists(
       select 1
       from public.atp_ranking_zero_pointers z
       where z.player_id=p_player_id
         and ('zero:'||z.tournament_id::text)=p.event_key
         and z.replacement_eligible=true
         and z.active=true
     )
   )
   and exists(
     select 1 from pool o
     where o.rank_category in ('ATP500','ATP250')
       and o.earned_date>p.earned_date and o.points>p.points
   )
),
replace_m as (
 select m.*
 from m_candidates m cross join slot_info s
 where m.rn<=s.replacement_capacity
),
replacement_candidates as (
 select p.*,row_number() over(order by p.points desc,p.earned_date desc,p.event_key) rn
 from pool p
 where p.rank_category in ('ATP500','ATP250')
   and exists(
     select 1 from replace_m m
     where p.earned_date>m.earned_date and p.points>m.points
   )
),
replace_o as (
 select * from replacement_candidates where rn<=(select count(*) from replace_m)
),
optional_ranked as (
 select p.event_key,row_number() over(order by p.points desc,p.earned_date desc,p.event_key) rn
 from pool p
 where p.rank_category not in ('Grand Slam','M1000','Finals','Reconciliation')
   and not exists(select 1 from replace_o r where r.event_key=p.event_key)
),
classified as (
 select p.*,
   exists(select 1 from replace_m m where m.event_key=p.event_key) replaced_m1000,
   exists(select 1 from replace_o r where r.event_key=p.event_key) replacement_event,
   case
    when p.rank_category='Reconciliation' then true
    when p.rank_category='Grand Slam' then true
    when p.rank_category='M1000'
      and not exists(select 1 from replace_m m where m.event_key=p.event_key) then true
    when p.rank_category='Finals' then true
    when exists(select 1 from replace_o r where r.event_key=p.event_key) then true
    when exists(
      select 1 from optional_ranked o cross join slot_info s
      where o.event_key=p.event_key and o.rn<=s.optional_slots
    ) then true
    else false end counting
 from pool p
)
select c.event_key,c.label,c.earned_date,c.drop_date,c.points,c.rank_category,c.counting,
 case
  when c.rank_category='Reconciliation' then 'Réconciliation historique avec le total ATP officiel du 01/12/2025'
  when c.rank_category='Grand Slam' then 'Grand Chelem obligatoire'
  when c.rank_category='M1000' and c.replaced_m1000 then
    case when c.source_kind='zero_pointer'
      then 'Zero-pointer M1000 remplacé après éligibilité médicale ATP'
      else 'Résultat M1000 joué remplacé par meilleur ATP 500/250 ultérieur' end
  when c.rank_category='M1000' and c.source_kind='zero_pointer' then
    'Zero-pointer M1000 obligatoire · remplacement médical non acquis'
  when c.rank_category='M1000' then 'Masters 1000 obligatoire'
  when c.rank_category='Finals' then 'ATP Finals en plus du socle'
  when c.replacement_event then 'Remplacement M1000 autorisé (max 3 sur 52 semaines)'
  when c.counting then 'Meilleur résultat optionnel'
  else 'Non comptabilisé actuellement' end,
 c.replaced_m1000,c.replacement_event,c.source_kind,c.estimated
from classified c
order by c.counting desc,c.points desc,c.earned_date desc,c.event_key;
$$;
