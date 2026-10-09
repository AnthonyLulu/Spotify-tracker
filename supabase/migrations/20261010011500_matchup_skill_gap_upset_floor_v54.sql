-- Court Boss v54: gradual, bounded upset floor for extreme Elo gaps.
-- At a 400-Elo gap or less, preserve 3.5%. At 1,000+ Elo, allow 0.5%.
-- This is an explicitly provisional, deterministic gameplay rule, not an
-- observed statistical calibration (the match ledgers must reach 200+ samples).
-- Only replace existing probability function bodies; no save/player writes.
DO $migration$
DECLARE
  fn text;
  fn_def text;
  old_expr text;
  new_expr text;
  gap_expr text;
  floor_expr text;
BEGIN
  FOREACH fn IN ARRAY ARRAY[
    'player_matchup_probability_v2_core',
    'player_matchup_probability_v2',
    'player_matchup_probability_v3',
    'player_matchup_probability_v4'
  ] LOOP
    SELECT pg_get_functiondef(p.oid)
    INTO fn_def
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.proname=fn
      AND oidvectortypes(p.proargtypes)='bigint, bigint, text, date, numeric, integer';

    IF fn_def IS NULL THEN
      RAISE EXCEPTION 'Missing gameplay probability function: %', fn;
    END IF;
    IF position('upset_floor numeric' IN fn_def)>0 THEN
      RAISE EXCEPTION 'Upset floor already migrated: %', fn;
    END IF;
    IF position(E'\nbegin' IN fn_def)=0 THEN
      RAISE EXCEPTION 'Unexpected function declaration: %', fn;
    END IF;

    gap_expr := CASE
      WHEN fn='player_matchup_probability_v2_core'
        THEN 'abs(aelo-belo)'
      ELSE
        'abs(coalesce((base->''components''->>''surface_elo_a'')::numeric,1500)-coalesce((base->''components''->>''surface_elo_b'')::numeric,1500))'
    END;
    floor_expr := 'upset_floor:=greatest(.005,least(.035,.035-greatest(0,' || gap_expr || '-400)*.00005));';

    IF fn='player_matchup_probability_v2_core' THEN
      old_expr := 'prob:=greatest(.035,least(.965,prob));';
      new_expr := floor_expr || E'\n  prob:=greatest(upset_floor,least(1-upset_floor,prob));';
    ELSE
      old_expr := 'fp:=greatest(.035,least(.965,';
      new_expr := floor_expr || E'\n  fp:=greatest(upset_floor,least(1-upset_floor,';
    END IF;

    IF position(old_expr IN fn_def)=0 THEN
      RAISE EXCEPTION 'Probability clamp changed upstream: %', fn;
    END IF;
    IF position(old_expr IN substring(fn_def FROM position(old_expr IN fn_def)+length(old_expr)))>0 THEN
      RAISE EXCEPTION 'Ambiguous probability clamp: %', fn;
    END IF;

    fn_def := replace(fn_def,E'\nbegin',E'\n  upset_floor numeric:=.035;\nbegin');
    fn_def := replace(fn_def,old_expr,new_expr);
    EXECUTE fn_def;
  END LOOP;
END
$migration$;
