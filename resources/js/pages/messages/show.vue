<script setup>
// a private message: read (marked as read), answer, delete
const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const messagesStore = useMessagesStore()
const { fetchMessage, deleteMessage, isLoading, error } = useMessages()

const message = ref(null)
watch(() => route.params.id, (id) => {
  fetchMessage(id).then((data) => {
    // (another message asked meanwhile: this one is not shown)
    if (id === route.params.id) {
      message.value = data
      messagesStore.reload()
    }
  }).catch(() => {}) // (shown by error)
}, { immediate: true })

const received = computed(() => message.value?.recipient.etwin_id === authStore.user?.etwin_id)
const answer = () => router.push({
  name: 'messages.new',
  query: {
    to: message.value.sender.display_name,
    subject: message.value.subject.startsWith('Re : ') ? message.value.subject : `Re : ${message.value.subject}`,
  },
})
const remove = () => {
  if (confirm('Supprimer ce message ?')) {
    deleteMessage(message.value.id).then(() => router.push({ name: received.value ? 'messages.inbox' : 'messages.sent' }))
  }
}
const date = (iso) => new Date(iso).toLocaleString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit' })
</script>

<template>
  <NavTabs
    :items="[
      { label: 'Reçus', value: 'inbox', route: { name: 'messages.inbox' } },
      { label: 'Envoyés', value: 'sent', route: { name: 'messages.sent' } },
      { label: 'Écrire', value: 'new', route: { name: 'messages.new' } },
      { label: messagesStore.notificationsUnread ? `Notifications (${messagesStore.notificationsUnread})` : 'Notifications', value: 'notifications', route: { name: 'messages.notifications' } },
    ]"
    :selected-index="received ? 0 : 1"
  />

  <div class="relative px-2 space-y-4 min-h-48">
    <Loader v-if="isLoading && !message" />
    <MessageError v-if="error">{{ error }}</MessageError>

    <template v-if="message">
      <KadoSectionTitle>{{ message.subject }}</KadoSectionTitle>
      <p class="text-sm">
        <template v-if="received">
          De
          <RouterLink v-if="message.sender" :to="{ name: 'profile.show', params: { id: message.sender.etwin_id } }" class="font-bold">{{ message.sender.display_name }}</RouterLink>
          <strong v-else class="text-kado-orange-500">KadoKado</strong>,
        </template>
        <template v-else>
          À <RouterLink :to="{ name: 'profile.show', params: { id: message.recipient.etwin_id } }" class="font-bold">{{ message.recipient.display_name }}</RouterLink>,
        </template>
        le {{ date(message.created_at) }}
      </p>
      <MarktwinContent :text="message.body" class="border-2 border-white bg-white/70 p-3" />

      <div class="flex gap-2">
        <FormButton v-if="received && message.sender" size="lg" @click="answer">Répondre</FormButton>
        <FormButton variant="pink"
                    size="lg"
                    :disabled="isLoading"
                    @click="remove">Supprimer</FormButton>
      </div>
    </template>
  </div>
</template>
