<script setup>
const props = defineProps({
  value: { type: [String, Number], required: true },
  color: {
    type: String,
    default: 'green',
    validator: (value) =>
      ['green', 'orange', 'pink', 'blue', 'violet', 'bigGreen', 'bigOrange', 'bigPink', 'bigViolet'].includes(value),
  },
  // a "+" before a positive number (a negative one always has its "-")
  signed: { type: Boolean, default: false },
  // height in px, defaults to the GIF height (20 for the big typos, 15 for the others)
  size: { type: Number, default: null },
})

const height = computed(() => props.size ?? (props.color.startsWith('big') ? 20 : 15))

// the images of the characters that are not digits (scripts/typo-svg.py)
const charFiles = { '.': 'dot', '+': 'plus', '-': 'minus', '\u2212': 'minus' }

const charUrls = computed(() => {
  const chars =
    typeof props.value === 'string'
      ? props.value
      : (props.signed && props.value > 0 ? '+' : '') + formatScore(props.value).replaceAll(' ', '.')
  return Array.from(chars).map((c) => `/gfx/typo/${props.color}/${charFiles[c] ?? c}.svg`)
})
</script>

<template>
  <span>
    <img
      v-for="(charUrl, index) in charUrls"
      :key="index"
      class="max-w-none"
      :src="charUrl"
      :style="{ height: `${height}px` }"
    />
  </span>
</template>
