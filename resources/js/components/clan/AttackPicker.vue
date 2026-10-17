<script setup>
// "Attaquer ce clan": the score of the run on the chosen game becomes the attack
const props = defineProps({
  clan: { type: Object, required: true },
})

const router = useRouter()
const { attack, error } = useClans()
const clanStore = useClanStore()

const choose = (game) =>
  attack(props.clan.id, game.id).then((data) => router.push({ name: 'clans.play', params: { action: data.data.id } }))
</script>

<template>
  <div class="space-y-4">
    <MessageError v-if="clan.viewer.attack_blocked">{{ clan.viewer.attack_blocked }}</MessageError>
    <template v-else>
      <p class="mx-0">
        Choisissez un jeu et faites le meilleur score possible : il deviendra une attaque contre le clan
        <strong>{{ clan.name }}</strong>. Si personne ne le bat dans les {{ clanStore.rules?.attack_hours }} heures, votre clan remporte
        <Number :value="clan.viewer.attack_points" color="pink" /> point(s) et le clan adverse en perd autant. Si
        l'attaque est repoussée, votre clan ne perd rien.
      </p>
      <MessageError v-if="error">{{ error }}</MessageError>
      <ClanGamePicker title="Attaquer avec" @select="choose" />
    </template>
  </div>
</template>
