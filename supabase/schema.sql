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

create table if not exists public.photo_worldcup_sets (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  candidate_signature text not null unique,
  is_active boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.photo_worldcup_set_photos (
  set_id uuid not null references public.photo_worldcup_sets(id) on delete cascade,
  photo_id uuid not null references public.photo_worldcup_photos(id) on delete cascade,
  slot integer not null,
  win_count integer not null default 0,
  created_at timestamptz not null default now(),
  primary key (set_id, photo_id),
  unique (set_id, slot)
);

create table if not exists public.photo_worldcup_sessions (
  id uuid primary key default gen_random_uuid(),
  winner_photo_id uuid references public.photo_worldcup_photos(id) on delete set null,
  created_at timestamptz not null default now()
);

alter table public.photo_worldcup_sessions
add column if not exists set_id uuid references public.photo_worldcup_sets(id) on delete set null;

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
  show_in_gallery boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.eunseo_gallery_photos
add column if not exists show_in_gallery boolean not null default false;

create table if not exists public.eunseo_home_video (
  id boolean primary key default true check (id = true),
  video_url text not null,
  storage_path text not null,
  updated_at timestamptz not null default now()
);

alter table public.photo_worldcup_photos
add column if not exists gallery_photo_id uuid references public.eunseo_gallery_photos(id) on delete set null;

create unique index if not exists photo_worldcup_photos_gallery_photo_id_key
on public.photo_worldcup_photos(gallery_photo_id)
where gallery_photo_id is not null;

create or replace function public.ensure_active_photo_worldcup_set()
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  active_count integer;
  set_signature text;
  target_set_id uuid;
begin
  select count(*)
  into active_count
  from public.photo_worldcup_photos
  where is_active = true;

  if active_count <> 16 then
    update public.photo_worldcup_sets set is_active = false where is_active = true;
    return null;
  end if;

  select md5(string_agg(id::text, ',' order by id::text))
  into set_signature
  from public.photo_worldcup_photos
  where is_active = true;

  insert into public.photo_worldcup_sets (name, candidate_signature, is_active)
  values (
    'Set ' || to_char(now(), 'YYYY-MM-DD HH24:MI'),
    set_signature,
    true
  )
  on conflict (candidate_signature) do update
  set is_active = true
  returning id into target_set_id;

  update public.photo_worldcup_sets
  set is_active = false
  where id <> target_set_id and is_active = true;

  insert into public.photo_worldcup_set_photos (set_id, photo_id, slot)
  select
    target_set_id,
    id,
    row_number() over (order by id::text)::integer
  from public.photo_worldcup_photos
  where is_active = true
  on conflict (set_id, photo_id) do nothing;

  return target_set_id;
end;
$$;

drop function if exists public.increment_photo_win(uuid);

create or replace function public.increment_photo_win(photo_id uuid, set_id uuid default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target_set_id uuid := set_id;
begin
  if target_set_id is null then
    select id into target_set_id
    from public.photo_worldcup_sets
    where is_active = true
    order by created_at desc
    limit 1;
  end if;

  if target_set_id is not null then
    update public.photo_worldcup_set_photos
    set win_count = win_count + 1
    where photo_worldcup_set_photos.set_id = target_set_id
      and photo_worldcup_set_photos.photo_id = increment_photo_win.photo_id;
  end if;

  update public.photo_worldcup_photos
  set win_count = win_count + 1
  where id = increment_photo_win.photo_id;
end;
$$;

create or replace function public.reset_eunseo_data()
returns void
language sql
security definer
set search_path = public
as $$
  truncate table
    public.photo_worldcup_sessions,
    public.doljabi_votes,
    public.rolling_paper_notes
  restart identity cascade;

  update public.photo_worldcup_photos
  set win_count = 0;

  update public.photo_worldcup_set_photos
  set win_count = 0;
$$;

alter table public.doljabi_votes enable row level security;
alter table public.photo_worldcup_photos enable row level security;
alter table public.photo_worldcup_sets enable row level security;
alter table public.photo_worldcup_set_photos enable row level security;
alter table public.photo_worldcup_sessions enable row level security;
alter table public.rolling_paper_notes enable row level security;
alter table public.eunseo_gallery_photos enable row level security;
alter table public.eunseo_home_video enable row level security;

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

drop policy if exists "Anyone can read worldcup sets" on public.photo_worldcup_sets;
create policy "Anyone can read worldcup sets"
on public.photo_worldcup_sets for select
to anon
using (true);

drop policy if exists "Anyone can read worldcup set photos" on public.photo_worldcup_set_photos;
create policy "Anyone can read worldcup set photos"
on public.photo_worldcup_set_photos for select
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

drop policy if exists "Anyone can read home video" on public.eunseo_home_video;
create policy "Anyone can read home video"
on public.eunseo_home_video for select
to anon
using (true);

drop policy if exists "Anyone can add home video" on public.eunseo_home_video;
create policy "Anyone can add home video"
on public.eunseo_home_video for insert
to anon
with check (true);

drop policy if exists "Anyone can update home video" on public.eunseo_home_video;
create policy "Anyone can update home video"
on public.eunseo_home_video for update
to anon
using (true)
with check (true);

grant usage on schema public to anon;
grant select, insert on public.doljabi_votes to anon;
grant select, insert, update, delete on public.photo_worldcup_photos to anon;
grant select on public.photo_worldcup_sets to anon;
grant select on public.photo_worldcup_set_photos to anon;
grant insert, select on public.photo_worldcup_sessions to anon;
grant select, insert on public.rolling_paper_notes to anon;
grant select, insert, update, delete on public.eunseo_gallery_photos to anon;
grant select, insert, update on public.eunseo_home_video to anon;
grant execute on function public.increment_photo_win(uuid, uuid) to anon;
grant execute on function public.ensure_active_photo_worldcup_set() to anon;
grant execute on function public.reset_eunseo_data() to anon;

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
