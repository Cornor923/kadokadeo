<script setup>
// "19h 25m 11s" until the date, "9 j 9 h 30 min" when more than a day is left
const props = defineProps({
  until: { type: String, required: true },
})
const emit = defineEmits(['done'])

const now = ref(Date.now())
let intervalId = null
onMounted(() => {
  intervalId = setInterval(() => {
    now.value = Date.now()
  }, 1000)
})
onUnmounted(() => clearInterval(intervalId))

const remaining = computed(() => Math.max(0, Math.floor((new Date(props.until).getTime() - now.value) / 1000)))
const label = computed(() => {
  const s = remaining.value
  const pad = (n) => String(n).padStart(2, '0')
  if (s >= 86400) {
    return `${Math.floor(s / 86400)} j ${Math.floor((s % 86400) / 3600)} h ${pad(Math.floor((s % 3600) / 60))} min`
  }
  return `${Math.floor(s / 3600)}h ${pad(Math.floor((s % 3600) / 60))}m ${pad(s % 60)}s`
})

watch(remaining, (value, previous) => {
  if (value === 0 && previous > 0) {
    emit('done')
  }
})
</script>

<template>
  <span class="whitespace-nowrap">{{ label }}</span>
</template>
