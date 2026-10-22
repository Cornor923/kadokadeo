<script setup>
defineOptions({
  inheritAttrs: false,
})

const attrs = useAttrs()
</script>

<template>
  <div class="absolute inset-0 flex flex-col items-center justify-center bg-white/10">
    <!-- three rings: grey, orange the other way, green -->
    <div class="relative inline-block size-12 animate-spin rounded-full border-3 border-kado-slate-700 border-b-transparent border-l-transparent" v-bind="attrs">
      <div class="absolute inset-0 m-auto size-8 animate-[spin_1.5s_linear_infinite] rounded-full border-3 border-kado-play-400 border-b-transparent border-l-transparent"></div>
      <div class="absolute inset-0 m-auto size-10 animate-spin-reverse rounded-full border-3 border-kado-orange-500 border-t-transparent border-r-transparent"></div>
    </div>
    <slot />
  </div>
</template>

