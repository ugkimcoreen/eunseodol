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
- `photo_worldcup_photos`: 월드컵 사진과 우승 카운트
- `photo_worldcup_sessions`: 월드컵 참여 결과 이력
- `rolling_paper_notes`: 실시간 롤링페이퍼 메모

## 사진 등록 예시

`photo_worldcup_photos` 테이블에 사진 URL을 넣으면 월드컵에 자동으로 표시됩니다.

```sql
insert into public.photo_worldcup_photos (title, image_url)
values
  ('웃는 은서', 'https://example.com/eunseo-1.jpg'),
  ('케이크 앞 은서', 'https://example.com/eunseo-2.jpg');
```

실제 운영에서는 `/admin` 화면에 별도 인증을 붙이는 것을 권장합니다.
