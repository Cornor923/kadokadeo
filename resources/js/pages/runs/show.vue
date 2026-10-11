<script setup>
const route = useRoute()
const { isLoading, fetchRun } = useRuns()
const runId = route.params.id
const run = ref(null)

fetchRun(runId).then((data) => {
  run.value = data.data
})

// the replay is played by the version of the game it was recorded with (run.gamedata)
const replayGame = computed(() => run.value && { ...run.value.game, gamedata: run.value.gamedata ?? run.value.game.gamedata })
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


    <div class="max-w-full w-fit max-h-full h-fit m-auto overflow-y-auto pt-5">
      <div class="flex flex-col">
        <div class="relative gameint1 mx-auto max-w-full! shrink-0" :class="[run.game.is_arkadeo ? 'aspect-arkadeo' : 'aspect-kadokado']">
          <GamesGameScript
            :game="run.game"
            :args="{
              replayData: run.replay,
              seed: run.seed,
              contractScore: run.contract_score,
              contractPoints: run.contract_points,
              assetBase: replayGame.gamedata?.asset_base ?? undefined,
            }"
            :game-width="300"
            :game-height="320"
          />
        </div>
      </div>
    </div>
  </template>
</template>
