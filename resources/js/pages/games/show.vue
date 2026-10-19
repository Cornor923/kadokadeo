<script setup>
const { isLoading, error, fetchGame } = useGames()
const authStore = useAuthStore()
const route = useRoute()

const gameId = route.params.id

const game = ref(null)
const scores = ref([])
const personalBest = ref(null)
const personalBestForPeriod = ref(null)

fetchGame(gameId).then((data) => {
  game.value = data.data
  scores.value = data.leaderboard
  personalBest.value = data.personalBest
  personalBestForPeriod.value = data.personalBestForPeriod
})
</script>

<template>
  <div class="relative min-h-48">
    <Loader v-if="isLoading">Chargement ...</Loader>
    <template v-else-if="!game">
      <MessageError> Jeu introuvable. ({{ error }}) </MessageError>
    </template>
    <template v-else>
      <h1 class="center">{{ game.name }}</h1>
      <p v-if="authStore.user?.kado_games >= 0">
        Il vous reste {{ authStore.user.kado_games }} parties à jouer aujourd'hui
      </p>

      <GamesGamePlayer :game="game" />
    </template>
  </div>
</template>
