<script setup>
import { useChannel, userChannel } from '@/composables/useRealtime'
import { messageDraft } from '@/messages/draft'

// the private messages: received, sent, the form to write one, and the notifications of the player
const route = useRoute()
const authStore = useAuthStore()
const router = useRouter()
const messagesStore = useMessagesStore()
// (its own error)
const { sendMessage, isLoading: isSending, error: sendError } = useMessages()

const box = computed(() => route.meta.box)
const { items: messages, hasNextPage, loadMore, reload, isLoading, error } = useMessageBox(box, {
  onPage: (data) => {
    messagesStore.unread = data.unread
  },
})
// received or sent meanwhile (in another tab too): the first page again
useChannel(() => userChannel(authStore.user?.id), {
  'message.received': () => box.value === 'inbox' && reload(),
  'message.sent': () => box.value === 'sent' && reload(),
}, { resync: reload })

// writing: the form can be filled by its URL
const draft = messageDraft(route.query)
const to = ref(draft.to ?? '')
const subject = ref(draft.subject ?? '')
const body = ref(draft.body ?? '')
watch(() => route.query, (query) => {
  const next = messageDraft(query)
  to.value = next.to ?? to.value
  subject.value = next.subject ?? subject.value
  body.value = next.body ?? body.value
})
const send = () =>
  sendMessage({ to: to.value, subject: subject.value, body: body.value }).then(() => {
    body.value = ''
    router.push({ name: 'messages.sent', query: { sent: 1 } })
  })

const tabs = computed(() => [
  { label: messagesStore.unread ? `Reçus (${messagesStore.unread})` : 'Reçus', value: 'inbox', route: { name: 'messages.inbox' } },
  { label: 'Envoyés', value: 'sent', route: { name: 'messages.sent' } },
  { label: 'Écrire', value: 'new', route: { name: 'messages.new' } },
  { label: messagesStore.notificationsUnread ? `Notifications (${messagesStore.notificationsUnread})` : 'Notifications', value: 'notifications', route: { name: 'messages.notifications' } },
])
const selectedIndex = computed(() => tabs.value.findIndex((t) => t.value === box.value))
const date = (iso) => new Date(iso).toLocaleString('fr-FR', { day: '2-digit', month: '2-digit', year: '2-digit', hour: '2-digit', minute: '2-digit' })
</script>

<template>
  <NavTabs :items="tabs" :selected-index="selectedIndex" />

  <div class="relative px-2 space-y-4">
    <KadoPageTitle>{{ box === 'notifications' ? 'Notifications' : 'Messages' }}</KadoPageTitle>

    <NotificationsList v-if="box === 'notifications'" />

    <template v-else-if="box === 'new'">
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
        <KadoTable class="w-full">
          <thead>
            <tr class="text-2xs uppercase">
              <th></th>
              <th>{{ box === 'sent' ? 'À' : 'De' }}</th>
              <th>Sujet</th>
              <th>Date</th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="!messages.length && !isLoading" class="bg-kado-blue-100">
              <td colspan="4" class="py-4 italic">{{ box === 'sent' ? 'Vous n\'avez envoyé aucun message.' : 'Vous n\'avez aucun message.' }}</td>
            </tr>
            <tr
              v-for="(message, index) in messages"
              :key="message.id"
              :class="[index % 2 ? 'bg-white' : 'bg-kado-blue-100', { 'font-bold': box === 'inbox' && !message.is_read }]"
              class="cursor-pointer"
              @click="router.push({ name: 'messages.show', params: { id: message.id } })"
            >
              <td class="w-8">
                <img :src="box === 'inbox' && !message.is_read ? '/assets/img/gfx/icons/newMail.gif' : '/assets/img/gfx/icons/readedMail.gif'" :alt="message.is_read ? 'lu' : 'nouveau'" />
              </td>
              <td class="text-left small-caps">
                <template v-if="box === 'sent'">{{ message.recipient.display_name }}</template>
                <template v-else-if="message.sender">{{ message.sender.display_name }}</template>
                <template v-else><span class="text-kado-orange-500">KadoKadéo</span></template>
              </td>
              <td class="text-left">
                <RouterLink :to="{ name: 'messages.show', params: { id: message.id } }">{{ message.subject }}</RouterLink>
              </td>
              <td class="whitespace-nowrap text-xs">{{ date(message.created_at) }}</td>
            </tr>
          </tbody>
        </KadoTable>
      </div>
      <div v-if="hasNextPage" class="text-center">
        <FormButton size="lg" :disabled="isLoading" @click="loadMore()">Messages précédents</FormButton>
      </div>
    </template>
  </div>
</template>
