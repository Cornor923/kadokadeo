import { useApi } from './useApi'

// the comments of a replay, its views and the reports of its comments (App\Http\Controllers\Api\RunCommentController)
export function useRunComments() {
  const { isLoading, error, get, post, put, patch, del } = useApi()

  const data = (response) => response.data

  return {
    isLoading,
    error,
    // { data: comments (in the order of the replay, answers after their comment), viewer: { can_comment },
    //   limits: { max_length, view_after_seconds }, report_reasons: [{ value, label }] }
    fetchComments: (runId) => get(`/runs/${runId}/comments`).then(data),
    // { frame, content, parent_id? } -> { data: comment }
    createComment: (runId, payload) => post(`/runs/${runId}/comments`, payload).then(data),
    updateComment: (commentId, content) => patch(`/run-comments/${commentId}`, { content }),
    deleteComment: (commentId) => del(`/run-comments/${commentId}`),
    // { data: { liked, likes_count } }
    like: (commentId) => put(`/run-comments/${commentId}/like`).then(data),
    unlike: (commentId) => del(`/run-comments/${commentId}/like`).then(data),
    // { reason, details? }
    report: (commentId, payload) => post(`/run-comments/${commentId}/report`, payload),
    // the replay watched long enough (counted once by player on the server)
    recordView: (runId) => post(`/runs/${runId}/view`),
  }
}
