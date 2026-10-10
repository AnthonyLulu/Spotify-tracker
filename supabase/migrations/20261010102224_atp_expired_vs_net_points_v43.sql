-- ATP 2026: explicit separation of points expiring versus NET ATP movement.
-- Public ATP 52-week calculations already exist in atp_player_breakdown and
-- atp_player_ranking_summary; this function reuses the EXACT same counters,
-- not a second approximation. Security invoker; service_role-only.
-- Verified in isolated E2E stage: 330 -> 0 => net -330;
-- 3730 -> 3500 with 100 point reserve => gross -330, net -230.
-- This SQL does not update ranking history, game points or user saves.
CREATE OR REPLACE FUNCTION public.atp_points_movement_v1(p_player_id bigint, p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
DECLARE
 v_old integer:=0;
 v_new integer:=0;
 v_expired integer:=0;
 v_events jsonb:='[]'::jsonb;
BEGIN
 IF p_player_id IS NULL OR p_from_date IS NULL OR p_to_date IS NULL
    OR p_to_date < p_from_date OR p_to_date-p_from_date>62 THEN
   RETURN pg_catalog.jsonb_build_object('ok',false,'reason','invalid_dates_or_player',
     'max_window_days',62);
 END IF;
 SELECT coalesce(total_points,0) INTO v_old
 FROM public.atp_player_ranking_summary(p_player_id,p_from_date);
 SELECT coalesce(total_points,0) INTO v_new
 FROM public.atp_player_ranking_summary(p_player_id,p_to_date);
 SELECT coalesce(sum(points),0)::integer,
    coalesce(jsonb_agg(
      pg_catalog.jsonb_build_object(
        'event_key',event_key,'label',label,'points',points,
        'drop_date',drop_date,'category',rank_category,
        'estimated',estimated
      ) ORDER BY drop_date,event_key
    ),'[]'::jsonb)
 INTO v_expired,v_events
 FROM public.atp_player_breakdown(p_player_id,p_from_date)
 WHERE counting=true AND points>0
   AND drop_date>=p_from_date AND drop_date<p_to_date;
 RETURN pg_catalog.jsonb_build_object(
   'ok',true,'player_id',p_player_id,
   'from_date',p_from_date,'to_date',p_to_date,
   'points_before',v_old,'points_after',v_new,
   'expired_counted_points',v_expired,
   'other_effects_points',v_new-v_old+v_expired,
   'net_change_points',v_new-v_old,
   'expired_events',v_events,
   'calculation','ATP 52-week counting breakdown at both dates',
   'note','Other effects may include newly earned results and scores re-entering the best-results allocation. Not an attribution of specific replacement events.'
 );
END;
$function$;
REVOKE ALL ON FUNCTION public.atp_points_movement_v1(bigint,date,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.atp_points_movement_v1(bigint,date,date) TO service_role;
