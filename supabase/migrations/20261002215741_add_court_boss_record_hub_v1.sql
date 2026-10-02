-- Court Boss Record Hub v1
-- Live migration version: 20261002215741
-- Historical baseline intentionally frozen to 2025-12-01.

create table if not exists public.record_catalog (
  code text primary key,
  category text not null,
  subcategory text,
  name text not null,
  description text,
  record_type text not null default 'numeric',
  unit text,
  baseline_value numeric,
  baseline_holder text,
  baseline_country text,
  baseline_year integer,
  rarity text not null default 'elite',
  dynamic_rule text,
  source_label text,
  source_url text,
  as_of_date date not null default date '2025-12-01',
  display_order integer not null default 100,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.record_occurrences (
  id bigserial primary key,
  record_code text not null references public.record_catalog(code) on delete cascade,
  player_id bigint references public.players(id) on delete set null,
  player_name text not null,
  country text,
  season integer,
  achieved_on date,
  value numeric,
  label text,
  source_type text not null default 'historical',
  source_label text,
  source_url text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create unique index if not exists record_occurrences_natural_uidx
  on public.record_occurrences(record_code, lower(player_name), coalesce(season,-1), coalesce(label,''));
create index if not exists record_occurrences_code_idx on public.record_occurrences(record_code);
create index if not exists record_occurrences_player_idx on public.record_occurrences(player_id);

alter table public.record_catalog enable row level security;
alter table public.record_occurrences enable row level security;

CREATE OR REPLACE FUNCTION public.cb_record_event_key(p_name text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select case
    when coalesce(p_name,'') ilike '%indian wells%' then 'indian_wells'
    when coalesce(p_name,'') ilike '%miami%' and coalesce(p_name,'') not ilike '%wct%' then 'miami'
    when coalesce(p_name,'') ilike '%monte%carlo%' then 'monte_carlo'
    when coalesce(p_name,'') ilike '%madrid%' then 'madrid'
    when coalesce(p_name,'') ilike '%rome%' or coalesce(p_name,'') ilike '%roma%' then 'rome'
    when coalesce(p_name,'') ilike '%canada%' or coalesce(p_name,'') ilike '%montreal%' or coalesce(p_name,'') ilike '%toronto%' then 'canada'
    when coalesce(p_name,'') ilike '%cincinnati%' then 'cincinnati'
    when coalesce(p_name,'') ilike '%shanghai%' then 'shanghai'
    when coalesce(p_name,'') ilike '%paris%' and coalesce(p_name,'') not ilike '%olymp%' then 'paris'
    when coalesce(p_name,'') ilike '%hamburg%' then 'hamburg'
    when coalesce(p_name,'') ilike '%australian%' then 'australian_open'
    when coalesce(p_name,'') ilike '%roland garros%' or coalesce(p_name,'') ilike '%french open%' then 'roland_garros'
    when coalesce(p_name,'') ilike '%wimbledon%' then 'wimbledon'
    when coalesce(p_name,'') ilike '%us open%' or coalesce(p_name,'') ilike '%u.s. open%' then 'us_open'
    when coalesce(p_name,'') ilike '%olymp%' then 'olympics'
    else lower(regexp_replace(trim(coalesce(p_name,'')), '[^a-zA-Z0-9]+', '_', 'g'))
  end;
$function$


with src as (
  select *
  from jsonb_to_recordset('[{"code":"masters_titles_career","name":"Plus de titres Masters 1000","unit":"titres","rarity":"legendary","category":"Masters 1000","metadata":{"scope":"career"},"as_of_date":"2025-12-01","source_url":"https://www.atptour.com/-/media/files/media-guide/2025/2025-atp-media-guide-full.pdf","description":"Record de titres ATP Masters 1000 en simple.","record_type":"numeric","subcategory":"Carrière","dynamic_rule":"masters_titles_career","source_label":"ATP Media Guide 2025","baseline_year":2023,"display_order":10,"baseline_value":40,"baseline_holder":"Novak Djokovic","baseline_country":"SRB"},{"code":"masters_titles_season","name":"Plus de Masters sur une saison","unit":"titres","rarity":"legendary","category":"Masters 1000","metadata":{"scope":"season"},"as_of_date":"2025-12-01","source_url":"https://www.atptour.com/-/media/files/media-guide/2025/2025-atp-media-guide-full.pdf","description":"Record de titres Masters 1000 gagnés au cours d’une même saison.","record_type":"numeric","subcategory":"Saison","dynamic_rule":"masters_titles_season","source_label":"ATP Media Guide 2025","baseline_year":2015,"display_order":20,"baseline_value":6,"baseline_holder":"Novak Djokovic","baseline_country":"SRB"},{"code":"masters_consecutive_titles","name":"Masters consécutifs remportés","unit":"titres","rarity":"legendary","category":"Masters 1000","metadata":{"ties":true,"scope":"streak"},"as_of_date":"2025-12-01","source_url":"https://www.atptour.com/-/media/files/media-guide/2025/2025-atp-media-guide-full.pdf","description":"Plus longue série de titres Masters 1000 consécutifs.","record_type":"numeric","subcategory":"Série","dynamic_rule":null,"source_label":"ATP Media Guide 2025","baseline_year":null,"display_order":30,"baseline_value":4,"baseline_holder":"Novak Djokovic / Rafael Nadal","baseline_country":null},{"code":"masters_win_streak","name":"Plus longue série de victoires","unit":"victoires","rarity":"legendary","category":"Masters 1000","metadata":{"end":"2012 Cincinnati F","scope":"streak"},"as_of_date":"2025-12-01","source_url":"https://www.atptour.com/-/media/files/media-guide/2021/2021-atp-media-guide-20210108.pdf","description":"Plus longue série de matchs remportés en Masters 1000.","record_type":"numeric","subcategory":"Série","dynamic_rule":null,"source_label":"ATP Media Guide 2021","baseline_year":2011,"display_order":40,"baseline_value":31,"baseline_holder":"Novak Djokovic","baseline_country":"SRB"},{"code":"career_golden_masters","name":"Career Golden Masters","unit":"tournois","rarity":"mythic","category":"Exploits","metadata":{"target":9},"as_of_date":"2025-12-01","source_url":"https://www.atptour.com/en/news/djokovic-number-one-profile","description":"Remporter chacun des neuf Masters 1000 actuels au moins une fois.","record_type":"achievement","subcategory":"Masters 1000","dynamic_rule":"career_golden_masters","source_label":"ATP Tour","baseline_year":2018,"display_order":50,"baseline_value":9,"baseline_holder":"Novak Djokovic","baseline_country":"SRB"},{"code":"double_career_golden_masters","name":"Double Career Golden Masters","unit":"cycles","rarity":"mythic","category":"Exploits","metadata":{"target":2},"as_of_date":"2025-12-01","source_url":"https://www.atptour.com/en/news/djokovic-100-titles-longform-tribute","description":"Remporter chacun des neuf Masters 1000 actuels au moins deux fois.","record_type":"achievement","subcategory":"Masters 1000","dynamic_rule":"double_career_golden_masters","source_label":"ATP Tour","baseline_year":2020,"display_order":60,"baseline_value":2,"baseline_holder":"Novak Djokovic","baseline_country":"SRB"},{"code":"sunshine_double","name":"Sunshine Double","unit":"sweep","rarity":"legendary","category":"Exploits","metadata":{"events":["indian_wells","miami"]},"as_of_date":"2025-12-01","source_url":"https://www.atptour.com/-/media/files/media-guide/2025/2025-atp-media-guide-full.pdf","description":"Gagner Indian Wells et Miami la même saison.","record_type":"achievement","subcategory":"Enchaînement","dynamic_rule":"sunshine_double","source_label":"ATP Media Guide 2025","baseline_year":null,"display_order":70,"baseline_value":2,"baseline_holder":"Multiple","baseline_country":null},{"code":"clay_masters_sweep","name":"Sweep Masters sur terre","unit":"sweep","rarity":"mythic","category":"Exploits","metadata":{"events":["monte_carlo","madrid","rome"]},"as_of_date":"2025-12-01","source_url":"https://www.atptour.com/-/media/files/media-guide/2025/2025-atp-media-guide-full.pdf","description":"Gagner Monte-Carlo, Madrid et Rome la même saison.","record_type":"achievement","subcategory":"Enchaînement","dynamic_rule":"clay_masters_sweep","source_label":"ATP Media Guide 2025","baseline_year":2010,"display_order":80,"baseline_value":3,"baseline_holder":"Rafael Nadal","baseline_country":"ESP"},{"code":"summer_masters_sweep","name":"Summer Sweep","unit":"sweep","rarity":"legendary","category":"Exploits","metadata":{"events":["canada","cincinnati"]},"as_of_date":"2025-12-01","source_url":"https://www.atptour.com/-/media/files/media-guide/2025/2025-atp-media-guide-full.pdf","description":"Gagner Canada et Cincinnati la même saison.","record_type":"achievement","subcategory":"Enchaînement","dynamic_rule":"summer_masters_sweep","source_label":"ATP Media Guide 2025","baseline_year":null,"display_order":90,"baseline_value":2,"baseline_holder":"Multiple","baseline_country":null},{"code":"fall_masters_sweep","name":"Fall Sweep","unit":"sweep","rarity":"legendary","category":"Exploits","metadata":{"events":["shanghai","paris"]},"as_of_date":"2025-12-01","source_url":"https://www.atptour.com/-/media/files/media-guide/2025/2025-atp-media-guide-full.pdf","description":"Gagner Shanghai et Paris la même saison.","record_type":"achievement","subcategory":"Enchaînement","dynamic_rule":"fall_masters_sweep","source_label":"ATP Media Guide 2025","baseline_year":null,"display_order":100,"baseline_value":2,"baseline_holder":"Multiple","baseline_country":null},{"code":"career_golden_slam","name":"Career Golden Slam","unit":"trophées","rarity":"mythic","category":"Exploits","metadata":{"target":5},"as_of_date":"2025-12-01","source_url":"https://www.atptour.com/en/news/djokovic-olympics-2024-big-titles-kings/","description":"Gagner les quatre Majeurs et l’or olympique en simple au cours d’une carrière.","record_type":"achievement","subcategory":"Grand Chelem","dynamic_rule":"career_golden_slam","source_label":"ATP Tour","baseline_year":null,"display_order":110,"baseline_value":5,"baseline_holder":"Agassi / Nadal / Djokovic","baseline_country":null},{"code":"calendar_grand_slam_men","name":"Grand Chelem calendaire","unit":"Majeurs","rarity":"mythic","category":"Grand Chelem","metadata":{"target":4,"open_era":true},"as_of_date":"2025-12-01","source_url":"https://www.itftennis.com/en/tours/grand-slam-tournaments/","description":"Gagner les quatre Majeurs en simple la même année.","record_type":"achievement","subcategory":"Saison","dynamic_rule":"calendar_grand_slam","source_label":"ITF","baseline_year":1969,"display_order":120,"baseline_value":4,"baseline_holder":"Rod Laver","baseline_country":"AUS"},{"code":"calendar_golden_slam_men","name":"Golden Slam calendaire","unit":"trophées","rarity":"mythic","category":"Grand Chelem","metadata":{"target":5,"mens_singles":true},"as_of_date":"2025-12-01","source_url":"https://www.itftennis.com/en/tours/grand-slam-tournaments/","description":"Gagner les quatre Majeurs et l’or olympique en simple la même année. Aucun homme ne l’avait réalisé à la date de référence.","record_type":"challenge","subcategory":"Saison","dynamic_rule":"calendar_golden_slam","source_label":"ITF","baseline_year":null,"display_order":130,"baseline_value":5,"baseline_holder":null,"baseline_country":null},{"code":"slam_years_streak","name":"Années consécutives avec un Majeur","unit":"saisons","rarity":"legendary","category":"Grand Chelem","metadata":{"to":2014,"from":2005},"as_of_date":"2025-12-01","source_url":"https://www.atptour.com/en/news/rafael-nadal-retirement-untouchable-records","description":"Plus longue série de saisons consécutives avec au moins un titre du Grand Chelem en simple.","record_type":"numeric","subcategory":"Série","dynamic_rule":null,"source_label":"ATP Tour","baseline_year":2014,"display_order":140,"baseline_value":10,"baseline_holder":"Rafael Nadal","baseline_country":"ESP"},{"code":"career_aces_reference","name":"Aces en carrière · référence ATP","unit":"aces","rarity":"legendary","category":"Service","metadata":{"note":"ATP Tour and Grand Slam singles matches, ATP bio citation","scope":"career"},"as_of_date":"2025-12-01","source_url":"https://www.atptour.com/en/players/jawiki/I186/bio","description":"Marque de carrière citée par l’ATP pour John Isner. Les définitions statistiques peuvent varier selon les archives.","record_type":"numeric","subcategory":"Carrière","dynamic_rule":"career_aces","source_label":"ATP Tour · bio John Isner","baseline_year":2023,"display_order":150,"baseline_value":14411,"baseline_holder":"John Isner","baseline_country":"USA"},{"code":"masters_aces_edition_save","name":"Aces sur une édition Masters · sauvegarde","unit":"aces","rarity":"elite","category":"Service","metadata":{"scope":"save","historical_absolute_claim":false},"as_of_date":"2025-12-01","source_url":"","description":"Meilleur total d’aces cumulé par ton joueur sur une édition Masters 1000 dans la sauvegarde.","record_type":"dynamic","subcategory":"Masters 1000","dynamic_rule":"masters_aces_edition","source_label":"Court Boss","baseline_year":null,"display_order":160,"baseline_value":null,"baseline_holder":null,"baseline_country":null},{"code":"masters_aces_match_save","name":"Aces sur un match Masters · sauvegarde","unit":"aces","rarity":"elite","category":"Service","metadata":{"scope":"save","historical_absolute_claim":false},"as_of_date":"2025-12-01","source_url":"","description":"Meilleur total d’aces de ton joueur dans un match de Masters 1000 joué dans la sauvegarde.","record_type":"dynamic","subcategory":"Masters 1000","dynamic_rule":"masters_aces_match","source_label":"Court Boss","baseline_year":null,"display_order":170,"baseline_value":null,"baseline_holder":null,"baseline_country":null},{"code":"masters_event_iw","name":"Roi d’Indian Wells","unit":"titres","rarity":"legendary","category":"Masters par tournoi","metadata":{"event":"indian_wells"},"as_of_date":"2025-12-01","source_url":"https://www.atptour.com/en/news/atp-masters-1000-records-tournaments-stats","description":"Record de titres à Indian Wells.","record_type":"numeric","subcategory":"Indian Wells","dynamic_rule":null,"source_label":"ATP Masters 1000 records","baseline_year":null,"display_order":201,"baseline_value":5,"baseline_holder":"Novak Djokovic / Roger Federer","baseline_country":null},{"code":"masters_event_miami","name":"Roi de Miami","unit":"titres","rarity":"legendary","category":"Masters par tournoi","metadata":{"event":"miami"},"as_of_date":"2025-12-01","source_url":"https://www.atptour.com/en/news/atp-masters-1000-records-tournaments-stats","description":"Record de titres au Miami Open.","record_type":"numeric","subcategory":"Miami","dynamic_rule":null,"source_label":"ATP Masters 1000 records","baseline_year":null,"display_order":202,"baseline_value":6,"baseline_holder":"Andre Agassi / Novak Djokovic","baseline_country":null},{"code":"masters_event_monte_carlo","name":"Roi de Monte-Carlo","unit":"titres","rarity":"mythic","category":"Masters par tournoi","metadata":{"event":"monte_carlo"},"as_of_date":"2025-12-01","source_url":"https://www.atptour.com/en/news/atp-masters-1000-records-tournaments-stats","description":"Record de titres à Monte-Carlo.","record_type":"numeric","subcategory":"Monte-Carlo","dynamic_rule":null,"source_label":"ATP Masters 1000 records","baseline_year":null,"display_order":203,"baseline_value":11,"baseline_holder":"Rafael Nadal","baseline_country":"ESP"},{"code":"masters_event_madrid","name":"Roi de Madrid","unit":"titres","rarity":"legendary","category":"Masters par tournoi","metadata":{"event":"madrid"},"as_of_date":"2025-12-01","source_url":"https://www.atptour.com/en/news/atp-masters-1000-records-tournaments-stats","description":"Record de titres à Madrid.","record_type":"numeric","subcategory":"Madrid","dynamic_rule":null,"source_label":"ATP Masters 1000 records","baseline_year":null,"display_order":204,"baseline_value":5,"baseline_holder":"Rafael Nadal","baseline_country":"ESP"},{"code":"masters_event_rome","name":"Roi de Rome","unit":"titres","rarity":"mythic","category":"Masters par tournoi","metadata":{"event":"rome"},"as_of_date":"2025-12-01","source_url":"https://www.atptour.com/en/news/atp-masters-1000-records-tournaments-stats","description":"Record de titres à Rome.","record_type":"numeric","subcategory":"Rome","dynamic_rule":null,"source_label":"ATP Masters 1000 records","baseline_year":null,"display_order":205,"baseline_value":10,"baseline_holder":"Rafael Nadal","baseline_country":"ESP"},{"code":"masters_event_canada","name":"Roi du Canada","unit":"titres","rarity":"legendary","category":"Masters par tournoi","metadata":{"event":"canada"},"as_of_date":"2025-12-01","source_url":"https://www.atptour.com/en/news/atp-masters-1000-records-tournaments-stats","description":"Record de titres au Masters du Canada.","record_type":"numeric","subcategory":"Canada","dynamic_rule":null,"source_label":"ATP Masters 1000 records","baseline_year":null,"display_order":206,"baseline_value":6,"baseline_holder":"Ivan Lendl","baseline_country":"USA"},{"code":"masters_event_cincinnati","name":"Roi de Cincinnati","unit":"titres","rarity":"legendary","category":"Masters par tournoi","metadata":{"event":"cincinnati"},"as_of_date":"2025-12-01","source_url":"https://www.atptour.com/en/news/atp-masters-1000-records-tournaments-stats","description":"Record de titres à Cincinnati.","record_type":"numeric","subcategory":"Cincinnati","dynamic_rule":null,"source_label":"ATP Masters 1000 records","baseline_year":null,"display_order":207,"baseline_value":7,"baseline_holder":"Roger Federer","baseline_country":"SUI"},{"code":"masters_event_shanghai","name":"Roi de Shanghai","unit":"titres","rarity":"legendary","category":"Masters par tournoi","metadata":{"event":"shanghai"},"as_of_date":"2025-12-01","source_url":"https://www.atptour.com/en/news/atp-masters-1000-records-tournaments-stats","description":"Record de titres à Shanghai.","record_type":"numeric","subcategory":"Shanghai","dynamic_rule":null,"source_label":"ATP Masters 1000 records","baseline_year":null,"display_order":208,"baseline_value":4,"baseline_holder":"Novak Djokovic","baseline_country":"SRB"},{"code":"masters_event_paris","name":"Roi de Paris","unit":"titres","rarity":"legendary","category":"Masters par tournoi","metadata":{"event":"paris"},"as_of_date":"2025-12-01","source_url":"https://www.atptour.com/en/news/atp-masters-1000-records-tournaments-stats","description":"Record de titres au Masters de Paris.","record_type":"numeric","subcategory":"Paris","dynamic_rule":null,"source_label":"ATP Masters 1000 records","baseline_year":null,"display_order":209,"baseline_value":7,"baseline_holder":"Novak Djokovic","baseline_country":"SRB"}]'::jsonb) as x(
    code text, category text, subcategory text, name text, description text,
    record_type text, unit text, baseline_value numeric, baseline_holder text,
    baseline_country text, baseline_year integer, rarity text, dynamic_rule text,
    source_label text, source_url text, as_of_date date, display_order integer, metadata jsonb
  )
)
insert into public.record_catalog(
  code,category,subcategory,name,description,record_type,unit,baseline_value,
  baseline_holder,baseline_country,baseline_year,rarity,dynamic_rule,source_label,
  source_url,as_of_date,display_order,metadata
)
select code,category,subcategory,name,description,record_type,unit,baseline_value,
       baseline_holder,baseline_country,baseline_year,rarity,dynamic_rule,source_label,
       source_url,as_of_date,display_order,coalesce(metadata,'{}'::jsonb)
from src
on conflict (code) do update set
  category=excluded.category,subcategory=excluded.subcategory,name=excluded.name,
  description=excluded.description,record_type=excluded.record_type,unit=excluded.unit,
  baseline_value=excluded.baseline_value,baseline_holder=excluded.baseline_holder,
  baseline_country=excluded.baseline_country,baseline_year=excluded.baseline_year,
  rarity=excluded.rarity,dynamic_rule=excluded.dynamic_rule,source_label=excluded.source_label,
  source_url=excluded.source_url,as_of_date=excluded.as_of_date,
  display_order=excluded.display_order,metadata=excluded.metadata,updated_at=now();

with src as (
  select *
  from jsonb_to_recordset('[{"label":"Indian Wells + Miami","value":1,"season":1991,"country":"USA","metadata":{},"player_id":51926,"source_url":"https://www.atptour.com/-/media/files/media-guide/2025/2025-atp-media-guide-full.pdf","achieved_on":null,"player_name":"Jim Courier","record_code":"sunshine_double","source_type":"historical","source_label":"ATP Media Guide 2025"},{"label":"Indian Wells + Miami","value":1,"season":1992,"country":"USA","metadata":{},"player_id":48556,"source_url":"https://www.atptour.com/-/media/files/media-guide/2025/2025-atp-media-guide-full.pdf","achieved_on":null,"player_name":"Michael Chang","record_code":"sunshine_double","source_type":"historical","source_label":"ATP Media Guide 2025"},{"label":"Indian Wells + Miami","value":1,"season":1994,"country":"USA","metadata":{},"player_id":20001,"source_url":"https://www.atptour.com/-/media/files/media-guide/2025/2025-atp-media-guide-full.pdf","achieved_on":null,"player_name":"Pete Sampras","record_code":"sunshine_double","source_type":"historical","source_label":"ATP Media Guide 2025"},{"label":"Indian Wells + Miami","value":1,"season":1998,"country":"CHI","metadata":{},"player_id":20014,"source_url":"https://www.atptour.com/-/media/files/media-guide/2025/2025-atp-media-guide-full.pdf","achieved_on":null,"player_name":"Marcelo Rios","record_code":"sunshine_double","source_type":"historical","source_label":"ATP Media Guide 2025"},{"label":"Indian Wells + Miami","value":1,"season":2001,"country":"USA","metadata":{},"player_id":51883,"source_url":"https://www.atptour.com/-/media/files/media-guide/2025/2025-atp-media-guide-full.pdf","achieved_on":null,"player_name":"Andre Agassi","record_code":"sunshine_double","source_type":"historical","source_label":"ATP Media Guide 2025"},{"label":"Indian Wells + Miami","value":1,"season":2005,"country":"SUI","metadata":{},"player_id":14405,"source_url":"https://www.atptour.com/-/media/files/media-guide/2025/2025-atp-media-guide-full.pdf","achieved_on":null,"player_name":"Roger Federer","record_code":"sunshine_double","source_type":"historical","source_label":"ATP Media Guide 2025"},{"label":"Indian Wells + Miami","value":1,"season":2006,"country":"SUI","metadata":{},"player_id":14405,"source_url":"https://www.atptour.com/-/media/files/media-guide/2025/2025-atp-media-guide-full.pdf","achieved_on":null,"player_name":"Roger Federer","record_code":"sunshine_double","source_type":"historical","source_label":"ATP Media Guide 2025"},{"label":"Indian Wells + Miami","value":1,"season":2011,"country":"SRB","metadata":{},"player_id":12,"source_url":"https://www.atptour.com/-/media/files/media-guide/2025/2025-atp-media-guide-full.pdf","achieved_on":null,"player_name":"Novak Djokovic","record_code":"sunshine_double","source_type":"historical","source_label":"ATP Media Guide 2025"},{"label":"Indian Wells + Miami","value":1,"season":2014,"country":"SRB","metadata":{},"player_id":12,"source_url":"https://www.atptour.com/-/media/files/media-guide/2025/2025-atp-media-guide-full.pdf","achieved_on":null,"player_name":"Novak Djokovic","record_code":"sunshine_double","source_type":"historical","source_label":"ATP Media Guide 2025"},{"label":"Indian Wells + Miami","value":1,"season":2015,"country":"SRB","metadata":{},"player_id":12,"source_url":"https://www.atptour.com/-/media/files/media-guide/2025/2025-atp-media-guide-full.pdf","achieved_on":null,"player_name":"Novak Djokovic","record_code":"sunshine_double","source_type":"historical","source_label":"ATP Media Guide 2025"},{"label":"Indian Wells + Miami","value":1,"season":2016,"country":"SRB","metadata":{},"player_id":12,"source_url":"https://www.atptour.com/-/media/files/media-guide/2025/2025-atp-media-guide-full.pdf","achieved_on":null,"player_name":"Novak Djokovic","record_code":"sunshine_double","source_type":"historical","source_label":"ATP Media Guide 2025"},{"label":"Indian Wells + Miami","value":1,"season":2017,"country":"SUI","metadata":{},"player_id":14405,"source_url":"https://www.atptour.com/-/media/files/media-guide/2025/2025-atp-media-guide-full.pdf","achieved_on":null,"player_name":"Roger Federer","record_code":"sunshine_double","source_type":"historical","source_label":"ATP Media Guide 2025"},{"label":"Monte-Carlo + Madrid + Rome","value":1,"season":2010,"country":"ESP","metadata":{},"player_id":14406,"source_url":"https://www.atptour.com/-/media/files/media-guide/2025/2025-atp-media-guide-full.pdf","achieved_on":null,"player_name":"Rafael Nadal","record_code":"clay_masters_sweep","source_type":"historical","source_label":"ATP Media Guide 2025"},{"label":"Canada + Cincinnati","value":1,"season":1995,"country":"USA","metadata":{},"player_id":51883,"source_url":"https://www.atptour.com/-/media/files/media-guide/2025/2025-atp-media-guide-full.pdf","achieved_on":null,"player_name":"Andre Agassi","record_code":"summer_masters_sweep","source_type":"historical","source_label":"ATP Media Guide 2025"},{"label":"Canada + Cincinnati","value":1,"season":1998,"country":"AUS","metadata":{},"player_id":52018,"source_url":"https://www.atptour.com/-/media/files/media-guide/2025/2025-atp-media-guide-full.pdf","achieved_on":null,"player_name":"Patrick Rafter","record_code":"summer_masters_sweep","source_type":"historical","source_label":"ATP Media Guide 2025"},{"label":"Canada + Cincinnati","value":1,"season":2003,"country":"USA","metadata":{},"player_id":52122,"source_url":"https://www.atptour.com/-/media/files/media-guide/2025/2025-atp-media-guide-full.pdf","achieved_on":null,"player_name":"Andy Roddick","record_code":"summer_masters_sweep","source_type":"historical","source_label":"ATP Media Guide 2025"},{"label":"Canada + Cincinnati","value":1,"season":2013,"country":"ESP","metadata":{},"player_id":14406,"source_url":"https://www.atptour.com/-/media/files/media-guide/2025/2025-atp-media-guide-full.pdf","achieved_on":null,"player_name":"Rafael Nadal","record_code":"summer_masters_sweep","source_type":"historical","source_label":"ATP Media Guide 2025"},{"label":"Madrid + Paris (format historique)","value":1,"season":2004,"country":"RUS","metadata":{},"player_id":20013,"source_url":"https://www.atptour.com/-/media/files/media-guide/2025/2025-atp-media-guide-full.pdf","achieved_on":null,"player_name":"Marat Safin","record_code":"fall_masters_sweep","source_type":"historical","source_label":"ATP Media Guide 2025"},{"label":"Madrid + Paris (format historique)","value":1,"season":2007,"country":"ARG","metadata":{},"player_id":52116,"source_url":"https://www.atptour.com/-/media/files/media-guide/2025/2025-atp-media-guide-full.pdf","achieved_on":null,"player_name":"David Nalbandian","record_code":"fall_masters_sweep","source_type":"historical","source_label":"ATP Media Guide 2025"},{"label":"Shanghai + Paris","value":1,"season":2013,"country":"SRB","metadata":{},"player_id":12,"source_url":"https://www.atptour.com/-/media/files/media-guide/2025/2025-atp-media-guide-full.pdf","achieved_on":null,"player_name":"Novak Djokovic","record_code":"fall_masters_sweep","source_type":"historical","source_label":"ATP Media Guide 2025"},{"label":"Shanghai + Paris","value":1,"season":2015,"country":"SRB","metadata":{},"player_id":12,"source_url":"https://www.atptour.com/-/media/files/media-guide/2025/2025-atp-media-guide-full.pdf","achieved_on":null,"player_name":"Novak Djokovic","record_code":"fall_masters_sweep","source_type":"historical","source_label":"ATP Media Guide 2025"},{"label":"Shanghai + Paris","value":1,"season":2016,"country":"GBR","metadata":{},"player_id":20003,"source_url":"https://www.atptour.com/-/media/files/media-guide/2025/2025-atp-media-guide-full.pdf","achieved_on":null,"player_name":"Andy Murray","record_code":"fall_masters_sweep","source_type":"historical","source_label":"ATP Media Guide 2025"},{"label":"9 Masters différents","value":9,"season":2018,"country":"SRB","metadata":{},"player_id":12,"source_url":"https://www.atptour.com/en/news/djokovic-number-one-profile","achieved_on":null,"player_name":"Novak Djokovic","record_code":"career_golden_masters","source_type":"historical","source_label":"ATP Tour"},{"label":"Deux fois les 9 Masters","value":2,"season":2020,"country":"SRB","metadata":{},"player_id":12,"source_url":"https://www.atptour.com/en/news/djokovic-100-titles-longform-tribute","achieved_on":null,"player_name":"Novak Djokovic","record_code":"double_career_golden_masters","source_type":"historical","source_label":"ATP Tour"},{"label":"4 Majeurs + or olympique","value":5,"season":1999,"country":"USA","metadata":{},"player_id":51883,"source_url":"https://www.atptour.com/en/news/djokovic-olympics-2024-big-titles-kings/","achieved_on":null,"player_name":"Andre Agassi","record_code":"career_golden_slam","source_type":"historical","source_label":"ATP Tour"},{"label":"4 Majeurs + or olympique","value":5,"season":2010,"country":"ESP","metadata":{},"player_id":14406,"source_url":"https://www.atptour.com/en/news/djokovic-olympics-2024-big-titles-kings/","achieved_on":null,"player_name":"Rafael Nadal","record_code":"career_golden_slam","source_type":"historical","source_label":"ATP Tour"},{"label":"4 Majeurs + or olympique","value":5,"season":2024,"country":"SRB","metadata":{},"player_id":12,"source_url":"https://www.atptour.com/en/news/djokovic-olympics-2024-big-titles-kings/","achieved_on":null,"player_name":"Novak Djokovic","record_code":"career_golden_slam","source_type":"historical","source_label":"ATP Tour"},{"label":"Australian Open + Roland-Garros + Wimbledon + US Open","value":4,"season":1969,"country":"AUS","metadata":{},"player_id":20005,"source_url":"https://www.itftennis.com/en/tours/grand-slam-tournaments/","achieved_on":null,"player_name":"Rod Laver","record_code":"calendar_grand_slam_men","source_type":"historical","source_label":"ITF"},{"label":"6 Masters 1000","value":6,"season":2015,"country":"SRB","metadata":{},"player_id":12,"source_url":"https://www.atptour.com/-/media/files/media-guide/2025/2025-atp-media-guide-full.pdf","achieved_on":null,"player_name":"Novak Djokovic","record_code":"masters_titles_season","source_type":"historical","source_label":"ATP Media Guide 2025"},{"label":"31 victoires · 2011 Indian Wells à 2012 Cincinnati F","value":31,"season":2011,"country":"SRB","metadata":{},"player_id":12,"source_url":"https://www.atptour.com/-/media/files/media-guide/2021/2021-atp-media-guide-20210108.pdf","achieved_on":null,"player_name":"Novak Djokovic","record_code":"masters_win_streak","source_type":"historical","source_label":"ATP Media Guide 2021"},{"label":"2014 Paris → 2015 Monte-Carlo","value":4,"season":2015,"country":"SRB","metadata":{},"player_id":12,"source_url":"https://www.atptour.com/-/media/files/media-guide/2025/2025-atp-media-guide-full.pdf","achieved_on":null,"player_name":"Novak Djokovic","record_code":"masters_consecutive_titles","source_type":"historical","source_label":"ATP Media Guide 2025"},{"label":"2015 Shanghai → 2016 Miami","value":4,"season":2016,"country":"SRB","metadata":{},"player_id":12,"source_url":"https://www.atptour.com/-/media/files/media-guide/2025/2025-atp-media-guide-full.pdf","achieved_on":null,"player_name":"Novak Djokovic","record_code":"masters_consecutive_titles","source_type":"historical","source_label":"ATP Media Guide 2025"},{"label":"Madrid → Cincinnati","value":4,"season":2013,"country":"ESP","metadata":{},"player_id":14406,"source_url":"https://www.atptour.com/-/media/files/media-guide/2025/2025-atp-media-guide-full.pdf","achieved_on":null,"player_name":"Rafael Nadal","record_code":"masters_consecutive_titles","source_type":"historical","source_label":"ATP Media Guide 2025"}]'::jsonb) as x(
    record_code text, player_id bigint, player_name text, country text, season integer,
    achieved_on date, value numeric, label text, source_type text, source_label text,
    source_url text, metadata jsonb
  )
)
insert into public.record_occurrences(
  record_code,player_id,player_name,country,season,achieved_on,value,label,
  source_type,source_label,source_url,metadata
)
select record_code,player_id,player_name,country,season,achieved_on,value,label,
       source_type,source_label,source_url,coalesce(metadata,'{}'::jsonb)
from src
on conflict do nothing;

CREATE OR REPLACE FUNCTION public.court_boss_record_hub(p_player_id bigint DEFAULT NULL::bigint, p_date date DEFAULT '2025-12-01'::date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_pid bigint;
  v_name text;
  v_country text;
  v_masters_titles integer := 0;
  v_masters_season integer := 0;
  v_masters_unique integer := 0;
  v_double_golden_events integer := 0;
  v_slam_unique integer := 0;
  v_has_olympic boolean := false;
  v_sunshine boolean := false;
  v_clay boolean := false;
  v_summer boolean := false;
  v_fall boolean := false;
  v_calendar_slam boolean := false;
  v_calendar_golden boolean := false;
  v_career_aces bigint := 0;
  v_masters_match_aces integer := 0;
  v_masters_edition_aces integer := 0;
  v_progress jsonb := '[]'::jsonb;
  v_catalog jsonb;
  v_occurrences jsonb;
begin
  select coalesce(p_player_id,cs.managed_player_id)
    into v_pid
  from public.career_state cs
  where cs.id='demo';

  if v_pid is null then
    v_pid := p_player_id;
  end if;

  select p.name,p.country into v_name,v_country from public.players p where p.id=v_pid;

  if v_pid is not null then
    select count(*) into v_masters_titles
    from (
      select distinct extract(year from pt.title_date)::int as season, public.cb_record_event_key(pt.tournament_name) as event_key
      from public.player_titles pt
      where pt.player_id=v_pid and pt.event_type='singles' and pt.title_date<=p_date
        and coalesce(pt.level,'') ilike '%1000%'
    ) q;

    select coalesce(max(c),0) into v_masters_season
    from (
      select extract(year from pt.title_date)::int as season,
             count(distinct public.cb_record_event_key(pt.tournament_name)) as c
      from public.player_titles pt
      where pt.player_id=v_pid and pt.event_type='singles' and pt.title_date<=p_date
        and coalesce(pt.level,'') ilike '%1000%'
      group by extract(year from pt.title_date)::int
    ) q;

    select count(distinct public.cb_record_event_key(pt.tournament_name)) into v_masters_unique
    from public.player_titles pt
    where pt.player_id=v_pid and pt.event_type='singles' and pt.title_date<=p_date
      and public.cb_record_event_key(pt.tournament_name) in ('indian_wells','miami','monte_carlo','madrid','rome','canada','cincinnati','shanghai','paris');

    select count(*) into v_double_golden_events
    from (
      select public.cb_record_event_key(pt.tournament_name) event_key,
             count(distinct extract(year from pt.title_date)::int) c
      from public.player_titles pt
      where pt.player_id=v_pid and pt.event_type='singles' and pt.title_date<=p_date
        and public.cb_record_event_key(pt.tournament_name) in ('indian_wells','miami','monte_carlo','madrid','rome','canada','cincinnati','shanghai','paris')
      group by public.cb_record_event_key(pt.tournament_name)
      having count(distinct extract(year from pt.title_date)::int)>=2
    ) q;

    select count(distinct public.cb_record_event_key(pt.tournament_name)) into v_slam_unique
    from public.player_titles pt
    where pt.player_id=v_pid and pt.event_type='singles' and pt.title_date<=p_date
      and public.cb_record_event_key(pt.tournament_name) in ('australian_open','roland_garros','wimbledon','us_open');

    select exists(
      select 1 from public.player_titles pt
      where pt.player_id=v_pid and pt.event_type='singles' and pt.title_date<=p_date
      and public.cb_record_event_key(pt.tournament_name)='olympics'
    ) into v_has_olympic;

    select exists(
      select 1 from (
        select extract(year from pt.title_date)::int season,
               count(distinct public.cb_record_event_key(pt.tournament_name)) c
        from public.player_titles pt
        where pt.player_id=v_pid and pt.event_type='singles' and pt.title_date<=p_date
          and public.cb_record_event_key(pt.tournament_name) in ('indian_wells','miami')
        group by extract(year from pt.title_date)::int
      ) s where c=2
    ) into v_sunshine;

    select exists(
      select 1 from (
        select extract(year from pt.title_date)::int season,
               count(distinct public.cb_record_event_key(pt.tournament_name)) c
        from public.player_titles pt
        where pt.player_id=v_pid and pt.event_type='singles' and pt.title_date<=p_date
          and public.cb_record_event_key(pt.tournament_name) in ('monte_carlo','madrid','rome')
        group by extract(year from pt.title_date)::int
      ) s where c=3
    ) into v_clay;

    select exists(
      select 1 from (
        select extract(year from pt.title_date)::int season,
               count(distinct public.cb_record_event_key(pt.tournament_name)) c
        from public.player_titles pt
        where pt.player_id=v_pid and pt.event_type='singles' and pt.title_date<=p_date
          and public.cb_record_event_key(pt.tournament_name) in ('canada','cincinnati')
        group by extract(year from pt.title_date)::int
      ) s where c=2
    ) into v_summer;

    select exists(
      select 1 from (
        select extract(year from pt.title_date)::int season,
               count(distinct public.cb_record_event_key(pt.tournament_name)) c
        from public.player_titles pt
        where pt.player_id=v_pid and pt.event_type='singles' and pt.title_date<=p_date
          and public.cb_record_event_key(pt.tournament_name) in ('shanghai','paris')
        group by extract(year from pt.title_date)::int
      ) s where c=2
    ) into v_fall;

    select exists(
      select 1 from (
        select extract(year from pt.title_date)::int season,
               count(distinct public.cb_record_event_key(pt.tournament_name)) c
        from public.player_titles pt
        where pt.player_id=v_pid and pt.event_type='singles' and pt.title_date<=p_date
          and public.cb_record_event_key(pt.tournament_name) in ('australian_open','roland_garros','wimbledon','us_open')
        group by extract(year from pt.title_date)::int
      ) s where c=4
    ) into v_calendar_slam;

    select exists(
      select 1 from (
        select extract(year from pt.title_date)::int season,
               count(distinct public.cb_record_event_key(pt.tournament_name)) c
        from public.player_titles pt
        where pt.player_id=v_pid and pt.event_type='singles' and pt.title_date<=p_date
          and public.cb_record_event_key(pt.tournament_name) in ('australian_open','roland_garros','wimbledon','us_open','olympics')
        group by extract(year from pt.title_date)::int
      ) s where c=5
    ) into v_calendar_golden;

    select coalesce(pcs.aces,0) into v_career_aces
    from public.player_career_stats pcs where pcs.player_id=v_pid;
    v_career_aces := coalesce(v_career_aces,0) + coalesce((
      select sum(coalesce((mh.match_data->>'aces')::numeric,0))::bigint
      from public.match_history mh
      where mh.user_involved=true and mh.match_date>date '2025-12-01' and mh.match_date<=p_date
        and mh.match_data ? 'aces'
    ),0);

    select coalesce(max((mh.match_data->>'aces')::numeric),0)::int into v_masters_match_aces
    from public.match_history mh
    where mh.user_involved=true and mh.match_date<=p_date
      and coalesce(mh.match_data->>'category','') ilike '%Masters 1000%'
      and mh.match_data ? 'aces';

    select coalesce(max(total_aces),0)::int into v_masters_edition_aces
    from (
      select extract(year from mh.match_date)::int season,mh.tournament_name,
             sum(coalesce((mh.match_data->>'aces')::numeric,0)) total_aces
      from public.match_history mh
      where mh.user_involved=true and mh.match_date<=p_date
        and coalesce(mh.match_data->>'category','') ilike '%Masters 1000%'
        and mh.match_data ? 'aces'
      group by extract(year from mh.match_date)::int,mh.tournament_name
    ) z;

    v_progress := jsonb_build_array(
      jsonb_build_object('code','masters_titles_career','value',v_masters_titles,'target',40,'achieved',v_masters_titles>40,'label',v_masters_titles||' titres'),
      jsonb_build_object('code','masters_titles_season','value',v_masters_season,'target',6,'achieved',v_masters_season>6,'label','meilleure saison: '||v_masters_season),
      jsonb_build_object('code','career_golden_masters','value',v_masters_unique,'target',9,'achieved',v_masters_unique=9,'label',v_masters_unique||'/9 Masters'),
      jsonb_build_object('code','double_career_golden_masters','value',v_double_golden_events,'target',9,'achieved',v_double_golden_events=9,'label',v_double_golden_events||'/9 gagnés au moins 2 fois'),
      jsonb_build_object('code','sunshine_double','value',case when v_sunshine then 2 else 0 end,'target',2,'achieved',v_sunshine,'label',case when v_sunshine then 'Réalisé' else 'À réaliser' end),
      jsonb_build_object('code','clay_masters_sweep','value',case when v_clay then 3 else 0 end,'target',3,'achieved',v_clay,'label',case when v_clay then 'Réalisé' else 'À réaliser' end),
      jsonb_build_object('code','summer_masters_sweep','value',case when v_summer then 2 else 0 end,'target',2,'achieved',v_summer,'label',case when v_summer then 'Réalisé' else 'À réaliser' end),
      jsonb_build_object('code','fall_masters_sweep','value',case when v_fall then 2 else 0 end,'target',2,'achieved',v_fall,'label',case when v_fall then 'Réalisé' else 'À réaliser' end),
      jsonb_build_object('code','career_golden_slam','value',v_slam_unique+(case when v_has_olympic then 1 else 0 end),'target',5,'achieved',v_slam_unique=4 and v_has_olympic,'label',v_slam_unique||'/4 Majeurs'||case when v_has_olympic then ' + or olympique' else '' end),
      jsonb_build_object('code','calendar_grand_slam_men','value',case when v_calendar_slam then 4 else 0 end,'target',4,'achieved',v_calendar_slam,'label',case when v_calendar_slam then 'Réalisé' else 'À réaliser' end),
      jsonb_build_object('code','calendar_golden_slam_men','value',case when v_calendar_golden then 5 else 0 end,'target',5,'achieved',v_calendar_golden,'label',case when v_calendar_golden then 'HISTORIQUE' else 'Jamais réalisé chez les hommes' end),
      jsonb_build_object('code','career_aces_reference','value',v_career_aces,'target',14411,'achieved',v_career_aces>14411,'label',v_career_aces||' aces'),
      jsonb_build_object('code','masters_aces_edition_save','value',v_masters_edition_aces,'target',null,'achieved',v_masters_edition_aces>0,'label',v_masters_edition_aces||' aces'),
      jsonb_build_object('code','masters_aces_match_save','value',v_masters_match_aces,'target',null,'achieved',v_masters_match_aces>0,'label',v_masters_match_aces||' aces')
    );
  end if;

  select coalesce(jsonb_agg(to_jsonb(c) order by c.display_order,c.code),'[]'::jsonb)
    into v_catalog from public.record_catalog c;

  select coalesce(jsonb_agg(to_jsonb(o) order by o.record_code,o.season,o.id),'[]'::jsonb)
    into v_occurrences from public.record_occurrences o;

  return jsonb_build_object(
    'as_of_date',date '2025-12-01',
    'catalog',v_catalog,
    'occurrences',v_occurrences,
    'managed',jsonb_build_object('player_id',v_pid,'name',v_name,'country',v_country,'progress',v_progress)
  );
end;
$function$


revoke all on function public.court_boss_record_hub(bigint,date) from public;
grant execute on function public.court_boss_record_hub(bigint,date) to service_role;
