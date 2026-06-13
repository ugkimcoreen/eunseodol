<script setup>
import { computed, onMounted, ref } from 'vue'
import { AlertTriangle, Download, ImagePlus, LockKeyhole, MinusCircle, Pencil, PlusCircle, RefreshCw, Save, Trash2, Video, X } from '@lucide/vue'
import PageShell from '../components/PageShell.vue'
import { doljabiOptions, optionLabel } from '../lib/doljabi'
import { hasSupabaseConfig, supabase } from '../lib/supabase'

const votes = ref([])
const photos = ref([])
const activeWorldcupSet = ref(null)
const galleryPhotos = ref([])
const notes = ref([])
const isLoading = ref(false)
const isUploading = ref(false)
const isDownloadingGallery = ref(false)
const error = ref('')
const uploadError = ref('')
const uploadSuccess = ref('')
const galleryTitle = ref('')
const galleryFiles = ref([])
const galleryFileInput = ref(null)
const homeVideo = ref(null)
const homeVideoFile = ref(null)
const homeVideoFileInput = ref(null)
const isVideoUploading = ref(false)
const videoError = ref('')
const videoSuccess = ref('')
const worldcupUpdatingId = ref('')
const galleryEditingId = ref('')
const galleryEditingTitle = ref('')
const gallerySavingId = ref('')
const galleryDeletingId = ref('')
const galleryVisibilityUpdatingId = ref('')
const isResetModalOpen = ref(false)
const isResetting = ref(false)
const resetConfirmText = ref('')
const resetError = ref('')
const resetSuccess = ref('')
const isAdminUnlocked = ref(false)
const adminPassword = ref('')
const adminAuthError = ref('')
const WORLDCUP_SIZE = 16
const RESET_CONFIRM_TEXT = '초기화'
const ADMIN_PASSWORD = '1111'
const ADMIN_AUTH_COOKIE = 'eunseo_admin_auth'
const ADMIN_AUTH_COOKIE_VALUE = 'unlocked'
const ADMIN_AUTH_COOKIE_MAX_AGE = 60 * 60 * 24 * 30
const ZIP_UTF8_FLAG = 0x0800
const ZIP_VERSION = 20
const ZIP_CRC_TABLE = Uint32Array.from({ length: 256 }, (_, value) => {
  let crc = value
  for (let index = 0; index < 8; index += 1) {
    crc = crc & 1 ? 0xedb88320 ^ (crc >>> 1) : crc >>> 1
  }
  return crc >>> 0
})

const voteSummary = computed(() =>
  doljabiOptions.map((option) => ({
    ...option,
    count: votes.value.filter((vote) => vote.selected_option === option.id).length,
  })),
)

const activeSetWinCounts = computed(() => {
  const entries = activeWorldcupSet.value?.photo_worldcup_set_photos ?? []
  return new Map(entries.map((entry) => [entry.photo_id, Number(entry.win_count ?? 0)]))
})
const activeWorldcupPhotos = computed(() =>
  photos.value
    .filter((photo) => photo.is_active)
    .map((photo) => ({
      ...photo,
      win_count: activeWorldcupSet.value ? (activeSetWinCounts.value.get(photo.id) ?? 0) : Number(photo.win_count ?? 0),
    }))
    .sort(
      (a, b) =>
        Number(b.win_count ?? 0) - Number(a.win_count ?? 0) || String(a.title).localeCompare(String(b.title)),
    ),
)
const activeWorldcupGalleryIds = computed(
  () => new Set(activeWorldcupPhotos.value.map((photo) => photo.gallery_photo_id).filter(Boolean)),
)
const worldcupCountText = computed(() => `${activeWorldcupPhotos.value.length} / ${WORLDCUP_SIZE}장 선택됨`)
const worldcupSetText = computed(() => {
  if (activeWorldcupPhotos.value.length !== WORLDCUP_SIZE) return '16장이 되면 새 세트가 자동 저장됩니다.'
  if (!activeWorldcupSet.value) return '현재 후보 세트를 준비 중입니다.'
  return `${activeWorldcupSet.value.name} 결과`
})
const galleryFileCountText = computed(() => {
  if (!galleryFiles.value.length) return '이미지 파일'
  return `${galleryFiles.value.length}장 선택됨`
})
const visibleGalleryCount = computed(() => galleryPhotos.value.filter((photo) => photo.show_in_gallery).length)
const homeVideoFileText = computed(() => homeVideoFile.value?.name ?? '가로 영상 파일')

