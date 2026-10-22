<script setup>
const authStore = useAuthStore()
</script>

<template>
  <div class="flex flex-wrap items-start justify-center">
    <section class="h-[475px] w-[488px] bg-[url(/gfx/bgIntroHomePage.png)] bg-no-repeat"></section>
    <section class="mx-4 w-[360px]">
      <KadoPageTitle class="mt-6.25 mb-5">Bienvenue</KadoPageTitle>
      <KadoSectionTitle>Des jeux</KadoSectionTitle>
      <p class="mx-2.5 my-4">Plus de 70 jeux exclusifs à débloquer !</p>
      <KadoSectionTitle>Plein d'amis</KadoSectionTitle>
      <p class="mx-2.5 my-4">... et d'adversaires dans une communauté de joueurs pleine de bonne humeur !</p>
      <MessageError v-if="authStore.banMessage">{{ authStore.banMessage }}</MessageError>
      <!-- the play button of the home page: green letters in a gradient, a yellow shadow -->
      <p class="mt-10 h-[52px] w-[362px] bg-[url(/gfx/btnHomepagePlay.png)] bg-no-repeat pt-1.25 text-center font-junegull text-[2em] tracking-[0.1em] hover:bg-[url(/gfx/btnHomepagePlayHover.png)] hover:pt-2">
        <a href="/login"
           title="S'identifier / s'inscrire"
           class="mr-2.5 ml-[62px] bg-[linear-gradient(to_bottom,var(--color-kado-play-400)_0%,var(--color-kado-play-500)_40%,var(--color-kado-play-900)_41%,var(--color-kado-play-700)_100%)] bg-clip-text font-bold text-transparent drop-shadow-[0_3px_0_var(--color-kado-yellow-500)]">
          {{ '>> Jouer <<' }}
        </a>
      </p>
    </section>
  </div>
</template>
