// ANTI CHEAT: first, before any other script can change them (see the module)
import './anticheat/natives'

import dayjs from 'dayjs'
import utc from 'dayjs/plugin/utc'
import { createPinia } from 'pinia'
import { createApp } from 'vue'
import VueLazyload from 'vue-lazyload'

import App from './App.vue'
import { registerPwa } from './composables/usePwa'
import router from './router'

import('./pixi-tween')

dayjs.extend(utc)

const app = createApp(App)

app.use(createPinia())
app.use(router)
app.use(VueLazyload, {
  error: '/gfx/achievements/error.png',
  loading: '/gfx/achievements/loading.png',
  attempt: 1,
  // the default is ['scroll', 'wheel', 'mousewheel', 'resize', 'animationend', 'transitionend']
  listenEvents: ['scroll', 'mouseup', 'resize', 'pointerup'],
})

registerPwa(router)

app.mount('#app')
