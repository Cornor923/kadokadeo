import { useApi } from './useApi'

// the private forum of a clan (App\Http\Controllers\Api\ClanForumController)
export function useClanForum() {
  const { isLoading, error, get, post, patch, del } = useApi()

  const data = (response) => response.data
  const base = (clanId) => `/clans/${clanId}/forum`

  return {
    isLoading,
    error,
    // { data: topics, meta, viewer: { can_moderate } }
    fetchTopics: (clanId, params = {}) => get(`${base(clanId)}/topics`, { params }).then(data),
    createTopic: (clanId, payload) => post(`${base(clanId)}/topics`, payload).then(data),
    // { data: messages, meta, topic, viewer: { can_moderate, can_reply } } ("page" can be "last")
    fetchTopic: (clanId, topicId, page = 1) => get(`${base(clanId)}/topics/${topicId}`, { params: { page } }).then(data),
    updateTopic: (clanId, topicId, changes) => patch(`${base(clanId)}/topics/${topicId}`, changes),
    deleteTopic: (clanId, topicId) => del(`${base(clanId)}/topics/${topicId}`),
    // { data: { id, page } }
    reply: (clanId, topicId, content) => post(`${base(clanId)}/topics/${topicId}/messages`, { content }).then(data),
    updateMessage: (clanId, messageId, content) => patch(`${base(clanId)}/messages/${messageId}`, { content }),
    deleteMessage: (clanId, messageId) => del(`${base(clanId)}/messages/${messageId}`),
    restoreMessage: (clanId, messageId) => post(`${base(clanId)}/messages/${messageId}/restore`),
  }
}
