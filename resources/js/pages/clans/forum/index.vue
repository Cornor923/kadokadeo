<script setup>
// the private forum of a clan: its topics (30 a page), searched in their titles and their messages
const route = useRoute()
const router = useRouter()
const { fetchTopics, isLoading, error } = useClanForum()

const clanId = computed(() => route.params.id)
const page = computed(() => Number(route.query.page) || 1)
const query = computed(() => route.query.q ?? '')

const result = ref(null)
const load = () =>
  fetchTopics(clanId.value, { page: page.value, q: query.value || undefined }).then((data) => {
    result.value = data
  })
watch([clanId, page, query], load, { immediate: true })

const showSearch = ref(Boolean(query.value))
const search = ref(query.value)
const submitSearch = () => router.push({ query: search.value.trim() ? { q: search.value.trim() } : {} })
const clearSearch = () => {
  search.value = ''
  router.push({ query: {} })
}
const pageRoute = (page) => ({ query: { ...route.query, page } })
</script>

<template>
  <div class="relative min-h-48">
    <ClanForumHeader :clan-id="clanId" />

    <div class="space-y-3 px-2 pb-2">
      <div class="flex flex-wrap gap-2">
        <FormButton @click="showSearch = !showSearch">Rechercher</FormButton>
        <FormButton @click="router.push({ name: 'clans.forum.new', params: { id: clanId } })">Créer un nouveau sujet</FormButton>
      </div>

      <form v-if="showSearch" class="flex flex-wrap items-center gap-2" @submit.prevent="submitSearch">
        <FormInput v-model="search"
                   type="search"
                   maxlength="100"
                   placeholder="Un mot du titre ou des messages"
                   class="w-64 max-w-full" />
        <FormButton type="submit">Chercher</FormButton>
      </form>
      <p v-if="query" class="m-0 text-sm">
        Sujets contenant « {{ query }} »
        <button type="button" class="cursor-pointer border-0 bg-transparent p-0 font-bold text-kado-orange underline" @click="clearSearch">tous les sujets</button>
      </p>

      <MessageError v-if="error">{{ error }}</MessageError>
      <Loader v-if="isLoading && !result" />

      <template v-if="result">
        <ClanForumTopicTable :clan-id="clanId" :topics="result.data" />
        <NavPagination :current-page="result.meta.current_page" :last-page="result.meta.last_page" :to="pageRoute" />
      </template>
    </div>
  </div>
</template>
