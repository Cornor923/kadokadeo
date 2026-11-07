const SUBJECT_MAX = 100
const BODY_MAX = 5000

// The form of a private message filled from its URL: the recipient and the subject from a profile or an answer, the
// title, text and link from another app (share_target of public/manifest.webmanifest). Some apps give the link in
// `text`, others in `url`, others in both: never twice. What the URL does not give is null.
export function messageDraft({ to, subject, title, text, url }) {
  const parts = [text, url && !text?.includes(url) ? url : null].filter(Boolean)

  return {
    to: to ?? null,
    subject: (subject ?? title)?.slice(0, SUBJECT_MAX) ?? null,
    body: parts.length ? parts.join('\n').slice(0, BODY_MAX) : null,
  }
}
