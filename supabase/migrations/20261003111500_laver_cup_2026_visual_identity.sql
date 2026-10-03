update public.tournaments
set
  venue = 'The O2',
  image_url = 'https://commons.wikimedia.org/wiki/Special:Redirect/file/Laver_Cup_2026_O2_Arena.jpg',
  image_source_url = 'https://commons.wikimedia.org/wiki/File:Laver_Cup_2026_O2_Arena.jpg',
  image_source_label = 'Daniel Cooper · CC BY-SA 4.0 · Wikimedia Commons'
where id = 2040
  and category = 'Laver Cup';
