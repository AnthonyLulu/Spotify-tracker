create or replace function public.world_invert_tennis_score(p_score text)
returns text
language plpgsql
immutable
set search_path to 'public'
as $function$
declare
  token text;
  m text[];
  out_score text := '';
begin
  if p_score is null or btrim(p_score) = '' then
    return p_score;
  end if;

  foreach token in array regexp_split_to_array(btrim(p_score), '\\s+') loop
    if out_score <> '' then
      out_score := out_score || ' ';
    end if;

    m := regexp_match(token, '^(\\d+)-(\\d+)$');
    if m is not null then
      out_score := out_score || m[2] || '-' || m[1];
      continue;
    end if;

    m := regexp_match(token, '^\\((\\d+)-(\\d+)\\)$');
    if m is not null then
      out_score := out_score || '(' || m[2] || '-' || m[1] || ')';
      continue;
    end if;

    m := regexp_match(token, '^\\[(\\d+)-(\\d+)\\]$');
    if m is not null then
      out_score := out_score || '[' || m[2] || '-' || m[1] || ']';
      continue;
    end if;

    m := regexp_match(token, '^(\\d+)-(\\d+)\\((\\d+)-(\\d+)\\)$');
    if m is not null then
      out_score := out_score || m[2] || '-' || m[1] || '(' || m[4] || '-' || m[3] || ')';
      continue;
    end if;

    out_score := out_score || token;
  end loop;

  return out_score;
end;
$function$;
