<template>
  <main class="page-shell">
    <div class="page-ornament page-ornament-left" aria-hidden="true"></div>
    <div class="page-ornament page-ornament-right" aria-hidden="true"></div>
    <nav class="top-nav" aria-label="주요 메뉴">
      <RouterLink class="brand" to="/">
        <span>EUNSEO</span>
        <strong>1st Birthday</strong>
      </RouterLink>
      <div class="nav-links">
        <RouterLink to="/doljabi">돌잡이 로또</RouterLink>
        <RouterLink to="/photo-worldcup">포토월드컵</RouterLink>
        <RouterLink to="/rolling-paper">롤링페이퍼</RouterLink>
        <RouterLink to="/admin">Admin</RouterLink>
      </div>
    </nav>
    <slot />
  </main>
</template>
