<script setup>
import KadoPoints from '@svg/k.svg'

const props = defineProps({
  game: { type: Object, required: true },
  isZoomed: { type: Boolean, default: false },
})
const { isLoading, get } = useApi()
const authStore = useAuthStore()
const periodStore = usePeriodStore()
const leagueStore = useLeagueStore()
const achievementStore = useAchievementStore()
let intervalId = null

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
  s.push({ score: 0, points: 0, img: '/gfx/iconContract.png', alt: 'Contrat' })
  s.sort((a, b) => b.score - a.score)
  return s
})
const nextPallierIndex = computed(() => {
  return palliers.value.findLastIndex((p) => currentScore.value < p.score)
})
const notZoomedHiddenState = computed(() => (props.isZoomed ? '' : 'hidden'))

const refreshScores = () => {
  return get(`/games/${props.game.id}/scores`).then((data) => {
    scores.value = data.data.scores
    worldsBest.value = data.data.worlds_best
    personalBest.value = data.data.personal_best
    personalBestForPeriod.value = data.data.personal_best_for_period
    league.value = data.data.league ?? null
    leaguesScores.value = data.data.leagues_scores ?? {}
  })
}

const updateCurrentScore = (evt) => {
  if (evt.detail?.score != null) {
    currentScore.value = evt.detail.score
  }
}

onMounted(() => {
  intervalId = setInterval(refreshScores, 1200000)
  window.evts.addEventListener('gameFinished', refreshScores)
  window.evts.addEventListener('score', updateCurrentScore)
})
onUnmounted(() => {
  clearInterval(intervalId)
  window.evts.removeEventListener('gameFinished', refreshScores)
  window.evts.removeEventListener('score', updateCurrentScore)
})

refreshScores()

const selectedTab = ref('gameRules')

const menus = [
  { id: 'gameRules', label: 'Règles', icon: '/gfx/iconGameRules.png' },
  { id: 'gameStars', label: 'Paliers', icon: '/gfx/iconGameStars.png' },
  { id: 'gameRanking', label: 'Classement', icon: '/gfx/iconGameRanking.png' },
  ...(achievementStore.enabled ? [{ id: 'achievements', label: 'Succès', icon: '/gfx/iconAchievements.png' }] : []),
]
</script>

