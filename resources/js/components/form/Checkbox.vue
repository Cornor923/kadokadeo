<script setup>
// a check box of the site with its label (the label is the slot)
const model = defineModel({ type: Boolean, default: false })
defineProps({
  disabled: { type: Boolean, default: false },
})
</script>

<template>
  <label class="flex cursor-pointer items-start gap-2" :class="{ 'cursor-not-allowed opacity-60': disabled }">
    <input v-model="model"
           type="checkbox"
           :disabled="disabled"
           class="mt-0.5 size-4 shrink-0 cursor-pointer accent-kado-teal-500 disabled:cursor-not-allowed" />
    <span><slot /></span>
  </label>
</template>
