<script setup>
// the preferences of the player (App\Enums\UserPreference): saved as soon as one changes
const authStore = useAuthStore()
const { savePreferences, isLoading, error } = useAccount()

const groups = [
  {
    title: 'Notifications des replays',
    items: [
      { key: 'notify_run_comments', label: 'Être averti lorsqu\'un commentaire est posé sur un de mes replays' },
      { key: 'notify_comment_replies', label: 'Être averti des réponses à mes commentaires sur les replays' },
      { key: 'notify_comment_likes', label: 'Être averti quand on aime mes commentaires (une seule notification par commentaire)' },
    ],
  },
]

const values = ref({ ...(authStore.user?.preferences ?? {}) })
watch(() => authStore.user?.preferences, (preferences) => {
  values.value = { ...(preferences ?? {}) }
})
const saved = ref(false)

const save = (key, value) => {
  saved.value = false
  values.value[key] = value
  savePreferences({ [key]: value }).then((preferences) => {
    values.value = preferences
    authStore.user.preferences = preferences
    saved.value = true
  }).catch(() => {
    values.value[key] = !value
  })
}
</script>

<template>
  <div class="space-y-4">
    <MessageError v-if="error">{{ error }}</MessageError>
    <MessageSuccess v-else-if="saved">Vos préférences ont été enregistrées.</MessageSuccess>

    <section v-for="group in groups" :key="group.title" class="space-y-2">
      <h2 class="normal-case">{{ group.title }}</h2>
      <FormCheckbox v-for="item in group.items"
                    :key="item.key"
                    :model-value="values[item.key] ?? true"
                    :disabled="isLoading"
                    @update:model-value="save(item.key, $event)">
        {{ item.label }}
      </FormCheckbox>
    </section>
    <p class="mx-0 text-xs italic">
      Les notifications se trouvent avec vos messages privés, dans l'onglet « Notifications ». Elles sont supprimées
      automatiquement après deux mois.
    </p>
  </div>
</template>
