<script setup>
// the clan runs begun by the player and never ended (the page closed during the run...): "Annuler la partie" when it can
// really not be finished
const props = defineProps({
  actions: { type: Array, required: true },
})
const emit = defineEmits(['updated'])

const { cancelAction, error } = useClans()

const cancel = (action) => {
  if (confirm(`Annuler cette partie sur ${action.game.name} ? Si elle est encore ouverte quelque part, elle ne comptera plus pour votre clan.`)) {
    cancelAction(action.id).then(() => emit('updated'))
  }
}
</script>

<template>
  <div v-if="props.actions.length" class="mx-0 mb-4 space-y-1 border-2 border-l-[10px] border-solid border-kado-orange bg-[#fff4dc] px-3 py-2 text-[#c25e00]">
    <MessageError v-if="error">{{ error }}</MessageError>
    <div v-for="action in props.actions" :key="action.id" class="flex flex-wrap items-center gap-2">
      <strong>{{ action.label }}</strong>
      <span>{{ action.game.name }}<template v-if="action.target"> ({{ action.target }})</template>, commencée le {{ new Date(action.started_at).toLocaleString('fr-FR') }}</span>
      <FormButton variant="pink" size="sm" @click="cancel(action)">Annuler la partie</FormButton>
      <span v-if="action.blocks" class="w-full text-xs">Tant qu'elle n'est pas terminée ou annulée, vous ne pouvez ni lancer une autre attaque ni défendre.</span>
    </div>
    <p class="m-0 text-xs">Une partie de clan qui n'a pas été terminée (page fermée pendant la partie...) reste en cours. Annulez-la seulement si vous ne pouvez vraiment plus la terminer.</p>
  </div>
</template>
