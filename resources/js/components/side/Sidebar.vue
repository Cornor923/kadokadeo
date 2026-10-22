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
// the menu: each link with its icon
const menu = [
  { label: 'Nouveautés', to: '/', icon: 'bg-[url(/gfx/menuIconNews.gif)] bg-[position:0_2px]', disabled: true },
  { label: 'Mes scores', to: { name: 'profile.index' }, icon: 'bg-[url(/gfx/menuIconScores.gif)] bg-[position:-2px_3px]' },
  { label: 'Records du site', to: { name: 'site-records' }, icon: 'bg-[url(/gfx/iconKingPiou.png)] bg-[position:-2px_-1px] bg-size-[auto_22px]' },
  { label: 'Mon compte', to: { name: 'account' }, icon: 'bg-[url(/gfx/menuIconAccount.gif)] bg-[position:0_3px]' },
  { label: 'Discord', href: 'https://discord.gg/cqasFsD', icon: 'bg-[url(/gfx/menuIconForum.gif)] bg-[position:0_1px]' },
  { label: 'Aide', to: { name: 'help' }, icon: 'bg-[url(/gfx/menuIconHelp.gif)] bg-[position:-3px_0]' },
]
const menuLinkClasses = 'my-px block w-full bg-no-repeat pl-6.25 hover:pl-6.75 hover:no-underline'
</script>

<template>
  <aside class="z-10">
    <KadoSideBox title="Menu" color="green" as="nav">
      <ul class="m-1.25 text-[1.5em]">
        <li v-for="item in menu" :key="item.label" :class="{ grayscale: item.disabled }">
          <a v-if="item.href"
             :href="item.href"
             :title="item.label"
             :class="[menuLinkClasses, item.icon]"
             target="_blank"
             rel="noopener noreferrer">{{ item.label }}</a>
          <RouterLink v-else
                      :to="item.to"
                      :title="item.label"
                      :class="[menuLinkClasses, item.icon]">{{ item.label }}</RouterLink>
        </li>
      </ul>
    </KadoSideBox>
    <!-- the clans turned off in the admin: the boxes greyed, without their rankings -->
    <KadoSideBox title="Top 3 clans de guerre" color="blue" :class="{ grayscale: !clanStore.enabled }">
      <ul v-if="!clanStore.enabled" class="m-1.25">
        <li class="text-center italic">Prochainement disponible</li>
      </ul>
      <ul v-else class="m-1.25">
        <li v-for="clan in clanStore.top" :key="clan.id" class="flex justify-between gap-1">
          <RouterLink :to="{ name: 'clans.show', params: { id: clan.id } }" class="truncate">{{ clan.rank }}. {{ clan.name }}</RouterLink>
          <Number :value="clan.war_score" color="orange" />
        </li>
        <li v-if="!clanStore.top.length" class="text-center italic">Aucun clan</li>
        <li class="text-center mt-1">
          <RouterLink :to="{ name: 'clans.index', query: { tab: 'war' } }">Classement des attaques</RouterLink>
        </li>
      </ul>
    </KadoSideBox>
    <KadoSideBox title="Top 3 clans de mission" color="violet" :class="{ grayscale: !clanStore.enabled }">
      <ul v-if="!clanStore.enabled" class="m-1.25">
        <li class="text-center italic">Prochainement disponible</li>
      </ul>
      <ul v-else class="m-1.25">
        <li v-for="clan in clanStore.topMissions" :key="clan.id" class="flex justify-between gap-1">
          <RouterLink :to="{ name: 'clans.show', params: { id: clan.id } }" class="truncate">{{ clan.rank }}. {{ clan.name }}</RouterLink>
          <Number :value="clan.mission_score" color="violet" />
        </li>
        <li v-if="!clanStore.topMissions.length" class="text-center italic">Aucun clan</li>
        <li class="text-center mt-1">
          <RouterLink :to="{ name: 'clans.index', query: { tab: 'missions' } }">Classement des missions</RouterLink>
        </li>
      </ul>
    </KadoSideBox>
    <KadoSideBox title="Nos autres jeux" color="pink">
      <ul class="m-1.25">
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
    </KadoSideBox>
  </aside>
</template>
