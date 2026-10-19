// the frames of a replay by second (FixedFramerate.STEP of the games, App\Models\RunComment::FPS)
export const REPLAY_FPS = 32

// "mm:ss" of a frame of a replay
export function formatFrame(frame) {
  const seconds = Math.floor(Math.max(0, frame) / REPLAY_FPS)
  return `${String(Math.floor(seconds / 60)).padStart(2, '0')}:${String(seconds % 60).padStart(2, '0')}`
}

const PUBLISH_MS = 100

// Follows the replay being watched, on the client only: the frame shown, paused, a seek being computed, the comments
// shown or hidden by the player (key C) (KadoKadeoManager.getReplayFrame / isReplayPaused / isReplaySeeking /
// areReplayCommentsShown), read every picture but published at most every 100 ms. getInstance: the game (GameScript). The bundles archived before these functions have none of them: nothing
// follows them.
export function useReplayClock(getInstance) {
  // -1: no replay being played (yet)
  const frame = ref(-1)
  const paused = ref(true)
  const seeking = ref(false)
  const commentsShown = ref(true)
  let raf = null
  let published = 0

  const instance = () => {
    const game = getInstance?.()
    return game && typeof game.getReplayFrame === 'function' ? game : null
  }

  const tick = (time) => {
    raf = requestAnimationFrame(tick)
    if (time - published < PUBLISH_MS) {
      return
    }
    published = time
    const game = instance()
    if (!game) {
      return
    }
    const shown = game.getReplayFrame()
    if (shown !== frame.value) {
      frame.value = shown
    }
    const isPaused = game.isReplayPaused()
    if (isPaused !== paused.value) {
      paused.value = isPaused
    }
    const isSeeking = game.isReplaySeeking?.() ?? false
    if (isSeeking !== seeking.value) {
      seeking.value = isSeeking
    }
    const isShown = game.areReplayCommentsShown?.() ?? true
    if (isShown !== commentsShown.value) {
      commentsShown.value = isShown
    }
  }

  const start = () => {
    if (raf === null) {
      raf = requestAnimationFrame(tick)
    }
  }
  const stop = () => {
    if (raf !== null) {
      cancelAnimationFrame(raf)
    }
    raf = null
  }
  onBeforeUnmount(stop)

  return {
    frame,
    paused,
    seeking,
    commentsShown,
    start,
    stop,
    seek: (target) => instance()?.seekReplay(target),
    // the marks of the progress bar of the game (frames)
    setMarkers: (frames) => {
      const game = getInstance?.()
      if (game && typeof game.setReplayMarkers === 'function') {
        game.setReplayMarkers(frames)
      }
    },
    // the comment shown in the game, over its controls: { time, author, text, more } or null
    setComment: (comment) => {
      const game = getInstance?.()
      if (game && typeof game.setReplayComment === 'function') {
        game.setReplayComment(comment)
      }
    },
  }
}
