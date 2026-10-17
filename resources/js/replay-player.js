// The replay of a run in the admin panel (App\Http\Controllers\RunReplayController): the game and its replay, like on
// the replay page of the site (pages/runs/show.vue), outside of the Vue app.
import { watch } from 'vue'

import { useGame } from './composables/useGame'

async function play() {
  const { game, args } = JSON.parse(document.getElementById('replay-data').textContent)
  const message = document.getElementById('message')
  // part of the bundle of the site (main.js)
  await import('./pixi-tween')
  const { mount, crash } = useGame(game)
  watch(crash, (value) => {
    message.hidden = !value
    message.textContent = value ? `Le jeu a planté : ${value.message ?? 'erreur inconnue'}` : ''
  })
  try {
    // the size of the game (like components/games/GameScript.vue): without it, the canvas stays empty
    await mount(document.getElementById('game'), {
      ...args,
      canvasWidth: 600,
      canvasHeight: game.is_arkadeo ? 500 : 640,
    })
  } catch(e) {
    message.hidden = false
    message.textContent = `Le replay n’a pas pu être lancé : ${e.message}`
  }
}

play()
