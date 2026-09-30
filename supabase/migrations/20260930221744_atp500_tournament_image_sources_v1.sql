-- Curated official image source pages for the 2026 ATP 500 calendar.
-- Applied in production as migration 20260930221744.
-- The Edge image resolver extracts Open Graph / Twitter imagery from these pages,
-- then falls back to verified Wikimedia tournament/city imagery.

with src(name,url) as (
  values
    ('ABN AMRO Open','https://www.abnamro-open.nl/en/'),
    ('Nexo Dallas Open','https://www.dallasopen.com/en'),
    ('Qatar ExxonMobil Open','https://www.atptour.com/en/tournaments/doha/451/overview/'),
    ('Rio Open presented by Claro','https://www.rioopen.com/en'),
    ('Abierto Mexicano Telcel presentado por HSBC','https://abiertomexicanodetenis.com/en/'),
    ('Dubai Duty Free Tennis Championships','https://dubaidutyfreetennischampionships.com/'),
    ('Barcelona Open Banc Sabadell','https://www.barcelonaopenbancsabadell.com/en'),
    ('BMW Open by Bitpanda','https://www.bmwopen.de/en/'),
    ('Bitpanda Hamburg Open','https://hamburgopenatp500.com/en/'),
    ('HSBC Championships','https://www.atptour.com/en/tournaments/hsbc-championships/311/overview'),
    ('Terra Wortmann Open','https://www.terrawortmann-open.de/en/'),
    ('Mubadala Citi DC Open','https://www.atptour.com/en/tournaments/mubadala-citi-dc-open/418/overview'),
    ('Kinoshita Group Japan Open Tennis Championships','https://www.japanopentennis.com/atp/en/'),
    ('Erste Bank Open','https://www.erstebank-open.com/en/'),
    ('Swiss Indoors Basel','https://www.swissindoorsbasel.ch/en/')
)
update public.tournaments t
set image_source_url=src.url,
    image_source_label=case
      when nullif(trim(t.image_url),'') is null then 'Source photo officielle · à résoudre'
      else t.image_source_label
    end
from src
where t.name=src.name and t.category='ATP 500';

update public.tournaments
set image_url='https://www.abnamro-open.nl/files/images/2025/nieuwsberichten/tijdens-toernooi/Overzichtsfoto.jpg',
    image_source_url='https://www.abnamro-open.nl/en/news/headlines/52nd-edition/abn-amro-open-2025-in-facts-and-figures',
    image_source_label='Photo officielle ABN AMRO Open 2025'
where name='ABN AMRO Open'
  and category='ATP 500'
  and nullif(trim(image_url),'') is null;
