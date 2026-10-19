<script setup>
const props = defineProps({
  game: { type: Object, required: true },
  args: { type: Object, default: () => ({}) },
  canvasStyle: { type: Object, default: () => ({}) },
})

const emit = defineEmits(['mounted'])

const canvas = ref(null)
const { mount, destroy, invalidate, crash, getInstance } = useGame(() => props.game)
// the replay page follows the replay (useReplayClock)
defineExpose({ getInstance })
const showTechnicalDetails = ref(false)
const copyFeedback = ref('')

const technicalDetails = computed(() => {
  if (!crash.value) {
    return ''
  }

  const details = [
    'KadoKadeo runtime crash',
    `message: ${crash.value.message ?? 'Unknown error'}`,
    `state: ${crash.value.runState ?? 'unknown'}`,
    `score: ${crash.value.score ?? 'n/a'}`,
    `timestamp: ${crash.value.timestamp ?? new Date().toISOString()}`,
    '',
    'stack:',
    crash.value.stack ?? '(no stack trace available)',
  ]

  return details.join('\n')
})

watch(crash, (value) => {
  if (value) {
    showTechnicalDetails.value = false
  }
  copyFeedback.value = ''
})

async function copyTechnicalDetails() {
  const text = technicalDetails.value
  if (!text) {
    return
  }

  try {
    if (navigator?.clipboard?.writeText) {
      await navigator.clipboard.writeText(text)
      copyFeedback.value = 'Détails techniques copiés.'
      return
    }
  } catch {
    copyFeedback.value = 'Copie impossible. Veuillez copier manuellement.'
  }
}

// iOS Safari : sans ça, des taps répétés sur le canvas déclenchent la loupe, la sélection
// et le menu « Copier / Partager / Rechercher ». Le jeu lit les Pointer Events, qui sont
// émis avant les Touch Events et ne sont pas affectés par preventDefault.
function blockNativeGesture(event) {
  if (event.cancelable) {
    event.preventDefault()
  }
}

async function mountGame() {
  await mount(canvas.value, {
    ...props.args,
    canvasWidth: props.game.is_arkadeo ? 600 : 600,
    // an Arkadeo game: its 600 x 460 area and the bar of KadoKadeo under it (40)
    canvasHeight: props.game.is_arkadeo ? 500 : 640,
    // seed:'123',
    // replayData: '',
  })
}

onMounted(async() => {
  document.documentElement.classList.add('kado-game-mounted')
  await mountGame()
  emit('mounted')
})

onBeforeUnmount(() => {
  document.documentElement.classList.remove('kado-game-mounted')
  invalidate()
  destroy()
})
</script>

<template>
  <div class="relative w-full">
    <div v-if="crash" class="error absolute top-2 right-2 left-2 z-20">
      <div class="text-xs">
        <p>Un problème technique est survenu pendant la partie.</p>
        <p>Vous pouvez nous envoyer les détails techniques pour faciliter le diagnostic.</p>
        <div class="mt-2 flex flex-wrap gap-2">
          <button
            type="button"
            class="cursor-pointer border border-pink-400 bg-white px-2.5 py-1.5 text-xs leading-none font-bold text-pink-700"
            @click="showTechnicalDetails = !showTechnicalDetails"
          >
            {{ showTechnicalDetails ? 'Masquer les détails techniques' : 'Voir les détails techniques' }}
          </button>
          <button
            type="button"
            class="cursor-pointer border border-pink-400 bg-white px-2.5 py-1.5 text-xs leading-none font-bold text-pink-700"
            @click="copyTechnicalDetails"
          >
            Copier les détails techniques
          </button>
          <div v-if="copyFeedback">{{ copyFeedback }}</div>
          <button
            type="button"
            class="cursor-pointer border border-pink-400 bg-white px-2.5 py-1.5 text-xs leading-none font-bold text-pink-700"
            @click="crash = null"
          >
            Fermer ce message
          </button>
        </div>
        <textarea
          v-if="showTechnicalDetails"
          class="mt-2.5 max-h-[280px] min-h-[140px] w-full resize-y font-mono text-xs"
          readonly
          :value="technicalDetails"
        />
      </div>
    </div>
    <canvas
      ref="canvas"
      :width="game.is_arkadeo ? 600 : 900"
      :height="game.is_arkadeo ? 500 : 960"
      class="w-full"
      :style="{
        touchAction: 'none',
        userSelect: 'none',
        WebkitUserSelect: 'none',
        WebkitTouchCallout: 'none',
        WebkitTapHighlightColor: 'transparent',
        ...props.canvasStyle,
      }"
      @touchstart="blockNativeGesture"
      @touchend="blockNativeGesture"
      @dblclick="blockNativeGesture"
      @contextmenu="blockNativeGesture"
      @selectstart="blockNativeGesture"
      @dragstart="blockNativeGesture"
      @gesturestart="blockNativeGesture"
    >
      <p>
        Votre navigateur ne supporte pas Canvas. Veuillez installer un navigateur plus moderne afin
        de jouer.
      </p>
    </canvas>
  </div>
</template>
