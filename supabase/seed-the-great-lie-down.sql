insert into public.blingbooks_works (slug, title, owner_id)
select 'the-great-lie-down', 'The Great Lie Down', id
from auth.users
where email = 'damourio@hotmail.com'
on conflict (slug) do update
set title = excluded.title,
    owner_id = excluded.owner_id;

insert into public.blingbooks_authors (work_id, display_name, status)
select w.id, 'Bob', 'approved'
from public.blingbooks_works w
where w.slug = 'the-great-lie-down'
  and not exists (
    select 1
    from public.blingbooks_authors a
    where a.work_id = w.id
      and lower(a.display_name) = 'bob'
      and a.status = 'approved'
  );

select w.slug, w.title, u.email as owner_email,
       array_remove(array_agg(a.display_name order by a.created_at), null) as approved_authors
from public.blingbooks_works w
join auth.users u on u.id = w.owner_id
left join public.blingbooks_authors a on a.work_id = w.id and a.status = 'approved'
where w.slug = 'the-great-lie-down'
group by w.slug, w.title, u.email;
