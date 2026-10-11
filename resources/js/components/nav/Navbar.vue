<script setup></script>

<template>
  <nav>
    <ul class="flex justify-around">
      <li>
        <RouterLink :to="{ name: 'games.index' }">
          <img src="/gfx/menuGames.png" alt="Jeux" class="h-fit w-auto" />
        </RouterLink>
      </li>
      <li>
        <RouterLink :to="{ name: 'competition.index' }">
          <img src="/gfx/menuCompetition.png" alt="Compétition" class="h-fit w-auto" />
        </RouterLink>
      </li>
      <li>
        <RouterLink :to="{ name: 'profile.index' }">
          <img src="/gfx/menuProfile.png" alt="Profil" class="h-fit w-auto" />
        </RouterLink>
      </li>
    </ul>
  </nav>
</template>

<style scoped>
ul li:hover {
  background: url('/gfx/menuHover.png') no-repeat;
}
</style>
