<script setup>
// the forum of the site: the sections of its category on the forum of Eternaltwin (services.etwin.forumCategory). A
// single section: it is shown at once.
const router = useRouter()
const { fetchStatus, fetchSections, isLoading, error } = useEtwinForum()

const category = ref(null)
const sections = ref([])
Promise.all([fetchStatus(), fetchSections()]).then(([status, listing]) => {
  // the listing is flat, each parent followed by its children (a category holds no threads)
  category.value = listing.items.find((section) => section.key === status.category) ?? null
  sections.value = listing.items.filter((section) => category.value && section.parent?.id === category.value.id)
  if (sections.value.length === 1) {
    router.replace({ name: 'forum.section', params: { section: sections.value[0].key ?? sections.value[0].id } })
  }
})
</script>

<template>
  <NavTabs :items="[{ label: 'Forum', value: 'forum', route: { name: 'forum.index' } }]" :selected-index="0" />

  <div class="relative min-h-48 px-2 pb-2">
    <MessageError v-if="error">{{ error }}</MessageError>
    <Loader v-if="isLoading && !category" />

    <template v-if="category">
      <EtwinForumBar :title="category.display_name" />
      <ul class="m-0 list-none space-y-px p-0">
        <li v-for="section in sections" :key="section.id">
          <RouterLink :to="{ name: 'forum.section', params: { section: section.key ?? section.id } }"
                      class="flex items-center justify-between bg-kado-slate-450 px-3 py-2 text-white no-underline hover:bg-kado-slate-600 hover:text-white hover:no-underline">
            <span class="font-bold">{{ section.display_name }}</span>
            <span class="text-2xs opacity-80">
              {{ section.threads?.count ?? 0 }} sujet(s)
              <strong v-if="section.self?.unread_threads" class="ml-1 text-kado-orange">{{ section.self.unread_threads }} non lu(s)</strong>
            </span>
          </RouterLink>
        </li>
      </ul>
    </template>
    <p v-else-if="!isLoading && !error" class="italic">Le forum n'est pas encore ouvert.</p>
  </div>
</template>
