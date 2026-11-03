<script setup>
import KadoPoints from '@svg/k.svg'

const { isLoading: isRankingV1Loading, error: leaderboardError, fetchRankingV1 } = useCompetition()
const { isLoading: isFeathersLoading, error: feathersError, fetchFeathers } = useCompetition()
const { isLoading: isGamesLoading, error: gamesError, fetchGames } = useGames()
const route = useRoute()
const router = useRouter()
const leaderboard = ref([])
// the pages of the ranking V1, and the line of the player (shown above or below the page when it is on another one)
const leaderboardMeta = ref(null)
const myRanking = ref(null)
const feathersLeaderboard = ref([])
const games = ref([])
const selectedGameId = ref('')
const scoreInput = ref('')
// shared by both tabs, null: the current period
const selectedPeriod = ref(null)
const selectedPlayerId = ref(null)
const periodStore = usePeriodStore()

const currentPeriod = computed(() => periodStore.period?.id ?? null)
const isCurrentPeriod = computed(() => selectedPeriod.value === null)
const displayedPeriod = computed(() => selectedPeriod.value ?? currentPeriod.value)
const canGoPrevious = computed(() => displayedPeriod.value !== null && displayedPeriod.value > 1)
const periodLabel = computed(() => (isCurrentPeriod.value ? 'Période courante' : `Période ${selectedPeriod.value}`))
const page = computed(() => Number(route.query.page) || 1)
const pageRoute = (pageNumber) => ({ query: { ...route.query, page: pageNumber } })
const isMe = (player) => player.user.etwin_id === myRanking.value?.user.etwin_id
// the players of the page, and the player out of it: first if ranked before the page, last if after ("…" between)
const rankingRows = computed(() => {
  const rows = leaderboard.value.map((player) => ({ key: player.user.etwin_id, player }))
  const me = myRanking.value
  if (!me || !rows.length || leaderboard.value.some(isMe)) return rows
  const meRow = { key: me.user.etwin_id, player: me }
  return me.rank < leaderboard.value[0].rank
    ? [meRow, { key: 'gap', gap: true }, ...rows]
    : [...rows, { key: 'gap', gap: true }, meRow]
})
const selectedPlayer = computed(() => rankingRows.value.find((row) => row.player?.user.etwin_id === selectedPlayerId.value)?.player ?? null)

function togglePlayerDetails(event) {
  const playerId = event.currentTarget.dataset.playerId
  selectedPlayerId.value = selectedPlayerId.value === playerId ? null : playerId
}

// (an answer for a page or a period asked before is ignored)
let leaderboardRequest = 0
function loadLeaderboard() {
  selectedPlayerId.value = null
  const current = ++leaderboardRequest
  fetchRankingV1(selectedPeriod.value, page.value)
    .then((data) => {
      if (current !== leaderboardRequest) return
      leaderboard.value = data.data
      leaderboardMeta.value = data.meta
      myRanking.value = data.me
    })
    .catch(() => null)
}

watch(page, loadLeaderboard)

let feathersRequest = 0
function loadFeathersLeaderboard() {
  const current = ++feathersRequest
  fetchFeathers(selectedPeriod.value)
    .then((data) => {
      if (current !== feathersRequest) return
      feathersLeaderboard.value = data
    })
    .catch(() => null)
}

// another period: from its first page (the watch of the page loads the ranking when it changes)
function loadLeaderboards() {
  if (page.value > 1) {
    router.replace({ query: { ...route.query, page: undefined } })
  } else {
    loadLeaderboard()
  }
  loadFeathersLeaderboard()
}

function goPrevious() {
  if (!canGoPrevious.value) return
  selectedPeriod.value = displayedPeriod.value - 1
  loadLeaderboards()
}

function goNext() {
  if (isCurrentPeriod.value) return
  const next = selectedPeriod.value + 1
  // Si on atteint la période courante, on repasse en mode "courante"
  selectedPeriod.value = currentPeriod.value === null || next >= currentPeriod.value ? null : next
  loadLeaderboards()
}

