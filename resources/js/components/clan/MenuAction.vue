<script setup>
// a link (to) or a button of the "Actions" menu of the clan
defineProps({
  to: { type: [Object, String], default: null },
})
const emit = defineEmits(['click'])

// the button image stretched as a nine-patch (border-image): the 38px on the left and the 39px on the right are kept,
// the single column of the middle (cut down from the old 155px wide gif) fills the width
const classes = 'mb-0.5 box-border block h-9 w-full cursor-pointer overflow-hidden border-0 [border-image:url(/assets/img/gfx/icons/clanInfo.png)_0_39_0_38_fill_/_0_39px_0_38px] bg-transparent py-0.5 pr-2.5 pl-0.5 text-right font-[inherit] text-sm leading-[30px] text-ellipsis whitespace-nowrap text-kado-blue no-underline hover:[border-image:url(/assets/img/gfx/icons/clanInfo_hover.png)_0_39_0_38_fill_/_0_39px_0_38px] hover:text-kado-green-600'
</script>

<template>
  <li>
    <RouterLink v-if="to" :to="to" :class="classes">
      <slot />
    </RouterLink>
    <button v-else
            type="button"
            :class="classes"
            @click="emit('click')">
      <slot />
    </button>
  </li>
</template>
