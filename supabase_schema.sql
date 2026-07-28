-- ==========================================
-- SUPABASE POSTGRESQL SCHEMA FOR FINANCEFLOW
-- ==========================================

-- Enable UUID generation extension
create extension if not exists "uuid-ossp";

-- 1. Profiles Table (Holds metadata and preferences synced from auth.users)
create table public.profiles (
  id uuid references auth.users on delete cascade primary key,
  name text not null,
  currency text default 'LKR' not null,
  theme_preference text default 'classic-blue' not null,
  simple_mode boolean default false not null,
  fcm_token text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS for profiles
alter table public.profiles enable row level security;

-- Policies for Profiles
create policy "Users can read own profile" 
  on public.profiles for select 
  using (auth.uid() = id);

create policy "Users can update own profile" 
  on public.profiles for update 
  using (auth.uid() = id);

-- Trigger: Automatically create a public profile entry when a new user signs up
create function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, name, currency, theme_preference, simple_mode)
  values (
    new.id, 
    coalesce(new.raw_user_meta_data->>'name', 'New Member'), 
    'LKR', 
    'classic-blue', 
    false
  );
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();


-- 2. Categories Table (Categories for transactions)
create table public.categories (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  name text not null,
  icon text not null,
  color text not null,
  type text check (type in ('income', 'expense')) not null,
  budget_limit numeric(12,2) default 0.00,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique (user_id, name)
);

-- Enable RLS for categories
alter table public.categories enable row level security;

-- Policies for Categories (Users can manage only their own categories)
create policy "Users can view own categories" 
  on public.categories for select 
  using (auth.uid() = user_id);

create policy "Users can insert own categories" 
  on public.categories for insert 
  with check (auth.uid() = user_id);

create policy "Users can update own categories" 
  on public.categories for update 
  using (auth.uid() = user_id);

create policy "Users can delete own categories" 
  on public.categories for delete 
  using (auth.uid() = user_id);


-- 3. Transactions Table (Optimized structure - no files/images for security)
create table public.transactions (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  type text check (type in ('income', 'expense')) not null,
  amount numeric(12,2) not null check (amount > 0),
  category text not null,
  payment_method text not null,
  date date not null,
  notes text,
  tags text[],
  location text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS for transactions
alter table public.transactions enable row level security;

-- Policies for Transactions (Ensures complete data isolation)
create policy "Users can view own transactions" 
  on public.transactions for select 
  using (auth.uid() = user_id);

create policy "Users can insert own transactions" 
  on public.transactions for insert 
  with check (auth.uid() = user_id);

create policy "Users can update own transactions" 
  on public.transactions for update 
  using (auth.uid() = user_id);

create policy "Users can delete own transactions" 
  on public.transactions for delete 
  using (auth.uid() = user_id);


-- 4. Budgets Table
create table public.budgets (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  category text not null,
  limit_amount numeric(12,2) not null check (limit_amount > 0),
  period text default 'monthly' check (period in ('weekly', 'monthly', 'yearly')) not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique (user_id, category, period)
);

-- Enable RLS for budgets
alter table public.budgets enable row level security;

-- Policies for Budgets
create policy "Users can view own budgets" 
  on public.budgets for select 
  using (auth.uid() = user_id);

create policy "Users can manage own budgets" 
  on public.budgets for all 
  using (auth.uid() = user_id);


-- 5. Goals Table
create table public.goals (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  name text not null,
  target_amount numeric(12,2) not null check (target_amount > 0),
  saved_amount numeric(12,2) default 0.00 check (saved_amount >= 0) not null,
  deadline date not null,
  color text,
  icon text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS for goals
alter table public.goals enable row level security;

-- Policies for Goals
create policy "Users can view own goals" 
  on public.goals for select 
  using (auth.uid() = user_id);

create policy "Users can manage own goals" 
  on public.goals for all 
  using (auth.uid() = user_id);
