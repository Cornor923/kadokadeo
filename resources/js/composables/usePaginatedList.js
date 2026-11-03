import { computed, ref, toValue, watch } from 'vue'

import { useApi } from './useApi'

// a list of the API loaded page by page (the « Charger plus » buttons: { data, meta } of a paginated resource of
// Laravel): its first page as soon as it is created, again when its url or its params change (a ref or a getter; a url
// null: no list); an answer for a page asked before is ignored. onPage(response.data, page): what comes with the page
export function usePaginatedList(url, { params = () => ({}), onPage = null } = {}) {
  const { isLoading, error, get } = useApi()
  const items = ref([])
  const meta = ref(null)
  const hasNextPage = computed(() => !!meta.value && meta.value.current_page < meta.value.last_page)
  // the last request: an answer to an older one is dropped
  let request = 0

  function load(page = 1) {
    const target = toValue(url)
    const current = ++request
    if (!target) {
      return Promise.resolve(null)
    }
    return get(target, { params: { ...toValue(params), page } }).then((response) => {
      if (current !== request) {
        return null
      }
      items.value = page === 1 ? response.data.data : [...items.value, ...response.data.data]
      meta.value = response.data.meta
      onPage?.(response.data, page)
      return response.data
    }).catch(() => null) // (shown by error)
  }

  // another list: emptied at once (not the one of before while the new one loads)
  watch([() => toValue(url), () => JSON.stringify(toValue(params))], () => {
    items.value = []
    meta.value = null
    load()
  }, { immediate: true })

  return {
    items,
    meta,
    hasNextPage,
    isLoading,
    error,
    // the first page again (a list changed on the server)
    reload: () => load(),
    loadMore: () => (hasNextPage.value ? load(meta.value.current_page + 1) : Promise.resolve(null)),
  }
}
