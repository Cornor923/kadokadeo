<script setup>
// the page of a clan: Présentation, Statut, Mission, Membres, Gestion, Parties de clan, Historique, and the choice of the game of an
// attack
const route = useRoute()
const router = useRouter()
const clanStore = useClanStore()
const { fetchClan, isLoading, error } = useClans()
// (their own errors)
const actions = useClans()

const clan = ref(null)
const tournament = ref(null)
const tab = computed(() => route.meta.tab ?? 'show')
const clanId = computed(() => route.params.id)

const load = () =>
  fetchClan(clanId.value).then((data) => {
    clan.value = data.data
    tournament.value = data.tournament
  })
watch(clanId, load, { immediate: true })

const viewer = computed(() => clan.value?.viewer ?? {})
// a single application at a time: the one sent to another clan
const applicationElsewhere = computed(() => clanStore.applications.find((a) => a.clan.id !== clan.value?.id) ?? null)
const applicationMessage = ref('')
const showApplyForm = ref(false)
// the confirmation of the last action of the player on the page
const notice = ref(null)
watch(clanId, () => {
  notice.value = null
})

const apply = () =>
  actions.apply(clan.value.id, applicationMessage.value || null).then(() => {
    showApplyForm.value = false
    applicationMessage.value = ''
    notice.value = `Votre candidature a bien été envoyée au chef du clan ${clan.value.name}. Vous serez membre du clan dès qu'il l'aura acceptée.`
    clanStore.reload()
    load()
  })
const cancelApplication = () => {
  if (!confirm('Retirer votre candidature à ce clan ?')) {
    return
  }
  actions.cancelApplication(viewer.value.application_id).then(() => {
    notice.value = 'Votre candidature a été retirée.'
    clanStore.reload()
    load()
  })
}
const leave = () => {
  if (viewer.value.is_new_member) {
    alert('Vous ne pourrez quitter le clan qu\'après la fin de cette période.')
    return
  }
  if (confirm('Quitter ce clan ?')) {
    actions.leave().then(() => {
      clanStore.reload()
      router.push({ name: 'clans.index' })
    })
  }
}
// "Déclarer la guerre": the targets of the members of the clan of the player (3 at most, until the end of the period), shown
// in "Statut"
const toggleWar = () => {
  const atWar = viewer.value.at_war
  if (!confirm(atWar ? `Faire la paix avec le clan ${clan.value.name} ?` : `Déclarer la guerre au clan ${clan.value.name} ?`)) {
    return
  }
  ;(atWar ? actions.endWar(clan.value.id) : actions.declareWar(clan.value.id)).then(() => {
    notice.value = atWar
      ? `Votre clan a fait la paix avec le clan ${clan.value.name}.`
      : `Votre clan a déclaré la guerre au clan ${clan.value.name} jusqu'à la fin de la période : elle apparaît maintenant dans le statut des deux clans.`
    load()
  })
}
const updated = () => {
  load()
  clanStore.reload()
}
</script>

