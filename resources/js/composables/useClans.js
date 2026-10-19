import { useApi } from './useApi'

// the clans (App\Http\Controllers\Api\Clan*Controller)
export function useClans() {
  const { isLoading, error, get, post, put, del } = useApi()

  const data = (response) => response.data

  return {
    isLoading,
    error,
    fetchRanking: (params = {}) => get('/clans', { params }).then(data),
    fetchOverview: () => get('/clans/overview').then(data),
    createClan: (payload) => post('/clans', payload).then(data),
    fetchClan: (id) => get(`/clans/${id}`).then(data),
    updateClan: (id, payload) => put(`/clans/${id}`, payload),
    fetchMembers: (id) => get(`/clans/${id}/members`).then(data),
    fetchStatus: (id) => get(`/clans/${id}/status`).then(data),
    fetchHistory: (id, page = 1) => get(`/clans/${id}/history`, { params: { page } }).then(data),
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
