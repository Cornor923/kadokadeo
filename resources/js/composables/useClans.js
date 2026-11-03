import { ref, toValue } from 'vue'

import { useApi } from './useApi'
import { usePaginatedList } from './usePaginatedList'

// the clans (App\Http\Controllers\Api\Clan*Controller)
export function useClans() {
  const { isLoading, error, get, post, put, del } = useApi()

  const data = (response) => response.data

  return {
    isLoading,
    error,
    createClan: (payload) => post('/clans', payload).then(data),
    fetchClan: (id) => get(`/clans/${id}`).then(data),
    updateClan: (id, payload) => put(`/clans/${id}`, payload),
    fetchMembers: (id) => get(`/clans/${id}/members`).then(data),
    fetchStatus: (id) => get(`/clans/${id}/status`).then(data),
    fetchMissions: (id) => get(`/clans/${id}/missions`).then(data),
    fetchApplications: (id) => get(`/clans/${id}/applications`).then(data),
    apply: (id, message) => post(`/clans/${id}/applications`, { message }).then(data),
    cancelApplication: (applicationId) => del(`/clan-applications/${applicationId}`),
    acceptApplication: (applicationId) => post(`/clan-applications/${applicationId}/accept`),
    refuseApplication: (applicationId) => post(`/clan-applications/${applicationId}/refuse`),
    leave: () => post('/clans/leave'),
    kick: (id, etwinId) => post(`/clans/${id}/members/${etwinId}/kick`),
    promote: (id, etwinId) => post(`/clans/${id}/members/${etwinId}/leader`),
    setRole: (id, etwinId, role) => put(`/clans/${id}/members/${etwinId}/role`, { role }),
    setCombatRole: (id, etwinId, combatRole) => put(`/clans/${id}/members/${etwinId}/combat-role`, { combat_role: combatRole }),
    setStatus: (id, etwinId, status) => put(`/clans/${id}/members/${etwinId}/status`, { status }),
    dissolve: (id) => del(`/clans/${id}`),
    attack: (id, gameId) => post(`/clans/${id}/attacks`, { game_id: gameId }).then(data),
    declareWar: (id) => post(`/clans/${id}/war`),
    endWar: (id) => del(`/clans/${id}/war`),
    defend: (attackId) => post(`/clan-attacks/${attackId}/defend`).then(data),
    improveAttack: (attackId) => post(`/clan-attacks/${attackId}/improve`).then(data),
    cancelAttack: (attackId) => post(`/clan-attacks/${attackId}/cancel`),
    reserveDefense: (attackId) => post(`/clan-attacks/${attackId}/reserve`),
    reserveStep: (stepId) => post(`/clan-mission-steps/${stepId}/reserve`),
    playStep: (stepId) => post(`/clan-mission-steps/${stepId}/play`).then(data),
    useBonus: (bonusId, payload = {}) => post(`/clan-bonuses/${bonusId}/use`, payload),
    fetchAction: (actionId) => get(`/clan-actions/${actionId}`).then(data),
    playAgain: (actionId) => post(`/clan-actions/${actionId}/again`).then(data),
    cancelAction: (actionId) => post(`/clan-actions/${actionId}/cancel`),
    fetchClanGames: () => get('/clan-games').then(data),
    buyClanGames: (count) => post('/clan-games/buy', { count }),
    donateClanGames: (id, count) => post(`/clans/${id}/games/donate`, { count }),
    distributeClanGames: (id, etwinId, count) => post(`/clans/${id}/members/${etwinId}/games`, { count }),
  }
}

// the ranking of the clans of the period, page by page: { ranking: 'war' | 'missions', q } (a getter; null: no ranking),
// and the tournament of the period that comes with it
export function useClanRanking(params) {
  const tournament = ref(null)
  const list = usePaginatedList(() => (toValue(params) ? '/clans' : null), {
    params: () => toValue(params) ?? {},
    onPage: (data) => {
      tournament.value = data.tournament
    },
  })

  return { ...list, tournament }
}

// the finished attacks and defenses of a clan, page by page (its id: a ref or a getter)
export function useClanHistory(clanId) {
  return usePaginatedList(() => `/clans/${toValue(clanId)}/history`)
}

// the tools to try the clans alone (KADO_DEBUG_TOOLS, App\Http\Controllers\Api\ClanDebugController)
export function useClanDebug() {
  const { isLoading, error, get, post } = useApi()

  return {
    isLoading,
    error,
    fetchState: () => get('/debug/clans').then((response) => response.data.data),
    // an action: 'attack', 'attacks/{id}/defend', 'mission-steps/{id}', 'time', 'end-period'
    run: (action, payload = {}) => post(`/debug/clans/${action}`, payload).then((response) => response.data.data),
  }
}
