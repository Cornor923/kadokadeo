<script setup>
// the tabs of the side panel of a game; after: what follows the label of a tab
defineProps({
  // [{ id, label, icon }]
  tabs: { type: Array, required: true },
})
const selected = defineModel({ type: String, required: true })

// the active one underlined in orange, the others in relief (white top and left, teal right and bottom), sunken when
// hovered
const activeTab = 'flex-1 border-b border-kado-orange-500 bg-kado-cream-200 font-bold text-kado-orange-500'
const inactiveTab = [
  'border-t-2 border-r border-b border-l border-t-white border-r-kado-teal-400 border-b-kado-teal-400 border-l-white',
  'hover:border-t-kado-teal-400 hover:border-r-white hover:border-b-white hover:border-l-kado-teal-400',
  'bg-kado-blue-600/10 text-kado-blue-700 hover:bg-kado-blue-100 hover:pt-1 hover:text-kado-orange-500',
]
</script>

<template>
  <nav>
    <ul class="flex items-stretch">
      <li v-for="tab in tabs"
          :key="tab.id"
          @click="selected = tab.id"
          class="flex items-center justify-center text-center gap-1 pt-0.5 cursor-pointer h-7 px-2 @md:flex-1"
          :class="selected === tab.id ? activeTab : inactiveTab"
          :title="tab.label">
        <img v-if="tab.icon" :src="tab.icon" :alt="tab.label" />
        <div class="overflow-hidden" :class="selected === tab.id ? 'w-full' : 'w-0 @md:w-full'">{{ tab.label }}</div>
        <slot name="after" :tab="tab" />
      </li>
    </ul>
  </nav>
</template>
