<script setup>
import { computed, onMounted, onUnmounted, ref } from 'vue'
import { BarChart3, Trophy } from '@lucide/vue'
import PageShell from '../components/PageShell.vue'
import { fallbackPhotos } from '../lib/photos'
import { hasSupabaseConfig, supabase } from '../lib/supabase'

const photos = ref([])
const activeSetId = ref('')
const round = ref([])
const nextRound = ref([])
const pairIndex = ref(0)
const winner = ref(null)
const isLoading = ref(true)
const error = ref('')
const showRanking = ref(false)
const roundAnnouncement = ref('')
const showFinale = ref(false)
const WORLDCUP_SIZE = 16
let roundTimer = null
let finaleTimer = null

const currentPair = computed(() => round.value.slice(pairIndex.value, pairIndex.value + 2))
const progressText = computed(() => {
  if (showRanking.value) return '베스트포토 랭킹'
  if (winner.value) return '우승 사진'
  if (!round.value.length) return '준비 중'
  const roundName = round.value.length === 2 ? '결승' : `${round.value.length}강`
  return `${roundName} ${Math.floor(pairIndex.value / 2) + 1} / ${Math.ceil(round.value.length / 2)} 매치`
})
const readyText = computed(() => `${photos.value.length} / ${WORLDCUP_SIZE}장 준비됨`)
const hasEnoughPhotos = computed(() => photos.value.length >= WORLDCUP_SIZE)
const rankingPhotos = computed(() =>
  [...photos.value]
    .sort((a, b) => Number(b.win_count ?? 0) - Number(a.win_count ?? 0) || String(a.title).localeCompare(String(b.title))),
)
const podiumPhotos = computed(() => [
  rankingPhotos.value[1],
  rankingPhotos.value[0],
  rankingPhotos.value[2],
])
const lowerRankingPhotos = computed(() => rankingPhotos.value.slice(3))

function shuffle(items) {
  return [...items].sort(() => Math.random() - 0.5)
}

function clearTimers() {
  if (roundTimer) {
    clearTimeout(roundTimer)
    roundTimer = null
  }
  if (finaleTimer) {
    clearTimeout(finaleTimer)
    finaleTimer = null
  }
}

function getRoundName(size) {
  if (size === 2) return '결승!'
  return `${size}강`
}

function showRoundAnnouncement(size) {
  roundAnnouncement.value = getRoundName(size)
  return new Promise((resolve) => {
    roundTimer = setTimeout(() => {
      roundAnnouncement.value = ''
      roundTimer = null
      resolve()
    }, 1000)
  })
}

function playFanfare() {
  const AudioContext = window.AudioContext || window.webkitAudioContext
  if (!AudioContext) return

  const context = new AudioContext()
  const notes = [523.25, 659.25, 783.99, 1046.5]
  const now = context.currentTime

  notes.forEach((frequency, index) => {
    const oscillator = context.createOscillator()
    const gain = context.createGain()
    oscillator.type = 'triangle'
    oscillator.frequency.value = frequency
    oscillator.connect(gain)
    gain.connect(context.destination)
    const start = now + index * 0.12
    gain.gain.setValueAtTime(0.0001, start)
    gain.gain.exponentialRampToValueAtTime(0.18, start + 0.025)
    gain.gain.exponentialRampToValueAtTime(0.0001, start + 0.22)
    oscillator.start(start)
    oscillator.stop(start + 0.24)
  })

  setTimeout(() => context.close(), 900)
}

function startTournament(items = photos.value) {
  clearTimers()
  roundAnnouncement.value = ''
  showFinale.value = false

  if (items.length < WORLDCUP_SIZE) {
    round.value = []
    nextRound.value = []
    pairIndex.value = 0
    winner.value = null
    showRanking.value = false
    return
  }

  const activePhotos = shuffle(items).slice(0, WORLDCUP_SIZE)
  round.value = activePhotos
  nextRound.value = []
  pairIndex.value = 0
  winner.value = null
  showRanking.value = false
}

