-- Court Boss v57: fix mutable search_path warnings on pure immutable helpers.
-- Both helpers use only pg_catalog builtins and have no table references.
-- ALTER FUNCTION retains the existing function body, grants and volatility.
ALTER FUNCTION public.atp_historical_rank_category(text,text,text)
  SET search_path = pg_catalog;
ALTER FUNCTION public.atp500_bonus_swing_v18(date,date)
  SET search_path = pg_catalog;
