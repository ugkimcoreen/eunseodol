<script setup>
import { computed, ref } from 'vue'
import { CheckCircle2 } from '@lucide/vue'
import PageShell from '../components/PageShell.vue'
import { doljabiOptions } from '../lib/doljabi'
import { hasSupabaseConfig, supabase } from '../lib/supabase'

const participantName = ref('')
const selectedOption = ref('')
const isSubmitting = ref(false)
const saved = ref(false)
const error = ref('')

const canSubmit = computed(() => participantName.value.trim().length >= 2 && selectedOption.value)

async function submitVote() {
  if (!canSubmit.value || isSubmitting.value) return

  isSubmitting.value = true
  error.value = ''
  saved.value = false

  try {
    if (!hasSupabaseConfig) {
      throw new Error('Supabase 환경 변수가 설정되지 않았습니다.')
    }

    const { error: insertError } = await supabase.from('doljabi_votes').insert({
      participant_name: participantName.value.trim(),
      selected_option: selectedOption.value,
    })

    if (insertError) throw insertError
    saved.value = true
    participantName.value = ''
    selectedOption.value = ''
  } catch (err) {
    error.value = err.message ?? '저장 중 오류가 발생했습니다.'
  } finally {
    isSubmitting.value = false
  }
}
</script>

<template>
  <PageShell>
    <section class="content-header">
      <p class="eyebrow">DOLJABI LOTTO</p>
      <h1>미리 돌잡이 로또</h1>
      <p>은서가 실제 돌잡이에서 무엇을 고를지 이름과 함께 남겨주세요.</p>
    </section>

    <form class="form-panel" @submit.prevent="submitVote">
      <div class="section-title">
        <span></span>
        <strong>무엇을 잡을까요?</strong>
        <span></span>
      </div>

      <label class="field">
        <span>참여자 이름</span>
        <input v-model="participantName" maxlength="24" placeholder="예: 김은서삼촌" />
      </label>

      <div class="option-grid" role="radiogroup" aria-label="돌잡이 예측 선택">
        <button
          v-for="option in doljabiOptions"
          :key="option.id"
          type="button"
          class="choice-card"
          :class="{ selected: selectedOption === option.id }"
          :style="{ '--choice-color': option.color }"
          @click="selectedOption = option.id"
        >
          <span class="choice-dot" aria-hidden="true"></span>
          <strong>{{ option.label }}</strong>
          <small>{{ option.detail }}</small>
        </button>
      </div>

      <button class="primary-action" type="submit" :disabled="!canSubmit || isSubmitting">
        {{ isSubmitting ? '저장 중' : '예측 저장하기' }}
      </button>

      <p v-if="saved" class="success-message">
        <CheckCircle2 :size="18" />
        저장되었습니다.
      </p>
      <p v-if="error" class="error-message">{{ error }}</p>
    </form>
  </PageShell>
</template>
