import { ref, toValue } from 'vue'

import { natives } from '../anticheat/natives'

const scriptRegistry = {}

// ANTI CHEAT: a game bundle is an ES module that doesn't put its classes on window (resources/js/games/builds/
// bundle.mjs): its default export gives them once. It is imported with a random fragment: a module of its own (its
// classes, statics...), that a script of the page can't import too (another URL is another module).
async function loadModule(url) {
  const nonce = Array.from(natives.randomValues(new Uint32Array(4)), (n) => n.toString(36)).join('')
  const module = await import(/* @vite-ignore */ `${url}#k${nonce}`)
  const exports = typeof module.default === 'function' ? module.default() : null
  return exports ?? {}
}

// The versions of the games built before the ES modules (played for the replays recorded with them) are classic
// scripts that put their classes on window.
function loadScript(url) {
  const existing = scriptRegistry[url]
  if (existing) {
    existing.refCount += 1
    return existing.promise
  }

  const script = document.createElement('script')
  script.src = url
  script.dataset.kadoGameScript = url

  const entry = {
    node: script,
    promise: null,
    refCount: 1,
    loaded: false,
    exports: null,
  }
  entry.promise = new Promise((resolve, reject) => {
    script.addEventListener('load', () => {
      entry.loaded = true
      resolve()
    })
    script.addEventListener('error', () => {
      entry.loaded = true
      reject(new Error(`Failed to load game script: ${url}`))
    })
  })
  scriptRegistry[url] = entry

  document.body.appendChild(script)
  return entry.promise
}

// the classes put on window by a classic script: KadoKadeo and Game<Name>
function getGameClasses(url, globalName) {
  const entry = scriptRegistry[url]
  if (!entry) {
    return {}
  }
  if (!entry.exports) {
    entry.exports = { KadoKadeo: window.KadoKadeo, [globalName]: window[globalName] }
    delete window.KadoKadeo
    delete window[globalName]
  }
  return { KadoKadeo: entry.exports.KadoKadeo, gameClass: entry.exports[globalName] }
}

function unloadScript(url) {
  const entry = scriptRegistry[url]
  if (!entry) {
    return
  }

  entry.refCount -= 1
  if (entry.refCount > 0) {
    return
  }

  entry.node?.remove()
  delete scriptRegistry[url]
}

export function useGame(game) {
  let gameInstance = null
  let activeScript = null
  let loadToken = 0
  let crashListenerAttached = false

  const crash = ref(null)

  function onGameCrash(event) {
    crash.value = event?.detail ?? {
      message: 'Unknown game crash',
      phase: 'updatePhysics',
    }
  }

  function attachCrashListener() {
    if (crashListenerAttached || !window?.evts?.addEventListener) {
      return
    }
    window.evts.addEventListener('gameCrash', onGameCrash)
    crashListenerAttached = true
  }

  function detachCrashListener() {
    if (!crashListenerAttached || !window?.evts?.removeEventListener) {
      return
    }
    window.evts.removeEventListener('gameCrash', onGameCrash)
    crashListenerAttached = false
  }

  function clearCrash() {
    crash.value = null
  }

  function destroy() {
    detachCrashListener()
    if (gameInstance && typeof gameInstance.destroy === 'function') {
      gameInstance.destroy(true)
    }
    gameInstance = null

    if (activeScript && !activeScript.module) {
      unloadScript(activeScript.src)
    }
    activeScript = null
    PIXI.utils.destroyTextureCache()
    PIXI.utils.clearTextureCache()
    PIXI.Loader.shared.resources = {}
  }

  async function mount(canvas, args = {}) {
    const token = ++loadToken
    destroy()
    clearCrash()
    attachCrashListener()

    const currentGame = toValue(game)
    const config = {
      src: currentGame?.gamedata?.url ?? currentGame?.gamedata?.file,
      global: currentGame?.pascal_name,
      module: currentGame?.gamedata?.module === true,
    }

    if (!canvas || !config.src || !config.global) {
      return
    }

    let KadoKadeo, gameClass
    if (config.module) {
      const exports = await loadModule(config.src)
      if (token != loadToken) {
        return
      }
      KadoKadeo = exports.KadoKadeo
      gameClass = exports[config.global]
    } else {
      await loadScript(config.src)
      if (token != loadToken) {
        unloadScript(config.src)
        return
      }
      ;({ KadoKadeo, gameClass } = getGameClasses(config.src, config.global))
    }

    if (typeof KadoKadeo !== 'function' || typeof gameClass !== 'function') {
      console.error('Game classes are missing:', { kadoKadeo: KadoKadeo, gameClass })
      if (!config.module) {
        unloadScript(config.src)
      }
      throw new Error(`Game classes are missing for ${config.src} - ${config.global}`)
    }

    activeScript = config
    gameInstance = new KadoKadeo(canvas, gameClass, {
      ...args,
      // the game key of the server (Game::getGameKeyAttribute): accents dropped first ("Chakré Bouddha" -> chakrebouddha)
      name: currentGame.name
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '')
        .toLowerCase()
        .replaceAll(/\W/g, ''),
      gameId: currentGame.id,
      // version of the bundle: sent with the run, its replay is played with the same version
      build: currentGame?.gamedata?.hash ?? null,
      // ANTI CHEAT: functions of the browser taken when the page loaded (kac.Natives of the game)
      natives,
    })
  }

  function invalidate() {
    loadToken += 1
  }

  return {
    mount,
    destroy,
    invalidate,
    crash,
    clearCrash,
    // the game (KadoKadeoManager), null until it is mounted: the replay page follows and drives its replay
    getInstance: () => gameInstance,
  }
}
