import { registerMiddleware } from '@yazida/vue-router-middleware'

import { useAuthStore } from '@/stores/auth'
import { useClanStore } from '@/stores/clan'

// the pages of a logged in player: the server says who is logged in (the session cookie, that no script reads)
registerMiddleware('auth', ({ next }) => {
  const authStore = useAuthStore()

  if (!authStore.isAuthenticated) {
    authStore.fetchUser().then(() => {
      next()
    }).catch((e) => {
      if (e.response?.status === 401 || e.response?.data?.banned) {
        return next('/login')
      }
      next()
    })
  } else {
    next()
  }
})

// the pages of the clans, closed while the clans are turned off in the admin
registerMiddleware('clans', ({ next }) => {
  if (!useClanStore().enabled) {
    return next({ name: 'games.index' })
  }
  next()
})
