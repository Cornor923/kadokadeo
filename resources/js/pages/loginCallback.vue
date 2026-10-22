<script setup>
const authStore = useAuthStore()
const route = useRoute()
const router = useRouter()
const error = ref(null)

authStore.login(route.query?.code, route.query?.state).then(() => {
  router.push({ path: '/' })
}).catch((e) => {
  error.value = e.response?.data?.message || e.message
})
</script>

<template>
  <div class="flex flex-wrap items-start justify-center">
    <p class="mx-2.5 my-4" v-if="!error">Veuillez patienter...</p>
    <MessageError v-else>{{ error }}</MessageError>
  </div>
</template>
