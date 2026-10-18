import axios from 'axios'
import { ref } from 'vue'

export const client = axios.create({
  baseURL: '/api',
  withCredentials: true,
  headers: {
    'Content-Type': 'application/json',
    Accept: 'application/json',
    'X-Requested-With': 'XMLHttpRequest',
    'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]').getAttribute('content'),
  },
})

export function useApi() {
  const isLoading = ref(false)
  const error = ref(null)

  const request = async(requestFn) => {
    isLoading.value = true
    error.value = null

    try {
      const response = await requestFn()
      return response
    } catch(e) {
      const message = e.response?.data?.message || 'An error occurred while doing the request.'
      error.value = message
      throw e
    } finally {
      isLoading.value = false
    }
  }

  return {
    isLoading,
    error,
    request,
    get: (url, config = {}) => request(() => client.get(url, config)),
    post: (url, data = {}, config = {}) => request(() => client.post(url, data, config)),
    put: (url, data = {}, config = {}) => request(() => client.put(url, data, config)),
    patch: (url, data = {}, config = {}) => request(() => client.patch(url, data, config)),
    del: (url, config = {}) => request(() => client.delete(url, config)),
  }
}
