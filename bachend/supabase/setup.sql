-- Spilver Café: the menu database (Supabase / Postgres)
--
-- Run once from the Supabase dashboard: SQL Editor > New query > paste this whole file > Run.
-- Safe to run again: it only creates what is missing and never duplicates the menu.
--
-- Who can do what (row level security):
--   * everyone (the public website) reads the visible menu items, nothing else
--   * an admin (a signed-in account listed in public.admins) reads, adds, edits, hides and deletes items
-- The site only ever holds the public anon/publishable key; these policies are what protect the data.


-- 1. Admin accounts ------------------------------------------------------------

create table if not exists public.admins (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

-- true when the signed-in account is an admin (security definer so policies can ask without
-- exposing the admins table itself)
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.admins where user_id = auth.uid());
$$;


-- 2. The menu -------------------------------------------------------------------

create table if not exists public.menu_items (
  id         uuid primary key default gen_random_uuid(),
  slug       text unique,  -- stable key the site uses to keep the "most loved" cards in sync
  category   text not null check (category in ('iced', 'hot', 'tea', 'bakery')),
  name_ar    text not null check (char_length(btrim(name_ar)) between 1 and 60),
  name_en    text not null check (char_length(btrim(name_en)) between 1 and 60),
  price      numeric(6, 2) not null check (price >= 0 and price < 1000),
  is_visible boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists menu_items_category_order on public.menu_items (category, sort_order);

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists menu_items_touch on public.menu_items;
create trigger menu_items_touch
  before update on public.menu_items
  for each row execute function public.touch_updated_at();


-- 3. Row level security -------------------------------------------------------------

alter table public.admins     enable row level security;
alter table public.menu_items enable row level security;

drop policy if exists "admins see their own row" on public.admins;
create policy "admins see their own row" on public.admins
  for select to authenticated
  using (user_id = auth.uid());

drop policy if exists "everyone reads the visible menu" on public.menu_items;
create policy "everyone reads the visible menu" on public.menu_items
  for select to anon, authenticated
  using (is_visible or public.is_admin());

drop policy if exists "admins add items" on public.menu_items;
create policy "admins add items" on public.menu_items
  for insert to authenticated
  with check (public.is_admin());

drop policy if exists "admins edit items" on public.menu_items;
create policy "admins edit items" on public.menu_items
  for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists "admins delete items" on public.menu_items;
create policy "admins delete items" on public.menu_items
  for delete to authenticated
  using (public.is_admin());

grant usage on schema public to anon, authenticated;
grant select on public.menu_items to anon, authenticated;
grant insert, update, delete on public.menu_items to authenticated;
grant select on public.admins to authenticated;
grant execute on function public.is_admin() to anon, authenticated;


-- 4. The current menu (the 19 items from the Spilver data file) ----------------------

insert into public.menu_items (slug, category, name_ar, name_en, price, sort_order) values
  ('iced-americano',    'iced',   'أمريكانو مثلج',     'Iced Americano',    4.00, 1),
  ('iced-latte',        'iced',   'لاتيه مثلج',        'Iced Latte',        5.00, 2),
  ('iced-mocha',        'iced',   'موكا مثلج',         'Iced Mocha',        5.50, 3),
  ('caramel-macchiato', 'iced',   'كراميل ماكياتو',    'Caramel Macchiato', 5.50, 4),
  ('cold-brew',         'iced',   'قهوة باردة',        'Cold Brew',         4.50, 5),
  ('espresso',          'hot',    'إسبريسو',           'Espresso',          3.00, 1),
  ('americano',         'hot',    'أمريكانو',          'Americano',         3.50, 2),
  ('cappuccino',        'hot',    'كابتشينو',          'Cappuccino',        4.50, 3),
  ('flat-white',        'hot',    'فلات وايت',         'Flat White',        4.50, 4),
  ('mocha',             'hot',    'موكا',              'Mocha',             5.50, 5),
  ('thai-tea',          'tea',    'شاي تايلاندي',      'Thai Tea',          4.50, 1),
  ('chai-tea',          'tea',    'شاي تشاي',          'Chai Tea',          4.50, 2),
  ('matcha-latte',      'tea',    'لاتيه ماتشا',       'Matcha Latte',      5.50, 3),
  ('hot-chocolate',     'tea',    'شوكولاتة ساخنة',    'Hot Chocolate',     4.50, 4),
  ('herbal-tea',        'tea',    'شاي أعشاب',         'Herbal Tea',        3.50, 5),
  ('croissant',         'bakery', 'كرواسون',           'Croissant',         3.50, 1),
  ('blueberry-muffin',  'bakery', 'مافن التوت الأزرق', 'Blueberry Muffin',  3.00, 2),
  ('chocolate-cookies', 'bakery', 'كوكيز الشوكولاتة',  'Chocolate Cookies', 2.50, 3),
  ('avocado-toast',     'bakery', 'خبز الأفوكادو',     'Avocado Toast',     6.50, 4)
on conflict (slug) do nothing;
