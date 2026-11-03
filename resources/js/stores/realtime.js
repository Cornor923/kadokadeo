import Echo from 'laravel-echo'
import { defineStore } from 'pinia'
import Pusher from 'pusher-js'
import { reactive, ref } from 'vue'

import { client } from '@/composables/useApi'

// after a cut, the pages of every player reload what they show: spread over that long (Reverb started again, every
// browser connects at the same moment)
const RECONNECT_JITTER_MS = 5000
// a channel nothing listens to anymore is left that long after: coming back to the page does not authorize it again
const LINGER_MS = 30000
// a subscription refused for another reason than the rights: tried again, waiting longer each time
const RETRY_MIN_MS = 2000
const RETRY_MAX_MS = 60000

// the private channel of a player: left at once (logged out, nothing of him must still come to this browser)
const USER_CHANNEL_PREFIX = 'App.Models.User.'

// fn now, or once the tab is shown again when it is hidden (a tab in the background does not reload what nobody sees).
// The same fn asked several times while hidden: once. Returns what cancels it
const hiddenQueue = new Set()
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState !== 'hidden') {
    const queued = [...hiddenQueue]
    hiddenQueue.clear()
    queued.forEach((fn) => fn())
  }
})
export function whenVisible(fn) {
  if (document.visibilityState === 'hidden') {
    hiddenQueue.add(fn)
  } else {
    fn()
  }
  return () => hiddenQueue.delete(fn)
}

