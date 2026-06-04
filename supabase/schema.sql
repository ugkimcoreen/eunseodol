create table if not exists public.doljabi_votes (
  id uuid primary key default gen_random_uuid(),
  participant_name text not null,
  selected_option text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.photo_worldcup_photos (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  image_url text not null,
  win_count integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.photo_worldcup_sessions (
  id uuid primary key default gen_random_uuid(),
  winner_photo_id uuid references public.photo_worldcup_photos(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.rolling_paper_notes (
  id uuid primary key default gen_random_uuid(),
  author_name text not null,
  message text not null,
  x numeric not null,
  y numeric not null,
  color text not null default '#fff4b8',
  rotation numeric not null default 0,
  created_at timestamptz not null default now()
);

create or replace function public.increment_photo_win(photo_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.photo_worldcup_photos
  set win_count = win_count + 1
  where id = photo_id;
$$;

alter table public.doljabi_votes enable row level security;
alter table public.photo_worldcup_photos enable row level security;
alter table public.photo_worldcup_sessions enable row level security;
alter table public.rolling_paper_notes enable row level security;

create policy "Anyone can submit doljabi votes"
on public.doljabi_votes for insert
to anon
with check (true);

create policy "Anyone can read doljabi votes"
on public.doljabi_votes for select
to anon
using (true);

create policy "Anyone can read active photos"
on public.photo_worldcup_photos for select
to anon
using (is_active = true);

create policy "Anyone can create worldcup sessions"
on public.photo_worldcup_sessions for insert
to anon
with check (true);

create policy "Anyone can read worldcup sessions"
on public.photo_worldcup_sessions for select
to anon
using (true);

create policy "Anyone can read rolling paper"
on public.rolling_paper_notes for select
to anon
using (true);

create policy "Anyone can add rolling paper notes"
on public.rolling_paper_notes for insert
to anon
with check (true);

grant execute on function public.increment_photo_win(uuid) to anon;

do $$
begin
  alter publication supabase_realtime add table public.rolling_paper_notes;
exception
  when duplicate_object then null;
end $$;
