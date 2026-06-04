<script setup>
import { Baby, Camera, ScrollText } from '@lucide/vue'
import PageShell from '../components/PageShell.vue'

const menus = [
  {
    title: '미리 돌잡이 로또',
    description: '참여자 이름과 예측 선택을 남기고, 관리자 화면에서 결과 내역을 확인합니다.',
    to: '/doljabi',
    label: '예측하러 가기',
    icon: Baby,
  },
  {
    title: '베스트포토월드컵',
    description: '은서 사진을 토너먼트로 고르고 최종 우승 사진의 카운트를 올립니다.',
    to: '/photo-worldcup',
    label: '월드컵 시작',
    icon: Camera,
  },
  {
    title: '은서 롤링페이퍼',
    description: '큰 종이 위에 실시간으로 축하 메모를 남기는 공동 캔버스입니다.',
    to: '/rolling-paper',
    label: '메모 남기기',
    icon: ScrollText,
  },
]
</script>

<template>
  <PageShell>
    <section class="home-hero">
      <div class="hero-copy">
        <p class="eyebrow">INVITATION</p>
        <h1>은서의 첫 생일</h1>
        <p>돌잡이 예측, 사진 월드컵, 롤링페이퍼를 한 곳에서 즐기는 작은 돌잔치 놀이터입니다.</p>
      </div>
      <div class="invite-card" aria-label="은서 첫 생일 초대장">
        <div class="invite-line"></div>
        <p>1ST BIRTHDAY</p>
        <div class="invite-photo-frame">
          <div class="invite-photo">E</div>
        </div>
        <strong>김은서</strong>
        <span>2025.07.24 THU 12:00</span>
        <RouterLink class="admin-link" to="/admin">결과 보기</RouterLink>
      </div>
    </section>

    <section class="menu-grid" aria-label="참여 메뉴">
      <RouterLink v-for="(menu, index) in menus" :key="menu.to" class="menu-card" :to="menu.to">
        <component :is="menu.icon" :size="30" stroke-width="1.8" />
        <div>
          <small>{{ String(index + 1).padStart(2, '0') }} · EUNSEO PARTY</small>
          <h2>{{ menu.title }}</h2>
          <p>{{ menu.description }}</p>
        </div>
        <span>{{ menu.label }}</span>
      </RouterLink>
    </section>
  </PageShell>
</template>
