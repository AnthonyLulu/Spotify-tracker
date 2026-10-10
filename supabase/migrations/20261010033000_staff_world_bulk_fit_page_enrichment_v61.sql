-- v61. Bulk staff/player fit is mathematically identical to staff_fit_score(...)
-- for staff primary_role (the only role passed by staff_world_search).
-- The original sort and filters remain intact. Fetch expensive per-row
-- profile enrichment only AFTER LIMIT/OFFSET to avoid 8,845 subqueries.
CREATE OR REPLACE FUNCTION public.staff_fit_scores_bulk_v61(p_player_id bigint)
 RETURNS TABLE(staff_id bigint, managed_fit integer)
 LANGUAGE sql STABLE SET search_path TO ''
AS $bulk$
with x as (
  select
    p.id as player_id,p.country,p.style,p.personality,p.form,p.morale,
    sp.id as staff_id,sp.nationality,sp.primary_role,sp.staff_personality,sp.coaching_style,
    sp.preferred_surface,sp.ambition,sp.loyalty,sp.discipline,sp.pressure_handling,
    sp.professionalism,sp.communication_rating,sp.adaptability_rating,sp.reputation,
    sp.coach_rating,sp.technical_rating,sp.tactical_rating,sp.mental_rating,
    sp.fitness_rating,sp.medical_rating,sp.scouting_rating,sp.youth_rating,
    public.staff_role_group(sp.primary_role) as grp,
    b.bond_type,
    coalesce(b.affinity,50) as bond_affinity,
    coalesce(b.trust,50) as bond_trust,
    coalesce(b.respect,50) as bond_respect
  from public.players p
  join public.staff_profiles sp on true
  left join public.staff_player_bonds b
    on b.player_id=p.id
   and b.staff_profile_id=sp.id
   and b.active=true
  where p.id=p_player_id
),
s as (
  select *,
    case when country=nationality and country is not null then 11 else 0 end as nation_bonus,
    case
      when lower(coalesce(style,'')) like '%serveur%' and lower(coalesce(coaching_style,'')) in ('agressif','technique') then 9
      when lower(coalesce(style,'')) like '%contreur%' and lower(coalesce(coaching_style,'')) in ('tactique','mental') then 9
      when lower(coalesce(style,'')) like '%défenseur%' and lower(coalesce(coaching_style,'')) in ('tactique','mental') then 8
      when lower(coalesce(style,'')) like '%all-court%' and lower(coalesce(coaching_style,''))='all-court' then 10
      when lower(coalesce(style,'')) like '%attaquant%' and lower(coalesce(coaching_style,'')) in ('agressif','technique') then 8
      else 4
    end as style_bonus,
    case
      when lower(coalesce(personality,'')) like '%ambit%' and ambition>=15 then 6
      when lower(coalesce(personality,'')) like '%calme%' and staff_personality='Calme' then 5
      when lower(coalesce(personality,'')) like '%travail%' and professionalism>=15 then 6
      when lower(coalesce(personality,'')) like '%perfection%' and staff_personality='Perfectionniste' then 6
      else 2
    end as personality_bonus,
    case grp
      when 'coach' then round((coach_rating*.28+technical_rating*.20+tactical_rating*.20+mental_rating*.12+communication_rating*.10+reputation*.10))::int
      when 'fitness' then round((fitness_rating*.45+discipline*.15+communication_rating*.15+professionalism*.15+reputation*.10))::int
      when 'medical' then round((medical_rating*.50+communication_rating*.15+professionalism*.15+adaptability_rating*.10+reputation*.10))::int
      when 'analysis' then round((tactical_rating*.35+scouting_rating*.30+adaptability_rating*.15+communication_rating*.10+reputation*.10))::int
      when 'mental' then round((mental_rating*.40+pressure_handling*.25+communication_rating*.20+adaptability_rating*.15))::int
      when 'scout' then round((scouting_rating*.50+adaptability_rating*.20+communication_rating*.15+reputation*.15))::int
      else round((coach_rating+communication_rating+reputation)/3.0)::int
    end as role_quality,
    case
      when bond_type='Joueur favori' then 12
      when bond_type='Relation de confiance' then 9
      when bond_type='Ancien joueur apprécié' then 8
      when bond_type='Bonne collaboration' then 6
      when bond_type='Relation difficile' then -12
      when bond_type='Ancienne collaboration' then 3
      when bond_type is not null then 2
      else 0
    end
    +case when bond_type is not null
      then round(
        greatest(-5,least(5,
          ((bond_affinity-50)+(bond_trust-50)+(bond_respect-50))/30.0
        ))
      )::int
      else 0
    end as relationship_bonus
  from x
)
select staff_id, greatest(25,least(99,
  28
  +nation_bonus
  +style_bonus
  +personality_bonus
  +round(role_quality*1.85)::int
  +relationship_bonus
  +case when coalesce(morale,65)<45 and communication_rating>=16 then 4 else 0 end
  +case when coalesce(form,65)<45 and adaptability_rating>=16 then 3 else 0 end
))::int
AS managed_fit
from s;
$bulk$;

