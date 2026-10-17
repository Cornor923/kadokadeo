<script setup>
// "Mon compte": the theme of the site, bought with Kado points (App\Http\Controllers\Api\ThemeController)
const authStore = useAuthStore()
const { get, post, put, isLoading, error } = useApi()

const themes = ref([])
const notice = ref(null)
// the look of each theme: its pattern and its title bar
const previews = {
  base: { pattern: '/gfx/bgBodyPattern.jpg', title: '/gfx/bgTitleBlue.svg', panel: '#dffaff' },
  karbon: { pattern: '/gfx/themes/karbon/patternBG.jpg', title: '/gfx/themes/karbon/greyh2_bg.jpg', panel: '#eef3f4' },
}

const load = () => get('/themes').then((response) => {
  themes.value = response.data.data
})
load()

const refresh = (message) => {
  notice.value = message
  authStore.fetchUser()
  load()
}
const buy = (theme) => {
  if (confirm(`Acheter le thème ${theme.name} pour ${formatScore(theme.price)} points Kado ?`)) {
    notice.value = null
    post(`/themes/${theme.key}/buy`).then(() => refresh(`Le thème ${theme.name} est à vous ! Il est maintenant utilisé sur le site.`))
  }
}
const use = (theme) => {
  notice.value = null
  put('/user/theme', { theme: theme.key }).then(() => refresh(`Le thème ${theme.name} est maintenant utilisé sur le site.`))
}
</script>

<template>
  <NavTabs :items="[{ label: 'Mon compte', value: 'account' }]" />

  <div class="relative px-2 space-y-4">
    <h1 class="mt-0 text-center">Mon compte</h1>

    <h2 class="normal-case">Thème du site</h2>
    <p class="mx-0">
      Changez l'apparence de KadoKadéo ! Le thème KadoKado est offert à tous les joueurs, les autres thèmes s'achètent
      une seule fois avec vos points Kado. Vous pouvez ensuite changer de thème quand vous le voulez.
    </p>
    <p class="mx-0">
      Vos points Kado :
      <strong>{{ formatScore(authStore.user?.kado_points ?? 0) }}</strong>
      <img src="/gfx/skpoint.gif" alt="Kado" class="ml-1 inline size-5" />
    </p>

    <MessageError v-if="error">{{ error }}</MessageError>
    <MessageSuccess v-else-if="notice">{{ notice }}</MessageSuccess>
    <Loader v-if="isLoading && !themes.length" />

    <div class="grid gap-4 sm:grid-cols-2">
      <div
        v-for="theme in themes"
        :key="theme.key"
        class="border-2 bg-white"
        :class="theme.active ? 'border-kado-orange' : 'border-kado-cyan-800'"
      >
        <!-- the preview: the pattern of the background, around a panel with the title bar of the theme -->
        <div class="p-3" :style="{ background: `url(${previews[theme.key]?.pattern}) repeat` }">
          <div class="h-20 border-2 border-white" :style="{ backgroundColor: previews[theme.key]?.panel }">
            <div class="h-[35px] pl-10 pt-1 text-lg font-bold" :style="{ background: `url(${previews[theme.key]?.title}) no-repeat` }">
              {{ theme.name }}
            </div>
          </div>
        </div>
        <div class="flex items-center justify-between gap-2 p-2">
          <div class="text-sm">
            <template v-if="theme.price === 0">Offert</template>
            <template v-else-if="theme.owned">Acheté</template>
            <template v-else>
              <strong>{{ formatScore(theme.price) }}</strong>
              <img src="/gfx/skpoint.gif" alt="Kado" class="ml-1 inline size-4" />
            </template>
          </div>
          <span v-if="theme.active" class="font-bold text-kado-orange">Thème actuel</span>
          <FormButton v-else-if="theme.owned" size="lg" @click="use(theme)">Utiliser</FormButton>
          <FormButton v-else
                      size="lg"
                      variant="pink"
                      :disabled="(authStore.user?.kado_points ?? 0) < theme.price"
                      :title="(authStore.user?.kado_points ?? 0) < theme.price ? 'Vous n\'avez pas assez de points Kado' : ''"
                      @click="buy(theme)">Acheter</FormButton>
        </div>
      </div>
    </div>
  </div>
</template>
