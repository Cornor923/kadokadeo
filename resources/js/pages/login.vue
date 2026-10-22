<script setup>
const authStore = useAuthStore()
</script>

<template>
  <div class="inColumns">
    <section class="homeLeftColumn"></section>
    <section class="homeRightColumn">
      <KadoPageTitle class="mt-6.25 mb-5">Bienvenue</KadoPageTitle>
      <KadoSectionTitle>Des jeux</KadoSectionTitle>
      <p>Plus de 70 jeux exclusifs à débloquer !</p>
      <KadoSectionTitle>Plein d'amis</KadoSectionTitle>
      <p>... et d'adversaires dans une communauté de joueurs pleine de bonne humeur !</p>
      <MessageError v-if="authStore.banMessage">{{ authStore.banMessage }}</MessageError>
      <p class="text-center btnHomepagePlay">
        <a href="/login" title="S'identifier / s'inscrire">
          {{ '>> Jouer <<' }}
        </a>
      </p>
    </section>
  </div>
</template>
