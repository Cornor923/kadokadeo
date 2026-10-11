<script setup>
const authStore = useAuthStore()
const periodStore = usePeriodStore()
const router = useRouter()

const logout = () => {
  authStore.logout()
  router.push('/login')
}
</script>

<template>
  <nav id="kalendrier">
    <div class="kalendrierDays">
      <div v-for="i in periodStore.dayCount" :key="i" class="kalendrierPreviousDay"></div>
      <div class="kalendrierPresentDay"></div>
    </div>
    <aside>
      <p class="kalUser">
        <RouterLink to="/" title="Préférences du compte">{{ authStore.user.display_name }}</RouterLink>
      </p>
      <p class="kalendrierText">Période {{ periodStore.period?.id }} - Jour {{ periodStore.dayCount+1 }}</p>
    </aside>
    <ul class="navKalendrierButtonsRight">
      <li><RouterLink to="/" @click="logout"><img src="/gfx/kalendarPreviousDay.gif" alt="logout"></RouterLink></li>
      <li><RouterLink to="/" class="grayscale"><img src="/gfx/kalendarIconMail.gif" alt="mail"></RouterLink></li>
      <li><RouterLink to="/" class="grayscale"><img src="/gfx/kalendarIconForum.gif" alt="forum"></RouterLink></li>
      <li><RouterLink :to="{ name: 'profile.index' }"><img src="/gfx/kalendarIconScore.gif" alt="scores"></RouterLink></li>
      <li><RouterLink to="/" class="grayscale"><img src="/gfx/kalendarIconClan.gif" alt="clans"></RouterLink></li>
    </ul>
    <ul class="navKalendrierButtonsBottom">
      <li><RouterLink to="/" class="grayscale"><img src="/gfx/kalendarIconKado.gif" alt="points kado"></RouterLink></li>
      <li><RouterLink :to="{ name: 'help' }"><img src="/gfx/kalendarIconHelp.gif" alt="aide"></RouterLink></li>
    </ul>
  </nav>
</template>
