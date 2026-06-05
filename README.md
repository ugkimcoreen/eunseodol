# 은서 playground

Vite + Vue + Supabase로 만든 첫 생일 참여 허브입니다.

## 실행

```bash
npm install
npm run dev
```

## Supabase 설정

`.env`에는 아래 값이 필요합니다.

```bash
VITE_SUPABASE_URL=...
VITE_SUPABASE_PUBLISHABLE_KEY=...
```

Supabase SQL editor에서 `supabase/schema.sql`을 실행하면 다음 기능이 준비됩니다.

- `doljabi_votes`: 돌잡이 예측 저장
- `photo_worldcup_photos`: 갤러리에서 선택한 월드컵 후보와 우승 카운트
- `photo_worldcup_sessions`: 월드컵 참여 결과 이력
- `rolling_paper_notes`: 실시간 롤링페이퍼 메모
- `eunseo_gallery_photos`: 홈 갤러리에 공개되는 전체 사진

## 사진 등록 예시

`/admin`에서 이미지를 업로드하면 홈 갤러리에 모두 공개됩니다.
각 갤러리 사진의 `월드컵 추가` 버튼으로 최대 32장을 선택하면 포토월드컵에만 따로 사용됩니다.

```sql
insert into public.eunseo_gallery_photos (title, image_url, storage_path)
values
  ('웃는 은서', 'https://example.com/eunseo-1.jpg', 'manual/eunseo-1.jpg'),
  ('케이크 앞 은서', 'https://example.com/eunseo-2.jpg', 'manual/eunseo-2.jpg');
```

실제 운영에서는 `/admin` 화면에 별도 인증을 붙이는 것을 권장합니다.
