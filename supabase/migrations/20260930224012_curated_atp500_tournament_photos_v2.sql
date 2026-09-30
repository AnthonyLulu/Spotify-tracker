-- Curated high-quality ATP 500 tournament images replacing generic city fallbacks.

update public.tournaments
set
  image_url=case id
    when 2944 then 'https://www.dallasopen.com/-/media/sites/tournaments/dallas/hero/2027do-website-clocktemplate-rado5.jpg'
    when 2104 then 'https://www.atptour.com/-/media/images/news/2022/09/09/09/55/acapulco-tournament-page-2022.jpg'
    when 2062 then 'https://www.atptour.com/-/media/images/news/2025/04/15/11/36/munich-tournament-page-photo-2025.jpg'
    when 2041 then 'https://www.atptour.com/-/media/images/news/2025/06/18/00/52/queens-club-2025-stadium.jpg'
    when 2070 then 'https://www.atptour.com/-/media/images/atp-tournaments/tournament-images/tokyo_tournimage_2023.jpg'
    else image_url
  end,
  image_source_url=case id
    when 2944 then 'https://www.dallasopen.com/en'
    when 2104 then 'https://www.atptour.com/en/tournaments/acapulco/807/overview'
    when 2062 then 'https://www.atptour.com/en/tournaments/bmw-open-by-bitpanda/308/overview'
    when 2041 then 'https://www.atptour.com/en/tournaments/london/311/overview'
    when 2070 then 'https://www.atptour.com/en/tournaments/kinoshita-group-japan-open-tennis-championships/329/overview'
    else image_source_url
  end,
  image_source_label=case id
    when 2944 then 'Photo officielle Nexo Dallas Open'
    when 2104 then 'Photo tournoi officielle · ATP Tour'
    when 2062 then 'Photo tournoi officielle · ATP Tour'
    when 2041 then 'Photo tournoi officielle · ATP Tour'
    when 2070 then 'Photo tournoi officielle · ATP Tour'
    else image_source_label
  end
where id in (2944,2104,2062,2041,2070);
