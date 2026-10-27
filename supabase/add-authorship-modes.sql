alter table public.blingbooks_works
  add column if not exists authorship_mode text not null default 'automatic';

alter table public.blingbooks_works
  drop constraint if exists blingbooks_works_authorship_mode_check;
alter table public.blingbooks_works
  add constraint blingbooks_works_authorship_mode_check
  check (authorship_mode in ('automatic', 'approval', 'closed'));

update public.blingbooks_works
set authorship_mode = 'automatic'
where authorship_mode is null or authorship_mode not in ('automatic', 'approval', 'closed');

grant select, update on table public.blingbooks_works to authenticated;

drop policy if exists "owners update their works" on public.blingbooks_works;
create policy "owners update their works"
on public.blingbooks_works for update
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

drop function if exists public.blingbooks_list_authors(text);
create function public.blingbooks_list_authors(work_slug text)
returns table(display_name text, authorship_mode text)
language sql stable security definer set search_path=public as $$
  select a.display_name, w.authorship_mode
  from blingbooks_works w
  left join blingbooks_authors a on a.work_id=w.id and a.status='approved'
  where w.slug=work_slug
  order by a.created_at nulls last;
$$;

drop function if exists public.blingbooks_request_authorship(text,text);
create function public.blingbooks_request_authorship(work_slug text, author_name text)
returns text language plpgsql security definer set search_path=public as $$
declare target uuid; cleaned text := trim(author_name); mode text; resulting_status text;
begin
  if char_length(cleaned) not between 1 and 80 then raise exception 'Invalid author name'; end if;
  select id, authorship_mode into target, mode from blingbooks_works where slug=work_slug;
  if target is null then raise exception 'Unknown work'; end if;
  if mode='closed' then raise exception 'Authorship is closed for this work'; end if;
  resulting_status := case when mode='automatic' then 'approved' else 'pending' end;
  if exists(select 1 from blingbooks_authors where work_id=target and lower(display_name)=lower(cleaned) and status='approved') then return 'approved'; end if;
  if exists(select 1 from blingbooks_authors where work_id=target and lower(display_name)=lower(cleaned) and status='pending') then
    if resulting_status='approved' then update blingbooks_authors set status='approved' where work_id=target and lower(display_name)=lower(cleaned) and status='pending'; end if;
    return resulting_status;
  end if;
  insert into blingbooks_authors(work_id,display_name,status) values(target,cleaned,resulting_status);
  return resulting_status;
end $$;

revoke all on function public.blingbooks_request_authorship(text,text) from public;
grant execute on function public.blingbooks_list_authors(text) to anon,authenticated;
grant execute on function public.blingbooks_request_authorship(text,text) to anon,authenticated;
