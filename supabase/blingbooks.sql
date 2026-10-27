-- BlingBooks MVP. Safe to use in the existing Supabase project: all objects
-- use the blingbooks_ prefix and have their own row-level security rules.
create extension if not exists pgcrypto;

create table if not exists public.blingbooks_works (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null check (slug ~ '^[a-z0-9-]+$'),
  title text not null,
  owner_id uuid not null references auth.users(id) on delete cascade,
  authorship_mode text not null default 'automatic' check (authorship_mode in ('automatic','approval','closed')),
  created_at timestamptz not null default now()
);
create table if not exists public.blingbooks_authors (
  id uuid primary key default gen_random_uuid(),
  work_id uuid not null references public.blingbooks_works(id) on delete cascade,
  display_name text not null check (char_length(trim(display_name)) between 1 and 80),
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at timestamptz not null default now()
);
create unique index if not exists blingbooks_approved_name_unique
  on public.blingbooks_authors(work_id, lower(display_name)) where status = 'approved';
create table if not exists public.blingbooks_editions (
  id uuid primary key default gen_random_uuid(),
  work_id uuid not null references public.blingbooks_works(id) on delete cascade,
  share_slug text unique not null default encode(gen_random_bytes(9), 'hex'),
  edition_author text not null check (char_length(trim(edition_author)) between 1 and 80),
  character_name text not null check (char_length(character_name) between 1 and 60),
  dedication text not null default '' check (char_length(dedication) <= 500),
  created_at timestamptz not null default now()
);

alter table public.blingbooks_works enable row level security;
alter table public.blingbooks_authors enable row level security;
alter table public.blingbooks_editions enable row level security;
grant select, update on table public.blingbooks_works to authenticated;
grant select, update, delete on table public.blingbooks_authors to authenticated;
grant select on table public.blingbooks_editions to authenticated;
create policy "owners read their works" on public.blingbooks_works for select using (owner_id = auth.uid());
create policy "owners update their works" on public.blingbooks_works for update using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy "owners manage authors" on public.blingbooks_authors for all using (exists(select 1 from public.blingbooks_works w where w.id=work_id and w.owner_id=auth.uid())) with check (exists(select 1 from public.blingbooks_works w where w.id=work_id and w.owner_id=auth.uid()));
create policy "owners read editions" on public.blingbooks_editions for select using (exists(select 1 from public.blingbooks_works w where w.id=work_id and w.owner_id=auth.uid()));

create or replace function public.blingbooks_list_authors(work_slug text)
returns table(display_name text, authorship_mode text) language sql stable security definer set search_path=public as $$
  select a.display_name,w.authorship_mode from blingbooks_works w left join blingbooks_authors a on a.work_id=w.id and a.status='approved'
  where w.slug=work_slug order by a.created_at nulls last;
$$;
create or replace function public.blingbooks_request_authorship(work_slug text, author_name text)
returns text language plpgsql security definer set search_path=public as $$
declare target uuid; cleaned text := trim(author_name); mode text; resulting_status text;
begin
  if char_length(cleaned) not between 1 and 80 then raise exception 'Invalid author name'; end if;
  select id,authorship_mode into target,mode from blingbooks_works where slug=work_slug;
  if target is null then raise exception 'Unknown work'; end if;
  if mode='closed' then raise exception 'Authorship is closed for this work'; end if;
  resulting_status:=case when mode='automatic' then 'approved' else 'pending' end;
  if exists(select 1 from blingbooks_authors where work_id=target and lower(display_name)=lower(cleaned) and status='approved') then return 'approved'; end if;
  if exists(select 1 from blingbooks_authors where work_id=target and lower(display_name)=lower(cleaned) and status='pending') then
    if resulting_status='approved' then update blingbooks_authors set status='approved' where work_id=target and lower(display_name)=lower(cleaned) and status='pending'; end if;
    return resulting_status;
  end if;
  insert into blingbooks_authors(work_id,display_name,status) values(target,cleaned,resulting_status);
  return resulting_status;
end $$;
create or replace function public.blingbooks_create_edition(work_slug text, edition_author text, edition_character text, edition_dedication text)
returns table(share_slug text) language plpgsql security definer set search_path=public as $$
declare target uuid; created_slug text;
begin
  select id into target from blingbooks_works where slug=work_slug;
  if target is null then raise exception 'Unknown work'; end if;
  if char_length(trim(edition_author)) not between 1 and 80 or char_length(trim(edition_character)) not between 1 and 60 or char_length(edition_dedication)>500 then raise exception 'Invalid edition'; end if;
  insert into blingbooks_editions(work_id,edition_author,character_name,dedication) values(target,trim(edition_author),trim(edition_character),edition_dedication) returning blingbooks_editions.share_slug into created_slug;
  return query select created_slug;
end $$;
create or replace function public.blingbooks_get_edition(edition_slug text)
returns table(authors text[],character_name text,dedication text) language sql stable security definer set search_path=public as $$
  select array_append(coalesce((select array_agg(a.display_name order by a.created_at) from blingbooks_authors a where a.work_id=e.work_id and a.status='approved'),'{}'),e.edition_author),e.character_name,e.dedication from blingbooks_editions e where e.share_slug=edition_slug;
$$;
revoke all on function public.blingbooks_request_authorship(text,text) from public;
revoke all on function public.blingbooks_create_edition(text,text,text,text) from public;
grant execute on function public.blingbooks_list_authors(text) to anon,authenticated;
grant execute on function public.blingbooks_request_authorship(text,text) to anon,authenticated;
grant execute on function public.blingbooks_create_edition(text,text,text,text) to anon,authenticated;
grant execute on function public.blingbooks_get_edition(text) to anon,authenticated;

-- Seed The Great Lie Down under its existing Supabase owner:
-- insert into public.blingbooks_works(slug,title,owner_id)
-- select 'the-great-lie-down','The Great Lie Down',id from auth.users where email='damourio@hotmail.com'
-- on conflict(slug) do update set title=excluded.title, owner_id=excluded.owner_id;
-- Seed the original author after the work row exists:
-- insert into public.blingbooks_authors(work_id,display_name,status)
-- select w.id,'Bob','approved' from public.blingbooks_works w
-- where w.slug='the-great-lie-down' and not exists (
--   select 1 from public.blingbooks_authors a
--   where a.work_id=w.id and lower(a.display_name)='bob' and a.status='approved'
-- );

