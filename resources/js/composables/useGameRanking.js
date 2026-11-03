import { ref } from 'vue'

import { usePaginatedList } from './usePaginatedList'

// the ranking of a game, page by page, for a period and a league (null: the current period, the league of the player)
export function useGameRanking(gameId, { period: initialPeriod = null, league: initialLeague = null } = {}) {
  const period = ref(initialPeriod)
  const league = ref(initialLeague)
  const { items, ...list } = usePaginatedList(() => `/games/${gameId}/ranking`, {
    params: () => ({ period: period.value || undefined, league: league.value || undefined }),
  })

  return { ...list, period, league, results: items }
}
