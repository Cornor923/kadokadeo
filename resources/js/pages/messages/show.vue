<script setup>
// a private message: read (marked as read), answer, delete
const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const messagesStore = useMessagesStore()
const { get, del, isLoading, error } = useApi()

const message = ref(null)
watch(() => route.params.id, (id) => {
  get(`/messages/${id}`).then((response) => {
    message.value = response.data.data
    messagesStore.reload()
  })
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
    del(`/messages/${message.value.id}`).then(() => router.push({ name: received.value ? 'messages.inbox' : 'messages.sent' }))
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
    ]"
    :selected-index="received ? 0 : 1"
  />

  <div class="relative px-2 space-y-4 min-h-48">
    <Loader v-if="isLoading && !message" />
    <MessageError v-if="error">{{ error }}</MessageError>

    <template v-if="message">
      <h2 class="normal-case">{{ message.subject }}</h2>
      <p class="mx-0 text-sm">
        <template v-if="received">
          De
          <RouterLink v-if="message.sender" :to="{ name: 'profile.show', params: { id: message.sender.etwin_id } }" class="font-bold">{{ message.sender.display_name }}</RouterLink>
          <strong v-else class="text-kado-orange">KadoKado</strong>,
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
