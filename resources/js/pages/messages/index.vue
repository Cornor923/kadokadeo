<script setup>
// the private messages: received, sent, and the form to write one
const route = useRoute()
const router = useRouter()
const messagesStore = useMessagesStore()
const { get, isLoading, error } = useApi()
// (its own error)
const { post, isLoading: isSending, error: sendError } = useApi()

const box = computed(() => route.meta.box)
const messages = ref([])
const meta = ref(null)

const load = (page = 1) => {
  if (box.value === 'new') {
    return
  }
  get('/messages', { params: { box: box.value, page } }).then((response) => {
    messages.value = page === 1 ? response.data.data : [...messages.value, ...response.data.data]
    meta.value = response.data.meta
    messagesStore.unread = response.data.unread
  })
}
watch(box, () => load(), { immediate: true })
const hasNextPage = computed(() => meta.value && meta.value.current_page < meta.value.last_page)

// writing: the recipient and the subject can come from a profile or an answer
const to = ref(route.query.to ?? '')
const subject = ref(route.query.subject ?? '')
const body = ref('')
watch(() => route.query, (query) => {
  to.value = query.to ?? to.value
  subject.value = query.subject ?? subject.value
})
const send = () =>
  post('/messages', { to: to.value, subject: subject.value, body: body.value }).then(() => {
    body.value = ''
    router.push({ name: 'messages.sent', query: { sent: 1 } })
  })

const tabs = [
  { label: 'Reçus', value: 'inbox', route: { name: 'messages.inbox' } },
  { label: 'Envoyés', value: 'sent', route: { name: 'messages.sent' } },
  { label: 'Écrire', value: 'new', route: { name: 'messages.new' } },
]
const selectedIndex = computed(() => tabs.findIndex((t) => t.value === box.value))
const date = (iso) => new Date(iso).toLocaleString('fr-FR', { day: '2-digit', month: '2-digit', year: '2-digit', hour: '2-digit', minute: '2-digit' })
</script>

<template>
  <NavTabs :items="tabs" :selected-index="selectedIndex" />

  <div class="relative px-2 space-y-4">
    <h1 class="mt-0 text-center">Messages</h1>

    <template v-if="box === 'new'">
      <form class="max-w-xl space-y-3" @submit.prevent="send">
        <div>
          <label for="messageTo" class="block font-bold">Destinataire (nom du joueur)</label>
          <FormInput id="messageTo"
                     v-model="to"
                     type="text"
                     maxlength="255"
                     required
                     class="w-full" />
        </div>
        <div>
          <label for="messageSubject" class="block font-bold">Sujet</label>
          <FormInput id="messageSubject"
                     v-model="subject"
                     type="text"
                     maxlength="100"
                     required
                     class="w-full" />
        </div>
        <div>
          <label for="messageBody" class="block font-bold">Message</label>
          <MarktwinEditor id="messageBody"
                          v-model="body"
                          :maxlength="5000"
                          :rows="10" />
        </div>
        <FormButton type="submit" size="lg" :disabled="isSending || !body.trim()">Envoyer</FormButton>
      </form>
      <MessageError v-if="sendError">{{ sendError }}</MessageError>
    </template>

    <template v-else>
      <MessageSuccess v-if="route.query.sent">Votre message a bien été envoyé.</MessageSuccess>
      <MessageError v-if="error">{{ error }}</MessageError>
      <div class="relative overflow-x-auto">
        <Loader v-if="isLoading && !messages.length" />
        <table class="w-full">
          <thead>
            <tr class="text-2xs uppercase">
              <th></th>
              <th>{{ box === 'sent' ? 'À' : 'De' }}</th>
              <th>Sujet</th>
              <th>Date</th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="!messages.length && !isLoading" class="bg-kado-cyan-200">
              <td colspan="4" class="py-4 italic">{{ box === 'sent' ? 'Vous n\'avez envoyé aucun message.' : 'Vous n\'avez aucun message.' }}</td>
            </tr>
            <tr
              v-for="(message, index) in messages"
              :key="message.id"
              :class="[index % 2 ? 'bg-white' : 'bg-kado-cyan-200', { 'font-bold': box === 'inbox' && !message.is_read }]"
              class="cursor-pointer"
              @click="router.push({ name: 'messages.show', params: { id: message.id } })"
            >
              <td class="w-8">
                <img :src="box === 'inbox' && !message.is_read ? '/assets/img/gfx/icons/newMail.gif' : '/assets/img/gfx/icons/readedMail.gif'" :alt="message.is_read ? 'lu' : 'nouveau'" />
              </td>
              <td class="text-left [font-variant:small-caps]">
                <template v-if="box === 'sent'">{{ message.recipient.display_name }}</template>
                <template v-else-if="message.sender">{{ message.sender.display_name }}</template>
                <template v-else><span class="text-kado-orange">KadoKadéo</span></template>
              </td>
              <td class="text-left">
                <RouterLink :to="{ name: 'messages.show', params: { id: message.id } }">{{ message.subject }}</RouterLink>
              </td>
              <td class="whitespace-nowrap text-xs">{{ date(message.created_at) }}</td>
            </tr>
          </tbody>
        </table>
      </div>
      <div v-if="hasNextPage" class="text-center">
        <FormButton size="lg" :disabled="isLoading" @click="load(meta.current_page + 1)">Messages précédents</FormButton>
      </div>
    </template>
  </div>
</template>
