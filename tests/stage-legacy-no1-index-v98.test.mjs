import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const sql=readFileSync(new URL('../qa/world-2050/stage-legacy-no1-index-v98.sql',import.meta.url),'utf8');
test('legacy rank index only touches 2025+ weeks-at-no1 lookup in isolated stage',()=>{
 assert.match(sql,/cb_e2e_checkpoint_20261010\.players/);
 assert.match(sql,/world_week_jobs_v1/);
 assert.match(sql,/FROM public\.game_saves/);
 assert.match(sql,/FROM public\.game_save_slots/);
 assert.match(sql,/FROM public\.career_state/);
 assert.match(sql,/CREATE INDEX IF NOT EXISTS cb_e2e_legacy_rank_history_no1_date_v96/);
 assert.match(sql,/ON public\.ranking_history\(snapshot_date,player_id\)/);
 assert.match(sql,/WHERE ranking=1/);
 assert.doesNotMatch(sql,/\b(?:delete|truncate|drop|update)\s+(?:from\s+)?public\./i);
});
