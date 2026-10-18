<script setup>
// a message of the forum of a clan, as on the old forum: its author on the left (his role in the clan, the date), the
// message on the right. Its author edits it, the leader and the right hands edit, delete and restore it (a deleted
// message stays, its content shown to the moderators only).
const props = defineProps({
  clanId: { type: [Number, String], required: true },
  message: { type: Object, required: true },
  canModerate: { type: Boolean, default: false },
})
const emit = defineEmits(['updated'])

const { updateMessage, deleteMessage, restoreMessage, isLoading, error } = useClanForum()
const editing = ref(false)
const draft = ref('')

const startEditing = () => {
  draft.value = props.message.content ?? ''
  editing.value = true
}
const save = () =>
  updateMessage(props.clanId, props.message.id, draft.value).then(() => {
    editing.value = false
    emit('updated')
  })
const remove = () => {
  if (confirm('Supprimer ce message ? Il restera visible par le chef et les bras droits, qui pourront le restaurer.')) {
    deleteMessage(props.clanId, props.message.id).then(() => emit('updated'))
  }
}
const restore = () => restoreMessage(props.clanId, props.message.id).then(() => emit('updated'))

const formatDate = (date) => dayjs(date).format('DD/MM/YY à HH:mm')
</script>

<template>
  <article class="flex flex-col border border-solid border-kado-cyan-750 sm:flex-row">
    <div class="flex shrink-0 flex-wrap items-center gap-x-2 border-0 border-b border-solid border-kado-cyan-750 bg-kado-cyan-muted bg-[url(/assets/img/gfx/gui/forum_info_bg.jpg)] bg-no-repeat p-2 text-2xs text-kado-slate-600 sm:w-32 sm:flex-col sm:border-r sm:border-b-0 sm:text-center">
      <RouterLink v-if="message.author"
                  :to="{ name: 'profile.show', params: { id: message.author.etwin_id } }"
                  class="text-sm font-bold [font-variant:small-caps] break-all">
        {{ message.author.display_name }}
      </RouterLink>
      <span v-else class="text-sm italic">Ancien joueur</span>
      <span v-if="message.author_role === 'leader'" class="inline-flex items-center gap-1">
        <img src="/gfx/clan/clanleader.gif" alt="" />{{ message.author_role_label }}
      </span>
      <span v-else-if="message.author_role === 'right_hand'">{{ message.author_role_label }}</span>
      <span v-else-if="message.author && !message.author_role" class="italic">A quitté le clan</span>
      <time :datetime="message.created_at" class="sm:mt-1">{{ formatDate(message.created_at) }}</time>
    </div>

    <div class="min-w-0 flex-1 bg-white bg-[url(/assets/img/gfx/gui/base/greyh2_bg.jpg)] bg-[position:-150px_-40px] bg-no-repeat p-2 pl-3">
      <MessageError v-if="error">{{ error }}</MessageError>

      <template v-if="message.is_deleted">
        <p class="m-0 font-bold text-red-600">Ce message a été supprimé par un modérateur.</p>
        <MarktwinContent v-if="canModerate && message.content" :text="message.content" class="mt-2 opacity-50" />
      </template>
      <form v-else-if="editing" class="space-y-2" @submit.prevent="save">
        <MarktwinEditor v-model="draft" />
        <div class="flex gap-2">
          <FormButton type="submit" :disabled="isLoading || !draft.trim()">Enregistrer</FormButton>
          <FormButton variant="pink" @click="editing = false">Annuler</FormButton>
        </div>
      </form>
      <MarktwinContent v-else :text="message.content" />

      <div class="mt-3 flex flex-wrap items-center justify-end gap-2 text-2xs text-kado-slate-400">
        <span v-if="message.edited_at" class="mr-auto italic">Modifié le {{ formatDate(message.edited_at) }}</span>
        <FormButton v-if="message.can_edit && !editing" size="sm" @click="startEditing">Éditer</FormButton>
        <FormButton v-if="canModerate && !message.is_deleted"
                    size="sm"
                    variant="pink"
                    :disabled="isLoading"
                    @click="remove">Supprimer</FormButton>
        <FormButton v-if="canModerate && message.is_deleted"
                    size="sm"
                    variant="pink"
                    :disabled="isLoading"
                    @click="restore">Restaurer</FormButton>
      </div>
    </div>
  </article>
</template>
