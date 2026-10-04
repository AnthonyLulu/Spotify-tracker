-- Court Boss V23.2: accelerate world-rank integrity checks used by long-career audit

CREATE INDEX IF NOT EXISTS idx_players_active_visible_world_rank_v23
ON public.players (game_world_rank)
WHERE career_status='active'
  AND game_world_rank IS NOT NULL
  AND (data_source IS NULL OR data_source NOT ILIKE 'hidden duplicate merged into %');
