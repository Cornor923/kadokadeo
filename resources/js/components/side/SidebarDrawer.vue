<script setup>
import { Dialog, DialogPanel, TransitionChild, TransitionRoot } from '@headlessui/vue'

import Kalendrier from '@/components/nav/Kalendrier.vue'
import Sidebar from '@/components/side/Sidebar.vue'

const open = defineModel('open', { type: Boolean, default: false })
const route = useRoute()

watch(() => route.fullPath, () => {
  open.value = false
})
</script>

<template>
  <TransitionRoot :show="open" as="template">
    <Dialog class="relative z-50 lg:hidden" @close="open = false">
      <TransitionChild
        as="template"
        enter="transition-opacity duration-200"
        enter-from="opacity-0"
        enter-to="opacity-100"
        leave="transition-opacity duration-200"
        leave-from="opacity-100"
        leave-to="opacity-0"
      >
        <div class="fixed inset-0 bg-black/40" aria-hidden="true" />
      </TransitionChild>

      <div class="fixed inset-y-0 right-0 flex max-w-full">
        <TransitionChild
          as="template"
          enter="transition-transform duration-200"
          enter-from="translate-x-full"
          enter-to="translate-x-0"
          leave="transition-transform duration-200"
          leave-from="translate-x-0"
          leave-to="translate-x-full"
        >
          <DialogPanel class="w-[240px] h-full overflow-y-auto bg-kado-cyan-200 border-l-2 border-solid border-kado-cyan-800 px-4 pb-6 text-xs">
            <div class="flex justify-end pt-2">
              <button type="button"
                      class="text-2xl leading-none text-kado-cyan-800 cursor-pointer"
                      title="Fermer"
                      @click="open = false">
                &times;
              </button>
            </div>
            <!-- the calendar of the header, hidden on mobile; text-base: its sizes are relative to the font of the header -->
            <div class="flex justify-center text-base">
              <Kalendrier />
            </div>
            <Sidebar />
          </DialogPanel>
        </TransitionChild>
      </div>
    </Dialog>
  </TransitionRoot>
</template>
