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
    <header id="topPage" class="mx-auto w-full max-w-5xl h-[100px] flex relative justify-center z-10">
      <!-- <nav class="w-8">
      <ul class="flex flex-col space-y-1">
        <li>
          <a href="#" title="Français">
            <div data-lang="fr" alt="french" title="Français"></div>
          </a>
        </li>
      </ul>
    </nav> -->
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

      <section id="bodySection" class="w-full md:mx-4 lg:mx-8 flex max-w-4xl border-2 border-solid border-kado-cyan-800 bg-kado-cyan-200 pb-4 md:mb-10">
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

    <div v-if="authStore.isAuthenticated" class="bgBack border-t-2 border-solid border-kado-cyan-50">
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
                 class="h-auto max-w-full fill-kado-cyan-700 stroke-white stroke-[3]"
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

<style scoped>
.bgBack {
  background: url('/gfx/bgHeader.png') top repeat-x;
}
</style>
