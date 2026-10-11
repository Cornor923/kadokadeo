<script setup>
const leagueStore = useLeagueStore()
const stars = [
  { name: 'étoile verte', image: '/gfx/starGreenMedium.gif' },
  { name: 'étoile orange', image: '/gfx/starOrangeMedium.gif' },
  { name: 'étoile rouge', image: '/gfx/starRedMedium.gif' },
]

// const colors = {
//   'kado-orange': 'bg-kado-orange',
//   'kado-yellow': 'bg-kado-yellow',
//   'kado-cream': 'bg-kado-cream',
//   'kado-cyan-50': 'bg-kado-cyan-50',
//   'kado-cyan-100': 'bg-kado-cyan-100',
//   'kado-cyan-200': 'bg-kado-cyan-200',
//   'kado-cyan-300': 'bg-kado-cyan-300',
//   'kado-cyan-400': 'bg-kado-cyan-400',
//   'kado-cyan-500': 'bg-kado-cyan-500',
//   'kado-cyan-muted': 'bg-kado-cyan-muted',
//   'kado-cyan-600': 'bg-kado-cyan-600',
//   'kado-cyan-650': 'bg-kado-cyan-650',
//   'kado-cyan-700': 'bg-kado-cyan-700',
//   'kado-cyan-750': 'bg-kado-cyan-750',
//   'kado-cyan-800': 'bg-kado-cyan-800',
//   'kado-cyan-900': 'bg-kado-cyan-900',
//   'kado-cyan-950': 'bg-kado-cyan-950',
//   'kado-slate-400': 'bg-kado-slate-400',
//   'kado-green-50': 'bg-kado-green-50',
//   'kado-green-100': 'bg-kado-green-100',
//   'kado-green-500': 'bg-kado-green-500',
//   'kado-green-600': 'bg-kado-green-600',
//   'kado-play-400': 'bg-kado-play-400',
//   'kado-play-500': 'bg-kado-play-500',
//   'kado-play-700': 'bg-kado-play-700',
//   'kado-play-900': 'bg-kado-play-900',
//   'kado-pink-50': 'bg-kado-pink-50',
//   'kado-pink-400': 'bg-kado-pink-400',
//   'kado-pink-600': 'bg-kado-pink-600',
//   'kado-pink-900': 'bg-kado-pink-900',
// }
</script>

<template>
  <div class="p-2">
    <h1 class="text-center">Aide</h1>

    <h3>Les niveaux</h3>
    <p>A chaque passage de niveau, vous obtenez des points Kado supplémentaires, qui augmenteront de plus en plus au fur et à mesure que votre niveau progressera :</p>
    <table>
      <thead>
        <tr>
          <th>Niveau</th>
          <th>Nombre de joueurs qualifiés</th>
          <th>Etoile minimum requise</th>
          <th>Points Kado</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="league in leagueStore.leagues" :key="league.level">
          <td class="!text-left">
            <div class="flex items-center space-x-2">
              <img :src="`/gfx/leagues/${league.level}s.svg`" :alt="league.name" class="w-10 h-auto">
              <div>{{ league.name }}</div>
            </div>
          </td>
          <td class="!text-left">
            <span v-if="league.promotion_ratio">
              {{ league.promotion_ratio }}% des joueurs jusqu'à {{ league.promotion_max_slots }} max
            </span>
            <span v-else>
              {{ league.promotion_max_slots }}
            </span>
          </td>
          <td>
            <img v-if="league.promotion_min_stars !== null" :src="stars[league.promotion_min_stars].image" :alt="stars[league.promotion_min_stars].name">
          </td>
          <td>
            <div class="flex space-x-1 items-center justify-end">
              <div>{{ formatScore(league.promotion_reward) }}</div>
              <img src="/gfx/skpoint.gif" alt="Kado" class="w-5 h-5">
            </div>
          </td>
        </tr>
      </tbody>
    </table>

    <p>Il n'y a pas de nombre de joueur minimum pour le passage d'un niveau à un autre. Par contre, il vous faudra avoir des étoiles minimum pour pouvoir être promu selon le niveau où vous vous trouvez.</p>
    <p>Par exemple, pour le niveau Bronze, vous devrez avoir au moins l'étoile orange pour vous qualifier.</p>

    <p>Si un joueur est seul dans son niveau, il ne pourra monter que s'il y a des joueurs dans le niveau suivant. Sinon, il faudra au moins 2 joueurs pour prétendre à monter.</p>

    <h3>Classement V1</h3>

    <p>Chaque période, la compétition du classement V1 a lieu. Il s'agit d'un classement dans lequel les 12 meilleurs scores de chaque joueur sont additionnés pour atteindre un maximum de 18.000 points</p>
    <p>Les scores de chaque jeu sont convertis dans une échelle allant de 0 à 1500 selon les critères suivants : </p>

    <table>
      <thead>
        <tr>
          <th>Score atteint</th>
          <th>Nombre de points V1</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td><img src="/gfx/iconGreenStar.gif" alt="Etoile verte" /></td>
          <td>1000</td>
        </tr>
        <tr>
          <td><img src="/gfx/iconOrangeStar.gif" alt="Etoile orange" /></td>
          <td>1100</td>
        </tr>
        <tr>
          <td><img src="/gfx/iconRedStar.gif" alt="Etoile rouge" /></td>
          <td>1150</td>
        </tr>
        <tr>
          <td>Score V1</td>
          <td>1500</td>
        </tr>
      </tbody>
    </table>

    <!-- <div class="grid grid-cols-2">
      <div v-for="(colorClass, colorName) in colors" :key="colorName" class="h-10 flex items-center relative">
        <div :class="['h-10 w-full', colorClass]"></div>
        <div class="text-shadow-lg text-shadow-white text-black absolute place-self-center left-1/2 -translate-x-1/2">{{ colorName }}</div>
      </div>
    </div> -->
  </div>
</template>
