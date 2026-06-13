<script setup>
import { ref, watch } from 'vue'
import { Menu, X } from '@lucide/vue'
import { useRoute } from 'vue-router'

const route = useRoute()
const isMenuOpen = ref(false)

watch(
  () => route.fullPath,
  () => {
    isMenuOpen.value = false
  },
)
</script>

<template>
  <main class="page-shell">
    <div class="page-ornament page-ornament-left" aria-hidden="true"></div>
    <div class="page-ornament page-ornament-right" aria-hidden="true"></div>
    <nav class="top-nav" aria-label="주요 메뉴">
      <RouterLink class="brand" to="/">
        <span>EUNSEO</span>
        <strong>1st Birthday</strong>
      </RouterLink>
      <button
        class="mobile-menu-button"
        type="button"
        :aria-expanded="isMenuOpen"
        aria-controls="primary-menu"
        aria-label="메뉴 열기"
        @click="isMenuOpen = !isMenuOpen"
      >
        <X v-if="isMenuOpen" :size="20" />
        <Menu v-else :size="20" />
      </button>
      <div id="primary-menu" class="nav-links" :class="{ open: isMenuOpen }">
        <RouterLink to="/menu">식사메뉴</RouterLink>
        <RouterLink to="/photo-worldcup">포토월드컵</RouterLink>
        <RouterLink to="/rolling-paper">롤링페이퍼</RouterLink>
        <RouterLink to="/admin">Admin</RouterLink>
      </div>
    </nav>
    <slot />
  </main>
</template>
