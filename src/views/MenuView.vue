<script setup>
import { Coffee, Cookie, Fish, Salad, Soup, Utensils } from "@lucide/vue";
import PageShell from "../components/PageShell.vue";

const courses = [
  {
    title: "Welcome Bread",
    description: "제공되는 브레드 종류는 시즌마다 다를 수 있습니다.",
    icon: Cookie,
  },
  {
    title: "Appetizer",
    description: "참치 연어 타르타르 / 아보카도 감태 캐비어 한련화",
    icon: Fish,
  },
  {
    title: "Soup",
    description: "아메리칸 비스큐 스프",
    icon: Soup,
  },
  {
    title: "Salad",
    description: "판자넬라",
    icon: Salad,
  },
  {
    title: "Main",
    description: "안심 스테이크와 랍스타 테일 페퍼 소스",
    icon: Utensils,
  },
  {
    title: "Dessert",
    description: "레몬 타르트 & 커피",
    icon: Coffee,
  },
];
</script>

<template>
  <PageShell>
    <section class="content-header dining-header">
      <p class="eyebrow">DINING MENU</p>
    </section>

    <section class="dining-menu-panel" aria-label="Western Set 03 메뉴">
      <div class="course-list">
        <article
          v-for="course in courses"
          :key="course.title"
          class="course-card"
        >
          <span class="course-icon" aria-hidden="true">
            <component :is="course.icon" :size="22" stroke-width="1.9" />
          </span>
          <div>
            <h2>{{ course.title }}</h2>
            <p>{{ course.description }}</p>
          </div>
        </article>
      </div>
    </section>
  </PageShell>
</template>
