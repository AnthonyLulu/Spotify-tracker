-- v63: the player catalog's existing predicate uses a prefix-only test,
-- while /api/search-players excludes this phrase wherever it occurs.
-- Keep the original exclusion semantics, including two non-prefix hidden rows.
-- A matching partial browse index avoids sorting the entire 55k-player catalog.
CREATE INDEX IF NOT EXISTS idx_players_search_visible_exact_v63
ON public.players (potential DESC,current_ability DESC,id)
WHERE (data_source IS NULL OR data_source NOT ILIKE '%hidden duplicate merged into%');