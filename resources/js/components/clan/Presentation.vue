<script setup>
import KadoPoints from '@svg/k.svg'

defineProps({
  clan: { type: Object, required: true },
  tournament: { type: Object, default: null },
})

// the presentation written in Markdown, turned into HTML by the server (App\Support\ClanMarkdown: the HTML of the
// players is escaped): the titles keep the style of the site, the lists get back their bullets
const markdownClasses = [
  'break-words [&_p]:my-2 [&_img]:inline [&_img]:max-w-full',
  '[&_h1]:mx-0 [&_h1]:mt-4 [&_h1]:mb-3 [&_h1]:text-[2em] [&_h2]:mt-4 [&_h2]:mb-2 [&_h3]:mt-3 [&_h3]:mb-2',
  '[&_ul]:my-2 [&_ul]:ml-4 [&_ul]:list-inside [&_ul]:list-image-[url(/gfx/puce.jpg)]',
  '[&_ol]:my-2 [&_ol]:ml-4 [&_ol]:list-inside [&_ol]:list-decimal [&_li]:my-0.5',
  '[&_blockquote]:my-2 [&_blockquote]:border-l-4 [&_blockquote]:border-kado-cyan-750 [&_blockquote]:pl-3 [&_blockquote]:italic',
  '[&_hr]:mx-auto [&_hr]:my-3 [&_hr]:w-48 [&_hr]:border-0 [&_hr]:border-t [&_hr]:border-solid [&_hr]:border-kado-blue',
  '[&_code]:bg-kado-cyan-200 [&_code]:px-1',
]
</script>

<template>
  <div class="space-y-4">

    <!-- sanitized server-side (App\Support\ClanMarkdown) -->
    <div v-if="clan.description_html"
         id="clanPresentation"
         :class="markdownClasses"
         v-html="clan.description_html" />
    <p v-else class="italic text-kado-cyan-900">Bienvenue sur la page du clan {{ clan.name }}.</p>

    <ul class="list-inside list-image-[url(/gfx/puce.jpg)] ml-4 space-y-1">
      <li v-if="clan.leader">
        Chef de clan :
        <img src="/gfx/clan/clanleader.gif" alt="Chef de Clan" title="Chef de Clan" />
        <RouterLink :to="{ name: 'profile.show', params: { id: clan.leader.etwin_id } }">{{ clan.leader.display_name }}</RouterLink>
      </li>
      <li>Ce clan comporte {{ clan.members_count }} joueur(s) sur {{ clan.max_members }}.</li>
      <li>{{ clan.is_recruiting ? 'Ce clan recrute de nouveaux membres.' : 'Ce clan ne recrute pas pour le moment.' }}</li>
    </ul>

    <template v-if="clan.history.length">
      <h2>Historique</h2>
      <ul class="list-inside list-image-[url(/gfx/puce.jpg)] ml-4 space-y-1">
        <li v-for="h in clan.history" :key="h.period_id">
          Période {{ h.period_id }} :
          <template v-if="h.war_rank">TOP {{ h.war_rank }} au classement des attaques ({{ h.war_score }})</template>
          <template v-if="h.war_rank && h.mission_rank">, </template>
          <template v-if="h.mission_rank">TOP {{ h.mission_rank }} au classement des missions ({{ h.mission_score }})</template>
          <template v-if="!h.war_rank && !h.mission_rank">non classé</template>
          <template v-if="h.reward > 0">
            — <Number :value="h.reward" color="green" /> <KadoPoints class="inline size-[17px]" />
          </template>
        </li>
      </ul>
    </template>
  </div>
</template>
