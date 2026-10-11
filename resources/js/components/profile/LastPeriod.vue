<script setup>
import KadoPoints from '@svg/k.svg'

defineProps({
  profile: { type: Object, required: true },
})
</script>

<template>
  <h1 class="mt-0 text-center">Votre dernière période</h1>
  <h2 class="normal-case">Résumé de vos points Kado</h2>
  <ul class="list-inside list-image-[url(/gfx/puce.jpg)] mt-6 mb-6 ml-10">
    <li>Le classement de votre clan vous a rapporté <Number :value="11538" color="green" /> <KadoPoints class="inline size-[17px]" /></li>
    <li>Votre progression sur les jeux vous a rapporté <Number :value="5000" color="green" /> <KadoPoints class="inline size-[17px]" /></li>
    <li>Vos plumes ont rapporté <Number :value="9091" color="green" /> <KadoPoints class="inline size-[17px]" /></li>
    <li>23 x <img src="/gfx/iconGreenStar.gif" alt="Etoile verte" /> vous rapportent <Number :value="230" color="green" /> <KadoPoints class="inline size-[17px]" /></li>
    <li>7 x <img src="/gfx/iconOrangeStar.gif" alt="Etoile orange" /> vous rapportent <Number :value="350" color="green" /> <KadoPoints class="inline size-[17px]" /></li>
    <li>21 x <img src="/gfx/iconRedStar.gif" alt="Etoile rouge" /> vous rapportent <Number :value="2100" color="green" /> <KadoPoints class="inline size-[17px]" /></li>
    <li class="font-bold">Total période : <Number :value="28309" color="green" /> <KadoPoints class="inline size-[17px]" /></li>
  </ul>

  <h2 class="normal-case">Améliorations aux jeux</h2>
  <table class="w-75/100 thinTitles">
    <thead>
      <tr>
        <th> </th>
        <th>Jeu</th>
        <th>Position</th>
        <th>Nvx</th>
        <th>Score</th>
        <th>Gains</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><img src="/gfx/greenArrowUp.png" alt="Qualifié !" /></td>
        <td>
          <RouterLink :to="{ name: 'games.show', params: { id: 7 } }">Interwheel</RouterLink>
        </td>
        <td><Number :value="1" color="orange" /><sup> er</sup></td>
        <td><img src="/gfx/leagues/old/8.png" alt="Ligue or" /></td>
        <td><Number :value="53800" color="blue" /></td>
        <td><Number :value="5000" color="green" /> <KadoPoints class="inline size-[17px]" /></td>
      </tr>
    </tbody>
  </table>

  <h2 class="normal-case">Classement</h2>
  <table class="w-60/100 thinTitles">
    <thead>
      <tr>
        <th>Jeu</th>
        <th>Position</th>
        <th>Nvx</th>
        <th>Score</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><RouterLink :to="{ name: 'games.show', params: { id: 5 } }">Kanji</RouterLink></td>
        <td><Number :value="5" color="orange" /><sup> e</sup></td>
        <td><img src="/gfx/leagues/old/7.png" alt="Ligue argent" /></td>
        <td><Number :value="42800" color="blue" /></td>
      </tr>
      <tr>
        <td><RouterLink :to="{ name: 'games.show', params: { id: 52 } }">Kaskade 2</RouterLink></td>
        <td><Number :value="112" color="orange" /><sup> e</sup></td>
        <td><img src="/gfx/leagues/old/6.png" alt="Ligue bronze" /></td>
        <td><Number :value="152700" color="blue" /></td>
      </tr>
      <tr>
        <td><RouterLink :to="{ name: 'games.show', params: { id: 58 } }">Choco-Mouche</RouterLink></td>
        <td><Number :value="731" color="orange" /><sup> e</sup></td>
        <td><img src="/gfx/leagues/old/1.png" alt="Ligue débutant" /></td>
        <td><Number :value="96100" color="blue" /></td>
      </tr>
      <tr>
        <td><RouterLink :to="{ name: 'games.show', params: { id: 25 } }">F1 Champion</RouterLink></td>
        <td><Number :value="1" color="orange" /><sup> er</sup></td>
        <td><img src="/gfx/leagues/old/9.png" alt="Ligue paradis" /></td>
        <td><Number :value="35142" color="blue" /></td>
      </tr>
    </tbody>
  </table>

  <p class="text-center">
    <input type="button" value="Période précédente" class="pinkButton h-6 w-auto pt-px" />
    <input type="button" value="Période suivante" class="h-6 w-auto pt-px ml-4" />
  </p>
  <!-- <pre>{{ profile }}</pre> -->

</template>