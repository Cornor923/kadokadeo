<script setup>
const authStore = useAuthStore()
</script>

<template>
  <aside class="top-bar-frame absolute bottom-0 h-fit w-full max-w-[424px] translate-y-[calc(50%-6px)]">
    <ul class="flex justify-between items-center -my-1.5 flex-wrap gap-2">
      <li class="flex gap-2 items-center">
        <img src="/gfx/topBarPointsKado.png" alt="Points Kado" />
        <Number :value="authStore.user.kado_points ?? 0" color="bigGreen" />
      </li>
      <li class="flex gap-1 items-center">
        <img src="/gfx/topBarGreenStar.png" alt="Green Star" />
        <Number :value="authStore.greenStars" color="bigGreen" />
      </li>
      <li class="flex gap-1 items-center">
        <img src="/gfx/topBarOrangeStar.png" alt="Orange Star" />
        <Number :value="authStore.orangeStars" color="bigGreen" />
      </li>
      <li class="flex gap-1 items-center">
        <img src="/gfx/topBarRedStar.png" alt="Red Star" />
        <Number :value="authStore.redStars" color="bigGreen" />
      </li>
    </ul>
  </aside>
</template>

