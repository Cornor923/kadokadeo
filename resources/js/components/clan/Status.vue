<script setup>
// "Statut": the attacks launched by the clan and the attacks against it still waiting for a defense, as on the old site
// (the finished ones are in "Historique"), then the wars declared by the clan and against it
const props = defineProps({
  clan: { type: Object, required: true },
})

const router = useRouter()
const clanStore = useClanStore()
const { fetchStatus, defend, improveAttack, cancelAttack, reserveDefense, isLoading, error } = useClans()
const status = ref(null)
const tournament = ref(null)

const load = () =>
  fetchStatus(props.clan.id).then((data) => {
    status.value = data.data
    tournament.value = data.tournament
  })
watchEffect(load)

// only the kinds of attacks there are
const sections = computed(() => [
  { key: 'launched', type: 'atk', title: `Le clan ${props.clan.name} a lancé les attaques suivantes`, attacks: status.value?.launched ?? [] },
  { key: 'received', type: 'def', title: 'Ce clan est attaqué', attacks: status.value?.received ?? [] },
].filter((section) => section.attacks.length))

const goPlay = (data) => router.push({ name: 'clans.play', params: { action: data.data.id } })
const doDefend = (attack) => defend(attack.id).then(goPlay)
const doImprove = (attack) => improveAttack(attack.id).then(goPlay)
// "Je m'en occupe": reserve the defense, take the place of another member, or give it up
const doReserve = (attack) => reserveDefense(attack.id).then(load)
const reserveLabel = (item) => (item.reserved_by_me ? 'Libérer' : item.reserved_by ? 'Prendre' : 'Réserver')
const doCancel = (attack) => {
  if (confirm('Annuler cette attaque ?')) {
    cancelAttack(attack.id).then(() => {
      load()
      clanStore.reload()
    })
  }
}
</script>

<template>
  <div class="relative space-y-4">
    <MessageError v-if="error">{{ error }}</MessageError>
    <Loader v-if="isLoading && !status" />

    <div class="overflow-x-auto">
      <table v-if="status" class="w-full text-sm [&_td]:px-2 [&_td]:py-1">
        <thead>
          <tr class="uppercase text-2xs">
            <th class="min-w-28 text-left!">Joueur</th>
            <th class="min-w-28 text-left!">Clan</th>
            <th class="min-w-24 text-left!">Jeu</th>
            <th class="text-right!">Score</th>
            <th>Statut</th>
          </tr>
        </thead>
        <tbody>
          <!-- no attack: the frame of the table with a single line -->
          <tr v-if="!sections.length" class="bg-kado-cyan-200">
            <td colspan="5" class="py-4 italic text-kado-blue">
              Aucune attaque en cours de ce clan ni contre ce clan.
            </td>
          </tr>
          <template v-for="section in sections" :key="section.key">
            <tr>
              <td colspan="5"
                  class="border border-l border-solid bg-[position:-34px_-6px] bg-no-repeat pl-1! text-left text-[15px] leading-[17px]"
                  :class="section.type === 'atk'
                    ? 'border-kado-pink-400 bg-[#ffe3ec] bg-[url(/gfx/clan/pinkh2_bg.jpg)] text-kado-pink-400'
                    : 'border-kado-cyan-800 bg-[url(/gfx/clan/blueh2_bg.jpg)] text-kado-blue'">
                <img :src="section.type === 'atk' ? '/gfx/clan/atksmall.gif' : '/gfx/clan/defsmall.gif'" alt="" class="mr-1" />
                {{ section.title }}
              </td>
            </tr>
            <tr v-for="(attack, index) in section.attacks" :key="attack.id" :class="index % 2 ? 'bg-white' : 'bg-kado-cyan-200'">
              <td class="text-left [font-variant:small-caps]">
                <RouterLink :to="{ name: 'profile.show', params: { id: attack.attacker.etwin_id } }">{{ attack.attacker.display_name }}</RouterLink>
              </td>
              <td class="text-left font-bold">
                <RouterLink v-if="section.key === 'launched'" :to="{ name: 'clans.show', params: { id: attack.defender_clan.id } }">{{ attack.defender_clan.name }}</RouterLink>
                <RouterLink v-else :to="{ name: 'clans.show', params: { id: attack.attacker_clan.id } }">{{ attack.attacker_clan.name }}</RouterLink>
              </td>
              <td class="text-left">
                <RouterLink :to="{ name: 'games.show', params: { id: attack.game.id } }" class="text-kado-blue">{{ attack.game.name }}</RouterLink>
              </td>
              <td class="text-right font-bold text-kado-blue whitespace-nowrap">
                <Number :value="attack.score" color="blue" />
              </td>
              <td class="whitespace-nowrap">
                <!-- the countdown, then the small buttons of what the player can do -->
                <div class="flex flex-col items-center justify-center gap-2">
                  <ClanCountdown :until="attack.expires_at" @done="load" />
                  <FormButton v-if="attack.can_defend" size="sm" @click="doDefend(attack)">Défendre</FormButton>
                  <FormButton v-if="attack.can_improve"
                              size="sm"
                              title="Rejouer pour améliorer cette attaque : le nouveau score ne compte que s'il est meilleur"
                              @click="doImprove(attack)">Améliorer</FormButton>
                  <FormButton v-if="attack.can_cancel"
                              size="sm"
                              variant="pink"
                              title="Annuler cette attaque"
                              @click="doCancel(attack)">Annuler</FormButton>
                  <FormButton v-if="attack.can_reserve"
                              size="sm"
                              :variant="attack.reserved_by_me ? 'pink' : 'green'"
                              title="Je m'en occupe : prévenez votre clan que vous battrez ce score plus tard"
                              @click="doReserve(attack)">{{ reserveLabel(attack) }}</FormButton>
                  <span v-if="attack.reserved_by" class="text-xs italic">Réservée par {{ attack.reserved_by.display_name }}</span>
                </div>
              </td>
            </tr>
          </template>
        </tbody>
      </table>
    </div>

    <!-- the wars declared by the clan (its targets) and against it -->
    <template v-if="status?.wars?.length">
      <h2 class="normal-case">Clans en guerre</h2>
      <ul class="list-inside list-image-[url(/gfx/puce.jpg)] ml-4 space-y-1">
        <li v-for="war in status.wars" :key="war.id">
          <template v-for="(side, index) in [war.clan, war.target]" :key="side.id">
            <strong v-if="side.id === clan.id">{{ side.name }}</strong>
            <RouterLink v-else :to="{ name: 'clans.status', params: { id: side.id } }" class="font-bold">{{ side.name }}</RouterLink>
            <template v-if="index === 0"> a déclaré la guerre à </template>
          </template>
        </li>
      </ul>
    </template>
  </div>
</template>
