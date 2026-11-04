<script setup>
import KadoPoints from '@svg/k.svg'

const props = defineProps({
  game: { type: Object, required: true },
  isZoomed: { type: Boolean, default: false },
  // more paliers: [{ score, img, alt }] (a clan defense, a mission step...)
  goals: { type: Array, default: () => [] },
  // the tab open first (a clan run: the paliers)
  initialTab: { type: String, default: 'gameRules' },
})
const { isLoading, fetchScores } = useGames()
const authStore = useAuthStore()
const periodStore = usePeriodStore()
const leagueStore = useLeagueStore()
const achievementStore = useAchievementStore()

const scores = ref([])
const personalBestForPeriod = ref(null)
const personalBest = ref(null)
const worldsBest = ref(null)
const currentScore = ref(0)
const league = ref(null)
const leaguesScores = ref({})
const palliers = computed(() => {
  const s = []
  if (props.game.stars?.length > 2) {
    if (!personalBestForPeriod.value || personalBestForPeriod.value.score < props.game.stars[0]) {
      s.push({ score: props.game.stars[0], points: 0, img: '/gfx/iconGreenStar.gif', alt: 'Etoile verte' })
    }
    if (!personalBestForPeriod.value || personalBestForPeriod.value.score < props.game.stars[1]) {
      s.push({ score: props.game.stars[1], points: 0, img: '/gfx/iconOrangeStar.gif', alt: 'Etoile orange' })
    }
    if (!personalBestForPeriod.value || personalBestForPeriod.value.score < props.game.stars[2]) {
      s.push({ score: props.game.stars[2], points: 0, img: '/gfx/iconRedStar.gif', alt: 'Etoile rouge' })
    }
  }
  if (personalBestForPeriod.value) {
    s.push({ score: personalBestForPeriod.value.score, points: null, img: '/gfx/iconBlueArrow.gif', alt: 'Record période' })
  }
  const bestScore = scores.value?.[0]
  if (bestScore && bestScore.user?.etwin_id !== authStore.user?.etwin_id && league.value?.level === leagueStore.paradiseLeagueId) {
    s.push({ score: bestScore.score + 1, points: null, img: '/gfx/iconFeather.gif', alt: 'Plume de Piou' })
  }
  // keyed by league id; shown before the first run of the period too
  const leagueScore = league.value ? leaguesScores.value[league.value.id] : null
  // required_score null: nobody played in the league yet, only the stars count
  if (leagueScore && (!personalBestForPeriod.value || leagueScore.required_score === null || leagueScore.required_score > personalBestForPeriod.value.score)) {
    // the promotion also asks for a minimum star
    const minStarScore = props.game.stars?.[league.value.promotion_min_stars] ?? 0
    const score = Math.max((leagueScore.required_score ?? -1) + 1, minStarScore)
    s.push({ score, points: null, img: `/gfx/leagues/${league.value.level + 1}s.svg`, alt: 'Ligue supérieure', className: 'w-[18px] h-auto' })
  }
  s.push(...props.goals.map((goal) => ({ points: null, ...goal })))
  s.push({ score: 0, points: 0, img: '/gfx/iconContract.png', alt: 'Contrat' })
  s.sort((a, b) => b.score - a.score)
  return s
})
// record of the period, mine, of the world: the run being played beats them on screen
const records = computed(() =>
  [personalBestForPeriod, personalBest, worldsBest].map((record) => Math.max(record.value?.score ?? 0, currentScore.value)),
)
// the three hold in the panel (345px) up to 7 digits at the height of the GIFs (15px), smaller beyond
const recordSize = computed(() => {
  const digits = String(Math.max(...records.value)).length
  return digits <= 7 ? null : digits === 8 ? 13 : digits === 9 ? 12 : 10
})
const nextPallierIndex = computed(() => {
  return palliers.value.findLastIndex((p) => currentScore.value < p.score)
})
const notZoomedHiddenState = computed(() => (props.isZoomed ? '' : 'hidden'))

const refreshScores = () => {
  return fetchScores(props.game.id).then((data) => {
    scores.value = data.scores
    worldsBest.value = data.worlds_best
    personalBest.value = data.personal_best
    personalBestForPeriod.value = data.personal_best_for_period
    league.value = data.league ?? null
    leaguesScores.value = data.leagues_scores ?? {}
  })
}

const updateCurrentScore = (evt) => {
  if (evt.detail?.score != null) {
    currentScore.value = evt.detail.score
  }
}

// a run in the top 10 of the league of the player, a record of the game, a run taken out (App\Events\GameScoresChanged): the
// leaderboard again, a bit later (the players watching the game do not all ask at once). Polled only without the realtime
const refreshSoon = refetchSoon(refreshScores, { delay: 1000, jitter: 3000 })
const gameChannel = () => `games.${props.game.id}`
useChannel(gameChannel, {
  'scores.changed': (e) => {
    const samePeriod = !e.period_id || !periodStore.period || e.period_id === periodStore.period.id
    if (samePeriod && (!e.league_id || e.league_id === league.value?.id || e.world_best)) {
      refreshSoon()
    }
  },
}, { isPrivate: false, resync: refreshScores })
useChannel('site', { 'period.started': refetchSoon(refreshScores, { delay: 2000, jitter: 10000 }) }, { isPrivate: false })
usePolling(refreshScores, 1200000, { channel: gameChannel })

