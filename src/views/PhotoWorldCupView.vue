<script setup>
import { computed, onMounted, ref } from 'vue'
import { Trophy } from '@lucide/vue'
import PageShell from '../components/PageShell.vue'
import { fallbackPhotos } from '../lib/photos'
import { hasSupabaseConfig, supabase } from '../lib/supabase'

const photos = ref([])
const round = ref([])
const nextRound = ref([])
const pairIndex = ref(0)
const winner = ref(null)
const isLoading = ref(true)
const error = ref('')
const saved = ref(false)
const WORLDCUP_SIZE = 16

const currentPair = computed(() => round.value.slice(pairIndex.value, pairIndex.value + 2))
const progressText = computed(() => {
  if (winner.value) return '우승 사진'
  if (!round.value.length) return '준비 중'
  const roundName = round.value.length === 2 ? '결승' : `${round.value.length}강`
  return `${roundName} ${Math.floor(pairIndex.value / 2) + 1} / ${Math.ceil(round.value.length / 2)} 매치`
})
const readyText = computed(() => `${photos.value.length} / ${WORLDCUP_SIZE}장 준비됨`)
const hasEnoughPhotos = computed(() => photos.value.length >= WORLDCUP_SIZE)

function shuffle(items) {
  return [...items].sort(() => Math.random() - 0.5)
}

function startTournament(items = photos.value) {
  if (items.length < WORLDCUP_SIZE) {
    round.value = []
    nextRound.value = []
    pairIndex.value = 0
    winner.value = null
    saved.value = false
    return
  }

  const activePhotos = shuffle(items).slice(0, WORLDCUP_SIZE)
  round.value = activePhotos
  nextRound.value = []
  pairIndex.value = 0
  winner.value = null
  saved.value = false
}

async function loadPhotos() {
  isLoading.value = true
  error.value = ''

  try {
    if (!hasSupabaseConfig) {
      photos.value = fallbackPhotos
    } else {
      const { data, error: selectError } = await supabase
        .from('photo_worldcup_photos')
        .select('id,title,image_url,win_count')
        .eq('is_active', true)
        .order('created_at', { ascending: true })

      if (selectError) throw selectError
      photos.value = data ?? []
    }

    startTournament()
  } catch (err) {
    error.value = err.message ?? '사진을 불러오지 못했습니다.'
    photos.value = fallbackPhotos
    startTournament()
  } finally {
    isLoading.value = false
  }
}

async function choosePhoto(photo) {
  nextRound.value.push(photo)

  if (pairIndex.value + 2 < round.value.length) {
    pairIndex.value += 2
    return
  }

  if (nextRound.value.length === 1) {
    winner.value = nextRound.value[0]
    await saveWinner(winner.value)
    return
  }

  round.value = shuffle(nextRound.value)
  nextRound.value = []
  pairIndex.value = 0
}

async function saveWinner(photo) {
  saved.value = false
  if (!hasSupabaseConfig || String(photo.id).startsWith('sample-')) return

  try {
    const { error: rpcError } = await supabase.rpc('increment_photo_win', { photo_id: photo.id })
    if (rpcError) {
      const currentCount = Number(photo.win_count ?? 0)
      const { error: updateError } = await supabase
        .from('photo_worldcup_photos')
        .update({ win_count: currentCount + 1 })
        .eq('id', photo.id)

      if (updateError) throw updateError
    }

    await supabase.from('photo_worldcup_sessions').insert({ winner_photo_id: photo.id })
    saved.value = true
  } catch (err) {
    error.value = err.message ?? '우승 결과 저장 중 오류가 발생했습니다.'
  }
}

onMounted(loadPhotos)
</script>

<template>
  <PageShell>
    <section class="content-header">
      <p class="eyebrow">PHOTO MOMENTS</p>
      <h1>베스트포토월드컵</h1>
      <p>둘 중 더 마음에 드는 은서 사진을 골라 최종 베스트 사진을 뽑아주세요.</p>
    </section>

    <section class="worldcup-stage">
      <div class="stage-toolbar">
        <div>
          <small>BEST PHOTO TOURNAMENT</small>
          <strong>{{ hasEnoughPhotos ? progressText : readyText }}</strong>
        </div>
        <button type="button" :disabled="!hasEnoughPhotos" @click="startTournament()">처음부터</button>
      </div>

      <p v-if="isLoading" class="muted">사진을 불러오는 중입니다.</p>
      <p v-if="error" class="error-message">{{ error }}</p>

      <div v-if="winner" class="winner-panel">
        <Trophy :size="40" />
        <p class="eyebrow">WINNER</p>
        <img :src="winner.image_url" :alt="winner.title" />
        <h2>{{ winner.title }}</h2>
        <p>{{ saved ? '우승 카운트가 저장되었습니다.' : '샘플 또는 로컬 모드에서는 카운트를 저장하지 않습니다.' }}</p>
      </div>

      <div v-else-if="hasEnoughPhotos" class="photo-pair">
        <button v-for="photo in currentPair" :key="photo.id" class="photo-choice" type="button" @click="choosePhoto(photo)">
          <img :src="photo.image_url" :alt="photo.title" />
          <span>{{ photo.title }}</span>
        </button>
      </div>

      <div v-else-if="!isLoading" class="worldcup-empty">
        <strong>16강 후보가 아직 부족합니다.</strong>
        <p>Admin에서 업로드한 갤러리 이미지 중 월드컵 후보 16장을 선택하면 바로 플레이할 수 있습니다.</p>
      </div>
    </section>
  </PageShell>
</template>
