<script setup>
import KadoPoints from '@svg/k.svg'
// "Parties de clan": the paid games of the player for the attacks and the defenses (used once the games of the day are),
// bought by packs with Kado points, given to the clan, distributed by the leader and the right hands
const props = defineProps({
  clan: { type: Object, required: true },
})
const emit = defineEmits(['updated'])

const authStore = useAuthStore()
const { fetchClanGames, buyClanGames, donateClanGames, distributeClanGames, fetchMembers, isLoading, error } = useClans()
const data = ref(null)
const members = ref([])
const donateCount = ref(1)
const distribution = reactive({ member: null, count: 1 })
const notice = ref(null)

const load = () => fetchClanGames().then((response) => {
  data.value = response.data
  if (response.data.clan?.can_distribute && !members.value.length) {
    fetchMembers(props.clan.id).then((membersData) => {
      members.value = membersData.data
    })
  }
})
load()

const done = (message) => {
  notice.value = message
  authStore.fetchUser()
  load()
  // the chest of the clan in its menu
  emit('updated')
}
const buy = (pack) => {
  const s = pack.count > 1 ? 's' : ''
  if (confirm(`Acheter ${pack.count} partie${s} de clan pour ${pack.price} points Kado ?`)) {
    buyClanGames(pack.count).then(() => done(`${pack.count} partie${s} de clan achetée${pack.count > 1 ? 's' : ''} !`))
  }
}
const donate = () => donateClanGames(props.clan.id, donateCount.value).then(() => done(`${donateCount.value} partie${donateCount.value > 1 ? 's' : ''} donnée${donateCount.value > 1 ? 's' : ''} au clan.`))
const distribute = () => {
  const member = members.value.find((m) => m.user.etwin_id === distribution.member)
  distributeClanGames(props.clan.id, distribution.member, distribution.count)
    .then(() => done(`${distribution.count} partie${distribution.count > 1 ? 's' : ''} donnée${distribution.count > 1 ? 's' : ''} à ${member?.user.display_name}.`))
}
</script>

<template>
  <div class="relative space-y-4">
    <MessageError v-if="error">{{ error }}</MessageError>
    <MessageSuccess v-else-if="notice">{{ notice }}</MessageSuccess>
    <Loader v-if="isLoading && !data" />

    <template v-if="data">
      <p class="mx-0">
        Chaque jour, vous avez <Number :value="data.attack_games" color="green" /> partie(s) gratuite(s) pour attaquer et
        défendre (sur {{ data.attack_games_per_day }} par jour). Une fois jouées, les attaques et les défenses utilisent vos
        parties de clan achetées. Les missions, elles, sont gratuites et illimitées. Vous avez
        <Number :value="data.games" color="blue" /> partie(s) de clan et <strong>{{ formatScore(data.kado_points) }}</strong>
        points Kado.
      </p>

      <h2 class="normal-case">Acheter des parties</h2>
      <div class="space-y-2">
        <FormButton v-for="pack in data.packs"
                    :key="pack.count"
                    :disabled="data.kado_points < pack.price"
                    :title="data.kado_points < pack.price ? 'Vous n\'avez pas assez de points Kado' : `${pack.unit_price} points Kado la partie`"
                    @click="buy(pack)"
                    class="flex items-center gap-1">
          {{ pack.count }} partie{{ pack.count > 1 ? 's' : '' }} : {{ formatScore(pack.price) }} <KadoPoints class="inline size-4"/>
        </FormButton>
      </div>

      <h2 class="normal-case">Donner au clan</h2>
      <p class="mx-0 text-sm">
        Vous pouvez donner à votre clan les parties que vous avez achetées (pas vos parties gratuites du jour). Le chef et ses bras
        droits les distribueront aux membres. Le clan possède <Number :value="data.clan.games" color="orange" /> <img src="/gfx/gemOrange.svg" class="w-5 max-w-none"> parties en stock.
      </p>
      <form class="flex items-center gap-2" @submit.prevent="donate">
        <FormInput v-model.number="donateCount"
                   type="number"
                   min="1"
                   :max="data.games"
                   class="w-20" />
        <FormButton type="submit" size="lg" :disabled="data.games < 1">Donner</FormButton>
      </form>

      <template v-if="data.clan.can_distribute">
        <h2 class="normal-case">Distribuer les parties du clan</h2>
        <form class="flex flex-wrap items-center gap-2" @submit.prevent="distribute">
          <FormSelect v-model="distribution.member">
            <option :value="null" disabled>Choisir un joueur</option>
            <option v-for="m in members" :key="m.user.etwin_id" :value="m.user.etwin_id">{{ m.user.display_name }}</option>
          </FormSelect>
          <FormInput v-model.number="distribution.count"
                     type="number"
                     min="1"
                     :max="data.clan.games"
                     class="w-20" />
          <FormButton type="submit" size="lg" :disabled="!distribution.member || data.clan.games < 1">Distribuer</FormButton>
        </form>
      </template>

      <template v-if="data.clan.transfers.length">
        <h2 class="normal-case">Derniers dons</h2>
        <ul class="list-inside list-image-[url(/gfx/puce.jpg)] ml-4 space-y-1 text-sm">
          <li v-for="(transfer, index) in data.clan.transfers" :key="index">
            <template v-if="transfer.type === 'donation'">{{ transfer.from?.display_name }} a donné {{ transfer.count }} partie(s) au clan</template>
            <template v-else>{{ transfer.from?.display_name }} a donné {{ transfer.count }} partie(s) à {{ transfer.to?.display_name }}</template>
          </li>
        </ul>
      </template>
    </template>
  </div>
</template>
