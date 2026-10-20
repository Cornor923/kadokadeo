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

  function normalizeResource(resource) {
    return resource?.data ?? resource
  }

  function normalizeResourceCollection(collection) {
    if (Array.isArray(collection)) return collection
    return collection?.data ?? []
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
    const currentLevel = normalizeResource(achievementUpdate.current_level)
    const nextLevel = normalizeResource(achievementUpdate.next_level)
    const unlockedLevels = normalizeResourceCollection(achievementUpdate.newly_unlocked_levels)
    const levels = unlockedLevels.length
      ? unlockedLevels
      : [
        currentLevel ??
            achievement?.levels?.find(
              (level) => Number(level.level) === Number(achievementUpdate.completed_level),
            ),
      ].filter(Boolean)

    for (const level of levels) {
      const notificationId = `${achievementUpdate.id}-${level.id}-${Date.now()}-${nextCompletedAchievementNotificationId++}`
      const maxLevel = achievement?.levels?.length ?? (nextLevel ? 3 : level.level)

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

  // addUnlockedAchievement({
  //   achievement_key: 'elevation',
  //   category: 'game',
  //   completed_level: 1,
  //   completed_level_before: 0,
  //   current_level: { description: 'Monter d\'une hauteur de 1.000 mètres en une seule ascension.', id: 19, level: 1, reward: 100, target: 1000, title: 'Mont-Blanc' },
  //   game_key: 'interwheel',
  //   id: 7,
  //   newly_unlocked_levels: [{ description: 'Monter d\'une hauteur de 1.000 mètres en une seule ascension.', id: 19, level: 1, reward: 100, target: 1000, title: 'Mont-Blanc' }],
  //   next_level: { description: 'Monter d\'une hauteur de 2.500 mètres en une seule ascension.', id: 20, level: 2, reward: 500, target: 2500, title: 'Kilimanjaro' },
  //   progress: 1109,
  //   progress_before: 834,
  //   type: 'unlocked',
  // })

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
