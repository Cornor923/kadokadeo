<script setup>
// a drop-down list, the options in the slot
const model = defineModel({ type: [String, Number, null], default: null })
</script>

<template>
  <select v-model="model" class="border border-solid border-kado-cyan-800 bg-white px-1 py-0.5 text-kado-blue">
    <slot />
  </select>
</template>
