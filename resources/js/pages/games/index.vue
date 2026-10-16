<script setup>
import PromotionPlay from '@svg/promotionPlay.svg'

const { isLoading, fetchGames } = useGames()
const route = useRoute()
const games = ref([])
const categories = ref([])
// games where the player is in the promotion slots of their league
const promotionGameIds = ref([])

fetchGames().then((data) => {
  games.value = data.data
  categories.value = data.categories
  promotionGameIds.value = data.promotion_game_ids ?? []
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
          <PromotionPlay
            v-if="promotionGameIds.includes(game.id)"
            class="absolute z-[3] left-[5.4%] top-[5.8%] w-[6.19%] h-[10.56%] sm:left-3 sm:top-2 sm:w-[14px] sm:h-[15px]"
            aria-label="Qualifié pour la ligue supérieure"
          />
          <img
            v-if="game.is_favorite"
            src="/gfx/iconGameLiked.gif"
            alt="Jeu favori"
            class="absolute z-[3] left-[3.54%] top-[39.4%] w-[7.96%] h-auto sm:left-2 sm:top-14 sm:w-[18px]"
          />
          <div class="absolute left-[15.93%] top-[5.63%] w-[78.4%] sm:left-9 sm:top-2 sm:w-[178px]">
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
