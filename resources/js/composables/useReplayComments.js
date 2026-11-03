import { computed, onScopeDispose, ref, toValue, watch } from 'vue'

import { formatFrame, REPLAY_FPS } from '@/composables/useReplayClock'

const SHOW_MS = 3000
// more than this between two readings of the clock: a jump, not the replay playing (8x at most)
const JUMP_FRAMES = REPLAY_FPS * 4
const MAX_QUEUE = 3

// The comments of a replay shown when the replay reaches them, SoundCloud style, on one line in the game itself, above
// its controls (onChange: the page gives it to the game, ReplayHud.setComment, larger on a phone where the game is shown
// smaller). Each one stays 3 seconds (ReplayHud.COMMENT_SECONDS: the width of its mark); a jump in the replay (seek)
// shows nothing but the comments where it lands. The pointer over a mark of the progress bar shows its comment. Hidden:
// nothing (C or the bubble of the controls of the game).
// comments: the comments with a mark in the progress bar, in its order; hovered: the mark under the pointer (-1: none).
// Refs or getters.
export function useReplayComments({ comments, frame, seeking, hovered, hidden, onChange }) {
  // [{ comment, until }]: the first one is shown
  const queue = ref([])

  const push = (list) => {
    for (const comment of list) {
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

  watch(() => toValue(frame), (now, previous) => {
    if (now < 0 || previous < 0 || now === previous || toValue(hidden)) {
      return
    }
    const jumped = toValue(seeking) || now < previous || now - previous > JUMP_FRAMES
    // where it lands: the comments of the last second (the ones waiting before the jump are gone)
    if (jumped) {
      queue.value = []
    }
    const from = jumped ? now - REPLAY_FPS : previous
    push(toValue(comments).filter((comment) => comment.frame > from && comment.frame <= now))
  })

  const timer = setInterval(() => {
    const first = queue.value[0]
    if (first && first.until !== null && Date.now() >= first.until) {
      queue.value.shift()
      if (queue.value.length) {
        queue.value[0].until = Date.now() + SHOW_MS
      }
    }
  }, 200)
  onScopeDispose(() => clearInterval(timer))

  watch(() => toValue(hidden), (isHidden) => {
    if (isHidden) {
      queue.value = []
    }
  })

  const shown = computed(() => (toValue(hidden) ? null : toValue(comments)[toValue(hovered)] ?? queue.value[0]?.comment ?? null))
  const waiting = computed(() => (toValue(comments)[toValue(hovered)] ? 0 : Math.max(0, queue.value.length - 1)))

  watch([shown, waiting], ([comment, more]) => {
    onChange(comment
      ? { time: formatFrame(comment.frame), author: comment.author?.display_name ?? 'Ancien joueur', text: comment.content, more }
      : null)
  })
}
