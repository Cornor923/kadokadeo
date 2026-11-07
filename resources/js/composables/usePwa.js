import { computed, shallowRef } from 'vue'

const installEvent = shallowRef(null)
const installed = shallowRef(matchMedia('(display-mode: standalone)').matches || navigator.standalone === true)
// (an iPhone or an iPad has no install prompt: the player does it from the Share menu of his browser)
const needsManualInstall = /iphone|ipad|ipod/i.test(navigator.userAgent)
  || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1)

// (before the first event of the browser: called by main.js, at load)
export function registerPwa(router) {
  addEventListener('beforeinstallprompt', (event) => {
    event.preventDefault()
    installEvent.value = event
  })
  addEventListener('appinstalled', () => {
    installEvent.value = null
    installed.value = true
  })

  const { serviceWorker } = navigator
  if (!serviceWorker) {
    return
  }
  if (!import.meta.env.PROD && import.meta.env.VITE_PWA_DEV !== 'true') {
    // (no worker left by a production build, or VITE_PWA_DEV, tried on this address)
    serviceWorker.getRegistrations().then((registrations) => registrations.forEach((registration) => registration.unregister()))
    return
  }

  serviceWorker.register('/sw.js').then((registration) => {
    // an installed app stays open for days: it looks for a new build each time it comes back
    document.addEventListener('visibilitychange', () => {
      if (document.visibilityState === 'visible') {
        registration.update().catch(() => {})
      }
    })
  }).catch((error) => console.warn('Service worker:', error))

  // A new build: its pages are loaded at the next change of page (after the guards of the pages, that keep a run), never
  // during a run. (No controller yet: the first install of the worker, nothing new.)
  let controlled = Boolean(serviceWorker.controller)
  let updated = false
  serviceWorker.addEventListener('controllerchange', () => {
    updated = controlled
    controlled = true
  })
  router.beforeResolve((to, from) => {
    if (updated && to.path !== from.path) {
      location.assign(to.fullPath)
      return false
    }
  })
}

// the sheet of the system, else the link copied; a sheet closed by the player is not an error
export async function shareLink(data) {
  if (!navigator.share) {
    await navigator.clipboard.writeText(data.url)
    return 'copied'
  }
  try {
    await navigator.share(data)
  } catch(error) {
    if (error.name !== 'AbortError') {
      throw error
    }
  }
  return 'shared'
}

export function usePwa() {
  const canInstall = computed(() => !installed.value && (installEvent.value !== null || needsManualInstall))

  async function install() {
    const event = installEvent.value
    if (!event) {
      return false
    }
    await event.prompt()
    installEvent.value = null
    return true
  }

  // (an installed app on iOS has no back button; the other systems give one)
  return { canInstall, install, needsBackButton: navigator.standalone === true }
}
