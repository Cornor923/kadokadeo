<script setup>
// the buttons of the site: green or pink, small (in a table), medium, or large (as the submit buttons of the forms)
const props = defineProps({
  variant: { type: String, default: 'green', validator: (value) => ['green', 'pink'].includes(value) },
  size: { type: String, default: 'md', validator: (value) => ['sm', 'md', 'lg'].includes(value) },
  type: { type: String, default: 'button' },
})

const variants = {
  green: {
    sm: 'border-kado-green-600 text-kado-green-600 bg-[url(/gfx/bgFormButtonFill.jpg)] hover:bg-[url(/gfx/bgFormButtonFillHover.jpg)]',
    md: 'border-kado-green-600 text-kado-green-600 bg-[url(/gfx/bgFormButtonFill.jpg)] hover:bg-[url(/gfx/bgFormButtonFillHover.jpg)]',
    lg: 'border-kado-green-600 text-kado-green-600 bg-kado-green-100 bg-[url(/gfx/bgFormButtonLeft.jpg),url(/gfx/bgFormButtonFill.jpg)] hover:bg-[url(/gfx/bgFormButtonLeftHover.jpg),url(/gfx/bgFormButtonFillHover.jpg)]',
  },
  pink: {
    sm: 'border-kado-pink-600 text-kado-pink-600 bg-[url(/gfx/bgFormButtonPinkFill.jpg)] hover:bg-[url(/gfx/bgFormButtonPinkFillHover.jpg)]',
    md: 'border-kado-pink-600 text-kado-pink-600 bg-[url(/gfx/bgFormButtonPinkFill.jpg)] hover:bg-[url(/gfx/bgFormButtonPinkFillHover.jpg)]',
    lg: 'border-kado-pink-600 text-kado-pink-600 bg-kado-pink-50 bg-[url(/gfx/bgFormButtonPinkLeft.jpg),url(/gfx/bgFormButtonPinkFill.jpg)] hover:bg-[url(/gfx/bgFormButtonPinkLeftHover.jpg),url(/gfx/bgFormButtonPinkFillHover.jpg)]',
  },
}
const sizes = {
  sm: 'h-[18px] px-1.5 text-[11px] leading-4 bg-center bg-repeat-x',
  md: 'px-2 py-px bg-repeat-x',
  lg: 'h-8 min-w-20 pr-2.5 pl-[15px] text-base [background-position:left,0_0] [background-repeat:no-repeat,repeat-x]',
}
const classes = computed(() => [variants[props.variant][props.size], sizes[props.size]])
</script>

<template>
  <button :type="type"
          class="cursor-pointer border border-solid font-bold font-[inherit] whitespace-nowrap disabled:cursor-not-allowed disabled:grayscale"
          :class="classes">
    <slot />
  </button>
</template>
