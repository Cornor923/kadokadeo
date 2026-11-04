<script setup>
import KadoPoints from '@svg/k.svg'

// the side panel of the daily game: its rules, its ranking of the day and the one of the period (tabs, all of them when
// zoomed, as GameSide.vue)
defineProps({
  game: { type: Object, required: true },
  isZoomed: { type: Boolean, default: false },
})
const dailyGameStore = useDailyGameStore()
const kadoPerPoint = window.Kado.daily_kado_per_point

const tabs = [
  { id: 'rules', label: 'Règles', icon: '/gfx/iconGameRules.png' },
  { id: 'day', label: 'Jour', icon: '/gfx/iconGameRanking.png' },
  { id: 'period', label: 'Période', icon: '/gfx/iconGameStars.png' },
]
const selectedTab = ref('day')
</script>

<template>
  <div :class="{ 'grid @md:grid-cols-2': isZoomed }">
    <GamesGameSideTabs v-if="!isZoomed" v-model="selectedTab" :tabs="tabs" />

    <div>
      <GamesGameSideHeading v-if="isZoomed" class="my-2 text-center">Règles</GamesGameSideHeading>

      <article class="m-2" :class="{ hidden: !isZoomed && selectedTab !== 'rules' }">
        <p class="my-2">{{ game.description ?? '[WIP description]' }}</p>
        <hr class="mx-auto my-2 w-[200px] border-t border-kado-blue-700" />
        <GamesGameControls :game="game" />
      </article>
    </div>

    <div>
      <GamesGameSideHeading v-if="isZoomed" class="my-2 text-center">Classement du jour</GamesGameSideHeading>

      <article class="relative m-2" :class="{ hidden: !isZoomed && selectedTab !== 'day' }">
        <Loader v-if="dailyGameStore.isScoresLoading">Chargement des scores...</Loader>
        <GamesGameScoreTable v-if="dailyGameStore.scores.length" :scores="dailyGameStore.scores" />
        <p v-else class="my-2 text-center italic">Aucun score pour l'instant.</p>
      </article>
    </div>

    <div>
      <GamesGameSideHeading v-if="isZoomed" class="my-2 text-center">Classement de la période</GamesGameSideHeading>

      <article class="relative m-2" :class="{ hidden: !isZoomed && selectedTab !== 'period' }">
        <Loader v-if="dailyGameStore.isStandingsLoading">Chargement du classement...</Loader>
        <p class="my-2 text-center">
          1 point = <Number :value="kadoPerPoint" color="green" /> <KadoPoints class="inline size-4.25" />, versés à la fin de la période
        </p>
        <GamesDailyStandingsTable v-if="dailyGameStore.standings.length" :standings="dailyGameStore.standings" />
        <p v-else class="my-2 text-center italic">Aucun point pour l'instant.</p>
      </article>
    </div>
  </div>
</template>
