// Tells whether the replay verifier can run on this server (admin page App\Filament\Pages\ReplayVerifierDashboard):
// the Node, the browser found (downloaded with --install when there is none), its missing system libraries, and a
// start of it with WebGL and fonts (PIXI needs both: without any font, measuring a text throws).
//   usage: node check.mjs [--install]
//   output (stdout, one JSON line)
//   env: BROWSER, KADO_VERIFIER_CACHE, KADO_VERIFIER_TIMEOUT (see verify.mjs)
import { userInfo } from 'node:os'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

import { findBrowser, missingLibraries } from './browser.mjs'
import { deadline, launch } from './cdp.mjs'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../../..')
const CACHE = process.env.KADO_VERIFIER_CACHE || join(ROOT, 'storage/app/replay-verifier')

const report = {
  node: process.version,
  platform: `${process.platform} ${process.arch}`,
  user: (() => { try { return userInfo().username } catch { return null } })(),
  browser: null,
  missingLibraries: null,
  launch: null,
}
const message = (e) => String(e?.message || e).slice(0, 1000)
deadline((seconds) => ({ ...report, error: `the check took more than ${seconds} s` }))

try {
  report.browser = await findBrowser({ cacheDir: join(CACHE, 'browser'), install: process.argv.includes('--install') })
  report.missingLibraries = missingLibraries(report.browser.path)
} catch(e) {
  report.browser = { error: message(e) }
}

if (report.browser.path) {
  let b = null
  try {
    b = await launch(report.browser.path)
    report.launch = {
      ok: true,
      version: await b.eval('navigator.userAgent'),
      webgl: await b.eval(`(() => {
        const gl = document.createElement('canvas').getContext('webgl')
        if (!gl) return null
        const info = gl.getExtension('WEBGL_debug_renderer_info')
        return gl.getParameter(info ? info.UNMASKED_RENDERER_WEBGL : gl.RENDERER)
      })()`),
      // the width of a text in the default font: 0 without any font on the system
      fonts: await b.eval(`(() => {
        const ctx = document.createElement('canvas').getContext('2d')
        ctx.font = '20px sans-serif'
        return ctx.measureText('KadoKado').width > 0
      })()`),
    }
  } catch(e) {
    report.launch = { ok: false, error: message(e) }
  } finally {
    await b?.close()
  }
}

console.log(JSON.stringify(report))
process.exit(0)
