<script setup>
import GreenStar from '@svg/greenStar.svg'
import KadoPoints from '@svg/k.svg'
import OrangeStar from '@svg/orangeStar.svg'
import RedStar from '@svg/redStar.svg'

// the last finished period of a player, as on KadoKado: the Kado points it brought at its close, the promotions in the
// leagues, the rankings; the buttons go through the older finished periods (App\Services\PeriodSummaryService)
const props = defineProps({
  // the etwin_id of the player and their name
  playerId: { type: String, required: true },
  playerName: { type: String, required: true },
  isMe: { type: Boolean, default: false },
})

const { fetchPeriodSummary, isLoading, error } = useProfile()
const summary = ref(null)
// the period shown: null, the last finished one
const periodId = ref(null)

// the last request: an answer to an older one (another player, another period) is dropped
let request = 0
function load() {
  const current = ++request
  fetchPeriodSummary(props.playerId, periodId.value).then((data) => {
    if (current === request) {
      summary.value = data
    }
  }).catch(() => {}) // (shown by error)
}
watch(() => props.playerId, () => {
  periodId.value = null
  summary.value = null
})
watch([() => props.playerId, periodId], load, { immediate: true })

// the words of the player: "vous" on their own profile
const words = computed(() => props.isMe
  ? { your: 'votre', yours: 'vos', you: 'vous' }
  : { your: 'son', yours: 'ses', you: 'lui' })
const stars = computed(() => [
  { count: summary.value?.stars.green, icon: GreenStar, label: 'Étoile verte' },
  { count: summary.value?.stars.orange, icon: OrangeStar, label: 'Étoile orange' },
  { count: summary.value?.stars.red, icon: RedStar, label: 'Étoile rouge' },
].filter((star) => star.count > 0))
const rankings = computed(() => [...(summary.value?.rankings ?? [])].sort((a, b) => a.game.name.localeCompare(b.game.name)))
const ordinal = (rank) => (rank === 1 ? 'er' : 'e')
// (the periods are in UTC: they end at 23:59:59 UTC)
const formatDate = (date) => dayjs.utc(date).format('DD/MM/YYYY')

// the tables of the summary: thin uppercase headers, cells without borders
const thinTitles = '[&_th]:px-2 [&_th]:text-xs [&_th]:font-normal [&_th]:uppercase [&_td]:border-0 [&_td]:px-2'
</script>

<template>
  <KadoPageTitle class="mb-5">{{ isMe ? 'Votre dernière période' : `Dernière période de ${playerName}` }}</KadoPageTitle>

  <Loader v-if="isLoading && !summary">Chargement de la période...</Loader>
  <MessageError v-else-if="error">{{ error }}</MessageError>
  <p v-else-if="!summary" class="mx-2.5 my-4 text-center italic">Aucune période n'est encore terminée.</p>

  <div v-else class="relative">
    <Loader v-if="isLoading" />

    <KadoSectionTitle>Résumé de {{ words.yours }} points Kado</KadoSectionTitle>
    <p class="mx-2.5 mt-2 text-center text-sm">
      Du {{ formatDate(summary.period.start_at) }} au {{ formatDate(summary.period.end_at) }}
    </p>
    <ul class="mt-4 mb-6 ml-10 list-inside list-kado space-y-1">
      <li v-if="summary.clan?.reward">
        Le classement de {{ words.your }} clan
        <RouterLink v-if="summary.clan.id" :to="{ name: 'clans.show', params: { id: summary.clan.id } }">{{ summary.clan.name }}</RouterLink>
        {{ words.you }} a rapporté <Number :value="summary.clan.reward" color="green" /> <KadoPoints class="inline size-4.25" />
      </li>
      <li v-if="summary.promotions_reward">
        {{ isMe ? 'Votre' : 'Sa' }} progression sur les jeux {{ words.you }} a rapporté <Number :value="summary.promotions_reward" color="green" /> <KadoPoints class="inline size-4.25" />
      </li>
      <li v-if="summary.feathers?.reward">
        {{ isMe ? 'Vos' : 'Ses' }} plumes ({{ summary.feathers.count }}) {{ isMe ? 'vous ont' : 'lui ont' }} rapporté <Number :value="summary.feathers.reward" color="green" /> <KadoPoints class="inline size-4.25" />
      </li>
      <li v-for="star in stars" :key="star.label">
        {{ star.count }} x <component :is="star.icon" class="inline size-4" :aria-label="star.label" />
      </li>
      <li class="font-bold">Total période : <Number :value="summary.total" color="green" /> <KadoPoints class="inline size-4.25" /></li>
    </ul>

    <KadoSectionTitle>Améliorations aux jeux</KadoSectionTitle>
    <KadoTable v-if="summary.promotions.length" :class="thinTitles" class="mx-auto my-4 w-3/4">
      <thead>
        <tr>
          <th></th>
          <th>Jeu</th>
          <th>Position</th>
          <th>Nvx</th>
          <th>Score</th>
          <th>Gains</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="promotion in summary.promotions" :key="promotion.game.id">
          <td><img src="/gfx/greenArrowUp.png" alt="Qualifié !" title="Qualifié pour la ligue supérieure" /></td>
          <td><RouterLink :to="{ name: 'games.show', params: { id: promotion.game.id } }">{{ promotion.game.name }}</RouterLink></td>
          <td><Number :value="promotion.rank_position" color="orange" /><sup> {{ ordinal(promotion.rank_position) }}</sup></td>
          <td><img :src="`/gfx/leagues/${promotion.from_league_id}s.svg`" alt="Niveau" class="mx-auto h-auto w-6" /></td>
          <td><Number :value="promotion.score" color="blue" /></td>
          <td class="whitespace-nowrap"><Number :value="promotion.reward" color="green" /> <KadoPoints class="inline size-4.25" /></td>
        </tr>
      </tbody>
    </KadoTable>
    <p v-else class="mx-2.5 my-4 text-center italic">Aucune promotion dans les ligues pendant cette période.</p>

    <KadoSectionTitle>Classement</KadoSectionTitle>
    <KadoTable v-if="rankings.length" :class="thinTitles" class="mx-auto my-4 w-3/5">
      <thead>
        <tr>
          <th>Jeu</th>
          <th>Position</th>
          <th>Nvx</th>
          <th>Score</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="run in rankings" :key="run.id">
          <td class="text-left"><RouterLink :to="{ name: 'games.show', params: { id: run.game.id } }">{{ run.game.name }}</RouterLink></td>
          <td><Number :value="run.league_rank" color="orange" /><sup> {{ ordinal(run.league_rank) }}</sup></td>
          <td><img v-if="run.league_id"
                   :src="`/gfx/leagues/${run.league_id}s.svg`"
                   alt="Niveau"
                   class="mx-auto h-auto w-6" /></td>
          <td class="text-right"><Number :value="run.score" color="blue" /></td>
        </tr>
      </tbody>
    </KadoTable>
    <p v-else class="mx-2.5 my-4 text-center italic">Aucune partie jouée pendant cette période.</p>

    <CompetitionPeriodNavigator
      :label="`Période ${summary.period.id}`"
      :can-go-previous="!!summary.previous_period_id"
      :can-go-next="!!summary.next_period_id"
      :disabled="isLoading"
      class="mt-6"
      @previous="periodId = summary.previous_period_id"
      @next="periodId = summary.next_period_id"
    />
  </div>
</template>