onMounted(() => {
  // window.evts.addEventListener('gameFinished', refreshScores)
  window.evts.addEventListener('score', updateCurrentScore)
})
onUnmounted(() => {
  // window.evts.removeEventListener('gameFinished', refreshScores)
  window.evts.removeEventListener('score', updateCurrentScore)
})

refreshScores()

const selectedTab = ref(props.initialTab)

const menus = [
  { id: 'gameRules', label: 'Règles', icon: '/gfx/iconGameRules.png' },
  { id: 'gameStars', label: 'Paliers', icon: '/gfx/iconGameStars.png' },
  { id: 'gameRanking', label: 'Classement', icon: '/gfx/iconGameRanking.png' },
  ...(achievementStore.enabled ? [{ id: 'achievements', label: 'Succès', icon: '/gfx/iconAchievements.png' }] : []),
]
</script>

<template>
  <div :class="{ 'grid @md:grid-cols-2': isZoomed }">
    <GamesGameSideTabs v-if="!isZoomed" v-model="selectedTab" :tabs="menus">
      <template #after="{ tab }">
        <img  v-if="tab.id === 'gameStars' && league"
              :src="`/gfx/leagues/${league.level}s.svg`"
              :alt="league.name"
              class="w-6 h-auto" />
      </template>
    </GamesGameSideTabs>

    <div>
      <GamesGameSideHeading v-if="isZoomed" class="my-2 text-center">Règles</GamesGameSideHeading>

      <article id="gameRules" class="m-2" :class="selectedTab === 'gameRules' ? '' : notZoomedHiddenState">
        <p class="my-2">{{ game.description ?? '[WIP description]' }}</p>
        <hr class="mx-auto my-2 w-[200px] border-t border-kado-blue-700" />
        <GamesGameControls :game="game" />
      </article>
    </div>

    <div>
      <GamesGameSideHeading v-if="isZoomed" class="my-2 flex justify-center">Paliers
        <img  v-if="league"
              :src="`/gfx/leagues/${league.level}s.svg`"
              :alt="league.name"
              class="w-6 h-auto" />
      </GamesGameSideHeading>

      <article id="gameStars" class="m-2" :class="selectedTab === 'gameStars' ? '' : notZoomedHiddenState">
        <KadoTable borderless
                   plain-header
                   rows="white"
                   class="w-full">
          <thead>
            <tr>
              <th scope="col">Record période</th>
              <th scope="col">Mon record</th>
              <th scope="col">Record du monde</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td v-for="(record, index) in records" :key="index">
                <Number :value="record" color="orange" :size="recordSize" />
              </td>
            </tr>
          </tbody>
        </KadoTable>

        <GamesGameSideHeading class="my-2 text-right">Objectifs</GamesGameSideHeading>
        <KadoTable borderless plain-header class="w-full">
          <thead>
            <tr>
              <th scope="col" class="w-7.5"></th>
              <th scope="col" class="text-left">Paliers</th>
              <th scope="col" class="text-right">Valeur</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(pallier, index) in palliers" :key="index" :class="{'opacity-35': nextPallierIndex < index}">
              <td>
                <img v-if="nextPallierIndex === index" src="/gfx/iconOrangeArrow.gif" alt="Prochain palier" />
              </td>
              <td class="text-left">
                <img :src="pallier.img"
                     :alt="pallier.alt"
                     :title="pallier.alt"
                     class="max-w-5"
                     :class="pallier.className"/>
                <Number :value="pallier.score" color="orange" />
              </td>
              <td class="text-right">
                <template v-if="pallier.points !== null">
                  <Number :value="pallier.points" color="green" />
                  <KadoPoints class="inline size-4.25" />
                </template>
              </td>
            </tr>
          </tbody>
        </KadoTable>
      </article>
    </div>

    <div>
      <GamesGameSideHeading v-if="isZoomed" class="my-2 text-center">Classement</GamesGameSideHeading>

      <article id="gameRanking" class="m-2" :class="selectedTab === 'gameRanking' ? '' : notZoomedHiddenState">
        <Loader v-if="isLoading">Chargement des scores...</Loader>
        <GamesGameScoreTable v-else :scores="scores" class="mx-auto" />
        <p class="my-2 text-center font-bold">
          <RouterLink :to="{ name: 'games.ranking', params: { id: game.id }, query: { period: periodStore.period?.id, league: league?.id } }">
            Classement de ce jeu
          </RouterLink>
        </p>
      </article>
    </div>

    <div v-if="achievementStore.enabled">
      <GamesGameSideHeading v-if="isZoomed" class="my-2 text-center">Succès</GamesGameSideHeading>

      <article id="achievements" class="m-2" :class="selectedTab === 'achievements' ? '' : notZoomedHiddenState">
        <Loader v-if="achievementStore.isLoading">Chargement des succès...</Loader>
        <template v-else>
          <GamesGameAchievements :game="game" />
        </template>
      </article>
    </div>
  </div>
</template>

