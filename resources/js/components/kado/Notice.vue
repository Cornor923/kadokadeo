<script setup>
// a notice of KadoKado: error (pink) and success (green) in the double frame of the old site (a coloured frame around a
// white-bordered panel, its margins defaults of .kado-notice in app.css), warning: the plain orange box
const props = defineProps({
  variant: { type: String, required: true, validator: (variant) => ['error', 'success', 'warning'].includes(variant) },
  // the element of the warning box (a <p> around a sentence)
  as: { type: String, default: 'div' },
})

const FRAMES = {
  error: { frame: 'border-kado-pink-400 bg-kado-pink-600', panel: 'bg-kado-pink-50 bg-[url(/gfx/bgPink.png)]' },
  success: { frame: 'border-kado-green-500 bg-kado-green-600 text-kado-green-500', panel: 'bg-kado-green-50 bg-[url(/gfx/bgGreen.png)]' },
}
</script>

<template>
  <component :is="props.as" v-if="props.variant === 'warning'" class="border-2 border-l-10 border-kado-orange-500 bg-kado-orange-50 px-3 py-2">
    <slot />
  </component>
  <div v-else class="kado-notice border-2 border-l-10 p-px font-bold" :class="FRAMES[props.variant].frame">
    <div class="border-3 border-white bg-no-repeat p-1.25" :class="FRAMES[props.variant].panel">
      <slot />
    </div>
  </div>
</template>