<template>
  <div class="relative min-h-48">
    <Loader v-if="isLoading && !clan">Chargement ...</Loader>
    <MessageError v-else-if="!clan">Clan introuvable. ({{ error }})</MessageError>

    <ClanLayout v-else :clan="clan" :tab="tab">
      <template #actions>
        <ClanMenuAction v-if="viewer.can_manage" :to="{ name: 'clans.manage', params: { id: clan.id } }">Gérer le clan</ClanMenuAction>
        <ClanMenuAction v-if="viewer.is_member" :to="{ name: 'clans.games', params: { id: clan.id } }">Parties de clan</ClanMenuAction>
        <ClanMenuAction v-if="viewer.is_member" :to="{ name: 'clans.forum', params: { id: clan.id } }">Forum</ClanMenuAction>
        <ClanMenuAction :to="{ name: 'clans.history', params: { id: clan.id } }">Historique</ClanMenuAction>
        <ClanMenuAction v-if="!viewer.is_member && viewer.has_clan"
                        :to="{ name: 'clans.attack', params: { id: clan.id } }"
                        :title="viewer.attack_blocked ?? 'Attaquer ce clan'">Attaquer ce clan</ClanMenuAction>
        <ClanMenuAction v-if="viewer.can_declare_war"
                        :title="viewer.at_war ? 'Ne plus faire de ce clan une cible de votre clan' : 'Indiquer ce clan comme cible à votre clan jusqu\'à la fin de la période (3 clans au maximum)'"
                        @click="toggleWar">{{ viewer.at_war ? 'Faire la paix' : 'Déclarer la guerre' }}</ClanMenuAction>
        <ClanMenuAction v-if="!viewer.has_clan && viewer.application_id" title="Annuler ma candidature" @click="cancelApplication">Retirer ma demande</ClanMenuAction>
        <ClanMenuAction v-else-if="!viewer.has_clan && clan.is_recruiting && !applicationElsewhere" title="Envoyer ma candidature" @click="showApplyForm = !showApplyForm">Postuler</ClanMenuAction>
        <ClanMenuAction v-if="viewer.is_member" @click="leave" :class="{'grayscale cursor-not-allowed': viewer.is_new_member}">Quitter le clan</ClanMenuAction>
        <ClanMenuAction v-if="clanStore.clan && clanStore.clan.id !== clan.id" :to="{ name: 'clans.show', params: { id: clanStore.clan.id } }">Mon clan</ClanMenuAction>
      </template>

      <MessageError v-if="actions.error.value">{{ actions.error.value }}</MessageError>
      <MessageSuccess v-else-if="notice">{{ notice }}</MessageSuccess>
      <p v-else-if="!viewer.has_clan && viewer.application_id" class="mx-0 mb-4 border-2 border-l-[10px] border-kado-orange bg-[#fff4dc] px-3 py-2 font-bold text-[#c25e00]">
        Votre candidature à ce clan est en attente de la réponse du chef de clan.
      </p>
      <p v-else-if="!viewer.has_clan && applicationElsewhere" class="mx-0 mb-4 border-2 border-l-[10px] border-kado-orange bg-[#fff4dc] px-3 py-2 font-bold text-[#c25e00]">
        Vous avez déjà une candidature en attente pour le clan
        <RouterLink :to="{ name: 'clans.show', params: { id: applicationElsewhere.clan.id } }">{{ applicationElsewhere.clan.name }}</RouterLink>.
        Retirez-la avant de postuler dans un autre clan.
      </p>

      <ClanUnfinishedActions v-if="viewer.is_member" :actions="viewer.unfinished_actions ?? []" @updated="load" />

      <form v-if="showApplyForm" class="mb-4" @submit.prevent="apply">
        <div>
          <label for="applicationMessage">Votre message au chef de clan (facultatif)</label>
          <FormTextarea id="applicationMessage"
                        v-model="applicationMessage"
                        rows="3"
                        maxlength="500" />
        </div>
        <FormButton type="submit" size="lg">Envoyer votre candidature</FormButton>
      </form>

      <ClanPresentation v-if="tab === 'show'" :clan="clan" :tournament="tournament" />
      <ClanStatus v-else-if="tab === 'status'" :clan="clan" />
      <ClanMissions v-else-if="tab === 'missions'" :clan="clan" />
      <ClanMembers v-else-if="tab === 'members'" :clan="clan" />
      <ClanManage v-else-if="tab === 'manage'" :clan="clan" @updated="updated" />
      <ClanAttackPicker v-else-if="tab === 'attack'" :clan="clan" />
      <ClanHistory v-else-if="tab === 'history'" :clan="clan" />
      <ClanGames v-else-if="tab === 'games' && viewer.is_member" :clan="clan" @updated="load" />
    </ClanLayout>
  </div>
</template>