<template>
  <div :class="{ 'grid @md:grid-cols-2': isZoomed }">
    <nav v-if="!isZoomed">
      <ul class="flex items-stretch">
        <li v-for="menu in menus"
            :key="menu.id"
            @click="selectedTab = menu.id"
            class="flex items-center justify-center text-center gap-1 pt-0.5 cursor-pointer h-7 px-2 @md:flex-1"
            :class="selectedTab === menu.id ? 'flex-1 bg-kado-cream borderactive text-kado-orange font-bold' : 'text-kado-blue bordernormal bg-kado-cyan-700/10 hover:bg-kado-cyan-200 hover:text-kado-orange hover:pt-1'"
            :title="menu.label">
          <img v-if="menu.icon" :src="menu.icon" :alt="menu.label" />
          <div class="overflow-hidden" :class="selectedTab === menu.id ? 'w-full' : 'w-0 @md:w-full'">{{ menu.label }}</div>
          <img  v-if="menu.id === 'gameStars' && league"
                :src="`/gfx/leagues/${league.level}s.svg`"
                :alt="league.name"
                class="w-6 h-auto" />
        </li>
      </ul>
    </nav>

    <div>
      <h3 v-if="isZoomed" class="text-center">Règles</h3>

      <article id="gameRules" :class="selectedTab === 'gameRules' ? '' : notZoomedHiddenState">
        <p>{{ game.description ?? '[WIP description]' }}</p>
        <hr />
        <GamesGameControls :game="game" />
      </article>
    </div>

    <div>
      <h3 v-if="isZoomed" class="flex justify-center">Paliers
        <img  v-if="league"
              :src="`/gfx/leagues/${league.level}s.svg`"
              :alt="league.name"
              class="w-6 h-auto" />
      </h3>

      <article id="gameStars" :class="selectedTab === 'gameStars' ? '' : notZoomedHiddenState">
        <table class="border-0 **:border-0 whiteFirst">
          <thead>
            <tr class="noBackground">
              <th scope="col">Record période</th>
              <th scope="col">Mon record</th>
              <th scope="col">Record du monde</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td scope="row">
                <Number :value="Math.max(personalBestForPeriod?.score ?? 0, currentScore)" color="orange" />
              </td>
              <td>
                <Number :value="Math.max(personalBest?.score ?? 0, currentScore)" color="orange" />
              </td>
              <td>
                <Number :value="Math.max(worldsBest?.score ?? 0, currentScore)" color="orange" />
              </td>
            </tr>
          </tbody>
        </table>

        <h3 class="text-right">Objectifs</h3>
        <table class="gameGoals border-0 **:border-0">
          <thead>
            <tr class="noBackground">
              <th scope="col" style="width:30px;"></th>
              <th scope="col" class="textLeft">Paliers</th>
              <th scope="col" class="textRight">Valeur</th>
            </tr>
          </thead>
          <tbody class="twoColoured">
            <tr v-for="(pallier, index) in palliers" :key="index" :class="{'opacity-35': nextPallierIndex < index}">
              <td scope="row">
                <img v-if="nextPallierIndex === index" src="/gfx/iconOrangeArrow.gif" alt="Prochain palier" />
              </td>
              <td class="textLeft">
                <img :src="pallier.img" :alt="pallier.alt" :class="pallier.className" /> <Number :value="pallier.score" color="orange" />
              </td>
              <td class="textRight">
                <template v-if="pallier.points !== null">
                  <Number :value="pallier.points" color="green" />
                  <KadoPoints class="inline size-[17px]" />
                </template>
              </td>
            </tr>
          </tbody>
        </table>
      </article>
    </div>

    <div>
      <h3 v-if="isZoomed" class="text-center">Classement</h3>

      <article id="gameRanking" :class="selectedTab === 'gameRanking' ? '' : notZoomedHiddenState">
        <Loader v-if="isLoading">Chargement des scores...</Loader>
        <GamesGameScoreTable v-else :scores="scores" style="margin:0 auto" />
        <p class="center bold">
          <RouterLink :to="{ name: 'games.ranking', params: { id: game.id }, query: { period: periodStore.period?.id, league: league?.id } }">
            Classement de ce jeu
          </RouterLink>
        </p>
      </article>
    </div>

    <div v-if="achievementStore.enabled">
      <h3 v-if="isZoomed" class="text-center">Succès</h3>

      <article id="achievements" :class="selectedTab === 'achievements' ? '' : notZoomedHiddenState">
        <Loader v-if="achievementStore.isLoading">Chargement des succès...</Loader>
        <template v-else>
          <GamesGameAchievements :game="game" />
        </template>
      </article>
    </div>
  </div>
</template>

<style scoped>
@reference "@/../css/app.css";
article {
  margin: 8px;
}

hr {
  width: 200px;
  margin: 8px auto;
  border: 0;
  border-top: 1px solid var(--color-kado-blue);
}

p {
  margin: 8px 0;
}

h3 {
  width: 100%;
  margin: 8px 0 8px 0;
  font-weight: bold;
  font-size: 1.3em;
  color: var(--color-kado-blue);
  border-bottom: 3px double var(--color-kado-blue);
  letter-spacing: 1px;
}

.bordernormal {
  @apply border-t-2 border-t-white
  border-l border-l-white
  border-r border-r-kado-cyan-750
  border-b border-b-kado-cyan-750
  hover:border-t-2 hover:border-t-kado-cyan-750
  hover:border-l hover:border-l-kado-cyan-750
  hover:border-r hover:border-r-white
  hover:border-b hover:border-b-white;
}

.borderactive {
  @apply border-t-0
  border-l-0
  border-r-0
  border-b border-b-kado-orange;
}
</style>
