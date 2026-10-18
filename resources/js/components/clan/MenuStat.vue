<script setup>
// a number of the "Infos" menu of the clan, with its icon
defineProps({
  icon: { type: String, required: true },
})
</script>

<template>
  <div class="flex h-8 items-center justify-end gap-1.5 px-1">
    <slot />
    <img :src="icon" alt="" class="w-5 max-w-none" />
  </div>
</template>
