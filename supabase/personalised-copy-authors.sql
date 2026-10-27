-- Personalised copies have their own visible author credit.
-- The source relationship remains recorded in blingbooks_editions.work_id.
drop function if exists public.blingbooks_get_edition(text);
create function public.blingbooks_get_edition(edition_slug text)
returns table(edition_author text, authors text[], character_name text, dedication text)
language sql stable security definer set search_path=public as $$
  select e.edition_author, array[e.edition_author]::text[], e.character_name, e.dedication
  from blingbooks_editions e
  where e.share_slug=edition_slug;
$$;

grant execute on function public.blingbooks_get_edition(text) to anon, authenticated;
