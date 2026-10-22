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
    <FormButton size="lg"
                variant="pink"
                :disabled="!canGoPrevious || disabled"
                @click="emit('previous')">Période précédente</FormButton>

    <span class="font-bold">{{ label }}</span>

    <FormButton v-if="canGoNext"
                size="lg"
                class="ml-4"
                :disabled="disabled"
                @click="emit('next')">Période suivante</FormButton>
  </div>
</template>
