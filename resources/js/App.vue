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

const layout = computed(() => {
  return layouts[route.meta?.layout || 'DefaultLayout']
})
</script>

<template>
  <component :is="layout">
    <router-view />
  </component>
</template>
