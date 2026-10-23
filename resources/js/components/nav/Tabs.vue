<script setup>
import { Tab, TabGroup, TabList, TabPanel,TabPanels } from '@headlessui/vue'

defineProps({
  items: {
    type: Array,
    required: true,
    // [{ label: 'Stats', value: 'stats', disabled: false, route: null }]
  },
})

// the bar scrolls by itself when the tabs are wider than the page: the selected tab is brought into view
const tabList = ref(null)
const route = useRoute()

function revealSelectedTab() {
  const list = tabList.value?.$el
  const tab = list?.querySelector('[aria-selected="true"]')
  if (!tab || (tab.offsetLeft >= list.scrollLeft && tab.offsetLeft + tab.offsetWidth <= list.scrollLeft + list.clientWidth)) {
    return
  }
  list.scrollLeft = tab.offsetLeft - (list.clientWidth - tab.offsetWidth) / 2
}

onMounted(() => nextTick(revealSelectedTab))
watch(() => route.fullPath, () => nextTick(revealSelectedTab))

function tabMenuLinkClasses(item) {
  const defaultClasses = 'border-solid text-center min-w-0 px-4 md:px-0 md:min-w-40 text-kado-blue-700 font-bold block no-underline bg-repeat-x'
  const bgClasses = item.disabled ? 'grayscale cursor-not-allowed' : 'cursor-pointer hover:text-kado-teal-500 hover:bg-[url(/gfx/bgTabmenuHover.jpg)]'
  const activeClasses = 'bg-[url(/gfx/bgTabmenuActive.jpg)] leading-[24px] bg-kado-teal-500 border-2 border-white border-solid border-b-0 text-xl small-caps tracking-normal p-0.5'
  const inactiveClasses = 'h-7 border border-kado-blue-100 bg-[url(/gfx/bgTabmenu.jpg)]'
  // Karbon: grey folders (also when a disabled tab is hovered)
  const karbonActiveClasses = 'karbon:border-kado-slate-200 karbon:bg-kado-slate-700 karbon:bg-[url(/gfx/themes/karbon/folder_active.jpg)] karbon:text-kado-slate-500'
  const karbonInactiveClasses = 'karbon:border-kado-slate-200 karbon:bg-[url(/gfx/themes/karbon/folder_up.jpg)] karbon:text-kado-slate-700 karbon:hover:bg-[url(/gfx/themes/karbon/folder_active.jpg)] karbon:hover:text-kado-slate-900'
  return item.selected
    ? `${defaultClasses} ${bgClasses} ${activeClasses} ${karbonActiveClasses}`
    : `${defaultClasses} ${bgClasses} ${inactiveClasses} ${karbonInactiveClasses}`
}
</script>

<template>
  <TabGroup>
    <TabList ref="tabList" class="flex gap-2 h-8 relative -top-[34px] -ml-1 overflow-x-auto overflow-y-hidden [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
      <Tab
        v-for="(item, index) in items"
        :key="item.value ?? index"
        as="template"
        :disabled="item.disabled"
        v-slot="{ selected }"
      >
        <slot
          name="tab"
          :item="item"
          :index="index"
          :selected="selected"
        >
          <div class="outline-none shrink-0 karbon:bg-kado-slate-700 whitespace-nowrap h-8 bg-kado-teal-500 border-2 border-white border-solid border-b-0 text-xl small-caps tracking-normal p-0.5" :class="item.disabled ? 'grayscale' : ''">
            <div v-if="!item.route" :class="tabMenuLinkClasses({ ...item, selected })">
              {{ item.label }}
            </div>
            <RouterLink v-else :to="item.route" :class="tabMenuLinkClasses({ ...item, selected })">
              {{ item.label }}
            </RouterLink>
          </div>
        </slot>
      </Tab>
    </TabList>

    <TabPanels>
      <TabPanel
        v-for="(item, index) in items"
        :key="item.value ?? index"
      >
        <slot
          name="panel"
          :item="item"
          :index="index"
        />
      </TabPanel>
    </TabPanels>
  </TabGroup>
</template>
