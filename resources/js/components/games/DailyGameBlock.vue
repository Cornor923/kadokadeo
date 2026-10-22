<script setup>
import KadoPoints from '@svg/k.svg'

const dailyGameStore = useDailyGameStore()
const dailyGame = toRef(dailyGameStore, 'dailyGame')
const game = toRef(dailyGameStore, 'game')
</script>

<template>
  <Loader v-if="dailyGameStore.isDailyGameLoading" />
  <div v-else-if="game" class="mx-auto mb-10 w-full max-w-[700px] md:h-[142px]">
    <RouterLink
      class="relative z-[2] flex w-full flex-col overflow-hidden md:h-full md:flex-row decoration-0"
      :class="{ grayscale: dailyGameStore.position !== null }"
      :to="{ name: 'games.daily' }"
      :title="`Jouer au jeu du jour`"
    >
      <div class="relative w-full aspect-[113/71] bg-[url('/gfx/gameBoxDayLeft.png')] bg-no-repeat bg-[length:100%_100%] md:w-[226px] md:h-[142px] md:aspect-auto md:shrink-0">
        <div class="absolute left-[15.93%] top-[5.63%] w-[77.88%] md:left-9 md:top-2 md:w-[176px]">
          <img class="w-full h-auto" :src="game.image_path" :alt="game.name" />
          <h3 class="w-full text-center text-xl font-normal leading-5 text-kado-pink-900">
            {{ game.name }}
          </h3>
        </div>
      </div>
      <div class="relative min-h-[142px] flex-1 daily-game-frame text-sm font-normal text-kado-pink-900">
        <div class="absolute -top-8 text-kado-pink-100 font-junegull text-shadow-sm text-shadow-kado-pink-300 text-lg w-full text-center">JEU DU JOUR</div>
        Le jeu du jour est choisi aléatoirement chaque jour à minuit (UTC). La partie est identique pour tous les joueurs.
        <div class="flex items-center gap-1">
          Contrat :
          <Number :value="dailyGame.contract_score" color="blue" />
          pts pour gagner
          <Number :value="dailyGame.contract_points" color="green" />
          <KadoPoints class="inline size-4" />
        </div>
        <div v-if="!dailyGameStore.isScoresLoading" class="flex items-center gap-1">
          Nombre de parties restantes :
          <Number :value="dailyGameStore.position === null ? 1 : 0" color="orange" />
          <img class="size-4" src="/gfx/gemOrange.svg" alt="icone gemme orange" />
        </div>
        <div v-if="dailyGameStore.position !== null" class="flex items-center gap-1">
          Votre position actuelle :
          <Number :value="dailyGameStore.position" color="green" />
        </div>
      </div>
    </RouterLink>
  </div>
</template>

