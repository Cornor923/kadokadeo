import { defineStore } from 'pinia'
import { ref } from 'vue'

const DURATION = 6000
const MAX = 4

// the short messages of the realtime at the top right (under the Kalendrier on a computer) (a message received, a notification, the feats of the clan): a few
// seconds, a click opens what they are about (the achievements have their banners at the bottom right). While a live run
// is played ("runPlaying" of the game) they wait for its end ("gameFinished"), not to distract the player
export const useToastStore = defineStore('toast', () => {
  const toasts = ref([])
  let nextId = 0
  let held = false
  let waiting = []

  const dismiss = (id) => {
    toasts.value = toasts.value.filter((toast) => toast.id !== id)
  }

  const display = (toast) => {
    const id = ++nextId
    toasts.value = [...toasts.value, { ...toast, id }].slice(-MAX)
    setTimeout(() => dismiss(id), DURATION)
  }

  // { title, text, to (a route), icon }
  const show = (toast) => {
    if (held) {
      waiting = [...waiting, toast].slice(-MAX)
      return
    }
    display(toast)
  }

  // the toasts kept during the run, at once
  const release = () => {
    held = false
    const kept = waiting
    waiting = []
    kept.forEach(display)
  }

  window.evts?.addEventListener('runPlaying', (e) => {
    if (e.detail?.playing) {
      held = true
    } else if (held) {
      // (no score sent: the run changed, the sending failed)
      release()
    }
  })
  window.evts?.addEventListener('gameFinished', release)
  window.evts?.addEventListener('gameCrash', release)

  return {
    toasts,
    show,
    dismiss,
    release,
  }
})
