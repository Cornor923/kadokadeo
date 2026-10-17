<script setup>
import { etwinIcons,etwinIconUrl } from '@/marktwin/etwin'

// a thread of the forum of Eternaltwin: its posts (a page), the answer (self.can_post), and the posts shown marked as
// read (an explicit write, once on screen)
const route = useRoute()
const router = useRouter()
const { fetchStatus, fetchThread, fetchSection, markRead, isLoading, error } = useEtwinForum()
const answer = useEtwinForum()

const threadRef = computed(() => route.params.thread)
const page = computed(() => Number(route.query.page) || 1)
const status = ref(null)
const thread = ref(null)
// the grammar of its section, for the editor
const grammar = ref(null)
fetchStatus().then((data) => {
  status.value = data
})

const load = () =>
  fetchThread(threadRef.value, page.value).then((data) => {
    thread.value = data
    const posts = data.posts.items
    if (status.value?.can_write && posts.length) {
      nextTick(() => markRead(data.id, posts[posts.length - 1].id).catch(() => {}))
    }
    if (!grammar.value && data.self?.can_post) {
      fetchSection(data.section.id).then((section) => {
        grammar.value = section.self?.grammar ?? null
      })
    }
  })
watch([threadRef, page], load, { immediate: true })

const lastPage = computed(() => (thread.value ? Math.max(1, Math.ceil(thread.value.posts.count / thread.value.posts.limit)) : 1))
const pageRoute = (number) => ({ query: number > 1 ? { page: number } : {} })

const draft = ref('')
const reply = () =>
  answer.reply(thread.value.id, draft.value).then(() => {
    draft.value = ''
    // the last page, where the answer is
    const last = Math.max(1, Math.ceil((thread.value.posts.count + 1) / thread.value.posts.limit))
    if (last === page.value) {
      load()
    } else {
      router.push(pageRoute(last))
    }
  })
</script>

<template>
  <NavTabs :items="[{ label: 'Forum', value: 'forum', route: { name: 'forum.index' } }]" :selected-index="0" />

  <div class="relative min-h-48 px-2 pb-2">
    <MessageError v-if="error">{{ error }}</MessageError>
    <Loader v-if="isLoading && !thread" />
    <EtwinForumLoginNotice v-if="status?.needs_login" />

    <template v-if="thread">
      <EtwinForumBar :title="thread.title" :crumbs="[{ label: thread.section.display_name, to: { name: 'forum.section', params: { section: thread.section.key ?? thread.section.id } } }]">
        <EtwinForumButton icon="back" :to="{ name: 'forum.section', params: { section: thread.section.key ?? thread.section.id } }" />
        <img v-if="thread.is_locked"
             src="/gfx/forum/twinoid/lock.png"
             alt="Verrouillé"
             title="Sujet verrouillé" />
        <div class="ml-auto"><EtwinForumPagination :current-page="page" :last-page="lastPage" :to="pageRoute" /></div>
      </EtwinForumBar>

      <EtwinForumPost v-for="post in thread.posts.items"
                      :key="post.id"
                      :post="post"
                      :grammar="grammar"
                      @updated="load" />

      <EtwinForumPagination :current-page="page" :last-page="lastPage" :to="pageRoute" />

      <form v-if="thread.self?.can_post" class="mt-4 space-y-2" @submit.prevent="reply">
        <MessageError v-if="answer.error.value">{{ answer.error.value }}</MessageError>
        <MarktwinEditor v-model="draft"
                        :grammar="grammar"
                        :icons="etwinIcons(grammar?.icons)"
                        :icon-url="etwinIconUrl" />
        <FormButton type="submit" size="lg" :disabled="answer.isLoading.value || !draft.trim()">Répondre</FormButton>
      </form>
      <p v-else-if="thread.is_locked" class="mt-4 text-center italic">Ce sujet est verrouillé.</p>
    </template>
  </div>
</template>
