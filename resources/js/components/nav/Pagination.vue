<script setup>
// the pages of a list, as on the old forum: "Page 2 / 14", then "< précédent 1 … 4 5 6 … 14 suivant >". Each page is
// a link: "to" gives the route of a page.
const props = defineProps({
  currentPage: { type: Number, required: true },
  lastPage: { type: Number, required: true },
  to: { type: Function, required: true },
})

// the first and the last pages, and the 2 pages around the current one ("…" between)
const pages = computed(() => {
  const shown = [...new Set([1, props.currentPage - 2, props.currentPage - 1, props.currentPage, props.currentPage + 1, props.currentPage + 2, props.lastPage])]
    .filter((page) => page >= 1 && page <= props.lastPage)
    .sort((a, b) => a - b)
  return shown.flatMap((page, index) => (index > 0 && page - shown[index - 1] > 1 ? ['…', page] : [page]))
})
</script>

<template>
  <nav v-if="lastPage > 1" class="my-3 text-center">
    <div class="italic">Page {{ currentPage }} / {{ lastPage }}</div>
    <ul class="m-0 flex list-none flex-wrap justify-center gap-x-2 p-0">
      <li>
        <RouterLink v-if="currentPage > 1" :to="to(currentPage - 1)">&lt; précédent</RouterLink>
        <span v-else class="text-kado-slate-400">&lt; précédent</span>
      </li>
      <li v-for="(page, index) in pages" :key="`${page}-${index}`">
        <span v-if="page === '…'">…</span>
        <strong v-else-if="page === currentPage">{{ page }}</strong>
        <RouterLink v-else :to="to(page)">{{ page }}</RouterLink>
      </li>
      <li>
        <RouterLink v-if="currentPage < lastPage" :to="to(currentPage + 1)">suivant &gt;</RouterLink>
        <span v-else class="text-kado-slate-400">suivant &gt;</span>
      </li>
    </ul>
  </nav>
</template>
