<script setup>
const authStore = useAuthStore()
const periodStore = usePeriodStore()
const clanStore = useClanStore()
const messagesStore = useMessagesStore()
const router = useRouter()

clanStore.reload()
messagesStore.watchUnread()

const logout = () => {
  authStore.logout()
  router.push('/login')
}
</script>

<template>
  <nav class="kalendrier">
    <div class="kalendrierDays">
      <div v-for="i in periodStore.dayCount" :key="i" class="kalendrierPreviousDay"></div>
      <div class="kalendrierPresentDay"></div>
    </div>
    <aside>
      <p class="kalUser">
        <RouterLink :to="{ name: 'account' }" title="Préférences du compte">{{ authStore.user.display_name }}</RouterLink>
      </p>
      <p class="kalendrierText">Période {{ periodStore.period?.id }} - Jour {{ periodStore.dayCount+1 }}</p>
    </aside>
    <ul class="navKalendrierButtonsRight">
      <li><RouterLink to="/" @click="logout"><img src="/gfx/kalendarPreviousDay.gif" alt="logout"></RouterLink></li>
      <!-- the yellow mail of KadoKado when a message is unread -->
      <li class="relative">
        <RouterLink :to="{ name: 'messages.inbox' }" :title="messagesStore.unread ? `${messagesStore.unread} nouveau(x) message(s)` : 'Messages'">
          <img :src="messagesStore.unread ? '/assets/img/gfx/icons/newMail.gif' : '/gfx/kalendarIconMail.gif'" alt="mail">
        </RouterLink>
        <span v-if="messagesStore.unread" class="pointer-events-none absolute -top-1 -right-1 min-w-4 rounded-full border border-white bg-kado-pink-600 px-0.5 text-center text-2xs leading-3.5 font-bold text-white">
          {{ messagesStore.unread > 9 ? '9+' : messagesStore.unread }}
        </span>
      </li>
      <li><RouterLink :to="{ name: 'forum.index' }" title="Forum"><img src="/gfx/kalendarIconForum.gif" alt="forum"></RouterLink></li>
      <li><RouterLink :to="{ name: 'profile.index' }"><img src="/gfx/kalendarIconScore.gif" alt="scores"></RouterLink></li>
      <li>
        <RouterLink v-if="clanStore.enabled" :to="clanStore.clan ? { name: 'clans.show', params: { id: clanStore.clan.id } } : { name: 'clans.index' }" title="Mon clan">
          <img src="/gfx/kalendarIconClan.gif" alt="clans">
        </RouterLink>
        <!-- the clans turned off in the admin -->
        <a v-else class="grayscale cursor-default" title="Mon clan : prochainement disponible">
          <img src="/gfx/kalendarIconClan.gif" alt="clans">
        </a>
      </li>
    </ul>
    <ul class="navKalendrierButtonsBottom">
      <li><RouterLink to="/" class="grayscale"><img src="/gfx/kalendarIconKado.gif" alt="points kado"></RouterLink></li>
      <li><RouterLink :to="{ name: 'help' }"><img src="/gfx/kalendarIconHelp.gif" alt="aide"></RouterLink></li>
      <!-- the admin panel (Filament), outside of the SPA -->
      <li v-if="authStore.user.is_admin">
        <a href="/admin" title="Administration" class="text-kado-orange hover:text-kado-pink-600">
          <svg viewBox="0 0 24 24"
               width="15"
               height="15"
               class="inline-block align-middle"
               aria-label="admin">
            <circle cx="12"
                    cy="12"
                    r="8.5"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="4"
                    stroke-dasharray="3.34 3.34" />
            <circle cx="12"
                    cy="12"
                    r="5.5"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="3" />
          </svg>
        </a>
      </li>
    </ul>
  </nav>
</template>