// the realtime of the site (Reverb, App\Support\Realtime and routes/channels.php): one socket, the channels joined while
// something listens to them (useChannel). window.Kado.reverb is only set when the server broadcasts: without it nothing
// connects and the pages poll as before (usePolling)
export const useRealtimeStore = defineStore('realtime', () => {
  const config = window.Kado?.reverb ?? null
  const available = !!config
  const connected = ref(false)
  // the channels subscribed now (their events come): the others are polled
  const live = reactive(new Set())

  // name -> { channel, count, resyncs (resync -> its call), leaveTimer, retryTimer, retries }
  const channels = new Map()
  const reconnectHooks = new Set()
  // the status of the last refused authorization of a channel (its full name)
  const authStatus = new Map()
  let reconnectedAt = 0
  let echo = null

  // (a reconnect: every browser at once, spread)
  const afterReconnect = () => Date.now() - reconnectedAt < RECONNECT_JITTER_MS * 2
  const spread = (fn) => setTimeout(() => whenVisible(fn), Math.random() * RECONNECT_JITTER_MS)

  if (available) {
    const https = (config.scheme ?? window.location.protocol.replace(':', '')) === 'https'
    const port = Number(config.port ?? (window.location.port || (https ? 443 : 80)))
    echo = new Echo({
      broadcaster: 'reverb',
      Pusher,
      key: config.key,
      wsHost: config.host ?? window.location.hostname,
      wsPort: port,
      wssPort: port,
      forceTLS: https,
      enabledTransports: ['ws', 'wss'],
      // the private channels are authorized with the session of the site (its cookie, App\Support\Realtime). After a
      // cut every channel of every browser asks again: spread
      channelAuthorization: {
        customHandler: ({ socketId, channelName }, callback) => {
          setTimeout(() => {
            client.post('/broadcasting/auth', { socket_id: socketId, channel_name: channelName })
              .then((response) => {
                authStatus.delete(channelName)
                callback(null, response.data)
              })
              .catch((e) => {
                authStatus.set(channelName, e.response?.status ?? 0)
                callback(e, null)
              })
          }, afterReconnect() ? Math.random() * RECONNECT_JITTER_MS : 0)
        },
      },
    })

    // connected again after a cut: what happened meanwhile was missed, the pages reload what they show
    let connectedOnce = false
    echo.connector.pusher.connection.bind('state_change', ({ current }) => {
      const now = current === 'connected'
      if (!now) {
        // (pusher-js subscribes every channel again once connected)
        live.clear()
      }
      if (now && !connected.value && connectedOnce) {
        reconnectedAt = Date.now()
        reconnectHooks.forEach(spread)
      }
      connectedOnce ||= now
      connected.value = now
    })
  }

  const leave = (name, entry) => {
    clearTimeout(entry.retryTimer)
    clearTimeout(entry.leaveTimer)
    echo.leave(name)
    channels.delete(name)
    live.delete(name)
  }

  // the channel of a name, joined at the first listener
  const join = (name, isPrivate) => {
    let entry = channels.get(name)
    if (entry) {
      clearTimeout(entry.leaveTimer)
      // (refused or failed meanwhile: asked again for this page; nothing while pending or subscribed)
      if (!live.has(name) && connected.value) {
        echo.connector.pusher.subscribe(entry.channel.name)
      }
      return entry
    }
    entry = { channel: isPrivate ? echo.private(name) : echo.channel(name), count: 0, resyncs: new Map(), leaveTimer: null, retryTimer: null, retries: 0 }
    channels.set(name, entry)
    // (a channel left while its subscription was pending, joined again: pusher-js gives the same one, its old callbacks
    // with it)
    const current = () => channels.get(name) === entry
    entry.channel.subscribed(() => {
      if (!current()) {
        return
      }
      entry.retries = 0
      live.add(name)
      // what came between the load of the pages and now (or during a cut) was missed
      entry.resyncs.forEach(afterReconnect() ? spread : whenVisible)
    })
    entry.channel.error(() => {
      if (!current()) {
        return
      }
      live.delete(name)
      // not allowed (not in the clan anymore, logged out...): asked again only by a new page
      const status = authStatus.get(entry.channel.name)
      if (status === 401 || status === 403) {
        return
      }
      const delay = Math.min(RETRY_MAX_MS, RETRY_MIN_MS * 2 ** entry.retries++)
      clearTimeout(entry.retryTimer)
      entry.retryTimer = setTimeout(() => {
        // (cut meanwhile: pusher-js subscribes it again once connected; left meanwhile: nothing)
        if (current() && connected.value && entry.count > 0) {
          echo.connector.pusher.subscribe(entry.channel.name)
        }
      }, delay * (0.5 + Math.random()))
    })
    return entry
  }

  // listens to the events of a channel ({ '<event>': handler }, RealtimeEvent::broadcastAs); resync is called when its
  // events may have been missed (its subscription done after the page loaded, again after a cut or a failure). Returns
  // the function that stops it. The channel is left a while after nothing listens to it anymore
  const listen = (name, handlers, { isPrivate = true, resync = null } = {}) => {
    if (!echo) {
      return () => {}
    }
    const entry = join(name, isPrivate)
    entry.count++
    const events = Object.entries(handlers).map(([event, handler]) => [`.${event}`, handler])
    events.forEach(([event, handler]) => entry.channel.listen(event, handler))
    if (resync) {
      // (not after the page is gone: the call can wait for the tab to be shown)
      entry.resyncs.set(resync, () => entry.resyncs.has(resync) && resync())
    }

    let stopped = false
    return () => {
      if (stopped) {
        return
      }
      stopped = true
      events.forEach(([event, handler]) => entry.channel.stopListening(event, handler))
      entry.resyncs.delete(resync)
      if (--entry.count === 0) {
        if (name.startsWith(USER_CHANNEL_PREFIX)) {
          leave(name, entry)
        } else {
          entry.leaveTimer = setTimeout(() => leave(name, entry), LINGER_MS)
        }
      }
    }
  }

  // its events come now (no channel: the socket is connected)
  const isLive = (name) => connected.value && (!name || live.has(name))

  const onReconnect = (hook) => {
    reconnectHooks.add(hook)
    return () => reconnectHooks.delete(hook)
  }

  return {
    available,
    connected,
    isLive,
    listen,
    onReconnect,
  }
})
