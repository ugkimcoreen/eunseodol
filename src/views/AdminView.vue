<script setup>
import { computed, onMounted, ref } from 'vue'
import { ImagePlus, MinusCircle, Pencil, PlusCircle, RefreshCw, Save, Trash2, X } from '@lucide/vue'
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
const galleryFiles = ref([])
const galleryFileInput = ref(null)
const worldcupUpdatingId = ref('')
const galleryEditingId = ref('')
const galleryEditingTitle = ref('')
const gallerySavingId = ref('')
const galleryDeletingId = ref('')
const WORLDCUP_SIZE = 16

const voteSummary = computed(() =>
  doljabiOptions.map((option) => ({
    ...option,
    count: votes.value.filter((vote) => vote.selected_option === option.id).length,
  })),
)

const activeWorldcupPhotos = computed(() => photos.value.filter((photo) => photo.is_active))
const activeWorldcupGalleryIds = computed(
  () => new Set(activeWorldcupPhotos.value.map((photo) => photo.gallery_photo_id).filter(Boolean)),
)
const worldcupCountText = computed(() => `${activeWorldcupPhotos.value.length} / ${WORLDCUP_SIZE}장 선택됨`)
const galleryFileCountText = computed(() => {
  if (!galleryFiles.value.length) return '이미지 파일'
  return `${galleryFiles.value.length}장 선택됨`
})

function worldcupPhotoForGallery(galleryPhoto) {
  return photos.value.find((photo) => photo.gallery_photo_id === galleryPhoto.id)
}

function isInWorldcup(galleryPhoto) {
  return activeWorldcupGalleryIds.value.has(galleryPhoto.id)
}

function startEditGalleryPhoto(photo) {
  galleryEditingId.value = photo.id
  galleryEditingTitle.value = photo.title
  uploadError.value = ''
  uploadSuccess.value = ''
}

function cancelEditGalleryPhoto() {
  galleryEditingId.value = ''
  galleryEditingTitle.value = ''
}

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
  galleryFiles.value = Array.from(event.target.files ?? [])
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

  if (!galleryFiles.value.length) {
    uploadError.value = '업로드할 이미지를 선택해주세요.'
    return
  }

  if (galleryFiles.value.some((file) => !file.type.startsWith('image/'))) {
    uploadError.value = '이미지 파일만 업로드할 수 있습니다.'
    return
  }

  isUploading.value = true

  try {
    const baseTitle = galleryTitle.value.trim()
    const uploadedPhotos = []

    for (const [index, file] of galleryFiles.value.entries()) {
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

      uploadedPhotos.push({
        title:
          galleryFiles.value.length === 1
            ? baseTitle || file.name.replace(/\.[^.]+$/, '')
            : baseTitle
              ? `${baseTitle} ${index + 1}`
              : file.name.replace(/\.[^.]+$/, ''),
        image_url: publicUrl,
        storage_path: storagePath,
      })
    }

    const { error: insertError } = await supabase.from('eunseo_gallery_photos').insert(uploadedPhotos)

    if (insertError) throw insertError

    galleryTitle.value = ''
    galleryFiles.value = []
    if (galleryFileInput.value) galleryFileInput.value.value = ''
    uploadSuccess.value = `갤러리 이미지 ${uploadedPhotos.length}장이 업로드되었습니다.`
    await loadAdminData()
  } catch (err) {
    uploadError.value = err.message ?? '이미지 업로드 중 오류가 발생했습니다.'
  } finally {
    isUploading.value = false
  }
}

async function toggleWorldcupPhoto(galleryPhoto) {
  if (!hasSupabaseConfig) {
    uploadError.value = 'Supabase 환경 변수가 없어 월드컵 사진을 수정할 수 없습니다.'
    return
  }

  uploadError.value = ''
  uploadSuccess.value = ''
  worldcupUpdatingId.value = galleryPhoto.id

  try {
    const existingPhoto = worldcupPhotoForGallery(galleryPhoto)

    if (existingPhoto?.is_active) {
      const { error: updateError } = await supabase
        .from('photo_worldcup_photos')
        .update({ is_active: false })
        .eq('id', existingPhoto.id)

      if (updateError) throw updateError
      uploadSuccess.value = '월드컵 후보에서 제외했습니다.'
      await loadAdminData()
      return
    }

    if (activeWorldcupPhotos.value.length >= WORLDCUP_SIZE) {
      uploadError.value = `월드컵 후보는 최대 ${WORLDCUP_SIZE}장까지 선택할 수 있습니다.`
      return
    }

    if (existingPhoto) {
      const { error: updateError } = await supabase
        .from('photo_worldcup_photos')
        .update({
          title: galleryPhoto.title,
          image_url: galleryPhoto.image_url,
          is_active: true,
        })
        .eq('id', existingPhoto.id)

      if (updateError) throw updateError
    } else {
      const { error: insertError } = await supabase.from('photo_worldcup_photos').insert({
        gallery_photo_id: galleryPhoto.id,
        title: galleryPhoto.title,
        image_url: galleryPhoto.image_url,
        is_active: true,
      })

      if (insertError) throw insertError
    }

    uploadSuccess.value = '월드컵 후보에 추가했습니다.'
    await loadAdminData()
  } catch (err) {
    uploadError.value = err.message ?? '월드컵 후보 수정 중 오류가 발생했습니다.'
  } finally {
    worldcupUpdatingId.value = ''
  }
}

