<script setup>
const authStore = useAuthStore()
</script>

<template>
  <div class="inColumns">
    <section class="homeLeftColumn"></section>
    <section class="homeRightColumn">
      <h1 class="text-center">Bienvenue</h1>
      <h2 style="margin:0;">Des jeux</h2>
      <p>Plus de 70 jeux exclusifs à débloquer !</p>
      <h2 style="margin-left:0;">Plein d'amis</h2>
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
