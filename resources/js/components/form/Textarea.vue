<script setup>
// as the text fields, the gradient stretched to the height of the text area
const model = defineModel({ type: String, default: '' })
</script>

<template>
  <textarea v-model="model"
            class="box-border w-full border-2 border-l-[7px] border-solid border-kado-teal-500 bg-white bg-[url(/gfx/bgInput.jpg)] bg-[length:100%_100%] bg-no-repeat p-1 text-kado-blue-600 outline-none focus:bg-[url(/gfx/bgInputFocus.jpg)] focus:text-kado-green-500 karbon:bg-[url(/gfx/themes/karbon/inputBg.jpg)] karbon:text-kado-slate-700 karbon:focus:bg-[url(/gfx/themes/karbon/inputBg.jpg)] karbon:focus:text-kado-slate-700"></textarea>
</template>
