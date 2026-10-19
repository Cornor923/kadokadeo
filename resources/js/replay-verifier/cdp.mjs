// Minimal Chrome DevTools Protocol driver for a headless Chromium (no dependency: global WebSocket of Node 22+).
// Adapted from .opencode/skills/flash-port/scripts/harness/cdp.mjs for the replay verifier: a free debugging port and
// a temporary profile per run (several verifications can run at the same time). The browser: browser.mjs.
import { spawn } from 'node:child_process'
import { mkdtempSync, readFileSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

const sleep = (ms) => new Promise((r) => setTimeout(r, ms))

// the browsers still open: killed when this process ends in any way (an error, process.exit, the timeout of
// App\Services\ReplayVerifier...). Left alone, a browser outlives it with the game running (100% of a CPU)
const open = new Set()
process.on('exit', () => { for (const kill of open) kill() })
for (const signal of ['SIGTERM', 'SIGINT', 'SIGHUP']) {
  process.on(signal, () => process.exit(1))
}

// a timeout for the whole script (env KADO_VERIFIER_TIMEOUT, seconds): it prints its result (one JSON line) and quits
export function deadline(result) {
  const seconds = +process.env.KADO_VERIFIER_TIMEOUT
  if (!(seconds > 0)) return
  setTimeout(() => {
    console.log(JSON.stringify(result(seconds)))
    process.exit(0)
  }, seconds * 1000).unref()
}

export async function launch(browser) {
  if (typeof WebSocket === 'undefined') throw new Error('no global WebSocket: Node 22+ is needed')

  // in the command line of all the processes of the browser: php artisan kado:replay-verifier:reap finds them by it
  const profile = mkdtempSync(join(tmpdir(), 'kado-verifier-'))
  const proc = spawn(browser, [
    '--headless=new', '--remote-debugging-port=0', '--user-data-dir=' + profile,
    '--no-first-run', '--no-default-browser-check', '--disable-extensions', '--mute-audio',
    // no crash handler: it detaches itself from Chrome (left to PID 1 in a container)
    '--disable-breakpad', '--disable-crash-reporter',
    '--enable-unsafe-swiftshader', '--use-angle=swiftshader',
    // in a container: no sandbox (it needs the user namespaces, and can't run as root), small /dev/shm, and no zygote
    // (its processes outlive Chrome, left to PID 1). On any Linux server: a container is not always told by
    // /.dockerenv (Kubernetes, Podman...), and the page only runs the bundles of the site
    ...(process.platform === 'linux' ? ['--no-sandbox', '--disable-dev-shm-usage', '--no-zygote'] : []),
    'about:blank',
  ], {
    // Chrome writes in HOME (the worker of the queue may run with the HOME of another user): its temporary profile
    env: { ...process.env, HOME: profile },
    stdio: ['ignore', 'ignore', 'pipe'],
    // a process group of its own: killed with all its processes (renderer, GPU...)
    detached: process.platform !== 'win32',
  })
  const kill = () => {
    try { process.kill(process.platform === 'win32' ? proc.pid : -proc.pid, 'SIGKILL') } catch { /* already gone */ }
  }
  open.add(kill)
  // the end of its error output: why it did not start
  let stderr = ''
  proc.stderr.on('data', (chunk) => { stderr = (stderr + chunk).slice(-2000) })
  const exited = new Promise((resolve) => proc.once('exit', resolve))
  // asked to quit first: it ends its own child processes (killed, they would be left to PID 1 of a container)
  const cleanup = async(send) => {
    if (send && proc.exitCode === null) {
      try { await send('Browser.close', {}, 3000) } catch { /* already quitting */ }
      await Promise.race([exited, sleep(3000)])
    }
    // what is left of it (its processes do not always end with it)
    kill()
    open.delete(kill)
    try { rmSync(profile, { recursive: true, force: true }) } catch { /* already gone */ }
  }

  try {
    // the port chosen by Chrome is written in its profile
    let port = null
    for (let i = 0; i < 150 && !port; i++) {
      try { port = +readFileSync(join(profile, 'DevToolsActivePort'), 'utf8').split('\n')[0] } catch { /* not written yet */ }
      if (!port) await sleep(100)
    }
    if (!port) throw new Error('the browser did not start: ' + (stderr.trim().split('\n').pop() || `exit code ${proc.exitCode}`))
    let page = null
    for (let i = 0; i < 100 && !page; i++) {
      try { page = (await (await fetch(`http://127.0.0.1:${port}/json/list`)).json()).find((t) => t.type === 'page') } catch { /* not ready */ }
      if (!page) await sleep(100)
    }
    if (!page) throw new Error('no page in the browser')

    const ws = new WebSocket(page.webSocketDebuggerUrl)
    await new Promise((resolve, reject) => {
      ws.addEventListener('open', resolve, { once: true })
      ws.addEventListener('error', reject, { once: true })
    })
    let id = 0
    const pending = new Map()
    const consoleLines = []
    ws.addEventListener('message', (ev) => {
      const msg = JSON.parse(ev.data)
      if (msg.id && pending.has(msg.id)) {
        const { resolve, reject } = pending.get(msg.id)
        pending.delete(msg.id)
        msg.error ? reject(new Error(JSON.stringify(msg.error))) : resolve(msg.result)
      } else if (msg.method === 'Runtime.exceptionThrown') {
        consoleLines.push('EXCEPTION: ' + JSON.stringify(msg.params.exceptionDetails).slice(0, 500))
      }
    })
    const send = (method, params = {}, timeout = 60000) => new Promise((resolve, reject) => {
      const mid = ++id
      const timer = setTimeout(() => { pending.delete(mid); reject(new Error('CDP timeout ' + method)) }, timeout)
      pending.set(mid, { resolve: (v) => { clearTimeout(timer); resolve(v) }, reject: (e) => { clearTimeout(timer); reject(e) } })
      ws.send(JSON.stringify({ id: mid, method, params }))
    })
    await send('Runtime.enable')
    await send('Page.enable')

    const b = {
      consoleLines,
      async goto(url) {
        await send('Page.navigate', { url })
        await send('Page.bringToFront')
      },
      async eval(expr) {
        const r = await send('Runtime.evaluate', { expression: expr, returnByValue: true, awaitPromise: true })
        if (r.exceptionDetails) throw new Error('eval failed: ' + JSON.stringify(r.exceptionDetails).slice(0, 500))
        return r.result.value
      },
      async waitFor(expr, timeout) {
        const t0 = Date.now()
        while (Date.now() - t0 < timeout) {
          try { if (await b.eval(expr)) return } catch { /* page not ready */ }
          await sleep(100)
        }
        throw new Error('timeout waiting for ' + expr)
      },
      async close() {
        await cleanup(send)
        try { ws.close() } catch { /* already closed */ }
      },
    }
    return b
  } catch(e) {
    await cleanup(null)
    throw e
  }
}
