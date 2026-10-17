<script setup>
// the bar at the top of a page of the forum, as the one of the forum of Twinoid: where it is (the links to the pages
// above), then its actions
defineProps({
  // [{ label, to }]
  crumbs: { type: Array, default: () => [] },
  title: { type: String, required: true },
})
</script>

<template>
  <div class="mb-2 overflow-hidden rounded-sm shadow-[0_0_4px_rgba(0,0,0,0.35)]">
    <div class="truncate bg-kado-slate-600 bg-[url(/gfx/forum/twinoid/forum_postHeader.png)] bg-repeat-x px-1.5 text-sm leading-6 text-white">
      <template v-for="crumb in crumbs" :key="crumb.label">
        <RouterLink :to="crumb.to" class="text-xs font-normal text-white underline hover:text-white">{{ crumb.label }}</RouterLink>
        <span class="mx-1.5 opacity-40">›</span>
      </template>
      <strong>{{ title }}</strong>
    </div>
    <div v-if="$slots.default" class="flex flex-wrap items-center gap-2 bg-kado-slate-600/80 p-1">
      <slot />
    </div>
  </div>
</template>