async function updateGalleryPhotoTitle(galleryPhoto) {
  if (!hasSupabaseConfig) {
    uploadError.value = 'Supabase 환경 변수가 없어 사진을 수정할 수 없습니다.'
    return
  }

  const nextTitle = galleryEditingTitle.value.trim()
  if (!nextTitle) {
    uploadError.value = '사진 제목을 입력해주세요.'
    return
  }

  uploadError.value = ''
  uploadSuccess.value = ''
  gallerySavingId.value = galleryPhoto.id

  try {
    const { error: galleryError } = await supabase
      .from('eunseo_gallery_photos')
      .update({ title: nextTitle })
      .eq('id', galleryPhoto.id)

    if (galleryError) throw galleryError

    const existingPhoto = worldcupPhotoForGallery(galleryPhoto)
    if (existingPhoto) {
      const { error: worldcupError } = await supabase
        .from('photo_worldcup_photos')
        .update({ title: nextTitle })
        .eq('id', existingPhoto.id)

      if (worldcupError) throw worldcupError
    }

    uploadSuccess.value = '사진 제목을 수정했습니다.'
    cancelEditGalleryPhoto()
    await loadAdminData()
  } catch (err) {
    uploadError.value = err.message ?? '사진 수정 중 오류가 발생했습니다.'
  } finally {
    gallerySavingId.value = ''
  }
}

async function deleteGalleryPhoto(galleryPhoto) {
  if (!hasSupabaseConfig) {
    uploadError.value = 'Supabase 환경 변수가 없어 사진을 삭제할 수 없습니다.'
    return
  }

  if (!confirm(`"${galleryPhoto.title}" 사진을 삭제할까요?`)) return

  uploadError.value = ''
  uploadSuccess.value = ''
  galleryDeletingId.value = galleryPhoto.id

  try {
    const existingPhoto = worldcupPhotoForGallery(galleryPhoto)
    if (existingPhoto) {
      const { error: worldcupError } = await supabase
        .from('photo_worldcup_photos')
        .delete()
        .eq('id', existingPhoto.id)

      if (worldcupError) throw worldcupError
    }

    if (galleryPhoto.storage_path) {
      const { error: storageError } = await supabase.storage.from('eunseo-gallery').remove([galleryPhoto.storage_path])
      if (storageError) throw storageError
    }

    const { error: galleryError } = await supabase.from('eunseo_gallery_photos').delete().eq('id', galleryPhoto.id)
    if (galleryError) throw galleryError

    if (galleryEditingId.value === galleryPhoto.id) cancelEditGalleryPhoto()
    uploadSuccess.value = '사진을 삭제했습니다.'
    await loadAdminData()
  } catch (err) {
    uploadError.value = err.message ?? '사진 삭제 중 오류가 발생했습니다.'
  } finally {
    galleryDeletingId.value = ''
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
        <div class="panel-title-row">
          <h2>포토월드컵 순위</h2>
          <span>{{ worldcupCountText }}</span>
        </div>
        <div class="rank-list">
          <div v-for="photo in activeWorldcupPhotos" :key="photo.id">
            <img :src="photo.image_url" :alt="photo.title" />
            <span>{{ photo.title }}</span>
            <strong>{{ photo.win_count }}</strong>
          </div>
        </div>
      </div>

      <div class="admin-panel wide">
        <div class="panel-title-row">
          <h2>홈 갤러리 이미지 업로드</h2>
          <span>갤러리는 전체 공개, 월드컵은 선택한 16장만 사용</span>
        </div>
        <form class="upload-form" @submit.prevent="uploadGalleryPhoto">
          <label class="field">
            사진 제목
            <input v-model="galleryTitle" type="text" placeholder="여러 장이면 제목 뒤에 번호가 붙습니다" />
          </label>
          <label class="field">
            {{ galleryFileCountText }}
            <input ref="galleryFileInput" type="file" accept="image/*" multiple @change="onGalleryFileChange" />
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
            <div class="gallery-admin-meta">
              <input
                v-if="galleryEditingId === photo.id"
                v-model="galleryEditingTitle"
                class="gallery-title-input"
                type="text"
                @keydown.enter.prevent="updateGalleryPhotoTitle(photo)"
                @keydown.esc.prevent="cancelEditGalleryPhoto"
              />
              <strong v-else>{{ photo.title }}</strong>
              <span>{{ new Date(photo.created_at).toLocaleString('ko-KR') }}</span>
            </div>
            <div class="gallery-actions">
              <template v-if="galleryEditingId === photo.id">
                <button
                  class="gallery-action-button"
                  type="button"
                  title="저장"
                  :disabled="gallerySavingId === photo.id"
                  @click="updateGalleryPhotoTitle(photo)"
                >
                  <Save :size="15" />
                </button>
                <button class="gallery-action-button" type="button" title="취소" @click="cancelEditGalleryPhoto">
                  <X :size="15" />
                </button>
              </template>
              <template v-else>
                <button class="gallery-action-button" type="button" title="제목 수정" @click="startEditGalleryPhoto(photo)">
                  <Pencil :size="15" />
                </button>
                <button
                  class="gallery-action-button danger"
                  type="button"
                  title="삭제"
                  :disabled="galleryDeletingId === photo.id"
                  @click="deleteGalleryPhoto(photo)"
                >
                  <Trash2 :size="15" />
                </button>
              </template>
            </div>
            <button
              class="worldcup-toggle"
              type="button"
              :class="{ active: isInWorldcup(photo) }"
              :disabled="worldcupUpdatingId === photo.id || (!isInWorldcup(photo) && activeWorldcupPhotos.length >= WORLDCUP_SIZE)"
              @click="toggleWorldcupPhoto(photo)"
            >
              <MinusCircle v-if="isInWorldcup(photo)" :size="16" />
              <PlusCircle v-else :size="16" />
              {{ isInWorldcup(photo) ? '월드컵 포함' : '월드컵 추가' }}
            </button>
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
