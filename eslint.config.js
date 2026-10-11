import js from '@eslint/js'
import stylistic from '@stylistic/eslint-plugin'
import skipFormatting from '@vue/eslint-config-prettier/skip-formatting'
import { defineConfig, globalIgnores } from 'eslint/config'
import simpleImportSort from 'eslint-plugin-simple-import-sort'
import unusedImports from 'eslint-plugin-unused-imports'
import pluginVue from 'eslint-plugin-vue'
import globals from 'globals'

import autoImportGlobals from './.eslintrc-auto-import.mjs'

export default defineConfig([
  globalIgnores(['**/dist/**', '**/coverage/**', 'resources/js/games/**']),

  // Base JS rules
  js.configs.recommended,

  // Vue rules
  ...pluginVue.configs['flat/essential'],

  // Désactive les règles de formatting en conflit (via Prettier)
  skipFormatting,

  {
    files: ['resources/js/**/*.{js,jsx,mjs,ts,tsx,vue}', '*.{js,ts,json}'],
    languageOptions: {
      parserOptions: {
        ecmaVersion: 'latest',
        sourceType: 'module',
      },
      globals: {
        ...globals.browser,
        PIXI: 'readonly',
        ...autoImportGlobals.globals,
      },
    },
    plugins: {
      '@stylistic': stylistic,
      'unused-imports': unusedImports,
      'simple-import-sort': simpleImportSort,
    },
    rules: {
      // tri imports
      'simple-import-sort/imports': 'error',
      'simple-import-sort/exports': 'error',

      // unused
      'unused-imports/no-unused-imports': 'error',

      // syntaxe JS
      // indent: ['error', 2],
      quotes: ['error', 'single'],
      semi: ['error', 'never'],
      'comma-dangle': ['error', 'always-multiline'],

      // Vue
      'vue/html-indent': ['error', 2],
      'vue/max-attributes-per-line': [
        'error',
        {
          singleline: 3,
          multiline: 1,
        },
      ],
      'vue/no-v-html': 'off',
      'vue/multi-word-component-names': 'off',

      // stylistic
      '@stylistic/indent': ['error', 2],
      '@stylistic/semi': ['error', 'never'],
      '@stylistic/quotes': ['error', 'single'],
      '@stylistic/brace-style': ['error', '1tbs', { allowSingleLine: true }],
      '@stylistic/space-before-function-paren': ['error', 'never'],
      '@stylistic/object-curly-spacing': ['error', 'always'],
      '@stylistic/no-mixed-spaces-and-tabs': ['error'],
      '@stylistic/no-trailing-spaces': ['error'],
      '@stylistic/arrow-spacing': ['error'],
      '@stylistic/space-before-blocks': ['error'],
    },
  },

  // Node scripts (run on the server)
  {
    files: ['resources/js/replay-verifier/**/*.mjs'],
    languageOptions: {
      globals: globals.node,
    },
  },
])
