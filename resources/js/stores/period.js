import dayjs from 'dayjs'
import { defineStore } from 'pinia'
import { computed,ref } from 'vue'

import { updateAtMidnight } from '@/composables/helpers'
import { useApi } from '@/composables/useApi'
import { onRealtimeReconnect, useChannel } from '@/composables/useRealtime'

export const usePeriodStore = defineStore('period', () => {
  const period = ref(null)
  const currentTime = ref(Date.now())

  const { get } = useApi()

  const fetchPeriod = () => {
    currentTime.value = Date.now()
    return get('/period/current').then((response) => {
      period.value = response.data.data
    })
  }
  // (the day of the period changes at midnight)
  const reload = () => {
    fetchPeriod()
    updateAtMidnight().then(() => reload())
  }
  reload()
  // a new period (App\Events\PeriodStarted): in the event (the API is cached by the browser until midnight)
  useChannel('site', {
    'period.started': (e) => {
      currentTime.value = Date.now()
      period.value = e.period
    },
  }, { isPrivate: false })
  onRealtimeReconnect(fetchPeriod)

  const dayCount = computed(() => {
    if (!period.value) {
      return 0
    }
    const startDate = dayjs(period.value.start_at)
    const now = dayjs(currentTime.value)

    return now.diff(startDate, 'day')
  })

  return {
    period,
    dayCount,
  }
})
