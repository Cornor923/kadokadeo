<script setup>
// as the text fields, the gradient stretched to the height of the text area
const model = defineModel({ type: String, default: '' })
</script>

<template>
  <textarea v-model="model"
            class="box-border w-full border-2 border-l-[7px] border-solid border-kado-cyan-800 bg-white bg-[url(/gfx/bgInput.jpg)] bg-[length:100%_100%] bg-no-repeat p-1 text-kado-cyan-700 outline-none focus:bg-[url(/gfx/bgInputFocus.jpg)] focus:text-kado-green-500 karbon:bg-[url(/gfx/themes/karbon/inputBg.jpg)] karbon:text-[#466167] karbon:focus:bg-[url(/gfx/themes/karbon/inputBg.jpg)] karbon:focus:text-[#466167]"></textarea>
</template>
