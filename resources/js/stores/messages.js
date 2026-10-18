import { defineStore } from 'pinia'
import { ref } from 'vue'

import { useApi } from '@/composables/useApi'

// the unread private messages, shown by the mail of the Kalendrier (checked every minute)
export const useMessagesStore = defineStore('messages', () => {
  const unread = ref(0)
  let intervalId = null

  const { get } = useApi()

  const reload = () =>
    get('/messages/unread').then((response) => {
      unread.value = response.data.data.unread
    }).catch(() => {})

  const watchUnread = () => {
    reload()
    if (!intervalId) {
      intervalId = setInterval(reload, 60000)
    }
  }

  return {
    unread,
    reload,
    watchUnread,
  }
})
