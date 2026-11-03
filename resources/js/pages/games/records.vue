<script setup>
const route = useRoute()
const { isLoading, error, fetchPeriodRecords } = useGames()
const history = ref(null)
const scoredPeriods = computed(() => (history.value?.periods ?? []).filter((period) => period.score != null))

watch(() => route.params.id, (gameId) => {
  history.value = null
  fetchPeriodRecords(gameId)
    .then((data) => {
      // (another game asked meanwhile: not this one)
      if (gameId === route.params.id) {
        history.value = data
      }
    })
    .catch(() => {})
}, { immediate: true })

const chartFrame = {
  left: 64,
  right: 700,
  top: 20,
  bottom: 286,
}

const chartPoints = computed(() => {
  const periods = history.value?.periods ?? []
  const scores = periods.map((period) => period.score).filter((score) => score !== null).map(Number)
  const maxScore = Math.max(0, ...scores)
  const scaleMax = maxScore || 1
  const plotWidth = chartFrame.right - chartFrame.left
  const plotHeight = chartFrame.bottom - chartFrame.top

  return periods.map((period, index) => ({
    periodId: period.id,
    score: period.score,
    x: periods.length > 1 ? chartFrame.left + (index * plotWidth) / (periods.length - 1) : (chartFrame.left + chartFrame.right) / 2,
    y: period.score === null ? null : chartFrame.bottom - (Number(period.score) / scaleMax) * plotHeight,
  }))
})

const chartMaxScore = computed(() => Math.max(0, ...chartPoints.value.map((point) => Number(point.score)).filter(Number.isFinite)))
const chartYTicks = computed(() => Array.from({ length: 5 }, (_, index) => {
  const fraction = index / 4
  return {
    y: chartFrame.bottom - fraction * (chartFrame.bottom - chartFrame.top),
    score: Math.round(chartMaxScore.value * fraction),
  }
}))
const scoredChartPoints = computed(() => chartPoints.value.filter((point) => point.y !== null))
const chartLines = computed(() => {
  const lines = []
  let segment = []

  for (const point of chartPoints.value) {
    if (point.y === null) {
      if (segment.length > 1) lines.push(segment.map(({ x, y }) => `${x},${y}`).join(' '))
      segment = []
      continue
    }

    segment.push(point)
  }

  if (segment.length > 1) lines.push(segment.map(({ x, y }) => `${x},${y}`).join(' '))
  return lines
})
const chartLabels = computed(() => {
  const points = chartPoints.value
  if (points.length <= 6) return points

  const interval = Math.ceil((points.length - 1) / 5)
  return points.filter((point, index) => index % interval === 0 || index === points.length - 1)
})
</script>

<template>
  <div>
    <Loader v-if="isLoading">Chargement des scores...</Loader>
    <MessageError v-else-if="error">Error: {{ error }}</MessageError>
    <template v-else-if="history">
      <KadoPageTitle class="mb-5">{{ history.game.name }}</KadoPageTitle>
      <div class="grid gap-8 px-4 py-4 sm:px-6 lg:grid-cols-2">
        <section>
          <KadoSectionTitle>Historique</KadoSectionTitle>
          <KadoTable class="w-full">
            <thead>
              <tr class="text-kado-orange-500 uppercase text-sm *:px-2">
                <th class="text-left">Période</th>
                <th class="text-right">Meilleur score</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="period in scoredPeriods" :key="period.id">
                <td class="text-left">Période {{ period.id }}</td>
                <td class="text-right">
                  <Number v-if="period.score !== null" color="blue" :value="period.score" />
                  <span v-else>-</span>
                </td>
              </tr>
            </tbody>
          </KadoTable>
        </section>

        <section>
          <KadoSectionTitle>Évolution</KadoSectionTitle>
          <svg
            v-if="scoredChartPoints.length"
            viewBox="0 0 720 340"
            class="w-full h-auto"
            role="img"
            :aria-label="`Meilleur score par période pour ${history.game.name}`"
          >
            <g v-for="tick in chartYTicks" :key="tick.y">
              <line :x1="chartFrame.left"
                    :x2="chartFrame.right"
                    :y1="tick.y"
                    :y2="tick.y"
                    class="stroke-kado-slate-200"
                    stroke-dasharray="4 4" />
              <text :x="chartFrame.left - 10"
                    :y="tick.y + 4"
                    text-anchor="end"
                    class="fill-kado-slate-700 text-xs">{{ tick.score }}</text>
            </g>
            <line :x1="chartFrame.left"
                  :x2="chartFrame.right"
                  :y1="chartFrame.bottom"
                  :y2="chartFrame.bottom"
                  class="stroke-kado-slate-500" />
            <polyline
              v-for="(line, index) in chartLines"
              :key="index"
              :points="line"
              fill="none"
              class="stroke-kado-orange-500"
              stroke-width="3"
              stroke-linecap="round"
              stroke-linejoin="round"
            />
            <circle v-for="point in scoredChartPoints"
                    :key="point.periodId"
                    :cx="point.x"
                    :cy="point.y"
                    r="4"
                    class="fill-kado-blue-700" />
            <text v-for="point in chartLabels"
                  :key="`label-${point.periodId}`"
                  :x="point.x"
                  y="312"
                  text-anchor="middle"
                  class="fill-kado-slate-700 text-xs">
              P{{ point.periodId }}
            </text>
          </svg>
          <p class="mx-2.5 my-4" v-else>Aucun score enregistré pour ce jeu.</p>
        </section>
      </div>
      <p class="mx-2.5 my-4 text-center">
        <RouterLink :to="{ name: 'games.show', params: { id: history.game.id } }">
          Jouer à {{ history.game.name }}
        </RouterLink>
      </p>
    </template>
  </div>
</template>