<script setup>
import { notificationLink, notificationText } from '@/composables/useNotifications'
import { useChannel, userChannel } from '@/composables/useRealtime'

// the notifications of the player (the tab « Notifications » of the messages): read when the tab is opened (the new ones
// stay highlighted while it is open), deleted one by one or all
const authStore = useAuthStore()
const messagesStore = useMessagesStore()
const actions = useNotificationActions()
// the ids of the ones not read when they were shown
const fresh = ref(new Set())

const markRead = () => actions.markRead().then((counts) => messagesStore.setCounts(counts)).catch(() => {})

const { items: notifications, meta, hasNextPage, loadMore, isLoading, error } = useNotificationList({
  onPage: (data) => {
    data.data.filter((n) => !n.read).forEach((n) => fresh.value.add(n.id))
    messagesStore.setCounts(data.unread)
    if (data.data.some((n) => !n.read)) {
      markRead()
    }
  },
})

// a new one (or the likes of a comment again): on top, read since the tab is open
useChannel(() => userChannel(authStore.user?.id), {
  'notification.received': (e) => {
    fresh.value.add(e.notification.id)
    notifications.value = [e.notification, ...notifications.value.filter((n) => n.id !== e.notification.id)]
    markRead()
  },
})

const remove = (notification) =>
  actions.remove(notification.id).then(() => {
    notifications.value = notifications.value.filter((n) => n.id !== notification.id)
  })
const removeAll = () => {
  if (confirm('Supprimer toutes vos notifications ?')) {
    actions.removeAll().then(() => {
      notifications.value = []
      meta.value = null
    })
  }
}

const date = (iso) => new Date(iso).toLocaleString('fr-FR', { day: '2-digit', month: '2-digit', year: '2-digit', hour: '2-digit', minute: '2-digit' })
</script>

<template>
  <MessageError v-if="error">{{ error }}</MessageError>
  <div class="relative overflow-x-auto">
    <Loader v-if="isLoading && !notifications.length" />
    <table class="w-full">
      <tbody>
        <tr v-if="!notifications.length && !isLoading" class="bg-kado-blue-100">
          <td class="py-4 italic">Vous n'avez aucune notification.</td>
        </tr>
        <tr v-for="(notification, index) in notifications"
            :key="notification.id"
            :class="[index % 2 ? 'bg-white' : 'bg-kado-blue-100', { 'font-bold': fresh.has(notification.id) }]">
          <td class="text-left">
            <RouterLink v-if="notificationLink(notification)" :to="notificationLink(notification)">{{ notificationText(notification) }}</RouterLink>
            <template v-else>{{ notificationText(notification) }}</template>
            <span v-if="notification.comment?.excerpt" class="block text-xs font-normal italic text-kado-teal-500">« {{ notification.comment.excerpt }} »</span>
          </td>
          <td class="whitespace-nowrap text-xs font-normal">{{ date(notification.updated_at) }}</td>
          <td class="w-6">
            <button type="button"
                    class="cursor-pointer border-0 bg-transparent px-1 font-bold text-kado-pink-600"
                    title="Supprimer"
                    aria-label="Supprimer"
                    @click="remove(notification)">
              ×
            </button>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
  <div class="flex justify-center gap-2">
    <FormButton v-if="hasNextPage"
                size="lg"
                :disabled="isLoading"
                @click="loadMore()">Plus anciennes</FormButton>
    <FormButton v-if="notifications.length"
                variant="pink"
                size="lg"
                @click="removeAll">Tout supprimer</FormButton>
  </div>
  <p class="text-center text-xs italic">Les notifications sont supprimées automatiquement après deux mois.</p>
</template>
