<script setup>
// a clan run: an attack, a defense or a mission step, on the page of the game (rules, paliers, ranking) with the score of
// the clan in the paliers. The game sends the action when a run begins: the run is bound to it on the server while its
// target is open, however long the page stays open (ClanRunService::pageAction).
const route = useRoute()
const authStore = useAuthStore()
const router = useRouter()
const clanStore = useClanStore()
const { fetchAction, playAgain, error } = useClans()
const { fetchGame } = useGames()

const action = ref(null)
const game = ref(null)
const result = ref(null)
// "Rejouer" in the game: false when the next run would be a normal run (the attack over...)
const countsAgain = ref(true)
// a mission step no longer open (completed, by the player or another member, or the mission over): no more runs here,
// the page goes back to the missions (as on KadoKado)
const closedMessage = ref(null)
const BACK_TO_MISSIONS_MS = 3000
let backTimer = null

fetchAction(route.params.action).then((data) => {
  action.value = data.data
  if (action.value.is_open) {
    fetchGame(action.value.game_id).then((gameData) => {
      game.value = gameData.data
    })
  }
})

const onGameFinished = (e) => {
  if (e.detail?.clan) {
    result.value = e.detail.clan
    clanStore.reload()
    // the next run of the page counts for the clan too while the target is open
    playAgain(action.value.id).then((data) => {
      countsAgain.value = data.data !== null
      if (data.closed) {
        closedMessage.value = data.closed
        game.value = null
        backTimer = setTimeout(() => router.push(backRoute.value), BACK_TO_MISSIONS_MS)
      } else if (data.data) {
        router.replace({ params: { action: data.data.id } })
        fetchAction(data.data.id).then((actionData) => {
          action.value = actionData.data
        })
      }
    })
  }
}
onMounted(() => window.evts.addEventListener('gameFinished', onGameFinished))
onUnmounted(() => {
  window.evts.removeEventListener('gameFinished', onGameFinished)
  clearTimeout(backTimer)
})

const backRoute = computed(() => {
  const id = action.value?.clan.id
  return action.value?.type === 'mission'
    ? { name: 'clans.missions', params: { id } }
    : { name: 'clans.status', params: { id } }
})
// the score to beat of a defense or of an improvement, the score to reach of a mission step, in the paliers of the game
const goals = computed(() => {
  const target = action.value?.target
  if (!target?.score) {
    return []
  }
  if (action.value.type === 'mission') {
    return [{ score: target.score, img: '/gfx/clan/clan_mission_points.png', alt: `Étape de la mission ${target.mission}` }]
  }
  return action.value.is_improvement
    ? [{ score: target.score + 1, img: '/gfx/clan/atksmall.gif', alt: 'Améliorer votre attaque' }]
    : [{ score: target.score + 1, img: '/gfx/clan/defsmall.gif', alt: `Repousser l'attaque de ${target.attacker}` }]
})
const isSuccess = computed(() => ['launched', 'improved', 'repelled', 'completed'].includes(result.value?.result))
</script>

<template>
  <div class="relative min-h-48 px-2">
    <MessageError v-if="error">{{ error }}</MessageError>
    <Loader v-else-if="!action">Chargement ...</Loader>

    <template v-else>
      <KadoPageTitle class="mb-5">{{ action.type_label }}</KadoPageTitle>

      <template v-if="result">
        <MessageSuccess v-if="isSuccess">{{ result.message }}</MessageSuccess>
        <MessageError v-else>{{ result.message }}</MessageError>
        <p v-if="closedMessage" class="mx-2.5 my-4 text-center">
          {{ closedMessage }} Retour à la page des missions dans quelques secondes...
        </p>
        <p v-else class="mx-2.5 my-4 text-center text-sm">
          <template v-if="countsAgain">Si vous rejouez, votre nouvelle partie comptera aussi pour votre clan.</template>
          <template v-else>Si vous rejouez, ce sera une partie normale : elle ne comptera plus pour votre clan.</template>
        </p>
      </template>

      <MessageError v-if="!action.is_open && !result">
        Cette action de clan est terminée ou a expiré. Retournez sur la page de votre clan pour en lancer une nouvelle.
      </MessageError>
      <div v-else-if="!game && !result" class="relative min-h-48">
        <Loader>Chargement du jeu ...</Loader>
      </div>
      <template v-else-if="game">
        <KadoSectionTitle class="text-center">{{ game.name }}</KadoSectionTitle>
        <GamesGamePlayer :game="game" :goals="goals" :args="{ clanAction: action.id }" />
      </template>

      <div class="flex items-center gap-2 border-l-4 px-2 py-1" :class="action.type === 'attack' ? 'border-kado-pink-400 bg-kado-pink-50 text-kado-pink-400' : 'border-kado-teal-500 bg-kado-blue-50'">
        <img :src="action.type === 'attack' ? '/assets/img/gfx/icons/atk.gif' : action.type === 'defense' ? '/assets/img/gfx/icons/def.gif' : '/gfx/clan/clan_mission_points.png'" alt="" />
        <div>
          <template v-if="action.is_improvement">
            Améliorez votre attaque contre le clan <strong>{{ action.target.clan.name }}</strong> : votre score ne
            remplacera celui de l'attaque (<strong>{{ action.target.score }} pts</strong>) que s'il est meilleur.
          </template>
          <template v-else-if="action.type === 'attack'">
            Votre score deviendra une attaque du clan <strong>{{ action.clan.name }}</strong> contre le clan
            <strong>{{ action.target.clan.name }}</strong>. Faites le meilleur score possible !
          </template>
          <template v-else-if="action.type === 'defense'">
            Battez le score de <strong>{{ action.target.score }} pts</strong> de {{ action.target.attacker }}
            (clan {{ action.target.clan.name }}) pour repousser son attaque.
          </template>
          <template v-else>
            Mission {{ action.target.mission }} : atteignez <strong>{{ action.target.score }} pts</strong> pour réussir cette étape.
            Les parties des missions sont gratuites.
          </template>
        </div>
      </div>
      <p class="mx-2.5 my-4 text-center">
        <RouterLink :to="backRoute">Retour à la page du clan</RouterLink>
      </p>
      <p v-if="action.type !== 'mission' && authStore.user" class="mx-2.5 my-4 flex items-center justify-center gap-1 text-sm">
        <img src="/gfx/gemGreen.svg" alt="" class="w-4" />
        {{ authStore.user.clan_attack_games }} partie(s) d'attaque gratuite(s) aujourd'hui, puis
        <img src="/gfx/gemOrange.svg" alt="" class="w-4" />
        {{ authStore.user.clan_games }} partie(s) de clan achetée(s)
      </p>
    </template>
  </div>
</template>
