<script setup>
const clanStore = useClanStore()
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
        <li class="account">
          <RouterLink :to="{ name: 'account' }" title="Mon compte">Mon compte</RouterLink>
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
    <aside class="sideBoxBlue">
      <h2>Top 3 clans de guerre</h2>
      <ul>
        <li v-for="clan in clanStore.top" :key="clan.id" class="flex justify-between gap-1">
          <RouterLink :to="{ name: 'clans.show', params: { id: clan.id } }" class="truncate">{{ clan.rank }}. {{ clan.name }}</RouterLink>
          <Number :value="clan.war_score" color="orange" />
        </li>
        <li v-if="!clanStore.top.length" class="text-center italic">Aucun clan</li>
        <li class="text-center mt-1">
          <RouterLink :to="{ name: 'clans.index', query: { tab: 'war' } }">Classement des attaques</RouterLink>
        </li>
      </ul>
    </aside>
    <aside class="sideBoxViolet">
      <h2>Top 3 clans de mission</h2>
      <ul>
        <li v-for="clan in clanStore.topMissions" :key="clan.id" class="flex justify-between gap-1">
          <RouterLink :to="{ name: 'clans.show', params: { id: clan.id } }" class="truncate">{{ clan.rank }}. {{ clan.name }}</RouterLink>
          <Number :value="clan.mission_score" color="violet" />
        </li>
        <li v-if="!clanStore.topMissions.length" class="text-center italic">Aucun clan</li>
        <li class="text-center mt-1">
          <RouterLink :to="{ name: 'clans.index', query: { tab: 'missions' } }">Classement des missions</RouterLink>
        </li>
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
