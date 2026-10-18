<script setup>
// the name of the clan written with the letters of the old site in the Junegull font (/gfx/clan/typo/kword, drawn by
// scripts/clan_letters.py), when they all exist
const props = defineProps({
  name: { type: String, required: true },
})

const FILES = {
  ...Object.fromEntries([...'abcdefghijklmnopqrstuvwxyz0123456789'].map((c) => [c, c])),
  ' ': 'space',
  '-': 'dash',
  '\'': 'apostrophe',
  '’': 'apostrophe',
  '.': 'dot',
  '!': 'exclamation',
  '?': 'question',
}

const chars = computed(() =>
  Array.from(props.name.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '')),
)
const asImages = computed(() => chars.value.every((c) => c in FILES))
// one group of letters per word, so that the name wraps between the words on mobile (the gap is the width of space.svg)
const words = computed(() => chars.value.join('').split(' ').filter(Boolean).map((word) => Array.from(word)))
</script>

<template>
  <span v-if="asImages" class="flex flex-wrap items-end gap-x-3" :title="name">
    <span v-for="(word, w) in words" :key="w" class="inline-flex items-end">
      <img
        v-for="(c, index) in word"
        :key="index"
        :src="`/gfx/clan/typo/kword/${FILES[c]}.svg`"
        :alt="c"
        class="max-w-none"
      />
    </span>
  </span>
  <span v-else>{{ name }}</span>
</template>
