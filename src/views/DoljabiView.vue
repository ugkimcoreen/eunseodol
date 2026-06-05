<script setup>
import { computed, onMounted, ref } from 'vue'
import { CheckCircle2 } from '@lucide/vue'
import PageShell from '../components/PageShell.vue'
import { doljabiOptions } from '../lib/doljabi'
import { hasSupabaseConfig, supabase } from '../lib/supabase'

const SESSION_VOTE_KEY = 'eunseo-doljabi-voted'

const participantName = ref('')
const selectedOption = ref('')
const votes = ref([])
const openResultId = ref('')
const isSubmitting = ref(false)
const saved = ref(false)
const hasVotedThisSession = ref(false)
const error = ref('')

const canSubmit = computed(
  () => participantName.value.trim().length >= 2 && selectedOption.value && !hasVotedThisSession.value,
)
const activeOption = computed(() => doljabiOptions.find((option) => option.id === selectedOption.value))
const voteSummary = computed(() =>
  doljabiOptions
    .map((option, index) => {
      const optionVotes = votes.value.filter((vote) => vote.selected_option === option.id)
      return {
        ...option,
        count: optionVotes.length,
        names: optionVotes.map((vote) => vote.participant_name).filter(Boolean),
        sortIndex: index,
      }
    })
    .sort((a, b) => b.count - a.count || a.sortIndex - b.sortIndex),
)
const maxVoteCount = computed(() => Math.max(1, ...voteSummary.value.map((option) => option.count)))
const totalVoteCount = computed(() => votes.value.length)

function toggleResultPopover(optionId) {
  openResultId.value = openResultId.value === optionId ? '' : optionId
}

async function loadVoteCounts() {
  if (!hasSupabaseConfig) {
    votes.value = []
    return
  }

  try {
    const { data, error: selectError } = await supabase
      .from('doljabi_votes')
      .select('id,participant_name,selected_option')
      .order('created_at', { ascending: false })

    if (selectError) throw selectError
    votes.value = data ?? []
  } catch (err) {
    error.value = err.message ?? '돌잡이 결과를 불러오지 못했습니다.'
  }
}

async function submitVote(optionId = selectedOption.value) {
  selectedOption.value = optionId

  if (hasVotedThisSession.value) {
    error.value = '이미 이 세션에서 선택을 완료했습니다.'
    return
  }

  if (participantName.value.trim().length < 2) {
    error.value = '참여자 이름을 2글자 이상 입력해주세요.'
    return
  }

  if (!selectedOption.value || isSubmitting.value) return

  isSubmitting.value = true
  error.value = ''
  saved.value = false

  try {
    if (!hasSupabaseConfig) {
      throw new Error('Supabase 환경 변수가 설정되지 않았습니다.')
    }

    const { error: insertError } = await supabase.from('doljabi_votes').insert({
      participant_name: participantName.value.trim(),
      selected_option: optionId,
    })

    if (insertError) throw insertError
    saved.value = true
    hasVotedThisSession.value = true
    sessionStorage.setItem(SESSION_VOTE_KEY, optionId)
    await loadVoteCounts()
    participantName.value = ''
    selectedOption.value = ''
  } catch (err) {
    error.value = err.message ?? '저장 중 오류가 발생했습니다.'
  } finally {
    isSubmitting.value = false
  }
}

onMounted(() => {
  hasVotedThisSession.value = Boolean(sessionStorage.getItem(SESSION_VOTE_KEY))
  loadVoteCounts()
})
</script>

