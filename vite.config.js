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

export default defineConfig({
  plugins: [
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
  publicDir: 'public',
  server: {
    origin: 'http://kadokadeo.localhost/vite',
    cors: true,
  },
})
