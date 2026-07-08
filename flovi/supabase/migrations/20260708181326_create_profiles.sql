create table public.profiles (
  id uuid primary key references auth.users (id),
  role text not null check (role in ('dispatcher', 'driver')),
  full_name text,
  completed_rides_count int not null default 0,
  is_active boolean not null default true
);

alter table public.profiles enable row level security;
