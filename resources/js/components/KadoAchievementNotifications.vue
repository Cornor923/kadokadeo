<script setup>
const achievementStore = useAchievementStore()
// they come in from the right and leave to it (transform and opacity, each at its pace)
const motion = '[transition:transform_800ms_cubic-bezier(0.22,1,0.36,1),opacity_240ms_ease]'
const away = '[transform:translateX(120%)_scale(0.96)] opacity-0'
</script>

<template>
  <div
    class="pointer-events-none fixed inset-x-4 bottom-4 z-50 sm:bottom-6 sm:left-auto sm:right-6 sm:w-[36rem]"
    aria-live="polite"
  >
    <TransitionGroup tag="div"
                     class="flex w-full flex-col gap-3"
                     :move-class="motion"
                     :enter-active-class="motion"
                     :leave-active-class="`${motion} absolute inset-x-0`"
                     :enter-from-class="away"
                     :leave-to-class="away">
      <div
        v-for="achievement in achievementStore.completedAchievements"
        :key="achievement.id"
      >
        <Transition
          appear
          :enter-active-class="motion"
          :leave-active-class="motion"
          :enter-from-class="away"
          :leave-to-class="away"
          @after-leave="achievementStore.removeCompletedAchievement(achievement.id)"
        >
          <div v-if="achievement.visible" class="pointer-events-auto">
            <KadoAchievementBanner
              :title="achievement.title"
              :description="achievement.description"
              :complete="achievement.complete"
              :level="achievement.level"
              :max-level="achievement.maxLevel"
              :current="achievement.current"
              :goal="achievement.goal"
              :achievement-level-icon="achievement.achievementLevelIcon"
            />
          </div>
        </Transition>
      </div>
    </TransitionGroup>
  </div>
</template>

