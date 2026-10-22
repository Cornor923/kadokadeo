<script setup>
defineProps({
  scores: { type: Array, required: true },
  showPos: { type: Boolean, default: true },
  showPlayer: { type: Boolean, default: true },
  showGame: { type: Boolean, default: false },
})
</script>

<template>
  <KadoTable borderless class="w-full">
    <thead>
      <tr>
        <!-- <th scope="col">Période</th> -->
        <th v-if="showPos" scope="col">Pos</th>
        <th v-if="showPlayer" scope="col">Joueur</th>
        <th v-if="showGame" scope="col">Jeu</th>
        <th scope="col">Score</th>
        <th scope="col">Temps</th>
      </tr>
    </thead>
    <tbody>
      <tr v-for="(score, index) in scores" :key="score.id">
        <!-- <td>{{ score.period_id }}</td> -->
        <td v-if="showPos" class="w-px whitespace-nowrap"><Number :value="score.rank_position ?? index + 1" color="orange" /></td>
        <!-- w-full + max-w-0 : la colonne prend la place restante et peut descendre sous la largeur de son contenu -->
        <td v-if="showPlayer" class="w-full max-w-0">
          <RouterLink class="block truncate" :to="{ name: 'profile.show', params: { id: score.user.etwin_id } }">
            {{ score.user.display_name }}
          </RouterLink>
        </td>
        <td v-if="showGame" class="w-px whitespace-nowrap">
          <RouterLink :to="{ name: 'games.show', params: { id: score.game.id } }">
            {{ score.game.name }}
          </RouterLink>
        </td>
        <td class="w-px whitespace-nowrap"><Number class="flex shrink-0 justify-center" :value="score.score" color="blue" /></td>
        <td class="w-px whitespace-nowrap">
          <RouterLink
            v-if="score.has_replay"
            :to="{ name: 'runs.show', params: { id: score.id } }"
          >
            {{ formatTime(score.play_time_seconds) }}
          </RouterLink>
          <span v-else>
            {{ formatTime(score.play_time_seconds) }}
          </span>
        </td>
      </tr>
    </tbody>
  </KadoTable>
</template>
