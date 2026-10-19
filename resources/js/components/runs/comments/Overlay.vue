<script setup>
// The comments of a replay shown when the replay reaches them, SoundCloud style, on one line: on a computer in the game
// itself, above its controls (inGame: emits "change", the page gives it to the game, ReplayHud.setComment), on a phone
// fixed at the top of the screen. Each one stays 3 seconds (ReplayHud.COMMENT_SECONDS: the width of its mark); a jump
// in the replay (seek) shows nothing but the comments where it lands. The pointer over a mark of the progress bar shows
// its comment. Hidden: nothing (the player pressed C in the game).
const props = defineProps({
  // the comments with a mark in the progress bar, in its order
  comments: { type: Array, required: true },
  frame: { type: Number, default: -1 },
  seeking: { type: Boolean, default: false },
  // the mark under the pointer (-1: none)
  hovered: { type: Number, default: -1 },
  inGame: { type: Boolean, default: false },
  hidden: { type: Boolean, default: false },
})
const emit = defineEmits(['change'])

const SHOW_MS = 3000
// more than this between two readings of the clock: a jump, not the replay playing (8x at most)
const JUMP_FRAMES = REPLAY_FPS * 4
const MAX_QUEUE = 3

// [{ comment, until }]: the first one is shown
const queue = ref([])
let timer = null

const push = (comments) => {
  for (const comment of comments) {
    if (!queue.value.some((item) => item.comment.id === comment.id)) {
      queue.value.push({ comment, until: null })
    }
  }
  // the latest ones: the replay goes on
  while (queue.value.length > MAX_QUEUE) {
    queue.value.splice(1, 1)
  }
  if (queue.value.length && queue.value[0].until === null) {
    queue.value[0].until = Date.now() + SHOW_MS
  }
}

watch(() => props.frame, (frame, previous) => {
  if (frame < 0 || previous < 0 || frame === previous || props.hidden) {
    return
  }
  const jumped = props.seeking || frame < previous || frame - previous > JUMP_FRAMES
  // where it lands: the comments of the last second (the ones waiting before the jump are gone)
  if (jumped) {
    queue.value = []
  }
  const from = jumped ? frame - REPLAY_FPS : previous
  push(props.comments.filter((comment) => comment.frame > from && comment.frame <= frame))
})

onMounted(() => {
  timer = setInterval(() => {
    const first = queue.value[0]
    if (first && first.until !== null && Date.now() >= first.until) {
      queue.value.shift()
      if (queue.value.length) {
        queue.value[0].until = Date.now() + SHOW_MS
      }
    }
  }, 200)
})
onBeforeUnmount(() => clearInterval(timer))

watch(() => props.hidden, (hidden) => {
  if (hidden) {
    queue.value = []
  }
})

const shown = computed(() => (props.hidden ? null : props.comments[props.hovered] ?? queue.value[0]?.comment ?? null))
const waiting = computed(() => (props.comments[props.hovered] ? 0 : Math.max(0, queue.value.length - 1)))

// for the game
watch([shown, waiting, () => props.inGame], ([comment, more, inGame]) => {
  emit('change', inGame && comment
    ? { time: formatFrame(comment.frame), author: comment.author?.display_name ?? 'Ancien joueur', text: comment.content, more }
    : null)
})
</script>

<template>
  <Transition enter-from-class="opacity-0"
              leave-to-class="opacity-0"
              enter-active-class="transition-opacity duration-200"
              leave-active-class="transition-opacity duration-300">
    <div v-if="shown && !inGame"
         :key="shown.id"
         class="pointer-events-none fixed inset-x-0 top-0 z-40 flex items-center gap-2 border-0 border-b border-l-4 border-solid border-kado-cyan-750 border-l-kado-orange bg-white/95 px-2 py-1 text-xs text-kado-slate-600 shadow-md"
         role="status">
      <span class="shrink-0 text-2xs font-bold text-kado-orange">{{ formatFrame(shown.frame) }}</span>
      <span class="shrink-0 font-bold [font-variant:small-caps]">{{ shown.author?.display_name ?? 'Ancien joueur' }}</span>
      <span class="min-w-0 flex-1 truncate">{{ shown.content }}</span>
      <span v-if="waiting" class="shrink-0 text-2xs text-kado-slate-400">+{{ waiting }}</span>
    </div>
  </Transition>
</template>
