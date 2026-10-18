import { useApi } from './useApi'

// the sizes of the pages of the forum of Eternaltwin (GET /api/v1/config: forum.threads_per_page, posts_per_page)
let pageSizes = null

// the forum of Eternaltwin (https://eternaltwin.org/docs/app/etwin-forum), through the site
// (App\Http\Controllers\Api\EtwinForumController: Eternaltwin can't be called from the browser): its answers as they
// are, the pages counted from 1
export function useEtwinForum() {
  const { isLoading, error, get, post, patch } = useApi()

  const data = (response) => response.data
  const sizes = () => (pageSizes ??= get('/etwin-forum/config').then((response) => response.data.forum))
  const page = (number, size) => ({ offset: (Math.max(1, number) - 1) * size, limit: size })

  return {
    isLoading,
    error,
    // { category, can_write, needs_login }
    fetchStatus: () => get('/etwin-forum/status').then((response) => response.data.data),
    // every section, flat, each parent followed by its children
    fetchSections: () => get('/etwin-forum/sections').then(data),
    fetchSection: (ref, number = 1) =>
      sizes().then((size) => get(`/etwin-forum/sections/${ref}`, { params: page(number, size.threads_per_page) })).then(data),
    createThread: (ref, title, body) => post(`/etwin-forum/sections/${ref}`, { title, body }).then(data),
    fetchThread: (ref, number = 1) =>
      sizes().then((size) => get(`/etwin-forum/threads/${ref}`, { params: page(number, size.posts_per_page) })).then(data),
    reply: (ref, body) => post(`/etwin-forum/threads/${ref}`, { body }).then(data),
    // an explicit write, once the posts are on screen (never a side effect of the reading)
    markRead: (ref, upToPost) => post(`/etwin-forum/threads/${ref}/read`, { up_to_post: upToPost }).then(data),
    // the post with the Marktwin source of its revisions, to edit it
    fetchPostSource: (id) => get(`/etwin-forum/posts/${id}/source`).then(data),
    updatePost: (id, lastRevisionId, content) =>
      patch(`/etwin-forum/posts/${id}`, { last_revision_id: lastRevisionId, content, comment: null }).then(data),
  }
}

// the name of an actor of the forum (an author: {type: "UserForumActor", user: {display_name: {current: {value}}}})
export const etwinActorName = (actor) => actor?.user?.display_name?.current?.value ?? '?'

// a date of the forum, as on the site: "le 10/06/2010 à 22:02"
export const etwinForumDate = (iso) => (iso ? `le ${dayjs(iso).format('DD/MM/YYYY à HH:mm')}` : '')
