<script setup>
// "Historique": the finished attacks (A) and defenses (D) of the clan, without the cancelled attacks
const props = defineProps({
  clan: { type: Object, required: true },
})

const { fetchHistory, isLoading, error } = useClans()
const rows = ref([])
const meta = ref(null)

const load = (page = 1) =>
  fetchHistory(props.clan.id, page).then((data) => {
    rows.value = page === 1 ? data.data : [...rows.value, ...data.data]
    meta.value = data.meta
  })
watch(() => props.clan.id, () => load(), { immediate: true })

const hasNextPage = computed(() => meta.value && meta.value.current_page < meta.value.last_page)
const formatDate = (date) => (date ? dayjs(date).format('DD/MM/YYYY HH:mm') : '—')
</script>

<template>
  <div class="relative space-y-4">
    <MessageError v-if="error">{{ error }}</MessageError>
    <Loader v-if="isLoading && !meta" />

    <div class="overflow-x-auto">
      <table v-if="meta" class="w-full text-sm [&_td]:px-2 [&_td]:py-1">
        <thead>
          <tr class="uppercase text-2xs">
            <th class="text-left!">Date</th>
            <th class="min-w-10" title="A : attaque du clan, D : attaque reçue par le clan">Type</th>
            <th class="min-w-16 text-left!">Joueur</th>
            <th class="min-w-20 text-left!">Clan</th>
            <th class="min-w-16 text-left!">Jeu</th>
            <th class="text-right!">Score</th>
            <th>Statut</th>
            <th class="text-center"><img src="/assets/img/gfx/icons/clan_points.gif" alt="Points" class="w-5"></th>
          </tr>
        </thead>
        <tbody class="text-2xs">
          <tr v-if="!rows.length" class="bg-kado-cyan-200">
            <td colspan="8" class="py-4 italic text-kado-blue">Aucune attaque ni défense terminée pour le moment.</td>
          </tr>
          <tr v-for="(row, index) in rows" :key="row.id" :class="index % 2 ? 'bg-white' : 'bg-kado-cyan-200'">
            <td class="text-left whitespace-nowrap">{{ formatDate(row.date) }}</td>
            <td class="font-bold">
              <img :src="row.type === 'attack' ? '/gfx/clan/atksmall.gif' : '/gfx/clan/defsmall.gif'"
                   :alt="row.type === 'attack' ? 'Attaque' : 'Défense'"
                   class="w-5" />
            </td>
            <td class="text-left [font-variant:small-caps]">
              <RouterLink v-if="row.player" :to="{ name: 'profile.show', params: { id: row.player.etwin_id } }">{{ row.player.display_name }}</RouterLink>
              <template v-else>—</template>
            </td>
            <td class="text-left font-bold">
              <RouterLink :to="{ name: 'clans.show', params: { id: row.clan.id } }">{{ row.clan.name }}</RouterLink>
            </td>
            <td class="text-left">
              <RouterLink :to="{ name: 'games.show', params: { id: row.game.id } }" class="text-kado-blue">{{ row.game.name }}</RouterLink>
            </td>
            <td class="text-right whitespace-nowrap">
              <Number v-if="row.score !== null" :value="row.score" color="blue" />
            </td>
            <td class="whitespace-nowrap">
              {{ row.status_label }}
              <template v-if="row.other_player">
                {{ row.type === 'attack' ? 'par' : 'attaque de' }} {{ row.other_player.display_name }}
              </template>
              <template v-if="row.other_score !== null">
                (<Number :value="row.other_score" color="blue" />)
              </template>
            </td>
            <td class="text-center whitespace-nowrap font-bold"
                :title="row.type === 'defense' && row.points > 0 ? 'Points du défenseur dans le classement du clan' : null">
              <Number v-if="row.points > 0"
                      :value="row.points"
                      color="pink"
                      signed />
              <Number v-else-if="row.points < 0"
                      :value="row.points"
                      color="blue"
                      signed />
              <template v-else>—</template>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <div v-if="hasNextPage" class="text-center">
      <FormButton size="lg" :disabled="isLoading" @click="load(meta.current_page + 1)">Charger plus</FormButton>
    </div>
  </div>
</template>
