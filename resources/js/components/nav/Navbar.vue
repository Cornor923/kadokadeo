<script setup></script>

<script setup>
// the buttons of the menu: the halo of menuHover.png when hovered
const item = 'min-w-0 bg-size-[100%_100%] bg-no-repeat hover:bg-[url(/gfx/menuHover.png)]'
</script>

<template>
  <nav>
    <ul class="flex justify-around">
      <li :class="item">
        <RouterLink :to="{ name: 'games.index' }">
          <img src="/gfx/menuGames.png" alt="Jeux" class="h-auto w-auto max-w-full" />
        </RouterLink>
      </li>
      <li :class="item">
        <RouterLink :to="{ name: 'competition.index' }">
          <img src="/gfx/menuCompetition.png" alt="Compétition" class="h-auto w-auto max-w-full" />
        </RouterLink>
      </li>
      <li :class="item">
        <RouterLink :to="{ name: 'profile.index' }">
          <img src="/gfx/menuProfile.png" alt="Profil" class="h-auto w-auto max-w-full" />
        </RouterLink>
      </li>
      <slot />
    </ul>
  </nav>
</template>

