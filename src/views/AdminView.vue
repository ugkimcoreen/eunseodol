<script setup>
import { computed, onMounted, ref } from 'vue'
import { RefreshCw } from '@lucide/vue'
import PageShell from '../components/PageShell.vue'
import { doljabiOptions, optionLabel } from '../lib/doljabi'
import { hasSupabaseConfig, supabase } from '../lib/supabase'

const votes = ref([])
const photos = ref([])
const notes = ref([])
const isLoading = ref(false)
const error = ref('')

const voteSummary = computed(() =>
  doljabiOptions.map((option) => ({
    ...option,
    count: votes.value.filter((vote) => vote.selected_option === option.id).length,
  })),
)

async function loadAdminData() {
  isLoading.value = true
  error.value = ''

  try {
    if (!hasSupabaseConfig) {
      votes.value = []
      photos.value = []
      notes.value = []
      return
    }

    const [voteResult, photoResult, noteResult] = await Promise.all([
      supabase.from('doljabi_votes').select('*').order('created_at', { ascending: false }),
      supabase.from('photo_worldcup_photos').select('*').order('win_count', { ascending: false }),
      supabase.from('rolling_paper_notes').select('*').order('created_at', { ascending: false }),
    ])

    if (voteResult.error) throw voteResult.error
    if (photoResult.error) throw photoResult.error
    if (noteResult.error) throw noteResult.error

    votes.value = voteResult.data ?? []
    photos.value = photoResult.data ?? []
    notes.value = noteResult.data ?? []
  } catch (err) {
    error.value = err.message ?? '관리자 데이터를 불러오지 못했습니다.'
  } finally {
    isLoading.value = false
  }
}

onMounted(loadAdminData)
</script>

<template>
  <PageShell>
    <section class="content-header admin-header">
      <div>
        <p class="eyebrow">결과 확인</p>
        <h1>Admin</h1>
        <p>돌잡이 예측, 포토월드컵 집계, 롤링페이퍼 메모를 확인합니다.</p>
      </div>
      <button class="icon-button" type="button" title="새로고침" @click="loadAdminData">
        <RefreshCw :size="18" />
      </button>
    </section>

    <p v-if="!hasSupabaseConfig" class="error-message">Supabase 환경 변수가 없어 실제 데이터를 불러올 수 없습니다.</p>
    <p v-if="error" class="error-message">{{ error }}</p>
    <p v-if="isLoading" class="muted">불러오는 중입니다.</p>

    <section class="admin-grid">
      <div class="admin-panel">
        <h2>돌잡이 예측 요약</h2>
        <div class="summary-list">
          <div v-for="item in voteSummary" :key="item.id">
            <span>{{ item.label }}</span>
            <strong>{{ item.count }}</strong>
          </div>
        </div>
      </div>

      <div class="admin-panel">
        <h2>포토월드컵 순위</h2>
        <div class="rank-list">
          <div v-for="photo in photos" :key="photo.id">
            <img :src="photo.image_url" :alt="photo.title" />
            <span>{{ photo.title }}</span>
            <strong>{{ photo.win_count }}</strong>
          </div>
        </div>
      </div>

      <div class="admin-panel wide">
        <h2>돌잡이 참여 내역</h2>
        <div class="table-wrap">
          <table>
            <thead>
              <tr>
                <th>이름</th>
                <th>선택</th>
                <th>시간</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="vote in votes" :key="vote.id">
                <td>{{ vote.participant_name }}</td>
                <td>{{ optionLabel(vote.selected_option) }}</td>
                <td>{{ new Date(vote.created_at).toLocaleString('ko-KR') }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div class="admin-panel wide">
        <h2>롤링페이퍼 메모</h2>
        <div class="note-list">
          <article v-for="note in notes" :key="note.id">
            <p>{{ note.message }}</p>
            <span>{{ note.author_name }} · {{ new Date(note.created_at).toLocaleString('ko-KR') }}</span>
          </article>
        </div>
      </div>
    </section>
  </PageShell>
</template>
