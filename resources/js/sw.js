// The service worker of the installed site, copied to public/sw.js by vite.config.js with the time of the build at its
// top: every build is a new version for the browser (resources/js/composables/usePwa.js).
// Only the static files go through its cache: the API, the session and the pages stay on the network (a page holds the
// CSRF token), no score can be played or read offline.
const CACHE = 'kado-v1'
const OFFLINE = '/offline.html'
const MAX_ENTRIES = 500
const STATIC_FILES = /^\/(build|vendor|gamesdata|gfx|fonts|assets|icons)\//

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll([OFFLINE, '/gfx/logoBasic.png'])).then(() => self.skipWaiting()))
})

self.addEventListener('activate', (event) => {
  event.waitUntil((async() => {
    const names = await caches.keys()
    await Promise.all(names.filter((name) => name !== CACHE).map((name) => caches.delete(name)))
    await self.registration.navigationPreload?.enable()
    await self.clients.claim()
  })())
})

async function page(event) {
  try {
    return await event.preloadResponse || await fetch(event.request)
  } catch {
    return await caches.match(OFFLINE) ?? Response.error()
  }
}

// ponytail: first in, first out, an LRU if the games played most often get pushed out
async function trim(cache) {
  const keys = await cache.keys()
  await Promise.all(keys.slice(0, Math.max(0, keys.length - MAX_ENTRIES)).map((key) => cache.delete(key)))
}

async function store(event, cache) {
  const response = await fetch(event.request)
  if (response.status === 200) {
    await cache.put(event.request, response.clone())
    await trim(cache)
  }
  return response
}

// a file named by its content (build) or its version (vendor, ?v= of the games) never changes: the cache, else the
// network; another one: the cache at once, refreshed for the next time
async function staticFile(event, immutable) {
  const cache = await caches.open(CACHE)
  const cached = await cache.match(event.request)
  if (cached && immutable) {
    return cached
  }
  const update = store(event, cache)
  if (cached) {
    event.waitUntil(update.catch(() => {}))
    return cached
  }
  return update
}

self.addEventListener('fetch', (event) => {
  const { request } = event
  const url = new URL(request.url)
  if (request.method !== 'GET' || url.origin !== location.origin) {
    return
  }
  if (request.mode === 'navigate') {
    event.respondWith(page(event))
    return
  }
  // (a Range request, the sounds: its 206 can't be cached)
  if (STATIC_FILES.test(url.pathname) && !request.headers.has('range')) {
    event.respondWith(staticFile(event, url.search !== '' || /^\/(build|vendor)\//.test(url.pathname)))
  }
})
