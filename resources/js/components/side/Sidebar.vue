<script setup>
const otherGames = [
  { name: 'Eternalfest', url: 'https://eternalfest.net' },
  { name: 'eMush', url: 'https://emush.eternaltwin.org' },
  { name: 'Neoparc', url: 'https://neoparc.eternal-twin.net' },
  { name: 'MyHordes', url: 'https://myhordes.eu' },
  { name: 'Directquiz', url: 'https://directquiz.org' },
  { name: 'La Brute', url: 'https://brute.eternaltwin.org' },
  { name: 'ePopotamo', url: 'https://epopotamo.eternaltwin.org' },
  { name: 'DinoRPG', url: 'https://dinorpg.eternaltwin.org' },
  { name: 'EternalKingdom', url: 'https://kingdom.eternaltwin.org' },
  { name: 'DinoCard', url: 'https://dinocard.eternaltwin.org/' },
]
</script>

<template>
  <aside id="containerSide" class="z-10">
    <nav class="sideBoxGreen">
      <h2>Menu</h2>
      <ul id="menuSide">
        <li class="news grayscale">
          <RouterLink to="/" title="Nouveautés">Nouveautés</RouterLink>
        </li>
        <li class="scores">
          <RouterLink :to="{ name: 'profile.index' }" title="Mes scores">Mes scores</RouterLink>
        </li>
        <li class="worldrecords">
          <RouterLink :to="{ name: 'site-records' }" title="Records du site">Records du site</RouterLink>
        </li>
        <li class="account grayscale">
          <RouterLink to="/" title="Mon compte">Mon compte</RouterLink>
        </li>
        <li class="forum">
          <a href="https://discord.gg/cqasFsD"
             title="Discord"
             target="_blank"
             rel="noopener noreferrer">Discord</a>
        </li>
        <li class="help">
          <RouterLink :to="{ name: 'help' }" title="Aide">Aide</RouterLink>
        </li>
      </ul>
    </nav>
    <aside class="sideBoxBlue grayscale">
      <h2>Top 3 clans</h2>
      <ul>
        <li class="text-center italic">Non disponible...</li>
      </ul>
    </aside>
    <aside class="sideBoxPink">
      <h2>Nos autres jeux</h2>
      <ul>
        <li class="text-center mb-1">
          <a href="https://eternaltwin.org"
             title="Projet EternalTwin"
             class="font-bold"
             target="_blank">
            Projet EternalTwin
          </a>
          <br />
          <a href="https://discord.gg/ERc3svy" title="Discord EternalTwin" target="_blank">
            Nous rejoindre sur Discord
          </a>
        </li>
        <li>
          <template v-for="og of otherGames" :key="og.name">
            <a :href="og.url" :title="og.name" target="_blank">
              {{ og.name }}
            </a>
            <br />
          </template>
        </li>
      </ul>
    </aside>
  </aside>
</template>
