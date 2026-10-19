<script setup>
// the comments of a replay under it, in the order of the replay, each one followed by its answers
const props = defineProps({
  runId: { type: String, required: true },
  comments: { type: Array, required: true },
  canComment: { type: Boolean, default: false },
  maxLength: { type: Number, default: 280 },
  reasons: { type: Array, default: () => [] },
  // the frame of the replay shown
  frame: { type: Number, default: -1 },
})
const emit = defineEmits(['seek', 'changed'])

const threads = computed(() => {
  const replies = new Map()
  for (const comment of props.comments) {
    if (comment.parent_id) {
      replies.set(comment.parent_id, [...(replies.get(comment.parent_id) ?? []), comment])
    }
  }
  return props.comments
    .filter((comment) => !comment.parent_id)
    .map((comment) => ({ comment, replies: replies.get(comment.id) ?? [] }))
})

// the last comment reached by the replay (within 3 seconds)
const activeId = computed(() => {
  if (props.frame < 0) {
    return null
  }
  const reached = props.comments.filter((comment) => !comment.parent_id && !comment.is_deleted
    && comment.frame <= props.frame && props.frame - comment.frame < REPLAY_FPS * 3)
  return reached.at(-1)?.id ?? null
})

const answering = ref(null)
const answered = () => {
  answering.value = null
  emit('changed')
}
</script>

<template>
  <div class="space-y-2">
    <p v-if="!threads.length" class="m-0 text-xs italic text-kado-slate-400">
      Aucun commentaire pour l'instant{{ canComment ? ' : soyez le premier !' : '.' }}
    </p>
    <div v-for="{ comment, replies } in threads" :key="comment.id">
      <RunsCommentsItem :run-id="runId"
                        :comment="comment"
                        :can-comment="canComment"
                        :max-length="maxLength"
                        :reasons="reasons"
                        :active="comment.id === activeId"
                        @seek="emit('seek', $event)"
                        @reply="answering = $event.id"
                        @changed="emit('changed')" />
      <RunsCommentsItem v-for="reply in replies"
                        :key="reply.id"
                        :run-id="runId"
                        :comment="reply"
                        is-reply
                        :max-length="maxLength"
                        :reasons="reasons"
                        @changed="emit('changed')" />
      <div v-if="answering === comment.id" class="ml-6 border border-t-0 border-solid border-kado-cyan-750 bg-white px-2 py-1 sm:ml-10">
        <RunsCommentsComposer :run-id="runId"
                              :parent="comment"
                              :max-length="maxLength"
                              @created="answered"
                              @cancel="answering = null" />
      </div>
    </div>
  </div>
</template>
