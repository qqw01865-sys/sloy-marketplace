-- Fix SLOY order table permissions.
-- Run this file once in Supabase Dashboard -> SQL Editor.

grant usage on schema public to authenticated;
grant select, insert, update on table public.orders to authenticated;

alter table public.orders enable row level security;

drop policy if exists "participants read orders" on public.orders;
create policy "participants read orders"
on public.orders for select to authenticated
using (
  buyer_id = auth.uid()
  or seller_id = auth.uid()
  or (auth.jwt() ->> 'email') = 'qqw01865@gmail.com'
);

drop policy if exists "buyer creates orders" on public.orders;
create policy "buyer creates orders"
on public.orders for insert to authenticated
with check (buyer_id = auth.uid());

drop policy if exists "participants update orders" on public.orders;
create policy "participants update orders"
on public.orders for update to authenticated
using (
  buyer_id = auth.uid()
  or seller_id = auth.uid()
  or (auth.jwt() ->> 'email') = 'qqw01865@gmail.com'
)
with check (
  buyer_id = auth.uid()
  or seller_id = auth.uid()
  or (auth.jwt() ->> 'email') = 'qqw01865@gmail.com'
);
