<script setup>
// the pages of the forum, as on the forum of Twinoid: the first and the previous pages, "Page 2 / 14", the next and the
// last pages. "to" gives the route of a page.
const props = defineProps({
  currentPage: { type: Number, required: true },
  lastPage: { type: Number, required: true },
  to: { type: Function, required: true },
})

const arrows = computed(() => ({
  before: [{ icon: 'first', page: 1, title: 'Première page' }, { icon: 'left', page: props.currentPage - 1, title: 'Page précédente' }],
  after: [{ icon: 'right', page: props.currentPage + 1, title: 'Page suivante' }, { icon: 'last', page: props.lastPage, title: 'Dernière page' }],
}))
const off = (page) => page < 1 || page > props.lastPage || page === props.currentPage
const arrowClasses = 'flex h-6 w-6 items-center justify-center rounded-sm bg-twinoid-500 outline outline-twinoid-900 hover:bg-twinoid-600'
</script>

<template>
  <nav v-if="lastPage > 1" class="flex items-center justify-between gap-2">
    <div class="flex gap-px">
      <template v-for="arrow in arrows.before" :key="arrow.icon">
        <span v-if="off(arrow.page)" :class="arrowClasses" class="opacity-30"><img :src="`/gfx/forum/twinoid/${arrow.icon}.png`" alt="" /></span>
        <RouterLink v-else
                    :to="to(arrow.page)"
                    :title="arrow.title"
                    :class="arrowClasses"><img :src="`/gfx/forum/twinoid/${arrow.icon}.png`" :alt="arrow.title" /></RouterLink>
      </template>
    </div>
    <div class="rounded-sm border-0 border-t border-solid border-white/20 bg-twinoid-500 px-4 text-2xs leading-6 text-white outline outline-twinoid-900">
      Page <strong class="align-[-10%] text-base">{{ currentPage }}</strong> <span class="opacity-60">/ {{ lastPage }}</span>
    </div>
    <div class="flex gap-px">
      <template v-for="arrow in arrows.after" :key="arrow.icon">
        <span v-if="off(arrow.page)" :class="arrowClasses" class="opacity-30"><img :src="`/gfx/forum/twinoid/${arrow.icon}.png`" alt="" /></span>
        <RouterLink v-else
                    :to="to(arrow.page)"
                    :title="arrow.title"
                    :class="arrowClasses"><img :src="`/gfx/forum/twinoid/${arrow.icon}.png`" :alt="arrow.title" /></RouterLink>
      </template>
    </div>
  </nav>
</template>
