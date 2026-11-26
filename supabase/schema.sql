-- MarinadeMaster Supabase schema
-- Run this in Supabase SQL Editor after creating a project.
-- All user-owned rows are isolated with Row Level Security.

create extension if not exists pgcrypto;

create table if not exists public.recipes (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  local_id text not null,
  name text not null,
  version text not null,
  base_kg numeric(12,4) not null check (base_kg > 0),
  groups jsonb not null default '[]'::jsonb,
  note text not null default '',
  based_on_local_id text,
  created_at timestamptz not null default now(),
  unique(owner_id, local_id)
);

create table if not exists public.ingredients (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  stock_unit text not null check (stock_unit in ('g','kg')),
  quantity numeric(16,6) not null default 0 check (quantity >= 0),
  average_unit_cost numeric(16,6) not null default 0 check (average_unit_cost >= 0),
  updated_at timestamptz not null default now(),
  unique(owner_id, name)
);

create table if not exists public.purchases (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  local_id text not null,
  purchase_date date not null,
  ingredient_name text not null,
  unit text not null check (unit in ('g','kg')),
  quantity numeric(16,6) not null check (quantity > 0),
  unit_price numeric(16,6) not null check (unit_price > 0),
  returned_quantity numeric(16,6) not null default 0 check (returned_quantity >= 0 and returned_quantity <= quantity),
  supplier text not null default '',
  invoice text not null default '',
  note text not null default '',
  created_at timestamptz not null default now(),
  unique(owner_id, local_id)
);

create table if not exists public.batches (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  local_id text not null,
  code text not null,
  recipe_local_id text not null,
  recipe_snapshot jsonb not null,
  chicken_kg numeric(12,4) not null check (chicken_kg > 0),
  status text not null default '準備中',
  process jsonb not null default '{}'::jsonb,
  cost_snapshot jsonb,
  cost_total numeric(16,4),
  cost_complete boolean not null default false,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  stock_deducted_at timestamptz,
  unique(owner_id, local_id),
  unique(owner_id, code)
);

create table if not exists public.inventory_ledger (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  local_id text not null,
  event_type text not null,
  reference_code text not null default '',
  ingredient_name text not null,
  quantity_delta numeric(16,6) not null,
  balance_after numeric(16,6) not null check (balance_after >= 0),
  unit text not null check (unit in ('g','kg')),
  unit_price numeric(16,6),
  created_at timestamptz not null default now(),
  unique(owner_id, local_id)
);

create table if not exists public.batch_photos (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  local_id text not null,
  batch_local_id text not null,
  object_path text not null,
  caption text not null default '',
  captured_at timestamptz not null default now(),
  unique(owner_id, local_id)
);

create table if not exists public.workspace_snapshots (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  revision bigint not null default 0,
  payload jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.recipes enable row level security;
alter table public.ingredients enable row level security;
alter table public.purchases enable row level security;
alter table public.batches enable row level security;
alter table public.inventory_ledger enable row level security;
alter table public.batch_photos enable row level security;
alter table public.workspace_snapshots enable row level security;

do $$
declare t text;
begin
  foreach t in array array['recipes','ingredients','purchases','batches','inventory_ledger','batch_photos','workspace_snapshots']
  loop
    execute format('drop policy if exists owner_access on public.%I', t);
    execute format('create policy owner_access on public.%I for all using (owner_id = auth.uid()) with check (owner_id = auth.uid())', t);
  end loop;
end $$;

create index if not exists recipes_owner_name_idx on public.recipes(owner_id, name);
create index if not exists batches_owner_created_idx on public.batches(owner_id, created_at desc);
create index if not exists purchases_owner_date_idx on public.purchases(owner_id, purchase_date desc);
create index if not exists ledger_owner_created_idx on public.inventory_ledger(owner_id, created_at desc);
create index if not exists photos_owner_batch_idx on public.batch_photos(owner_id, batch_local_id);

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('marinade-batch-photos','marinade-batch-photos',false,10485760,array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

drop policy if exists marinade_photo_owner_access on storage.objects;
create policy marinade_photo_owner_access on storage.objects
for all to authenticated
using (bucket_id = 'marinade-batch-photos' and (storage.foldername(name))[1] = auth.uid()::text)
with check (bucket_id = 'marinade-batch-photos' and (storage.foldername(name))[1] = auth.uid()::text);

create or replace function public.save_workspace_snapshot(p_payload jsonb, p_expected_revision bigint)
returns table(new_revision bigint, saved_at timestamptz)
language plpgsql
security definer
set search_path = public
as $$
declare current_revision bigint;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  select revision into current_revision
    from public.workspace_snapshots
    where owner_id = auth.uid()
    for update;

  if not found then
    if p_expected_revision <> 0 then raise exception 'revision_conflict'; end if;
    insert into public.workspace_snapshots(owner_id, revision, payload)
      values(auth.uid(), 1, p_payload);
    return query select 1::bigint, now();
    return;
  end if;

  if current_revision <> p_expected_revision then raise exception 'revision_conflict'; end if;

  update public.workspace_snapshots
    set payload = p_payload, revision = current_revision + 1, updated_at = now()
    where owner_id = auth.uid();

  return query select current_revision + 1, now();
end;
$$;

revoke all on function public.save_workspace_snapshot(jsonb,bigint) from public;
grant execute on function public.save_workspace_snapshot(jsonb,bigint) to authenticated;
