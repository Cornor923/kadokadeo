<script setup>
const route = useRoute()
const { isLoading, fetchRun } = useRuns()
const { fetchComments, recordView } = useRunComments()
const runId = route.params.id
const run = ref(null)

fetchRun(runId).then((data) => {
  run.value = data.data
})

// the replay is played by the version of the game it was recorded with (run.gamedata)
const replayGame = computed(() => run.value && { ...run.value.game, gamedata: run.value.gamedata ?? run.value.game.gamedata })

// the replay being watched (frame shown, paused, seek), followed on the client only
const gameScript = ref(null)
const gameBox = ref(null)
const clock = useReplayClock(() => gameScript.value?.getInstance())

// COMMENTS: all of them at once (their number is limited by the server), again after a change
const comments = ref([])
const canComment = ref(false)
const limits = ref({ max_length: 280, view_after_seconds: 10 })
const reasons = ref([])

const loadComments = () => fetchComments(runId).then((data) => {
  comments.value = data.data
  canComment.value = data.viewer.can_comment
  limits.value = data.limits
  reasons.value = data.report_reasons
  if (run.value) {
    run.value.comments_count = data.data.filter((comment) => !comment.is_deleted).length
  }
})
loadComments()

// the comments with a mark in the progress bar of the game (in its order: the index of the event "replayMarker")
const marked = computed(() => comments.value.filter((comment) => !comment.parent_id && !comment.is_deleted))
watch(marked, (list) => clock.setMarkers(list.map((comment) => comment.frame)))

const onGameMounted = () => {
  clock.setMarkers(marked.value.map((comment) => comment.frame))
  clock.start()
}

const hovered = ref(-1)
const onMarker = (event) => {
  hovered.value = event.detail?.index ?? -1
}
onMounted(() => window.evts?.addEventListener('replayMarker', onMarker))
onBeforeUnmount(() => window.evts?.removeEventListener('replayMarker', onMarker))

// on a computer the comments are shown in the game, above its controls (on a phone: at the top of the screen)
const desktopQuery = window.matchMedia('(min-width: 1024px)')
const isDesktop = ref(desktopQuery.matches)
const onDesktopChange = (event) => {
  isDesktop.value = event.matches
}
onMounted(() => desktopQuery.addEventListener('change', onDesktopChange))
onBeforeUnmount(() => desktopQuery.removeEventListener('change', onDesktopChange))

const seek = (frame) => {
  clock.seek(frame)
  gameBox.value?.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
}

// VIEW: counted once the replay was really played long enough (not paused, the tab visible), once by page
const VIEW_KEY = `kado.replay-view.${runId}`
let watchedMs = 0
let lastTick = null
let viewSent = (() => {
  try {
    return sessionStorage.getItem(VIEW_KEY) === '1'
  } catch {
    return false
  }
})()
watch(clock.frame, (frame, previous) => {
  const now = performance.now()
  const playing = frame > previous && previous >= 0 && !clock.paused.value && !clock.seeking.value && !document.hidden
  if (playing && lastTick !== null) {
    watchedMs += Math.min(500, now - lastTick)
  }
  lastTick = now
  if (!viewSent && watchedMs >= limits.value.view_after_seconds * 1000) {
    viewSent = true
    try {
      sessionStorage.setItem(VIEW_KEY, '1')
    } catch {
      // private browsing: once by page
    }
    recordView(runId).then(() => {
      if (run.value) {
        run.value.views_count += 1
      }
    }).catch(() => {})
  }
})
</script>

<template>
  <template v-if="isLoading || !run">Chargement...</template>
  <template v-else>
    <h1 class="text-center">Replay</h1>
    <h2 class="m-0!">Vous regardez {{ run.user?.display_name }}</h2>
    <h2 class="m-0!">Score: {{ run.score }}</h2>
    <h2 class="m-0!">Jeu: {{ run.game.name }}</h2>
    <h2 class="m-0!">Date: {{ dayjs(run.completed_at).format('DD/MM/YYYY HH:mm') }}</h2>
    <h2 class="m-0!">Temps: {{ formatTime(run.play_time_seconds) }}</h2>
    <h2 class="m-0!">Vues: {{ run.views_count }} · Commentaires: {{ run.comments_count }}</h2>

    <div ref="gameBox" class="max-w-full w-fit max-h-full h-fit m-auto overflow-y-auto pt-5">
      <div class="flex flex-col">
        <div class="relative gameint1 mx-auto max-w-full! shrink-0" :class="[run.game.is_arkadeo ? 'aspect-arkadeo' : 'aspect-kadokado']">
          <GamesGameScript
            ref="gameScript"
            :game="replayGame"
            :args="{
              replayData: run.replay,
              seed: run.seed,
              contractScore: run.contract_score,
              contractPoints: run.contract_points,
              assetBase: replayGame.gamedata?.asset_base ?? undefined,
            }"
            :game-width="300"
            :game-height="320"
            @mounted="onGameMounted"
          />
          <RunsCommentsOverlay :comments="marked"
                               :frame="clock.frame.value"
                               :seeking="clock.seeking.value"
                               :hovered="hovered"
                               :in-game="isDesktop"
                               :hidden="!clock.commentsShown.value"
                               @change="clock.setComment" />
        </div>
      </div>
    </div>

    <section class="mx-auto mt-4 max-w-2xl space-y-2">
      <h3 class="m-0 border border-solid border-kado-green-600 bg-kado-green-500 bg-[url(/assets/img/gfx/gui/base/greenh2_bg.jpg)] bg-[position:-25px_-5px] bg-no-repeat px-2 text-base tracking-widest text-kado-green-600">
        Commentaires
      </h3>
      <RunsCommentsComposer v-if="canComment"
                            :run-id="runId"
                            :frame="clock.frame.value"
                            :max-length="limits.max_length"
                            @created="loadComments" />
      <p v-else class="m-0 text-xs italic text-kado-slate-400">Les commentaires sont fermés pour le moment.</p>
      <RunsCommentsList :run-id="runId"
                        :comments="comments"
                        :can-comment="canComment"
                        :max-length="limits.max_length"
                        :reasons="reasons"
                        :frame="clock.frame.value"
                        @seek="seek"
                        @changed="loadComments" />
    </section>
  </template>
</template>
