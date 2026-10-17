<script setup>
// "Classement" of the clans of the period, and the creation of a clan
const route = useRoute()
const router = useRouter()
const clanStore = useClanStore()
const { fetchRanking, isLoading, error } = useClans()
// (its own error)
const { createClan, error: createError } = useClans()

const tab = computed(() => ['war', 'missions', 'create'].includes(route.query.tab) ? route.query.tab : 'war')
const search = ref(route.query.q ?? '')
const clans = ref([])
const meta = ref(null)
const tournament = ref(null)

const load = (page = 1) => {
  if (tab.value === 'create') {
    return
  }
  fetchRanking({ ranking: tab.value, q: route.query.q || undefined, page }).then((data) => {
    clans.value = page === 1 ? data.data : [...clans.value, ...data.data]
    meta.value = data.meta
    tournament.value = data.tournament
  })
}
watch(() => [route.query.tab, route.query.q], () => load(), { immediate: true })
clanStore.reload()

const hasNextPage = computed(() => meta.value && meta.value.current_page < meta.value.last_page)
const doSearch = () => router.push({ query: { ...route.query, q: search.value || undefined } })

const name = ref('')
const description = ref('')
const submit = () =>
  createClan({ name: name.value, description: description.value || null }).then((data) => {
    clanStore.reload()
    router.push({ name: 'clans.show', params: { id: data.data.id } })
  })

const tabs = [
  { label: 'Classement', value: 'war', route: { name: 'clans.index' } },
  { label: 'Missions', value: 'missions', route: { name: 'clans.index', query: { tab: 'missions' } } },
  { label: 'Créer un clan', value: 'create', route: { name: 'clans.index', query: { tab: 'create' } } },
]
const selectedIndex = computed(() => tabs.findIndex((t) => t.value === tab.value))
</script>

<template>
  <NavTabs :items="tabs" :selected-index="selectedIndex" />

  <div class="px-2 space-y-4">
    <h1 class="mt-0 text-center">Les clans</h1>
    <ClanPeriodBanner :tournament="tournament ?? clanStore.tournament" />
    <p v-if="clanStore.debug" class="mx-0 text-right text-xs">
      <RouterLink :to="{ name: 'clans.debug' }">🔧 Outils de test des clans</RouterLink>
    </p>

    <p v-if="clanStore.clan" class="mx-0">
      <img src="/assets/img/gfx/icons/clan.gif" alt="" />
      Votre clan :
      <RouterLink :to="{ name: 'clans.show', params: { id: clanStore.clan.id } }" class="font-bold">{{ clanStore.clan.name }}</RouterLink>
    </p>
    <p v-else class="mx-0">
      Vous ne faites partie d'aucun clan. Un clan est un groupe de 1 à 50 joueurs qui combattent ensemble contre les
      autres clans : rejoignez un clan existant en envoyant votre candidature depuis sa page, ou
      <RouterLink :to="{ name: 'clans.index', query: { tab: 'create' } }">créez votre propre clan</RouterLink>.
    </p>
    <p v-if="clanStore.applications.length" class="mx-0 text-sm">
      Candidature(s) en attente :
      <template v-for="(a, i) in clanStore.applications" :key="a.id">
        <template v-if="i">, </template>
        <RouterLink :to="{ name: 'clans.show', params: { id: a.clan.id } }">{{ a.clan.name }}</RouterLink>
      </template>
    </p>

    <template v-if="tab === 'create'">
      <MessageError v-if="clanStore.clan">Vous faites déjà partie d'un clan.</MessageError>
      <form v-else class="max-w-lg" @submit.prevent="submit">
        <div>
          <label for="clanName">Nom du clan</label>
          <FormInput id="clanName"
                     v-model="name"
                     type="text"
                     minlength="3"
                     maxlength="32"
                     required
                     class="w-full" />
          <p class="m-0 text-xs text-kado-cyan-900">De 3 à 32 caractères : lettres, chiffres, espaces et - ' . ! ? Il ne pourra plus être changé.</p>
        </div>
        <div>
          <label for="clanDescription">Présentation (vous pourrez la modifier plus tard)</label>
          <FormTextarea id="clanDescription"
                        v-model="description"
                        rows="6"
                        maxlength="5000" />
        </div>
        <MessageError v-if="createError">{{ createError }}</MessageError>
        <FormButton type="submit" size="lg">Créer le clan</FormButton>
      </form>
    </template>

    <template v-else>
      <form class="flex items-center gap-2" @submit.prevent="doSearch">
        <FormInput v-model="search" type="search" placeholder="Rechercher un clan" />
        <FormButton type="submit" size="lg">Rechercher</FormButton>
      </form>

      <MessageError v-if="error">{{ error }}</MessageError>
      <div class="relative min-h-24 overflow-x-auto">
        <Loader v-if="isLoading && !clans.length" />
        <table class="w-full">
          <thead>
            <tr class="text-[10px] uppercase">
              <th>Position</th>
              <th class="min-w-28">Clan</th>
              <th>Membres</th>
              <template v-if="tab === 'war'">
                <th><img src="/assets/img/gfx/icons/clan_points.gif"
                         alt="score"
                         title="Score d'attaque"
                         class="h-5" /></th>
                <th><img src="/assets/img/gfx/icons/atk.gif"
                         alt="attaques"
                         title="Attaques réussies"
                         class="h-5" /></th>
                <th><img src="/assets/img/gfx/icons/def.gif"
                         alt="défenses"
                         title="Défenses réussies"
                         class="h-5" /></th>
              </template>
              <template v-else>
                <th><img src="/gfx/clan/clan_mission_points.png"
                         alt="score"
                         title="Score de mission"
                         class="h-5" /></th>
                <th title="Missions réussies pendant la période">Missions</th>
                <th title="Étapes réussies de la mission en cours, sur son nombre d'étapes">Étapes</th>
              </template>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(clan, index) in clans"
                :key="clan.id"
                :class="[index % 2 ? 'bg-white' : 'bg-kado-cyan-200', { 'font-bold': clan.id === clanStore.clan?.id }]">
              <td><Number :value="clan.rank" :color="tab === 'war' ? 'green' : 'violet'" /></td>
              <td class="text-left">
                <RouterLink :to="{ name: 'clans.show', params: { id: clan.id } }">{{ clan.name }}</RouterLink>
              </td>
              <td>{{ clan.members_count }}</td>
              <template v-if="tab === 'war'">
                <td class="text-right"><Number :value="clan.war_score" color="orange" /></td>
                <td class="text-right"><Number :value="clan.attacks_won" color="pink" /></td>
                <td class="text-right"><Number :value="clan.defenses_won" color="blue" /></td>
              </template>
              <template v-else>
                <td class="text-right"><Number :value="clan.mission_score" color="violet" /></td>
                <td class="text-right">{{ clan.missions_completed }}</td>
                <td class="text-right whitespace-nowrap" :title="clan.mission ? `Mission ${clan.mission.number}` : ''">
                  <template v-if="clan.mission">{{ clan.mission.steps_done }} / {{ clan.mission.steps }}</template>
                  <template v-else>-</template>
                </td>
              </template>
            </tr>
            <tr v-if="!isLoading && !clans.length">
              <td colspan="6" class="italic">Aucun clan pour le moment.</td>
            </tr>
          </tbody>
        </table>
      </div>
      <p v-if="hasNextPage" class="text-center">
        <FormButton size="lg" @click="load(meta.current_page + 1)">Charger plus de clans</FormButton>
      </p>
    </template>
  </div>
</template>
