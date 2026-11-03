<script setup>
import KadoPoints from '@svg/k.svg'
// "Classement" of the clans of the period, and the creation of a clan
const route = useRoute()
const router = useRouter()
const clanStore = useClanStore()
const authStore = useAuthStore()
// (its own error)
const { createClan, isLoading: isCreating, error: createError } = useClans()

const tab = computed(() => ['war', 'missions', 'create'].includes(route.query.tab) ? route.query.tab : 'war')
const search = ref(route.query.q ?? '')
// (none on the tab of the creation)
const { items: clans, tournament, hasNextPage, loadMore, isLoading, error } = useClanRanking(
  () => (tab.value === 'create' ? null : { ranking: tab.value, q: route.query.q || undefined }),
)
clanStore.reload()

const doSearch = () => router.push({ query: { ...route.query, q: search.value || undefined } })

const name = ref('')
const description = ref('')
// a clan costs Kado points (ClanSettings::$creation_price)
const creationPrice = computed(() => clanStore.rules?.creation_price ?? 0)
const canPayCreation = computed(() => (authStore.user?.kado_points ?? 0) >= creationPrice.value)
const submit = () => {
  if (isCreating.value) {
    return
  }
  createClan({ name: name.value, description: description.value || null }).then((data) => {
    authStore.fetchUser()
    clanStore.reload()
    router.push({ name: 'clans.show', params: { id: data.data.id } })
  }).catch(() => {})
}

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
    <KadoPageTitle>Les clans</KadoPageTitle>
    <ClanPeriodBanner :tournament="tournament ?? clanStore.tournament" />
    <p v-if="clanStore.debug" class="text-right text-xs">
      <RouterLink :to="{ name: 'clans.debug' }">🔧 Outils de test des clans</RouterLink>
    </p>

    <p v-if="clanStore.clan">
      <img src="/assets/img/gfx/icons/clan.gif" alt="" />
      Votre clan :
      <RouterLink :to="{ name: 'clans.show', params: { id: clanStore.clan.id } }" class="font-bold">{{ clanStore.clan.name }}</RouterLink>
    </p>
    <p v-else>
      <!-- the maximum set in the admin (ClanSettings::$max_members) -->
      Vous ne faites partie d'aucun clan. Un clan est un groupe
      <template v-if="clanStore.rules?.max_members">de 1 à {{ clanStore.rules.max_members }}</template><template v-else>de</template>
      joueurs qui combattent ensemble contre les
      autres clans : rejoignez un clan existant en envoyant votre candidature depuis sa page, ou
      <RouterLink :to="{ name: 'clans.index', query: { tab: 'create' } }">créez votre propre clan</RouterLink>.
    </p>
    <p v-if="clanStore.applications.length" class="text-sm">
      Candidature(s) en attente :
      <template v-for="(a, i) in clanStore.applications" :key="a.id">
        <template v-if="i">, </template>
        <RouterLink :to="{ name: 'clans.show', params: { id: a.clan.id } }">{{ a.clan.name }}</RouterLink>
      </template>
    </p>

    <template v-if="tab === 'create'">
      <MessageError v-if="clanStore.clan">Vous faites déjà partie d'un clan.</MessageError>
      <form v-else class="max-w-lg space-y-2" @submit.prevent="submit">
        <div>
          <label for="clanName" class="font-bold">Nom du clan</label>
          <FormInput id="clanName"
                     v-model="name"
                     type="text"
                     minlength="3"
                     maxlength="32"
                     required
                     class="w-full" />
          <p class="m-0 text-xs text-kado-blue-800">De 3 à 32 caractères : lettres, chiffres, espaces et - ' . ! ? Il ne pourra plus être changé.</p>
        </div>
        <div>
          <label for="clanDescription" class="font-bold">Présentation (vous pourrez la modifier plus tard)</label>
          <FormTextarea id="clanDescription"
                        v-model="description"
                        rows="6"
                        maxlength="5000" />
        </div>
        <MessageError v-if="createError">{{ createError }}</MessageError>
        <FormButton type="submit"
                    size="lg"
                    :disabled="isCreating || !canPayCreation"
                    :title="canPayCreation ? '' : 'Vous n\'avez pas assez de points Kado'">
          <template v-if="!isCreating"><Number :value="creationPrice" color="green" /> <KadoPoints class="inline size-5" /></template>
          {{ isCreating ? 'Création en cours ...' : 'Créer le clan' }}
        </FormButton>
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
        <KadoTable class="w-full">
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
                :class="[index % 2 ? 'bg-white' : 'bg-kado-blue-100', { 'font-bold': clan.id === clanStore.clan?.id }]">
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
        </KadoTable>
      </div>
      <p v-if="hasNextPage" class="mx-2.5 my-4 text-center">
        <FormButton size="lg" @click="loadMore()">Charger plus de clans</FormButton>
      </p>
    </template>
  </div>
</template>
