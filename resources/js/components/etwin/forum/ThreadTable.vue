<script setup>
// the threads of a section of the forum, as on the forum of Twinoid: the pinned ones ("Post-It") first, then the others
// grouped by the day of their last message; an unread thread in bold, a read one in italic
const props = defineProps({
  threads: { type: Array, required: true },
})

const day = (iso) => new Date(iso).toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' })
const rows = computed(() => {
  const rows = []
  let group = null
  for (const thread of props.threads) {
    const label = thread.is_pinned ? 'Post-It' : `Le ${day(thread.last_post?.ctime ?? thread.ctime)}`
    if (label !== group) {
      rows.push({ key: `group-${label}`, separator: label })
      group = label
    }
    rows.push({ key: thread.id, thread })
  }
  return rows
})
const cellClasses = (thread) => [
  'border-0 border-b border-solid border-white/15 px-1 py-1 text-left text-white',
  thread.is_pinned ? 'bg-kado-slate-600' : 'bg-kado-slate-450',
  thread.self?.is_unread ? 'font-bold' : 'italic',
]
</script>

<template>
  <!-- (the tables of the site have borders and gradient headers: not these ones) -->
  <table class="mb-4 w-full border-collapse border-0 text-xs [&_th]:border-0 [&_th]:bg-none [&_th]:px-1 [&_th]:text-left [&_th]:font-normal">
    <thead>
      <tr class="text-2xs text-kado-blue">
        <th class="w-5"></th>
        <th>Sujets</th>
        <th class="w-10 text-center!">Rép.</th>
        <th class="w-28">Dernier</th>
      </tr>
    </thead>
    <tbody>
      <tr v-if="!threads.length">
        <td colspan="4" class="border-0 bg-kado-slate-450 p-3 text-center text-white italic">Aucun sujet pour le moment.</td>
      </tr>
      <template v-for="row in rows" :key="row.key">
        <tr v-if="row.separator">
          <td colspan="4" class="border-0 bg-kado-slate-600 py-0.5 pl-5 text-left text-2xs font-bold text-white [font-variant:small-caps]">{{ row.separator }}</td>
        </tr>
        <tr v-else class="cursor-pointer hover:shadow-[inset_0_0_2px_rgba(0,0,0,0.4)]" :class="row.thread.self?.is_unread ? '' : 'opacity-75'">
          <td :class="cellClasses(row.thread)" class="text-center!">
            <img v-if="row.thread.is_locked"
                 src="/gfx/forum/twinoid/lock.png"
                 alt="Verrouillé"
                 title="Sujet verrouillé" />
            <img v-else-if="row.thread.has_admin_announcement"
                 src="/gfx/forum/twinoid/announce.png"
                 alt="Annonce"
                 title="Annonce" />
          </td>
          <td :class="cellClasses(row.thread)">
            <RouterLink :to="{ name: 'forum.thread', params: { thread: row.thread.id } }" class="block text-sm text-white no-underline hover:text-white hover:no-underline">
              {{ row.thread.title }}
            </RouterLink>
          </td>
          <td :class="cellClasses(row.thread)" class="text-center! text-base font-bold opacity-80">{{ Math.max(0, (row.thread.posts?.count ?? 1) - 1) || '' }}</td>
          <td :class="cellClasses(row.thread)" class="text-2xs leading-3 opacity-80">
            {{ etwinActorName(row.thread.last_post?.author) }}<br />
            <span class="opacity-75">{{ dayjs(row.thread.last_post?.ctime).format('DD/MM HH:mm') }}</span>
          </td>
        </tr>
      </template>
    </tbody>
  </table>
</template>
