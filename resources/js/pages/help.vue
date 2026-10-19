<script setup>
// the help as on KadoKado (HelpUI of kk.js, 2008): a box of 400px showing one section at a time with its art on the
// left, the table of content in roman numbers, a "Suivant" button, and the sections sliding from one to the next
const leagueStore = useLeagueStore()
const clanStore = useClanStore()
const route = useRoute()
const router = useRouter()

const stars = [
  { name: 'étoile verte', image: '/gfx/starGreenMedium.gif' },
  { name: 'étoile orange', image: '/gfx/starOrangeMedium.gif' },
  { name: 'étoile rouge', image: '/gfx/starRedMedium.gif' },
]

const art = (name) => `/assets/img/gfx/art/${name}.jpg`
// level 2: a part of the table of content, level 3: one of its sections (those of the clans only once they are open)
const sections = [
  { id: 'bienvenue', title: 'Bienvenue', level: 2, art: art('general') },
  { id: 'periodes', title: 'Les périodes', level: 2, art: art('periode') },
  { id: 'etoiles', title: 'Les étoiles', level: 2, art: art('star') },
  { id: 'niveaux', title: 'Les niveaux', level: 2, art: art('scoring') },
  { id: 'clans', title: 'Les clans', level: 2, art: art('clan'), clan: true },
  { id: 'attaques', title: 'Les attaques', level: 3, art: art('clan'), clan: true },
  { id: 'defenses', title: 'Les défenses', level: 3, art: art('clan'), clan: true },
  { id: 'roles', title: 'Les rôles', level: 3, art: art('clan'), clan: true },
  { id: 'missions', title: 'Les missions', level: 3, art: art('clan'), clan: true },
  { id: 'options', title: 'Les options', level: 3, art: art('clan'), clan: true },
  { id: 'classement', title: 'Le classement des clans', level: 3, art: art('clan'), clan: true },
  { id: 'classementv1', title: 'Le classement V1', level: 2, art: art('general') },
  { id: 'compte', title: 'Mon compte', level: 2, art: art('pks') },
  { id: 'questions', title: 'Questions', level: 2, art: art('gem') },
].filter((section) => clanStore.enabled || !section.clan)

const romans = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X']

// the table of content: the parts and their sections
const toc = sections.reduce((parts, section, index) => {
  if (section.level === 2) {
    parts.push({ ...section, index, children: [] })
  } else {
    parts[parts.length - 1].children.push({ ...section, index })
  }
  return parts
}, [])

const indexOf = (hash) => Math.max(0, sections.findIndex((s) => `#${s.id}` === hash))
const current = ref(indexOf(route.hash))
watch(() => route.hash, (hash) => {
  current.value = indexOf(hash)
})
// "Les attaques" -> "Attaques"
const shortTitle = (section) => {
  const title = section.title.replace(/^(Les?|La) /, '')
  return title.charAt(0).toUpperCase() + title.slice(1)
}
// the part of a section, and of the section shown
const partOf = (index) => [...toc].reverse().find((part) => part.index <= index)
const openPart = computed(() => partOf(current.value) ?? null)
const go = (index) => {
  router.replace({ hash: `#${sections[index].id}` })
}

// the rules of the clans set in the admin (App\Settings\ClanSettings)
if (!clanStore.rules) {
  clanStore.reload()
}
const rules = computed(() => clanStore.rules ?? {})
// "1er", "2e à 5e"
const rank = (n) => (n === 1 ? '1er' : `${n}e`)
const ranks = (reward) => (reward.from === reward.to ? rank(reward.from) : `${rank(reward.from)} à ${rank(reward.to)}`)
const clanRewards = computed(() => [
  { title: 'Classement des attaques', rewards: rules.value.rewards?.war ?? [] },
  { title: 'Classement des missions', rewards: rules.value.rewards?.missions ?? [] },
])
// the seats of a role for a clan of n members (App\Services\ClanService::combatSeats): at least one (nothing while
// the rules load)
const seatsFor = (members, share) => (members && share != null ? Math.max(1, Math.floor((members * share) / 100)) : '')
const gamePacks = computed(() => (rules.value.game_packs ?? []).map((pack) => `${pack.count} pour ${formatScore(pack.price)} points`).join(', '))
</script>

