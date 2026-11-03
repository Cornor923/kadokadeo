import { defineStore } from 'pinia'
import { ref } from 'vue'

import { useApi } from '@/composables/useApi'
import { useChannel } from '@/composables/useRealtime'

export const useAnnouncementStore = defineStore('announcement', () => {
  const announcement = ref(null)

  const { get, isLoading } = useApi()

  const fetchAnnouncement = async() => {
    if (isLoading.value) {
      return
    }
    try {
      const { data } = await get('/announcement')
      announcement.value = data.data
    } catch {
      // Keep the last known announcement on network/server errors
    }
  }

  // saved in the admin (App\Events\AnnouncementUpdated): no request, the API is cached a minute
  useChannel('site', {
    'announcement.updated': (e) => {
      announcement.value = e.announcement
    },
  }, { isPrivate: false })

  return {
    announcement,
    isLoading,
    fetchAnnouncement,
  }
})