async function loadPhotos() {
  isLoading.value = true
  error.value = ''
  activeSetId.value = ''

  try {
    if (!hasSupabaseConfig) {
      photos.value = fallbackPhotos
    } else {
      await supabase.rpc('ensure_active_photo_worldcup_set')

      const { data: setData, error: setError } = await supabase
        .from('photo_worldcup_sets')
        .select(
          `
          id,
          photo_worldcup_set_photos (
            win_count,
            photo:photo_worldcup_photos (
              id,
              title,
              image_url
            )
          )
        `,
        )
        .eq('is_active', true)
        .maybeSingle()

      if (setError) throw setError
      activeSetId.value = setData?.id ?? ''
      photos.value =
        setData?.photo_worldcup_set_photos
          ?.map((entry) => ({
            ...entry.photo,
            win_count: entry.win_count,
          }))
          .filter((photo) => photo?.id) ?? []
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
  if (roundAnnouncement.value || showFinale.value) return

  nextRound.value.push(photo)

  if (pairIndex.value + 2 < round.value.length) {
    pairIndex.value += 2
    return
  }

  if (nextRound.value.length === 1) {
    winner.value = nextRound.value[0]
    showFinale.value = true
    playFanfare()
    await saveWinner(winner.value)
    finaleTimer = setTimeout(() => {
      showFinale.value = false
      finaleTimer = null
    }, 1800)
    return
  }

  const upcomingRound = shuffle(nextRound.value)
  await showRoundAnnouncement(upcomingRound.length)
  round.value = upcomingRound
  nextRound.value = []
  pairIndex.value = 0
}

async function saveWinner(photo) {
  if (!hasSupabaseConfig || String(photo.id).startsWith('sample-')) {
    updateLocalWinCount(photo.id)
    return
  }

  try {
    const { error: rpcError } = await supabase.rpc('increment_photo_win', {
      photo_id: photo.id,
      set_id: activeSetId.value || null,
    })
    if (rpcError) {
      const currentCount = Number(photo.win_count ?? 0)
      const { error: updateError } = await supabase
        .from('photo_worldcup_photos')
        .update({ win_count: currentCount + 1 })
        .eq('id', photo.id)

      if (updateError) throw updateError
    }

    await supabase.from('photo_worldcup_sessions').insert({
      winner_photo_id: photo.id,
      set_id: activeSetId.value || null,
    })
    updateLocalWinCount(photo.id)
  } catch (err) {
    error.value = err.message ?? '우승 결과 저장 중 오류가 발생했습니다.'
  }
}

function updateLocalWinCount(photoId) {
  const target = photos.value.find((photo) => photo.id === photoId)
  if (!target) return
  target.win_count = Number(target.win_count ?? 0) + 1
}

onMounted(loadPhotos)
onUnmounted(clearTimers)
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
      </div>

      <p v-if="isLoading" class="muted">사진을 불러오는 중입니다.</p>
      <p v-if="error" class="error-message">{{ error }}</p>

      <div v-if="showRanking" class="worldcup-ranking">
        <div class="podium">
          <article
            v-for="(photo, index) in podiumPhotos"
            :key="photo?.id ?? index"
            class="podium-place"
            :class="[`rank-${index === 0 ? 'second' : index === 1 ? 'first' : 'third'}`]"
          >
            <template v-if="photo">
              <img :src="photo.image_url" :alt="photo.title" />
              <strong>{{ index === 0 ? 2 : index === 1 ? 1 : 3 }}등</strong>
              <span>{{ Number(photo.win_count ?? 0) }}표로 {{ index === 0 ? 2 : index === 1 ? 1 : 3 }}등</span>
              <p>{{ photo.title }}</p>
            </template>
          </article>
        </div>

        <div v-if="lowerRankingPhotos.length" class="ranking-row">
          <article v-for="(photo, index) in lowerRankingPhotos" :key="photo.id">
            <img :src="photo.image_url" :alt="photo.title" />
            <strong>{{ index + 4 }}등</strong>
            <span>{{ Number(photo.win_count ?? 0) }}표</span>
            <p>{{ photo.title }}</p>
          </article>
        </div>
      </div>

      <div v-else-if="winner" class="winner-panel">
        <Trophy :size="40" />
        <p class="eyebrow">WINNER</p>
        <img :src="winner.image_url" :alt="winner.title" />
        <h2>{{ winner.title }}</h2>
        <button type="button" class="primary-action" @click="showRanking = true">
          <BarChart3 :size="18" />
          랭킹보기
        </button>
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

      <button class="worldcup-reset-link" type="button" :disabled="!hasEnoughPhotos" @click="startTournament()">처음부터</button>

      <Teleport to="body">
        <Transition name="round-announcement">
          <div v-if="roundAnnouncement" class="worldcup-round-screen" aria-live="polite">
            <strong>{{ roundAnnouncement }}</strong>
          </div>
        </Transition>
        <Transition name="finale">
          <div v-if="showFinale" class="worldcup-finale" aria-live="polite">
            <div class="fireworks fireworks-left" aria-hidden="true">
              <span v-for="index in 18" :key="`left-${index}`"></span>
            </div>
            <strong>최종 선택!</strong>
            <div class="fireworks fireworks-right" aria-hidden="true">
              <span v-for="index in 18" :key="`right-${index}`"></span>
            </div>
          </div>
        </Transition>
      </Teleport>
    </section>
  </PageShell>
</template>
