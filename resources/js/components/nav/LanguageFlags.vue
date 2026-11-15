<script setup>
import { t } from '@/i18n'
import { chooseLocale, languageName, pageLocale, siteLanguages } from '@/i18n/locale'
import { reloadPage } from '@/i18n/reload'

const flags = siteLanguages().map((locale) => ({ locale, src: `/gfx/flags/${locale}.gif` }))

const authStore = useAuthStore()
const { error, saveLocale } = useAccount()
const toastStore = useToastStore()

const isShown = computed(() => window.Kado?.i18n_enabled && authStore.isAuthenticated)
const isLanguageOfThePage = (flag) => flag.locale === pageLocale()

function choose(flag) {
  if (!isLanguageOfThePage(flag)) {
    chooseLocale(flag.locale, { save: saveLocale, reload: reloadPage }).catch(tellWhyTheLanguageWasRefused)
  }
}

// the flags have no place for an error under them, unlike the choice of the account page
function tellWhyTheLanguageWasRefused() {
  toastStore.show({ title: t('language.title'), text: error.value })
}
</script>

<template>
  <ul v-if="isShown" class="flex w-max flex-col gap-0.5">
    <li v-for="flag in flags" :key="flag.locale">
      <button type="button"
              class="block"
              :class="isLanguageOfThePage(flag) ? 'cursor-default' : 'cursor-pointer opacity-60 hover:opacity-100'"
              :title="languageName(flag.locale)"
              :aria-pressed="isLanguageOfThePage(flag)"
              @click="choose(flag)">
        <img :src="flag.src"
             :alt="languageName(flag.locale)"
             width="29"
             height="22" />
      </button>
    </li>
  </ul>
</template>
