import { toValue } from 'vue'

import { usePaginatedList } from './usePaginatedList'

// the runs of a player, page by page; its etwin_id (a ref or a getter) can change: the history of the new player
export function useUserGameHistory(userId) {
  const { items, ...list } = usePaginatedList(() => (toValue(userId) ? `/users/${toValue(userId)}/history` : null))

  return { ...list, results: items }
}
