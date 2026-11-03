import { getCurrentScope, onScopeDispose, toValue, watch } from 'vue'

import { useClanStore } from '@/stores/clan'
import { useRealtimeStore, whenVisible } from '@/stores/realtime'

// the private channel of a player (App\Support\Realtime::user)
export const userChannel = (id) => (id ? `App.Models.User.${id}` : null)

// listens to the events of a channel while the component (or the store) lives: { 'event.name': handler }. The name can be
// a ref or a getter (null: nothing), the channel changes with it. resync: what reloads what the page shows from the
// channel, called when its events may have been missed (subscribed after the page loaded, again after a cut)
export function useChannel(name, handlers, { isPrivate = true, resync = null } = {}) {
  const realtime = useRealtimeStore()
  let stop = () => {}

  watch(() => toValue(name), (channel) => {
    stop()
    stop = channel ? realtime.listen(channel, handlers, { isPrivate, resync }) : () => {}
  }, { immediate: true })
  onScopeDispose(() => stop())
}

// called when the socket connects again after a cut (the events of meanwhile were missed): a few seconds later (not every
// player at once), once the tab is shown
export function onRealtimeReconnect(hook) {
  const realtime = useRealtimeStore()
  onScopeDispose(realtime.onReconnect(hook))
}

// a refresh called by the polling of before: only while the events do not come (no Reverb, cut, or the channel not
// subscribed: { channel } its name, a ref or a getter)
export function usePolling(fn, ms, { channel = null } = {}) {
  const realtime = useRealtimeStore()
  const id = setInterval(() => {
    if (!realtime.isLive(toValue(channel))) {
      fn()
    }
  }, ms)
  onScopeDispose(() => clearInterval(id))
}

// several events in a row make one reload, a bit later (jitter: the players who receive the same event of the site do
// not all call the API at the same millisecond), once the tab is shown when it is hidden
export function refetchSoon(fn, { delay = 1000, jitter = 0 } = {}) {
  let timer = null
  let lastArgs = []
  const run = () => fn(...lastArgs)
  let cancel = () => {}
  if (getCurrentScope()) {
    onScopeDispose(() => {
      clearTimeout(timer)
      cancel()
    })
  }
  return (...args) => {
    lastArgs = args
    clearTimeout(timer)
    timer = setTimeout(() => {
      cancel = whenVisible(run)
    }, delay + Math.random() * jitter)
  }
}

// the channel of the clan of the player while a page shows it (the other clans: no channel, their members only)
const ownClanChannel = (clanId) => {
  const clanStore = useClanStore()
  const id = Number(toValue(clanId))
  return id && clanStore.clan?.id === id ? `clans.${id}` : null
}

// a page of the clan of the player: fn again when one of these parts changed (App\Events\ClanUpdated: 'clan', 'members',
// 'status', 'missions', 'history')
export function onClanUpdated(clanId, parts, fn) {
  const reload = refetchSoon(fn, { delay: 300, jitter: 700 })
  useChannel(() => ownClanChannel(clanId), {
    'clan.updated': (e) => e.parts.some((part) => parts.includes(part)) && reload(),
  }, { resync: fn })
}

// the forum of the clan of the player: fn(event) when a topic changed (App\Events\ClanForumUpdated: topic_id, deleted),
// a bit later for each topic (two topics changed in a row: both told); resync: what reloads the page when its events may
// have been missed
export function onClanForumUpdated(clanId, fn, { resync = null } = {}) {
  const reloads = new Map()
  // (made in the scope of the page: stopped with it)
  const scope = getCurrentScope()
  const reload = (e) => {
    if (!reloads.has(e.topic_id)) {
      reloads.set(e.topic_id, scope.run(() => refetchSoon(fn, { delay: 300, jitter: 700 })))
    }
    reloads.get(e.topic_id)(e)
  }
  useChannel(() => ownClanChannel(clanId), { 'clan.forum': reload }, { resync })
}
