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
- `photo_worldcup_photos`: 갤러리에서 선택한 월드컵 후보
- `photo_worldcup_sets`: 후보 16장 조합별 월드컵 세트
- `photo_worldcup_set_photos`: 세트 안의 후보별 우승 카운트
- `photo_worldcup_sessions`: 월드컵 참여 결과 이력과 사용한 세트
- `rolling_paper_notes`: 실시간 롤링페이퍼 메모
- `eunseo_gallery_photos`: 홈 갤러리에 공개되는 전체 사진

## 사진 등록 예시

`/admin`에서 이미지를 업로드하면 홈 갤러리에 모두 공개됩니다.
각 갤러리 사진의 `월드컵 추가` 버튼으로 최대 16장을 선택하면 포토월드컵에만 따로 사용됩니다.
후보가 정확히 16장이 되면 해당 후보 조합이 하나의 세트로 자동 저장되고, 같은 16장 조합은 기존 결과를 이어서 사용합니다.
후보를 교체해 다른 16장 조합이 되면 새 세트 결과가 0표부터 따로 관리됩니다.

```sql
insert into public.eunseo_gallery_photos (title, image_url, storage_path)
values
  ('웃는 은서', 'https://example.com/eunseo-1.jpg', 'manual/eunseo-1.jpg'),
  ('케이크 앞 은서', 'https://example.com/eunseo-2.jpg', 'manual/eunseo-2.jpg');
```

실제 운영에서는 `/admin` 화면에 별도 인증을 붙이는 것을 권장합니다.