function getCookieValue(name) {
  return document.cookie
    .split('; ')
    .find((cookie) => cookie.startsWith(`${name}=`))
    ?.split('=')
    .slice(1)
    .join('=')
}

function setAdminAuthCookie() {
  document.cookie = `${ADMIN_AUTH_COOKIE}=${ADMIN_AUTH_COOKIE_VALUE}; path=/; max-age=${ADMIN_AUTH_COOKIE_MAX_AGE}; SameSite=Lax`
}

function unlockAdminFromCookie() {
  isAdminUnlocked.value = getCookieValue(ADMIN_AUTH_COOKIE) === ADMIN_AUTH_COOKIE_VALUE
}

async function submitAdminPassword() {
  adminAuthError.value = ''

  if (adminPassword.value !== ADMIN_PASSWORD) {
    adminAuthError.value = '비밀번호가 올바르지 않습니다.'
    adminPassword.value = ''
    return
  }

  setAdminAuthCookie()
  isAdminUnlocked.value = true
  adminPassword.value = ''
  await loadAdminData()
}

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

function sanitizeFilename(value, fallback = 'image') {
  const filename = String(value || fallback)
    .trim()
    .replace(/[\\/:*?"<>|]/g, '-')
    .replace(/\s+/g, ' ')
    .slice(0, 80)

  return filename || fallback
}

function uniqueFilename(filename, usedFilenames) {
  if (!usedFilenames.has(filename)) {
    usedFilenames.add(filename)
    return filename
  }

  const dotIndex = filename.lastIndexOf('.')
  const basename = dotIndex === -1 ? filename : filename.slice(0, dotIndex)
  const extension = dotIndex === -1 ? '' : filename.slice(dotIndex)
  let count = 2

  while (usedFilenames.has(`${basename}-${count}${extension}`)) {
    count += 1
  }

  const nextFilename = `${basename}-${count}${extension}`
  usedFilenames.add(nextFilename)
  return nextFilename
}

function extensionForGalleryPhoto(galleryPhoto, blob) {
  const storagePathExtension = storagePathForGalleryPhoto(galleryPhoto).split('.').pop()
  if (storagePathExtension && storagePathExtension.length <= 5) return storagePathExtension.toLowerCase()

  const urlExtension = galleryPhoto.image_url?.split('?')[0]?.split('.').pop()
  if (urlExtension && urlExtension.length <= 5) return urlExtension.toLowerCase()

  const mimeExtension = blob.type.split('/')[1]
  return mimeExtension || 'jpg'
}

function triggerBlobDownload(blob, filename) {
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = filename
  document.body.append(link)
  link.click()
  link.remove()
  URL.revokeObjectURL(url)
}

function crc32(bytes) {
  let crc = 0xffffffff
  for (const byte of bytes) {
    crc = ZIP_CRC_TABLE[(crc ^ byte) & 0xff] ^ (crc >>> 8)
  }
  return (crc ^ 0xffffffff) >>> 0
}

function createZipRecord(signature, length) {
  const bytes = new Uint8Array(length)
  const view = new DataView(bytes.buffer)
  view.setUint32(0, signature, true)
  return { bytes, view }
}

function buildZipBlob(entries) {
  const encoder = new TextEncoder()
  const chunks = []
  const centralDirectoryChunks = []
  let offset = 0

  for (const entry of entries) {
    const filenameBytes = encoder.encode(entry.filename)
    const dataBytes = new Uint8Array(entry.blob)
    const checksum = crc32(dataBytes)

    const localHeader = createZipRecord(0x04034b50, 30)
    localHeader.view.setUint16(4, ZIP_VERSION, true)
    localHeader.view.setUint16(6, ZIP_UTF8_FLAG, true)
    localHeader.view.setUint16(8, 0, true)
    localHeader.view.setUint32(14, checksum, true)
    localHeader.view.setUint32(18, dataBytes.length, true)
    localHeader.view.setUint32(22, dataBytes.length, true)
    localHeader.view.setUint16(26, filenameBytes.length, true)

    chunks.push(localHeader.bytes, filenameBytes, dataBytes)

    const centralDirectoryHeader = createZipRecord(0x02014b50, 46)
    centralDirectoryHeader.view.setUint16(4, ZIP_VERSION, true)
    centralDirectoryHeader.view.setUint16(6, ZIP_VERSION, true)
    centralDirectoryHeader.view.setUint16(8, ZIP_UTF8_FLAG, true)
    centralDirectoryHeader.view.setUint16(10, 0, true)
    centralDirectoryHeader.view.setUint32(16, checksum, true)
    centralDirectoryHeader.view.setUint32(20, dataBytes.length, true)
    centralDirectoryHeader.view.setUint32(24, dataBytes.length, true)
    centralDirectoryHeader.view.setUint16(28, filenameBytes.length, true)
    centralDirectoryHeader.view.setUint32(42, offset, true)

    centralDirectoryChunks.push(centralDirectoryHeader.bytes, filenameBytes)
    offset += localHeader.bytes.length + filenameBytes.length + dataBytes.length
  }

  const centralDirectoryOffset = offset
  const centralDirectorySize = centralDirectoryChunks.reduce((size, chunk) => size + chunk.length, 0)
  const endOfCentralDirectory = createZipRecord(0x06054b50, 22)
  endOfCentralDirectory.view.setUint16(8, entries.length, true)
  endOfCentralDirectory.view.setUint16(10, entries.length, true)
  endOfCentralDirectory.view.setUint32(12, centralDirectorySize, true)
  endOfCentralDirectory.view.setUint32(16, centralDirectoryOffset, true)

  return new Blob([...chunks, ...centralDirectoryChunks, endOfCentralDirectory.bytes], { type: 'application/zip' })
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
      activeWorldcupSet.value = null
      galleryPhotos.value = []
      homeVideo.value = null
      notes.value = []
      return
    }

    await supabase.rpc('ensure_active_photo_worldcup_set')

    const [voteResult, photoResult, setResult, galleryResult, videoResult, noteResult] = await Promise.all([
      supabase.from('doljabi_votes').select('*').order('created_at', { ascending: false }),
      supabase.from('photo_worldcup_photos').select('*').order('win_count', { ascending: false }),
      supabase
        .from('photo_worldcup_sets')
        .select(
          `
          id,
          name,
          photo_worldcup_set_photos (
            photo_id,
            win_count
          )
        `,
        )
        .eq('is_active', true)
        .maybeSingle(),
      supabase.from('eunseo_gallery_photos').select('*').order('created_at', { ascending: false }),
      supabase.from('eunseo_home_video').select('*').eq('id', true).maybeSingle(),
      supabase.from('rolling_paper_notes').select('*').order('created_at', { ascending: false }),
    ])

    if (voteResult.error) throw voteResult.error
    if (photoResult.error) throw photoResult.error
    if (setResult.error) throw setResult.error
    if (galleryResult.error) throw galleryResult.error
    if (videoResult.error) throw videoResult.error
    if (noteResult.error) throw noteResult.error

    votes.value = voteResult.data ?? []
    photos.value = photoResult.data ?? []
    activeWorldcupSet.value = setResult.data ?? null
    galleryPhotos.value = galleryResult.data ?? []
    homeVideo.value = videoResult.data ?? null
    notes.value = noteResult.data ?? []
  } catch (err) {
    error.value = err.message ?? '관리자 데이터를 불러오지 못했습니다.'
  } finally {
    isLoading.value = false
  }
}

