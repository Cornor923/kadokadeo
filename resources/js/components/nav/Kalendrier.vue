<script setup>
const authStore = useAuthStore()
const periodStore = usePeriodStore()
const clanStore = useClanStore()
const messagesStore = useMessagesStore()
const router = useRouter()

clanStore.reload()
messagesStore.watchUnread()

const mailTitle = computed(() => {
  const parts = [
    messagesStore.unread && `${messagesStore.unread} nouveau(x) message(s)`,
    messagesStore.notificationsUnread && `${messagesStore.notificationsUnread} notification(s)`,
  ].filter(Boolean)
  return parts.length ? parts.join(', ') : 'Messages'
})

// the login page once the session is closed
const logout = async() => {
  await authStore.logout().catch(() => {})
  router.push('/login')
}
// the round buttons of the kalendrier
const button = 'block h-[21px] w-[25px] bg-[url(/gfx/kalendarButton.gif)] bg-no-repeat text-center leading-[17px] hover:bg-[url(/gfx/kalendarButtonHover.gif)]'
const rightButton = `${button} mb-1.25`
const bottomButton = `${button} mr-1.25`
</script>

<template>
  <nav class="relative mt-0.5 h-[141px] w-[201px] bg-[url(/gfx/bgKalendrier.png)] bg-no-repeat text-[0.75em]">
    <div class="absolute top-[47px] left-[18px] flex h-9 w-[140px] flex-wrap">
      <div v-for="i in periodStore.dayCount" :key="i" class="mr-1.25 mb-1.5 size-[15px] bg-[url(/gfx/kalendarPreviousDay.gif)] bg-no-repeat"></div>
      <div class="mr-1.25 mb-1.5 size-[15px] bg-[url(/gfx/kalendarPresentDay.gif)] bg-no-repeat"></div>
    </div>
    <aside>
      <p class="absolute top-2 left-3.75">
        <RouterLink :to="{ name: 'account' }" title="Préférences du compte">{{ authStore.user.display_name }}</RouterLink>
      </p>
      <p class="absolute top-[87px] left-[54px] h-3 w-[103px] text-center text-[0.8em] text-kado-slate-400">Période {{ periodStore.period?.id }} - Jour {{ periodStore.dayCount+1 }}</p>
    </aside>
    <ul class="absolute top-1.5 left-[166px] flex flex-col">
      <li><a href="/login"
             :class="rightButton"
             title="Déconnexion"
             @click.prevent="logout"><img src="/gfx/kalendarPreviousDay.gif" alt="Déconnexion"></a></li>
      <!-- the yellow mail of KadoKado when a message is unread -->
      <li class="relative">
        <RouterLink :class="rightButton" :to="{ name: !messagesStore.unread && messagesStore.notificationsUnread ? 'messages.notifications' : 'messages.inbox' }" :title="mailTitle">
          <img :src="messagesStore.total ? '/assets/img/gfx/icons/newMail.gif' : '/gfx/kalendarIconMail.gif'" alt="mail">
        </RouterLink>
        <span v-if="messagesStore.total" class="pointer-events-none absolute -top-1 -right-1 min-w-4 rounded-full border border-white bg-kado-pink-600 px-0.5 text-center text-2xs leading-3.5 font-bold text-white">
          {{ messagesStore.total > 9 ? '9+' : messagesStore.total }}
        </span>
      </li>
      <li><RouterLink :class="rightButton" :to="{ name: 'forum.index' }" title="Forum"><img src="/gfx/kalendarIconForum.gif" alt="forum"></RouterLink></li>
      <li><RouterLink :class="rightButton" :to="{ name: 'profile.index' }"><img src="/gfx/kalendarIconScore.gif" alt="scores"></RouterLink></li>
      <li>
        <RouterLink :class="rightButton"
                    v-if="clanStore.enabled"
                    :to="clanStore.clan ? { name: 'clans.show', params: { id: clanStore.clan.id } } : { name: 'clans.index' }"
                    title="Mon clan">
          <img src="/gfx/kalendarIconClan.gif" alt="clans">
        </RouterLink>
        <!-- the clans turned off in the admin -->
        <a :class="rightButton"
           v-else
           class="grayscale cursor-default"
           title="Mon clan : prochainement disponible">
          <img src="/gfx/kalendarIconClan.gif" alt="clans">
        </a>
      </li>
    </ul>
    <ul class="absolute top-[110px] left-[7px] flex">
      <li><RouterLink :class="bottomButton" to="/" class="grayscale"><img src="/gfx/kalendarIconKado.gif" alt="points kado"></RouterLink></li>
      <li><RouterLink :class="bottomButton" :to="{ name: 'help' }"><img src="/gfx/kalendarIconHelp.gif" alt="aide"></RouterLink></li>
      <!-- the admin panel (Filament), outside of the SPA -->
      <li v-if="authStore.user.is_admin">
        <a :class="bottomButton"
           href="/admin"
           title="Administration"
           class="text-kado-orange-500 hover:text-kado-pink-600">
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
