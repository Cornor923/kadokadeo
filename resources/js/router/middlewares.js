import { registerMiddleware } from '@yazida/vue-router-middleware'

import { useAuthStore } from '@/stores/auth'
import { useClanStore } from '@/stores/clan'

registerMiddleware('auth', ({ next }) => {
  const authStore = useAuthStore()

  if (!authStore.token) {
    return next('/login')
  }

  if (!authStore.isAuthenticated) {
    authStore.fetchUser().then(() => {
      next()
    }).catch((e) => {
      if (e.response?.status === 401 || e.response?.data?.banned) {
        authStore.resetToken()
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
