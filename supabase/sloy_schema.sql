-- SLOY Marketplace: cloud database and private model storage
-- Run once in Supabase SQL Editor. Safe to re-run.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  category text not null default 'Другое',
  description text not null default '',
  price numeric(12,2) not null default 0 check (price >= 0),
  format text not null default 'GLB',
  file_path text,
  file_name text,
  color_options text,
  dimensions text,
  material text,
  extra_specs text,
  status text not null default 'pending' check (status in ('pending','published','rejected','archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  buyer_id uuid not null references auth.users(id) on delete restrict,
  seller_id uuid references auth.users(id) on delete set null,
  items jsonb not null default '[]'::jsonb,
  total numeric(12,2) not null default 0 check (total >= 0),
  status text not null default 'new',
  cancellation_reason text,
  delivery jsonb not null default '{}'::jsonb,
  buyer_name text,
  buyer_phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  order_id uuid references public.orders(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 5000),
  created_at timestamptz not null default now(),
  read_at timestamptz
);

create table if not exists public.print_requests (
  id uuid primary key default gen_random_uuid(),
  buyer_id uuid not null references auth.users(id) on delete cascade,
  file_name text,
  file_path text,
  source_url text,
  description text not null default '',
  color text,
  quantity integer not null default 1 check (quantity > 0),
  status text not null default 'new',
  quoted_price numeric(12,2),
  estimated_time text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.favorites (
  user_id uuid not null references auth.users(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, product_id)
);

create index if not exists products_status_created_idx on public.products(status, created_at desc);
create index if not exists products_seller_idx on public.products(seller_id);
create index if not exists orders_buyer_created_idx on public.orders(buyer_id, created_at desc);
create index if not exists orders_seller_created_idx on public.orders(seller_id, created_at desc);
create index if not exists messages_order_created_idx on public.messages(order_id, created_at);
create index if not exists print_requests_buyer_idx on public.print_requests(buyer_id, created_at desc);

alter table public.profiles enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;
alter table public.messages enable row level security;
alter table public.print_requests enable row level security;
alter table public.favorites enable row level security;

-- Profile: each user can see and edit only their own profile.
drop policy if exists "profile read own" on public.profiles;
create policy "profile read own" on public.profiles for select to authenticated using (id = auth.uid());
drop policy if exists "profile insert own" on public.profiles;
create policy "profile insert own" on public.profiles for insert to authenticated with check (id = auth.uid());
drop policy if exists "profile update own" on public.profiles;
create policy "profile update own" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- Products: published products are public; sellers manage their own products.
drop policy if exists "published products are public" on public.products;
create policy "published products are public" on public.products for select using (status = 'published' or seller_id = auth.uid() or (auth.jwt() ->> 'email') = 'qqw01865@gmail.com');
drop policy if exists "seller creates products" on public.products;
create policy "seller creates products" on public.products for insert to authenticated with check (seller_id = auth.uid());
drop policy if exists "seller or owner updates products" on public.products;
create policy "seller or owner updates products" on public.products for update to authenticated using (seller_id = auth.uid() or (auth.jwt() ->> 'email') = 'qqw01865@gmail.com') with check (seller_id = auth.uid() or (auth.jwt() ->> 'email') = 'qqw01865@gmail.com');
drop policy if exists "seller or owner deletes products" on public.products;
create policy "seller or owner deletes products" on public.products for delete to authenticated using (seller_id = auth.uid() or (auth.jwt() ->> 'email') = 'qqw01865@gmail.com');

-- Orders: only buyer, assigned seller, and marketplace owner can access.
drop policy if exists "participants read orders" on public.orders;
create policy "participants read orders" on public.orders for select to authenticated using (buyer_id = auth.uid() or seller_id = auth.uid() or (auth.jwt() ->> 'email') = 'qqw01865@gmail.com');
drop policy if exists "buyer creates orders" on public.orders;
create policy "buyer creates orders" on public.orders for insert to authenticated with check (buyer_id = auth.uid());
drop policy if exists "participants update orders" on public.orders;
create policy "participants update orders" on public.orders for update to authenticated using (buyer_id = auth.uid() or seller_id = auth.uid() or (auth.jwt() ->> 'email') = 'qqw01865@gmail.com') with check (buyer_id = auth.uid() or seller_id = auth.uid() or (auth.jwt() ->> 'email') = 'qqw01865@gmail.com');

-- Messages: only order participants can read/send messages.
drop policy if exists "participants read messages" on public.messages;
create policy "participants read messages" on public.messages for select to authenticated using (
  sender_id = auth.uid() or exists (
    select 1 from public.orders o where o.id = order_id
    and (o.buyer_id = auth.uid() or o.seller_id = auth.uid() or (auth.jwt() ->> 'email') = 'qqw01865@gmail.com')
  )
);
drop policy if exists "participants send messages" on public.messages;
create policy "participants send messages" on public.messages for insert to authenticated with check (
  sender_id = auth.uid() and exists (
    select 1 from public.orders o where o.id = order_id
    and (o.buyer_id = auth.uid() or o.seller_id = auth.uid() or (auth.jwt() ->> 'email') = 'qqw01865@gmail.com')
  )
);

-- Print requests: customer owns their requests; marketplace owner handles quotations/status.
drop policy if exists "customer or owner reads print requests" on public.print_requests;
create policy "customer or owner reads print requests" on public.print_requests for select to authenticated using (buyer_id = auth.uid() or (auth.jwt() ->> 'email') = 'qqw01865@gmail.com');
drop policy if exists "customer creates print requests" on public.print_requests;
create policy "customer creates print requests" on public.print_requests for insert to authenticated with check (buyer_id = auth.uid());
drop policy if exists "customer or owner updates print requests" on public.print_requests;
create policy "customer or owner updates print requests" on public.print_requests for update to authenticated using (buyer_id = auth.uid() or (auth.jwt() ->> 'email') = 'qqw01865@gmail.com') with check (buyer_id = auth.uid() or (auth.jwt() ->> 'email') = 'qqw01865@gmail.com');

-- Favorites are private to each account.
drop policy if exists "users manage own favorites" on public.favorites;
create policy "users manage own favorites" on public.favorites for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Create a private bucket for uploaded GLB and print files.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('sloy-models', 'sloy-models', false, 52428800,
  array['model/gltf-binary','application/octet-stream','application/vnd.ms-pki.stl','application/octet-stream'])
on conflict (id) do update set public = false, file_size_limit = 52428800;

drop policy if exists "users read own model files" on storage.objects;
create policy "users read own model files" on storage.objects for select to authenticated
using (bucket_id = 'sloy-models' and (owner_id = auth.uid()::text or (auth.jwt() ->> 'email') = 'qqw01865@gmail.com'));

drop policy if exists "users upload own model files" on storage.objects;
create policy "users upload own model files" on storage.objects for insert to authenticated
with check (bucket_id = 'sloy-models' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "users update own model files" on storage.objects;
create policy "users update own model files" on storage.objects for update to authenticated
using (bucket_id = 'sloy-models' and (owner_id = auth.uid()::text or (auth.jwt() ->> 'email') = 'qqw01865@gmail.com'))
with check (bucket_id = 'sloy-models' and (owner_id = auth.uid()::text or (auth.jwt() ->> 'email') = 'qqw01865@gmail.com'));

drop policy if exists "users delete own model files" on storage.objects;
create policy "users delete own model files" on storage.objects for delete to authenticated
using (bucket_id = 'sloy-models' and (owner_id = auth.uid()::text or (auth.jwt() ->> 'email') = 'qqw01865@gmail.com'));

-- Automatically create a profile row when a new account is registered.
create or replace function public.handle_new_sloy_user()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, phone)
  values (new.id, new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'phone')
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_sloy_user_created on auth.users;
create trigger on_sloy_user_created
after insert on auth.users
for each row execute procedure public.handle_new_sloy_user();
