<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from "vue";
import { Camera, Images, ScrollText, Utensils, X } from "@lucide/vue";
import PageShell from "../components/PageShell.vue";
import { hasSupabaseConfig, supabase } from "../lib/supabase";

const primaryMenus = [
  {
    title: "오늘의 식사 메뉴",
    description: "Western Set 03 코스 구성을 모바일에서 편하게 확인하세요.",
    to: "/menu",
    label: "식사메뉴",
    icon: Utensils,
  },
  {
    title: "은서 사진 월드컵",
    description:
      "마음에 드는 은서 사진을 골라 오늘의 베스트 사진을 뽑아주세요.",
    to: "/photo-worldcup",
    label: "월드컵 시작",
    icon: Camera,
  },
];

const secondaryMenus = [
  {
    title: "은서에게 한마디",
    to: "/rolling-paper",
    icon: ScrollText,
  },
  {
    title: "사진 갤러리",
    to: { path: "/", hash: "#gallery" },
    icon: Images,
  },
];

const galleryPhotos = ref([]);
const galleryError = ref("");
const selectedPhoto = ref(null);
const homeVideoUrl = ref("");

const framedGalleryPhotos = computed(() =>
  galleryPhotos.value.map((photo, index) => ({
    ...photo,
    rotation: `${[-5, 3, -2, 5, -4, 2][index % 6]}deg`,
    offset: `${[10, 0, 18, 4, 14, 2][index % 6]}px`,
  })),
);

async function loadGalleryPhotos() {
  if (!hasSupabaseConfig) return;

  try {
    const { data, error } = await supabase
      .from("eunseo_gallery_photos")
      .select("id,title,image_url,created_at")
      .eq("show_in_gallery", true)
      .order("created_at", { ascending: false })
      .limit(24);

    if (error) throw error;
    galleryPhotos.value = data ?? [];

    const { data: videoData } = await supabase
      .from("eunseo_home_video")
      .select("video_url")
      .eq("id", true)
      .maybeSingle();
    homeVideoUrl.value = videoData?.video_url ?? "";
  } catch (err) {
    galleryError.value = err.message ?? "갤러리 사진을 불러오지 못했습니다.";
  }
}

function openPhoto(photo) {
  selectedPhoto.value = photo;
}

function closePhoto() {
  selectedPhoto.value = null;
}

function handleKeydown(event) {
  if (event.key === "Escape") closePhoto();
}

onMounted(() => {
  loadGalleryPhotos();
  window.addEventListener("keydown", handleKeydown);
});

onBeforeUnmount(() => {
  window.removeEventListener("keydown", handleKeydown);
});
</script>

<template>
  <PageShell>
    <video
      v-if="homeVideoUrl"
      class="home-background-video"
      :src="homeVideoUrl"
      autoplay
      muted
      loop
      playsinline
      aria-hidden="true"
    ></video>
    <div
      v-if="homeVideoUrl"
      class="home-background-scrim"
      aria-hidden="true"
    ></div>

    <section class="home-hero">
      <div class="hero-copy">
        <p class="eyebrow">INVITATION</p>
        <h1>은서의 첫 생일</h1>
        <p>오늘의 식사 메뉴와 은서 사진 월드컵을 먼저 만나보세요.</p>
      </div>
    </section>

    <section class="home-primary-actions" aria-label="주요 메뉴">
      <RouterLink
        v-for="menu in primaryMenus"
        :key="menu.to"
        class="primary-menu-card"
        :to="menu.to"
      >
        <component :is="menu.icon" :size="30" stroke-width="1.8" />
        <div>
          <small>EUNSEO PARTY</small>
          <h2>{{ menu.title }}</h2>
          <p>{{ menu.description }}</p>
        </div>
        <span>{{ menu.label }}</span>
      </RouterLink>
    </section>

    <section class="home-secondary-actions" aria-label="보조 메뉴">
      <RouterLink
        v-for="menu in secondaryMenus"
        :key="menu.title"
        class="secondary-menu-link"
        :to="menu.to"
      >
        <component :is="menu.icon" :size="20" stroke-width="1.9" />
        <span>{{ menu.title }}</span>
      </RouterLink>
    </section>

    <section
      id="gallery"
      v-if="framedGalleryPhotos.length || galleryError"
      class="home-gallery"
      aria-label="은서 갤러리"
    >
      <div class="gallery-heading">
        <p class="eyebrow">EUNSEO GALLERY</p>
        <h2>은서의 순간들</h2>
      </div>
      <p v-if="galleryError" class="error-message">{{ galleryError }}</p>
      <div v-else class="polaroid-grid">
        <button
          v-for="photo in framedGalleryPhotos"
          :key="photo.id"
          type="button"
          class="polaroid-card"
          :style="{ '--rotation': photo.rotation, '--offset': photo.offset }"
          :aria-label="`${photo.title} 사진 크게 보기`"
          @click="openPhoto(photo)"
        >
          <img :src="photo.image_url" :alt="photo.title" loading="lazy" />
          <strong>{{ photo.title }}</strong>
        </button>
      </div>
    </section>

    <Teleport to="body">
      <div
        v-if="selectedPhoto"
        class="photo-lightbox"
        role="dialog"
        aria-modal="true"
        :aria-label="`${selectedPhoto.title} 사진 전체화면 보기`"
        @click="closePhoto"
      >
        <button
          type="button"
          class="lightbox-close"
          aria-label="닫기"
          @click.stop="closePhoto"
        >
          <X :size="24" stroke-width="1.9" />
        </button>
        <figure class="lightbox-frame" @click.stop>
          <img :src="selectedPhoto.image_url" :alt="selectedPhoto.title" />
          <figcaption>{{ selectedPhoto.title }}</figcaption>
        </figure>
      </div>
    </Teleport>
  </PageShell>
</template>
