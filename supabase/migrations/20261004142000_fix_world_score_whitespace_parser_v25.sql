create or replace function public.world_invert_tennis_score(p_score text)
returns text
language plpgsql
immutable
set search_path to 'public'
as $function$
declare
  token text;
  inner_token text;
  main_token text;
  m text[];
  main_m text[];
  inner_m text[];
  out_score text := '';
  normalized_score text;
begin
  if p_score is null or btrim(p_score) = '' then
    return p_score;
  end if;

  normalized_score := regexp_replace(btrim(p_score), '[[:space:]]+', ' ', 'g');

  foreach token in array string_to_array(normalized_score, ' ') loop
    if out_score <> '' then
      out_score := out_score || ' ';
    end if;

    m := regexp_match(token, '^([0-9]+)-([0-9]+)$');
    if m is not null then
      out_score := out_score || m[2] || '-' || m[1];
      continue;
    end if;

    if char_length(token) >= 5 and left(token,1) = '(' and right(token,1) = ')' then
      inner_token := substring(token from 2 for char_length(token)-2);
      m := regexp_match(inner_token, '^([0-9]+)-([0-9]+)$');
      if m is not null then
        out_score := out_score || '(' || m[2] || '-' || m[1] || ')';
        continue;
      end if;
    end if;

    if char_length(token) >= 5 and left(token,1) = '[' and right(token,1) = ']' then
      inner_token := substring(token from 2 for char_length(token)-2);
      m := regexp_match(inner_token, '^([0-9]+)-([0-9]+)$');
      if m is not null then
        out_score := out_score || '[' || m[2] || '-' || m[1] || ']';
        continue;
      end if;
    end if;

    if position('(' in token) > 1 and right(token,1) = ')' then
      main_token := split_part(token,'(',1);
      inner_token := substring(token from position('(' in token)+1 for char_length(token)-position('(' in token)-1);
      main_m := regexp_match(main_token, '^([0-9]+)-([0-9]+)$');
      inner_m := regexp_match(inner_token, '^([0-9]+)-([0-9]+)$');
      if main_m is not null and inner_m is not null then
        out_score := out_score
          || main_m[2] || '-' || main_m[1]
          || '(' || inner_m[2] || '-' || inner_m[1] || ')';
        continue;
      end if;
    end if;

    out_score := out_score || token;
  end loop;

  return out_score;
end;
$function$;
