import { defineStore } from 'pinia'
import { ref } from 'vue'

import { useApi } from '@/composables/useApi'

// what the menus need about the clans: the period of the tournament, the clan of the player, the top 3 of the wars and of
// the missions
export const useClanStore = defineStore('clan', () => {
  const tournament = ref(null)
  const clan = ref(null)
  const applications = ref([])
  const top = ref([])
  const topMissions = ref([])
  // the tools of /clans/debug are available (KADO_DEBUG_TOOLS)
  const debug = ref(false)
  // the rules of the clans set in the admin (App\Settings\ClanSettings), shown on the help and the clan pages
  const rules = ref(null)

  const { get } = useApi()

  const reload = () =>
    get('/clans/overview').then((response) => {
      const data = response.data.data
      tournament.value = data.tournament
      clan.value = data.clan
      applications.value = data.applications
      top.value = data.top
      topMissions.value = data.top_missions
      debug.value = data.debug
      rules.value = data.rules
    }).catch(() => {})

  return {
    tournament,
    clan,
    applications,
    top,
    topMissions,
    debug,
    rules,
    reload,
  }
})