async function ensureActiveWorldcupSet() {
  const { error: setError } = await supabase.rpc('ensure_active_photo_worldcup_set')
  if (setError) throw setError
}

function onGalleryFileChange(event) {
  galleryFiles.value = Array.from(event.target.files ?? [])
  uploadError.value = ''
  uploadSuccess.value = ''
}

function onHomeVideoFileChange(event) {
  homeVideoFile.value = event.target.files?.[0] ?? null
  videoError.value = ''
  videoSuccess.value = ''
}

function buildStoragePath(file, folder = 'gallery', fallbackExtension = 'jpg') {
  const extension = file.name.split('.').pop()?.toLowerCase().replace(/[^a-z0-9]/g, '') || fallbackExtension
  const random = globalThis.crypto?.randomUUID?.() ?? Math.random().toString(36).slice(2)
  return `${folder}/${Date.now()}-${random}.${extension}`
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
        show_in_gallery: false,
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

async function downloadAllGalleryPhotos() {
  uploadError.value = ''
  uploadSuccess.value = ''

  if (!galleryPhotos.value.length) {
    uploadError.value = '다운로드할 이미지가 없습니다.'
    return
  }

  isDownloadingGallery.value = true

  try {
    const usedFilenames = new Set()
    const zipEntries = []

    for (const [index, photo] of galleryPhotos.value.entries()) {
      const storagePath = storagePathForGalleryPhoto(photo)
      let blob

      if (hasSupabaseConfig && storagePath) {
        const { data, error: downloadError } = await supabase.storage.from('eunseo-gallery').download(storagePath)
        if (downloadError) throw downloadError
        blob = data
      } else {
        const response = await fetch(photo.image_url)
        if (!response.ok) throw new Error(`${photo.title} 이미지를 다운로드하지 못했습니다.`)
        blob = await response.blob()
      }

      const extension = extensionForGalleryPhoto(photo, blob)
      const filename = uniqueFilename(
        `${String(index + 1).padStart(2, '0')}-${sanitizeFilename(photo.title)}.${extension}`,
        usedFilenames,
      )
      zipEntries.push({ filename, blob: await blob.arrayBuffer() })
    }

    triggerBlobDownload(buildZipBlob(zipEntries), 'eunseo-gallery-images.zip')
    uploadSuccess.value = `갤러리 이미지 ${galleryPhotos.value.length}장을 ZIP으로 다운로드했습니다.`
  } catch (err) {
    uploadError.value = err.message ?? '이미지 다운로드 중 오류가 발생했습니다.'
  } finally {
    isDownloadingGallery.value = false
  }
}

async function uploadHomeVideo() {
  videoError.value = ''
  videoSuccess.value = ''

  if (!hasSupabaseConfig) {
    videoError.value = 'Supabase 환경 변수가 없어 업로드할 수 없습니다.'
    return
  }

  if (!homeVideoFile.value) {
    videoError.value = '업로드할 영상을 선택해주세요.'
    return
  }

  if (!homeVideoFile.value.type.startsWith('video/')) {
    videoError.value = '영상 파일만 업로드할 수 있습니다.'
    return
  }

  isVideoUploading.value = true

  try {
    const previousStoragePath = homeVideo.value?.storage_path
    const storagePath = buildStoragePath(homeVideoFile.value, 'home-video', 'mp4')
    const { error: storageError } = await supabase.storage.from('eunseo-gallery').upload(storagePath, homeVideoFile.value, {
      cacheControl: '3600',
      contentType: homeVideoFile.value.type,
      upsert: false,
    })

    if (storageError) throw storageError

    const {
      data: { publicUrl },
    } = supabase.storage.from('eunseo-gallery').getPublicUrl(storagePath)

    const { error: upsertError } = await supabase.from('eunseo_home_video').upsert({
      id: true,
      video_url: publicUrl,
      storage_path: storagePath,
      updated_at: new Date().toISOString(),
    })

    if (upsertError) throw upsertError

    if (previousStoragePath && previousStoragePath !== storagePath) {
      await supabase.storage.from('eunseo-gallery').remove([previousStoragePath])
    }

    homeVideoFile.value = null
    if (homeVideoFileInput.value) homeVideoFileInput.value.value = ''
    videoSuccess.value = '메인 배경 영상이 업로드되었습니다.'
    await loadAdminData()
  } catch (err) {
    videoError.value = err.message ?? '영상 업로드 중 오류가 발생했습니다.'
  } finally {
    isVideoUploading.value = false
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
      await ensureActiveWorldcupSet()
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

    await ensureActiveWorldcupSet()
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

async function toggleGalleryVisibility(galleryPhoto) {
  if (!hasSupabaseConfig) {
    uploadError.value = 'Supabase 환경 변수가 없어 갤러리 표시 여부를 수정할 수 없습니다.'
    return
  }

  uploadError.value = ''
  uploadSuccess.value = ''
  galleryVisibilityUpdatingId.value = galleryPhoto.id

  try {
    const nextValue = !galleryPhoto.show_in_gallery
    const { error: updateError } = await supabase
      .from('eunseo_gallery_photos')
      .update({ show_in_gallery: nextValue })
      .eq('id', galleryPhoto.id)

    if (updateError) throw updateError

    galleryPhotos.value = galleryPhotos.value.map((photo) =>
      photo.id === galleryPhoto.id ? { ...photo, show_in_gallery: nextValue } : photo,
    )
    uploadSuccess.value = nextValue ? '사용자 갤러리에 표시합니다.' : '사용자 갤러리에서 숨겼습니다.'
  } catch (err) {
    uploadError.value = err.message ?? '갤러리 표시 여부 수정 중 오류가 발생했습니다.'
  } finally {
    galleryVisibilityUpdatingId.value = ''
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

    await ensureActiveWorldcupSet()

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
    const { error: resetDataError } = await supabase.rpc('reset_eunseo_data')
    if (resetDataError) throw resetDataError

    votes.value = []
    notes.value = []
    resetSuccess.value = '참여 결과가 초기화되었습니다.'
    isResetModalOpen.value = false
    resetConfirmText.value = ''
    await loadAdminData()
  } catch (err) {
    resetError.value = err.message ?? '데이터 초기화 중 오류가 발생했습니다.'
  } finally {
    isResetting.value = false
  }
}

onMounted(() => {
  unlockAdminFromCookie()
  if (isAdminUnlocked.value) loadAdminData()
})
</script>

<template>
  <PageShell>
    <section v-if="!isAdminUnlocked" class="admin-auth-panel" aria-labelledby="admin-auth-title">
      <LockKeyhole :size="34" />
      <p class="eyebrow">PRIVATE DASHBOARD</p>
      <h1 id="admin-auth-title">Admin</h1>
      <p>관리자 화면에 접근하려면 비밀번호를 입력해주세요.</p>
      <form class="admin-auth-form" @submit.prevent="submitAdminPassword">
        <label class="field">
          비밀번호
          <input v-model="adminPassword" type="password" inputmode="numeric" autocomplete="current-password" autofocus />
        </label>
        <button class="primary-action" type="submit">입장</button>
      </form>
      <p v-if="adminAuthError" class="error-message">{{ adminAuthError }}</p>
    </section>

    <template v-else>
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
          <span>{{ worldcupCountText }} · {{ worldcupSetText }}</span>
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
          <h2>메인 배경 영상 업로드</h2>
          <span>홈 첫 화면에 자동 반복 재생됩니다</span>
        </div>
        <form class="upload-form home-video-upload-form" @submit.prevent="uploadHomeVideo">
          <label class="field">
            {{ homeVideoFileText }}
            <input ref="homeVideoFileInput" type="file" accept="video/*" @change="onHomeVideoFileChange" />
          </label>
          <button class="primary-action" type="submit" :disabled="isVideoUploading">
            <Video :size="18" />
            {{ isVideoUploading ? '업로드 중' : '영상 적용' }}
          </button>
        </form>
        <video v-if="homeVideo?.video_url" class="admin-video-preview" :src="homeVideo.video_url" controls muted playsinline></video>
        <p v-if="videoError" class="error-message">{{ videoError }}</p>
        <p v-if="videoSuccess" class="success-message">{{ videoSuccess }}</p>
      </div>

      <div class="admin-panel wide">
        <div class="panel-title-row">
          <h2>홈 갤러리 이미지 업로드</h2>
          <div class="panel-title-actions">
            <span>사용자 갤러리 {{ visibleGalleryCount }}장 표시 · 월드컵은 선택한 16장만 사용</span>
            <button
              class="primary-action compact-action"
              type="button"
              :disabled="isDownloadingGallery || !galleryPhotos.length"
              @click="downloadAllGalleryPhotos"
            >
              <Download :size="17" />
              {{ isDownloadingGallery ? '다운로드 중' : '전체 다운로드' }}
            </button>
          </div>
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
            <label class="gallery-visible-toggle">
              <input
                type="checkbox"
                :checked="Boolean(photo.show_in_gallery)"
                :disabled="galleryVisibilityUpdatingId === photo.id"
                @change="toggleGalleryVisibility(photo)"
              />
              <span>{{ photo.show_in_gallery ? '갤러리 표시 중' : '갤러리 숨김' }}</span>
            </label>
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
          <p>사진은 보존하고 돌잡이 투표, 포토월드컵 결과, 롤링페이퍼 메모만 삭제합니다.</p>
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
          삭제하면 돌잡이 참여 내역, 포토월드컵 승리 기록, 롤링페이퍼 메모를 복구할 수 없습니다. 업로드한 사진은 유지됩니다.
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
    </template>
  </PageShell>
</template>
