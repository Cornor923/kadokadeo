<script setup>
import KadoPoints from '@svg/k.svg'

const props = defineProps({
  achievement: { type: Object, required: true },
})

const achievementStore = useAchievementStore()
const currentProgress = computed(() => achievementStore.getAchievementProgress(props.achievement.id))
const currentLevelId = computed(() => {
  const progress = currentProgress.value
  return progress ? progress.completed_level : 0
})
const currentLevel = computed(() => props.achievement.levels.find((l) => l.level === currentLevelId.value))
const nextLevel = computed(() => props.achievement.levels.find((l) => l.level === currentLevelId.value + 1))

const displayedLevel = computed(() => {
  if (nextLevel.value) {
    return nextLevel.value
  }
  return currentLevel.value
})
const barWidth = computed(() => {
  if (!nextLevel.value) {
    return '100%'
  }
  if (!currentProgress.value) return '0%'
  return `${Math.min((currentProgress.value.current_value / nextLevel.value.target) * 100, 100)}%`
})

const achievementImages = computed(() => {
  const bg = props.achievement.levels.length > 1 ? displayedLevel.value.level - 1 : ''

  return [
    `/gfx/achievements/bg${bg}.png`,
    displayedLevel.value.icon,
  ]
})
</script>

<template>
  <div :class="nextLevel ? '' : 'opacity-50'">
    <div class="flex gap-2 items-start">

      <div class="rounded overflow-hidden relative shrink-0" v-lazy-container="{ selector: 'img', attempt: 1 }">
        <img :data-src="achievementImages[0]" class="relative grid size-13 place-items-center" :class="{ 'grayscale-75': !!nextLevel }" />
        <img v-if="achievementImages[1]"
             :data-src="achievementImages[1]"
             data-loading="/gfx/achievements/loading.png"
             data-error="/gfx/achievements/error.png"
             class="absolute top-0.5 left-0.5 grid size-12 place-items-center rounded-md"
             :class="{ 'grayscale-75': !!nextLevel }" />
      </div>
      <div class="flex-1">
        <div class="flex gap-4 justify-between items-center">
          <div class="font-semibold text-kado-pink-400">{{ displayedLevel.title }}</div>
          <div v-if="nextLevel" class="flex gap-1 items-center shrink-0">
            <Number :value="displayedLevel.reward" />
            <KadoPoints class="inline size-4" />
          </div>
        </div>
        <div>{{ displayedLevel.description }}</div>
      </div>
    </div>
    <div class="w-full bg-kado-slate-200 h-1 mt-1">
      <div class="bg-kado-green-500 h-1 transition-all ease-in duration-1000" :style="{ width: barWidth }"></div>
    </div>
  </div>
</template>
