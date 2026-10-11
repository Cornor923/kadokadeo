<script setup>
const { isLoading: isRankingV1Loading, error: leaderboardError, get: getLeaderboard } = useApi()
const { isLoading: isFeathersLoading, error: feathersError, get: getFeathersLeaderboard } = useApi()
const { isLoading: isGamesLoading, error: gamesError, fetchGames } = useGames()
const leaderboard = ref([])
const feathersLeaderboard = ref([])
const games = ref([])
const selectedGameId = ref('')
const scoreInput = ref('')
const currentPeriod = ref(null)
const selectedPeriod = ref(null)
const selectedPlayerId = ref(null)
const periodStore = usePeriodStore()

const isCurrentPeriod = computed(() => selectedPeriod.value === null)
const displayedPeriod = computed(() => selectedPeriod.value ?? currentPeriod.value)
const canGoPrevious = computed(() => displayedPeriod.value !== null && displayedPeriod.value > 1)
const selectedPlayer = computed(() => leaderboard.value.find((player) => player.user.etwin_id === selectedPlayerId.value) ?? null)

function togglePlayerDetails(event) {
  const playerId = event.currentTarget.dataset.playerId
  selectedPlayerId.value = selectedPlayerId.value === playerId ? null : playerId
}

function loadLeaderboard() {
  const url = isCurrentPeriod.value ? '/competition' : `/competition?period=${selectedPeriod.value}`
  selectedPlayerId.value = null

  getLeaderboard(url)
    .then((response) => {
      leaderboard.value = response.data

      if (isCurrentPeriod.value) {
        currentPeriod.value = periodStore?.period?.id || null
      }
    })
    .catch(() => null)
}

function goPrevious() {
  if (!canGoPrevious.value) return
  selectedPeriod.value = displayedPeriod.value - 1
  loadLeaderboard()
}

function goNext() {
  if (isCurrentPeriod.value) return
  const next = selectedPeriod.value + 1
  // Si on atteint la période courante, on repasse en mode "courante"
  selectedPeriod.value = next >= currentPeriod.value ? null : next
  loadLeaderboard()
}

loadLeaderboard()

getFeathersLeaderboard('/competition/poids-plumes')
  .then((response) => {
    feathersLeaderboard.value = response.data
  })
  .catch(() => null)

fetchGames()
  .then((response) => {
    games.value = response.data
  })
  .catch(() => null)

const selectedGame = computed(() => games.value.find((game) => String(game.id) === selectedGameId.value))
const scoreOn1500 = computed(() => {
  if (!selectedGame.value || scoreInput.value === '') return ''

  const score = Number(scoreInput.value)
  const [green, orange, red] = (selectedGame.value.stars ?? []).slice(0, 3).map(Number)
  const scoreRankV1 = Number(selectedGame.value.score_rankv1)
  if (![score, green, orange, red, scoreRankV1].every(Number.isFinite) || green <= 0 || orange <= green || red <= orange || scoreRankV1 <= red) {
    return ''
  }
  if (score <= 0) return 0

  let convertedScore
  if (score <= green) {
    convertedScore = (score / green) * 1000
  } else if (score <= orange) {
    convertedScore = 1000 + ((score - green) / (orange - green)) * 100
  } else if (score <= red) {
    convertedScore = 1100 + ((score - orange) / (red - orange)) * 50
  } else {
    convertedScore = 1150 + ((score - red) / (scoreRankV1 - red)) * 350
  }

  return Math.round(Math.min(convertedScore, 1500))
})
</script>

