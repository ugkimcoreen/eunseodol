<script setup>
import { computed, onMounted, onUnmounted, ref } from 'vue'
import { Send } from '@lucide/vue'
import PageShell from '../components/PageShell.vue'
import { hasSupabaseConfig, supabase } from '../lib/supabase'

const notes = ref([])
const authorName = ref('')
const message = ref('')
const selectedColor = ref('#fff4b8')
const error = ref('')
const isSaving = ref(false)
let channel = null

const colors = ['#fff4b8', '#d0ebff', '#ffd8d8', '#d3f9d8', '#f3d9fa']
const canSubmit = computed(() => authorName.value.trim().length >= 2 && message.value.trim().length >= 2)

function noteStyle(note) {
  return {
    left: `${note.x}%`,
    top: `${note.y}%`,
    background: note.color,
    transform: `rotate(${note.rotation}deg)`,
  }
}

function makePosition() {
  return {
    x: Math.round((12 + Math.random() * 70) * 10) / 10,
    y: Math.round((12 + Math.random() * 66) * 10) / 10,
    rotation: Math.round(-4 + Math.random() * 8),
  }
}

async function loadNotes() {
  if (!hasSupabaseConfig) {
    notes.value = [
      {
        id: 'sample-note',
        author_name: '은서 가족',
        message: '은서의 첫 생일을 축하해!',
        x: 18,
        y: 18,
        color: '#fff4b8',
        rotation: -2,
      },
    ]
    return
  }

  const { data, error: selectError } = await supabase
    .from('rolling_paper_notes')
    .select('*')
    .order('created_at', { ascending: true })

  if (selectError) {
    error.value = selectError.message
    return
  }

  notes.value = data ?? []
}

function subscribeNotes() {
  if (!hasSupabaseConfig) return

  channel = supabase
    .channel('rolling-paper-notes')
    .on(
      'postgres_changes',
      { event: 'INSERT', schema: 'public', table: 'rolling_paper_notes' },
      (payload) => {
        if (!notes.value.some((note) => note.id === payload.new.id)) {
          notes.value.push(payload.new)
        }
      },
    )
    .subscribe()
}

async function addNote() {
  if (!canSubmit.value || isSaving.value) return

  isSaving.value = true
  error.value = ''
  const position = makePosition()
  const nextNote = {
    author_name: authorName.value.trim(),
    message: message.value.trim(),
    color: selectedColor.value,
    ...position,
  }

  try {
    if (hasSupabaseConfig) {
      const { error: insertError } = await supabase.from('rolling_paper_notes').insert(nextNote)
      if (insertError) throw insertError
    } else {
      notes.value.push({ id: crypto.randomUUID(), ...nextNote })
    }

    authorName.value = ''
    message.value = ''
  } catch (err) {
    error.value = err.message ?? '메모 저장 중 오류가 발생했습니다.'
  } finally {
    isSaving.value = false
  }
}

onMounted(() => {
  loadNotes()
  subscribeNotes()
})

onUnmounted(() => {
  if (channel) supabase.removeChannel(channel)
})
</script>

<template>
  <PageShell>
    <section class="content-header">
      <p class="eyebrow">MESSAGE FOR EUNSEO</p>
      <h1>은서 롤링페이퍼</h1>
      <p>종이 위에 남기는 마음들이 실시간으로 함께 보입니다.</p>
    </section>

    <section class="rolling-layout">
      <div class="paper-canvas" aria-label="롤링페이퍼 캔버스">
        <div class="paper-heading" aria-hidden="true">
          <span>THANK YOU</span>
          <strong>은서에게 남기는 마음</strong>
        </div>
        <article v-for="note in notes" :key="note.id" class="paper-note" :style="noteStyle(note)">
          <p>{{ note.message }}</p>
          <strong>{{ note.author_name }}</strong>
        </article>
      </div>

      <form class="note-form" @submit.prevent="addNote">
        <label class="field">
          <span>작성자</span>
          <input v-model="authorName" maxlength="18" placeholder="이름을 입력하세요" />
        </label>

        <label class="field">
          <span>메시지</span>
          <textarea v-model="message" maxlength="120" rows="5" placeholder="은서에게 남길 말을 적어주세요" />
        </label>

        <div class="swatches" aria-label="메모 색상">
          <button
            v-for="color in colors"
            :key="color"
            type="button"
            :class="{ active: selectedColor === color }"
            :style="{ background: color }"
            :aria-label="`${color} 색상`"
            @click="selectedColor = color"
          />
        </div>

        <button class="primary-action" type="submit" :disabled="!canSubmit || isSaving">
          <Send :size="18" />
          {{ isSaving ? '저장 중' : '붙이기' }}
        </button>
        <p v-if="error" class="error-message">{{ error }}</p>
      </form>
    </section>
  </PageShell>
</template>
