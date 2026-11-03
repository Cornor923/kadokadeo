<script setup>
const route = useRoute()
const router = useRouter()
const gameId = route.params.id
const { isLoading: isGameLoading, error: gameError, fetchGame } = useGames()
const { isLoading, error, period, league, results, hasNextPage, loadMore } = useGameRanking(gameId, {
  period: route.query.period || null,
  league: route.query.league || null,
})
const periodStore = usePeriodStore()
const leagueStore = useLeagueStore()
const game = ref(null)

fetchGame(gameId).then((data) => {
  game.value = data.data
})

watch(period, (newVal) => {
  router.push({ query: { ...route.query, period: newVal || undefined } })
})
watch(league, (newVal) => {
  router.push({ query: { ...route.query, league: newVal || undefined } })
})
</script>

<template>
  <Loader v-if="isGameLoading" />
  <div v-else-if="game" class="relative w-full">
    <KadoSectionTitle>Classement général de {{ game.name }}</KadoSectionTitle>

    <div class="flex gap-4 my-4 justify-center items-center">
      <select id="period" v-model="period">
        <option :value="null">Toutes les périodes</option>
        <option v-for="periodOption in periodStore.period?.id" :key="periodOption" :value="periodOption">
          Période {{ periodOption }}
        </option>
      </select>
      <select id="league" v-model="league">
        <option :value="null">Toutes les ligues</option>
        <option v-for="leagueOption in leagueStore.leagues" :key="leagueOption.level" :value="leagueOption.level">
          {{ leagueOption.name }}
        </option>
      </select>
    </div>

    <GamesGameScoreTable :scores="results" />
    <div v-if="hasNextPage" class="mt-4 text-center">
      <button
        @click="loadMore()"
        :disabled="isLoading"
        class="text-kado-orange-500 underline cursor-pointer hover:text-kado-orange-700"
      >
        Charger plus de résultats
      </button>
      <Loader v-if="isLoading" />
      <MessageError v-else-if="error">{{ error }}</MessageError>
    </div>
    <MessageError v-else-if="gameError">{{ gameError }}</MessageError>
  </div>
</template>
