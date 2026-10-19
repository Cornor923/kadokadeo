<script setup>
// the game with its side panel (rules, paliers, ranking, achievements) and the zoom, as on the page of a game; goals:
// more paliers shown with the others (the score of a clan defense, of a mission step...)
const props = defineProps({
  game: { type: Object, required: true },
  goals: { type: Array, default: () => [] },
})

const { isLoading: isFavoriteLoading, error: favoriteError, put } = useApi()
const isArkadeo = computed(() => props.game.is_arkadeo ?? false)
const _zoomed = ref(localStorage.getItem('isZoomed') === 'true')
const isZoomed = computed({
  get() {
    return _zoomed.value
  },
  set(value) {
    _zoomed.value = value
    localStorage.setItem('isZoomed', value)
  },
})
const gameWidth = computed(() => isArkadeo.value ? 600 :  (isZoomed.value ? 600 : 300))
const gameHeight = computed(() => isArkadeo.value ? 500 :  (isZoomed.value ? 640 : 320))

const surfaceWidth = computed(() => gameWidth.value + 46)
const surfaceHeight = computed(() => gameHeight.value + 50)

const gameInterfaceStyle = computed(() => {
  return {
    '-webkit-user-select': 'none',
    '-webkit-touch-callout': 'none',
  }
})

// local copy: the prop is not mutated, re-synced when the parent gives another game
const isFavorite = ref(!!props.game.is_favorite)
watch(() => props.game.is_favorite, (value) => {
  isFavorite.value = !!value
})

function toggleFavorite() {
  if (isFavoriteLoading.value) return

  put(`/games/${props.game.id}/favorite`, { is_favorite: !isFavorite.value })
    .then((response) => {
      isFavorite.value = response.data.is_favorite
    })
    .catch(() => null)
}

watchEffect((onInvalidate) => {
  const cb = (e) => {
    if (e.keyCode === 27) {
      isZoomed.value = false
    }
  }
  window.addEventListener('keydown', cb)
  onInvalidate(() => window.removeEventListener('keydown', cb))
})
</script>

<template>
  <MessageError v-if="favoriteError">{{ favoriteError }}</MessageError>
  <div :class="{'w-full h-full fixed z-20 inset-0 bg-black/75': isZoomed}">
    <div :class="isZoomed ? 'fixed w-screen h-dvh flex flex-col overflow-hidden' : 'relative w-full mt-[30px] mb-[50px] mx-auto'" :style="gameInterfaceStyle">
      <div v-if="isZoomed" class="w-full text-center tracking-widest">
        <div class="text-white p-1 cursor-pointer bg-black/75 border border-solid border-black hover:bg-black hover:border-white" @click.prevent="isZoomed = false">
          Désactiver le zoom <span>❌</span>
        </div>
      </div>

      <div :class="isZoomed ? 'flex-1 flex lg:items-center min-h-0' : 'max-h-full h-fit'" class="max-w-full w-fit m-auto overflow-y-auto pt-5">
        <div class="flex flex-col" :class="{ 'w-full': isZoomed, 'lg:flex-col': game.is_arkadeo, 'lg:flex-row': !game.is_arkadeo }">
          <div class="relative gameint1 mx-auto max-w-full! shrink-0" :class="[game.is_arkadeo ? 'aspect-arkadeo' : 'aspect-kadokado', {'order-2 mt-4 lg:order-1 lg:mt-0': isZoomed}]" :style="{ width: surfaceWidth + 'px' }">
            <nav class="absolute -top-10 right-0 text-xs">
              <ul class="flex justify-end gap-2">
                <li class="game-interface-button h-5 hover:h-[18px] hover:mt-0.5">
                  <button
                    type="button"
                    class="w-full h-full pt-1 font-bold text-center hover:text-kado-orange cursor-pointer disabled:cursor-wait"
                    :title="isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris'"
                    :aria-pressed="isFavorite"
                    :disabled="isFavoriteLoading"
                    @click="toggleFavorite"
                  >
                    <img :src="isFavorite ? '/gfx/iconGameLiked.gif' : '/gfx/iconGameDisliked.gif'" alt="" class="size-4" />
                    Favori
                  </button>
                </li>
                <li v-if="!isArkadeo" class="game-interface-button h-5 hover:h-[18px] hover:mt-0.5">
                  <div class="pt-1 font-bold text-center hover:text-kado-orange cursor-pointer"
                       title="Zoom / dézoom"
                       @click.prevent="isZoomed = !isZoomed">
                    <img src="/gfx/iconGameZoom.gif" alt="zoom" class="size-4" />
                    Zoom
                  </div>
                </li>
              </ul>
            </nav>
            <GamesGameScript :game="game" />
          </div>
          <div v-if="!game.is_arkadeo"
               class="gameint2 hidden"
               :class="{ 'lg:block': !isZoomed }"
               :style="{ height: surfaceHeight + 'px' }"></div>
          <!-- Zoomed on mobile, the panel takes its full height: a single scroll goes through it then to the game (no nested scroll that keeps the gesture) -->
          <div class="gameint3 @container min-w-[345px]" :class="{ 'w-full lg:max-w-sm flex-1 order-1 lg:order-2 max-lg:h-auto!': isZoomed, 'w-full': game.is_arkadeo }" :style="{ height: surfaceHeight + 'px' }">
            <GamesGameSide class="overflow-y-auto overflow-x-hidden text-xs h-full"
                           :is-zoomed="isZoomed"
                           :game="game"
                           :goals="goals" />
          </div>
        </div>

      </div>
    </div>
  </div>
</template>
