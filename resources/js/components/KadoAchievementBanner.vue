<script setup>
import GreenStar from '@svg/greenStar.svg'
import GreyStar from '@svg/greyStar.svg'
import OrangeStar from '@svg/orangeStar.svg'
import RedStar from '@svg/redStar.svg'

const props = defineProps({
  visible: { type: Boolean, default: true },
  title: { type: String, default: 'Interwheel étoile verte' },
  description: { type: String, default: 'Obtenez l\'étoile verte dans Interwheel.' },
  complete: { type: Boolean, default: false },
  level: { type: Number, default: 2 },
  maxLevel: { type: Number, default: 3 },
  current: { type: Number, default: 650 },
  goal: { type: Number, default: 1000 },
  achievementLevelIcon: { type: String, default: null },
})

const isComplete = computed(() => props.complete)
const progressPercent = computed(() => {
  if (!props.goal) return 0
  return Math.max(0, Math.min(100, Math.round((props.current / props.goal) * 100)))
})

const achievementImages = computed(() => {
  if (props.achievementLevelIcon === null) {
    return ['/gfx/achievements/placeholder.png', null]
  }
  return [
    `/gfx/achievements/bg${props.maxLevel === 3 ? props.level - 1 : ''}.png`,
    props.achievementLevelIcon,
  ]
})
</script>

<template>
  <aside v-if="visible"
         class="w-full select-none"
         role="status"
         aria-live="polite">
    <div
      class="relative overflow-hidden rounded-2xl border-3 bg-white/95 shadow-[0_12px_28px] shadow-kado-blue-800/25 backdrop-blur"
      :class="isComplete ? 'border-kado-green-500' : 'border-kado-teal-500'"
    >
      <!-- diagonal glossy wash -->
      <div
        class="pointer-events-none absolute inset-0 opacity-70"
        :class="isComplete
          ? 'bg-linear-160 from-white/86 from-58% via-kado-green-100/90 via-58% to-kado-green-50/90'
          : 'bg-linear-160 from-white/90 from-58% via-kado-blue-100/95 via-58% to-kado-blue-50/95'"
      />

      <!-- subtle dotted texture -->
      <div
        class="pointer-events-none absolute inset-0 opacity-30"
        style="
          background-image: radial-gradient(circle, currentColor 1.2px, transparent 1.3px);
          background-size: 15px 15px;
        "
        :class="isComplete ? 'text-kado-green-300' : 'text-kado-blue-700/50'"
      />

      <div class="relative flex items-center gap-4 p-2 h-28">
        <!-- icon + optional ribbon -->
        <div class="relative grid shrink-0 place-items-center">
          <img
            v-if="isComplete"
            src="/gfx/achievements/ribbon.png"
            class="absolute -top-12 left-1/2 h-auto w-20 -translate-x-1/2"
          />

          <div
            :class="isComplete ? 'border-kado-green-300' : 'border-kado-blue-700/50'"
            class="border-3 rounded-2xl overflow-hidden relative"
          >
            <img
              :src="achievementImages[0]"
              class="relative grid size-20 place-items-center"
              :class="{ grayscale: !isComplete }"
            />
            <img
              v-lazy="achievementImages[1]"
              class="absolute top-[5px] left-[5px] grid size-[70px] place-items-center"
              :class="{ grayscale: !isComplete }"
            />
          </div>
        </div>

        <!-- text -->
        <div class="min-w-0 flex-1 place-self-start">
          <h3 class="mt-1 truncate text-xl font-black leading-tight text-kado-pink-400">
            {{ title }}
          </h3>

          <div class="mt-1 line-clamp-2 text-base font-semibold text-kado-slate-400">
            {{ description }}
          </div>
        </div>

        <!-- right status area -->
        <div class="hidden min-w-[155px] shrink-0 border-l-2 border-kado-blue-300/70 pl-4 sm:block">
          <template v-if="isComplete">
            <div class="flex items-center justify-center gap-3 text-kado-green-500">
              <span class="text-sm font-black uppercase tracking-wide"> Succès obtenu ! </span>
            </div>
          </template>

          <template v-else>
            <div class="text-center text-[15px] font-black text-kado-green-600">
              Niveau {{ level }}<span class="text-kado-slate-400">/{{ maxLevel }}</span>
            </div>

            <div class="mt-2 flex justify-center gap-1 text-2xl leading-none">
              <GreenStar v-if="level > 0" class="size-6" />
              <OrangeStar v-if="level > 1" class="size-6" />
              <RedStar v-if="level > 2" class="size-6" />
              <GreyStar v-for="star in maxLevel - level" :key="star" class="size-6 opacity-35" />
            </div>

            <div class="relative mt-3 h-5 overflow-hidden rounded-full border-2 border-kado-blue-800 bg-kado-teal-500 shadow-inner">
              <div
                class="grid h-full place-items-center rounded-full bg-[repeating-linear-gradient(135deg,var(--color-kado-green-300)_0,var(--color-kado-green-300)_8px,var(--color-kado-green-500)_8px,var(--color-kado-green-500)_16px)] transition-all duration-500"
                :style="{ width: `${progressPercent}%` }"
              />
              <span class="absolute top-0 drop-shadow-sm drop-shadow-black text-white text-xs font-black left-1/2 -translate-x-1/2">
                {{ current }} / {{ goal }}
              </span>
            </div>
          </template>
        </div>
      </div>
    </div>
  </aside>
</template>
