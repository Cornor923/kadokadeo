<script setup>
// the text fields of the site: the gradient of the old site, green when focused (the width is given by the parent)
const model = defineModel({ type: [String, Number], default: null })
</script>

<template>
  <input v-model="model"
         class="my-1 box-border border-2 border-l-[7px] border-solid border-kado-cyan-800 bg-[url(/gfx/bgInput.jpg)] bg-repeat-x p-1 text-kado-cyan-700 outline-none focus:bg-[url(/gfx/bgInputFocus.jpg)] focus:text-kado-green-500 karbon:bg-white karbon:bg-[url(/gfx/themes/karbon/inputBg.jpg)] karbon:text-[#466167] karbon:focus:bg-[url(/gfx/themes/karbon/inputBg.jpg)] karbon:focus:text-[#466167]" />
</template>
