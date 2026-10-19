import './middlewares'

import { createVueRouterMiddleware } from '@yazida/vue-router-middleware'
import { nextTick } from 'vue'
import { createRouter, createWebHistory } from 'vue-router'

import Account from '@/pages/account.vue'
import BestsScores from '@/pages/bestsScores.vue'
import ClansDebug from '@/pages/clans/debug.vue'
import ClansForumIndex from '@/pages/clans/forum/index.vue'
import ClansForumNew from '@/pages/clans/forum/new.vue'
import ClansForumTopic from '@/pages/clans/forum/topic.vue'
import ClansIndex from '@/pages/clans/index.vue'
import ClansPlay from '@/pages/clans/play.vue'
import ClansShow from '@/pages/clans/show.vue'
import Competition from '@/pages/competition/index.vue'
import ForumIndex from '@/pages/forum/index.vue'
import ForumSection from '@/pages/forum/section.vue'
import ForumThread from '@/pages/forum/thread.vue'
import GamesDaily from '@/pages/games/daily.vue'
import GamesIndex from '@/pages/games/index.vue'
import GamesRanking from '@/pages/games/ranking.vue'
import GamesRecords from '@/pages/games/records.vue'
import GamesShow from '@/pages/games/show.vue'
import Help from '@/pages/help.vue'
import Login from '@/pages/login.vue'
import LoginCallback from '@/pages/loginCallback.vue'
import MessagesIndex from '@/pages/messages/index.vue'
import MessagesShow from '@/pages/messages/show.vue'
import ProfileShow from '@/pages/profile/show.vue'
import RunsShow from '@/pages/runs/show.vue'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', redirect: '/games', meta: {} },
    { path: '/login', name: 'login', component: Login, meta: {} },
    // the forum of Eternaltwin (its category of the site)
    { path: '/forum', name: 'forum.index', component: ForumIndex, meta: { middleware: ['auth'], title: 'Forum - KadoKadéo' } },
    { path: '/forum/sections/:section', name: 'forum.section', component: ForumSection, meta: { middleware: ['auth'], title: 'Forum - KadoKadéo' } },
    { path: '/forum/threads/:thread', name: 'forum.thread', component: ForumThread, meta: { middleware: ['auth'], title: 'Forum - KadoKadéo' } },
    { path: '/oauth/callback', component: LoginCallback, meta: {} },
    { path: '/help', name: 'help', component: Help, meta: { middleware: ['auth'] } },
    { path: '/daily', name: 'games.daily', component: GamesDaily, meta: { middleware: ['auth'] } },
    { path: '/games', name: 'games.index', component: GamesIndex, meta: { middleware: ['auth'] } },
    { path: '/competition', name: 'competition.index', component: Competition, meta: { middleware: ['auth'] } },
    { path: '/site-records', name: 'site-records', component: BestsScores, meta: { middleware: ['auth'] } },
    { path: '/profile', name: 'profile.index', component: ProfileShow, meta: { middleware: ['auth'] } },
    { path: '/profile/:id', name: 'profile.show', component: ProfileShow, meta: { middleware: ['auth'] } },
    { path: '/games/:id', name: 'games.show', component: GamesShow, meta: { middleware: ['auth'] } },
    { path: '/games/:id/ranking', name: 'games.ranking', component: GamesRanking, meta: { middleware: ['auth'] } },
    { path: '/games/:id/records', name: 'games.records', component: GamesRecords, meta: { middleware: ['auth'] } },
    { path: '/runs/:id', name: 'runs.show', component: RunsShow, meta: { middleware: ['auth'] } },
    { path: '/messages', name: 'messages.inbox', component: MessagesIndex, meta: { middleware: ['auth'], box: 'inbox', title: 'Messages - KadoKadéo' } },
    { path: '/messages/sent', name: 'messages.sent', component: MessagesIndex, meta: { middleware: ['auth'], box: 'sent', title: 'Messages - KadoKadéo' } },
    { path: '/messages/new', name: 'messages.new', component: MessagesIndex, meta: { middleware: ['auth'], box: 'new', title: 'Messages - KadoKadéo' } },
    { path: '/messages/:id(\\d+)', name: 'messages.show', component: MessagesShow, meta: { middleware: ['auth'], title: 'Messages - KadoKadéo' } },
    { path: '/account', name: 'account', component: Account, meta: { middleware: ['auth'], title: 'Mon compte - KadoKadéo' } },
    { path: '/clans', name: 'clans.index', component: ClansIndex, meta: { middleware: ['auth', 'clans'], title: 'Clans - KadoKadéo' } },
    { path: '/clans/debug', name: 'clans.debug', component: ClansDebug, meta: { middleware: ['auth', 'clans'], title: 'Debug clans - KadoKadéo' } },
    { path: '/clans/play/:action', name: 'clans.play', component: ClansPlay, meta: { middleware: ['auth', 'clans'] } },
    { path: '/clans/:id', name: 'clans.show', component: ClansShow, meta: { middleware: ['auth', 'clans'], tab: 'show' } },
    { path: '/clans/:id/status', name: 'clans.status', component: ClansShow, meta: { middleware: ['auth', 'clans'], tab: 'status' } },
    { path: '/clans/:id/missions', name: 'clans.missions', component: ClansShow, meta: { middleware: ['auth', 'clans'], tab: 'missions' } },
    { path: '/clans/:id/members', name: 'clans.members', component: ClansShow, meta: { middleware: ['auth', 'clans'], tab: 'members' } },
    { path: '/clans/:id/manage', name: 'clans.manage', component: ClansShow, meta: { middleware: ['auth', 'clans'], tab: 'manage' } },
    { path: '/clans/:id/history', name: 'clans.history', component: ClansShow, meta: { middleware: ['auth', 'clans'], tab: 'history' } },
    { path: '/clans/:id/games', name: 'clans.games', component: ClansShow, meta: { middleware: ['auth', 'clans'], tab: 'games' } },
    { path: '/clans/:id/attack', name: 'clans.attack', component: ClansShow, meta: { middleware: ['auth', 'clans'], tab: 'attack' } },
    // the private forum of the clan
    { path: '/clans/:id/forum', name: 'clans.forum', component: ClansForumIndex, meta: { middleware: ['auth', 'clans'], title: 'Forum du clan - KadoKadéo' } },
    { path: '/clans/:id/forum/new', name: 'clans.forum.new', component: ClansForumNew, meta: { middleware: ['auth', 'clans'], title: 'Nouveau sujet - KadoKadéo' } },
    { path: '/clans/:id/forum/:topic(\\d+)', name: 'clans.forum.topic', component: ClansForumTopic, meta: { middleware: ['auth', 'clans'], title: 'Forum du clan - KadoKadéo' } },
  ],
})

router.afterEach((to) => {
  nextTick(() => {
    document.title = to.meta.title || 'KadoKadéo'
  })
})

createVueRouterMiddleware(router)

export default router
