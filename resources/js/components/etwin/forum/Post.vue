<script setup>
import { etwinIcons,etwinIconUrl } from '@/marktwin/etwin'

// a message of the forum, as on the forum of Twinoid: its author and its date in the dark header, the message below.
// Its author edits it (self.can_edit, from Eternaltwin): its Marktwin source is fetched, then sent with the revision it
// replaces.
const props = defineProps({
  post: { type: Object, required: true },
  // the grammar of the section (its self.grammar), for the editor
  grammar: { type: Object, default: null },
})
const emit = defineEmits(['updated'])

const { fetchPostSource, updatePost, isLoading, error } = useEtwinForum()
const revision = computed(() => props.post.revisions?.last ?? null)
const author = computed(() => props.post.author?.user ?? null)
const editing = ref(false)
const draft = ref('')
const editedRevision = ref(null)

// the last revision of the source (the most recent one)
const lastRevision = (source) => source.revisions?.last
  ?? [...(source.revisions?.items ?? [])].sort((a, b) => (a.time < b.time ? 1 : -1))[0]
  ?? null
const startEditing = () =>
  fetchPostSource(props.post.id).then((source) => {
    const last = lastRevision(source)
    editedRevision.value = last?.id ?? revision.value?.id
    draft.value = last?.content?.marktwin ?? ''
    editing.value = true
  })
const save = () =>
  updatePost(props.post.id, editedRevision.value, draft.value).then(() => {
    editing.value = false
    emit('updated')
  })
</script>

<template>
  <article class="mb-2.5">
    <header class="flex flex-wrap items-baseline justify-between gap-x-3 rounded bg-kado-slate-600 bg-[url(/gfx/forum/twinoid/forum_postHeader.png)] bg-bottom-left bg-repeat-x px-2.5 py-1 text-white">
      <RouterLink v-if="author"
                  :to="{ name: 'profile.show', params: { id: author.id } }"
                  class="text-sm font-bold text-kado-orange hover:text-kado-orange">{{ etwinActorName(post.author) }}</RouterLink>
      <span v-else class="text-sm font-bold italic">?</span>
      <time :datetime="post.ctime" class="text-2xs opacity-70">{{ etwinForumDate(post.ctime) }}</time>
    </header>
    <div class="mx-0.5 bg-kado-slate-450 p-2.5 text-sm text-white shadow-[0_2px_2px_rgba(0,0,0,0.15)] sm:mx-1">
      <MessageError v-if="error">{{ error }}</MessageError>
      <form v-if="editing" class="space-y-2" @submit.prevent="save">
        <MarktwinEditor v-model="draft"
                        :grammar="grammar"
                        :icons="etwinIcons(grammar?.icons)"
                        :icon-url="etwinIconUrl" />
        <div class="flex gap-2">
          <FormButton type="submit" :disabled="isLoading || !draft.trim()">Enregistrer</FormButton>
          <FormButton variant="pink" @click="editing = false">Annuler</FormButton>
        </div>
      </form>
      <EtwinForumContent v-else-if="revision?.content?.html" :html="revision.content.html" />
      <p v-else class="m-0 italic opacity-75">Ce message a été retiré par la modération.</p>

      <div class="mt-2 flex flex-wrap items-center justify-end gap-2 text-2xs opacity-80">
        <span v-if="(post.revisions?.count ?? 1) > 1" class="mr-auto italic">Modifié {{ etwinForumDate(revision?.time) }}</span>
        <EtwinForumButton v-if="post.self?.can_edit && !editing"
                          icon="edit"
                          :disabled="isLoading"
                          @click="startEditing">Éditer</EtwinForumButton>
      </div>
    </div>
  </article>
</template>
