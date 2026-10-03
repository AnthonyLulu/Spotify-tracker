-- Court Boss · official Next Gen ATP Finals selection v1
-- ATP 2026: U20 all year, 7 Race direct acceptances + 1 ATP wildcard.

CREATE OR REPLACE FUNCTION public.nextgen_finals_field(p_tournament_id bigint)
 RETURNS TABLE(player_id bigint, player_name text, country text, selection_method text, field_order integer, nextgen_rank integer, nextgen_points numeric, atp_rank integer, wildcard_score numeric, nitto_finals_exempt boolean)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
with event as (
  select id,extract(year from start_date)::int as season,start_date
  from public.tournaments
  where id=p_tournament_id
    and circuit='ATP'
    and category='Next Gen Finals'
  limit 1
),
eligible as (
  select
    p.id,
    p.name,
    p.country,
    p.nextgen_ranking::int as nextgen_rank,
    coalesce(p.nextgen_points,0)::numeric as nextgen_points,
    coalesce(p.game_world_rank,p.ranking,999999)::int as atp_rank,
    coalesce(p.current_ability,50)::numeric as ability,
    coalesce(p.form,70)::numeric as formv,
    coalesce(p.fitness,85)::numeric as fitnessv,
    coalesce(p.fatigue,20)::numeric as fatiguev,
    (coalesce(p.race_ranking,999999)<=8) as nitto_exempt
  from public.players p
  cross join event e
  where public.nextgen_player_eligible(p.id,e.season)
    and p.nextgen_ranking is not null
    and p.career_status='active'
    and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
    and coalesce(p.injury_status,'Fit')='Fit'
    and coalesce(p.fitness,85)>=45
),
direct as (
  select e.*,row_number() over(order by e.nextgen_rank,e.nextgen_points desc,e.atp_rank,e.id)::int as ord
  from eligible e
  order by e.nextgen_rank,e.nextgen_points desc,e.atp_rank,e.id
  limit 7
),
wildcard_pool as (
  select e.*,
    (
      e.ability*1.10
      +e.formv*.32
      +e.fitnessv*.08
      -e.fatiguev*.08
      +greatest(0,120-least(e.atp_rank,120))*.14
      +greatest(0,25-least(e.nextgen_rank,25))*.30
      +mod(abs(hashtext('nextgen-wc|'||p_tournament_id||'|'||e.id)),1000)::numeric/1000.0
    )::numeric as wc_score
  from eligible e
  where not exists(select 1 from direct d where d.id=e.id)
),
wildcard as (
  select *
  from wildcard_pool
  order by wc_score desc,nextgen_rank,atp_rank,id
  limit 1
),
field as (
  select
    d.id as player_id,d.name as player_name,d.country,'race_direct'::text as selection_method,
    d.ord as field_order,d.nextgen_rank,d.nextgen_points,d.atp_rank,
    null::numeric as wildcard_score,d.nitto_exempt as nitto_finals_exempt
  from direct d
  union all
  select
    w.id,w.name,w.country,'atp_wildcard'::text,
    8,w.nextgen_rank,w.nextgen_points,w.atp_rank,
    round(w.wc_score,3),w.nitto_exempt
  from wildcard w
)
select *
from field
order by field.field_order;
$function$
;

CREATE OR REPLACE FUNCTION public.nextgen_finals_player_status(p_tournament_id bigint, p_player_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  season int;
  rowv record;
  elig boolean;
  race_rank int;
begin
  select * into t
  from public.tournaments
  where id=p_tournament_id and circuit='ATP' and category='Next Gen Finals';

  if t.id is null then
    return jsonb_build_object('ok',false,'reason','not_nextgen_finals');
  end if;

  season:=extract(year from t.start_date)::int;
  elig:=public.nextgen_player_eligible(p_player_id,season);

  select p.nextgen_ranking into race_rank from public.players p where p.id=p_player_id;

  select * into rowv
  from public.nextgen_finals_field(t.id)
  where player_id=p_player_id
  limit 1;

  if rowv.player_id is null then
    return jsonb_build_object(
      'ok',true,
      'selected',false,
      'eligible_age',coalesce(elig,false),
      'nextgen_rank',race_rank,
      'selection_rule','Top 7 Race Next Gen + 1 ATP wildcard'
    );
  end if;

  return jsonb_build_object(
    'ok',true,
    'selected',true,
    'player_id',rowv.player_id,
    'selection_method',rowv.selection_method,
    'field_order',rowv.field_order,
    'nextgen_rank',rowv.nextgen_rank,
    'nextgen_points',rowv.nextgen_points,
    'atp_rank',rowv.atp_rank,
    'nitto_finals_exempt',rowv.nitto_finals_exempt,
    'selection_rule','Top 7 Race Next Gen + 1 ATP wildcard'
  );
end;
$function$
;


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
    entry_rule_note='Next Gen ATP Finals: joueurs âgés de 20 ans ou moins pendant toute l’année. 7 qualifiés via la Race Next Gen + 1 wildcard ATP. Pas d’inscription manuelle. En cas de forfait avant l’événement, le prochain joueur éligible de la Race remonte. Format: 2 groupes de 4, puis demi-finales et finale; meilleur des 5 sets à 4 jeux, tie-break à 3-3, no-ad; aucun point ATP.'
where circuit='ATP'
  and category='Next Gen Finals'
  and entry_rule_code='NEXTGEN_FINALS_2026';
