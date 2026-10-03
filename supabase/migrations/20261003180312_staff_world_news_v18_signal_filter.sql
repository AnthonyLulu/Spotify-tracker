CREATE OR REPLACE FUNCTION public.publish_staff_world_news(p_date date DEFAULT CURRENT_DATE)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
declare
  v_date date:=coalesce(p_date,current_date);
  v_added int:=0;
  r record;
  headline text;
begin
  for r in
    with ranked_events as (
      select
        e.id,e.event_date,e.event_type,e.description,e.player_id,e.other_player_id,
        e.staff_profile_id,
        sp.name as staff_name,sp.primary_role,sp.reputation,
        p.name as player_name,p.country as player_country,
        coalesce(p.game_world_rank,p.ranking,999999) as player_rank,
        op.name as other_player_name,
        row_number() over(
          partition by e.event_type,e.player_id
          order by sp.reputation desc,e.id
        ) as same_target_story_rank,
        exists(
          select 1
          from public.staff_career_events ix
          where ix.staff_profile_id=e.staff_profile_id
            and ix.event_date=e.event_date
            and ix.event_type='international_move'
        ) as has_international_move,
        exists(
          select 1
          from public.staff_career_events px
          where px.staff_profile_id=e.staff_profile_id
            and px.event_date=e.event_date
            and px.event_type in (
              'job_offer_accepted','followed_favorite_player','reunited_favorite_player'
            )
        ) as has_primary_move_story
      from public.staff_career_events e
      join public.staff_profiles sp on sp.id=e.staff_profile_id
      left join public.players p on p.id=e.player_id
      left join public.players op on op.id=e.other_player_id
      where e.event_date>=date_trunc('month',v_date)::date
        and e.event_date<=v_date
        and e.event_type in (
          'poached','left_user_for_offer','retained_after_offer','season_review','reputation',
          'job_offer_accepted','followed_favorite_player','reunited_favorite_player',
          'international_move','reputation_breakthrough','former_player_staff_entry'
        )
        and not exists(
          select 1 from public.staff_news_published n where n.event_id=e.id
        )
    )
    select *
    from ranked_events re
    where
      (
        re.event_type in (
          'poached','left_user_for_offer','followed_favorite_player',
          'reunited_favorite_player','reputation_breakthrough'
        )
        or (
          re.event_type='international_move'
          and not re.has_primary_move_story
        )
        or (
          re.event_type='job_offer_accepted'
          and re.same_target_story_rank=1
          and (re.player_rank<=20 or re.reputation>=18)
        )
        or (
          re.event_type in (
            'retained_after_offer','season_review','reputation','former_player_staff_entry'
          )
          and (re.player_rank<=50 or re.reputation>=17)
        )
      )
    order by
      case re.event_type
        when 'reputation_breakthrough' then 0
        when 'followed_favorite_player' then 1
        when 'reunited_favorite_player' then 1
        when 'poached' then 2
        when 'left_user_for_offer' then 2
        when 'international_move' then 3
        when 'former_player_staff_entry' then 4
        when 'job_offer_accepted' then 5
        when 'season_review' then 6
        else 7
      end,
      re.player_rank,
      re.reputation desc,
      re.event_date,
      re.id
    limit 12
  loop
    headline:=case r.event_type
      when 'poached' then
        coalesce(r.staff_name,'Un coach')||' rejoint '||coalesce(r.player_name,'un nouveau joueur')
        ||case when r.other_player_name is not null then ' après avoir quitté '||r.other_player_name else '' end||'.'
      when 'left_user_for_offer' then
        coalesce(r.staff_name,'Un membre du staff')||' change de projet et rejoint '||coalesce(r.player_name,'un autre joueur')||'.'
      when 'retained_after_offer' then
        coalesce(r.staff_name,'Un membre du staff')||' prolonge finalement son aventure malgré une approche extérieure.'
      when 'season_review' then
        coalesce(r.staff_name,'Un coach')||' voit sa cote progresser après une grosse saison.'
      when 'job_offer_accepted' then
        coalesce(r.staff_name,'Un membre du staff')||' change de projet et rejoint '
        ||coalesce(r.player_name,'un nouveau joueur')
        ||case
            when r.has_international_move and r.player_country is not null
              then ' pour un nouveau projet international en '||r.player_country
            else ''
          end||'.'
      when 'followed_favorite_player' then
        coalesce(r.staff_name,'Un coach')||' choisit de suivre '
        ||coalesce(r.player_name,'un joueur avec qui le lien est fort')
        ||case
            when r.has_international_move and r.player_country is not null
              then ' dans un nouveau projet en '||r.player_country
            else ''
          end||'.'
      when 'reunited_favorite_player' then
        coalesce(r.staff_name,'Un coach')||' retrouve '
        ||coalesce(r.player_name,'un ancien joueur')
        ||case
            when r.has_international_move and r.player_country is not null
              then ' pour une nouvelle collaboration en '||r.player_country
            else ' pour une nouvelle collaboration'
          end||'.'
      when 'international_move' then
        coalesce(r.staff_name,'Un membre du staff')||' tente une nouvelle aventure internationale'
        ||case when r.player_country is not null then ' en '||r.player_country else '' end||'.'
      when 'reputation_breakthrough' then
        coalesce(r.staff_name,'Un coach')||' explose sur le marché après une série de résultats majeurs.'
      when 'former_player_staff_entry' then
        coalesce(r.staff_name,'Un ancien joueur')||' entame sa seconde carrière dans le staff.'
      else
        coalesce(r.staff_name,'Un membre du staff')||' fait évoluer sa réputation sur le circuit.'
    end;

    insert into public.news_items(body) values(headline);
    insert into public.staff_news_published(event_id) values(r.id) on conflict do nothing;
    v_added:=v_added+1;
  end loop;

  return jsonb_build_object('date',v_date,'published',v_added,'model','CB-STAFF-NEWS-v18');
end;
$function$;
