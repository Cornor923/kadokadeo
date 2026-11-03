<script setup>
// tools to try the clans alone (KADO_DEBUG_TOOLS, never in production): attacks and defenses with a chosen score,
// mission steps, the time going by, the end of the period
const clanStore = useClanStore()
const { fetchState, run: runAction, isLoading, error } = useClanDebug()

const data = ref(null)
const log = ref([])
const attack = reactive({ attacker_clan_id: null, defender_clan_id: null, game_id: null, score: 1000 })
const defenseScores = reactive({})

const load = () => fetchState().then((state) => {
  data.value = state
  attack.attacker_clan_id ??= data.value.my_clan_id ?? data.value.clans[0]?.id ?? null
  attack.defender_clan_id ??= data.value.clans.find((c) => c.id !== attack.attacker_clan_id)?.id ?? null
  attack.game_id ??= data.value.games[0]?.id ?? null
})
load()

const run = (action, payload = {}) =>
  runAction(action, payload).then((result) => {
    log.value.unshift(`${new Date().toLocaleTimeString('fr-FR')} — ${result.result}`)
    clanStore.reload()
    load()
  })
const swap = () => {
  [attack.attacker_clan_id, attack.defender_clan_id] = [attack.defender_clan_id, attack.attacker_clan_id]
}
const endPeriod = () => {
  if (confirm('Terminer la période en cours ? Les classements des clans sont calculés, les points Kado distribués et une nouvelle période commence.')) {
    run('end-period')
  }
}
</script>

<template>
  <NavTabs :items="[{ label: 'Debug clans', value: 'debug' }]" />

  <div class="relative px-2 space-y-4">
    <KadoPageTitle>Debug clans</KadoPageTitle>
    <p class="text-sm">
      Outils de test (variable <code>KADO_DEBUG_TOOLS</code>, jamais en production) : les parties sont simulées avec le
      score choisi, par vous si vous êtes membre du clan, sinon par son chef.
      <RouterLink :to="{ name: 'clans.index' }">Retour aux clans</RouterLink>
    </p>

    <MessageError v-if="error">{{ error }}</MessageError>
    <Loader v-if="isLoading && !data" />

    <ul v-if="log.length" class="max-h-28 overflow-y-auto border-2 border-white bg-white/70 p-2 text-xs">
      <li v-for="(line, i) in log" :key="i">{{ line }}</li>
    </ul>

    <template v-if="data">
      <p class="text-sm">Période {{ data.period?.id ?? '—' }}, fin le {{ data.period ? new Date(data.period.end_at).toLocaleString('fr-FR') : '—' }}</p>

      <KadoSectionTitle>Lancer une attaque</KadoSectionTitle>
      <form class="flex flex-wrap items-end gap-2" @submit.prevent="run('attack', attack)">
        <label class="flex flex-col text-sm">Clan attaquant
          <FormSelect v-model="attack.attacker_clan_id" class="p-1">
            <option v-for="c in data.clans" :key="c.id" :value="c.id">{{ c.name }} ({{ c.war_score }})</option>
          </FormSelect>
        </label>
        <FormButton size="lg" title="Inverser" @click="swap">⇄</FormButton>
        <label class="flex flex-col text-sm">Clan attaqué
          <FormSelect v-model="attack.defender_clan_id" class="p-1">
            <option v-for="c in data.clans" :key="c.id" :value="c.id">{{ c.name }} ({{ c.war_score }})</option>
          </FormSelect>
        </label>
        <label class="flex flex-col text-sm">Jeu
          <FormSelect v-model="attack.game_id" class="p-1">
            <option v-for="g in data.games" :key="g.id" :value="g.id">{{ g.name }}</option>
          </FormSelect>
        </label>
        <label class="flex flex-col text-sm">Score
          <FormInput v-model.number="attack.score"
                     type="number"
                     min="0"
                     class="w-24" />
        </label>
        <FormButton type="submit" size="lg" variant="pink">Attaquer</FormButton>
      </form>

      <KadoSectionTitle>Attaques en cours</KadoSectionTitle>
      <p v-if="!data.attacks.length" class="italic text-sm">Aucune attaque en cours.</p>
      <KadoTable v-else class="w-full text-sm">
        <thead>
          <tr class="text-[10px] uppercase">
            <th>Attaque</th>
            <th>Jeu</th>
            <th>Score</th>
            <th>Fin</th>
            <th>Défendre</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(a, i) in data.attacks" :key="a.id" :class="i % 2 ? 'bg-white' : 'bg-kado-blue-100'">
            <td class="text-left">{{ a.attacker }} ({{ a.attacker_clan }}) → {{ a.defender_clan }}</td>
            <td>{{ a.game }}</td>
            <td class="font-bold">{{ a.score }}</td>
            <td><ClanCountdown :until="a.expires_at" /></td>
            <td class="whitespace-nowrap">
              <FormInput v-model.number="defenseScores[a.id]"
                         type="number"
                         min="0"
                         :placeholder="a.score + 1"
                         class="w-20" />
              <FormButton class="ml-1" @click="run(`attacks/${a.id}/defend`, { score: defenseScores[a.id] ?? a.score + 1 })">Défendre</FormButton>
            </td>
          </tr>
        </tbody>
      </KadoTable>

      <KadoSectionTitle>Mission de mon clan</KadoSectionTitle>
      <p v-if="!data.mission" class="italic text-sm">Vous ne faites partie d'aucun clan.</p>
      <template v-else>
        <p class="text-sm">Mission {{ data.mission.number }} ({{ data.mission.steps.length }} étapes, {{ data.mission.reward }} points si elle est réussie), fin dans <ClanCountdown :until="data.mission.expires_at" /></p>
        <ul class="space-y-1 text-sm">
          <li v-for="step in data.mission.steps" :key="step.id" class="flex items-center gap-2">
            <span>{{ step.game }} : {{ step.target_score }} pts</span>
            <strong v-if="step.done" class="text-kado-green-600">réussie</strong>
            <FormButton v-else @click="run(`mission-steps/${step.id}`)">Réussir l'étape</FormButton>
          </li>
        </ul>
      </template>

      <KadoSectionTitle>Le temps</KadoSectionTitle>
      <p class="mx-2.5 flex flex-wrap gap-2">
        <FormButton v-for="h in [1, 6, 12, 24]"
                    :key="h"
                    size="lg"
                    @click="run('time', { hours: h })">+{{ h }}h</FormButton>
        <FormButton size="lg" variant="pink" @click="endPeriod">Terminer la période</FormButton>
      </p>
      <p class="my-4 text-xs">« +12h » fait réussir les attaques non repoussées et échouer les missions en cours qui dépassent leur temps.</p>
    </template>
  </div>
</template>