<template>
  <div class="p-2">
    <h1 class="mt-0 text-center">Aide</h1>

    <!-- the table of content: the parts as the tabs of the site, the sections of the open part below -->
    <nav class="mb-3">
      <ul class="flex flex-wrap justify-center gap-1">
        <li v-for="(part, i) in toc" :key="part.id">
          <button type="button"
                  class="h-[26px] cursor-pointer border border-solid bg-repeat-x px-2.5 font-[inherit] text-[15px] leading-6 font-bold whitespace-nowrap [font-variant:small-caps]"
                  :class="openPart?.id === part.id
                    ? 'border-white bg-kado-cyan-800 bg-[url(/gfx/bgTabmenuActive.jpg)] text-white bg-blend-multiply'
                    : 'border-kado-cyan-800 bg-[url(/gfx/bgTabmenu.jpg)] text-kado-blue hover:bg-[url(/gfx/bgTabmenuHover.jpg)] hover:text-kado-cyan-800'"
                  :title="`${romans[i]}. ${part.title}`"
                  @click="go(part.index)">
            {{ part.title }}
          </button>
        </li>
      </ul>
    </nav>

    <!-- one section at a time: they slide in the box -->
    <div class="h-[400px] overflow-hidden">
      <div class="transition-transform duration-[600ms] ease-in-out" :style="{ transform: `translateY(-${current * 400}px)` }">
        <section v-for="(section, index) in sections"
                 :id="`help_${section.id}`"
                 :key="section.id"
                 class="flex h-[400px] gap-3"
                 :aria-hidden="index !== current">
          <img :src="section.art" alt="" class="hidden h-[400px] w-[275px] shrink-0 sm:block" />
          <div class="h-[400px] min-w-0 flex-1 overflow-y-auto [&_h3]:mt-0 [&_h3]:mb-1.5 [&_p]:mt-1 [&_p]:mb-2.5 [&_p]:text-[13px] [&_p]:leading-4 [&_table]:mt-1 [&_table]:mb-2.5 [&_table]:text-[13px] [&_table]:leading-4 [&_ul]:mt-1 [&_ul]:mb-2.5 [&_ul]:pl-2.5 [&_ul]:text-[13px] [&_ul]:leading-4">
            <h3>{{ section.title }}</h3>
            <!-- the sections of the part (the clans), as small links -->
            <nav v-if="partOf(index).children.length" class="mb-2 text-xs">
              <template v-for="(s, i) in [partOf(index), ...partOf(index).children]" :key="s.id">
                <span v-if="i" class="mx-1 text-kado-cyan-800">·</span>
                <strong v-if="s.index === index" class="text-kado-blue">{{ i ? shortTitle(s) : 'Présentation' }}</strong>
                <a v-else href="#" @click.prevent="go(s.index)">{{ i ? shortTitle(s) : 'Présentation' }}</a>
              </template>
            </nav>

            <template v-if="section.id === 'bienvenue'">
              <p>Bienvenue sur <strong>KadoKadéo</strong>, le retour de KadoKado par le projet Eternaltwin ! Retrouvez les jeux de Motion-Twin, battez vos records et grimpez dans les niveaux de chaque jeu.</p>
              <p>Chaque jour, vous disposez d'un nombre de parties à jouer sur les jeux que vous préférez. Le jeu du jour vous propose en plus un contrat : un score à battre pour remporter des <strong>points Kado</strong> <img src="/gfx/skpoint.gif" alt="Kado" class="inline size-4" />.</p>
              <p><template v-if="clanStore.enabled">Rejoignez un clan pour jouer en équipe, et utilisez</template><template v-else>Utilisez</template> ce menu ou le bouton « Suivant » pour découvrir le reste du site !</p>
            </template>

            <template v-else-if="section.id === 'periodes'">
              <p>Une période KadoKadéo se déroule sur deux semaines, soit <strong>14 jours</strong>. Le Kalendrier affiché en haut à droite du site indique la période actuelle ainsi que le jour actuel.</p>
              <p>Quand une période se termine, les classements sont remis à zéro : les meilleurs joueurs de chaque niveau montent au niveau supérieur et remportent des points Kado<template v-if="clanStore.enabled">, et le tournoi des clans recommence</template>.</p>
            </template>

            <template v-else-if="section.id === 'etoiles'">
              <p>Si vous faites un très bon score à un jeu, vous remportez une étoile. Il y a trois niveaux d'étoile pour chaque jeu :</p>
              <ul>
                <li v-for="star in stars" :key="star.name"><img :src="star.image" :alt="star.name" class="inline size-5" /> l'{{ star.name }}</li>
              </ul>
              <p>L'étoile que vous possédez est indiquée sur la boîte de chaque jeu. Les étoiles comptent aussi pour passer au niveau supérieur : il faudra une étoile minimum selon le niveau où vous vous trouvez.</p>
            </template>

            <template v-else-if="section.id === 'niveaux'">
              <p>A chaque passage de niveau, vous obtenez des points Kado supplémentaires, qui augmentent au fur et à mesure que votre niveau progresse :</p>
              <table class="w-full">
                <thead>
                  <tr>
                    <th>Niveau</th>
                    <th>Qualifiés</th>
                    <th>Etoile</th>
                    <th>Points Kado</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="league in leagueStore.leagues" :key="league.level">
                    <td class="!text-left">
                      <div class="flex items-center gap-1">
                        <img :src="`/gfx/leagues/${league.level}.svg`" :alt="league.name" class="h-5">
                        <div>{{ league.name }}</div>
                      </div>
                    </td>
                    <td class="!text-left">
                      <span v-if="league.promotion_ratio">{{ league.promotion_ratio }}% (max {{ league.promotion_max_slots }})</span>
                      <span v-else>{{ league.promotion_max_slots }}</span>
                    </td>
                    <td>
                      <img v-if="league.promotion_min_stars !== null"
                           :src="stars[league.promotion_min_stars].image"
                           :alt="stars[league.promotion_min_stars].name"
                           class="inline h-5">
                    </td>
                    <td class="!text-right whitespace-nowrap">
                      {{ formatScore(league.promotion_reward) }} <img src="/gfx/skpoint.gif" alt="Kado" class="inline size-4">
                    </td>
                  </tr>
                </tbody>
              </table>
              <p>Si un joueur est seul dans son niveau, il ne pourra monter que s'il y a des joueurs dans le niveau suivant. Sinon, il faudra au moins 2 joueurs pour prétendre à monter.</p>
            </template>

            <template v-else-if="section.id === 'clans'">
              <p>Un Clan est un groupe de joueurs (maximum {{ rules.max_members }}) qui se rassemblent pour combattre ensemble contre d'autres clans.</p>
              <p>Vous pouvez soit rejoindre un Clan existant en envoyant votre candidature depuis sa page, soit créer votre propre Clan à partir de la rubrique <RouterLink :to="{ name: 'clans.index' }">Clans</RouterLink>.</p>
              <p v-if="rules.creation_price || rules.application_price">Créer un Clan coûte <strong>{{ formatScore(rules.creation_price ?? 0) }} points Kado</strong> et chaque candidature <strong>{{ formatScore(rules.application_price ?? 0) }} points Kado</strong>. Vous pouvez postuler dans plusieurs clans à la fois : dès qu'un clan vous accepte, vos autres candidatures sont retirées et remboursées. Une candidature refusée ou que vous retirez vous est aussi remboursée.</p>
              <p>Un joueur accepté dans un Clan ne peut pas le quitter ni en être exclu pendant la période où il l'a rejoint.</p>
              <p>Le Clan est dirigé par son <strong>chef</strong>, qui peut nommer des <strong>bras droits</strong> : ils ont tous les droits du chef (candidatures, exclusions, options, rôles), sauf dissoudre le Clan et nommer un nouveau chef.</p>
              <p>Chaque Clan a deux scores et deux positions : une dans le classement des attaques et une dans le classement des missions. Vous pouvez participer à l'un ou l'autre de ces classements, ou aux deux !</p>
              <p>Dans le Clan, les joueurs ont aussi leur classement : 1 point par étape de mission réussie, et les points de chaque attaque et de chaque défense réussies.</p>
            </template>

            <template v-else-if="section.id === 'attaques'">
              <p><img src="/assets/img/gfx/icons/atk.gif" alt="Attaque" class="inline" /> Pour gagner des points, un Clan doit attaquer un autre Clan : allez sur la page d'un Clan adverse, cliquez sur « Attaquer ce clan », choisissez un jeu et effectuez une partie.</p>
              <p>Votre score devient une attaque. Pour la repousser, le Clan adverse devra faire un score supérieur au vôtre. Une attaque repoussée est annulée, et votre Clan ne perd rien.</p>
              <p>Si au bout de <strong>{{ rules.attack_hours }} heures</strong> l'attaque n'a pas été repoussée, votre Clan remporte de 1 à <strong>{{ rules.attack_max_points }} points</strong> et le Clan adverse perd autant (jamais en dessous de zéro). Contre un Clan qui a autant de points que le vôtre ou plus, l'attaque rapporte {{ rules.attack_max_points }} points ; c'est un point de moins par tranche de {{ rules.attack_points_palier }} points qu'il a de moins que vous. Le nombre de points est affiché avant d'attaquer. Attaquez des clans au score proche du vôtre : ceux qui ont plus de {{ rules.protection_range }} points d'écart avec vous sont protégés de vos attaques.</p>
              <p>Chaque joueur peut avoir une attaque en cours à la fois. Pour l'améliorer, cliquez sur « Améliorer » dans l'onglet Statut et rejouez sur le même jeu : le nouveau score ne remplace celui de l'attaque que s'il est meilleur, et le Clan adverse a de nouveau {{ rules.attack_hours }} heures pour le battre.</p>
              <p>Chaque jour, vous avez <strong>{{ rules.attack_games_per_day }} parties gratuites</strong> pour attaquer et défendre (la gemme verte dans le menu du Clan), à part de vos parties normales. Quand elles sont jouées, vous pouvez attaquer et défendre avec des <strong>parties de clan</strong>, achetées avec vos points Kado ({{ gamePacks }}). Vous pouvez les garder pour vous ou les donner à votre Clan : le chef et ses bras droits les distribuent ensuite aux membres. Les parties gratuites du jour ne peuvent pas être données.</p>
            </template>

            <template v-else-if="section.id === 'defenses'">
              <p><img src="/assets/img/gfx/icons/def.gif" alt="Défense" class="inline" /> Les attaques lancées par votre Clan et celles menées contre lui sont indiquées dans l'onglet Statut de votre clan. Cliquez sur « Défendre » et battez le score de l'attaque sur le même jeu.</p>
              <p>Sachez que tant que vous avez une attaque en cours, vous ne pouvez pas défendre ! Il faudra donc coordonner les membres du Clan entre attaquants et défenseurs.</p>
              <p>Un <strong>Défenseur</strong> peut défendre même quand il a une attaque en cours : voyez <a href="#" @click.prevent="go(sections.findIndex((s) => s.id === 'roles'))">les rôles</a>.</p>
              <p>Vous battrez le score d'une attaque plus tard ? Cliquez sur « Réserver » dans l'onglet Statut pour prévenir votre Clan. N'importe quel membre peut prendre la réservation à son tour : c'est seulement une information.</p>
              <p>Pour progresser dans le classement, il faudra à la fois remporter des attaques et défendre efficacement contre les clans ennemis.</p>
            </template>

            <template v-else-if="section.id === 'roles'">
              <p>Pour les attaques et les défenses, chaque joueur du Clan a un rôle. Sans siège, c'est un simple <strong>Membre</strong>. Le chef et ses bras droits peuvent donner les sièges d'<strong>Attaquant</strong> et de <strong>Défenseur</strong> depuis « Gérer le clan ».</p>
              <table class="w-full">
                <thead>
                  <tr>
                    <th class="!text-left">Rôle</th>
                    <th>Attaques en même temps</th>
                    <th>Défendre avec une attaque en cours</th>
                    <th>Sièges</th>
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    <td class="!text-left"><strong>Attaquant</strong></td>
                    <td>2</td>
                    <td>Non</td>
                    <td>{{ rules.attacker_seats }} % des membres</td>
                  </tr>
                  <tr>
                    <td class="!text-left"><strong>Défenseur</strong></td>
                    <td>1</td>
                    <td>Oui</td>
                    <td>{{ rules.defender_seats }} % des membres</td>
                  </tr>
                  <tr>
                    <td class="!text-left"><strong>Membre</strong></td>
                    <td>1</td>
                    <td>Non</td>
                    <td>Les autres</td>
                  </tr>
                </tbody>
              </table>
              <p>Le nombre de sièges dépend du nombre de membres, arrondi en dessous, avec au moins un siège de chaque rôle. Par exemple, un Clan de {{ rules.max_members }} joueurs a {{ seatsFor(rules.max_members, rules.attacker_seats) }} sièges d'Attaquant et {{ seatsFor(rules.max_members, rules.defender_seats) }} de Défenseur ; un Clan de 4 joueurs en a un de chaque.</p>
              <p>Attention, un rôle donné est <strong>bloqué jusqu'à la fin de la période</strong> : il ne peut plus être changé ni retiré avant la période suivante. Choisissez bien vos Attaquants et vos Défenseurs ! Les rôles de chacun sont indiqués dans l'onglet Membres.</p>
            </template>

            <template v-else-if="section.id === 'missions'">
              <p>Votre Clan reçoit des missions : plusieurs étapes, chacune étant un score à atteindre sur un jeu. Vous avez <strong>{{ rules.mission_hours }} heures</strong> pour toutes les réussir. Chacun peut faire les étapes sur les jeux où il est le meilleur, et les parties des missions sont <strong>gratuites et illimitées</strong> !</p>
              <p>Comme pour les défenses, chacun peut « Réserver » une étape pour prévenir le Clan qu'il s'en occupe.</p>
              <p>Plus votre Clan a de membres, plus les missions ont d'étapes : {{ rules.mission_steps_alone }} pour un joueur seul, jusqu'à {{ rules.mission_steps_full }} pour {{ rules.max_members }} joueurs. Le score à atteindre augmente avec les missions, jusqu'à dépasser l'étoile rouge. Chaque mission mélange des étapes de toutes les difficultés, et garde des étapes plus faciles (dès la moitié de l'étoile verte), pour que chacun puisse participer.</p>
              <p>Une mission réussie rapporte <strong>{{ rules.mission_points_first }} points</strong> (un point de moins toutes les {{ rules.mission_points_every }} missions, au moins {{ rules.mission_points_min }}) et ouvre la mission suivante. Si le temps est écoulé, votre Clan perd un point par étape non réussie, moins une, et reçoit une nouvelle mission. Combien de missions votre Clan réussira-t-il ?</p>
            </template>

            <template v-else-if="section.id === 'options'">
              <p>Au début de chaque période, votre Clan reçoit les options Jeu cool et Jeu caca. Chaque mission réussie a {{ rules.bonus_chance }} % de chances de lui en faire gagner une autre. C'est le chef de clan ou un bras droit qui les utilise. Chaque Jeu caca et chaque Jeu cool ajoute un jeu à la liste des jeux caca ou des jeux cool du Clan ; un jeu ne peut être que dans une seule liste. S'il y a plus de jeux cool que d'étapes, la mission en prend une partie au hasard. Elles sont remises à zéro à la fin de la période.</p>
              <table class="w-full">
                <tbody>
                  <tr v-for="bonus in rules.bonuses ?? []" :key="bonus.type">
                    <td class="w-10"><img :src="bonus.icon" :alt="bonus.label" class="size-9 max-w-none"></td>
                    <td class="!text-left text-xs"><strong>{{ bonus.label }}</strong> : {{ bonus.description }}</td>
                  </tr>
                </tbody>
              </table>
            </template>

            <template v-else-if="section.id === 'classement'">
              <p>Le tournoi des clans dure une période. A la fin, les clans les mieux classés de chaque classement remportent des points Kado, répartis à parts égales entre leurs membres. « L'union fait la force » !</p>
              <div class="flex flex-wrap gap-4">
                <table v-for="ranking in clanRewards" :key="ranking.title" class="min-w-48 flex-1">
                  <thead>
                    <tr><th colspan="2" class="text-xs">{{ ranking.title }}</th></tr>
                  </thead>
                  <tbody>
                    <tr v-for="reward in ranking.rewards" :key="reward.from">
                      <td class="!text-left">{{ ranks(reward) }}</td>
                      <td class="!text-right">{{ formatScore(reward.points) }} <img src="/gfx/skpoint.gif" alt="Kado" class="inline size-4"></td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </template>

            <template v-else-if="section.id === 'classementv1'">
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
            </template>

            <template v-else-if="section.id === 'compte'">
              <p>Dans <RouterLink :to="{ name: 'account' }">Mon compte</RouterLink>, vous pouvez changer l'apparence du site.</p>
              <p>Le thème <strong>Karbon</strong> s'achète une seule fois avec vos points Kado : vous pourrez ensuite passer d'un thème à l'autre quand vous le voulez.</p>
            </template>

            <template v-else-if="section.id === 'questions'">
              <p>Vous avez d'autres questions ? Les joueurs de KadoKadéo et l'équipe Eternaltwin vous répondent sur le <a href="https://discord.gg/cqasFsD" target="_blank">Discord KadoKadéo</a>.</p>
              <p>Bon jeu sur KadoKadéo !</p>
            </template>
          </div>
        </section>
      </div>
    </div>

    <p class="flex justify-between">
      <FormButton v-if="current > 0"
                  size="lg"
                  variant="pink"
                  @click="go(current - 1)">Précédent</FormButton>
      <span v-else></span>
      <FormButton v-if="current < sections.length - 1" size="lg" @click="go(current + 1)">Suivant</FormButton>
    </p>
  </div>
</template>