<template>
  <NavTabs :items="[
    { label: 'Ranking V1', value: 'rankingv1' },
    { label: 'Poids plumes', value: 'feathers' },
  ]">
    <template #panel="{ item }">
      <div v-if="item.value === 'rankingv1'">
        <h1 class="mt-0 text-center">Le classement V1</h1>

        <div class="mx-2 mb-4 flex items-center justify-center gap-4">
          <input
            type="button"
            value="Période précédente"
            class="pinkButton h-6 w-auto pt-px"
            :disabled="!canGoPrevious || isRankingV1Loading"
            @click="goPrevious"
          />

          <span class="font-bold">
            {{ isCurrentPeriod ? 'Période courante' : `Période ${selectedPeriod}` }}
          </span>

          <input
            v-if="!isCurrentPeriod"
            type="button"
            value="Période suivante"
            class="h-6 w-auto pt-px ml-4"
            :disabled="isRankingV1Loading"
            @click="goNext"
          />
        </div>

        <section class="mx-2 mb-4 grid gap-3 border border-kado-cyan-800 p-3 md:grid-cols-3">
          <h2 class="col-span-full">Calculateur 1500</h2>
          <label for="score-game" class="flex flex-col gap-1">
            Jeu
            <select id="score-game"
                    v-model="selectedGameId"
                    :disabled="isGamesLoading || !!gamesError"
                    class="min-h-10 border border-kado-cyan-800 bg-white px-2">
              <option value="">Sélectionner un jeu</option>
              <option v-for="game in games" :key="game.id" :value="String(game.id)">
                {{ game.name }}
              </option>
            </select>
          </label>
          <label for="score-input" class="flex flex-col gap-1">
            Votre score
            <input id="score-input"
                   v-model="scoreInput"
                   type="number"
                   min="0"
                   step="1"
                   inputmode="numeric"
                   class="min-h-10 border border-kado-cyan-800 bg-white px-2" />
          </label>
          <label for="score-1500" class="flex flex-col gap-1">
            Score en mode 1500
            <input id="score-1500"
                   :value="scoreOn1500"
                   type="text"
                   readonly
                   class="min-h-10 border border-kado-cyan-800 bg-kado-cyan-100 px-2" />
          </label>
          <MessageError v-if="gamesError" class="md:col-span-full">Error: {{ gamesError }}</MessageError>
        </section>

        <Loader v-if="isRankingV1Loading">Chargement du classement...</Loader>
        <MessageError v-else-if="leaderboardError">Error: {{ leaderboardError }}</MessageError>
        <div v-else class="px-8 sm:px-16">
          <table class="w-full">
            <thead>
              <tr class="text-kado-orange uppercase text-sm *:px-2 *:text-right">
                <th>Rang</th>
                <th class="text-left">Joueur</th>
                <th>Points</th>
              </tr>
            </thead>
            <tbody>
              <template v-for="player in leaderboard" :key="player.user.etwin_id">
                <tr
                  class="cursor-pointer transition-colors hover:bg-kado-cyan-100"
                  :class="{ 'bg-kado-cyan-100': selectedPlayerId === player.user.etwin_id }"
                  tabindex="0"
                  role="button"
                  :data-player-id="player.user.etwin_id"
                  :aria-expanded="selectedPlayerId === player.user.etwin_id"
                  @click="togglePlayerDetails"
                  @keydown.enter.prevent="togglePlayerDetails"
                  @keydown.space.prevent="togglePlayerDetails"
                >
                  <td class="text-right">{{ player.rank }}</td>
                  <td class="text-left">{{ player.user.display_name }}</td>
                  <td class="text-right"><Number color="blue" :value="player.score" /></td>
                </tr>
                <tr v-if="selectedPlayerId === player.user.etwin_id">
                  <td colspan="3" class="px-4 py-3 text-left">
                    <div class="rounded border border-kado-cyan-800 bg-white p-3">
                      <div class="mb-2 flex items-center justify-between gap-3">
                        <strong>{{ selectedPlayer.user.display_name }}</strong>
                        <button type="button"
                                class="cursor-pointer"
                                aria-label="Fermer le détail"
                                @click="selectedPlayerId = null">×</button>
                      </div>
                      <div class="grid gap-2 sm:grid-cols-2">
                        <div v-for="gameScore in selectedPlayer.games" :key="gameScore.game.id" class="flex justify-between gap-4">
                          <span>{{ gameScore.game.name }}</span>
                          <Number color="blue" :value="gameScore.score" />
                        </div>
                      </div>
                    </div>
                  </td>
                </tr>
              </template>
            </tbody>
          </table>
        </div>
      </div>

      <div v-else>
        <h1 class="mt-0 text-center">Poids plumes</h1>
        <p class="mb-4 text-center">Période courante</p>

        <Loader v-if="isFeathersLoading">Chargement du classement...</Loader>
        <MessageError v-else-if="feathersError">Error: {{ feathersError }}</MessageError>
        <div v-else class="px-8 sm:px-16">
          <table class="w-full">
            <thead>
              <tr class="text-kado-orange uppercase text-sm *:px-2 *:text-right">
                <th>Rang</th>
                <th class="text-left">Joueur</th>
                <th>Plumes</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="player in feathersLeaderboard" :key="player.user.etwin_id">
                <td class="text-right">{{ player.rank }}</td>
                <td class="text-left">
                  <RouterLink :to="{ name: 'profile.show', params: { id: player.user.etwin_id } }">
                    {{ player.user.display_name }}
                  </RouterLink>
                </td>
                <td class="text-right">
                  <span class="inline-flex items-center justify-end gap-0.5">
                    <img
                      v-for="(featherIndex, index) in Math.max(player.feathers_count, 3)"
                      :key="featherIndex"
                      src="/gfx/iconFeather.gif"
                      alt=""
                      aria-hidden="true"
                      class="feather-icon size-4"
                      :style="{ marginLeft: index === 0 ? '0' : '-8px', zIndex: index + 1 }"
                    />
                    <span class="sr-only">{{ Math.max(player.feathers_count, 3) }} plume(s)</span>
                  </span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </template>
  </NavTabs>
</template>
