import { createRouter, createWebHistory } from 'vue-router'
import HomeView from './views/HomeView.vue'
import DoljabiView from './views/DoljabiView.vue'
import PhotoWorldCupView from './views/PhotoWorldCupView.vue'
import RollingPaperView from './views/RollingPaperView.vue'
import AdminView from './views/AdminView.vue'

const routes = [
  { path: '/', name: 'home', component: HomeView },
  { path: '/doljabi', name: 'doljabi', component: DoljabiView },
  { path: '/photo-worldcup', name: 'photo-worldcup', component: PhotoWorldCupView },
  { path: '/rolling-paper', name: 'rolling-paper', component: RollingPaperView },
  { path: '/admin', name: 'admin', component: AdminView },
]

export default createRouter({
  history: createWebHistory(),
  routes,
})
