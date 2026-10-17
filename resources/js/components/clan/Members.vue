<script setup>
// "Membres": the ranking of the members during the period: 1 point by mission step, the points of their successful
// attacks and defenses
const props = defineProps({
  clan: { type: Object, required: true },
})

const route = useRoute()
const router = useRouter()
const { fetchMembers, setStatus, isLoading, error } = useClans()
const members = ref([])

const load = () => fetchMembers(props.clan.id).then((data) => {
  members.value = data.data
})
watchEffect(load)

const sorts = {
  names: (a, b) => a.user.display_name.localeCompare(b.user.display_name),
  points: (a, b) => b.points - a.points,
  performances: (a, b) => b.performance - a.performance,
  attacks: (a, b) => b.attacks_won - a.attacks_won,
  defenses: (a, b) => b.defenses_won - a.defenses_won,
  missions: (a, b) => b.mission_steps - a.mission_steps,
}
const sort = computed(() => (sorts[route.query.sort] ? route.query.sort : 'points'))
const roleLabels = { right_hand: 'Bras droit' }
const combatRoleLabels = { attacker: 'Attaquant', defender: 'Défenseur' }
const sorted = computed(() => [...members.value].sort(sorts[sort.value]))
const sortBy = (key) => router.replace({ query: { ...route.query, sort: key } })

// the totals of the clan
const total = (key) => members.value.reduce((sum, m) => sum + m[key], 0)

// the statuses ("dispo le soir"...), seen by the clan only: his own, or anyone's for the leader and the right hands
const showStatus = computed(() => props.clan.viewer.is_member)
const editing = ref(null)
const draft = ref('')
const editStatus = (m) => {
  editing.value = m.user.etwin_id
  draft.value = m.status ?? ''
}
const saveStatus = (m) => setStatus(props.clan.id, m.user.etwin_id, draft.value).then(() => {
  editing.value = null
  return load()
})
</script>

<template>
  <div class="relative space-y-4">
    <MessageError v-if="error">{{ error }}</MessageError>
    <Loader v-if="isLoading && !members.length" />
    <p class="mx-0">Ce clan comporte {{ members.length }} joueur(s).</p>

    <div class="overflow-x-auto">
      <table class="w-full">
        <thead>
          <tr class="text-[10px] uppercase *:cursor-pointer">
            <th class="min-w-28 text-right" @click="sortBy('names')">Joueur</th>
            <th title="Points dans le clan : 1 point par étape de mission réussie + les points de ses attaques et de ses défenses réussies." @click="sortBy('points')">
              Points
            </th>
            <th title="Performance en attaque et défense : nombre de points rapportés par ses attaques + nombre de points sauvés par ses défenses." @click="sortBy('performances')">
              <img src="/assets/img/gfx/icons/clan_points.gif" alt="performance" class="h-5" />
            </th>
            <th title="Étapes de mission réussies" @click="sortBy('missions')">
              <img src="/assets/img/gfx/icons/sgame.gif" alt="missions" class="h-5" />
            </th>
            <th title="Attaques réussies / lancées" @click="sortBy('attacks')">
              <img src="/assets/img/gfx/icons/atk.gif" alt="attaques" class="h-5" />
            </th>
            <th title="Défenses réussies / tentées" @click="sortBy('defenses')">
              <img src="/assets/img/gfx/icons/def.gif" alt="défenses" class="h-5" />
            </th>
            <th v-if="showStatus" class="min-w-40 cursor-default! text-left" title="Visible uniquement par les membres du clan">Statut</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(m, index) in sorted" :key="m.user.etwin_id" :class="index % 2 ? 'bg-white' : 'bg-kado-cyan-200'">
            <td class="text-right [font-variant:small-caps]">
              <img v-if="m.is_leader"
                   src="/gfx/clan/clanleader.gif"
                   alt="Chef de Clan"
                   title="Chef de Clan"
                   class="mr-1" />
              <RouterLink :to="{ name: 'profile.show', params: { id: m.user.etwin_id } }">{{ m.user.display_name }}</RouterLink>
              <span v-if="roleLabels[m.role] || combatRoleLabels[m.combat_role]" class="ml-1 text-[10px] [font-variant:normal]">
                ({{ [roleLabels[m.role], combatRoleLabels[m.combat_role]].filter(Boolean).join(', ') }})
              </span>
            </td>
            <td class="text-right font-bold"><Number :value="m.points" color="blue" /></td>
            <td class="text-right"><Number :value="m.performance" color="orange" /></td>
            <td class="text-right"><Number :value="m.mission_steps" color="green" /></td>
            <td class="text-right" :title="`${m.attacks_won} réussie(s) sur ${m.attacks}`"><Number :value="m.attacks_won" color="pink" /></td>
            <td class="text-right" :title="`${m.defenses_won} réussie(s) sur ${m.defenses}`"><Number :value="m.defenses_won" color="blue" /></td>
            <td v-if="showStatus" class="text-left text-xs">
              <form v-if="editing === m.user.etwin_id" class="flex items-center gap-1" @submit.prevent="saveStatus(m)">
                <FormInput v-model="draft"
                           maxlength="60"
                           placeholder="Vos dispos, vos absences..."
                           class="w-full min-w-0"
                           @keydown.esc="editing = null" />
                <FormButton type="submit" size="sm">OK</FormButton>
                <FormButton variant="pink" size="sm" @click="editing = null">Annuler</FormButton>
              </form>
              <template v-else>
                <span class="break-words">{{ m.status }}</span>
                <a v-if="m.can_edit_status"
                   href="#"
                   class="ml-1 text-kado-orange"
                   @click.prevent="editStatus(m)">Éditer</a>
              </template>
            </td>
          </tr>
        </tbody>
        <tfoot v-if="members.length > 1">
          <tr class="border-t-2 border-solid border-kado-cyan-800 font-bold">
            <td class="text-right [font-variant:small-caps]">Total</td>
            <td class="text-right"><Number :value="total('points')" color="blue" /></td>
            <td class="text-right"><Number :value="total('performance')" color="orange" /></td>
            <td class="text-right"><Number :value="total('mission_steps')" color="green" /></td>
            <td class="text-right" :title="`${total('attacks_won')} réussie(s) sur ${total('attacks')}`"><Number :value="total('attacks_won')" color="pink" /></td>
            <td class="text-right" :title="`${total('defenses_won')} réussie(s) sur ${total('defenses')}`"><Number :value="total('defenses_won')" color="blue" /></td>
            <td v-if="showStatus" />
          </tr>
        </tfoot>
      </table>
    </div>
  </div>
</template>
