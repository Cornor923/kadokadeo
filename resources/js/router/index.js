import './middlewares'

import { createVueRouterMiddleware } from '@yazida/vue-router-middleware'
import { nextTick } from 'vue'
import { createRouter, createWebHistory } from 'vue-router'

import BestsScores from '@/pages/bestsScores.vue'
import Competition from '@/pages/competition/index.vue'
import GamesDaily from '@/pages/games/daily.vue'
import GamesIndex from '@/pages/games/index.vue'
import GamesRanking from '@/pages/games/ranking.vue'
import GamesRecords from '@/pages/games/records.vue'
import GamesShow from '@/pages/games/show.vue'
import Help from '@/pages/help.vue'
import Login from '@/pages/login.vue'
import LoginCallback from '@/pages/loginCallback.vue'
import ProfileShow from '@/pages/profile/show.vue'
import RunsShow from '@/pages/runs/show.vue'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', redirect: '/games', meta: {} },
    { path: '/login', name: 'login', component: Login, meta: {} },
    { path: '/oauth/callback', component: LoginCallback, meta: {} },
    { path: '/help', name: 'help', component: Help, meta: { middleware: ['auth'] } },
    { path: '/daily', name: 'games.daily', component: GamesDaily, meta: { middleware: ['auth'] } },
    { path: '/games', name: 'games.index', component: GamesIndex, meta: { middleware: ['auth'] } },
    { path: '/competition', name: 'competition.index', component: Competition, meta: { middleware: ['auth'] } },
    { path: '/site-records', name: 'site-records', component: BestsScores, meta: { middleware: ['auth'] } },
    { path: '/profile', name: 'profile.index', component: ProfileShow, meta: { middleware: ['auth'] } },
    { path: '/profile/:id', name: 'profile.show', component: ProfileShow, meta: { middleware: ['auth'] } },
    {
      path: '/games/:id',
      name: 'games.show',
      component: GamesShow,
      meta: { middleware: ['auth'] },
    },
    {
      path: '/games/:id/ranking',
      name: 'games.ranking',
      component: GamesRanking,
      meta: { middleware: ['auth'] },
    },
    {
      path: '/games/:id/records',
      name: 'games.records',
      component: GamesRecords,
      meta: { middleware: ['auth'] },
    },
    { path: '/runs/:id', name: 'runs.show', component: RunsShow, meta: { middleware: ['auth'] } },
  ],
})

router.afterEach((to) => {
  nextTick(() => {
    document.title = to.meta.title || 'KadoKadéo'
  })
})

createVueRouterMiddleware(router)

export default router