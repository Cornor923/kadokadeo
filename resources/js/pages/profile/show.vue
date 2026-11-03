<script setup>
import GreenStar from '@svg/greenStar.svg'
import OrangeStar from '@svg/orangeStar.svg'
import RedStar from '@svg/redStar.svg'

const route = useRoute()
const authStore = useAuthStore()
// the player of the page: the one of the url, or the player logged in (/profile)
const playerId = computed(() => route.params.id ?? authStore.user?.etwin_id)
const isMe = computed(() => playerId.value === authStore.user?.etwin_id)
const { isLoading: isHistoryLoading, error: historyError, results: historyResults, hasNextPage: historyHasNextPage, loadMore: loadMoreHistory } = useUserGameHistory(playerId)

const { fetchProfile, isLoading, error } = useProfile()
const { isLoading: isRecordsLoading, error: recordsError, fetchRecords } = useProfile()
const leagueStore = useLeagueStore()
const achievementStore = useAchievementStore()

const profile = ref(null)
const playerRecords = ref([])
const rankingSort = ref({ key: 'game', direction: 'asc' })

const sortedRankingRuns = computed(() => {
  const sorters = {
    level: (leftRun, rightRun) => (leftRun.league_id ?? 0) - (rightRun.league_id ?? 0),
    position: (leftRun, rightRun) => (leftRun.league_rank ?? 0) - (rightRun.league_rank ?? 0),
    game: (leftRun, rightRun) => leftRun.game.name.localeCompare(rightRun.game.name),
    score: (leftRun, rightRun) => leftRun.score - rightRun.score,
  }
  const direction = rankingSort.value.direction === 'asc' ? 1 : -1

  return [...(profile.value?.best_period_runs ?? [])].sort((leftRun, rightRun) => {
    return direction * sorters[rankingSort.value.key](leftRun, rightRun)
  })
})

function sortRankingsBy(key) {
  if (rankingSort.value.key === key) {
    rankingSort.value.direction = rankingSort.value.direction === 'asc' ? 'desc' : 'asc'
  } else {
    rankingSort.value = { key, direction: 'asc' }
  }
}

// the profile and the records (the stats) of the player, loaded again when the page shows another one; an answer for
// the previous player is ignored
let request = 0
watch(playerId, (id) => {
  const current = ++request
  profile.value = null
  playerRecords.value = []
  if (!id) {
    return
  }
  fetchProfile(id).then((data) => {
    if (current === request) {
      profile.value = data
    }
  }).catch(() => {}) // (shown by error)
  fetchRecords(id).then((records) => {
    if (current === request) {
      playerRecords.value = records
    }
  }).catch(() => {}) // (shown by recordsError)
}, { immediate: true })

const starsByColor = computed(() => {
  return Object.values(profile.value.best_period_runs).reduce((acc, run) => {
    const star = getStarId(run)
    acc[star] = (acc[star] || 0) + 1
    return acc
  }, {})
})
const myStars = computed(() => {
  if (!profile.value) return 0
  return Object.values(profile.value.best_stars).reduce((sum, stars) => sum + (stars + 1), 0)
})
const barWidth = computed(() => {
  const maxStars = profile.value?.max_stars ?? 0.001
  return (myStars.value / maxStars) * 355
})

const gameCount = computed(() => profile.value?.max_stars / 3)
const leagueCount = computed(() => {
  if (!profile.value) return 0
  return Object.values(profile.value.current_leagues).reduce((acc, league) => {
    acc[league.id] = (acc[league.id] || 0) + 1
    return acc
  }, {})
})
const beginnerLeagueCount = computed(() => (leagueCount.value[1] || 0) + gameCount.value - Object.values(leagueCount.value).reduce((sum, count) => sum + count, 0))
const feathersCount = computed(() => {
  if (!profile.value) return 0
  return profile.value.best_period_runs.reduce((count, run) => run.league_rank === 1 && run.league_id === leagueStore.paradiseLeagueId ? count + 1 : count, 0)
})

function getStarImage(run) {
  const { getStarFromScore } = useGameModel(run.game)
  return getStarFromScore(run.score)
}

function getStarId(run) {
  const { getStarIdFromScore } = useGameModel(run.game)
  return getStarIdFromScore(run.score)
}

