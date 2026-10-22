<script setup>
// the boxes of the games, to choose one
defineProps({
  title: { type: String, default: null },
})
const emit = defineEmits(['select'])

const { isLoading, fetchGames } = useGames()
const games = ref([])
// the favorite games of the player first (each part in the order of the list of the games)
fetchGames().then((data) => {
  const playable = data.data.filter((game) => !game.is_arkadeo)
  games.value = [...playable.filter((game) => game.is_favorite), ...playable.filter((game) => !game.is_favorite)]
})
</script>

<template>
  <div class="relative min-h-48 grid grid-cols-2 sm:grid-cols-3 gap-4">
    <Loader v-if="isLoading">Chargement des jeux...</Loader>
    <button
      v-for="game in games"
      :key="game.id"
      type="button"
      class="relative w-full aspect-[113/71] cursor-pointer border-0 bg-transparent p-0"
      :title="title ? `${title} ${game.name}` : game.name"
      @click="emit('select', game)"
    >
      <div class="relative z-[2] w-full h-full bg-[url('/gfx/gameBox.png')] bg-no-repeat bg-[length:100%_100%]"></div>
      <img
        v-if="game.is_favorite"
        src="/gfx/iconGameLiked.gif"
        alt="Jeu favori"
        class="absolute z-[3] left-[3.54%] top-[39.4%] w-[7.96%] h-auto"
      />
      <div class="absolute left-[15.93%] top-[5.63%] w-[77.88%]">
        <img class="w-full h-auto" :src="game.image_path" :alt="game.name" />
      </div>
      <span class="absolute top-[78.87%] left-[55%] z-10 w-[77.88%] -translate-x-1/2 text-center text-base font-normal text-kado-blue-800 text-nowrap">
        {{ game.name }}
      </span>
    </button>
  </div>
</template>
