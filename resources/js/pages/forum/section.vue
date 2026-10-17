<script setup>
import { etwinIcons,etwinIconUrl } from '@/marktwin/etwin'

// a section of the forum of Eternaltwin: its threads, and a new thread (when Eternaltwin allows it: self.can_create_thread)
const route = useRoute()
const router = useRouter()
const { fetchStatus, fetchSection, isLoading, error } = useEtwinForum()
const creation = useEtwinForum()

const ref_ = computed(() => route.params.section)
const page = computed(() => Number(route.query.page) || 1)
const status = ref(null)
const section = ref(null)
fetchStatus().then((data) => {
  status.value = data
})
const load = () =>
  fetchSection(ref_.value, page.value).then((data) => {
    section.value = data
  })
watch([ref_, page], load, { immediate: true })

const lastPage = computed(() => (section.value ? Math.max(1, Math.ceil(section.value.threads.count / section.value.threads.limit)) : 1))
const pageRoute = (number) => ({ query: number > 1 ? { page: number } : {} })
const grammar = computed(() => section.value?.self?.grammar ?? null)

const writing = ref(false)
const title = ref('')
const body = ref('')
const create = () =>
  creation.createThread(section.value.id, title.value, body.value).then((thread) =>
    router.push({ name: 'forum.thread', params: { thread: thread.id } }))
</script>

<template>
  <NavTabs :items="[{ label: 'Forum', value: 'forum', route: { name: 'forum.index' } }]" :selected-index="0" />

  <div class="relative min-h-48 px-2 pb-2">
    <MessageError v-if="error">{{ error }}</MessageError>
    <Loader v-if="isLoading && !section" />
    <EtwinForumLoginNotice v-if="status?.needs_login" />

    <template v-if="section">
      <EtwinForumBar :title="section.display_name" :crumbs="section.parent ? [{ label: section.parent.display_name, to: { name: 'forum.index' } }] : []">
        <EtwinForumButton v-if="section.self?.can_create_thread" icon="reply" @click="writing = !writing">Nouveau sujet</EtwinForumButton>
      </EtwinForumBar>

      <form v-if="writing" class="mb-4 space-y-2" @submit.prevent="create">
        <MessageError v-if="creation.error.value">{{ creation.error.value }}</MessageError>
        <div>
          <label for="threadTitle" class="block font-bold">Titre du sujet</label>
          <FormInput id="threadTitle"
                     v-model="title"
                     maxlength="100"
                     required
                     class="w-full" />
        </div>
        <MarktwinEditor v-model="body"
                        :grammar="grammar"
                        :icons="etwinIcons(grammar?.icons)"
                        :icon-url="etwinIconUrl" />
        <FormButton type="submit" size="lg" :disabled="creation.isLoading.value || !title.trim() || !body.trim()">Créer le sujet</FormButton>
      </form>

      <EtwinForumThreadTable :threads="section.threads.items" />
      <EtwinForumPagination :current-page="page" :last-page="lastPage" :to="pageRoute" />
    </template>
  </div>
</template>
