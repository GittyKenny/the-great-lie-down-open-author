-- One-time fix for projects where blingbooks.sql was applied before the
-- authenticated table grants were added. RLS policies continue to restrict
-- every row to the owner of its BlingBooks work.
grant select on table public.blingbooks_works to authenticated;
grant select, update, delete on table public.blingbooks_authors to authenticated;
grant select on table public.blingbooks_editions to authenticated;
