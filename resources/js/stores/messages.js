import { defineStore } from 'pinia'
import { computed, ref } from 'vue'

import { useApi } from '@/composables/useApi'
import { notificationLink, notificationText } from '@/composables/useNotifications'
import { onRealtimeReconnect, refetchSoon, useChannel, usePolling, userChannel } from '@/composables/useRealtime'
import { useAuthStore } from '@/stores/auth'
import { useClanStore } from '@/stores/clan'
import { useToastStore } from '@/stores/toast'

// what the player has not read: his private messages and his notifications, shown by the mail of the Kalendrier. Sent
// by the server as they change (App\Events\MessageReceived, NotificationReceived, UnreadCountsChanged); polled every
// minute only without the realtime
export const useMessagesStore = defineStore('messages', () => {
  const unread = ref(0)
  const notificationsUnread = ref(0)
  const total = computed(() => unread.value + notificationsUnread.value)
  let watching = false

  const authStore = useAuthStore()
  const toastStore = useToastStore()
  const { get } = useApi()

  const setCounts = (counts) => {
    if (counts) {
      unread.value = counts.messages
      notificationsUnread.value = counts.notifications
    }
  }

  const reload = () => {
    if (!authStore.isAuthenticated) {
      return Promise.resolve()
    }
    return get('/notifications/unread').then((response) => setCounts(response.data.data)).catch(() => {})
  }

  useChannel(() => userChannel(authStore.user?.id), {
    'message.received': (e) => {
      setCounts(e.unread)
      toastStore.show({
        title: 'Nouveau message',
        text: `${e.message.sender?.display_name ?? 'KadoKadéo'} : ${e.message.subject}`,
        icon: '/assets/img/gfx/icons/newMail.gif',
        to: { name: 'messages.show', params: { id: e.message.id } },
      })
    },
    'notification.received': (e) => {
      setCounts(e.unread)
      toastStore.show({ title: 'Notification', text: notificationText(e.notification), to: notificationLink(e.notification) ?? { name: 'messages.notifications' } })
      // his application answered: the menus show his clan, or no longer his application
      if (e.notification.type === 'clan_accepted' || e.notification.type === 'clan_refused') {
        useClanStore().reload()
      }
    },
    unread: (e) => setCounts(e.unread),
  })
  // a message of the site to everyone: not all the players at the same moment
  useChannel('site', { 'messages.refresh': refetchSoon(reload, { delay: 0, jitter: 10000 }) }, { isPrivate: false })
  onRealtimeReconnect(reload)
  usePolling(() => watching && reload(), 60000, { channel: () => userChannel(authStore.user?.id) })

  const watchUnread = () => {
    if (!watching) {
      watching = true
      reload()
    }
  }

  return {
    unread,
    notificationsUnread,
    total,
    reload,
    setCounts,
    watchUnread,
  }
})
