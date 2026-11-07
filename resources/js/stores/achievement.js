import { defineStore } from 'pinia'
import { ref } from 'vue'

import { useApi } from '@/composables/useApi'

// App\Settings\SiteSettings::$achievements_enabled, injected by resources/views/layouts/default.blade.php
export const achievementsEnabled = window.Kado?.achievements_enabled === true

export const useAchievementStore = defineStore('achievement', () => {
  const achievements = ref(null)
  const authStore = useAuthStore()
  const completedAchievements = ref([])
  const completedAchievementTimers = new Map()
  let nextCompletedAchievementNotificationId = 0

  const { get, isLoading } = useApi()

  if (achievementsEnabled) {
    get('/achievements').then((response) => {
      achievements.value = response.data.data.sort((a, b) => {
        if (a.game.name < b.game.name) return -1
        if (a.game.name > b.game.name) return 1
        if (a.id < b.id) return -1
        if (a.id > b.id) return 1
        return 0
      })
    })
  }

  const achievementsByGame = computed(() => {
    if (!achievements.value) return {}

    return achievements.value.reduce((acc, achievement) => {
      const gameId = achievement.game.id
      if (!acc[gameId]) {
        acc[gameId] = []
      }
      acc[gameId].push(achievement)
      return acc
    }, {})
  })

  function getAchievementProgress(achievementId) {
    return authStore.achievementProgress.find(
      (progress) => progress.achievement_id === achievementId,
    )
  }

  function findAchievement(achievementUpdate) {
    return (
      achievements.value?.find(
        (achievement) => String(achievement.id) === String(achievementUpdate.id),
      ) ?? null
    )
  }

  function removeCompletedAchievement(notificationId) {
    const timer = completedAchievementTimers.get(notificationId)
    if (timer) {
      clearTimeout(timer)
      completedAchievementTimers.delete(notificationId)
    }

    completedAchievements.value = completedAchievements.value.filter(
      (achievement) => achievement.id !== notificationId,
    )
  }

  function hideCompletedAchievement(notificationId) {
    const timer = completedAchievementTimers.get(notificationId)
    if (timer) {
      clearTimeout(timer)
      completedAchievementTimers.delete(notificationId)
    }

    const achievement = completedAchievements.value.find(
      (achievement) => achievement.id === notificationId,
    )
    if (achievement) {
      achievement.visible = false
    }
  }

  function addUnlockedAchievement(achievementUpdate) {
    const achievement = findAchievement(achievementUpdate)
    for (const level of achievementUpdate.newly_unlocked_levels ?? []) {
      const notificationId = `${achievementUpdate.id}-${level.id}-${Date.now()}-${nextCompletedAchievementNotificationId++}`
      const maxLevel = achievement?.levels?.length ?? (achievementUpdate.next_level ? 3 : level.level)

      completedAchievements.value.push({
        id: notificationId,
        achievementId: achievementUpdate.id,
        achievementKey: achievementUpdate.achievement_key,
        gameKey: achievementUpdate.game_key,
        visible: true,
        title: level.title,
        description: level.description,
        complete: true,
        level: level.level,
        maxLevel,
        current: achievementUpdate.progress,
        goal: level.target,
        achievementLevelIcon: level.icon,
      })

      completedAchievementTimers.set(
        notificationId,
        setTimeout(() => {
          hideCompletedAchievement(notificationId)
        }, 5000),
      )
    }
  }


  return {
    enabled: achievementsEnabled,
    achievements,
    achievementsByGame,
    isLoading,
    completedAchievements,
    getAchievementProgress,
    addUnlockedAchievement,
    removeCompletedAchievement,
  }
})
