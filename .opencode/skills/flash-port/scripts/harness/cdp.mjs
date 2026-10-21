// Minimal Chrome DevTools Protocol driver for a headless Chromium browser (Chrome, Edge, Chromium).
// No dependency: needs the global WebSocket of Node 22+ (Node 20/21: run with --experimental-websocket).
//   env BROWSER: path of the browser (default: Chrome on macOS, Edge on Windows, google-chrome / chromium on Linux)
//   env GPU=1: real GPU (otherwise SwiftShader, a software renderer: fine for logic, wrong for performance)
import { spawn } from 'node:child_process'
import { writeFileSync, mkdirSync, existsSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

const CANDIDATES = {
  darwin: ['/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge', '/Applications/Chromium.app/Contents/MacOS/Chromium'],
  win32: ['C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', 'C:/Program Files/Google/Chrome/Application/chrome.exe'],
  linux: ['/usr/bin/google-chrome', '/usr/bin/chromium', '/usr/bin/chromium-browser', '/usr/bin/microsoft-edge'],
}
const BROWSER = process.env.BROWSER || (CANDIDATES[process.platform] || []).find((p) => existsSync(p))
const GPU_FLAGS = { darwin: ['--use-angle=metal'], win32: ['--use-angle=d3d11'], linux: ['--use-angle=gl'] }[process.platform] || []
const sleep = (ms) => new Promise((r) => setTimeout(r, ms))

export async function launch(port = 9333) {
  if (!BROWSER) throw new Error('no Chromium browser found: set BROWSER=<path of chrome / msedge / chromium>')
  if (typeof WebSocket === 'undefined') throw new Error('no global WebSocket: use Node 22+ (or node --experimental-websocket)')
  // one profile per debugging port: several scripts can run in parallel on different ports
  const profile = join(tmpdir(), 'kk-cdp-profile-' + port)
  mkdirSync(profile, { recursive: true })
  const proc = spawn(BROWSER, [
    '--headless=new', `--remote-debugging-port=${port}`, '--user-data-dir=' + profile,
    '--window-size=640,720', '--no-first-run', '--no-default-browser-check', '--disable-extensions',
    // (no dialog of the macOS keychain for the new profile)
    '--use-mock-keychain', '--password-store=basic',
    ...(process.env.GPU ? [...GPU_FLAGS, '--enable-gpu', '--ignore-gpu-blocklist'] : ['--enable-unsafe-swiftshader', '--use-angle=swiftshader']),
    // (the sounds of the games play, unheard: Hammerfest, Rock Faller)
    '--autoplay-policy=no-user-gesture-required', '--mute-audio',
    'about:blank',
  ], { stdio: 'ignore' })
  let targets
  for (let i = 0; i < 100; i++) {
    try {
      targets = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json()
      if (targets.find((t) => t.type === 'page')) break
    } catch {}
    await sleep(200)
  }
  const page = targets.find((t) => t.type === 'page')
  const ws = new WebSocket(page.webSocketDebuggerUrl)
  await new Promise((r) => ws.addEventListener('open', r, { once: true }))
  let id = 0
  const pending = new Map()
  const listeners = []
  ws.addEventListener('message', (ev) => {
    const msg = JSON.parse(ev.data)
    if (msg.id && pending.has(msg.id)) {
      const { resolve, reject } = pending.get(msg.id)
      pending.delete(msg.id)
      msg.error ? reject(new Error(JSON.stringify(msg.error))) : resolve(msg.result)
    } else if (msg.method) {
      for (const l of listeners) l(msg)
    }
  })
  const send = (method, params = {}, timeout = 10000) => new Promise((resolve, reject) => {
    const mid = ++id
    const timer = setTimeout(() => { pending.delete(mid); reject(new Error('CDP timeout ' + method)) }, timeout)
    pending.set(mid, { resolve: (v) => { clearTimeout(timer); resolve(v) }, reject: (e) => { clearTimeout(timer); reject(e) } })
    ws.send(JSON.stringify({ id: mid, method, params }))
  })
  const consoleLines = []
  listeners.push((m) => {
    if (m.method === 'Runtime.consoleAPICalled') {
      consoleLines.push(m.params.type + ': ' + m.params.args.map((a) => a.value ?? a.description ?? '').join(' '))
    } else if (m.method === 'Runtime.exceptionThrown') {
      consoleLines.push('EXCEPTION: ' + JSON.stringify(m.params.exceptionDetails).slice(0, 800))
    }
  })
  await send('Runtime.enable')
  await send('Page.enable')
  await send('Emulation.setDeviceMetricsOverride', { width: 640, height: 720, deviceScaleFactor: 1, mobile: false })

  const b = {
    send, consoleLines, sleep,
    async goto(url) {
      await send('Page.navigate', { url })
      await sleep(2000)
      // headless Chrome on macOS hides the page at the first input event (visibilityState "hidden": no more
      // requestAnimationFrame, the game stops) unless the page was brought to the front
      await send('Page.bringToFront')
    },
    async eval(expr) {
      const r = await send('Runtime.evaluate', { expression: expr, returnByValue: true, awaitPromise: true })
      if (r.exceptionDetails) throw new Error('eval failed: ' + JSON.stringify(r.exceptionDetails).slice(0, 500))
      return r.result.value
    },
    async waitFor(expr, timeout = 15000) {
      const t0 = Date.now()
      while (Date.now() - t0 < timeout) {
        try { if (await b.eval(expr)) return true } catch {}
        await sleep(100)
      }
      throw new Error('timeout waiting for ' + expr)
    },
    async mouse(type, x, y, button = 'left') {
      await send('Input.dispatchMouseEvent', { type, x, y, button, buttons: type === 'mousePressed' ? 1 : 0, clickCount: 1, pointerType: 'mouse' })
    },
    async move(x, y) { await send('Input.dispatchMouseEvent', { type: 'mouseMoved', x, y, button: 'none', pointerType: 'mouse' }) },
    async click(x, y, hold = 80) {
      await b.move(x, y)
      await sleep(40)
      await b.mouse('mousePressed', x, y)
      await sleep(hold)
      await b.mouse('mouseReleased', x, y)
    },
    async screenshot(path, clip) {
      const r = await send('Page.captureScreenshot', { format: 'png', ...(clip ? { clip: { ...clip, scale: 1 } } : {}) })
      writeFileSync(path, Buffer.from(r.data, 'base64'))
    },
    async close() {
      try { await send('Browser.close') } catch {}
      ws.close()
      proc.kill()
    },
  }
  return b
}
