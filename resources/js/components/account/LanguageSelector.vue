<script setup>
// the choice of the language of an account: only shown when the languages are on (App\Settings\SiteSettings::$i18n_enabled)
import { chooseLocale, languageName, siteLanguages } from '@/i18n/locale'
import { reloadPage } from '@/i18n/reload'

const authStore = useAuthStore()
const { error, saveLocale } = useAccount()

const isShown = window.Kado.i18n_enabled

// a refused choice: useAccount shows its error, the page stays as it is
const choice = computed({
  get: () => authStore.user?.locale ?? 'auto',
  set: (locale) => chooseLocale(locale, { save: saveLocale, reload: reloadPage }).catch(() => {}),
})
</script>

<template>
  <div v-if="isShown">
    <label>
      {{ $t('language.title') }}
      <FormSelect v-model="choice">
        <option value="auto">{{ $t('language.auto') }}</option>
        <option v-for="language in siteLanguages()" :key="language" :value="language">{{ languageName(language) }}</option>
      </FormSelect>
    </label>
    <MessageError v-if="error">{{ error }}</MessageError>
  </div>
</template>
