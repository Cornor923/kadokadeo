import JSEncrypt from 'jsencrypt'
import { defineStore } from 'pinia'
import { ref } from 'vue'

import { client } from '@/composables/useApi'
import { useAuthStore } from '@/stores/auth'

// Runs the game could not send to the server, stored by resources/hx/lib/kado/PendingRuns.hx
const STORAGE_KEY = 'kado:pendingRuns'

function readRuns() {
  try {
    const runs = JSON.parse(localStorage.getItem(STORAGE_KEY))
    return Array.isArray(runs) ? runs : []
  } catch {
    return []
  }
}

function writeRuns(runs) {
  try {
    if (runs.length) {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(runs))
    } else {
      localStorage.removeItem(STORAGE_KEY)
    }
  } catch {
    // storage full or disabled: the list stays as it was
  }
}

function toBase64(bytes) {
  let binary = ''
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i])
  }
  return btoa(binary)
}

// Same encryption as the game client (resources/hx/lib/kado/KadoEndRun.hx), decoded by App\Services\RunService:
// AES-128-CTR payload (iv + cipher), AES key encrypted with the RSA public key, HMAC-SHA256 of the JSON with the AES key.
async function encryptRun(request, publicKey) {
  const json = new TextEncoder().encode(JSON.stringify(request))
  const rawKey = crypto.getRandomValues(new Uint8Array(16))
  const iv = crypto.getRandomValues(new Uint8Array(16))

  const aesKey = await crypto.subtle.importKey('raw', rawKey, 'AES-CTR', false, ['encrypt'])
  const cipher = new Uint8Array(await crypto.subtle.encrypt({ name: 'AES-CTR', counter: iv, length: 128 }, aesKey, json))
  const hmacKey = await crypto.subtle.importKey('raw', rawKey, { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'])
  const sign = new Uint8Array(await crypto.subtle.sign('HMAC', hmacKey, json))

  const jse = new JSEncrypt()
  jse.setPublicKey(publicKey)
  const key = jse.encrypt(toBase64(rawKey))
  if (!key) {
    throw new Error('Unable to encrypt request key')
  }

  const payload = new Uint8Array(iv.length + cipher.length)
  payload.set(iv)
  payload.set(cipher, iv.length)

  return { payload: toBase64(payload), key, sign: toBase64(sign) }
}

// sent again without asking: never tried from the site yet, or failed because of the network, the session or the server
function shouldAutoRetry(run) {
  const status = run.error?.status ?? 0
  return (run.attempts ?? 1) <= 1 || status === 0 || status === 401 || status >= 500
}

export const usePendingRunsStore = defineStore('pendingRuns', () => {
  const runs = ref(readRuns())
  const isSending = ref(false)

  const load = () => {
    runs.value = readRuns()
  }

  // always from the storage: the game writes to it too
  const update = (fn) => {
    writeRuns(fn(readRuns()))
    load()
  }

  const discard = (runId) => {
    update((list) => list.filter((r) => r.run_id !== runId))
  }

  const send = async(run) => {
    // the key changes with each deployment: always the current one
    const { data } = await client.get('/runs/public-key')
    window.Kado.public_key = data.data.public_key
    const body = await encryptRun(run.request, data.data.public_key)
    const res = await client.post(`/runs/${run.run_id}/finish`, body)
    return res.data.data
  }

  // true when the run is on the server
  const retry = async(runId) => {
    const run = readRuns().find((r) => r.run_id === runId)
    if (!run) {
      return true
    }

    try {
      const endRunDetails = await send(run)
      discard(runId)
      window.evts.dispatchEvent(new CustomEvent('gameFinished', { detail: endRunDetails }))
      return true
    } catch(e) {
      const status = e.response?.status ?? 0
      // already finished (a previous sending did reach the server), or a daily game whose period is over
      if (status === 409) {
        discard(runId)
        return true
      }
      update((list) =>
        list.map((r) =>
          r.run_id === runId
            ? {
              ...r,
              attempts: (r.attempts ?? 1) + 1,
              last_attempt_at: new Date().toISOString(),
              error: { status, message: e.response?.data?.message ?? e.message },
            }
            : r,
        ),
      )
      return false
    }
  }

  const retryAll = async({ auto = false } = {}) => {
    if (isSending.value || !useAuthStore().isAuthenticated) {
      return
    }
    isSending.value = true
    try {
      for (const run of readRuns()) {
        if (auto && !shouldAutoRetry(run)) {
          continue
        }
        const sent = await retry(run.run_id)
        // no network: the next ones would fail too
        if (!sent && readRuns().find((r) => r.run_id === run.run_id)?.error?.status === 0) {
          break
        }
      }
    } finally {
      isSending.value = false
    }
  }

  window.evts.addEventListener('runSubmitFailed', load)
  window.addEventListener('storage', (e) => {
    if (e.key === STORAGE_KEY) {
      load()
    }
  })
  window.addEventListener('online', () => retryAll({ auto: true }))

  return {
    runs,
    isSending,
    load,
    discard,
    retry,
    retryAll,
  }
})
