import { readFileSync, writeFileSync } from 'node:fs'
import { fileURLToPath, URL } from 'node:url'

import tailwindcss from '@tailwindcss/vite'
import vue from '@vitejs/plugin-vue'
import laravel from 'laravel-vite-plugin'
import { resolve } from 'path'
import AutoImport from 'unplugin-auto-import/vite'
import Components from 'unplugin-vue-components/vite'
import { defineConfig } from 'vite'
import vueDevTools from 'vite-plugin-vue-devtools'
import wasm from 'vite-plugin-wasm'
import svgLoader from 'vite-svg-loader'

// the version of the site (package.json), shown in the bar of the top (nav/TopBar.vue)
const { version } = JSON.parse(readFileSync(new URL('./package.json', import.meta.url), 'utf8'))

// The service worker must be at the root of the site; a new content each time: the browsers see a new version. Under the
// dev server only with VITE_PWA_DEV=true in .env (written again when it is edited; nginx serves public/).
const writeServiceWorker = () => writeFileSync('public/sw.js', `// build ${Date.now()}\n${readFileSync('resources/js/sw.js', 'utf8')}`)
let serviceWorkerOn = false
const serviceWorker = {
  name: 'kado-service-worker',
  configResolved(config) {
    serviceWorkerOn = config.command === 'build' || config.env.VITE_PWA_DEV === 'true'
  },
  buildStart() {
    if (serviceWorkerOn) {
      writeServiceWorker()
    }
  },
  handleHotUpdate({ file }) {
    if (serviceWorkerOn && file.endsWith('resources/js/sw.js')) {
      writeServiceWorker()
      return []
    }
  },
}

export default defineConfig({
  plugins: [
    serviceWorker,
    laravel({
      input: ['resources/css/app.css', 'resources/js/main.js', 'resources/js/replay-player.js', 'resources/js/admin/marktwin.js'],
      refresh: true,
    }),
    tailwindcss(),
    vue(),
    vueDevTools(),
    svgLoader({
      svgo: false,
    }),
    // the WebAssembly of @eternaltwin/marktwin (the messages of the forums), imported as an ES module
    wasm(),
    AutoImport({
      include: [
        /\.[tj]s$/, // .ts, .js
        /\.vue$/,
        /\.vue\?vue/, // .vue
      ],
      imports: [
        // presets
        'vue',
        'vue-router',
        {
          'dayjs': [
            ['default', 'dayjs'],
          ],
        },
      ],

      // Auto import for module exports under directories
      // by default it only scan one level of modules under the directory
      dirs: [
        './resources/js/stores',
        './resources/js/composables',
      ],
      dts: false,
      viteOptimizeDeps: true,
      injectAtEnd: true,
      vueTemplate: true,
      eslintrc: {
        enabled: true,
        filepath: './.eslintrc-auto-import.mjs',
        globalsPropValue: true,
      },
    }),
    Components({
      dirs: ['resources/js/components'],
      extensions: ['vue'],
      deep: true,
      dts: false,
      directoryAsNamespace: true,
      collapseSamePrefixes: true,
    }),
  ],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./resources/js', import.meta.url)),
      '@svg': fileURLToPath(new URL('./resources/svg', import.meta.url)),
      public: resolve('./public'),
    },
  },
  // (esbuild can't pre-bundle its .wasm import: vite-plugin-wasm loads it)
  optimizeDeps: {
    exclude: ['@eternaltwin/marktwin'],
  },
  define: {
    'import.meta.env.VITE_APP_VERSION': JSON.stringify(version),
  },
  publicDir: 'public',
  server: {
    origin: 'http://kadokadeo.localhost/vite',
    cors: true,
  },
})
