import { computed, ref, toValue, watch } from 'vue'

import { useApi } from './useApi'

// the runs of a player, page by page; its etwin_id (a ref or a getter) can change, the history of the new player is
// then loaded and a late answer for the previous one ignored
export function useUserGameHistory(userId) {
  const { isLoading, error, get } = useApi()
  const meta = ref({
    current_page: 0,
    last_page: 0,
  })
  const results = ref([])
  const hasNextPage = computed(() => {
    return meta.value.current_page < meta.value.last_page
  })
  // the last request: an answer to an older one is dropped
  let request = 0

  function fetchGameHistory() {
    const id = toValue(userId)
    if (!id) {
      return Promise.resolve()
    }
    const current = ++request
    const params = {
      page: meta.value.current_page + 1,
    }
    return get(`/users/${id}/history`, {
      params,
    }).then((response) => {
      if (current !== request) {
        return
      }
      meta.value = response.data.meta
      if (meta.value.current_page === 1) {
        results.value = []
      }
      results.value = results.value.concat(response.data.data)
    }).catch(() => {}) // (shown by error)
  }

  watch(() => toValue(userId), () => {
    meta.value = { current_page: 0, last_page: 0 }
    results.value = []
    fetchGameHistory()
  }, { immediate: true })

  return {
    isLoading,
    error,
    meta,
    results,
    hasNextPage,
    fetchGameHistory,
  }
}
