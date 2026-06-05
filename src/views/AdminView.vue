<script setup>
import { computed, onMounted, ref } from 'vue'
import { AlertTriangle, ImagePlus, MinusCircle, Pencil, PlusCircle, RefreshCw, Save, Trash2, X } from '@lucide/vue'
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
const isResetModalOpen = ref(false)
const isResetting = ref(false)
const resetConfirmText = ref('')
const resetError = ref('')
const resetSuccess = ref('')
const WORLDCUP_SIZE = 16
const RESET_CONFIRM_TEXT = '초기화'

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

function worldcupPhotosForGallery(galleryPhoto) {
  return photos.value.filter(
    (photo) => photo.gallery_photo_id === galleryPhoto.id || photo.image_url === galleryPhoto.image_url,
  )
}

function storagePathForGalleryPhoto(galleryPhoto) {
  if (galleryPhoto.storage_path) return galleryPhoto.storage_path

  try {
    const pathPrefix = '/storage/v1/object/public/eunseo-gallery/'
    const { pathname } = new URL(galleryPhoto.image_url)
    const prefixIndex = pathname.indexOf(pathPrefix)

    if (prefixIndex === -1) return ''
    return decodeURIComponent(pathname.slice(prefixIndex + pathPrefix.length))
  } catch {
    return ''
  }
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
    const linkedWorldcupPhotos = worldcupPhotosForGallery(galleryPhoto)
    if (linkedWorldcupPhotos.length) {
      const { error: worldcupError } = await supabase
        .from('photo_worldcup_photos')
        .delete()
        .in(
          'id',
          linkedWorldcupPhotos.map((photo) => photo.id),
        )

      if (worldcupError) throw worldcupError
    }

    const { error: galleryError } = await supabase.from('eunseo_gallery_photos').delete().eq('id', galleryPhoto.id)
    if (galleryError) throw galleryError

    const storagePath = storagePathForGalleryPhoto(galleryPhoto)
    if (storagePath) {
      const { error: storageError } = await supabase.storage.from('eunseo-gallery').remove([storagePath])
      if (storageError) {
        uploadSuccess.value = '사진 목록에서는 삭제했습니다. Storage 파일 삭제 권한은 Supabase 정책을 확인해주세요.'
      }
    }

    if (galleryEditingId.value === galleryPhoto.id) cancelEditGalleryPhoto()
    if (!uploadSuccess.value) uploadSuccess.value = '사진을 삭제했습니다.'
    await loadAdminData()
  } catch (err) {
    uploadError.value = err.message ?? '사진 삭제 중 오류가 발생했습니다.'
  } finally {
    galleryDeletingId.value = ''
  }
}

function openResetModal() {
  resetConfirmText.value = ''
  resetError.value = ''
  resetSuccess.value = ''
  isResetModalOpen.value = true
}

function closeResetModal() {
  if (isResetting.value) return
  isResetModalOpen.value = false
  resetConfirmText.value = ''
  resetError.value = ''
}

async function removeAllGalleryStorageFiles() {
  const paths = new Set(galleryPhotos.value.map(storagePathForGalleryPhoto).filter(Boolean))
  let offset = 0
  const limit = 100

  while (true) {
    const { data, error: listError } = await supabase.storage.from('eunseo-gallery').list('gallery', {
      limit,
      offset,
      sortBy: { column: 'name', order: 'asc' },
    })

    if (listError) throw listError

    const files = data ?? []
    files.filter((file) => file.name).forEach((file) => paths.add(`gallery/${file.name}`))

    if (files.length < limit) break
    offset += limit
  }

  const allPaths = Array.from(paths)
  for (let index = 0; index < allPaths.length; index += 100) {
    const { error: removeError } = await supabase.storage.from('eunseo-gallery').remove(allPaths.slice(index, index + 100))
    if (removeError) throw removeError
  }
}

async function resetAllData() {
  if (!hasSupabaseConfig) {
    resetError.value = 'Supabase 환경 변수가 없어 데이터를 초기화할 수 없습니다.'
    return
  }

  if (resetConfirmText.value !== RESET_CONFIRM_TEXT) {
    resetError.value = `"${RESET_CONFIRM_TEXT}"를 입력해야 초기화할 수 있습니다.`
    return
  }

  isResetting.value = true
  resetError.value = ''
  resetSuccess.value = ''

  try {
    await removeAllGalleryStorageFiles()

    const { error: resetDataError } = await supabase.rpc('reset_eunseo_data')
    if (resetDataError) throw resetDataError

    votes.value = []
    photos.value = []
    galleryPhotos.value = []
    notes.value = []
    resetSuccess.value = '모든 데이터가 초기화되었습니다.'
    isResetModalOpen.value = false
    resetConfirmText.value = ''
    await loadAdminData()
  } catch (err) {
    resetError.value = err.message ?? '데이터 초기화 중 오류가 발생했습니다.'
  } finally {
    isResetting.value = false
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

      <div class="admin-panel wide danger-zone">
        <div>
          <h2>데이터 초기화</h2>
          <p>돌잡이 투표, 포토월드컵 기록, 갤러리 이미지, 롤링페이퍼 메모를 모두 삭제합니다.</p>
        </div>
        <button class="danger-action" type="button" :disabled="isResetting" @click="openResetModal">
          <AlertTriangle :size="18" />
          전체 데이터 초기화
        </button>
        <p v-if="resetSuccess" class="success-message">{{ resetSuccess }}</p>
        <p v-if="resetError && !isResetModalOpen" class="error-message">{{ resetError }}</p>
      </div>
    </section>

    <div v-if="isResetModalOpen" class="modal-backdrop" role="presentation" @click.self="closeResetModal">
      <section class="confirm-modal" role="dialog" aria-modal="true" aria-labelledby="reset-modal-title">
        <AlertTriangle :size="34" />
        <h2 id="reset-modal-title">정말 모든 데이터를 초기화할까요?</h2>
        <p>
          삭제하면 돌잡이 참여 내역, 월드컵 후보/승리 기록, 갤러리 이미지 파일, 롤링페이퍼 메모를 복구할 수 없습니다.
        </p>
        <label class="field">
          계속하려면 "{{ RESET_CONFIRM_TEXT }}"를 입력하세요
          <input v-model="resetConfirmText" type="text" autocomplete="off" />
        </label>
        <p v-if="resetError" class="error-message">{{ resetError }}</p>
        <div class="modal-actions">
          <button class="gallery-action-button modal-close-button" type="button" :disabled="isResetting" @click="closeResetModal">
            취소
          </button>
          <button
            class="danger-action"
            type="button"
            :disabled="isResetting || resetConfirmText !== RESET_CONFIRM_TEXT"
            @click="resetAllData"
          >
            <Trash2 :size="18" />
            {{ isResetting ? '삭제 중' : '진짜 삭제' }}
          </button>
        </div>
      </section>
    </div>
  </PageShell>
</template>
