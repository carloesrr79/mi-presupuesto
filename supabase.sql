-- Mi Presupuesto: tabla de sincronización (los datos llegan ya cifrados desde el dispositivo)
create table if not exists public.items (
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  store   text not null,
  id      text not null,
  data    text,
  deleted boolean not null default false,
  upd     bigint not null,
  seq     bigint not null default 0,
  primary key (user_id, store, id)
);
create index if not exists items_user_seq on public.items (user_id, seq);

create sequence if not exists public.items_seq;
create or replace function public.items_bump() returns trigger
language plpgsql security definer set search_path = public as $$
begin new.seq := nextval('public.items_seq'); return new; end $$;
drop trigger if exists items_bump on public.items;
create trigger items_bump before insert or update on public.items
  for each row execute function public.items_bump();

-- Cada usuario solo puede ver y tocar sus propias filas
alter table public.items enable row level security;
drop policy if exists items_own on public.items;
create policy items_own on public.items for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- Subida: gana el cambio más reciente
create or replace function public.push_items(p jsonb) returns void
language sql security invoker set search_path = public as $$
  insert into public.items as t (user_id, store, id, data, deleted, upd)
  select auth.uid(), x->>'store', x->>'id', x->>'data', coalesce((x->>'deleted')::boolean, false), (x->>'upd')::bigint
  from jsonb_array_elements(p) x
  on conflict (user_id, store, id) do update
    set data = excluded.data, deleted = excluded.deleted, upd = excluded.upd
    where t.upd <= excluded.upd;
$$;

revoke all on public.items from anon;
grant select, insert, update, delete on public.items to authenticated;
revoke execute on function public.push_items(jsonb) from public, anon;
grant execute on function public.push_items(jsonb) to authenticated;
revoke execute on function public.items_bump() from public, anon, authenticated;
