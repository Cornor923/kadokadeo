import { useApi } from './useApi'

// the competitions of the site (App\Http\Controllers\Api\GameScoreController): the ranking V1 of a period (null: the
// current one), a page and the line of the player, and the poids plumes
export function useCompetition() {
  const { isLoading, error, get } = useApi()

  return {
    isLoading,
    error,
    // { data, meta, me }
    fetchRankingV1: (period, page = 1) =>
      get('/competition', { params: { period: period ?? undefined, page: page > 1 ? page : undefined } }).then((response) => response.data),
    fetchFeathers: (period) =>
      get('/competition/poids-plumes', { params: { period: period ?? undefined } }).then((response) => response.data),
  }
}
