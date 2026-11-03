import { defineStore } from 'pinia'
import { computed, reactive, ref } from 'vue'

import { client } from '@/composables/useApi'
import { onRealtimeReconnect, refetchSoon, useChannel, userChannel } from '@/composables/useRealtime'

export const useAuthStore = defineStore('auth', () => {
  const user = ref(null)
  const achievementProgress = ref([])
  const stars = reactive({
    green: 0,
    orange: 0,
    red: 0,
    purple: 0,
  })
  const greenStars = computed(() => stars.green - stars.orange)
  const orangeStars = computed(() => stars.orange - stars.red)
  const redStars = computed(() => stars.red - stars.purple)
  const purpleStars = computed(() => stars.purple)

  // reason of the ban, shown on the login page (App.vue redirects there when it is set)
  const banMessage = ref(null)

  const isAuthenticated = computed(() => !!user.value)

  // a banned user is logged out on their next request (App\Http\Middleware\EnsureUserIsNotBanned); a player whose
  // session ended (logged out in another tab, expired) goes back to the login page
  client.interceptors.response.use(null, (e) => {
    if (e.response?.status === 403 && e.response.data?.banned) {
      setUser(null)
      banMessage.value = e.response.data.message
    } else if (e.response?.status === 401 && user.value) {
      setUser(null)
      window.location.assign('/login')
    }
    return Promise.reject(e)
  })

  window.evts.addEventListener('gameFinished', (e) => {
    const endRunDetails = e.detail
    if (endRunDetails.current_star >= 0 && endRunDetails.previous_star < endRunDetails.current_star) {
      if (endRunDetails.current_star >= 0 && endRunDetails.previous_star < 0) {
        stars.green += 1
      }
      if (endRunDetails.current_star >= 1 && endRunDetails.previous_star < 1) {
        stars.orange += 1
      }
      if (endRunDetails.current_star >= 2 && endRunDetails.previous_star < 2) {
        stars.red += 1
      }
      if (endRunDetails.current_star >= 3 && endRunDetails.previous_star < 3) {
        stars.purple += 1
      }
    }
    const p = achievementProgress.value
    console.log('currentProgress:', p)
    console.log('achievement_updates:', endRunDetails.achievement_updates)
    for (let au of endRunDetails?.achievement_updates ?? []) {
      const pr = p.find((ap) => ap.achievement_id === au.id)
      if (pr) {
        pr.current_value = au.progress
        pr.completed_level = au.completed_level
      } else {
        p.push({
          achievement_id: au.id,
          current_value: au.progress,
          completed_level: au.completed_level,
          completed_at: dayjs().format('YYYY-MM-DD HH:mm:ss'),
        })
      }
      if (au.type === 'unlocked') {
        const achievementStore = useAchievementStore()
        achievementStore.addUnlockedAchievement(au)
      }
    }
    achievementProgress.value = [...p]
  })

  const setUser = (u) => {
    user.value = u
    if (!u) {
      return
    }
    if (u.stars) {
      stars.green = u.stars.green_stars
      stars.orange = u.stars.orange_stars
      stars.red = u.stars.red_stars
      stars.purple = u.stars.purple_stars
    } else {
      stars.green = 0
      stars.orange = 0
      stars.red = 0
      stars.purple = 0
    }
    if (u.achievement_progress) {
      achievementProgress.value = u.achievement_progress
    } else {
      achievementProgress.value = []
    }
  }

  const fetchUser = async() => {
    const { data } = await client.get('/user')
    setUser(data.data)
  }

  // the end of the login on Eternaltwin: the server opens the session (its cookies) and gives the player
  const login = async(code, state) => {
    const res = await client.get('/oauth/callback', { params: { code, state } })
    banMessage.value = null
    setUser(res.data.user)
  }

  // (the player is forgotten even when the server could not be reached)
  const logout = async() => {
    try {
      await client.post('/logout')
    } finally {
      setUser(null)
    }
  }

  // his Kado points and games (App\Events\UserCountersChanged), read again when his stars or the period changed
  // (App\Events\UserRefresh, PeriodStarted: on the channel of the site, not all the players at once)
  const refreshSoon = refetchSoon(() => user.value && fetchUser().catch(() => {}), { delay: 0, jitter: 10000 })
  useChannel(() => userChannel(user.value?.id), {
    'user.counters': (counters) => {
      if (user.value) {
        Object.assign(user.value, counters)
      }
    },
    'user.refresh': refetchSoon(() => fetchUser().catch(() => {}), { delay: 500 }),
  })
  useChannel('site', { 'user.refresh': refreshSoon, 'period.started': refreshSoon }, { isPrivate: false })
  onRealtimeReconnect(() => user.value && fetchUser().catch(() => {}))

  return {
    user,
    banMessage,
    isAuthenticated,
    fetchUser,
    login,
    logout,
    setUser,
    stars,
    greenStars,
    orangeStars,
    redStars,
    purpleStars,
    achievementProgress,
  }
})
