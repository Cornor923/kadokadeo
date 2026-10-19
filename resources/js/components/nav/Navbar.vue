<script setup></script>

<template>
  <nav>
    <ul class="flex justify-around">
      <li class="min-w-0">
        <RouterLink :to="{ name: 'games.index' }">
          <img src="/gfx/menuGames.png" alt="Jeux" class="h-auto w-auto max-w-full" />
        </RouterLink>
      </li>
      <li class="min-w-0">
        <RouterLink :to="{ name: 'competition.index' }">
          <img src="/gfx/menuCompetition.png" alt="Compétition" class="h-auto w-auto max-w-full" />
        </RouterLink>
      </li>
      <li class="min-w-0">
        <RouterLink :to="{ name: 'profile.index' }">
          <img src="/gfx/menuProfile.png" alt="Profil" class="h-auto w-auto max-w-full" />
        </RouterLink>
      </li>
      <slot />
    </ul>
  </nav>
</template>

<style scoped>
ul li:hover {
  background: url('/gfx/menuHover.png') no-repeat;
  background-size: 100% 100%;
}
</style>
