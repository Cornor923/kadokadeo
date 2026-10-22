<script setup>
// the forum of the site is the forum of Eternaltwin, embedded (https://eternaltwin.org/docs/app/etwin-forum-embed):
// its script puts it in an iframe of Eternaltwin, sizes it, keeps the address of the page in step with the forum page
// shown (#!t/123) and asks for the access token of the player, given by the route token of EtwinForumController
const { get: getStatus, error } = useApi()
const { get: getToken } = useApi()

const container = ref(null)
const status = ref(null)
let forum = null

// the script of Eternaltwin, loaded once for the whole visit
function loadScript(src) {
  if (window.EternaltwinForum) {
    return Promise.resolve(window.EternaltwinForum)
  }
  return new Promise((resolve, reject) => {
    const script = document.createElement('script')
    script.src = src
    script.async = true
    script.onload = () => resolve(window.EternaltwinForum)
    script.onerror = () => reject(new Error(`could not load ${src}`))
    document.head.appendChild(script)
  })
}

// the token of the player, or none: the forum is then read as a guest and says to log in on the game
async function token() {
  try {
    const response = await getToken('/etwin-forum/token')
    return response.data.access_token
  } catch {
    return null
  }
}

onMounted(async() => {
  try {
    status.value = (await getStatus('/etwin-forum/status')).data.data
    const EternaltwinForum = await loadScript(`${status.value.url}/embed/forum.js`)
    // the page may have been left while the script loaded
    if (container.value) {
      forum = EternaltwinForum.mount(container.value, {
        group: status.value.group,
        getToken: token,
        locale: 'fr-FR',
        title: 'Forum de KadoKadéo',
      })
    }
  } catch {
    error.value ??= 'Le forum d\'Eternaltwin ne répond pas, réessayez plus tard.'
  }
})

onBeforeUnmount(() => {
  forum?.destroy()
})
</script>

<template>
  <NavTabs :items="[{ label: 'Forum', value: 'forum', route: { name: 'forum.index' } }]" :selected-index="0" />

  <div class="px-2 pb-2">
    <MessageError v-if="error">{{ error }}</MessageError>
    <p v-if="status?.needs_login" class="mb-2 italic">
      Pour écrire sur le forum, <RouterLink :to="{ name: 'login' }">reconnectez-vous</RouterLink> et autorisez KadoKadéo à
      poster pour vous.
    </p>
    <div ref="container" />
  </div>
</template>
