<script setup>
import Announcement from '@/components/message/Announcement.vue'
import PendingRuns from '@/components/message/PendingRuns.vue'
import Kalendrier from '@/components/nav/Kalendrier.vue'
import Navbar from '@/components/nav/Navbar.vue'
import Starbar from '@/components/nav/Starbar.vue'
import Sidebar from '@/components/side/Sidebar.vue'
import SidebarDrawer from '@/components/side/SidebarDrawer.vue'
import { achievementsEnabled } from '@/stores/achievement'
import { useAuthStore } from '@/stores/auth'

const authStore = useAuthStore()
const sidebarOpen = ref(false)
</script>

<template>
  <div class="flex flex-col h-dvh">
    <!-- the bar of the games of Eternaltwin; its menu opens the drawer of the page -->
    <NavTopBar @menu="sidebarOpen = true" />
    <header id="topPage" class="mx-auto w-full max-w-5xl h-[100px] flex relative justify-center z-10">
      <div class="flex flex-col items-center justify-center">
        <img src="/gfx/logoBasic.png" alt="KadoKadéo" class="h-fit w-auto mx-auto mb-5" />
        <Starbar v-if="authStore.isAuthenticated" />
      </div>
      <template v-if="authStore.isAuthenticated">
        <Navbar class="hidden md:block" />
        <Kalendrier class="hidden md:block" />
      </template>
    </header>

    <main class="items-center flex flex-col flex-1 overflow-auto md:overflow-clip pt-10 space-y-10">

      <div class="w-fit md:w-full max-w-4xl text-sm space-y-6">
        <Announcement class="w-full" />
        <PendingRuns class="w-full" />
      </div>

      <!-- the frame of the content: in Karbon the light panel of its frame (its dark top band and sides are outside) -->
      <section id="bodySection"
               class="flex w-full max-w-4xl border-2 border-kado-teal-500 bg-kado-blue-100 bg-[url(/gfx/bgContainerTopBlue.svg),url(/gfx/bgContainerTopRepeat.jpg)] [background-position:left_top,center_top] [background-repeat:no-repeat,repeat-x] pb-4 shadow-kado-page md:mx-4 md:mb-10 lg:mx-8 karbon:border-kado-slate-700 karbon:bg-kado-slate-50 karbon:bg-[url(/gfx/themes/karbon/content_top.jpg),url(/gfx/themes/karbon/background.jpg)] karbon:[background-position:center_-30px,center_top] karbon:[background-repeat:no-repeat,repeat-y] karbon:shadow-kado-page-karbon">
        <div class="flex-1 min-w-0">
          <slot />
        </div>

        <template v-if="authStore.isAuthenticated">
          <div class="hidden lg:block w-[150px] relative">
            <div class="absolute right-0 translate-x-1/4 text-xs w-[200px]">
              <Sidebar />
            </div>
          </div>
        </template>
      </section>
    </main>

    <KadoAchievementNotifications v-if="achievementsEnabled && authStore.isAuthenticated" />
    <KadoToasts v-if="authStore.isAuthenticated" />

    <div v-if="authStore.isAuthenticated" class="border-t-2 border-kado-blue-50 bg-[url(/gfx/bgHeader.png)] bg-top bg-repeat-x">
      <Navbar class="md:hidden">
        <li class="min-w-0">
          <button type="button"
                  class="block cursor-pointer"
                  title="Menu"
                  aria-label="Menu"
                  @click="sidebarOpen = true">
            <svg width="117"
                 height="95"
                 viewBox="0 0 117 95"
                 class="h-auto max-w-full fill-kado-blue-600 stroke-white stroke-[3]"
                 aria-hidden="true">
              <path d="M36.5 13h44a5.5 5.5 0 0 1 0 11h-44a5.5 5.5 0 0 1 0-11zM36.5 31h44a5.5 5.5 0 0 1 0 11h-44a5.5 5.5 0 0 1 0-11zM36.5 49h44a5.5 5.5 0 0 1 0 11h-44a5.5 5.5 0 0 1 0-11z" />
            </svg>
          </button>
        </li>
      </Navbar>
    </div>

    <SidebarDrawer v-if="authStore.isAuthenticated" v-model:open="sidebarOpen" />
  </div>
</template>