function getProgressPercent(record) {
  if (record.current_score === null || record.score === null) return 0
  if (record.score <= 0) return record.current_score <= 0 ? 100 : 0
  return Math.min(100, Math.round((record.current_score / record.score) * 100))
}

const gameAchievements = computed(() => {
  return achievementStore.achievements?.reduce((acc, achievement) => {
    if (!acc[achievement.game.name]) {
      acc[achievement.game.name] = []
    }
    acc[achievement.game.name].push(achievement)
    return acc
  }, {})
})
</script>

<template>
  <NavTabs
    :items="[
      { label: 'moi', value: 'me' },
      { label: 'dernière période', value: 'last' },
      { label: 'stats', value: 'stats' },
    ]"
  >
    <template #panel="{ item }">
      <div>
        <div v-if="isLoading">Loading...</div>
        <MessageError v-else-if="error">Error: {{ error }}</MessageError>
        <div v-else-if="profile">
          <div v-if="item.value === 'me'" class="space-y-4">
            <KadoPageTitle>Profil de {{ profile.data.display_name }}</KadoPageTitle>
            <p v-if="!isMe" class="mx-2.5 text-center">
              <RouterLink :to="{ name: 'messages.new', query: { to: profile.data.display_name } }">
                <img src="/assets/img/gfx/icons/readedMail.gif" alt="" class="mr-1" />Envoyer un message à {{ profile.data.display_name }}
              </RouterLink>
            </p>
            <div v-if="feathersCount > 0" class="flex justify-center items-center gap-1 mb-4">
              <img v-for="i in feathersCount"
                   :key="i"
                   src="/gfx/iconFeather.gif"
                   alt="Plume de Piou"
                   class="inline-block" />
            </div>
            <KadoSectionTitle>Statut</KadoSectionTitle>

            <div class="grid md:grid-cols-2">
              <div class="grid grid-cols-3 justify-items-center">
                <div class="flex items-end">
                  <GreenStar class="size-20" />
                  <Number :value="`x${starsByColor[0] ?? 0}`" color="green" />
                </div>
                <div class="flex items-end">
                  <OrangeStar class="size-20" />
                  <Number :value="`x${starsByColor[1] ?? 0}`" color="orange" />
                </div>
                <div class="flex items-end">
                  <RedStar class="size-20" />
                  <Number :value="`x${starsByColor[2] ?? 0}`" color="pink" />
                </div>
              </div>
              <div class="grid grid-cols-3 justify-items-stretch items-center">
                <div class="col-span-3 grid grid-cols-2 gap-4 justify-items-center items-center">
                  <div class="text-center">
                    <img class="w-8 h-auto" src="/gfx/leagues/5s.svg" />
                    <Number :value="leagueCount[5] || '.'" />
                  </div>
                  <div class="text-center">
                    <img class="w-8 h-auto" src="/gfx/leagues/4s.svg" />
                    <Number :value="leagueCount[4] || '.'" />
                  </div>
                </div>
                <div class="text-center">
                  <img class="w-8 h-auto" src="/gfx/leagues/3s.svg" />
                  <Number :value="leagueCount[3] || '.'" />
                </div>
                <div class="text-center">
                  <img class="w-8 h-auto" src="/gfx/leagues/2s.svg" />
                  <Number :value="leagueCount[2] || '.'" />
                </div>
                <div class="text-center">
                  <img class="w-8 h-auto" src="/gfx/leagues/1s.svg" />
                  <Number :value="beginnerLeagueCount || '.'" />
                </div>
              </div>

              <div class="md:col-span-2 flex">
                <div class="mx-auto relative">
                  <img src="/gfx/maxiuser_bar_bg_disabled.gif" alt="Barre de progression du profil" class="w-[355px] h-[18px]" />
                  <div class="absolute top-0.5 h-[18px] overflow-hidden" :style="{ width: barWidth + 'px' }">
                    <div class="w-[355px] h-[18px] contrast-200 bg-gradient-to-r from-kado-gauge-violet via-kado-gauge-orange to-kado-gauge-green mask-[url('/gfx/maxiuser_bar_mask.png')]"></div>
                  </div>
                  <div class="absolute right-1.5 top-1.5 text-white text-2xs">{{ Math.floor(myStars / profile.max_stars * 100) }}</div>
                </div>
              </div>
            </div>

            <KadoSectionTitle>Classements</KadoSectionTitle>
            <div class="px-2">
              <KadoTable class="w-full">
                <thead>
                  <tr class="text-kado-orange-500 uppercase text-sm *:px-2 *:text-right">
                    <th :aria-sort="rankingSort.key === 'level' ? (rankingSort.direction === 'asc' ? 'ascending' : 'descending') : 'none'">
                      <button type="button" class="inline-flex items-center gap-1 cursor-pointer" @click="sortRankingsBy('level')">
                        Niveau <span aria-hidden="true">{{ rankingSort.key === 'level' ? (rankingSort.direction === 'asc' ? '▲' : '▼') : '' }}</span>
                      </button>
                    </th>
                    <th :aria-sort="rankingSort.key === 'position' ? (rankingSort.direction === 'asc' ? 'ascending' : 'descending') : 'none'">
                      <button type="button" class="inline-flex items-center gap-1 cursor-pointer" @click="sortRankingsBy('position')">
                        Position <span aria-hidden="true">{{ rankingSort.key === 'position' ? (rankingSort.direction === 'asc' ? '▲' : '▼') : '' }}</span>
                      </button>
                    </th>
                    <th :aria-sort="rankingSort.key === 'game' ? (rankingSort.direction === 'asc' ? 'ascending' : 'descending') : 'none'">
                      <button type="button" class="inline-flex items-center gap-1 cursor-pointer" @click="sortRankingsBy('game')">
                        Jeu <span aria-hidden="true">{{ rankingSort.key === 'game' ? (rankingSort.direction === 'asc' ? '▲' : '▼') : '' }}</span>
                      </button>
                    </th>
                    <th :aria-sort="rankingSort.key === 'score' ? (rankingSort.direction === 'asc' ? 'ascending' : 'descending') : 'none'">
                      <button type="button" class="inline-flex items-center gap-1 cursor-pointer" @click="sortRankingsBy('score')">
                        Score <span aria-hidden="true">{{ rankingSort.key === 'score' ? (rankingSort.direction === 'asc' ? '▲' : '▼') : '' }}</span>
                      </button>
                    </th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="run in sortedRankingRuns" :key="run.id">
                    <td>
                      <div class="flex items-center gap-1">
                        <img v-if="run.league_id" :src="`/gfx/leagues/${run.league_id}s.svg`" class="w-6 h-auto" />
                        <img v-if="profile.promotion_game_ids?.includes(run.game.id)"
                             src="/gfx/greenArrowUp.png"
                             alt="Qualifié pour la promotion"
                             title="Qualifié pour la ligue supérieure" />
                      </div>
                    </td>
                    <td class="text-right">
                      <Number color="orange" :value="run.league_rank" />
                    </td>
                    <td class="text-left">
                      <div class="flex items-center gap-2">
                        <component :is="getStarImage(run)" class="size-4" />
                        <RouterLink :to="{ name: 'games.show', params: { id: run.game.id } }">
                          {{ run.game.name }}
                        </RouterLink>
                      </div>
                    </td>
                    <td class="text-right">
                      <Number color="blue" :value="run.score" />
                    </td>
                  </tr>
                </tbody>
              </KadoTable>
            </div>

            <template v-if="achievementStore.enabled">
              <KadoSectionTitle>Succès</KadoSectionTitle>
              <div class="px-4" v-lazy-container="{ selector: 'img', attempt: 1 }">
                <div v-for="(gameAs, game) in gameAchievements" :key="game">
                  <h3 class="text-2xl font-semibold text-kado-blue-800">{{ game }}</h3>
                  <div class="flex flex-wrap gap-2 py-2">
                    <div v-for="ac in gameAs" :key="ac.id" class="flex flex-wrap">
                      <div class="relative"
                           v-for="level of ac.levels"
                           :key="level.id"
                           :title="`${level.title}\n${level.description}`"
                           :class="{'grayscale-90': ac.level_user_counts[level.level - 1] === 0 }"
                      >
                        <img :data-src="`/gfx/achievements/bg${ac.levels.length === 3 ? level.level - 1 : ''}.png`" class="size-10 justify-self-center"/>
                        <img
                          :data-src="level.icon"
                          data-loading="/gfx/achievements/loading.png"
                          data-error="/gfx/achievements/error.png"
                          class="absolute top-[2.5px] left-[2.5px] grid size-[35px] rounded-sm"
                        />
                      </div>
                    </div>
                  </div>

                </div>
              </div>
            </template>

            <KadoSectionTitle>Historique</KadoSectionTitle>
            <GamesGameScoreTable :show-pos="false"
                                 :show-player="false"
                                 show-game
                                 :scores="historyResults" />
            <div v-if="historyHasNextPage" class="mt-4 text-center">
              <button
                @click="loadMoreHistory()"
                :disabled="isHistoryLoading"
                class="py-2 text-kado-orange-500 underline cursor-pointer hover:text-kado-orange-700"
              >
                Charger plus de résultats
              </button>
              <Loader v-if="isHistoryLoading" />
              <MessageError v-else-if="historyError">{{ historyError }}</MessageError>
            </div>
          </div>
          <div v-else-if="item.value === 'last'">
            <ProfileLastPeriod :player-id="profile.data.etwin_id" :player-name="profile.data.display_name" :is-me="isMe" />
          </div>
          <div v-else-if="item.value === 'stats'">
            <KadoPageTitle class="mb-5">Records de {{ profile.data.display_name }}</KadoPageTitle>
            <Loader v-if="isRecordsLoading">Chargement des records...</Loader>
            <MessageError v-else-if="recordsError">Error: {{ recordsError }}</MessageError>
            <div v-else class="px-8 sm:px-16">
              <KadoTable class="w-full">
                <thead>
                  <tr class="text-kado-orange-500 uppercase text-sm *:px-2 *:text-center">
                    <th>Jeu</th>
                    <th>Score actuel</th>
                    <th>Record</th>
                    <th>Progression</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="record in playerRecords" :key="record.game.id">
                    <td class="text-left">
                      <div class="flex items-center gap-2">
                        <img v-if="record.league"
                             :src="`/gfx/leagues/${record.league.id}s.svg`"
                             :alt="record.league.name"
                             class="size-6 shrink-0 object-contain" />
                        <!-- (the history of the scores by period: the one of the player logged in) -->
                        <RouterLink v-if="isMe" :to="{ name: 'games.records', params: { id: record.game.id } }">
                          {{ record.game.name }}
                        </RouterLink>
                        <span v-else>{{ record.game.name }}</span>
                      </div>
                    </td>
                    <td class="text-left">
                      <div v-if="record.current_score !== null" class="inline-flex items-center justify-start gap-1">
                        <component :is="getStarImage({ game: record.game, score: record.current_score })" class="size-[25px] shrink-0" />
                        <Number color="green" :value="record.current_score" />
                      </div>
                    </td>
                    <td class="text-left">
                      <div v-if="record.score !== null" class="inline-flex items-center justify-start gap-1">
                        <component :is="getStarImage({ game: record.game, score: record.score })" class="size-[25px] shrink-0" />
                        <Number color="orange" :value="record.score" />
                      </div>
                    </td>
                    <td class="text-left">
                      <!-- the progress bar of KadoKado (div.percentBar): its tab holds the percentage, the green bar is
                           100 px long at 100 % -->
                      <div v-if="record.current_score !== null && record.score !== null"
                           role="progressbar"
                           :aria-label="`Progression du score de ${record.game.name}`"
                           aria-valuemin="0"
                           aria-valuemax="100"
                           :aria-valuenow="getProgressPercent(record)"
                           class="relative inline-block h-5 w-[106px] overflow-hidden bg-[url(/assets/img/gfx/gui/base/progress_bg.gif)] bg-no-repeat align-middle">
                        <span class="absolute top-0.5 right-3 text-[10px] leading-2.5">{{ getProgressPercent(record) }} %</span>
                        <div class="absolute bottom-0.5 left-0.5 h-[5px] bg-[url(/assets/img/gfx/gui/base/progress.gif)] bg-no-repeat transition-[width]" :style="{ width: `${getProgressPercent(record)}px` }"></div>
                      </div>
                    </td>
                  </tr>
                </tbody>
              </KadoTable>
            </div>
          </div>
        </div>
      </div>
    </template>
  </NavTabs>
</template>