loadLeaderboard()
loadFeathersLeaderboard()

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
        <KadoPageTitle class="mb-5">Le classement V1</KadoPageTitle>

        <CompetitionPeriodNavigator
          :label="periodLabel"
          :can-go-previous="canGoPrevious"
          :can-go-next="!isCurrentPeriod"
          :disabled="isRankingV1Loading"
          @previous="goPrevious"
          @next="goNext"
        />

        <section class="mx-2 mb-4 grid gap-3 border border-kado-teal-500 p-3 md:grid-cols-3">
          <KadoSectionTitle class="col-span-full">Calculateur 1500</KadoSectionTitle>
          <label for="score-game" class="flex flex-col gap-1">
            Jeu
            <select id="score-game"
                    v-model="selectedGameId"
                    :disabled="isGamesLoading || !!gamesError"
                    class="min-h-10 border border-kado-teal-500 bg-white px-2">
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
                   class="min-h-10 border border-kado-teal-500 bg-white px-2" />
          </label>
          <label for="score-1500" class="flex flex-col gap-1">
            Score en mode 1500
            <input id="score-1500"
                   :value="scoreOn1500"
                   type="text"
                   readonly
                   class="min-h-10 border border-kado-teal-500 bg-kado-blue-50 px-2" />
          </label>
          <MessageError v-if="gamesError" class="md:col-span-full">Error: {{ gamesError }}</MessageError>
        </section>

        <Loader v-if="isRankingV1Loading">Chargement du classement...</Loader>
        <MessageError v-else-if="leaderboardError">Error: {{ leaderboardError }}</MessageError>
        <div v-else class="px-8 sm:px-16">
          <KadoTable class="w-full">
            <thead>
              <tr class="text-kado-orange-500 uppercase text-sm *:px-2 *:text-right">
                <th>Rang</th>
                <th class="text-left">Joueur</th>
                <th>Points</th>
              </tr>
            </thead>
            <tbody>
              <template v-for="row in rankingRows" :key="row.key">
                <tr v-if="row.gap" aria-hidden="true">
                  <td colspan="3" class="text-center text-kado-slate-400">…</td>
                </tr>
                <tr
                  v-else
                  class="cursor-pointer transition-colors hover:bg-kado-blue-50"
                  :class="{ 'bg-kado-blue-50': selectedPlayerId === row.player.user.etwin_id, 'font-bold': isMe(row.player) }"
                  tabindex="0"
                  role="button"
                  :data-player-id="row.player.user.etwin_id"
                  :aria-expanded="selectedPlayerId === row.player.user.etwin_id"
                  @click="togglePlayerDetails"
                  @keydown.enter.prevent="togglePlayerDetails"
                  @keydown.space.prevent="togglePlayerDetails"
                >
                  <td class="text-right">{{ row.player.rank }}</td>
                  <td class="text-left">{{ row.player.user.display_name }}</td>
                  <td class="text-right"><Number color="blue" :value="row.player.score" /></td>
                </tr>
                <tr v-if="!row.gap && selectedPlayerId === row.player.user.etwin_id">
                  <td colspan="3" class="px-4 py-3 text-left">
                    <div class="rounded border border-kado-teal-500 bg-white p-3">
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
          </KadoTable>
          <NavPagination v-if="leaderboardMeta"
                         :current-page="leaderboardMeta.current_page"
                         :last-page="leaderboardMeta.last_page"
                         :to="pageRoute" />
        </div>
      </div>

      <div v-else>
        <KadoPageTitle class="mb-5">Poids plumes</KadoPageTitle>
        <CompetitionPeriodNavigator
          :label="periodLabel"
          :can-go-previous="canGoPrevious"
          :can-go-next="!isCurrentPeriod"
          :disabled="isFeathersLoading"
          @previous="goPrevious"
          @next="goNext"
        />
        <p class="mx-2 my-4 text-center text-sm">
          Les joueurs ayant le plus de plumes se partagent le jackpot. Les autres joueurs ayant au moins 2 plumes se partagent
          à parts égales une récompense supplémentaire.
          <template v-if="isCurrentPeriod">Les récompenses de la période courante sont potentielles, elles sont versées à sa clôture.</template>
        </p>

        <Loader v-if="isFeathersLoading">Chargement du classement...</Loader>
        <MessageError v-else-if="feathersError">Error: {{ feathersError }}</MessageError>
        <div v-else class="px-8 sm:px-16">
          <KadoTable class="w-full">
            <thead>
              <tr class="text-kado-orange-500 uppercase text-sm *:px-2 *:text-right">
                <th>Rang</th>
                <th class="text-left">Joueur</th>
                <th>Plumes</th>
                <th>{{ isCurrentPeriod ? 'Récompense potentielle' : 'Récompense' }}</th>
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
                      v-for="(featherIndex, index) in player.feathers_count"
                      :key="featherIndex"
                      src="/gfx/iconFeather.gif"
                      alt=""
                      aria-hidden="true"
                      class="feather-icon size-4"
                      :style="{ marginLeft: index === 0 ? '0' : '-8px', zIndex: index + 1 }"
                    />
                    <span class="sr-only">{{ player.feathers_count }} plume(s)</span>
                  </span>
                </td>
                <td class="text-right whitespace-nowrap">
                  <template v-if="player.reward > 0">
                    <Number :value="player.reward" color="green" />
                    <KadoPoints class="inline size-4.25" />
                  </template>
                </td>
              </tr>
            </tbody>
          </KadoTable>
        </div>
      </div>
    </template>
  </NavTabs>
</template>