REVOKE EXECUTE ON FUNCTION public.staff_fit_scores_bulk_v61(bigint) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.staff_fit_scores_bulk_v61(bigint) TO service_role;

CREATE OR REPLACE FUNCTION public.staff_world_search(p_managed_player_id bigint, p_q text DEFAULT ''::text, p_role text DEFAULT ''::text, p_country text DEFAULT ''::text, p_former text DEFAULT ''::text, p_status text DEFAULT ''::text, p_offset integer DEFAULT 0, p_limit integer DEFAULT 50)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
with params as (
  select
    coalesce(nullif(trim(p_q),''),'') as q,
    coalesce(nullif(trim(p_role),''),'') as role_filter,
    upper(coalesce(nullif(trim(p_country),''),'')) as country_filter,
    lower(coalesce(nullif(trim(p_former),''),'')) as former_filter,
    lower(coalesce(nullif(trim(p_status),''),'')) as status_filter,
    greatest(0,coalesce(p_offset,0)) as off,
    greatest(1,least(coalesce(p_limit,50),100)) as lim
),
filtered as (
  select
    sp.id,sp.name,sp.nationality,sp.primary_role,sp.secondary_roles,
    sp.is_real,sp.former_player_status,sp.former_player_id,
    sp.coach_rating,sp.technical_rating,sp.tactical_rating,sp.mental_rating,
    sp.fitness_rating,sp.medical_rating,sp.scouting_rating,sp.youth_rating,
    sp.motivation_rating,sp.communication_rating,sp.adaptability_rating,sp.reputation,
    sp.negotiation_rating,sp.professionalism,sp.development_rating,
    sp.staff_personality,sp.coaching_style,sp.preferred_surface,sp.languages,sp.regions,
    sp.ambition,sp.loyalty,sp.discipline,sp.pressure_handling,
    sp.specialty,sp.market_status,sp.asking_weekly_cost,sp.max_clients,
    sp.verified,sp.world_generated,
    fit.managed_fit as managed_fit
  from public.staff_profiles sp
  cross join params p
  left join public.staff_fit_scores_bulk_v61(p_managed_player_id) fit on fit.staff_id=sp.id
  where sp.active=true
    and (
      p.q=''
      or sp.name ilike '%'||p.q||'%'
      or coalesce(sp.specialty,'') ilike '%'||p.q||'%'
      or coalesce(sp.coaching_style,'') ilike '%'||p.q||'%'
      or coalesce(sp.staff_personality,'') ilike '%'||p.q||'%'
    )
    and (p.role_filter='' or sp.primary_role=p.role_filter)
    and (p.country_filter='' or upper(coalesce(sp.nationality,''))=p.country_filter)
    and (
      p.former_filter=''
      or p.former_filter='tous'
      or (p.former_filter='oui' and sp.former_player_status='yes')
      or (p.former_filter='non' and sp.former_player_status<>'yes')
    )
    and (
      p.status_filter=''
      or p.status_filter='tous'
      or lower(coalesce(sp.market_status,''))=p.status_filter
    )
),
page as (
  select *
  from filtered
  order by
    case when managed_fit is null then 1 else 0 end,
    managed_fit desc nulls last,
    reputation desc,
    greatest(coach_rating,fitness_rating,medical_rating,scouting_rating,mental_rating) desc,
    name
  offset (select off from params)
  limit (select lim from params)
),
page_enriched as (
  select pg.*,
    coalesce((
      select count(*)::int
      from public.player_staff_assignments psa
      where psa.staff_profile_id=pg.id and psa.active=true
    ),0) as current_clients,
    (
      select a.name
      from public.staff_agency_members sam
      join public.staff_agencies a on a.id=sam.agency_id
      where sam.staff_profile_id=pg.id and sam.active=true and a.active=true
      order by a.reputation desc,a.id
      limit 1
    ) as agency_name,
    (
      select a.name
      from public.staff_academy_members sm
      join public.staff_academies a on a.id=sm.academy_id
      where sm.staff_profile_id=pg.id and a.active=true
      order by coalesce(sm.graduated_year,9999) desc,a.prestige desc,a.id
      limit 1
    ) as academy_name,
    (
      select sl.license_code
      from public.staff_licenses sl
      where sl.staff_profile_id=pg.id
      order by sl.license_level desc,sl.license_code
      limit 1
    ) as top_license
  from page pg
),
role_counts as (
  select primary_role,count(*)::int as n
  from filtered
  group by primary_role
  order by n desc,primary_role
),
country_counts as (
  select nationality,count(*)::int as n
  from filtered
  where nationality is not null
  group by nationality
  order by n desc,nationality
  limit 30
)
select jsonb_build_object(
  'total',(select count(*) from filtered),
  'offset',(select off from params),
  'limit',(select lim from params),
  'rows',coalesce((select jsonb_agg(to_jsonb(page)) from page_enriched page),'[]'::jsonb),
  'roles',coalesce((select jsonb_agg(jsonb_build_object('role',primary_role,'count',n)) from role_counts),'[]'::jsonb),
  'countries',coalesce((select jsonb_agg(jsonb_build_object('country',nationality,'count',n)) from country_counts),'[]'::jsonb),
  'agencies',coalesce((
    select jsonb_agg(to_jsonb(x))
    from (
      select a.id,a.name,a.country,a.reputation,a.commission_pct,a.network_strength,a.specialty,
             count(m.staff_profile_id)::int as members
      from public.staff_agencies a
      left join public.staff_agency_members m on m.agency_id=a.id and m.active=true
      where a.active=true
      group by a.id
      order by a.reputation desc,a.network_strength desc,a.name
      limit 10
    ) x
  ),'[]'::jsonb),
  'academies',coalesce((
    select jsonb_agg(to_jsonb(x))
    from (
      select a.id,a.name,a.country,a.prestige,a.philosophy,a.specialty,
             count(m.staff_profile_id)::int as members
      from public.staff_academies a
      left join public.staff_academy_members m on m.academy_id=a.id
      where a.active=true
      group by a.id
      order by a.prestige desc,a.name
      limit 10
    ) x
  ),'[]'::jsonb),
  'training_centers',coalesce((
    select jsonb_agg(to_jsonb(x))
    from (
      select c.id,c.name,c.country,c.specialty,c.reputation,c.capacity,
             count(e.id) filter(where e.status='active')::int as active_enrollments
      from public.staff_training_centers c
      left join public.staff_training_enrollments e on e.center_id=c.id
      where c.active=true
      group by c.id
      order by c.reputation desc,c.name
      limit 10
    ) x
  ),'[]'::jsonb)
);
$function$
;
