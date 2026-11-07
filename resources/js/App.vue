<script setup>
import { computed, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import DefaultLayout from '@/layouts/default.vue'
import { useAuthStore } from '@/stores/auth'

const layouts = {
  DefaultLayout,
}

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const messagesStore = useMessagesStore()

// banned while browsing: back to the login page, which shows the reason
watch(() => authStore.banMessage, (message) => {
  if (message) {
    router.push({ name: 'login' })
  }
})

// the theme of the site bought by the player (resources/css/themes)
watch(() => authStore.user?.theme, (theme) => {
  document.documentElement.dataset.theme = theme ?? 'base'
}, { immediate: true })

// the unread count on the icon of the installed site (0 removes it); refused by some systems without their permission
watch(() => messagesStore.total, (total) => {
  navigator.setAppBadge?.(total)?.catch(() => {})
})

const layout = computed(() => {
  return layouts[route.meta?.layout || 'DefaultLayout']
})
</script>

<template>
  <component :is="layout">
    <!-- meta.remount: a page made for one value of its params, made again when they change -->
    <router-view v-slot="{ Component, route: shown }">
      <component :is="Component" :key="shown.meta.remount ? shown.path : undefined" />
    </router-view>
  </component>
</template>
