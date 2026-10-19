<script setup>
// a comment of a replay (or an answer), compact as the forum of the clans: its moment (a click goes there in the
// replay), its author, its text, then the likes, answer, report, edit, delete
const props = defineProps({
  runId: { type: String, required: true },
  comment: { type: Object, required: true },
  isReply: { type: Boolean, default: false },
  canComment: { type: Boolean, default: false },
  maxLength: { type: Number, default: 280 },
  reasons: { type: Array, default: () => [] },
  // the replay is at this comment
  active: { type: Boolean, default: false },
})
const emit = defineEmits(['seek', 'reply', 'changed'])

const { updateComment, deleteComment, like, unlike, report, isLoading, error } = useRunComments()
const editing = ref(false)
const draft = ref('')
const reporting = ref(false)
const reason = ref(null)
const details = ref('')
const reported = ref(false)

const startEditing = () => {
  draft.value = props.comment.content ?? ''
  editing.value = true
}
const save = () => updateComment(props.comment.id, draft.value.trim()).then(() => {
  editing.value = false
  emit('changed')
})
const remove = () => {
  if (confirm('Supprimer ce commentaire ?')) {
    deleteComment(props.comment.id).then(() => emit('changed'))
  }
}

// at once on the screen, put back if the server refuses
const toggleLike = () => {
  const comment = props.comment
  const liked = comment.liked
  comment.liked = !liked
  comment.likes_count += liked ? -1 : 1
  ;(liked ? unlike : like)(comment.id)
    .then(({ data }) => {
      comment.liked = data.liked
      comment.likes_count = data.likes_count
    })
    .catch(() => {
      comment.liked = liked
      comment.likes_count += liked ? 1 : -1
    })
}

const sendReport = () => report(props.comment.id, { reason: reason.value, details: details.value.trim() || null }).then(() => {
  reporting.value = false
  reported.value = true
})

const formatDate = (date) => dayjs(date).format('DD/MM/YY à HH:mm')
</script>

<template>
  <article class="border border-solid border-kado-cyan-750 bg-white text-xs"
           :class="[isReply ? 'ml-6 border-t-0 sm:ml-10' : '', active ? 'outline-2 outline-kado-orange outline-solid' : '']">
    <div class="flex flex-wrap items-center gap-x-2 border-0 border-b border-solid border-kado-cyan-750 bg-kado-cyan-muted bg-[url(/assets/img/gfx/gui/forum_info_bg.jpg)] bg-no-repeat px-2 py-0.5 text-2xs text-kado-slate-600">
      <button v-if="!isReply"
              type="button"
              class="cursor-pointer border border-solid border-kado-orange bg-kado-orange-50 px-1 leading-4 font-bold text-kado-slate-600 hover:bg-kado-orange hover:text-white"
              :title="`Aller à ${formatFrame(comment.frame)} dans le replay`"
              @click="emit('seek', comment.frame)">
        {{ formatFrame(comment.frame) }}
      </button>
      <RouterLink v-if="comment.author"
                  :to="{ name: 'profile.show', params: { id: comment.author.etwin_id } }"
                  class="text-xs font-bold [font-variant:small-caps] break-all">
        {{ comment.author.display_name }}
      </RouterLink>
      <span v-else class="text-xs italic">Ancien joueur</span>
      <time :datetime="comment.created_at" class="ml-auto">{{ formatDate(comment.created_at) }}</time>
    </div>

    <div class="bg-[url(/assets/img/gfx/gui/base/greyh2_bg.jpg)] bg-[position:-150px_-40px] bg-no-repeat px-2 py-1">
      <MessageError v-if="error">{{ error }}</MessageError>

      <p v-if="comment.is_deleted" class="m-0 italic text-kado-slate-400">Ce commentaire a été supprimé.</p>
      <form v-else-if="editing" class="flex flex-wrap items-center gap-2" @submit.prevent="save">
        <FormInput v-model="draft" class="min-w-0 flex-1 text-xs" :maxlength="maxLength" />
        <FormButton type="submit" size="sm" :disabled="isLoading || !draft.trim()">Enregistrer</FormButton>
        <FormButton size="sm" variant="pink" @click="editing = false">Annuler</FormButton>
      </form>
      <p v-else class="m-0 break-words whitespace-pre-wrap">{{ comment.content }}</p>

      <form v-if="reporting" class="mt-1 flex flex-wrap items-center gap-2" @submit.prevent="sendReport">
        <FormSelect v-model="reason" class="text-2xs">
          <option :value="null" disabled>Motif du signalement</option>
          <option v-for="item in reasons" :key="item.value" :value="item.value">{{ item.label }}</option>
        </FormSelect>
        <FormInput v-model="details"
                   class="min-w-0 flex-1 text-2xs"
                   maxlength="500"
                   placeholder="Précisions (facultatif)" />
        <FormButton type="submit"
                    size="sm"
                    variant="pink"
                    :disabled="isLoading || !reason">Signaler</FormButton>
        <FormButton size="sm" @click="reporting = false">Annuler</FormButton>
      </form>

      <div v-if="!comment.is_deleted && !editing && !reporting"
           class="mt-1 flex flex-wrap items-center justify-end gap-2 text-2xs text-kado-slate-400">
        <span v-if="comment.edited_at" class="mr-auto italic">Modifié</span>
        <span v-if="reported" class="mr-auto italic">Merci, le commentaire a été signalé.</span>
        <button type="button"
                class="inline-flex cursor-pointer items-center gap-0.5 border-0 bg-transparent p-0 font-bold disabled:cursor-default"
                :class="comment.liked ? 'text-kado-pink-600' : 'text-kado-slate-400 hover:text-kado-pink-600'"
                :disabled="comment.is_own"
                :title="comment.is_own ? 'J\'aime' : (comment.liked ? 'Je n\'aime plus' : 'J\'aime')"
                @click="toggleLike">
          <span aria-hidden="true">{{ comment.liked ? '♥' : '♡' }}</span>{{ comment.likes_count }}
        </button>
        <FormButton v-if="!isReply && canComment" size="sm" @click="emit('reply', comment)">Répondre</FormButton>
        <FormButton v-if="!comment.is_own && !reported"
                    size="sm"
                    variant="pink"
                    @click="reporting = true">Signaler</FormButton>
        <FormButton v-if="comment.can_edit" size="sm" @click="startEditing">Éditer</FormButton>
        <FormButton v-if="comment.can_delete"
                    size="sm"
                    variant="pink"
                    :disabled="isLoading"
                    @click="remove">Supprimer</FormButton>
      </div>
    </div>
  </article>
</template>
