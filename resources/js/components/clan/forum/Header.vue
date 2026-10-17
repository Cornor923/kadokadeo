<script setup>
// the top of the pages of the forum of a clan: the tabs (the forum, back to the clan) and the title, a link to the
// list of the topics from a topic
const props = defineProps({
  clanId: { type: [Number, String], required: true },
  linked: { type: Boolean, default: false },
})

const forumRoute = computed(() => ({ name: 'clans.forum', params: { id: props.clanId } }))
const tabs = computed(() => [
  { label: 'Forum', value: 'forum', route: forumRoute.value },
  { label: 'Clan', value: 'clan', route: { name: 'clans.show', params: { id: props.clanId } } },
])
</script>

<template>
  <NavTabs :items="tabs" :selected-index="0" />
  <h2 class="mb-3">
    <RouterLink v-if="linked" :to="forumRoute">Le forum privé de votre clan</RouterLink>
    <template v-else>Le forum privé de votre clan</template>
  </h2>
</template>
