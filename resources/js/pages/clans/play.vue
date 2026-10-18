<script setup>
// a clan run: an attack, a defense or a mission step, on the page of the game (rules, paliers, ranking) with the score of
// the clan in the paliers. The next run of the game is bound to it on the server.
const route = useRoute()
const authStore = useAuthStore()
const router = useRouter()
const clanStore = useClanStore()
const { fetchAction, playAgain, error } = useClans()
const { fetchGame } = useGames()

const action = ref(null)
const game = ref(null)
const result = ref(null)
// "Rejouer" in the game: false when the next run would be a normal run (the step completed, the attack over...)
const countsAgain = ref(true)

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
      if (data.data) {
        router.replace({ params: { action: data.data.id } })
        fetchAction(data.data.id).then((actionData) => {
          action.value = actionData.data
        })
      }
    })
  }
}
onMounted(() => window.evts.addEventListener('gameFinished', onGameFinished))
onUnmounted(() => window.evts.removeEventListener('gameFinished', onGameFinished))

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
      <h1 class="mt-0 text-center">{{ action.type_label }}</h1>

      <template v-if="result">
        <MessageSuccess v-if="isSuccess">{{ result.message }}</MessageSuccess>
        <MessageError v-else>{{ result.message }}</MessageError>
        <p class="text-center text-sm">
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
        <h2 class="text-center">{{ game.name }}</h2>
        <GamesGamePlayer :game="game" :goals="goals" />
      </template>

      <div class="flex items-center gap-2 border-l-4 px-2 py-1" :class="action.type === 'attack' ? 'border-kado-pink-400 bg-[#ffe3ec] text-kado-pink-400' : 'border-kado-cyan-800 bg-kado-cyan-100'">
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
      <p class="text-center">
        <RouterLink :to="backRoute">Retour à la page du clan</RouterLink>
      </p>
      <p v-if="action.type !== 'mission' && authStore.user" class="flex items-center justify-center gap-1 text-sm">
        <img src="/gfx/gemGreen.svg" alt="" class="w-4" />
        {{ authStore.user.clan_attack_games }} partie(s) d'attaque gratuite(s) aujourd'hui, puis
        <img src="/gfx/gemOrange.svg" alt="" class="w-4" />
        {{ authStore.user.clan_games }} partie(s) de clan achetée(s)
      </p>
    </template>
  </div>
</template>
