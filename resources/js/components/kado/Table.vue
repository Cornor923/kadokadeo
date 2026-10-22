<script setup>
// a table of KadoKado (.kado-table in app.css): borders, gradient headers, rows blue and white in turn; the classes
// given to it or to its cells win over these styles
const props = defineProps({
  // without its borders nor the ones of its cells (the tables of the panel of a game)
  borderless: Boolean,
  // the headers without their gradient
  plainHeader: Boolean,
  // the background of the rows: blue and white in turn, white, none
  rows: { type: String, default: 'zebra', validator: (rows) => ['zebra', 'white', 'none'].includes(rows) },
})
</script>

<template>
  <table
    class="kado-table"
    :class="{
      'kado-table-borderless': props.borderless,
      'kado-table-plain-header': props.plainHeader,
      'kado-table-rows-white': props.rows === 'white',
      'kado-table-rows-none': props.rows === 'none',
    }"
  >
    <slot />
  </table>
</template>
