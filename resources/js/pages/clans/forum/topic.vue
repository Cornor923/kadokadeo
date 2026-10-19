<script setup>
// a topic of the forum of a clan: its messages (10 a page) and the answer. The leader and the right hands pin it
// ("Post-it"), lock it (only they can still answer) and delete it; its author or a moderator renames it.
const route = useRoute()
const router = useRouter()
const { fetchTopic, isLoading, error } = useClanForum()
// (the errors of the actions, apart from the loading)
const actions = useClanForum()

const clanId = computed(() => route.params.id)
const topicId = computed(() => route.params.topic)
const page = computed(() => (route.query.page === 'last' ? 'last' : Number(route.query.page) || 1))

const result = ref(null)
const load = () =>
  fetchTopic(clanId.value, topicId.value, page.value).then((data) => {
    result.value = data
  })
watch([clanId, topicId, page], load, { immediate: true })

const topic = computed(() => result.value?.topic ?? null)
const viewer = computed(() => result.value?.viewer ?? {})
const meta = computed(() => result.value?.meta ?? null)

const draft = ref('')
const toReply = () => document.getElementById('reply')?.scrollIntoView({ behavior: 'smooth' })
const reply = () =>
  actions.reply(clanId.value, topicId.value, draft.value).then(({ data }) => {
    draft.value = ''
    const shown = () => nextTick(() => document.getElementById(`message-${data.id}`)?.scrollIntoView({ behavior: 'smooth' }))
    if (data.page === meta.value?.current_page) {
      load().then(shown)
    } else {
      router.push({ query: { page: data.page } }).then(() => watch(result, shown, { once: true }))
    }
  })

const update = (changes) => actions.updateTopic(clanId.value, topicId.value, changes).then(load)
const rename = () => {
  const title = prompt('Nouveau titre du sujet', topic.value.title)
  if (title && title.trim() && title.trim() !== topic.value.title) {
    update({ title: title.trim() })
  }
}
const remove = () => {
  if (confirm(`Supprimer le sujet « ${topic.value.title} » et tous ses messages ? Cette action est définitive.`)) {
    actions.deleteTopic(clanId.value, topicId.value).then(() => router.push({ name: 'clans.forum', params: { id: clanId.value } }))
  }
}
const pageRoute = (page) => ({ query: { page } })
</script>

<template>
  <div class="relative min-h-48">
    <ClanForumHeader :clan-id="clanId" linked />

    <div class="space-y-3 px-2 pb-2">
      <MessageError v-if="error">{{ error }}</MessageError>
      <MessageError v-else-if="actions.error.value">{{ actions.error.value }}</MessageError>
      <Loader v-if="isLoading && !result" />

      <template v-if="topic">
        <div class="flex flex-wrap gap-2">
          <FormButton v-if="viewer.can_reply" @click="toReply">Répondre</FormButton>
          <FormButton v-if="viewer.can_rename" @click="rename">Renommer</FormButton>
          <template v-if="viewer.can_moderate">
            <FormButton variant="pink" @click="update({ is_pinned: !topic.is_pinned })">{{ topic.is_pinned ? 'Retirer des post-it' : 'Mettre en post-it' }}</FormButton>
            <FormButton variant="pink" @click="update({ is_locked: !topic.is_locked })">{{ topic.is_locked ? 'Déverrouiller' : 'Verrouiller' }}</FormButton>
            <FormButton variant="pink" @click="remove">Supprimer le sujet</FormButton>
          </template>
        </div>

        <div class="space-y-2">
          <div class="border border-solid border-kado-green-600 bg-kado-green-500 bg-[url(/assets/img/gfx/gui/base/greenh2_bg.jpg)] bg-[position:-25px_-5px] bg-no-repeat px-2 text-base tracking-widest text-kado-green-600">
            <span v-if="topic.is_locked" title="Sujet verrouillé">🔒 </span>{{ topic.title }}
          </div>
          <ClanForumMessage v-for="message in result.data"
                            :id="`message-${message.id}`"
                            :key="message.id"
                            :clan-id="clanId"
                            :message="message"
                            :can-moderate="viewer.can_moderate"
                            @updated="load" />
        </div>

        <NavPagination :current-page="meta.current_page" :last-page="meta.last_page" :to="pageRoute" />

        <form v-if="viewer.can_reply"
              id="reply"
              class="space-y-2"
              @submit.prevent="reply">
          <p v-if="topic.is_locked" class="m-0 text-sm italic">Ce sujet est verrouillé : seuls le chef et les bras droits peuvent encore y répondre.</p>
          <MarktwinEditor v-model="draft" />
          <FormButton type="submit" size="lg" :disabled="actions.isLoading.value || !draft.trim()">Envoyer</FormButton>
        </form>
        <p v-else class="m-0 text-center italic">Ce sujet est verrouillé.</p>
      </template>
    </div>
  </div>
</template>
