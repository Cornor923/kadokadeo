import { useApi } from './useApi'

export function useProfile() {
  const { isLoading, error, get } = useApi()
  const authStore = useAuthStore()

  function fetchProfile(id) {
    const url = id ? `/users/${id}` : `/users/${authStore.user.etwin_id}`
    return get(url).then((response) => response.data)
  }

  return {
    isLoading,
    error,
    fetchProfile,
    // the records of a player by game (the tab « stats » of the profile)
    fetchRecords: (id) => get(`/users/${id}/records`).then((response) => response.data),
    // the summary of a finished period of a player (null: the last one; App\Services\PeriodSummaryService)
    fetchPeriodSummary: (id, periodId = null) => get(`/users/${id}/periods${periodId ? `/${periodId}` : ''}`).then((response) => response.data.data),
  }
}
