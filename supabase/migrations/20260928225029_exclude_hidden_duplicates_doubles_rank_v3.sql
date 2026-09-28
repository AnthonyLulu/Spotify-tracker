update public.players
set doubles_ranking=null,
    doubles_points=0,
    doubles_source='hidden duplicate merged · excluded from doubles ranking'
where coalesce(data_source,'') ilike 'hidden duplicate merged into %'
  and (doubles_ranking is not null or coalesce(doubles_points,0)<>0);
