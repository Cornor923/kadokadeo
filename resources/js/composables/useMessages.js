import { toValue } from 'vue'

import { useApi } from './useApi'
import { usePaginatedList } from './usePaginatedList'

// a box of the private messages of the player ('inbox', 'sent'; a ref or a getter, another value: no list), page by page
// (App\Http\Controllers\Api\MessageController); onPage: what comes with a page (the unread count)
export function useMessageBox(box, { onPage = null } = {}) {
  return usePaginatedList(() => (['inbox', 'sent'].includes(toValue(box)) ? '/messages' : null), {
    params: () => ({ box: toValue(box) }),
    onPage,
  })
}

// a private message: read it (it is then marked as read), write one, delete one
export function useMessages() {
  const { isLoading, error, get, post, del } = useApi()

  return {
    isLoading,
    error,
    fetchMessage: (id) => get(`/messages/${id}`).then((response) => response.data.data),
    sendMessage: (payload) => post('/messages', payload).then((response) => response.data),
    deleteMessage: (id) => del(`/messages/${id}`),
  }
}
