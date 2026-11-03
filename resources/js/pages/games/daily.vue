<script setup>
const dailyGameStore = useDailyGameStore()
const game = toRef(dailyGameStore, 'game')

const waitAndRefresh = () => {
  setTimeout(() => {
    dailyGameStore.fetchScores()
  }, 2000)
}

// a run in the top 10 of the day, a run taken out (App\Events\DailyScoresChanged): polled only without the realtime
useChannel('daily', { 'scores.changed': refetchSoon(dailyGameStore.fetchScores, { delay: 1000, jitter: 3000 }) }, { isPrivate: false, resync: dailyGameStore.fetchScores })
usePolling(dailyGameStore.fetchScores, 1200000, { channel: 'daily' })

onMounted(() => {
  window.evts.addEventListener('gameFinished', waitAndRefresh)
  dailyGameStore.fetchDailyGameIfNecessary()
})
onUnmounted(() => {
  window.evts.removeEventListener('gameFinished', waitAndRefresh)
})
</script>

<template>
  <div>
    <GamesDailyGameBlock class="mt-4" />

    <div class="relative">
      <Loader v-if="dailyGameStore.isScoresLoading">Chargement des scores...</Loader>
      <KadoSectionTitle>Scores</KadoSectionTitle>
      <GamesGameScoreTable :scores="dailyGameStore.scores" />
    </div>

    <div v-if="dailyGameStore.isDailyGameLoading || !game" class="relative min-h-48">
      <Loader>Chargement ...</Loader>
    </div>
    <div v-else class="relative">
      <KadoSectionTitle>{{ game.name }}</KadoSectionTitle>
      <GamesGameScript :game="game"
                       :args="{ isDaily: true }"
                       :game-width="600"
                       :game-height="640" />
    </div>
  </div>
</template>
