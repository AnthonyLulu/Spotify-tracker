-- 2026 special team-event registration modes.
-- These events must not be treated as ordinary individual knockout draws.
-- United Cup official format:
-- https://www.unitedcup.com/en/media/news/united-cup-2026-history-draw-schedule
-- Laver Cup official event guide:
-- https://lavercup.com/event-guide
-- Junior Davis Cup Finals 2026:
-- https://www.itftennis.com/en/news-and-media/articles/history-served-cairo-to-stage-landmark-junior-finals/

update tournaments
set registration_mode='national_team_selection',
    entry_rule_code='UNITED_CUP_TEAM',
    entry_rule_note='18 nations · 6 groupes de 3 · chaque rencontre: 1 simple ATP, 1 simple WTA, 1 double mixte · vainqueurs de groupe + meilleurs deuxièmes par ville vers les quarts.',
    singles_draw_size=null,
    qualifying_draw_size=null,
    doubles_draw_size=null,
    source_note='United Cup 2026 · compétition mixte par équipes nationales; ne pas traiter comme un tableau ATP individuel.'
where id=2078;

update tournaments
set registration_mode='captain_invitation',
    entry_rule_code='LAVER_CUP_INVITE',
    entry_rule_note='Team Europe vs Team World · sélection/captain picks · 12 matches maximum sur 3 jours · 1/2/3 points par victoire selon le jour · première équipe à 13 points.',
    singles_draw_size=null,
    qualifying_draw_size=null,
    doubles_draw_size=null,
    source_note='Laver Cup 2026 · compétition par équipes/invitation; ne pas traiter comme un tableau ATP individuel.'
where id=2040;

update tournaments
set registration_mode='junior_national_team_selection',
    entry_rule_code='JUNIOR_DAVIS_SELECTION',
    entry_rule_note='16 équipes nationales garçons · 4 groupes de 4 en round robin, puis phase à élimination directe après un jour de repos.',
    singles_draw_size=null,
    qualifying_draw_size=null,
    doubles_draw_size=null,
    source_note='ITF Davis Cup Junior Finals 2026 · compétition par équipes nationales; ne pas traiter comme un tournoi junior individuel.'
where id=3396;
