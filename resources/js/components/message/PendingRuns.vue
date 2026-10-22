<script setup>
import { storeToRefs } from 'pinia'

import Error from '@/components/message/Error.vue'
import { formatScore } from '@/composables/helpers'
import { useAuthStore } from '@/stores/auth'
import { usePendingRunsStore } from '@/stores/pendingRuns'

const authStore = useAuthStore()
const pendingRunsStore = usePendingRunsStore()
const { runs, isSending } = storeToRefs(pendingRunsStore)
const showDetails = ref(false)

const formatDate = (iso) => (iso ? new Date(iso).toLocaleString('fr-FR') : '?')

function discard(run) {
  if (confirm(`Supprimer définitivement la partie de ${run.game_name} (${formatScore(run.request?.score ?? 0)} points) ?`)) {
    pendingRunsStore.discard(run.run_id)
  }
}

// sent again as soon as the player is logged in
watch(
  () => authStore.isAuthenticated,
  (isAuthenticated) => {
    if (isAuthenticated) {
      pendingRunsStore.retryAll({ auto: true })
    }
  },
  { immediate: true },
)
</script>

<template>
  <Error v-if="authStore.isAuthenticated && runs.length">
    <span class="text-xs">
      {{ runs.length > 1 ? `${runs.length} parties n'ont pas pu être envoyées` : "Une partie n'a pas pu être envoyée" }}
      au serveur.
    </span>
    <span class="mt-2 flex flex-wrap gap-2">
      <button
        type="button"
        class="cursor-pointer border border-kado-pink-400 bg-white px-2.5 py-1.5 text-xs leading-none font-bold text-kado-pink-600 disabled:cursor-wait disabled:opacity-60"
        :disabled="isSending"
        @click="pendingRunsStore.retryAll()"
      >
        {{ isSending ? 'Envoi en cours...' : 'Réessayer' }}
      </button>
      <button
        type="button"
        class="cursor-pointer border border-kado-pink-400 bg-white px-2.5 py-1.5 text-xs leading-none font-bold text-kado-pink-600"
        @click="showDetails = !showDetails"
      >
        {{ showDetails ? 'Masquer les détails' : 'Voir les détails' }}
      </button>
    </span>
    <span v-if="showDetails" class="mt-2 block text-xs">
      <span v-for="run in runs" :key="run.run_id" class="mt-1 flex items-center gap-2">
        <span class="flex-1">
          <b>{{ run.game_name }}</b> : {{ formatScore(run.request?.score ?? 0) }} points, le {{ formatDate(run.saved_at) }}
          <br>
          Erreur : {{ run.error?.status === 0 ? 'serveur injoignable' : `${run.error?.status} ${run.error?.message ?? ''}` }}
          ({{ run.attempts ?? 1 }} essai{{ (run.attempts ?? 1) > 1 ? 's' : '' }})
        </span>
        <button
          type="button"
          class="cursor-pointer border border-kado-pink-400 bg-white px-2.5 py-1.5 text-xs leading-none font-bold text-kado-pink-600"
          :disabled="isSending"
          @click="discard(run)"
        >
          Supprimer
        </button>
      </span>
    </span>
  </Error>
</template>
