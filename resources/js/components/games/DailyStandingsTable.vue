<script setup>
// the ranking of the daily game over the period: the points of each player (App\Services\DailyRankingService)
defineProps({
  // [{ rank, points, user }]
  standings: { type: Array, required: true },
})
const authStore = useAuthStore()
</script>

<template>
  <KadoTable borderless class="w-full">
    <thead>
      <tr>
        <th scope="col">Pos</th>
        <th scope="col">Joueur</th>
        <th scope="col">Points</th>
      </tr>
    </thead>
    <tbody>
      <tr v-for="player in standings" :key="player.user.etwin_id" :class="{ 'font-bold': player.user.etwin_id === authStore.user?.etwin_id }">
        <td class="w-px whitespace-nowrap"><Number :value="player.rank" color="orange" /></td>
        <!-- w-full + max-w-0 : la colonne prend la place restante et peut descendre sous la largeur de son contenu -->
        <td class="w-full max-w-0">
          <RouterLink class="block truncate" :to="{ name: 'profile.show', params: { id: player.user.etwin_id } }">
            {{ player.user.display_name }}
          </RouterLink>
        </td>
        <td class="w-px whitespace-nowrap"><Number class="flex shrink-0 justify-center" :value="player.points" color="blue" /></td>
      </tr>
    </tbody>
  </KadoTable>
</template>
