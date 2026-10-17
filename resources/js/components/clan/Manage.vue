<script setup>
// "Gestion" (the leader and the right hands): the presentation of the clan, the applications, the roles of the members.
// Only the leader names a new leader and disbands the clan.
const props = defineProps({
  clan: { type: Object, required: true },
})
const emit = defineEmits(['updated'])

const router = useRouter()
const authStore = useAuthStore()
const clanStore = useClanStore()
const { updateClan, fetchApplications, acceptApplication, refuseApplication, fetchMembers, kick, promote, setRole, setCombatRole, dissolve, error } = useClans()

const isLeader = computed(() => props.clan.viewer.is_leader)
const description = ref(props.clan.description ?? '')
const isRecruiting = ref(props.clan.is_recruiting)
const saved = ref(false)
const applications = ref([])
const members = ref([])
// the seats of "Attaquant" and "Défenseur": { attacker: { label, description, count }, ... }
const seats = ref({})

const loadApplications = () => fetchApplications(props.clan.id).then((data) => {
  applications.value = data.data
})
const loadMembers = () => fetchMembers(props.clan.id).then((data) => {
  members.value = data.data
  seats.value = data.seats
})
loadApplications()
loadMembers()

const taken = (role) => members.value.filter((m) => m.combat_role === role).length

const save = () =>
  updateClan(props.clan.id, { description: description.value, is_recruiting: isRecruiting.value }).then(() => {
    saved.value = true
    emit('updated')
  })
const accept = (application) => acceptApplication(application.id).then(() => {
  loadApplications()
  loadMembers()
  emit('updated')
})
const refuse = (application) => refuseApplication(application.id).then(loadApplications)
const doKick = (member) => {
  if (confirm(`Exclure ${member.user.display_name} du clan ?`)) {
    kick(props.clan.id, member.user.etwin_id).then(() => {
      loadMembers()
      emit('updated')
    })
  }
}
const doPromote = (member) => {
  if (confirm(`Nommer ${member.user.display_name} chef de clan ? Vous deviendrez son bras droit.`)) {
    promote(props.clan.id, member.user.etwin_id).then(() => {
      clanStore.reload()
      emit('updated')
    })
  }
}
const changeRole = (member, role) => setRole(props.clan.id, member.user.etwin_id, role).finally(loadMembers)
const changeCombatRole = (member, role) => setCombatRole(props.clan.id, member.user.etwin_id, role || null).finally(loadMembers)
const doDissolve = () => {
  if (confirm(`Dissoudre le clan ${props.clan.name} ? Tous ses membres le quitteront et ses scores seront perdus.`)) {
    dissolve(props.clan.id).then(() => {
      clanStore.reload()
      router.push({ name: 'clans.index' })
    })
  }
}
</script>

<template>
  <div class="space-y-4">
    <MessageError v-if="error">{{ error }}</MessageError>

    <h2 class="normal-case">Candidatures</h2>
    <p v-if="!applications.length" class="italic mx-0">Aucune candidature en attente.</p>
    <div v-else class="overflow-x-auto">
      <table class="w-full">
        <tbody>
          <tr v-for="(application, index) in applications" :key="application.id" :class="index % 2 ? 'bg-white' : 'bg-kado-cyan-200'">
            <td class="min-w-28 text-left">
              <RouterLink :to="{ name: 'profile.show', params: { id: application.user.etwin_id } }" class="font-bold">{{ application.user.display_name }}</RouterLink>
              <div v-if="application.message" class="text-sm italic whitespace-pre-line">{{ application.message }}</div>
            </td>
            <td class="whitespace-nowrap">
              <FormButton @click="accept(application)">Accepter</FormButton>
              <FormButton variant="pink" class="ml-1" @click="refuse(application)">Refuser</FormButton>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <h2 class="normal-case">Présentation du clan</h2>
    <form @submit.prevent="save">
      <FormTextarea v-model="description" rows="10" maxlength="5000" />
      <p class="mx-0 mt-1 mb-2 text-xs text-kado-cyan-900">
        Mise en forme (Markdown) : <code># Titre</code>, <code>## Sous-titre</code>, <code>### Petit titre</code>,
        <code>- liste</code>, <code>1. liste numérotée</code>, <code>**gras**</code>, <code>*italique*</code>,
        <code>[lien](https://…)</code>, <code>![image](https://….png)</code>.
      </p>
      <label class="flex items-center gap-2 font-bold">
        <input v-model="isRecruiting" type="checkbox" />
        Le clan recrute de nouveaux membres
      </label>
      <MessageSuccess v-if="saved">Présentation enregistrée.</MessageSuccess>
      <FormButton type="submit" size="lg">Enregistrer</FormButton>
    </form>

    <h2 class="normal-case">Membres</h2>
    <p class="mx-0 text-sm">
      Un <strong>bras droit</strong> a tous les droits du chef de clan, sauf dissoudre le clan et nommer un nouveau chef.
      Un siège choisi ne peut plus changer avant la prochaine période.
      <template v-for="(seat, role) in seats" :key="role">
        <br /><strong>{{ seat.label }}</strong> ({{ taken(role) }} / {{ seat.count }}) : {{ seat.description }}
      </template>
    </p>
    <div class="overflow-x-auto">
      <table class="w-full">
        <tbody>
          <tr v-for="(m, index) in members" :key="m.user.etwin_id" :class="index % 2 ? 'bg-white' : 'bg-kado-cyan-200'">
            <td class="min-w-28 text-left [font-variant:small-caps]">
              <img v-if="m.is_leader"
                   src="/gfx/clan/clanleader.gif"
                   alt="Chef de Clan"
                   title="Chef de Clan"
                   class="mr-1" />
              {{ m.user.display_name }}
            </td>
            <td class="whitespace-nowrap">
              <template v-if="m.is_leader">Chef de clan</template>
              <FormSelect v-else
                          :model-value="m.role"
                          title="Rôle dans le clan"
                          @update:model-value="changeRole(m, $event)">
                <option value="member">Membre</option>
                <option value="right_hand">Bras droit</option>
              </FormSelect>
            </td>
            <td class="whitespace-nowrap">
              <FormSelect :model-value="m.combat_role ?? ''"
                          :disabled="m.combat_role_locked"
                          :title="m.combat_role_locked ? 'Siège choisi pendant cette période : il pourra changer à la prochaine période' : 'Siège pour les attaques et les défenses'"
                          @update:model-value="changeCombatRole(m, $event)">
                <option value="">Sans siège</option>
                <option v-for="(seat, role) in seats"
                        :key="role"
                        :value="role"
                        :disabled="m.combat_role !== role && taken(role) >= seat.count">{{ seat.label }}</option>
              </FormSelect>
            </td>
            <td class="whitespace-nowrap">
              <template v-if="m.user.etwin_id !== authStore.user?.etwin_id && !m.is_leader">
                <FormButton v-if="isLeader" @click="doPromote(m)">Nommer chef</FormButton>
                <FormButton v-if="!m.is_new"
                            variant="pink"
                            class="ml-1"
                            @click="doKick(m)">Exclure</FormButton>
                <span v-else class="ml-1 text-xs italic" title="Un membre accepté pendant la période ne peut être exclu qu'à partir de la prochaine.">Nouveau</span>
              </template>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <template v-if="isLeader">
      <h2 class="normal-case">Dissoudre le clan</h2>
      <p class="mx-0 text-sm">Tous les membres quitteront le clan, et ses scores de la période seront perdus.</p>
      <FormButton variant="pink" @click="doDissolve">Dissoudre le clan</FormButton>
    </template>
  </div>
</template>
