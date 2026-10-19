<script setup>
// a new topic of the forum of a clan: its title and its first message
const route = useRoute()
const router = useRouter()
const { createTopic, isLoading, error } = useClanForum()

const clanId = computed(() => route.params.id)
const title = ref('')
const content = ref('')

const submit = () =>
  createTopic(clanId.value, { title: title.value, content: content.value }).then(({ data }) =>
    router.push({ name: 'clans.forum.topic', params: { id: clanId.value, topic: data.id } }))
</script>

<template>
  <div class="relative">
    <ClanForumHeader :clan-id="clanId" linked />

    <form class="space-y-3 px-2 pb-2" @submit.prevent="submit">
      <MessageError v-if="error">{{ error }}</MessageError>
      <div>
        <label for="forumTitle" class="block font-bold">Titre du sujet</label>
        <FormInput id="forumTitle"
                   v-model="title"
                   maxlength="100"
                   required
                   class="w-full" />
      </div>
      <MarktwinEditor v-model="content" />
      <FormButton type="submit" size="lg" :disabled="isLoading || !title.trim() || !content.trim()">Créer le sujet</FormButton>
    </form>
  </div>
</template>
