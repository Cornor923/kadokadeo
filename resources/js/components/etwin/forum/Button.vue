<script setup>
// a button of the forum, as the ones of the forum of Twinoid: a link (to) or a button, with its icon
// (public/gfx/forum/twinoid)
defineProps({
  to: { type: [Object, String], default: null },
  href: { type: String, default: null },
  icon: { type: String, default: null },
  disabled: { type: Boolean, default: false },
})
const emit = defineEmits(['click'])

const classes = 'inline-flex h-6 cursor-pointer items-center gap-1 rounded-sm border-0 border-t border-solid border-white/20 bg-twinoid-500 px-2 font-[inherit] text-2xs font-bold whitespace-nowrap text-white no-underline outline outline-twinoid-900 hover:bg-twinoid-600 hover:text-white hover:no-underline disabled:cursor-not-allowed disabled:opacity-40'
</script>

<template>
  <RouterLink v-if="to" :to="to" :class="classes">
    <img v-if="icon" :src="`/gfx/forum/twinoid/${icon}.png`" alt="" /><slot />
  </RouterLink>
  <a v-else-if="href" :href="href" :class="classes">
    <img v-if="icon" :src="`/gfx/forum/twinoid/${icon}.png`" alt="" /><slot />
  </a>
  <button v-else
          type="button"
          :class="classes"
          :disabled="disabled"
          @click="emit('click')">
    <img v-if="icon" :src="`/gfx/forum/twinoid/${icon}.png`" alt="" /><slot />
  </button>
</template>
