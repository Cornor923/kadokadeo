<script setup>
import { SMILEYS, smileyUrl } from '@/marktwin/grammar'

// the text area of a message of a forum, written in Marktwin: the box of the smileys of the old forum, and the preview
// rendered here (the same renderer as the messages shown)
const model = defineModel({ type: String, default: '' })
const props = defineProps({
  // (of the text area, for its label)
  id: { type: String, default: null },
  maxlength: { type: Number, default: 10000 },
  rows: { type: Number, default: 8 },
  // the grammar, the icons of the box ([{key, src}]) and their images, when not the ones of the site (the forum of
  // Eternaltwin serves its own)
  grammar: { type: Object, default: null },
  icons: { type: Array, default: null },
  iconUrl: { type: Function, default: null },
})
const boxIcons = computed(() => props.icons ?? SMILEYS.map((smiley) => ({ key: smiley.key, src: smileyUrl(smiley) })))

const textarea = ref(null)
const preview = ref(false)

// the smiley at the cursor (or in place of the selection), then the cursor after it
const insertSmiley = (smiley) => {
  const element = textarea.value?.$el
  const code = `:${smiley.key}:`
  const start = element?.selectionStart ?? model.value.length
  const end = element?.selectionEnd ?? model.value.length
  model.value = model.value.slice(0, start) + code + model.value.slice(end)
  preview.value = false
  nextTick(() => {
    element?.focus()
    element?.setSelectionRange(start + code.length, start + code.length)
  })
}
</script>

<template>
  <div class="space-y-1">
    <div class="flex flex-col gap-2 sm:flex-row sm:items-start">
      <div class="min-w-0 flex-1">
        <div v-if="preview" class="min-h-32 border-2 border-l-[7px] border-solid border-kado-cyan-800 bg-white p-2">
          <MarktwinContent v-if="model.trim()"
                           :text="model"
                           :grammar="grammar"
                           :icon-url="iconUrl" />
          <p v-else class="m-0 italic text-kado-slate-400">Rien à prévisualiser.</p>
        </div>
        <FormTextarea v-else
                      :id="id"
                      ref="textarea"
                      v-model="model"
                      :rows="rows"
                      :maxlength="maxlength" />
      </div>
      <ul class="m-0 grid max-h-40 w-fit shrink-0 list-none grid-cols-8 content-start gap-1 overflow-y-auto border-2 border-l-[10px] border-solid border-kado-orange bg-kado-orange-50 p-1 sm:grid-cols-5">
        <li v-for="icon in boxIcons" :key="icon.key">
          <button type="button"
                  class="block cursor-pointer border-0 bg-transparent p-0.5 hover:bg-white"
                  :title="`:${icon.key}:`"
                  @click="insertSmiley(icon)">
            <img :src="icon.src" :alt="`:${icon.key}:`" />
          </button>
        </li>
      </ul>
    </div>
    <div class="flex flex-wrap items-center justify-between gap-2 text-2xs text-kado-slate-400">
      <span>**gras** _italique_ __souligné__ ~~barré~~ ||spoiler|| [lien](https://…) [quote=pseudo]…[/quote]</span>
      <FormButton size="sm" @click="preview = !preview">{{ preview ? 'Modifier' : 'Aperçu' }}</FormButton>
    </div>
  </div>
</template>
