<script setup>
// the topics of the forum of a clan, as on the old forum: the "Post-it" first, then the topics grouped by the day of
// their last message (pink rows); a title green when unread, blue when read; the last message and the links to the
// pages of the topic in "Réponses"
const props = defineProps({
  clanId: { type: [Number, String], required: true },
  topics: { type: Array, required: true },
})

const DAYS = ['dimanche', 'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi']
const dayLabel = (date) => `${DAYS[dayjs(date).day()]} ${dayjs(date).format('DD/MM/YYYY')}`

const rows = computed(() => {
  const rows = []
  let group = null
  for (const topic of props.topics) {
    const label = topic.is_pinned ? 'Post-it' : dayLabel(topic.last_message_at)
    if (label !== group) {
      rows.push({ key: `group-${label}`, separator: label })
      group = label
    }
    rows.push({ key: topic.id, topic })
  }
  return rows
})

// the pages of a topic: all of them up to 6, otherwise 1-2-3-...-n-2-n-1-n
const pageLinks = (pages) => {
  if (pages <= 1) {
    return []
  }
  if (pages <= 6) {
    return Array.from({ length: pages }, (_, i) => i + 1)
  }
  return [1, 2, 3, '…', pages - 2, pages - 1, pages]
}
const topicRoute = (topic, page = 1) => ({
  name: 'clans.forum.topic',
  params: { id: props.clanId, topic: topic.id },
  query: page > 1 ? { page } : {},
})
// the day is given by the pink row, except for the "Post-it"
const lastMessageTime = (topic) => dayjs(topic.last_message_at).format(topic.is_pinned ? 'DD/MM à HH:mm' : 'HH:mm')

const headerClasses = 'border border-solid border-kado-green-600 bg-kado-green-500 bg-[url(/assets/img/gfx/gui/base/greenh2_bg.jpg)] bg-[position:-25px_-5px] bg-no-repeat px-2 text-left text-sm font-normal tracking-widest text-kado-green-600'
const greyCellClasses = 'border border-t-0 border-solid border-kado-cyan-750 bg-white bg-[url(/assets/img/gfx/gui/base/greyh2_bg.jpg)] bg-[position:top_right] bg-no-repeat px-2 pb-1 text-kado-slate-600'
</script>

<template>
  <div class="overflow-x-auto">
    <table class="w-full border-collapse text-xs">
      <thead>
        <tr>
          <th :class="headerClasses">Sujet</th>
          <th :class="headerClasses" class="hidden w-32 sm:table-cell">Auteur</th>
          <th :class="headerClasses" class="w-10">Msg</th>
          <th :class="headerClasses" class="w-32">Réponses</th>
        </tr>
      </thead>
      <tbody>
        <tr v-if="!topics.length">
          <td colspan="4" :class="greyCellClasses" class="py-4 text-center italic">Aucun sujet pour le moment.</td>
        </tr>
        <template v-for="row in rows" :key="row.key">
          <tr v-if="row.separator">
            <td colspan="4" class="border border-solid border-kado-pink-400 bg-kado-pink-400 bg-[url(/assets/img/gfx/gui/base/pinkh2_bg.jpg)] bg-[position:-30px_-9px] bg-no-repeat px-1.5 text-right text-xs leading-4 text-kado-pink-400">
              {{ row.separator }}
            </td>
          </tr>
          <tr v-else>
            <td class="border border-t-0 border-solid border-kado-cyan-750 p-0 text-right">
              <RouterLink :to="topicRoute(row.topic)"
                          class="block min-h-6 bg-white bg-[position:top_right] bg-no-repeat py-1 pr-2.5 pl-2 font-bold hover:bg-[url(/assets/img/gfx/gui/base/greyh2_bg.jpg)] hover:no-underline"
                          :class="row.topic.is_unread ? 'bg-[url(/assets/img/gfx/gui/base/greenh2_bg.jpg)]' : 'bg-[url(/assets/img/gfx/gui/base/blueh2_bg.jpg)]'"
                          :title="row.topic.is_unread ? 'Nouveaux messages' : null">
                <span v-if="row.topic.is_locked" title="Sujet verrouillé">🔒 </span>{{ row.topic.title }}
              </RouterLink>
            </td>
            <td :class="greyCellClasses" class="hidden text-left text-sm sm:table-cell">
              <RouterLink v-if="row.topic.author" :to="{ name: 'profile.show', params: { id: row.topic.author.etwin_id } }" class="font-bold">
                {{ row.topic.author.display_name }}
              </RouterLink>
              <span v-else class="italic">Ancien joueur</span>
            </td>
            <td :class="greyCellClasses" class="text-right text-2xs">{{ row.topic.replies_count }}</td>
            <td :class="greyCellClasses" class="text-right text-2xs leading-3">
              <template v-if="row.topic.last_message_user">
                <RouterLink :to="{ name: 'profile.show', params: { id: row.topic.last_message_user.etwin_id } }" class="font-bold">{{ row.topic.last_message_user.display_name }}</RouterLink>
              </template>
              <span v-else class="italic">Ancien joueur</span>
              à {{ lastMessageTime(row.topic) }}
              <div v-if="row.topic.pages > 1">
                <template v-for="(page, index) in pageLinks(row.topic.pages)" :key="`${page}-${index}`">
                  <template v-if="index > 0">-</template>
                  <template v-if="page === '…'">...</template>
                  <RouterLink v-else :to="topicRoute(row.topic, page)" class="font-bold">{{ page }}</RouterLink>
                </template>
              </div>
            </td>
          </tr>
        </template>
      </tbody>
    </table>
  </div>
</template>
