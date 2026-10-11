<script setup>
const { isLoading, fetchGames } = useGames()
const route = useRoute()
const games = ref([])
const categories = ref([])

fetchGames().then((data) => {
  games.value = data.data
  categories.value = data.categories
})

const gamesFiltered = computed(() => {
  if (route.query.category) {
    return games.value.filter(
      (game) =>
        game.category_id === categories.value.find((c) => c.name === route.query.category)?.id,
    )
  }
  const favs = games.value.filter((game) => game.is_favorite)
  if (favs.length > 0) {
    return favs
  }
  return games.value
})

function getStarImage(game) {
  const starImages = [
    '/gfx/starGreenMedium.gif',
    '/gfx/starOrangeMedium.gif',
    '/gfx/starRedMedium.gif',
  ]

  return starImages[game.user_star] ?? null
}
</script>

<template>
  <NavTabs
    :items="[
      {
        label: 'Sélection', value: 'favs', route: {name: 'games.index'} },
      ...categories.map((cat) => ({
        label: cat.name,
        value: cat.name,
        route: { name: 'games.index', query: { category: cat.name } },
      })),
    ]"
    :selected-index="route.query.category ? categories.findIndex((c) => c.name === route.query.category) + 1 : 0"
  />

  <div>
    <GamesDailyGameBlock class="px-2" />

    <div class="relative min-h-48 grid grid-cols-2 sm:grid-cols-3 justify-around px-2 gap-4">
      <Loader v-if="isLoading">Chargement des jeux...</Loader>
      <template v-else>
        <RouterLink
          v-for="game in gamesFiltered"
          :key="`game-${game.id}`"
          class="relative w-full aspect-[113/71] sm:w-[226px] sm:h-[142px] sm:aspect-auto"
          :to="{ name: 'games.show', params: { id: game.id } }"
          :title="`Jouer à ${game.name}`"
        >
          <div class="relative z-[2] w-full h-full bg-[url('/gfx/gameBox.png')] bg-no-repeat bg-[length:100%_100%] sm:bg-auto"></div>
          <div class="absolute left-[15.93%] top-[5.63%] w-[77.88%] sm:left-9 sm:top-2 sm:w-[176px]">
            <img class="w-full h-auto" :src="game.image_path" :alt="game.name" />
          </div>
          <div class="size-8 absolute z-[2] left-[3%] bottom-[14%] w-[14%] h-[14%]">
            <img
              v-if="game.user_star !== null"
              :src="getStarImage(game)"
              :alt="`star ${game.user_star}`"
              class="w-full"
            />
          </div>
          <h3 class="absolute top-[78.87%] left-[55%] z-10 w-[77.88%] -translate-x-1/2 text-center text-base md:text-xl font-normal text-kado-cyan-900 sm:top-28 sm:w-44 text-nowrap">
            {{ game.name }}
          </h3>
        </RouterLink>
      </template>
    </div>
  </div>
</template>
