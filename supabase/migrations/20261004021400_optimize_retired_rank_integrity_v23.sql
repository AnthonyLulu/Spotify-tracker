-- Court Boss V23.3: accelerate retired-rank integrity checks
CREATE INDEX IF NOT EXISTS idx_players_retired_world_rank_v23
ON public.players (game_world_rank)
WHERE career_status='retired' AND game_world_rank IS NOT NULL;
