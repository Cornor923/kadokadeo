<script setup>
const dailyGameStore = useDailyGameStore()
const game = toRef(dailyGameStore, 'game')

const refresh = () => {
  dailyGameStore.fetchScores()
  dailyGameStore.fetchStandings()
}
const waitAndRefresh = () => {
  setTimeout(refresh, 2000)
}

// a run in the top 10 of the day, a run taken out (App\Events\DailyScoresChanged): polled only without the realtime
useChannel('daily', { 'scores.changed': refetchSoon(refresh, { delay: 1000, jitter: 3000 }) }, { isPrivate: false, resync: refresh })
useChannel('site', { 'period.started': refetchSoon(dailyGameStore.fetchStandings, { delay: 2000, jitter: 10000 }) }, { isPrivate: false })
usePolling(refresh, 1200000, { channel: 'daily' })

onMounted(() => {
  window.evts.addEventListener('gameFinished', waitAndRefresh)
  dailyGameStore.fetchDailyGameIfNecessary()
  dailyGameStore.fetchStandings()
})
onUnmounted(() => {
  window.evts.removeEventListener('gameFinished', waitAndRefresh)
})
</script>

<template>
  <div>
    <GamesDailyGameBlock class="mt-4" />

    <div v-if="dailyGameStore.isDailyGameLoading || !game" class="relative min-h-48">
      <Loader>Chargement ...</Loader>
    </div>
    <div v-else class="relative">
      <KadoSectionTitle>{{ game.name }}</KadoSectionTitle>
      <GamesGamePlayer :game="game"
                       :args="{ isDaily: true }"
                       zoom-key="isZoomedDaily"
                       daily>
        <template #side="{ isZoomed }">
          <GamesDailyGameSide class="overflow-y-auto overflow-x-hidden text-xs h-full"
                              :game="game"
                              :is-zoomed="isZoomed" />
        </template>
      </GamesGamePlayer>
    </div>
  </div>
</template>
