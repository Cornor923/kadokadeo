<script setup>
// writes a comment of a replay on one line, SoundCloud style: at the moment of the replay shown when the field gets the
// focus (kept while writing), or an answer to a comment (at its moment)
const props = defineProps({
  runId: { type: String, required: true },
  // the frame of the replay shown (-1: not playing yet)
  frame: { type: Number, default: 0 },
  maxLength: { type: Number, default: 280 },
  // the comment answered
  parent: { type: Object, default: null },
})
const emit = defineEmits(['created', 'cancel'])

const { createComment, isLoading, error } = useRunComments()
const draft = ref('')
// the moment taken when the player started writing
const pinned = ref(null)
const input = ref(null)

const at = computed(() => pinned.value ?? Math.max(0, props.frame))
const placeholder = computed(() => props.parent
  ? `Répondre à ${props.parent.author?.display_name ?? 'Ancien joueur'}…`
  : `Commenter à ${formatFrame(at.value)}…`)

const pin = () => {
  if (pinned.value === null) {
    pinned.value = Math.max(0, props.frame)
  }
}
const unpin = () => {
  if (!draft.value.trim()) {
    pinned.value = null
  }
}

const send = () => {
  const content = draft.value.trim()
  if (!content || isLoading.value) {
    return
  }
  createComment(props.runId, { frame: at.value, content, parent_id: props.parent?.id ?? null }).then(({ data }) => {
    draft.value = ''
    pinned.value = null
    emit('created', data)
  })
}

defineExpose({ focus: () => input.value?.$el?.focus() })
</script>

<template>
  <form class="flex flex-wrap items-center gap-2" @submit.prevent="send">
    <span v-if="!parent"
          class="shrink-0 border border-solid border-kado-orange bg-kado-orange-50 px-1 text-2xs leading-4 font-bold text-kado-slate-600"
          :title="`Frame ${at}`">{{ formatFrame(at) }}</span>
    <FormInput ref="input"
               v-model="draft"
               class="min-w-0 flex-1 text-xs"
               :maxlength="maxLength"
               :placeholder="placeholder"
               @focus="pin"
               @blur="unpin" />
    <FormButton type="submit" size="sm" :disabled="isLoading || !draft.trim()">Envoyer</FormButton>
    <FormButton v-if="parent"
                size="sm"
                variant="pink"
                @click="emit('cancel')">Annuler</FormButton>
    <MessageError v-if="error" class="basis-full">{{ error }}</MessageError>
  </form>
</template>
