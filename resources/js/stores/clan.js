import { defineStore } from 'pinia'
import { ref } from 'vue'

import { useApi } from '@/composables/useApi'
import { clanToast } from '@/composables/useNotifications'
import { onRealtimeReconnect, refetchSoon, useChannel } from '@/composables/useRealtime'
import { useAuthStore } from '@/stores/auth'
import { useToastStore } from '@/stores/toast'

// what the menus need about the clans: the period of the tournament, the clan of the player, the top 3 of the wars and of
// the missions. The channel of the clan of the player is listened to while he is in it: the feats of the other members in
// toasts (App\Events\ClanToast), the menus again when the members change (App\Events\ClanUpdated)
export const useClanStore = defineStore('clan', () => {
  // the clans are open (App\Settings\ClanSettings::$enabled): else their pages are closed and their API refused
  const enabled = Boolean(window.Kado?.clans_enabled)
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

  const reload = () => {
    if (!enabled) {
      return Promise.resolve()
    }
    return get('/clans/overview').then((response) => {
      const data = response.data.data
      tournament.value = data.tournament
      clan.value = data.clan
      applications.value = data.applications
      top.value = data.top
      topMissions.value = data.top_missions
      debug.value = data.debug
      rules.value = data.rules
    }).catch(() => {})
  }

  const authStore = useAuthStore()
  const toastStore = useToastStore()
  const reloadSoon = refetchSoon(reload, { delay: 300, jitter: 700 })
  useChannel(() => (enabled && clan.value ? `clans.${clan.value.id}` : null), {
    'clan.toast': (e) => {
      const toast = e.player?.etwin_id !== authStore.user?.etwin_id ? clanToast(e) : null
      if (toast) {
        toastStore.show(toast)
      }
    },
    // excluded, the clan disbanded, a new right hand (can_manage)...
    'clan.updated': (e) => (e.parts.includes('members') || e.parts.includes('clan')) && reloadSoon(),
  })
  onRealtimeReconnect(() => clan.value && reload())

  return {
    enabled,
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
