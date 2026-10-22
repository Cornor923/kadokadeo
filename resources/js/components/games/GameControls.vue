<script setup>
defineProps({
  game: { type: Object, required: true },
})

const keyMap = {
  mouse: { image: '/gfx/controls/mouseMove.gif', title: 'Souris' },
  mouse1: { image: '/gfx/controls/mouseLeftClic.gif', title: 'Clic gauche' },
  mouse2: { image: '', title: 'Clic droit' },
  space: { image: '/gfx/controls/keySpace.gif', title: 'Espace' },
  enter: { image: '/gfx/controls/key.gif', title: 'Entrée' },
  arrows: { image: '/gfx/controls/keyarrow.gif', title: '4 flèches' },
  arrowup: { image: '/gfx/controls/keyUpArrow.gif', title: 'Flèche haut' },
  arrowdown: { image: '/gfx/controls/keyDownArrow.gif', title: 'Flèche bas' },
  arrowleft: { image: '/gfx/controls/keyLeftArrow.gif', title: 'Flèche gauche' },
  arrowright: { image: '/gfx/controls/keyRightArrow.gif', title: 'Flèche droite' },
  shift: { image: '/gfx/controls/keyshift.gif', title: 'Shift' },
  ctrl: { image: '/gfx/controls/keyctrl.gif', title: 'Ctrl' },
  control: { image: '/gfx/controls/keyctrl.gif', title: 'Ctrl' },
  esc: { image: '/gfx/controls/keyesc.gif', title: 'Echap' },
  escape: { image: '/gfx/controls/keyesc.gif', title: 'Echap' },
  p: { image: '/gfx/controls/keyp.gif', title: 'P' },
}

function getKeyView(key) {
  const mapped = keyMap[key]
  if (mapped) {
    return {
      image: mapped.image,
      title: mapped.title,
      text: mapped.title,
    }
  }

  return {
    image: '',
    title: key?.toUpperCase?.() || key,
    text: key?.toUpperCase?.() || key,
  }
}
</script>

<template>
  <KadoTable borderless
             plain-header
             rows="none"
             class="mx-auto my-2 w-71">
    <thead>
      <tr>
        <th scope="col" class="w-17.5">Commande</th>
        <th scope="col">Fonction</th>
      </tr>
    </thead>
    <tbody>
      <tr v-for="control in game.controls" :key="control.id">
        <td>
          <template v-for="key in control.keys" :key="key">
            <img
              v-if="getKeyView(key).image"
              :src="getKeyView(key).image"
              :title="getKeyView(key).title"
              :alt="getKeyView(key).title"
              class="inline-block mr-1"
            />
            <span v-else :title="getKeyView(key).title" class="inline-block mr-1">
              {{ getKeyView(key).text }}
            </span>
          </template>
        </td>
        <td>{{ control.description }}</td>
      </tr>
    </tbody>
  </KadoTable>
</template>
