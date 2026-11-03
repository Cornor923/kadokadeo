import dayjs from 'dayjs'
import { defineStore } from 'pinia'
import { ref } from 'vue'

import { updateAtMidnight } from '@/composables/helpers'
import { useApi } from '@/composables/useApi'
import { refetchSoon, useChannel } from '@/composables/useRealtime'

export const useDailyGameStore = defineStore('dailyGame', () => {
  const dailyGame = ref(null)
  const game = ref(null)
  const scores = ref([])
  const position = ref(null)

  const { get, isLoading } = useApi()
  const { get: getScores, isLoading: isScoresLoading } = useApi()

  // the game of the day (UTC) of today, not the one of yesterday still on a page open at midnight
  const isToday = (dg) => dg?.day?.substr(0, 10) === dayjs().utc().format('YYYY-MM-DD')

  // the one kept in the browser (null: none, or not readable)
  const stored = () => {
    try {
      return JSON.parse(localStorage.getItem('dailyGame'))
    } catch {
      localStorage.removeItem('dailyGame')
      return null
    }
  }

  const fetchDailyGameIfNecessary = () => {
    if (!isToday(dailyGame.value)) {
      dailyGame.value = null
      game.value = null
    }

    const tmp = dailyGame.value ? null : stored()
    if (tmp) {
      if (tmp.date) {
        localStorage.removeItem('dailyGame')
      }
      if (isToday(tmp)) {
        dailyGame.value = tmp
        game.value = tmp.game
      }
    }

    if (!dailyGame.value) {
      get('/daily/game').then((response) => {
        dailyGame.value = response.data.dailyGame
        dailyGame.value.game = response.data.data
        game.value = response.data.data
        localStorage.setItem(
          'dailyGame',
          JSON.stringify(dailyGame.value),
        )
      })
    }
  }

  const fetchScores = () => {
    getScores('/daily/scores').then((response) => {
      scores.value = response.data.data
      position.value = response.data.position
    })
  }

  const reload = () => {
    fetchDailyGameIfNecessary()
    fetchScores()
    updateAtMidnight().then(() => reload())
  }
  reload()
  // the game of today chosen (App\Events\DailyGameStarted: maybe after the midnight of this page), not all the players
  // at once (what the API says of it depends on the player). Nobody played it yet: no scores to ask
  useChannel('site', {
    'daily.started': refetchSoon(() => {
      localStorage.removeItem('dailyGame')
      dailyGame.value = null
      game.value = null
      scores.value = []
      position.value = null
      fetchDailyGameIfNecessary()
    }, { delay: 0, jitter: 10000 }),
  }, { isPrivate: false })

  return {
    dailyGame,
    game,
    isDailyGameLoading: isLoading,
    scores,
    position,
    isScoresLoading,
    fetchScores,
    fetchDailyGameIfNecessary,
  }
})
