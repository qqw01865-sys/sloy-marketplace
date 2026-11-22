-- SLOY: order status history
alter table public.orders
  add column if not exists status_history jsonb not null default '[]'::jsonb;

update public.orders
set status_history = jsonb_build_array(
  jsonb_build_object(
    'status', coalesce(status, 'Новый'),
    'at', created_at,
    'by', 'system'
  )
)
where status_history = '[]'::jsonb;