<template>
  <PageShell>
    <section class="content-header">
      <p class="eyebrow">DOLJABI LOTTO</p>
      <h1>미리 돌잡이 로또</h1>
      <p>은서가 실제 돌잡이에서 무엇을 고를지 이름과 함께 남겨주세요.</p>
    </section>

    <form class="form-panel doljabi-panel" @submit.prevent="submitVote()">
      <div class="section-title">
        <span></span>
        <strong>무엇을 잡을까요?</strong>
        <span></span>
      </div>

      <label class="field">
        <span>참여자 이름</span>
        <input
          v-model="participantName"
          maxlength="24"
          placeholder="예: 김은서삼촌"
          :disabled="hasVotedThisSession"
        />
      </label>

      <p v-if="hasVotedThisSession && !saved" class="muted">이 세션에서는 이미 선택을 완료했습니다.</p>

      <div class="doljabi-table-scene" role="radiogroup" aria-label="돌잡이 예측 선택">
        <div class="doljabi-table" aria-hidden="true">
          <span class="tabletop"></span>
          <span class="table-leg table-leg-left"></span>
          <span class="table-leg table-leg-right"></span>
        </div>
        <div
          v-for="(option, index) in doljabiOptions"
          :key="option.id"
          class="doljabi-item"
          :class="{ selected: selectedOption === option.id }"
          role="radio"
          tabindex="0"
          :style="{
            '--item-x': option.x,
            '--item-y': option.y,
            '--item-rotation': option.rotation,
            '--item-z': index + 2,
          }"
          :aria-checked="selectedOption === option.id"
          :aria-disabled="hasVotedThisSession"
          @click="!hasVotedThisSession && (selectedOption = option.id)"
          @focus="!hasVotedThisSession && (selectedOption = option.id)"
          @keydown.enter.prevent="!hasVotedThisSession && (selectedOption = option.id)"
          @keydown.space.prevent="!hasVotedThisSession && (selectedOption = option.id)"
        >
          <span v-if="selectedOption === option.id" class="doljabi-tooltip">
            <strong>{{ option.label }}</strong>
            <small>{{ option.detail }}</small>
            <button
              class="doljabi-select-button"
              type="button"
              :disabled="isSubmitting || hasVotedThisSession"
              @click.stop="submitVote(option.id)"
            >
              {{ isSubmitting ? '저장 중' : '선택' }}
            </button>
          </span>
          <img :src="option.image" :alt="option.label" draggable="false" />
        </div>
      </div>

      <p class="doljabi-selection-text">
        {{ activeOption ? `${activeOption.label}: ${activeOption.detail}` : '아이템을 눌러 의미를 확인해주세요.' }}
      </p>

      <p v-if="saved" class="success-message">
        <CheckCircle2 :size="18" />
        저장되었습니다.
      </p>
      <p v-if="error" class="error-message">{{ error }}</p>
    </form>

    <section class="doljabi-results" aria-label="돌잡이 선택 결과">
      <div class="panel-title-row">
        <h2>현재 선택 결과</h2>
        <span>{{ totalVoteCount }}표</span>
      </div>
      <div class="doljabi-chart">
        <button
          v-for="item in voteSummary"
          :key="item.id"
          type="button"
          class="doljabi-chart-row"
          :aria-expanded="openResultId === item.id"
          @click="toggleResultPopover(item.id)"
        >
          <span class="doljabi-chart-label">
            <img :src="item.image" alt="" aria-hidden="true" />
            <span>{{ item.label }}</span>
          </span>
          <span class="doljabi-bar-track" aria-hidden="true">
            <span class="doljabi-bar" :style="{ width: `${(item.count / maxVoteCount) * 100}%` }"></span>
          </span>
          <strong>{{ item.count }}</strong>
          <span v-if="openResultId === item.id" class="doljabi-result-popover">
            <strong>{{ item.label }} 선택</strong>
            <span v-if="item.names.length">{{ item.names.join(', ') }}</span>
            <span v-else>아직 선택한 사람이 없습니다.</span>
          </span>
        </button>
      </div>
    </section>

    <Teleport to="body">
      <div v-if="saved" class="doljabi-success-popup" role="dialog" aria-modal="true" aria-label="돌잡이 선택 완료">
        <div class="doljabi-success-card">
          <CheckCircle2 :size="34" />
          <strong>저장되었습니다.</strong>
          <p>돌잡이 선택이 반영되었습니다.</p>
          <button type="button" class="primary-action" @click="saved = false">확인</button>
        </div>
      </div>
    </Teleport>
  </PageShell>
</template>
