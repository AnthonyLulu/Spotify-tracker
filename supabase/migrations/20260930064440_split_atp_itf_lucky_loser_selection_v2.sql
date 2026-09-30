-- Circuit-specific Lucky Loser selection.
-- ATP/Challenger follows ATP 2026 vacancy-aware ranking draw.
-- ITF follows World Tennis Tour ordering: final qualifying round first, then random draw inside ranking-status groups.

create or replace function public.refresh_world_tournament_lucky_losers(
  p_tournament_id bigint,
  p_vacancies integer default 0
)
returns jsonb
language plpgsql
set search_path to 'public'
as $function$
declare
  t public.tournaments%rowtype;
  max_qround int;
  inserted_count int:=0;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null then
    return jsonb_build_object('ok',false,'reason','tournament_not_found');
  end if;

  select max(nullif(regexp_replace(m.round_code,'[^0-9]','','g'),'')::int)
  into max_qround
  from public.world_tournament_matches m
  where m.tournament_id=t.id
    and m.is_qualifying=true
    and m.loser_id is not null
    and m.round_code like 'Q%';

  delete from public.world_tournament_lucky_losers where tournament_id=t.id;

  if max_qround is null then
    return jsonb_build_object('ok',true,'candidates',0,'reason','qualifying_not_completed');
  end if;

  if t.circuit='ITF' then
    with losses as (
      select distinct on (m.loser_id)
        m.loser_id player_id,
        m.round_code loss_round_code,
        nullif(regexp_replace(m.round_code,'[^0-9]','','g'),'')::int qround,
        coalesce(public.player_rank_at_date(
          m.loser_id,
          coalesce(t.qualifying_entry_deadline,t.main_entry_deadline,t.start_date-21)
        )::int,999999) ranking_at_seeding,
        p.itf_ranking
      from public.world_tournament_matches m
      join public.players p on p.id=m.loser_id
      where m.tournament_id=t.id
        and m.is_qualifying=true
        and m.loser_id is not null
        and m.round_code like 'Q%'
        and p.career_status='active'
        and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
        and coalesce(p.injury_status,'Fit')='Fit'
      order by m.loser_id,
               nullif(regexp_replace(m.round_code,'[^0-9]','','g'),'')::int desc
    ),
    ordered as (
      select l.*,
        row_number() over(
          order by
            (max_qround-l.qround) asc,
            case
              when l.ranking_at_seeding<999999 then 0
              when l.itf_ranking is not null then 1
              else 2
            end asc,
            md5('itf-ll-draw-v2|'||t.id::text||'|'||l.qround::text||'|'||l.player_id::text) asc
        )::int ll_order
      from losses l
    )
    insert into public.world_tournament_lucky_losers(
      tournament_id,player_id,loss_round_code,ranking_at_seeding,ll_order,selected,source_label
    )
    select
      t.id,o.player_id,o.loss_round_code,o.ranking_at_seeding,o.ll_order,false,
      'ITF Lucky Loser order · final-round priority + ranking-group random draw'
    from ordered o
    order by o.ll_order;
  else
    with losses as (
      select distinct on (m.loser_id)
        m.loser_id player_id,
        m.round_code loss_round_code,
        nullif(regexp_replace(m.round_code,'[^0-9]','','g'),'')::int qround,
        coalesce(public.player_rank_at_date(
          m.loser_id,
          coalesce(t.qualifying_entry_deadline,t.main_entry_deadline,t.start_date-21)
        )::int,999999) ranking_at_seeding
      from public.world_tournament_matches m
      join public.players p on p.id=m.loser_id
      where m.tournament_id=t.id
        and m.is_qualifying=true
        and m.loser_id is not null
        and m.round_code like 'Q%'
        and p.career_status='active'
        and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
        and coalesce(p.injury_status,'Fit')='Fit'
      order by m.loser_id,
               nullif(regexp_replace(m.round_code,'[^0-9]','','g'),'')::int desc
    ),
    ranked as (
      select l.*,
        row_number() over(
          partition by l.qround
          order by l.ranking_at_seeding,l.player_id
        )::int rank_in_round
      from losses l
    ),
    ordered as (
      select r.*,
        row_number() over(
          order by
            (max_qround-r.qround) asc,
            case
              when r.qround=max_qround
               and greatest(0,p_vacancies)>0
               and r.rank_in_round<=greatest(2,p_vacancies+1)
                then 0
              else 1
            end asc,
            case
              when r.qround=max_qround
               and greatest(0,p_vacancies)>0
               and r.rank_in_round<=greatest(2,p_vacancies+1)
                then md5('atp-ll-draw-v2|'||t.id::text||'|'||r.player_id::text)
              else lpad(r.ranking_at_seeding::text,9,'0')
            end asc,
            r.ranking_at_seeding asc,
            r.player_id
        )::int ll_order
      from ranked r
    )
    insert into public.world_tournament_lucky_losers(
      tournament_id,player_id,loss_round_code,ranking_at_seeding,ll_order,selected,source_label
    )
    select
      t.id,o.player_id,o.loss_round_code,o.ranking_at_seeding,o.ll_order,false,
      case
        when p_vacancies>0
          then 'ATP/Challenger Lucky Loser order · vacancy-aware top-ranked draw'
        else 'ATP/Challenger Lucky Loser order · qualifying seeding ranking'
      end
    from ordered o
    order by o.ll_order;
  end if;

  get diagnostics inserted_count=row_count;

  return jsonb_build_object(
    'ok',true,'tournament_id',t.id,'circuit',t.circuit,'candidates',inserted_count,
    'final_qualifying_round','Q'||max_qround::text,
    'vacancies_at_completion',greatest(0,p_vacancies),
    'model',case when t.circuit='ITF' then 'ITF-LL-v2' else 'ATP-LL-v2' end
  );
end
$function$;
