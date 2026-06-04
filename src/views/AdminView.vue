<script setup>
import { computed, onMounted, ref } from 'vue'
import { ImagePlus, RefreshCw } from '@lucide/vue'
import PageShell from '../components/PageShell.vue'
import { doljabiOptions, optionLabel } from '../lib/doljabi'
import { hasSupabaseConfig, supabase } from '../lib/supabase'

const votes = ref([])
const photos = ref([])
const galleryPhotos = ref([])
const notes = ref([])
const isLoading = ref(false)
const isUploading = ref(false)
const error = ref('')
const uploadError = ref('')
const uploadSuccess = ref('')
const galleryTitle = ref('')
const galleryFile = ref(null)
const galleryFileInput = ref(null)

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
      galleryPhotos.value = []
      notes.value = []
      return
    }

    const [voteResult, photoResult, galleryResult, noteResult] = await Promise.all([
      supabase.from('doljabi_votes').select('*').order('created_at', { ascending: false }),
      supabase.from('photo_worldcup_photos').select('*').order('win_count', { ascending: false }),
      supabase.from('eunseo_gallery_photos').select('*').order('created_at', { ascending: false }),
      supabase.from('rolling_paper_notes').select('*').order('created_at', { ascending: false }),
    ])

    if (voteResult.error) throw voteResult.error
    if (photoResult.error) throw photoResult.error
    if (galleryResult.error) throw galleryResult.error
    if (noteResult.error) throw noteResult.error

    votes.value = voteResult.data ?? []
    photos.value = photoResult.data ?? []
    galleryPhotos.value = galleryResult.data ?? []
    notes.value = noteResult.data ?? []
  } catch (err) {
    error.value = err.message ?? '관리자 데이터를 불러오지 못했습니다.'
  } finally {
    isLoading.value = false
  }
}

function onGalleryFileChange(event) {
  galleryFile.value = event.target.files?.[0] ?? null
  uploadError.value = ''
  uploadSuccess.value = ''
}

function buildStoragePath(file) {
  const extension = file.name.split('.').pop()?.toLowerCase().replace(/[^a-z0-9]/g, '') || 'jpg'
  const random = globalThis.crypto?.randomUUID?.() ?? Math.random().toString(36).slice(2)
  return `gallery/${Date.now()}-${random}.${extension}`
}

async function uploadGalleryPhoto() {
  uploadError.value = ''
  uploadSuccess.value = ''

  if (!hasSupabaseConfig) {
    uploadError.value = 'Supabase 환경 변수가 없어 업로드할 수 없습니다.'
    return
  }

  if (!galleryFile.value) {
    uploadError.value = '업로드할 이미지를 선택해주세요.'
    return
  }

  if (!galleryFile.value.type.startsWith('image/')) {
    uploadError.value = '이미지 파일만 업로드할 수 있습니다.'
    return
  }

  isUploading.value = true

  try {
    const file = galleryFile.value
    const storagePath = buildStoragePath(file)
    const { error: storageError } = await supabase.storage
      .from('eunseo-gallery')
      .upload(storagePath, file, {
        cacheControl: '3600',
        contentType: file.type,
        upsert: false,
      })

    if (storageError) throw storageError

    const {
      data: { publicUrl },
    } = supabase.storage.from('eunseo-gallery').getPublicUrl(storagePath)

    const title = galleryTitle.value.trim() || file.name.replace(/\.[^.]+$/, '')
    const { error: insertError } = await supabase.from('eunseo_gallery_photos').insert({
      title,
      image_url: publicUrl,
      storage_path: storagePath,
    })

    if (insertError) throw insertError

    galleryTitle.value = ''
    galleryFile.value = null
    if (galleryFileInput.value) galleryFileInput.value.value = ''
    uploadSuccess.value = '갤러리 이미지가 업로드되었습니다.'
    await loadAdminData()
  } catch (err) {
    uploadError.value = err.message ?? '이미지 업로드 중 오류가 발생했습니다.'
  } finally {
    isUploading.value = false
  }
}

onMounted(loadAdminData)
</script>

<template>
  <PageShell>
    <section class="content-header admin-header">
      <div>
        <p class="eyebrow">PARTY DASHBOARD</p>
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
        <h2>홈 갤러리 이미지 업로드</h2>
        <form class="upload-form" @submit.prevent="uploadGalleryPhoto">
          <label class="field">
            사진 제목
            <input v-model="galleryTitle" type="text" placeholder="예: 은서의 생일 미소" />
          </label>
          <label class="field">
            이미지 파일
            <input ref="galleryFileInput" type="file" accept="image/*" @change="onGalleryFileChange" />
          </label>
          <button class="primary-action" type="submit" :disabled="isUploading">
            <ImagePlus :size="18" />
            {{ isUploading ? '업로드 중' : '갤러리에 추가' }}
          </button>
        </form>
        <p v-if="uploadError" class="error-message">{{ uploadError }}</p>
        <p v-if="uploadSuccess" class="success-message">{{ uploadSuccess }}</p>

        <div class="gallery-admin-list">
          <article v-for="photo in galleryPhotos" :key="photo.id">
            <img :src="photo.image_url" :alt="photo.title" />
            <div>
              <strong>{{ photo.title }}</strong>
              <span>{{ new Date(photo.created_at).toLocaleString('ko-KR') }}</span>
            </div>
          </article>
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
