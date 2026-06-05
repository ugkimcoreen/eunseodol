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

create table if not exists public.eunseo_gallery_photos (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  image_url text not null,
  storage_path text not null,
  created_at timestamptz not null default now()
);

alter table public.photo_worldcup_photos
add column if not exists gallery_photo_id uuid references public.eunseo_gallery_photos(id) on delete set null;

create unique index if not exists photo_worldcup_photos_gallery_photo_id_key
on public.photo_worldcup_photos(gallery_photo_id)
where gallery_photo_id is not null;

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
alter table public.eunseo_gallery_photos enable row level security;

drop policy if exists "Anyone can submit doljabi votes" on public.doljabi_votes;
create policy "Anyone can submit doljabi votes"
on public.doljabi_votes for insert
to anon
with check (true);

drop policy if exists "Anyone can read doljabi votes" on public.doljabi_votes;
create policy "Anyone can read doljabi votes"
on public.doljabi_votes for select
to anon
using (true);

drop policy if exists "Anyone can read active photos" on public.photo_worldcup_photos;
create policy "Anyone can read active photos"
on public.photo_worldcup_photos for select
to anon
using (true);

drop policy if exists "Anyone can add worldcup photos" on public.photo_worldcup_photos;
create policy "Anyone can add worldcup photos"
on public.photo_worldcup_photos for insert
to anon
with check (true);

drop policy if exists "Anyone can update worldcup photos" on public.photo_worldcup_photos;
create policy "Anyone can update worldcup photos"
on public.photo_worldcup_photos for update
to anon
using (true)
with check (true);

drop policy if exists "Anyone can delete worldcup photos" on public.photo_worldcup_photos;
create policy "Anyone can delete worldcup photos"
on public.photo_worldcup_photos for delete
to anon
using (true);

drop policy if exists "Anyone can create worldcup sessions" on public.photo_worldcup_sessions;
create policy "Anyone can create worldcup sessions"
on public.photo_worldcup_sessions for insert
to anon
with check (true);

drop policy if exists "Anyone can read worldcup sessions" on public.photo_worldcup_sessions;
create policy "Anyone can read worldcup sessions"
on public.photo_worldcup_sessions for select
to anon
using (true);

drop policy if exists "Anyone can read rolling paper" on public.rolling_paper_notes;
create policy "Anyone can read rolling paper"
on public.rolling_paper_notes for select
to anon
using (true);

drop policy if exists "Anyone can add rolling paper notes" on public.rolling_paper_notes;
create policy "Anyone can add rolling paper notes"
on public.rolling_paper_notes for insert
to anon
with check (true);

drop policy if exists "Anyone can read gallery photos" on public.eunseo_gallery_photos;
create policy "Anyone can read gallery photos"
on public.eunseo_gallery_photos for select
to anon
using (true);

drop policy if exists "Anyone can add gallery photos" on public.eunseo_gallery_photos;
create policy "Anyone can add gallery photos"
on public.eunseo_gallery_photos for insert
to anon
with check (true);

drop policy if exists "Anyone can update gallery photos" on public.eunseo_gallery_photos;
create policy "Anyone can update gallery photos"
on public.eunseo_gallery_photos for update
to anon
using (true)
with check (true);

drop policy if exists "Anyone can delete gallery photos" on public.eunseo_gallery_photos;
create policy "Anyone can delete gallery photos"
on public.eunseo_gallery_photos for delete
to anon
using (true);

grant usage on schema public to anon;
grant select, insert on public.doljabi_votes to anon;
grant select, insert, update, delete on public.photo_worldcup_photos to anon;
grant insert, select on public.photo_worldcup_sessions to anon;
grant select, insert on public.rolling_paper_notes to anon;
grant select, insert, update, delete on public.eunseo_gallery_photos to anon;
grant execute on function public.increment_photo_win(uuid) to anon;

insert into storage.buckets (id, name, public)
values ('eunseo-gallery', 'eunseo-gallery', true)
on conflict (id) do update set public = true;

drop policy if exists "Anyone can read eunseo gallery images" on storage.objects;
create policy "Anyone can read eunseo gallery images"
on storage.objects for select
to anon
using (bucket_id = 'eunseo-gallery');

drop policy if exists "Anyone can upload eunseo gallery images" on storage.objects;
create policy "Anyone can upload eunseo gallery images"
on storage.objects for insert
to anon
with check (bucket_id = 'eunseo-gallery');

drop policy if exists "Anyone can update eunseo gallery images" on storage.objects;
create policy "Anyone can update eunseo gallery images"
on storage.objects for update
to anon
using (bucket_id = 'eunseo-gallery')
with check (bucket_id = 'eunseo-gallery');

drop policy if exists "Anyone can delete eunseo gallery images" on storage.objects;
create policy "Anyone can delete eunseo gallery images"
on storage.objects for delete
to anon
using (bucket_id = 'eunseo-gallery');

do $$
begin
  alter publication supabase_realtime add table public.rolling_paper_notes;
exception
  when duplicate_object then null;
end $$;

notify pgrst, 'reload schema';
