<script setup>
defineProps({
  label: { type: String, required: true },
  canGoPrevious: { type: Boolean, default: false },
  canGoNext: { type: Boolean, default: false },
  disabled: { type: Boolean, default: false },
})

const emit = defineEmits(['previous', 'next'])
</script>

<template>
  <div class="mx-2 mb-4 flex items-center justify-center gap-4">
    <input
      type="button"
      value="Période précédente"
      class="pinkButton h-6 w-auto pt-px"
      :disabled="!canGoPrevious || disabled"
      @click="emit('previous')"
    />

    <span class="font-bold">{{ label }}</span>

    <input
      v-if="canGoNext"
      type="button"
      value="Période suivante"
      class="h-6 w-auto pt-px ml-4"
      :disabled="disabled"
      @click="emit('next')"
    />
  </div>
</template>
